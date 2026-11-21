using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Time;
using El3yada.Api.Infrastructure.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// The live board and the day's actions (spec 6.13, D34, AS1, AS16). Each action is one API call
/// that updates SQL Server and then the mirror (BR-LB1). The first action on a card wins; the
/// second gets <c>ALREADY_HANDLED</c> with who acted (BR-LB4).
/// </summary>
public sealed class BoardActionsService(
    AppDbContext db,
    AppointmentService appointments,
    BoardPublisher publisher,
    INotificationWriter notifications,
    TimeProvider clock)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;
    private DateOnly Today => CairoTime.Today(clock);

    public async Task<BoardSnapshot> GetBoardAsync(BookingActor actor, Guid branchId, DateOnly? date, CancellationToken ct)
    {
        actor.Staff!.Require(StaffPermission.AppointmentsView).RequireBranch(branchId);
        return await publisher.BuildAsync(branchId, date ?? Today, ct);
    }

    // ---- Stage changes ------------------------------------------------------------------------

    /// <summary>
    /// Patient arrived (BR-AP10). Check-in works only today (6.13). In queue mode the patient gets the period's
    /// next number, so turns go in order of arrival (BR-AP3), and is told the number, how many are ahead and the
    /// estimated wait (BR-AP16). A guest whose phone belongs to one of the doctor's patients is linked
    /// automatically (6.12.3).
    /// </summary>
    public Task<AppointmentDto> CheckInAsync(BookingActor actor, Guid id, CancellationToken ct) =>
        ArriveAsync(actor, id, [AppointmentStatuses.Confirmed, AppointmentStatuses.Pending], "checkedIn", async a =>
        {
            if (a.PatientId is null && a.GuestPhone is not null)
            {
                var match = await db.DoctorPatients.Where(l => l.DoctorId == a.DoctorId && l.PatientPhone == a.GuestPhone)
                    .Select(l => (Guid?)l.PatientId).FirstOrDefaultAsync(ct);
                if (match is { } pid) ConvertGuest(a, pid);
            }
        }, ct);

    /// <summary>Into the doctor. [S] The next checked-in patient of the period hears «دورك التالي» (BR-AP16).</summary>
    public Task<AppointmentDto> CallInAsync(BookingActor actor, Guid id, CancellationToken ct) =>
        TransitionAsync(actor, id, [AppointmentStatuses.CheckedIn], "calledIn", async a =>
        {
            a.Status = AppointmentStatuses.WithDoctor;
            a.CalledAt = Now;
            if (a.QueueNumber is { } n)
            {
                await SetNowServingAsync(a.BranchId, a.LocalDate, a.PeriodStartLocal, n, ct);
                await NotifyNextInLineAsync(a, ct);
            }
        }, ct);

    public Task<AppointmentDto> SendBackAsync(BookingActor actor, Guid id, CancellationToken ct) =>
        TransitionAsync(actor, id, [AppointmentStatuses.WithDoctor], "sentBack", a =>
        {
            a.Status = AppointmentStatuses.CheckedIn;
            return Task.CompletedTask;
        }, ct);

    /// <summary>BR-AP3 [S]: move a waiting patient up (emergency, elderly), with a reason.</summary>
    public Task<AppointmentDto> MovePriorityAsync(BookingActor actor, Guid id, string? reason, CancellationToken ct) =>
        TransitionAsync(actor, id, [AppointmentStatuses.CheckedIn, AppointmentStatuses.Confirmed], "priority", async a =>
        {
            if (string.IsNullOrWhiteSpace(reason)) throw ApiException.BadRequest(ErrorCodes.ValidationFailed);
            var first = await db.Appointments.Where(x => x.BranchId == a.BranchId && x.LocalDate == a.LocalDate).MinAsync(x => x.BoardOrder, ct);
            a.IsPriority = true;
            a.PriorityReason = reason.Trim();
            a.BoardOrder = first - 1;
        }, ct, reason);

    public Task<AppointmentDto> MarkNoShowAsync(BookingActor actor, Guid id, CancellationToken ct) =>
        TransitionAsync(actor, id, [AppointmentStatuses.Confirmed], "noShow", a =>
        {
            a.Status = AppointmentStatuses.NoShow;
            a.NoShowAt = Now;
            return Task.CompletedTask;
        }, ct);

    /// <summary>BR-AP8: undo a no-show the same day; the patient is checked in again, with a new number in queue mode (BR-AP3).</summary>
    public Task<AppointmentDto> UndoNoShowAsync(BookingActor actor, Guid id, CancellationToken ct) =>
        ArriveAsync(actor, id, [AppointmentStatuses.NoShow], "noShowUndone", a =>
        {
            a.NoShowAt = null;
            return Task.CompletedTask;
        }, ct);

    /// <summary>Case 20 / BR-AP11: checked in, but left before being seen. Costs nothing (BR-AP23).</summary>
    public Task<AppointmentDto> MarkLeftWithoutSeenAsync(BookingActor actor, Guid id, string? reason, CancellationToken ct) =>
        TransitionAsync(actor, id, [AppointmentStatuses.CheckedIn, AppointmentStatuses.WithDoctor], "leftWithoutSeen", a =>
        {
            a.Status = AppointmentStatuses.Cancelled;
            a.CancelledAt = Now;
            a.CancelledByRole = "clinic";
            a.CancelReason = string.IsNullOrWhiteSpace(reason) ? "leftWithoutSeen" : reason.Trim();
            a.FlaggedNoSession = false;
            return Task.CompletedTask;
        }, ct, reason);

    /// <summary>At check-in, staff link a guest to a patient created in D5 or found by phone (6.12.3).</summary>
    public Task<AppointmentDto> ConvertGuestAsync(BookingActor actor, Guid id, Guid patientId, CancellationToken ct) =>
        TransitionAsync(actor, id, AppointmentStatuses.Holding, "guestConverted", async a =>
        {
            if (a.PatientId is not null) throw ApiException.Conflict(ErrorCodes.InvalidTransition);
            if (!await db.DoctorPatients.AnyAsync(l => l.DoctorId == a.DoctorId && l.PatientId == patientId, ct))
                throw ApiException.Conflict(ErrorCodes.GuestNeedsAccount);
            ConvertGuest(a, patientId);
        }, ct);

    private static void ConvertGuest(Appointment a, Guid patientId)
    {
        a.PatientId = patientId;
        a.GuestName = null;
        a.GuestPhone = null;
    }

    // ---- Walk-in (case 4) -----------------------------------------------------------------------

    public async Task<AppointmentDto> AddWalkInAsync(BookingActor actor, WalkInRequest r, CancellationToken ct)
    {
        var staff = actor.Staff!.Require(StaffPermission.AppointmentsManage).RequireBranch(r.BranchId).RequireNotSuspended();
        var branch = await db.Branches.AsNoTracking().FirstOrDefaultAsync(b => b.Id == r.BranchId && b.DoctorId == staff.DoctorId, ct)
            ?? throw ApiException.NotFound();

        DoctorPatient? link = null;
        if (r.PatientId is { } pid)
            link = await db.DoctorPatients.FirstOrDefaultAsync(l => l.DoctorId == staff.DoctorId && l.PatientId == pid, ct)
                   ?? throw ApiException.NotFound(ErrorCodes.NotLinked);
        string? guestPhone = null;
        if (r.Guest is not null && !EgyptianPhone.TryNormalize(r.Guest.Phone, out guestPhone)) throw ApiException.BadRequest(ErrorCodes.ValidationFailed);
        await appointments.EnsureVisitTypeAllowedAsync(link, r.VisitType, ct);

        var today = Today;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await appointments.LockDayAsync(r.BranchId, today, ct);

        // The current period (or the next one today, or the last one) gets the next number.
        var schedule = await new ScheduleLoader(db).LoadAsync(r.BranchId, today, today, ct);
        var day = schedule.Day(new AvailabilityRequest(today, r.VisitType, false, Now));
        var nowLocal = TimeOnly.FromDateTime(CairoTime.Now(clock));
        var period = day.Periods.FirstOrDefault(p => p.Start <= nowLocal && (p.EndsNextDay || p.End > nowLocal))
                     ?? day.Periods.FirstOrDefault(p => p.Start > nowLocal)
                     ?? day.Periods.LastOrDefault();

        var isQueue = schedule.Settings.IsQueue;
        // A day without hours still keeps one line for its walk-ins.
        var periodStart = period?.Start ?? (isQueue ? TimeOnly.MinValue : nowLocal);
        var walkIn = new Appointment
        {
            Id = NewId.Next(),
            DoctorId = staff.DoctorId,
            BranchId = r.BranchId,
            PatientId = r.PatientId,
            GuestName = r.Guest?.Name.Trim(),
            GuestPhone = guestPhone,
            VisitType = r.VisitType,
            Mode = schedule.Settings.Mode,
            LocalDate = today,
            PeriodStartLocal = periodStart,
            StartUtc = isQueue && period is not null ? period.StartUtc : Now,
            EndUtc = isQueue ? period?.EndUtc : Now.AddMinutes(schedule.Settings.SlotMinutes),
            // Checked in at once: the period's next number, the same way as a check-in (BR-AP3).
            QueueNumber = isQueue ? await QueueNumbers.TakeAsync(db, r.BranchId, today, periodStart, Now, ct) : null,
            Status = AppointmentStatuses.CheckedIn,
            CheckedInAt = Now,
            Source = "walkIn",
            BookedBy = staff.UserId,
            BookedByRole = staff.Role,
            StaffNotes = string.IsNullOrWhiteSpace(r.StaffNotes) ? null : r.StaffNotes.Trim(),
            // A walk-in never takes a timed slot from someone who booked it.
            Overbooked = !isQueue,
            CreatedAt = Now,
            UpdatedAt = Now,
        };
        walkIn.BoardOrder = walkIn.QueueNumber ?? (int)nowLocal.ToTimeSpan().TotalMinutes;
        db.Appointments.Add(walkIn);
        appointments.AddHistory(walkIn, actor, "walkIn", null, null, null);
        await NotifyCheckedInAsync(walkIn, ct);
        await appointments.SaveBookingAsync(ct);
        await tx.CommitAsync(ct);
        await publisher.PublishAsync(r.BranchId, today, ct);
        return await appointments.GetAsync(actor, walkIn.Id, ct);
    }

    // ---- Same-day problems (BR-AP14, BR-AP15) ---------------------------------------------------

    /// <summary>"Cancel the rest of today": every booking not yet arrived is cancelled; patients get a rebook link.</summary>
    public async Task<int> CancelRestOfDayAsync(BookingActor actor, BranchDayRequest r, CancellationToken ct)
    {
        actor.Staff!.Require(StaffPermission.AppointmentsManage).RequireBranch(r.BranchId);
        var today = Today;
        var list = await db.Appointments
            .Where(a => a.BranchId == r.BranchId && a.DoctorId == actor.Staff.DoctorId && a.LocalDate == today
                        && (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed))
            .ToListAsync(ct);
        foreach (var a in list)
        {
            a.Status = AppointmentStatuses.Cancelled;
            a.CancelledAt = Now;
            a.CancelledByRole = "clinic";
            a.CancelReason = string.IsNullOrWhiteSpace(r.Reason) ? null : r.Reason.Trim();
            a.UpdatedAt = Now;
            appointments.AddHistory(a, actor, "cancelledRestOfDay", null, null, a.CancelReason);
            if (a.PatientId is { } pid)
                notifications.Add(await appointments.PatientUserIdAsync(pid, ct), NotificationTemplates.BookingCancelledByClinic(a.CancelReason, a.Id));
        }
        await appointments.SaveBookingAsync(ct);
        await publisher.PublishAsync(r.BranchId, today, ct);
        return list.Count;
    }

    /// <summary>[S] "Doctor delayed": today's remaining patients at the branch are told (BR-AP14).</summary>
    public async Task<int> SendDelayNoticeAsync(BookingActor actor, DelayRequest r, CancellationToken ct)
    {
        actor.Staff!.Require(StaffPermission.AppointmentsManage).RequireBranch(r.BranchId);
        var today = Today;
        var remaining = await db.Appointments.AsNoTracking()
            .Where(a => a.BranchId == r.BranchId && a.LocalDate == today && a.PatientId != null
                        && (a.Status == AppointmentStatuses.Confirmed || a.Status == AppointmentStatuses.CheckedIn || a.Status == AppointmentStatuses.Pending))
            .Select(a => new { a.PatientId, a.PeriodStartLocal })
            .ToListAsync(ct);

        foreach (var period in remaining.Select(x => x.PeriodStartLocal).Distinct())
        {
            var state = await DayStateAsync(r.BranchId, today, period, ct);
            state.DelayMinutes = r.Minutes;
            state.DelayNoticeSentAt = Now;
            state.UpdatedAt = Now;
        }
        foreach (var pid in remaining.Select(x => x.PatientId!.Value).Distinct())
            notifications.Add(await appointments.PatientUserIdAsync(pid, ct), NotificationTemplates.DoctorDelayed(r.Minutes));
        await db.SaveChangesAsync(ct);
        await publisher.PublishAsync(r.BranchId, today, ct);
        return remaining.Count;
    }

    /// <summary>[S] "Call next": the first waiting card is called in (BR-AP15).</summary>
    public async Task<AppointmentDto?> CallNextAsync(BookingActor actor, Guid branchId, CancellationToken ct)
    {
        actor.Staff!.Require(StaffPermission.AppointmentsManage).RequireBranch(branchId);
        var board = await publisher.BuildAsync(branchId, Today, ct);
        var next = board.Entries.FirstOrDefault(e => e.Stage == "waiting");
        return next is null ? null : await CallInAsync(actor, next.AppointmentId, ct);
    }

    /// <summary>BR-AP8: staff turn self-booking back on (or off) for one patient.</summary>
    public async Task SetSelfBookingAsync(BookingActor actor, Guid patientId, SetSelfBookingRequest r, CancellationToken ct)
    {
        actor.Staff!.Require(StaffPermission.AppointmentsManage);
        var link = await db.DoctorPatients.FirstOrDefaultAsync(l => l.DoctorId == actor.Staff.DoctorId && l.PatientId == patientId, ct)
            ?? throw ApiException.NotFound(ErrorCodes.NotLinked);
        link.SelfBookingBlocked = !r.Enabled;
        link.SelfBookingBlockedReason = r.Enabled ? null : r.Reason?.Trim();
        link.UpdatedAt = Now;
        await db.SaveChangesAsync(ct);
    }

    // ---- Session completion (BR-AP10, BR-AP23) --------------------------------------------------

    /// <summary>
    /// Called by <c>createSession</c> (Phase 2) in the same transaction as the session insert: the
    /// booking becomes <c>completed</c> and is linked to the session. A card reaches Done only this way
    /// (BR-LB3), so each completed visit is billed exactly once.
    /// </summary>
    public async Task CompleteWithSessionAsync(Guid appointmentId, Guid sessionId, Guid doctorId, CancellationToken ct)
    {
        var a = await db.Appointments.FirstOrDefaultAsync(x => x.Id == appointmentId && x.DoctorId == doctorId, ct)
            ?? throw ApiException.NotFound();
        if (a.Status == AppointmentStatuses.Completed) throw ApiException.Conflict(ErrorCodes.AlreadyHandled);
        if (a.Status is not (AppointmentStatuses.CheckedIn or AppointmentStatuses.WithDoctor)) throw ApiException.Conflict(ErrorCodes.InvalidTransition);
        a.Status = AppointmentStatuses.Completed;
        a.SessionId = sessionId;
        a.FlaggedNoSession = false;
        a.UpdatedAt = Now;
        appointments.AddHistory(a, null, "completed", null, sessionId.ToString(), null);
    }

    // ---- Side panel -----------------------------------------------------------------------------

    public async Task<BoardPatientSummaryDto> PatientSummaryAsync(BookingActor actor, Guid appointmentId, CancellationToken ct)
    {
        var staff = actor.Staff!.Require(StaffPermission.AppointmentsView);
        var a = await db.Appointments.AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == appointmentId && x.DoctorId == staff.DoctorId, ct) ?? throw ApiException.NotFound();
        staff.RequireBranch(a.BranchId);
        var max = await db.AppSettings.AsNoTracking().Select(s => s.MaxConsecutiveConsultations).FirstAsync(ct);

        if (a.PatientId is null)
        {
            return new BoardPatientSummaryDto(a.Id, a.GuestName!, true, a.GuestPhone, null, null, null, 0, 0, null, null, null, 0, 0,
                a.Reason, a.StaffNotes, null, null, null, null, a.VisitType == "examination", false);
        }

        var link = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.DoctorId == staff.DoctorId && l.PatientId == a.PatientId)
            .Select(l => new
            {
                l.Id, l.PatientName, l.PatientPhone, l.FileNumber, l.ExamCount, l.ConsultationCount, l.FirstSessionAt, l.LastSessionAt,
                l.LastSessionType, l.ConsultationsSinceExam, l.SelfBookingBlocked, l.SessionCount,
                l.Patient.Gender, l.Patient.DateOfBirth,
            })
            .FirstAsync(ct);
        var upcoming = await db.Appointments.CountAsync(x => x.DoctorId == staff.DoctorId && x.PatientId == a.PatientId
            && AppointmentStatuses.Upcoming.Contains(x.Status) && x.StartUtc > Now && x.Id != a.Id, ct);
        var noShows = await db.Appointments.CountAsync(x => x.DoctorId == staff.DoctorId && x.PatientId == a.PatientId && x.Status == AppointmentStatuses.NoShow, ct);

        IReadOnlyList<string>? allergies = null, chronic = null;
        string? lastDiagnosis = null;
        if (staff.Has(StaffPermission.ClinicalView))
        {
            var items = await db.PatientMedicalProfileItems.AsNoTracking().Where(i => i.LinkId == link.Id).Select(i => new { i.Kind, i.Text }).ToListAsync(ct);
            allergies = items.Where(i => i.Kind == "allergy").Select(i => i.Text).ToList();
            chronic = items.Where(i => i.Kind == "chronicDisease").Select(i => i.Text).ToList();
            lastDiagnosis = await db.Sessions.AsNoTracking().Where(s => s.LinkId == link.Id && !s.Deleted && s.Diagnosis != null)
                .OrderByDescending(s => s.CreatedAt).Select(s => s.Diagnosis).FirstOrDefaultAsync(ct);
        }
        IReadOnlyList<int>? amounts = null;
        if (staff.Has(StaffPermission.RevenueView))
        {
            amounts = await db.Sessions.AsNoTracking().Where(s => s.LinkId == link.Id && !s.Deleted)
                .OrderByDescending(s => s.CreatedAt).Take(3).Select(s => s.PatientFeePiasters).ToListAsync(ct);
        }

        var today = Today;
        var age = today.Year - link.DateOfBirth.Year - (today < link.DateOfBirth.AddYears(today.Year - link.DateOfBirth.Year) ? 1 : 0);
        return new BoardPatientSummaryDto(a.Id, link.PatientName, false, link.PatientPhone, link.Gender, age, link.FileNumber,
            link.ExamCount, link.ConsultationCount, link.FirstSessionAt, link.LastSessionAt, link.LastSessionType, upcoming, noShows,
            a.Reason, a.StaffNotes, allergies, chronic, lastDiagnosis, amounts,
            link.SessionCount > 0 && link.ConsultationsSinceExam < max, link.SelfBookingBlocked);
    }

    // ---- Helpers ------------------------------------------------------------------------------

    private async Task<AppointmentDto> TransitionAsync(
        BookingActor actor, Guid id, IReadOnlyCollection<string> from, string action, Func<Appointment, Task> apply,
        CancellationToken ct, string? reason = null)
    {
        var a = await appointments.LoadForActorAsync(actor, id, ct, tracking: true);
        if (!from.Contains(a.Status)) throw appointments.AlreadyHandled(a, ErrorCodes.InvalidTransition);
        var before = a.Status;
        await apply(a);
        a.UpdatedAt = Now;
        appointments.AddHistory(a, actor, action, before, a.Status, reason);
        await appointments.SaveBookingAsync(ct);
        await publisher.PublishAsync(a.BranchId, a.LocalDate, ct);
        return await appointments.GetAsync(actor, id, ct);
    }

    /// <summary>
    /// Check-in and undoing a no-show (BR-AP3, BR-AP8, BR-AP10). One transaction: in queue mode the period is
    /// locked first, then the booking is read again (the first check-in wins, BR-LB4) and gets the period's next
    /// number. Timed mode keeps its order by time.
    /// </summary>
    private async Task<AppointmentDto> ArriveAsync(
        BookingActor actor, Guid id, IReadOnlyCollection<string> from, string action, Func<Appointment, Task> apply, CancellationToken ct)
    {
        var a = await appointments.LoadForActorAsync(actor, id, ct, tracking: true);
        if (!from.Contains(a.Status)) throw appointments.AlreadyHandled(a, ErrorCodes.InvalidTransition);
        if (a.LocalDate != Today) throw ApiException.Conflict(ErrorCodes.InvalidTransition);

        var queue = a.Mode == "queue";
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        if (queue) await QueueNumbers.LockPeriodAsync(db, a.BranchId, a.LocalDate, a.PeriodStartLocal, Now, ct);
        await db.Entry(a).ReloadAsync(ct);
        if (!from.Contains(a.Status)) throw appointments.AlreadyHandled(a, ErrorCodes.InvalidTransition);

        var before = a.Status;
        a.Status = AppointmentStatuses.CheckedIn;
        a.CheckedInAt = Now;
        await apply(a);
        if (queue)
        {
            a.QueueNumber = await QueueNumbers.NextAsync(db, a.BranchId, a.LocalDate, a.PeriodStartLocal, ct);
            // A priority move made before arrival keeps its place (BR-AP3).
            if (!a.IsPriority) a.BoardOrder = a.QueueNumber.Value;
        }
        a.UpdatedAt = Now;
        appointments.AddHistory(a, actor, action, before, a.Status, null);
        await NotifyCheckedInAsync(a, ct);
        await appointments.SaveBookingAsync(ct);
        await tx.CommitAsync(ct);
        await publisher.PublishAsync(a.BranchId, a.LocalDate, ct);
        return await appointments.GetAsync(actor, id, ct);
    }

    /// <summary>
    /// BR-AP16, queue mode: «تم تسجيل حضورك — دورك رقم 7، وقبلك 3 مرضى» with the estimated wait (patients ahead ×
    /// the branch's average visit time, spec 6.12.2). It goes to the patient's app; a guest is told at the desk.
    /// </summary>
    private async Task NotifyCheckedInAsync(Appointment a, CancellationToken ct)
    {
        if (a.PatientId is not { } patientId || a.QueueNumber is not { } number) return;
        var ahead = await appointments.AheadAsync(a.Id, a.BranchId, a.LocalDate, a.PeriodStartLocal, a.IsPriority, a.BoardOrder, ct);
        var average = await db.Branches.Where(b => b.Id == a.BranchId).Select(b => b.AvgVisitMinutes).FirstAsync(ct);
        notifications.Add(await appointments.PatientUserIdAsync(patientId, ct), NotificationTemplates.CheckedIn(number, ahead, ahead * average, a.Id));
    }

    /// <summary>
    /// [S] BR-AP16: when a patient goes in, the next checked-in patient of the same period (priority first, then
    /// by number) hears «دورك التالي», once per booking.
    /// </summary>
    private async Task NotifyNextInLineAsync(Appointment calledIn, CancellationToken ct)
    {
        var next = await db.Appointments.AsNoTracking()
            .Where(x => x.BranchId == calledIn.BranchId && x.LocalDate == calledIn.LocalDate && x.PeriodStartLocal == calledIn.PeriodStartLocal
                        && x.Status == AppointmentStatuses.CheckedIn && x.Id != calledIn.Id && x.QueueNumber != null)
            .OrderByDescending(x => x.IsPriority).ThenBy(x => x.BoardOrder)
            .Select(x => new { x.Id, Number = x.QueueNumber!.Value, UserId = x.Patient == null ? (Guid?)null : x.Patient.UserId })
            .FirstOrDefaultAsync(ct);
        if (next?.UserId is not { } userId) return;
        var message = NotificationTemplates.NextInLine(next.Number, next.Id);
        if (await db.Notifications.AnyAsync(n => n.RecipientUserId == userId && n.Type == message.Type && n.Route == message.Route, ct)) return;
        notifications.Add(userId, message);
    }

    private async Task SetNowServingAsync(Guid branchId, DateOnly date, TimeOnly period, int number, CancellationToken ct)
    {
        var state = await DayStateAsync(branchId, date, period, ct);
        state.NowServingNumber = number;
        state.UpdatedAt = Now;
    }

    private async Task<BranchDayState> DayStateAsync(Guid branchId, DateOnly date, TimeOnly period, CancellationToken ct)
    {
        var state = db.BranchDayStates.Local.FirstOrDefault(s => s.BranchId == branchId && s.LocalDate == date && s.PeriodStartLocal == period)
                    ?? await db.BranchDayStates.FirstOrDefaultAsync(s => s.BranchId == branchId && s.LocalDate == date && s.PeriodStartLocal == period, ct);
        if (state is null)
        {
            state = new BranchDayState { BranchId = branchId, LocalDate = date, PeriodStartLocal = period, UpdatedAt = Now };
            db.BranchDayStates.Add(state);
        }
        return state;
    }
}
