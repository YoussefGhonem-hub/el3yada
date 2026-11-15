using El3yada.Api.Common;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Clinic;

/// <summary>
/// Clinic refusals that depend on the request or the data, in the same shape as <see cref="ClinicAttribute"/>'s
/// (api-phase-2.md): permissions an endpoint checks itself (any one of several, doctor-only fields), branches
/// (BR-AS13), and problems with extra fields.
/// </summary>
public static class ClinicDenials
{
    /// <summary>403 <c>PERMISSION_DENIED</c> with <c>permission</c>: a <see cref="ClinicPermissions"/> key or <c>doctorOnly</c>.</summary>
    public static ObjectResult PermissionDenied(this ControllerBase controller, string permission) =>
        controller.ForbiddenProblem(ErrorCodes.PermissionDenied, "Your clinic permissions don't include this.")
            .WithFields(("permission", permission));

    /// <summary>For endpoints open to any one of several permissions: null when the caller has one, otherwise a refusal naming the first.</summary>
    public static ObjectResult? RequireAny(this ControllerBase controller, ClinicCaller caller, params string[] permissions) =>
        permissions.Any(caller.Has) ? null : controller.PermissionDenied(permissions[0]);

    /// <summary>403 <c>BRANCH_NOT_ALLOWED</c> (BR-AS13).</summary>
    public static ObjectResult BranchNotAllowed(this ControllerBase controller) =>
        controller.ForbiddenProblem(ErrorCodes.BranchNotAllowed, "This branch is not one of your branches.");

    /// <summary>Adds fields next to <c>code</c> in a problem answer.</summary>
    public static ObjectResult WithFields(this ObjectResult result, params (string Name, object? Value)[] fields)
    {
        var problem = (ProblemDetails)result.Value!;
        foreach (var (name, value) in fields)
        {
            problem.Extensions[name] = value;
        }

        return result;
    }
}
