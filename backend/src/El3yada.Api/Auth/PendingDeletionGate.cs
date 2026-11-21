using El3yada.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc.Filters;

namespace El3yada.Api.Auth;

/// <summary>
/// Marks an endpoint that an account in its deletion grace period may still call (BR-DEL3, A16): restore, read the
/// session and its own deletion, set a first password, and the clinic's billing (a doctor pays the invoices that hold
/// the erasure back). Every other authenticated endpoint answers 403 <c>ACCOUNT_PENDING_DELETION</c>.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class AllowWhilePendingDeletionAttribute : Attribute;

/// <summary>The global filter behind <see cref="AllowWhilePendingDeletionAttribute"/>.</summary>
public sealed class PendingDeletionGate : IAuthorizationFilter
{
    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var metadata = context.ActionDescriptor.EndpointMetadata;
        if (metadata.OfType<IAllowAnonymous>().Any() || metadata.OfType<AllowWhilePendingDeletionAttribute>().Any())
        {
            return;
        }

        if (context.HttpContext.Items[AuthSetup.AccountStateKey] is AccountState { IsPendingDeletion: true })
        {
            context.Result = ApiProblems.Result(
                context.HttpContext, StatusCodes.Status403Forbidden, ErrorCodes.AccountPendingDeletion,
                "This account is scheduled for deletion. Restore it to continue.");
        }
    }
}
