using El3yada.Api.Features.PatientPortal;
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
/// AD11 accounts support and AD12 deletion requests. Admins see account data only, never
/// medical content (spec D9, 9.4).
/// </summary>
public sealed class AdminSupportService(
    AppDbContext db,
    ICurrentUser admin,
    IAuditLogger audit,
    SessionRevoker revoker,
    TimeProvider clock)
{
    // ---- AD12 --------------------------------------------------------------------------------

    public Task<PagedResult<AdminDeletionRequestDto>> GetDeletionRequestsAsync(DeletionRequestsQuery query, CancellationToken ct)
    {
        var requests = db.DeletionRequests.AsNoTracking();
        if (query.Status != "all") requests = requests.Where(r => r.Status == query.Status);

        // Oldest first while waiting (a queue); newest first for the history.
        requests = query.Status == "pending"
            ? requests.OrderBy(r => r.CreatedAt)
            : requests.OrderByDescending(r => r.CreatedAt);

        return requests
            .Select(r => new AdminDeletionRequestDto(
                r.Id, r.PatientId, r.Patient.FullName, r.Patient.Phone, r.Reason, r.Status,
                r.CreatedAt, r.ReviewedAt,
                r.ReviewedByNavigation == null ? null : r.ReviewedByNavigation.DisplayName,
                r.ReviewNote))
            .ToPagedAsync(query, ct);
    }

    /// <summary>
    /// <c>reviewDeletionRequest</c>. Approve: the patient can no longer sign in (login disabled,
    /// every session revoked) and the patient row is marked <c>deleted</c>. Medical records are kept:
    /// how long they are retained and when personal data is erased is open question Q16, so nothing
    /// is erased here. Reject: needs a note, which the patient sees in P14.
    /// </summary>
    public async Task<DeletionRequestDto> ReviewDeletionRequestAsync(Guid id, ReviewDeletionRequest request, CancellationToken ct)
    {
        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var entity = await db.DeletionRequests.Include(r => r.Patient).FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw ApiException.NotFound();
        if (entity.Status != "pending") throw ApiException.Conflict(ErrorCodes.DeletionAlreadyReviewed);

        var now = clock.GetUtcNow().UtcDateTime;
        var approve = request.Decision == "approve";
        entity.Status = approve ? "approved" : "rejected";
        entity.ReviewedBy = admin.UserId;
        entity.ReviewedAt = now;
        entity.ReviewNote = string.IsNullOrWhiteSpace(request.Note) ? null : request.Note.Trim();

        if (approve)
        {
            var patient = entity.Patient;
            patient.Status = "deleted";
            patient.DeletedAt = now;
            patient.UpdatedAt = now;
            await db.Users.Where(u => u.Id == patient.UserId)
                .ExecuteUpdateAsync(u => u.SetProperty(x => x.Status, "disabled"), ct);
            await revoker.RevokeAllAsync(patient.UserId, ct);
        }

        audit.Add(approve ? "deletionRequest.approved" : "deletionRequest.rejected",
            nameof(DeletionRequest), entity.Id, patientId: entity.PatientId,
            details: new { note = entity.ReviewNote });

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return PatientAccountService.ToDto(entity);
    }

    // ---- AD11 --------------------------------------------------------------------------------

    /// <summary>Finds patient and assistant accounts by phone (one number can be both, A3).</summary>
    public async Task<AccountSearchResultDto> SearchAccountsAsync(AccountSearchQuery query, CancellationToken ct)
    {
        if (!EgyptianPhone.TryNormalize(query.Phone, out var phone))
            throw ApiException.BadRequest(ErrorCodes.ValidationFailed);

        var patients = await db.Patients.AsNoTracking()
            .Where(p => p.Phone == phone)
            .Select(p => new SupportPatientDto(
                p.UserId, p.Id, p.FullName, p.Phone, p.User.Status, p.Status, p.CreatedAt,
                p.DoctorPatients.OrderBy(l => l.LinkedAt)
                    .Select(l => new LinkedDoctorDto(l.DoctorId, l.Doctor.FullName)).ToList()))
            .ToListAsync(ct);

        var assistants = await db.Assistants.AsNoTracking()
            .Where(a => a.Phone == phone)
            .OrderBy(a => a.CreatedAt)
            .Select(a => new SupportAssistantDto(
                a.UserId, a.FullName, a.Phone, a.User.Status, a.Status,
                a.DoctorId, a.Doctor.FullName, a.Preset, a.LastActiveAt))
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
    }
}
