using System.Security.Claims;
using System.Text.Json;
using System.Text.Json.Nodes;
using El3yada.Api.Auth;
using El3yada.Data;
using AuditLogRow = El3yada.Data.Entities.AuditLog;

namespace El3yada.Api.Audit;

/// <summary>Who did something: a signed-in user, or the system (background jobs, anonymous requests).</summary>
public readonly record struct AuditActor(Guid? UserId, string Role)
{
    public static readonly AuditActor System = new(null, "system");

    public static AuditActor Of(ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirstValue(ClaimNames.Subject), out var id)
        && user.FindFirstValue(ClaimNames.Role) is { } role
            ? new AuditActor(id, role)
            : System;
}

/// <summary>
/// The one way to write AuditLogs. <see cref="Add"/> adds the row to the request's DbContext, so it is saved
/// in the same SaveChanges (and transaction) as the change it describes: no change without its audit row,
/// and no audit row for a change that failed.
/// <para>
/// Never pass passwords, tokens or medical text (diagnoses, notes, file contents). Details are for IDs,
/// statuses, field names and admin-typed reasons. As a safety net, any detail whose name contains
/// "password", "token" or "secret" is dropped.
/// </para>
/// </summary>
public sealed class Auditor(AppDbContext db, IHttpContextAccessor httpContextAccessor, TimeProvider time)
{
    private static readonly string[] ForbiddenNameParts = ["password", "token", "secret"];

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    /// <summary>
    /// Adds an audit row. <paramref name="actor"/> defaults to the signed-in user of the current request
    /// (or <see cref="AuditActor.System"/>). <paramref name="doctorId"/> puts the row in that doctor's clinic
    /// activity log (D27).
    /// </summary>
    public AuditLogRow Add(
        string action,
        string targetType,
        object? targetId,
        object? details = null,
        Guid? doctorId = null,
        Guid? patientId = null,
        AuditActor? actor = null)
    {
        var who = actor ?? (httpContextAccessor.HttpContext?.User is { } user ? AuditActor.Of(user) : AuditActor.System);
        var row = new AuditLogRow
        {
            ActorUserId = who.UserId,
            ActorRole = who.Role,
            DoctorId = doctorId,
            PatientId = patientId,
            Action = action,
            TargetType = targetType,
            TargetId = targetId switch
            {
                null => null,
                Guid guid => guid.ToString(),
                _ => targetId.ToString(),
            },
            DetailsJson = Serialize(details),
            At = time.GetUtcNow().UtcDateTime,
        };
        db.AuditLogs.Add(row);
        return row;
    }

    /// <summary>The details as JSON, without forbidden names. Exposed for tests.</summary>
    public static string? Serialize(object? details)
    {
        if (details is null)
        {
            return null;
        }

        var node = JsonSerializer.SerializeToNode(details, JsonOptions);
        Scrub(node);
        return node?.ToJsonString(JsonOptions);
    }

    private static void Scrub(JsonNode? node)
    {
        switch (node)
        {
            case JsonObject obj:
                foreach (var name in obj.Select(pair => pair.Key).ToList())
                {
                    if (ForbiddenNameParts.Any(part => name.Contains(part, StringComparison.OrdinalIgnoreCase)))
                    {
                        obj.Remove(name);
                    }
                    else
                    {
                        Scrub(obj[name]);
                    }
                }

                break;
            case JsonArray array:
                foreach (var item in array)
                {
                    Scrub(item);
                }

                break;
        }
    }
}

/// <summary>AuditLogs.Action values (AD15 filters by these). Phase 1 here; later phases add theirs in their own files.</summary>
public static partial class AuditActions
{
    public const string DoctorRegistrationSubmitted = "doctorRegistrationSubmitted";
    public const string DoctorRegistrationResubmitted = "doctorRegistrationResubmitted";
    public const string DoctorRegistrationApproved = "doctorRegistrationApproved";
    public const string DoctorRegistrationRejected = "doctorRegistrationRejected";
    public const string DoctorLicenseViewed = "doctorLicenseViewed";
    public const string AdminCreated = "adminCreated";
    public const string AdminSeeded = "adminSeeded";
    public const string AdminRoleChanged = "adminRoleChanged";
    public const string AdminDisabled = "adminDisabled";
    public const string AdminEnabled = "adminEnabled";
    public const string AdminProfileUpdated = "adminProfileUpdated";
    public const string SettingsUpdated = "settingsUpdated";
    public const string PasswordSet = "passwordSet";
    public const string PasswordChanged = "passwordChanged";
    public const string PasswordResetRequested = "passwordResetRequested";
    public const string PasswordReset = "passwordReset";
    public const string AccountLockedOut = "accountLockedOut";
    public const string RefreshTokenReuseDetected = "refreshTokenReuseDetected";
    public const string EmailVerified = "emailVerified";
}

/// <summary>AuditLogs.TargetType values.</summary>
public static partial class AuditTargets
{
    public const string User = "user";
    public const string Doctor = "doctor";
    public const string Settings = "settings";
}
