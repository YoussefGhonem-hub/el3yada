using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using El3yada.Api.Storage;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.AccountDeletion;

/// <summary>
/// Erases an account's identity and keeps its medical and billing records (spec 6.17, BR-DEL4). Runs inside the daily
/// job's transaction and saves nothing itself; files to remove are returned, to delete once the transaction commits.
/// <para>
/// <b>Erased</b>, for every role: the name (the role's «… محذوف»), phone, email, password hash, refresh tokens, push
/// devices, email tokens, notifications, unread counts and notification preferences. A patient also loses the national
/// ID, address and emergency contact, and their name and phone on every clinic link (DoctorPatients). A doctor also
/// loses the English name, degrees, licence number and scan, prescription logo, signature and footer, and each branch's
/// address details, landmark, map link, email, description, phones and photos; their assistants are erased with them.
/// Chat messages keep their text, with the sender's name replaced.
/// </para>
/// <para>
/// <b>Kept</b>: sessions, private notes, medical profile items, medical files, prescriptions and their PDFs, chats,
/// invoices, payments and screenshots, adjustments, the audit log; and for a patient the gender, date of birth and blood
/// type, which the clinical record needs (doses, age-dependent ranges, transfusion safety).
/// </para>
/// </summary>
public sealed class AccountErasure(AppDbContext db, TimeProvider time)
{
    /// <summary>Erases the account and returns the stored files to delete after the commit.</summary>
    public async Task<List<StoragePath>> EraseAsync(Guid userId, CancellationToken cancellationToken)
    {
        var files = new List<StoragePath>();
        var user = await db.Users.SingleAsync(u => u.Id == userId, cancellationToken);
        switch (user.Role)
        {
            case Roles.Patient:
                await ErasePatientAsync(user, cancellationToken);
                break;
            case Roles.Doctor:
                await EraseDoctorAsync(user, files, cancellationToken);
                break;
            case Roles.Assistant:
                await EraseAssistantAsync(user, cancellationToken);
                break;
        }

        await EraseUserAsync(user, cancellationToken);
        return files;
    }

    /// <summary>The Users row and what hangs off it, for every role.</summary>
    private async Task EraseUserAsync(User user, CancellationToken cancellationToken)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var id = user.Id;
        user.DisplayName = Tombstones.NameFor(user.Role);
        user.Phone = null;
        user.Email = Tombstones.Email(id);
        user.EmailVerifiedAt = null;
        user.PasswordHash = null;
        user.SecurityStamp = Guid.NewGuid();
        user.MustChangePassword = false;
        user.AccessFailedCount = 0;
        user.LockoutEndAt = null;
        user.Locale = "ar";
        user.ThemeMode = "system";
        user.NotifyChat = true;
        user.NotifyReminders = true;
        user.NotifyShowPreview = false;
        user.NotifyBookings = false;
        user.LastLoginAt = null;
        user.Status = AccountStatuses.Deleted;
        user.UpdatedAt = now;

