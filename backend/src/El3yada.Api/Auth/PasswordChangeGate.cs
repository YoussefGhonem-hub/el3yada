using El3yada.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Filters;

namespace El3yada.Api.Auth;

/// <summary>
/// Marks an endpoint that an account with <c>mustChangePassword</c> may still call (A9: set the new password,
/// read the session, sign out). Every other authenticated endpoint answers 403 PASSWORD_CHANGE_REQUIRED.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class AllowWhilePasswordChangeRequiredAttribute : Attribute;

/// <summary>The global filter behind <see cref="AllowWhilePasswordChangeRequiredAttribute"/>.</summary>
public sealed class PasswordChangeGate : IAuthorizationFilter
{
    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var metadata = context.ActionDescriptor.EndpointMetadata;
        if (metadata.OfType<IAllowAnonymous>().Any() || metadata.OfType<AllowWhilePasswordChangeRequiredAttribute>().Any())
        {
            return;
        }

        if (context.HttpContext.Items[AuthSetup.AccountStateKey] is AccountState { MustChangePassword: true })
        {
            context.Result = ApiProblems.Result(
                context.HttpContext, StatusCodes.Status403Forbidden, ErrorCodes.PasswordChangeRequired,
                "Set a new password first.");
        }
    }
}
