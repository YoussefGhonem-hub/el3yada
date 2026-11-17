using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Clinic;

/// <summary>
/// Guards a clinic endpoint (spec 9.1, 9.4): the caller must be a doctor, or an assistant of that doctor, and
/// passes these checks in order, each read from the database on this request:
/// <list type="number">
/// <item>Not a doctor or an assistant (patient, admin): 403 <c>FORBIDDEN</c>.</item>
/// <item>The doctor is pending approval or rejected: 403 <c>DOCTOR_PENDING_APPROVAL</c> or <c>DOCTOR_REJECTED</c> (A6, A7).
/// For an assistant, a clinic that is not active or an assistant who is not active: 403 <c>CLINIC_NOT_ACTIVE</c>
/// or <c>ACCOUNT_DISABLED</c> (the sign-in check usually catches these first).</item>
/// <item>The clinic's free trial has ended (BR-T4): 403 <c>TRIAL_ENDED</c>, for every endpoint without
/// <see cref="AllowedAfterTrialAttribute"/>.</item>
/// <item><see cref="DoctorOnly"/> and the caller is an assistant (BR-AS5): 403 <c>PERMISSION_DENIED</c>.</item>
/// <item>The assistant lacks <see cref="Permission"/>: 403 <c>PERMISSION_DENIED</c>, with <c>permission</c> in the answer.</item>
/// <item><see cref="BlockedWhileSuspended"/> and the doctor is suspended (BR-G5, BR-G8): 403 <c>DOCTOR_SUSPENDED</c>.</item>
/// </list>
/// Put it on the controller for the role check and on actions for their permission; every attribute on an
/// action must pass. Branch checks (BR-AS13) depend on the data, so actions do them with
/// <see cref="ClinicCaller.CanUseBranch"/> and answer <c>BRANCH_NOT_ALLOWED</c>.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public sealed class ClinicAttribute(string? permission = null) : Attribute, IAsyncActionFilter, IOrderedFilter
{
    /// <summary>The assistant permission the endpoint needs (a <see cref="ClinicPermissions"/> key), or null.</summary>
    public string? Permission { get; } = permission is null || ClinicPermissions.IsKnown(permission)
        ? permission
        : throw new ArgumentException($"Unknown clinic permission '{permission}'.", nameof(permission));

    /// <summary>Never allowed to assistants (BR-AS5, spec 9.1 "doctor only").</summary>
    public bool DoctorOnly { get; set; }

    /// <summary>Refused while the doctor is suspended (the "Blocked" column of BR-G5).</summary>
    public bool BlockedWhileSuspended { get; set; }

    /// <summary>
    /// Runs before the global ValidationFilter (order 0), so a caller who may not use the endpoint gets 403 for
    /// any body, never a 400 that describes the endpoint's fields.
    /// </summary>
    public int Order => -1000;

    /// <summary>An assistant is "last active" at most this often (D25), to avoid a write on every request.</summary>
    private static readonly TimeSpan LastActiveResolution = TimeSpan.FromMinutes(5);

    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var http = context.HttpContext;
        var caller = http.Items[ClinicCallerExtensions.ItemKey] as ClinicCaller;
        if (caller is null)
        {
            var account = http.Account();
            var db = http.RequestServices.GetRequiredService<AppDbContext>();
            caller = await ClinicCaller.LoadAsync(db, account.UserId, account.Role, http.RequestAborted);
            if (caller is null)
            {
                context.Result = Forbidden(http, ErrorCodes.Forbidden, "Only doctors and assistants can use this.");
                return;
            }

            if (Refusal(caller) is { } refusal)
            {
                context.Result = refusal(http);
                return;
            }

            var now = http.RequestServices.GetRequiredService<TimeProvider>().GetUtcNow().UtcDateTime;
            if (Doctors.Trial.HasEnded(caller.TrialEndsAt, now)
                && !context.ActionDescriptor.EndpointMetadata.OfType<AllowedAfterTrialAttribute>().Any())
            {
                context.Result = Forbidden(http, ErrorCodes.TrialEnded, "The clinic's free trial has ended. Contact us to activate the service.");
                return;
            }

            http.Items[ClinicCallerExtensions.ItemKey] = caller;
            await TouchLastActiveAsync(db, caller, http);
        }

        if (DoctorOnly && !caller.IsDoctor)
        {
            context.Result = PermissionDenied(http, "doctorOnly");
            return;
        }

        if (Permission is not null && !caller.Has(Permission))
        {
            context.Result = PermissionDenied(http, Permission);
            return;
        }

        if (BlockedWhileSuspended && caller.IsSuspended)
        {
            context.Result = Forbidden(http, ErrorCodes.DoctorSuspended, "The clinic is suspended until the overdue invoice is paid.");
            return;
        }

        await next();
    }

    private static Func<HttpContext, IActionResult>? Refusal(ClinicCaller caller)
    {
        if (caller.IsDoctor)
        {
            string? code = caller.DoctorStatus switch
            {
                DoctorStatuses.Active or DoctorStatuses.Suspended => null,
                DoctorStatuses.PendingApproval => ErrorCodes.DoctorPendingApproval,
                DoctorStatuses.Rejected => ErrorCodes.DoctorRejected,
                _ => ErrorCodes.AccountDisabled,
            };
            return code is null ? null : http => Forbidden(http, code, "The doctor account is not active.");
        }

        if (caller.AssistantStatus != "active")
        {
            return http => Forbidden(http, ErrorCodes.AccountDisabled, "This account is disabled.");
        }

        return DoctorStatuses.ClinicIsOpen(caller.DoctorStatus)
            ? null
            : http => Forbidden(http, ErrorCodes.ClinicNotActive, "The clinic account is not active.");
    }

    private static async Task TouchLastActiveAsync(AppDbContext db, ClinicCaller caller, HttpContext http)
    {
        if (caller.IsDoctor)
        {
            return;
        }

        var now = http.RequestServices.GetRequiredService<TimeProvider>().GetUtcNow().UtcDateTime;
        if (caller.LastActiveAt is { } last && now - last < LastActiveResolution)
        {
            return;
        }

        await db.Assistants.Where(a => a.UserId == caller.UserId)
            .ExecuteUpdateAsync(set => set.SetProperty(a => a.LastActiveAt, now), http.RequestAborted);
    }

    private static ObjectResult Forbidden(HttpContext http, string code, string title) =>
        ApiProblems.Result(http, StatusCodes.Status403Forbidden, code, title);

    private static ObjectResult PermissionDenied(HttpContext http, string permission)
    {
        var result = Forbidden(http, ErrorCodes.PermissionDenied, "Your clinic permissions don't include this.");
        ((ProblemDetails)result.Value!).Extensions["permission"] = permission;
        return result;
    }
}