        await db.RefreshTokens.Where(t => t.UserId == id).ExecuteDeleteAsync(cancellationToken);
        await db.UserDevices.Where(d => d.UserId == id).ExecuteDeleteAsync(cancellationToken);
        await db.UserTokens.Where(t => t.UserId == id).ExecuteDeleteAsync(cancellationToken);
        await db.Notifications.Where(n => n.RecipientUserId == id).ExecuteDeleteAsync(cancellationToken);
        await db.ChatReadStates.Where(s => s.UserId == id).ExecuteDeleteAsync(cancellationToken);
        await db.ChatMessages.Where(m => m.SenderId == id)
            .ExecuteUpdateAsync(set => set.SetProperty(m => m.SenderName, Tombstones.NameFor(user.Role)), cancellationToken);
    }

    private async Task ErasePatientAsync(User user, CancellationToken cancellationToken)
    {
        var patient = await db.Patients.SingleOrDefaultAsync(p => p.UserId == user.Id, cancellationToken);
        if (patient is null)
        {
            return;
        }

        var now = time.GetUtcNow().UtcDateTime;
        // A value no number can match: the number is free for a new account (UQ_Patients_Phone, UQ_Users_PatientPhone).
        var phone = Tombstones.Phone();
        patient.FullName = Tombstones.PatientName;
        patient.Phone = phone;
        patient.NationalId = null;
        patient.Address = null;
        patient.EmergencyContactName = null;
        patient.EmergencyContactPhone = null;
        patient.Status = "deleted";
        patient.DeletedAt = now;
        patient.UpdatedAt = now;

        var search = SearchText.Normalize(Tombstones.PatientName);
        await db.DoctorPatients.Where(l => l.PatientId == patient.Id)
            .ExecuteUpdateAsync(
                set => set
                    .SetProperty(l => l.PatientName, Tombstones.PatientName)
                    .SetProperty(l => l.PatientPhone, phone)
                    .SetProperty(l => l.SearchName, search)
                    .SetProperty(l => l.UpdatedAt, now),
                cancellationToken);
    }

    private async Task EraseDoctorAsync(User user, List<StoragePath> files, CancellationToken cancellationToken)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var doctor = await db.Doctors.SingleOrDefaultAsync(d => d.UserId == user.Id, cancellationToken);
        if (doctor is not null)
        {
            AddFile(files, doctor.LicenseDocPath);
            AddFile(files, doctor.RxLogoPath);
            AddFile(files, doctor.RxSignaturePath);
            doctor.FullName = Tombstones.DoctorName;
            doctor.FullNameEn = Tombstones.DoctorNameEn;
            doctor.DegreesAr = null;
            doctor.DegreesEn = null;
            doctor.LicenseNumber = Tombstones.LicenseNumber;
            doctor.LicenseDocPath = "";
            doctor.RxLogoPath = null;
            doctor.RxSignaturePath = null;
            doctor.RxFooterText = null;
            // Out of every list, search and booking for good. Its invoices are all paid (BR-DEL9).
            doctor.Status = DoctorStatuses.Disabled;
            doctor.StatusReason = "accountDeleted";
            doctor.StatusChangedAt = now;
            doctor.UpdatedAt = now;
        }

        var branches = await db.Branches.Where(b => b.DoctorId == user.Id).ToListAsync(cancellationToken);
        var branchIds = branches.Select(b => b.Id).ToList();
        foreach (var branch in branches)
        {
            branch.AddressDetails = Tombstones.Address;
            branch.Landmark = null;
            branch.MapUrl = null;
            branch.Email = null;
            branch.Description = null;
            branch.ClosedMessage = null;
            branch.Status = "archived";
            branch.UpdatedAt = now;
        }

        var photos = await db.BranchPhotos.AsNoTracking()
            .Where(p => branchIds.Contains(p.BranchId))
            .Select(p => new { p.Id, p.BranchId, p.Path })
            .ToListAsync(cancellationToken);
        foreach (var photo in photos)
        {
            AddFile(files, photo.Path);
            files.Add(StoragePath.BranchPhotoThumbnail(user.Id, photo.BranchId, photo.Id));
        }

        await db.BranchPhotos.Where(p => branchIds.Contains(p.BranchId)).ExecuteDeleteAsync(cancellationToken);
        await db.BranchPhones.Where(p => branchIds.Contains(p.BranchId)).ExecuteDeleteAsync(cancellationToken);

        var uploads = await db.PendingUploads.AsNoTracking()
            .Where(u => u.DoctorId == user.Id)
            .Select(u => new { u.Path, u.ThumbPath })
            .ToListAsync(cancellationToken);
        foreach (var upload in uploads)
        {
            AddFile(files, upload.Path);
            AddFile(files, upload.ThumbPath);
        }

        await db.PendingUploads.Where(u => u.DoctorId == user.Id).ExecuteDeleteAsync(cancellationToken);

        // The clinic's assistants go with it (BR-DEL4), and a deletion one of them started is complete too.
        var assistantIds = await db.Assistants.Where(a => a.DoctorId == user.Id).Select(a => a.UserId).ToListAsync(cancellationToken);
        foreach (var assistantId in assistantIds)
        {
            var assistantUser = await db.Users.SingleAsync(u => u.Id == assistantId, cancellationToken);
            if (assistantUser.Status == AccountStatuses.Deleted)
            {
                continue;
            }

            await EraseAssistantAsync(assistantUser, cancellationToken);
            await EraseUserAsync(assistantUser, cancellationToken);
            await db.DeletionRequests
                .Where(r => r.UserId == assistantId && DeletionStatuses.Open.Contains(r.Status))
                .ExecuteUpdateAsync(
                    set => set.SetProperty(r => r.Status, DeletionStatuses.Completed).SetProperty(r => r.CompletedAt, (DateTime?)now),
                    cancellationToken);
        }
    }

    private async Task EraseAssistantAsync(User user, CancellationToken cancellationToken)
    {
        var assistant = await db.Assistants.SingleOrDefaultAsync(a => a.UserId == user.Id, cancellationToken);
        if (assistant is null)
        {
            return;
        }

        var now = time.GetUtcNow().UtcDateTime;
        assistant.FullName = Tombstones.AssistantName;
        assistant.Phone = Tombstones.Phone();
        assistant.Status = AssistantStatuses.Removed;
        assistant.RemovedAt ??= now;
        assistant.UpdatedAt = now;
    }

    private static void AddFile(List<StoragePath> files, string? stored)
    {
        if (StoragePath.TryParse(stored, out var path))
        {
            files.Add(path);
        }
    }
}
