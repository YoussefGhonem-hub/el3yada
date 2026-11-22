using El3yada.Api.Features.AccountDeletion;
using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Paging;
using El3yada.Api.Infrastructure.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Admin;

/// <summary>
/// AD11 accounts support. Admins see account data only, never medical content (spec D9, 9.4). Deleting an account
/// (AD12) is Features/AccountDeletion.
/// </summary>
public sealed class AdminSupportService(
    AppDbContext db,
    IAuditLogger audit,
    SessionRevoker revoker,
    AccountStateCache stateCache,
    TimeProvider clock)
{
    // ---- AD11 --------------------------------------------------------------------------------

    /// <summary>
    /// Finds patient and assistant accounts by phone (one number can be both, A3). Each carries its deletion in progress,
    /// if any, for AD11's "Delete account" and "Cancel and restore".
    /// </summary>
    public async Task<AccountSearchResultDto> SearchAccountsAsync(AccountSearchQuery query, CancellationToken ct)
    {
        if (!EgyptianPhone.TryNormalize(query.Phone, out var phone))
            throw ApiException.BadRequest(ErrorCodes.ValidationFailed);

        var patients = await db.Patients.AsNoTracking()
            .Where(p => p.Phone == phone)
            .Select(p => new SupportPatientDto(
                p.UserId, p.Id, p.FullName, p.Phone, p.User.Status, p.Status, p.CreatedAt,
                p.DoctorPatients.OrderBy(l => l.LinkedAt)
                    .Select(l => new LinkedDoctorDto(l.DoctorId, l.Doctor.FullName)).ToList(),
                db.DeletionRequests
                    .Where(r => r.UserId == p.UserId && DeletionStatuses.Open.Contains(r.Status))
                    .Select(r => new SupportDeletionDto(r.Id, r.Status, r.ScheduledFor))
                    .FirstOrDefault()))
            .ToListAsync(ct);

        var assistants = await db.Assistants.AsNoTracking()
            .Where(a => a.Phone == phone)
            .OrderBy(a => a.CreatedAt)
            .Select(a => new SupportAssistantDto(
                a.UserId, a.FullName, a.Phone, a.User.Status, a.Status,
                a.DoctorId, a.Doctor.FullName, a.Preset, a.LastActiveAt,
                db.DeletionRequests
                    .Where(r => r.UserId == a.UserId && DeletionStatuses.Open.Contains(r.Status))
                    .Select(r => new SupportDeletionDto(r.Id, r.Status, r.ScheduledFor))
                    .FirstOrDefault()))
            .ToListAsync(ct);

        audit.Add("accounts.searched", "User", null, details: new { phone });
        await db.SaveChangesAsync(ct);

        return new AccountSearchResultDto(phone, patients, assistants);
    }

    /// <summary>AD11: disable or enable login for a patient or assistant account.</summary>
    public async Task SetLoginStatusAsync(Guid userId, SetLoginStatusRequest request, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var user = await db.Users.FirstOrDefaultAsync(u => u.Id == userId, ct) ?? throw ApiException.NotFound();
        if (user.Role is not (Roles.Patient or Roles.Assistant))
            throw ApiException.BadRequest(ErrorCodes.AccountRoleNotSupported);

        // An account being deleted is restored or erased through AD12, never switched on here (spec 6.17).
        if (user.Status == AccountStatuses.Deleted) throw ApiException.Conflict(ErrorCodes.AccountDeleted);
        if (user.Status == AccountStatuses.PendingDeletion) throw ApiException.Conflict(ErrorCodes.AccountDeletionScheduled);

        if (request.Status == "active")
        {
            // A deleted patient or a removed assistant stays off.
            var blocked = user.Role == Roles.Patient
                ? await db.Patients.AnyAsync(p => p.UserId == userId && p.Status == "deleted", ct)
                : await db.Assistants.AnyAsync(a => a.UserId == userId && a.Status == "removed", ct);
            if (blocked) throw ApiException.Conflict(ErrorCodes.AccountDeleted);
        }

        if (user.Status != request.Status)
        {
            user.Status = request.Status;
            user.UpdatedAt = clock.GetUtcNow().UtcDateTime;
            if (request.Status == "disabled") await revoker.RevokeAllAsync(userId, ct);

            audit.Add(request.Status == "disabled" ? "user.disabled" : "user.enabled", "User", userId,
                details: new { role = user.Role, reason = request.Reason });
            await db.SaveChangesAsync(ct);
        }

        await tx.CommitAsync(ct);
        stateCache.Invalidate(userId);
    }
}
