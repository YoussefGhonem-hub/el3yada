using El3yada.Api.Audit;
using El3yada.Api.Billing;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Paging;
using PagedResultOf = El3yada.Api.Infrastructure.Paging;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.AccountDeletion;

/// <summary>
/// Account deletion for every role (spec 6.17, BR-DEL1 to BR-DEL12): starting it (the user, or an admin for a support
/// case), restoring it during the grace period (the user, or an admin who cancels it), and AD12's list. The erasure
/// itself is the daily job's (<see cref="AccountDeletionJob"/>, <see cref="AccountErasure"/>).
/// <para>
/// Starting a deletion disables the account at once (Users.Status <c>pendingDeletion</c>), signs out every device and
/// removes the push devices, then does what the role needs: a patient's future bookings are cancelled (BR-AP18); a
/// doctor's clinic stops (final invoice, every future booking cancelled, assistants signed out, admins told); an
/// assistant's doctor is told. Restoring undoes what can be undone; cancelled bookings stay cancelled.
/// </para>
/// </summary>
public sealed class AccountDeletionService(
    AppDbContext db,
    SessionService sessions,
    AccountStateCache stateCache,
    BillingService billing,
    INotificationWriter notifications,
    NotificationRecipients recipients,
    BoardPublisher boards,
    Auditor auditor,
    TimeProvider time,
    ILogger<AccountDeletionService> logger)
{
    /// <summary>Appointments.CancelReason of a booking cancelled by an account deletion.</summary>
    public const string CancelReason = "accountDeleted";

    private DateTime Now => time.GetUtcNow().UtcDateTime;

    // ---- The account's own view (P14, D24, AS12, AD18, A16) ------------------------------------------------------

    /// <summary><c>getAccountDeletion</c>: what deleting the account does now, or the deletion in progress.</summary>
    public async Task<AccountDeletionStateView> GetStateAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await db.Users.AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => new { u.Role, u.AdminRole, u.Status })
            .SingleAsync(cancellationToken);
        var grace = await GraceDaysAsync(cancellationToken);
        var pending = await PendingDeletionView.LoadAsync(db, userId, user.Role, cancellationToken);

        IReadOnlyList<UnpaidInvoiceView> unpaid = [];
        FinalInvoicePreview? final = null;
        if (user.Role == Roles.Doctor)
        {
            unpaid = await UnpaidInvoicesAsync(userId, cancellationToken);
            if (pending is null && unpaid.Count == 0)
            {
                final = Preview(await billing.PlanFinalInvoicesAsync(userId, cancellationToken));
            }
        }

        string? refusal = pending is not null
            ? ErrorCodes.AccountDeletionScheduled
            : unpaid.Count > 0
                ? ErrorCodes.UnpaidInvoices
                : user is { Role: Roles.Admin, AdminRole: AdminRoles.SuperAdmin, Status: AccountStatuses.Active }
                  && !await db.Users.AnyAsync(
                      u => u.Id != userId && u.Role == Roles.Admin && u.AdminRole == AdminRoles.SuperAdmin && u.Status == AccountStatuses.Active,
                      cancellationToken)
                    ? ErrorCodes.LastSuperAdmin
                    : null;
        return new AccountDeletionStateView(user.Role, grace, Now.AddDays(grace), pending, unpaid, final, refusal);
    }

    // ---- Start (BR-DEL1, BR-DEL2, BR-DEL5, BR-DEL7, BR-DEL8) ------------------------------------------------------

    /// <summary>
    /// Starts deleting <paramref name="userId"/>'s account, by the user themself or by an admin (<paramref name="requestedBy"/>).
    /// Throws 409 <c>ACCOUNT_DELETION_SCHEDULED</c> when a deletion is already in progress, <c>ACCOUNT_DELETED</c> for an
    /// erased account, <c>LAST_SUPER_ADMIN</c> for the last active super admin, and <c>UNPAID_INVOICES</c> (with
    /// <c>details.invoices</c>) for a doctor who still owes an invoice.
    /// </summary>
    public async Task<AccountDeletionStartedView> StartAsync(
        Guid userId, Guid requestedBy, string? reason, CancellationToken cancellationToken)
    {
        var role = await db.Users.AsNoTracking().Where(u => u.Id == userId).Select(u => u.Role).SingleOrDefaultAsync(cancellationToken)
            ?? throw ApiException.NotFound();
        var byAdmin = requestedBy != userId;

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        // The same lock order as AD14's admin changes (super admins first), so two deletions can't remove the last one.
        var superAdmins = role == Roles.Admin ? await LockActiveSuperAdminsAsync(cancellationToken) : [];
        var user = await LockUserAsync(userId, cancellationToken) ?? throw ApiException.NotFound();
        if (user.Status == AccountStatuses.Deleted)
        {
            throw ApiException.Conflict(ErrorCodes.AccountDeleted);
        }

        if (user.Status == AccountStatuses.PendingDeletion
            || await db.DeletionRequests.AnyAsync(r => r.UserId == userId && DeletionStatuses.Open.Contains(r.Status), cancellationToken))
        {
            throw ApiException.Conflict(ErrorCodes.AccountDeletionScheduled);
        }

        if (user is { Role: Roles.Admin, AdminRole: AdminRoles.SuperAdmin, Status: AccountStatuses.Active }
            && !superAdmins.Any(id => id != user.Id))
        {
            throw ApiException.Conflict(ErrorCodes.LastSuperAdmin);
        }

        var now = Now;
        var grace = await GraceDaysAsync(cancellationToken);
        var request = new DeletionRequest
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Role = user.Role,
            Reason = Validation.Text.TrimToNull(reason),
            Status = DeletionStatuses.Scheduled,
            RequestedBy = requestedBy,
            RequestedAt = now,
            ScheduledFor = now.AddDays(grace),
        };

        var boardDays = new List<(Guid BranchId, DateOnly Date)>();
        var signOut = new List<Guid> { userId };
        var cancelled = 0;
        FinalInvoicePreview? final = null;
        Guid? doctorOfAssistant = null;
        switch (user.Role)
        {
            case Roles.Patient:
            {
                var patientId = await db.Patients.Where(p => p.UserId == userId).Select(p => (Guid?)p.Id).SingleOrDefaultAsync(cancellationToken)
                    ?? throw ApiException.NotFound();
                request.PatientId = patientId;
                cancelled = await CancelPatientBookingsAsync(user, patientId, byAdmin, boardDays, cancellationToken);
                break;
            }

            case Roles.Doctor:
            {
                await ClinicLocks.LockDoctorAsync(db, userId, cancellationToken);
                var unpaid = await UnpaidInvoicesAsync(userId, cancellationToken);
                if (unpaid.Count > 0)
                {
                    throw new ApiException(StatusCodes.Status409Conflict, ErrorCodes.UnpaidInvoices) { Details = new { invoices = unpaid } };
                }

                request.DoctorId = userId;
                var issued = await billing.IssueFinalInvoicesAsync(userId, cancellationToken);
                request.FinalInvoiceId = issued.FirstOrDefault(i => i.IsFinal)?.Id;
                final = issued.Count == 0 ? null : new FinalInvoicePreview(
                    issued.Sum(i => i.TotalDuePiasters),
                    issued.Select(i => new FinalInvoiceLine(i.MonthKey, i.PeriodStart, i.PeriodEnd, i.DueDate, i.TotalDuePiasters, i.IsFinal)).ToList());
                cancelled = await CancelDoctorBookingsAsync(userId, boardDays, cancellationToken);
                // The clinic stops: its assistants are signed out, and CLINIC_NOT_ACTIVE keeps them out (BR-AS9, A10).
                signOut.AddRange(await db.Assistants.AsNoTracking()
                    .Where(a => a.DoctorId == userId && a.Status != AssistantStatuses.Removed)
                    .Select(a => a.UserId)
                    .ToListAsync(cancellationToken));
                var doctorName = await db.Doctors.Where(d => d.UserId == userId).Select(d => d.FullName).SingleAsync(cancellationToken);
                await notifications.AddForAdminsAsync(
                    NotificationTemplates.DoctorDeletionRequested(doctorName, userId, request.ScheduledFor, request.Id), cancellationToken);
                break;
            }

            case Roles.Assistant:
            {
                var assistant = await db.Assistants.AsNoTracking()
                    .Where(a => a.UserId == userId)
                    .Select(a => new { a.DoctorId, a.FullName, a.Status })
                    .SingleOrDefaultAsync(cancellationToken) ?? throw ApiException.NotFound();
                request.AssistantId = userId;
                doctorOfAssistant = assistant.DoctorId;
                if (assistant.Status != AssistantStatuses.Removed)
                {
                    notifications.Add(assistant.DoctorId, NotificationTemplates.AssistantDeletionRequested(assistant.FullName, userId));
                }

                break;
            }
        }

        db.DeletionRequests.Add(request);
        user.Status = AccountStatuses.PendingDeletion;
        // Every access token of the account stops working at its next request (SESSION_REVOKED).
        user.SecurityStamp = Guid.NewGuid();
        user.UpdatedAt = now;
        auditor.Add(
            byAdmin ? AuditActions.AccountDeletionScheduledByAdmin : AuditActions.AccountDeletionRequested,
            AuditTargets.User, userId,
            new
            {
                requestId = request.Id, role = user.Role, scheduledFor = request.ScheduledFor, reason = request.Reason,
                cancelledBookings = cancelled, finalInvoiceId = request.FinalInvoiceId, finalInvoicePiasters = final?.AmountPiasters,
            },
            doctorId: request.DoctorId ?? doctorOfAssistant,
            patientId: request.PatientId);
        await db.SaveChangesAsync(cancellationToken);

        foreach (var id in signOut)
        {
            await sessions.RevokeAllAsync(id, cancellationToken);
            await db.UserDevices.Where(d => d.UserId == id).ExecuteDeleteAsync(cancellationToken);
        }

        await transaction.CommitAsync(cancellationToken);
        foreach (var id in signOut)
        {
            stateCache.Invalidate(id);
        }

        foreach (var (branchId, date) in boardDays.Distinct())
        {
            await boards.PublishAsync(branchId, date, cancellationToken);
        }

        logger.LogInformation(
            "Account {UserId} ({Role}) scheduled for deletion on {ScheduledFor}", userId, user.Role, request.ScheduledFor);
        return new AccountDeletionStartedView(request.Id, request.Status, request.RequestedAt, request.ScheduledFor, cancelled, final);
    }

    // ---- Restore (BR-DEL11) -------------------------------------------------------------------------------------

    /// <summary><c>restoreAccount</c>: the signed-in user ends their own deletion. 409 <c>ACCOUNT_NOT_PENDING_DELETION</c>.</summary>
    public async Task RestoreAsync(Guid userId, CancellationToken cancellationToken)
    {
        var requestId = await db.DeletionRequests.AsNoTracking()
            .Where(r => r.UserId == userId && DeletionStatuses.Open.Contains(r.Status))
            .OrderByDescending(r => r.RequestedAt)
            .Select(r => (Guid?)r.Id)
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw ApiException.Conflict(ErrorCodes.AccountNotPendingDeletion);
        await RestoreCoreAsync(requestId, userId, null, cancellationToken);
    }

    /// <summary><c>adminCancelAccountDeletion</c>: an admin cancels a deletion and restores the account, with a reason.</summary>
    public async Task<AccountDeletionItem> AdminCancelAsync(Guid requestId, Guid adminId, bool callerIsSuperAdmin, string reason, CancellationToken cancellationToken)
    {
        var role = await db.DeletionRequests.AsNoTracking().Where(r => r.Id == requestId).Select(r => r.Role).SingleOrDefaultAsync(cancellationToken)
            ?? throw ApiException.NotFound();
        if (role == Roles.Admin && !callerIsSuperAdmin)
        {
            throw ApiException.Forbidden();
        }

        await RestoreCoreAsync(requestId, adminId, Validation.Text.TrimToNull(reason), cancellationToken);
        return (await ListAsync(new AccountDeletionsQuery(), cancellationToken, requestId)).Items.Single();
    }

    private async Task RestoreCoreAsync(Guid requestId, Guid restoredBy, string? reason, CancellationToken cancellationToken)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var request = await db.DeletionRequests
            .FromSqlInterpolated($"SELECT * FROM [DeletionRequests] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {requestId}")
            .SingleOrDefaultAsync(cancellationToken) ?? throw ApiException.NotFound();
        if (!DeletionStatuses.IsOpen(request.Status))
        {
            throw ApiException.Conflict(ErrorCodes.AccountNotPendingDeletion);
        }

        var user = await LockUserAsync(request.UserId, cancellationToken) ?? throw ApiException.NotFound();
        var now = Now;
        var byAdmin = restoredBy != request.UserId;
        request.Status = DeletionStatuses.Restored;
        request.RestoredAt = now;
        request.RestoredBy = restoredBy;
        request.RestoreReason = reason;
        if (user.Status == AccountStatuses.PendingDeletion)
        {
            user.Status = AccountStatuses.Active;
            user.UpdatedAt = now;
        }

        var reopened = new List<Guid> { user.Id };
        var finalRemoved = false;
        Guid? doctorOfAssistant = null;
        if (request.Role == Roles.Doctor)
        {
            await ClinicLocks.LockDoctorAsync(db, request.UserId, cancellationToken);
            if (request.FinalInvoiceId is { } finalId)
            {
                finalRemoved = await billing.RemoveFinalInvoiceIfUnpaidAsync(finalId, cancellationToken);
            }

            // Assistants come back with the clinic: they were never disabled, only shut out by CLINIC_NOT_ACTIVE.
            reopened.AddRange(await db.Assistants.AsNoTracking()
                .Where(a => a.DoctorId == request.UserId)
                .Select(a => a.UserId)
                .ToListAsync(cancellationToken));
        }
        else if (request.Role == Roles.Assistant)
        {
            doctorOfAssistant = await db.Assistants.Where(a => a.UserId == request.UserId).Select(a => (Guid?)a.DoctorId).SingleOrDefaultAsync(cancellationToken);
        }

        auditor.Add(
            byAdmin ? AuditActions.AccountDeletionCancelled : AuditActions.AccountRestored,
            AuditTargets.User, request.UserId,
            new { requestId = request.Id, role = request.Role, reason, finalInvoiceRemoved = finalRemoved },
            doctorId: request.DoctorId ?? doctorOfAssistant,
            patientId: request.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        foreach (var id in reopened)
        {
            stateCache.Invalidate(id);
        }

        logger.LogInformation("Account {UserId} restored ({By})", request.UserId, byAdmin ? "admin" : "user");
    }

    // ---- AD12 -----------------------------------------------------------------------------------------------

    /// <summary><c>getAccountDeletions</c>: every deletion, newest first, filtered by role, status and account.</summary>
    public Task<PagedResultOf.PagedResult<AccountDeletionItem>> ListAsync(AccountDeletionsQuery query, CancellationToken cancellationToken) =>
        ListAsync(query, cancellationToken, null);

    private Task<PagedResultOf.PagedResult<AccountDeletionItem>> ListAsync(
        AccountDeletionsQuery query, CancellationToken cancellationToken, Guid? requestId)
    {
        var rows = db.DeletionRequests.AsNoTracking();
        if (requestId is { } id)
        {
            rows = rows.Where(r => r.Id == id);
        }

        if (query.Role != "all")
        {
            rows = rows.Where(r => r.Role == query.Role);
        }

        if (query.Status == "open")
        {
            rows = rows.Where(r => DeletionStatuses.Open.Contains(r.Status));
        }
        else if (query.Status != "all")
        {
            rows = rows.Where(r => r.Status == query.Status);
        }

        if (query.UserId is { } userId)
        {
            rows = rows.Where(r => r.UserId == userId);
        }

        return rows
            .OrderByDescending(r => r.RequestedAt).ThenBy(r => r.Id)
            .Select(r => new AccountDeletionItem(
                r.Id, r.UserId, r.Role, r.User.DisplayName,
                r.User.Phone,
                r.User.Status == AccountStatuses.Deleted ? null : r.User.Email,
                r.Status, r.Reason, r.RequestedAt, r.RequestedBy != r.UserId,
                r.RequestedByNavigation.DisplayName,
                r.ScheduledFor, r.RestoredAt,
                r.RestoredByNavigation == null ? null : r.RestoredByNavigation.DisplayName,
                r.RestoreReason, r.CompletedAt, r.PatientId, r.DoctorId, r.AssistantId,
                r.Role == Roles.Doctor ? db.Invoices.Count(i => i.DoctorId == r.UserId && InvoiceStatuses.Outstanding.Contains(i.Status)) : 0,
                r.Role == Roles.Doctor
                    ? db.Invoices.Where(i => i.DoctorId == r.UserId && InvoiceStatuses.Outstanding.Contains(i.Status)).Sum(i => (int?)i.TotalDuePiasters) ?? 0
                    : 0))
            .ToPagedAsync(query, cancellationToken);
    }

    // ---- Helpers --------------------------------------------------------------------------------------------

    private Task<int> GraceDaysAsync(CancellationToken cancellationToken) =>
        db.AppSettings.AsNoTracking().Select(s => s.AccountDeletionGraceDays).SingleAsync(cancellationToken);

    private Task<List<UnpaidInvoiceView>> UnpaidInvoicesAsync(Guid doctorId, CancellationToken cancellationToken) =>
        db.Invoices.AsNoTracking()
            .Where(i => i.DoctorId == doctorId && InvoiceStatuses.Outstanding.Contains(i.Status))
            .OrderBy(i => i.MonthKey)
            .Select(i => new UnpaidInvoiceView(i.Id, i.MonthKey, i.TotalDuePiasters, i.Status, i.DueDate))
            .ToListAsync(cancellationToken);

    private static FinalInvoicePreview? Preview(List<PlannedInvoice> plans) => plans.Count == 0
        ? null
        : new FinalInvoicePreview(
            plans.Sum(p => p.TotalPiasters),
            plans.Select(p => new FinalInvoiceLine(p.MonthKey, p.PeriodStart, p.PeriodEnd, p.DueDate, p.TotalPiasters, p.IsFinal)).ToList());

    private Task<User?> LockUserAsync(Guid userId, CancellationToken cancellationToken) =>
        db.Users.FromSqlInterpolated($"SELECT * FROM [Users] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {userId}")
            .SingleOrDefaultAsync(cancellationToken);

    /// <summary>Locks every active super admin row for the transaction (as AD14 does) and returns their IDs.</summary>
    private Task<List<Guid>> LockActiveSuperAdminsAsync(CancellationToken cancellationToken) =>
        db.Database.SqlQuery<Guid>($"""
            SELECT [Id] AS [Value] FROM [Users] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Role] = 'admin' AND [AdminRole] = 'superAdmin' AND [Status] = 'active'
            """).ToListAsync(cancellationToken);

    /// <summary>
    /// BR-AP18, spec case 24: the patient's bookings that have not started are cancelled, and the clinic staff get the
    /// usual cancellation activity. Returns how many.
    /// </summary>
    private async Task<int> CancelPatientBookingsAsync(
        User user, Guid patientId, bool byAdmin, List<(Guid BranchId, DateOnly Date)> boardDays, CancellationToken cancellationToken)
    {
        var now = Now;
        var today = CairoTime.Today(time);
        var bookings = await db.Appointments
            .Where(a => a.PatientId == patientId && a.LocalDate >= today
                && (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed))
            .ToListAsync(cancellationToken);
        foreach (var a in bookings)
        {
            Cancel(a, byAdmin ? "system" : Roles.Patient, byAdmin ? null : user.Id, now);
            boardDays.Add((a.BranchId, a.LocalDate));

            var doctorWants = await db.Users.Where(u => u.Id == a.DoctorId).Select(u => u.NotifyBookings).FirstAsync(cancellationToken);
            var staff = await recipients.StaffAsync(a.DoctorId, StaffPermission.AppointmentsView, a.BranchId, includeDoctor: doctorWants, cancellationToken);
            var name = await db.DoctorPatients
                .Where(l => l.DoctorId == a.DoctorId && l.PatientId == patientId)
                .Select(l => l.PatientName)
                .FirstOrDefaultAsync(cancellationToken) ?? user.DisplayName;
            var when = AppointmentTexts.When(a);
            foreach (var staffId in staff)
            {
                notifications.Add(staffId, NotificationTemplates.StaffBookingActivity(
                    "إلغاء حجز", "Booking cancelled", $"{name} — {when.Ar}", $"{name}: {when.En}", a.Id));
            }
        }

        return bookings.Count;
    }

    /// <summary>
    /// The doctor's clinic stops (BR-DEL5): every booking that has not started is cancelled by the system and its patient
    /// told «تم إلغاء موعدك لأن العيادة أوقفت الخدمة». Returns how many.
    /// </summary>
    private async Task<int> CancelDoctorBookingsAsync(Guid doctorId, List<(Guid BranchId, DateOnly Date)> boardDays, CancellationToken cancellationToken)
    {
        var now = Now;
        var today = CairoTime.Today(time);
        var bookings = await db.Appointments
            .Where(a => a.DoctorId == doctorId && a.LocalDate >= today
                && (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed))
            .Select(a => new { Appointment = a, PatientUserId = a.Patient == null ? (Guid?)null : a.Patient.UserId })
            .ToListAsync(cancellationToken);
        foreach (var row in bookings)
        {
            Cancel(row.Appointment, "system", null, now);
            boardDays.Add((row.Appointment.BranchId, row.Appointment.LocalDate));
            if (row.PatientUserId is { } patientUserId)
            {
                notifications.Add(patientUserId, NotificationTemplates.BookingCancelledClinicClosed(row.Appointment.Id));
            }
        }

        return bookings.Count;
    }

    private void Cancel(Appointment a, string byRole, Guid? byUserId, DateTime now)
    {
        a.Status = AppointmentStatuses.Cancelled;
        a.CancelledAt = now;
        a.CancelledByRole = byRole;
        a.CancelReason = CancelReason;
        a.UpdatedAt = now;
        db.AppointmentHistories.Add(new AppointmentHistory
        {
            Id = Guid.NewGuid(), AppointmentId = a.Id, At = now, ByUserId = byUserId, ByRole = byRole, Action = "cancelled", Reason = CancelReason,
        });
    }
}
