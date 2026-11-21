using El3yada.Api.Common;
using PagedResultOf = El3yada.Api.Infrastructure.Paging;
using El3yada.Api.Validation;
using El3yada.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.AccountDeletion;

/// <summary>
/// Account deletion (spec 6.17; the contract is backend/docs/api-account-deletion.md): the account's own endpoints
/// (P14, D24, AS12, AD18 and the restore screen A16) and the admin's (AD12, and AD5 / AD11 / AD14 "Delete account").
/// </summary>
[ApiController]
[Produces("application/json")]
public sealed class AccountDeletionController(AccountDeletionService service, AppDbContext db, Passwords passwords, TimeProvider time)
    : ControllerBase
{
    // ---- The signed-in account ------------------------------------------------------------------------------

    /// <summary>
    /// <c>getAccountDeletion</c>: what deleting this account does now (the grace period, a doctor's unpaid invoices or
    /// final invoice), or the deletion in progress (A16).
    /// </summary>
    [HttpGet("api/me/accountDeletion", Name = "getAccountDeletion")]
    [Authorize(Policy = Policies.SignedIn)]
    [AllowWhilePendingDeletion]
    public Task<AccountDeletionStateView> GetState(CancellationToken cancellationToken) =>
        service.GetStateAsync(User.UserId(), cancellationToken);

    /// <summary>
    /// <c>requestAccountDeletion</c>: checks the current password, then disables the account and signs out every device
    /// (this one too). The identity is erased after the grace period (BR-DEL2).
    /// </summary>
    [HttpPost("api/me/requestAccountDeletion", Name = "requestAccountDeletion")]
    [Authorize(Policy = Policies.SignedIn)]
    [EnableRateLimiting(RateLimitPolicies.Login)]
    public async Task<IActionResult> RequestDeletion(RequestAccountDeletionRequest request, CancellationToken cancellationToken)
    {
        var userId = User.UserId();
        var user = await db.Users.AsNoTracking().SingleAsync(u => u.Id == userId, cancellationToken);
        if (!passwords.Verify(user, request.CurrentPassword!))
        {
            return ValidationProblems.Field(HttpContext, "currentPassword", ErrorCodes.CurrentPasswordIncorrect, "The current password is wrong.");
        }

        return Ok(await service.StartAsync(userId, userId, request.Reason, cancellationToken));
    }

    /// <summary><c>restoreAccount</c> (A16): ends the deletion and returns the session, now usable everywhere again.</summary>
    [HttpPost("api/me/restoreAccount", Name = "restoreAccount")]
    [Authorize(Policy = Policies.SignedIn)]
    [AllowWhilePendingDeletion]
    public async Task<IActionResult> Restore(CancellationToken cancellationToken)
    {
        var userId = User.UserId();
        await service.RestoreAsync(userId, cancellationToken);
        var account = await AccountState.LoadAsync(db, userId, cancellationToken);
        return Ok(await SessionView.OfAsync(db, account!, time.GetUtcNow().UtcDateTime, cancellationToken));
    }

    // ---- Admin (AD12) ---------------------------------------------------------------------------------------

    /// <summary><c>getAccountDeletions</c> (AD12): newest first; <c>role</c>, <c>status</c> and <c>userId</c> filter.</summary>
    [HttpGet("api/admin/accountDeletions", Name = "getAccountDeletions")]
    [Authorize(Policy = Policies.Admin)]
    public Task<PagedResultOf.PagedResult<AccountDeletionItem>> List([FromQuery] AccountDeletionsQuery query, CancellationToken cancellationToken) =>
        service.ListAsync(query, cancellationToken);

    /// <summary>
    /// <c>adminScheduleAccountDeletion</c>: an admin starts the deletion of an account for a support case, with a reason.
    /// The same grace period and rules apply. Only a super admin can start it for another admin.
    /// </summary>
    [HttpPost("api/admin/accountDeletions/schedule", Name = "adminScheduleAccountDeletion")]
    [Authorize(Policy = Policies.Admin)]
    public async Task<IActionResult> Schedule(AdminScheduleAccountDeletionRequest request, CancellationToken cancellationToken)
    {
        var targetId = request.UserId!.Value;
        var role = await db.Users.AsNoTracking().Where(u => u.Id == targetId).Select(u => u.Role).SingleOrDefaultAsync(cancellationToken);
        if (role is null)
        {
            return this.NotFoundProblem();
        }

        var adminId = User.UserId();
        if (role == Roles.Admin && targetId != adminId && !HttpContext.Account().IsSuperAdmin)
        {
            return this.ForbiddenProblem(ErrorCodes.Forbidden, "Only a super admin can delete another admin's account.");
        }

        var started = await service.StartAsync(targetId, adminId, request.Reason, cancellationToken);
        return Ok((await service.ListAsync(new AccountDeletionsQuery { UserId = targetId, PageSize = 1 }, cancellationToken)).Items.Single(i => i.Id == started.RequestId));
    }

    /// <summary><c>adminCancelAccountDeletion</c>: cancels a deletion in progress and restores the account, with a reason.</summary>
    [HttpPost("api/admin/accountDeletions/{id:guid}/cancel", Name = "adminCancelAccountDeletion")]
    [Authorize(Policy = Policies.Admin)]
    public async Task<IActionResult> Cancel(Guid id, AdminCancelAccountDeletionRequest request, CancellationToken cancellationToken) =>
        Ok(await service.AdminCancelAsync(id, User.UserId(), HttpContext.Account().IsSuperAdmin, request.Reason!, cancellationToken));
}
