using System.Data;
using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.PatientPortal;

/// <summary>P14: the patient's account, and <c>requestAccountDeletion</c>.</summary>
public sealed class PatientAccountService(
    AppDbContext db,
    PatientContext patient,
    PatientPortalService portal,
    ICurrentUser user,
    IAuditLogger audit,
    INotificationWriter notifications,
    TimeProvider clock)
{
    public async Task<PatientAccountDto> GetAccountAsync(CancellationToken ct)
    {
        var personal = await portal.GetPersonalInfoAsync(ct);
        var account = await db.Users.AsNoTracking()
            .Where(u => u.Id == user.UserId)
            .Select(u => new { u.Locale, u.ThemeMode, u.NotifyChat, u.NotifyReminders, u.NotifyShowPreview, u.AcceptedTermsAt })
            .FirstAsync(ct);

        return new PatientAccountDto(
            personal, account.Locale, account.ThemeMode, account.NotifyChat, account.NotifyReminders,
            account.NotifyShowPreview, account.AcceptedTermsAt, await GetLatestDeletionRequestAsync(personal.PatientId, ct));
    }

    public async Task<DeletionRequestDto?> GetDeletionRequestAsync(CancellationToken ct) =>
        await GetLatestDeletionRequestAsync(await patient.GetPatientIdAsync(ct), ct);

    /// <summary>
    /// <c>requestAccountDeletion</c> (P14 → AD12). One pending request at a time. Admins are notified.
    /// Nothing is deleted here: an admin reviews the request (<c>reviewDeletionRequest</c>).
    /// </summary>
    public async Task<DeletionRequestDto> RequestDeletionAsync(RequestAccountDeletionRequest request, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);

        // Serializable: two taps on two devices can't both create a pending request.
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);

        if (await db.DeletionRequests.AnyAsync(r => r.PatientId == pid && r.Status == "pending", ct))
            throw ApiException.Conflict(ErrorCodes.DeletionAlreadyRequested);

        var entity = new DeletionRequest
        {
            Id = NewId.Next(),
            PatientId = pid,
            Reason = string.IsNullOrWhiteSpace(request.Reason) ? null : request.Reason.Trim(),
            Status = "pending",
            CreatedAt = clock.GetUtcNow().UtcDateTime,
        };
        db.DeletionRequests.Add(entity);
        await db.SaveChangesAsync(ct);

        audit.Add("deletionRequest.created", nameof(DeletionRequest), entity.Id, patientId: pid);
        await notifications.AddForAdminsAsync(new NotificationMessage(
            Type: "deletionRequest",
            TitleAr: "طلب حذف حساب",
            TitleEn: "Account deletion request",
            BodyAr: "طلب مريض حذف حسابه. راجع الطلب.",
            BodyEn: "A patient asked to delete their account. Review the request.",
            Route: "/admin/deletion-requests",
            Data: new { deletionRequestId = entity.Id }), ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return ToDto(entity);
    }

    private async Task<DeletionRequestDto?> GetLatestDeletionRequestAsync(Guid patientId, CancellationToken ct)
    {
        var latest = await db.DeletionRequests.AsNoTracking()
            .Where(r => r.PatientId == patientId)
            .OrderByDescending(r => r.CreatedAt)
            .FirstOrDefaultAsync(ct);
        return latest is null ? null : ToDto(latest);
    }

    internal static DeletionRequestDto ToDto(DeletionRequest r) =>
        new(r.Id, r.Status, r.Reason, r.CreatedAt, r.ReviewedAt, r.ReviewNote);
}
