using System.Data;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Time;
using El3yada.Api.Infrastructure.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>Who is booking: a patient (self-booking, P15) or clinic staff (D32, AS14).</summary>
public sealed record BookingActor(Guid UserId, string Role, Guid? PatientId, StaffContext? Staff)
{
    public bool IsPatient => Staff is null;
    public string HistoryRole => IsPatient ? Roles.Patient : Staff!.Role;
}

/// <summary>
/// Bookings (spec 6.12): create, reschedule, cancel, confirm, reject. Every rule of 6.12.5 is checked
/// on the server inside one transaction that holds an application lock on the branch-day, so two
/// requests for the same place are serialised (BR-AP2). The timed-slot unique index is the second guard.
/// </summary>
public sealed class AppointmentService(
    AppDbContext db,
    ICurrentUser user,
    StaffAccess staffAccess,
    PatientContext patientContext,
    ScheduleLoader schedules,
    INotificationWriter notifications,
    NotificationRecipients recipients,
    BoardPublisher board,
    IAuditLogger audit,
    TimeProvider clock)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    public async Task<BookingActor> PatientActorAsync(CancellationToken ct) =>
        new(user.UserId, Roles.Patient, await patientContext.GetPatientIdAsync(ct), null);

    public async Task<BookingActor> StaffActorAsync(StaffPermission permission, CancellationToken ct)
    {
        var staff = (await staffAccess.GetAsync(ct)).Require(permission);
        return new BookingActor(staff.UserId, staff.Role, null, staff);
    }

    // ---- Locking ------------------------------------------------------------------------------

    /// <summary>Serialises bookings of one branch-day inside the current transaction.</summary>
    internal async Task LockDayAsync(Guid branchId, DateOnly date, CancellationToken ct)
    {
        var resource = $"booking:{branchId:N}:{date:yyyyMMdd}";
        var result = new SqlParameter("@result", SqlDbType.Int) { Direction = ParameterDirection.Output };
        await db.Database.ExecuteSqlRawAsync(
            "EXEC @result = sp_getapplock @Resource = @resource, @LockMode = 'Exclusive', @LockOwner = 'Transaction', @LockTimeout = 10000",
            [result, new SqlParameter("@resource", resource)], ct);
        if (result.Value is int code && code < 0) throw new ApiException(StatusCodes.Status503ServiceUnavailable, "BUSY");
    }

    // ---- Create -------------------------------------------------------------------------------

    public async Task<AppointmentDto> CreateAsync(BookingActor actor, CreateAppointmentRequest r, CancellationToken ct)
    {
        if (actor.IsPatient && r.Guest is not null) throw ApiException.BadRequest(ErrorCodes.ValidationFailed);
        if (!actor.IsPatient && r.PatientId is null && r.Guest is null) throw ApiException.BadRequest(ErrorCodes.ValidationFailed);

        var branchInfo = await db.Branches.AsNoTracking().Where(b => b.Id == r.BranchId)
            .Select(b => new { b.DoctorId, DoctorStatus = b.Doctor.Status, b.Doctor.FullName, b.Doctor.FullNameEn })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();

        if (actor.IsPatient)
        {
            // Patients book only with doctors they are linked to (6.12.3), and never while the doctor is suspended (BR-AP17).
            if (branchInfo.DoctorStatus != "active") throw ApiException.Forbidden(ErrorCodes.BookingUnavailable);
        }
        else
        {
            if (actor.Staff!.DoctorId != branchInfo.DoctorId) throw ApiException.NotFound();
            actor.Staff.RequireBranch(r.BranchId).RequireNotSuspended();
        }

        var patientId = actor.IsPatient ? actor.PatientId : r.PatientId;
        DoctorPatient? link = null;
        if (patientId is { } pid)
        {
            link = await db.DoctorPatients.FirstOrDefaultAsync(l => l.DoctorId == branchInfo.DoctorId && l.PatientId == pid, ct)
                ?? throw ApiException.NotFound(ErrorCodes.NotLinked);
        }

        string? guestPhone = null;
        if (r.Guest is not null && !EgyptianPhone.TryNormalize(r.Guest.Phone, out guestPhone))
            throw ApiException.BadRequest(ErrorCodes.ValidationFailed);

        await EnsureVisitTypeAllowedAsync(link, r.VisitType, ct);

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await LockDayAsync(r.BranchId, r.Date, ct);

        var schedule = await schedules.LoadAsync(r.BranchId, r.Date, r.Date, ct);
        var settings = schedule.Settings;

        if (actor.IsPatient)
        {
            if (schedule.Branch.Status == "temporarilyClosed") throw ApiException.Conflict(ErrorCodes.BranchClosed);
            if (!settings.SelfBooking) throw ApiException.Forbidden(ErrorCodes.BookingUnavailable);
            if (link!.SelfBookingBlocked) throw ApiException.Forbidden(ErrorCodes.SelfBookingBlocked);
        }

        // Upcoming-booking limit: a hard limit for patients, a warning for staff (BR-AP7, BR-AP21).
        if (patientId is { } p)
        {
            var upcoming = await db.Appointments.AsNoTracking()
                .Where(a => a.DoctorId == branchInfo.DoctorId && a.PatientId == p && AppointmentStatuses.Upcoming.Contains(a.Status) && a.StartUtc > Now)
                .OrderBy(a => a.StartUtc).Select(a => a.Id).ToListAsync(ct);
            var limitReached = actor.IsPatient ? upcoming.Count >= settings.MaxUpcomingPerPatient : upcoming.Count > 0 && !r.ConfirmWarnings;
            if (limitReached)
                throw new ApiException(StatusCodes.Status409Conflict, ErrorCodes.UpcomingLimit) { Details = new { appointmentId = upcoming[0] } };
        }

        var place = FindPlace(schedule, r.Date, r.Time, r.VisitType, actor, r.Overbook, ignore: null);

        var status = actor.IsPatient && !settings.AutoConfirm ? AppointmentStatuses.Pending : AppointmentStatuses.Confirmed;
        var appointment = new Appointment
        {
            Id = NewId.Next(),
            DoctorId = branchInfo.DoctorId,
            BranchId = r.BranchId,
            PatientId = patientId,
            GuestName = r.Guest?.Name.Trim(),
            GuestPhone = guestPhone,
            VisitType = r.VisitType,
            Mode = settings.Mode,
            LocalDate = r.Date,
            PeriodStartLocal = place.PeriodStart,
            StartUtc = place.StartUtc,
            EndUtc = place.EndUtc,
            // Queue mode: a place on the period's list, no number until check-in (BR-AP3).
            QueueNumber = null,
            Status = status,
            Source = actor.IsPatient ? "patientApp" : "staff",
            BookedBy = actor.UserId,
            BookedByRole = actor.HistoryRole,
            Reason = Clean(r.Reason),
            StaffNotes = actor.IsPatient ? null : Clean(r.StaffNotes),
            Overbooked = place.Overbooked,
            RemindersSentJson = RemindersAlreadyDue(place.StartUtc, settings.ReminderMinutes),
            CreatedAt = Now,
            UpdatedAt = Now,
        };
        appointment.BoardOrder = BookedOrder(appointment);
        db.Appointments.Add(appointment);
        AddHistory(appointment, actor, "created", null, Describe(appointment), null);

        var when = AppointmentTexts.When(appointment);
        if (actor.IsPatient)
        {
            notifications.Add(actor.UserId, status == AppointmentStatuses.Pending
                ? NotificationTemplates.BookingPending(appointment.Id)
                : NotificationTemplates.BookingConfirmed(when.Ar, when.En, appointment.Id, settings.IsQueue));
            await NotifyStaffAsync(appointment, "حجز جديد", "New booking", ct);
        }
        else if (patientId is not null)
        {
            notifications.Add(await PatientUserIdAsync(patientId.Value, ct),
                NotificationTemplates.BookingConfirmed(when.Ar, when.En, appointment.Id, settings.IsQueue));
        }
        if (!actor.IsPatient) audit.Add("appointment.created", nameof(Appointment), appointment.Id, appointment.DoctorId, patientId);

        await SaveBookingAsync(ct);
        await tx.CommitAsync(ct);
        await board.PublishAsync(appointment.BranchId, appointment.LocalDate, ct);
        return await GetAsync(actor, appointment.Id, ct);
    }

    // ---- Reschedule (BR-AP6) ------------------------------------------------------------------

    public async Task<AppointmentDto> RescheduleAsync(BookingActor actor, Guid id, RescheduleRequest r, CancellationToken ct)
    {
        var current = await LoadForActorAsync(actor, id, ct, tracking: false);
        if (current.Status is not (AppointmentStatuses.Pending or AppointmentStatuses.Confirmed))
            throw ApiException.Conflict(ErrorCodes.InvalidTransition);

        var newBranch = await db.Branches.AsNoTracking().Where(b => b.Id == r.BranchId).Select(b => new { b.DoctorId }).FirstOrDefaultAsync(ct);
        // Another branch is fine, with the same doctor (case 11).
        if (newBranch is null || newBranch.DoctorId != current.DoctorId) throw ApiException.NotFound();

        if (actor.IsPatient)
        {
            if (Now > current.StartUtc.AddMinutes(-await FreeCancelMinutesAsync(current.BranchId, ct))) throw ApiException.Conflict(ErrorCodes.CancelWindowPassed);
            var max = await db.Branches.Where(b => b.Id == current.BranchId).Select(b => b.MaxReschedules).FirstAsync(ct);
            if (current.RescheduleCount >= max) throw ApiException.Conflict(ErrorCodes.MaxReschedules);
        }
        else
        {
            actor.Staff!.RequireBranch(current.BranchId).RequireBranch(r.BranchId);
        }

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Lock both days in a fixed order, so two opposite moves can't deadlock.
        var days = new[] { (current.BranchId, current.LocalDate), (r.BranchId, r.Date) }
            .Distinct().OrderBy(d => d.Item1).ThenBy(d => d.Item2).ToList();
        foreach (var (b, d) in days) await LockDayAsync(b, d, ct);

        var appointment = await db.Appointments.FirstAsync(a => a.Id == id, ct);
        var schedule = await schedules.LoadAsync(r.BranchId, r.Date, r.Date, ct);
        if (actor.IsPatient && (!schedule.Settings.SelfBooking || schedule.Branch.Status != "active"))
            throw ApiException.Forbidden(ErrorCodes.BookingUnavailable);

        // The new place is checked while the old one is still held (ignored only for overlap with itself),
        // and both change in one UPDATE: the patient never ends up with neither (BR-AP6).
        var place = FindPlace(schedule, r.Date, r.Time, appointment.VisitType, actor, r.Overbook, ignore: appointment.Id);
        var from = Describe(appointment);
        var periodChanged = appointment.BranchId != r.BranchId || appointment.LocalDate != r.Date || appointment.PeriodStartLocal != place.PeriodStart;

        appointment.BranchId = r.BranchId;
        appointment.LocalDate = r.Date;
        appointment.PeriodStartLocal = place.PeriodStart;
        appointment.StartUtc = place.StartUtc;
        appointment.EndUtc = place.EndUtc;
        appointment.Mode = schedule.Settings.Mode;
        appointment.Overbooked = place.Overbooked;
        // Still only a place on the list (BR-AP3): the number comes at check-in.
        appointment.QueueNumber = null;
        appointment.BoardOrder = BookedOrder(appointment);
        // The reminders start again for the new time, except those whose time has already passed (case 27).
        if (periodChanged || appointment.StartUtc != current.StartUtc)
            appointment.RemindersSentJson = RemindersAlreadyDue(appointment.StartUtc, schedule.Settings.ReminderMinutes);
        appointment.RescheduleCount++;
        appointment.UpdatedAt = Now;
        AddHistory(appointment, actor, "rescheduled", from, Describe(appointment), Clean(r.Reason));

        if (actor.IsPatient)
        {
            await NotifyStaffAsync(appointment, "تغيير موعد", "Booking rescheduled", ct);
        }
        else if (appointment.PatientId is { } pid)
        {
            var when = AppointmentTexts.When(appointment);
            notifications.Add(await PatientUserIdAsync(pid, ct), NotificationTemplates.BookingRescheduledByClinic(when.Ar, when.En, appointment.Id));
            audit.Add("appointment.rescheduled", nameof(Appointment), appointment.Id, appointment.DoctorId, pid);
        }

        await SaveBookingAsync(ct);
        await tx.CommitAsync(ct);
        await board.PublishAsync(current.BranchId, current.LocalDate, ct);
        if (current.BranchId != appointment.BranchId || current.LocalDate != appointment.LocalDate)
            await board.PublishAsync(appointment.BranchId, appointment.LocalDate, ct);
        return await GetAsync(actor, id, ct);
    }

    // ---- Cancel, confirm, reject (BR-AP5, BR-AP9) -----------------------------------------------

    public async Task<AppointmentDto> CancelAsync(BookingActor actor, Guid id, string? reason, CancellationToken ct)
    {
        var appointment = await LoadForActorAsync(actor, id, ct, tracking: true);
        if (appointment.Status is not (AppointmentStatuses.Pending or AppointmentStatuses.Confirmed))
            throw AlreadyHandled(appointment, ErrorCodes.InvalidTransition);

        if (actor.IsPatient)
        {
            var freeCancel = await FreeCancelMinutesAsync(appointment.BranchId, ct);
            if (Now > appointment.StartUtc.AddMinutes(-freeCancel)) throw ApiException.Conflict(ErrorCodes.CancelWindowPassed);
        }

        appointment.Status = AppointmentStatuses.Cancelled;
        appointment.CancelledAt = Now;
        appointment.CancelledByRole = actor.IsPatient ? "patient" : "clinic";
        appointment.CancelReason = Clean(reason);
        appointment.UpdatedAt = Now;
        AddHistory(appointment, actor, "cancelled", null, null, appointment.CancelReason);

        if (actor.IsPatient) await NotifyStaffAsync(appointment, "إلغاء حجز", "Booking cancelled", ct);
        else if (appointment.PatientId is { } pid)
        {
            notifications.Add(await PatientUserIdAsync(pid, ct), NotificationTemplates.BookingCancelledByClinic(appointment.CancelReason, appointment.Id));
            audit.Add("appointment.cancelled", nameof(Appointment), appointment.Id, appointment.DoctorId, pid, new { reason });
        }

        await SaveBookingAsync(ct);
        await board.PublishAsync(appointment.BranchId, appointment.LocalDate, ct);
        return await GetAsync(actor, id, ct);
    }

    public async Task<AppointmentDto> ConfirmAsync(BookingActor actor, Guid id, CancellationToken ct)
    {
        var appointment = await LoadForActorAsync(actor, id, ct, tracking: true);
        if (appointment.Status != AppointmentStatuses.Pending) throw AlreadyHandled(appointment, ErrorCodes.InvalidTransition);
        appointment.Status = AppointmentStatuses.Confirmed;
        appointment.UpdatedAt = Now;
        AddHistory(appointment, actor, "confirmed", null, null, null);
        if (appointment.PatientId is { } pid)
        {
            var when = AppointmentTexts.When(appointment);
            notifications.Add(await PatientUserIdAsync(pid, ct),
                NotificationTemplates.BookingConfirmed(when.Ar, when.En, appointment.Id, appointment.Mode == "queue"));
        }
        await SaveBookingAsync(ct);
        await board.PublishAsync(appointment.BranchId, appointment.LocalDate, ct);
        return await GetAsync(actor, id, ct);
    }

    public async Task<AppointmentDto> RejectAsync(BookingActor actor, Guid id, string? reason, CancellationToken ct)
    {
        var appointment = await LoadForActorAsync(actor, id, ct, tracking: true);
        if (appointment.Status != AppointmentStatuses.Pending) throw AlreadyHandled(appointment, ErrorCodes.InvalidTransition);
        appointment.Status = AppointmentStatuses.Rejected;
        appointment.RejectReason = Clean(reason);
        appointment.UpdatedAt = Now;
        AddHistory(appointment, actor, "rejected", null, null, appointment.RejectReason);
        if (appointment.PatientId is { } pid)
            notifications.Add(await PatientUserIdAsync(pid, ct), NotificationTemplates.BookingNotConfirmed(appointment.Id, expired: false));
        await SaveBookingAsync(ct);
        await board.PublishAsync(appointment.BranchId, appointment.LocalDate, ct);
        return await GetAsync(actor, id, ct);
    }

    // ---- Reads --------------------------------------------------------------------------------

    public async Task<AppointmentDto> GetAsync(BookingActor actor, Guid id, CancellationToken ct)
    {
        var dto = await Scoped(actor).Where(a => a.Id == id).Select(Projection(actor.IsPatient)).FirstOrDefaultAsync(ct)
            ?? throw ApiException.NotFound();
        return await DecorateAsync(dto, actor, includeHistory: true, ct);
    }

    /// <summary>P16 tabs: upcoming, past, cancelled.</summary>
    public async Task<IReadOnlyList<AppointmentDto>> PatientListAsync(BookingActor actor, string tab, CancellationToken ct)
    {
        var q = Scoped(actor);
        var now = Now;
        q = tab switch
        {
            "cancelled" => q.Where(a => a.Status == AppointmentStatuses.Cancelled || a.Status == AppointmentStatuses.Rejected),
            "past" => q.Where(a => a.Status != AppointmentStatuses.Cancelled && a.Status != AppointmentStatuses.Rejected
                                   && (a.Status == AppointmentStatuses.Completed || a.Status == AppointmentStatuses.NoShow || (a.EndUtc ?? a.StartUtc) < now)),
            _ => q.Where(a => (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed
                               || a.Status == AppointmentStatuses.CheckedIn || a.Status == AppointmentStatuses.WithDoctor)
                              && (a.EndUtc ?? a.StartUtc) >= now.AddHours(-12)),
        };
        q = tab == "upcoming" || tab is not ("past" or "cancelled") ? q.OrderBy(a => a.StartUtc) : q.OrderByDescending(a => a.StartUtc);
        var list = await q.Take(100).Select(Projection(true)).ToListAsync(ct);
        var result = new List<AppointmentDto>(list.Count);
        foreach (var dto in list) result.Add(await DecorateAsync(dto, actor, includeHistory: false, ct));
        return result;
    }

    /// <summary>P15 steps 1–3: branches, visit type rule and prices for one doctor.</summary>
    public async Task<BookingOptionsDto> BookingOptionsAsync(BookingActor actor, Guid doctorId, CancellationToken ct)
    {
        var link = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.DoctorId == doctorId && l.PatientId == actor.PatientId)
            .Select(l => new
            {
                Doctor = new DoctorRef(l.Doctor.UserId, l.Doctor.FullName, l.Doctor.FullNameEn, l.Doctor.Title, l.Doctor.TitleEn),
                l.Doctor.Status, l.SessionCount, l.ConsultationsSinceExam, l.SelfBookingBlocked,
                l.Doctor.ExaminationPricePiasters, l.Doctor.ConsultationPricePiasters,
            })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound(ErrorCodes.NotLinked);
        var max = await db.AppSettings.AsNoTracking().Select(s => s.MaxConsecutiveConsultations).FirstAsync(ct);
        var upcoming = await db.Appointments.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.PatientId == actor.PatientId && AppointmentStatuses.Upcoming.Contains(a.Status) && a.StartUtc > Now)
            .OrderBy(a => a.StartUtc).Select(a => (Guid?)a.Id).FirstOrDefaultAsync(ct);

        var branches = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == doctorId && b.Status != "archived")
            .OrderByDescending(b => b.IsDefault).ThenBy(b => b.CreatedAt)
            .Select(b => new BookingBranchDto(
                b.Id, b.NameAr, b.NameEn, b.Area, b.Status, b.ClosedMessage, b.BookingMode, b.SelfBooking, b.FreeCancelMinutes, b.WindowDays,
                new VisitPricesDto(b.ExaminationPricePiasters ?? link.ExaminationPricePiasters, b.ConsultationPricePiasters ?? link.ConsultationPricePiasters),
                b.BranchPhones.OrderBy(p => p.SortOrder).Select(p => new BranchPhoneDto(p.Number, p.Label, p.IsWhatsapp)).ToList()))
            .ToListAsync(ct);

        string? reason = link.Status != "active" ? ErrorCodes.BookingUnavailable : link.SelfBookingBlocked ? ErrorCodes.SelfBookingBlocked : null;
        var isNew = link.SessionCount == 0;
        return new BookingOptionsDto(link.Doctor, reason is null, reason, isNew,
            !isNew && link.ConsultationsSinceExam < max, link.ConsultationsSinceExam, max, upcoming, branches);
    }

    public async Task<AvailabilityDto> AvailabilityAsync(BookingActor actor, AvailabilityQuery q, CancellationToken ct)
    {
        var branch = await db.Branches.AsNoTracking().Where(b => b.Id == q.BranchId).Select(b => new { b.DoctorId, b.BookingMode }).FirstOrDefaultAsync(ct)
            ?? throw ApiException.NotFound();
        if (actor.IsPatient)
        {
            if (!await db.DoctorPatients.AnyAsync(l => l.DoctorId == branch.DoctorId && l.PatientId == actor.PatientId, ct))
                throw ApiException.NotFound(ErrorCodes.NotLinked);
        }
        else if (actor.Staff!.DoctorId != branch.DoctorId) throw ApiException.NotFound();
        else actor.Staff.RequireBranch(q.BranchId);

        var to = q.To ?? q.From;
        if (to < q.From || to.DayNumber - q.From.DayNumber > 62) throw ApiException.BadRequest(ErrorCodes.ValidationFailed);
        var schedule = await schedules.LoadAsync(q.BranchId, q.From, to, ct);
        var days = new List<DayAvailability>();
        for (var d = q.From; d <= to; d = d.AddDays(1))
            days.Add(schedule.Day(new AvailabilityRequest(d, q.VisitType, actor.IsPatient, Now)));
        return new AvailabilityDto(q.BranchId, branch.BookingMode, days);
    }

    // ---- Helpers ------------------------------------------------------------------------------

    internal sealed record Place(TimeOnly PeriodStart, DateTime StartUtc, DateTime EndUtc, bool Overbooked);

    /// <summary>Finds the requested period or slot, or throws the 6.12.6 error. Staff may overbook after a warning.</summary>
    internal Place FindPlace(BranchSchedule schedule, DateOnly date, TimeOnly time, string visitType, BookingActor actor, bool overbook, Guid? ignore)
    {
        var day = schedule.Day(new AvailabilityRequest(date, visitType, actor.IsPatient, Now, ignore));
        if (day.Reason is { } dayReason) throw ApiException.Conflict(dayReason);

        var canOverbook = !actor.IsPatient && schedule.Settings.StaffOverbooking;
        if (schedule.Settings.IsQueue)
        {
            var period = day.Periods.FirstOrDefault(p => p.Start == time) ?? throw ApiException.Conflict(ErrorCodes.OutsideHours);
            if (period.Unavailable is null) return new Place(period.Start, period.StartUtc, period.EndUtc, false);
            if (period.Unavailable == ErrorCodes.PeriodFull && canOverbook)
                return overbook ? new Place(period.Start, period.StartUtc, period.EndUtc, true) : throw ApiException.Conflict(ErrorCodes.OverbookingWarning);
            throw new ApiException(StatusCodes.Status409Conflict, period.Unavailable) { Details = new { availability = day } };
        }

        var slot = day.Slots.FirstOrDefault(s => s.Start == time) ?? throw ApiException.Conflict(ErrorCodes.OutsideHours);
        if (slot.Unavailable is null) return new Place(slot.PeriodStart, slot.StartUtc, slot.EndUtc, false);
        if (slot.Unavailable == ErrorCodes.SlotTaken && canOverbook)
            return overbook ? new Place(slot.PeriodStart, slot.StartUtc, slot.EndUtc, true) : throw ApiException.Conflict(ErrorCodes.OverbookingWarning);
        throw new ApiException(StatusCodes.Status409Conflict, slot.Unavailable) { Details = new { availability = day } };
    }

    /// <summary>BR-AP4: new patients and guests are examinations; consultations follow BR-S3.</summary>
    internal async Task EnsureVisitTypeAllowedAsync(DoctorPatient? link, string visitType, CancellationToken ct)
    {
        if (visitType != "consultation") return;
        if (link is null || link.SessionCount == 0) throw ApiException.Conflict(ErrorCodes.ConsultationRequiresExam);
        var max = await db.AppSettings.AsNoTracking().Select(s => s.MaxConsecutiveConsultations).FirstAsync(ct);
        if (link.ConsultationsSinceExam >= max) throw ApiException.Conflict(ErrorCodes.ConsultationRequiresExam);
    }

    /// <summary>
    /// The board order of a booking not yet checked in. Queue mode: 0, as Expected is ordered by booking time
    /// and the card gets its number, and its place in Waiting, at check-in (BR-AP3). Timed mode: the minute of
    /// the day, so the booked time sets the order.
    /// </summary>
    internal static int BookedOrder(Appointment a) => a.Mode == "queue"
        ? 0
        : (int)TimeOnly.FromDateTime(CairoTime.ToCairo(a.StartUtc)).ToTimeSpan().TotalMinutes;

    /// <summary>Reminders whose time has already passed when the booking is made (or moved) are skipped (case 27).</summary>
    internal string RemindersAlreadyDue(DateTime startUtc, IReadOnlyList<int> reminderMinutes) =>
        System.Text.Json.JsonSerializer.Serialize(reminderMinutes.Where(m => startUtc.AddMinutes(-m) <= Now).Order().ToList());

    /// <summary>
    /// How many checked-in patients of the same period go in before this one (BR-AP16): priority patients
    /// first, then by number, which is the order of arrival. Patients with the doctor are not counted.
    /// </summary>
    internal Task<int> AheadAsync(Guid id, Guid branchId, DateOnly date, TimeOnly period, bool isPriority, int boardOrder, CancellationToken ct) =>
        db.Appointments.AsNoTracking().CountAsync(x =>
            x.BranchId == branchId && x.LocalDate == date && x.PeriodStartLocal == period
            && x.Status == AppointmentStatuses.CheckedIn && x.Id != id
            && (isPriority ? x.IsPriority && x.BoardOrder < boardOrder : x.IsPriority || x.BoardOrder < boardOrder), ct);

    internal async Task SaveBookingAsync(CancellationToken ct)
    {
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
        {
            // The timed-slot unique index caught a race the lock didn't (BR-AP2).
            throw ApiException.Conflict(ErrorCodes.SlotTaken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Someone changed the booking first (BR-LB4).
            throw ApiException.Conflict(ErrorCodes.AlreadyHandled);
        }
    }

    internal IQueryable<Appointment> Scoped(BookingActor actor)
    {
        var q = db.Appointments.AsNoTracking();
        if (actor.IsPatient) return q.Where(a => a.PatientId == actor.PatientId);
        var staff = actor.Staff!;
        var branches = staff.BranchIds.ToList();
        return q.Where(a => a.DoctorId == staff.DoctorId && branches.Contains(a.BranchId));
    }

    internal async Task<Appointment> LoadForActorAsync(BookingActor actor, Guid id, CancellationToken ct, bool tracking)
    {
        var q = tracking ? db.Appointments.AsQueryable() : db.Appointments.AsNoTracking();
        var a = await q.FirstOrDefaultAsync(x => x.Id == id, ct) ?? throw ApiException.NotFound();
        var visible = actor.IsPatient ? a.PatientId == actor.PatientId : a.DoctorId == actor.Staff!.DoctorId && actor.Staff.CanSeeBranch(a.BranchId);
        if (!visible) throw ApiException.NotFound();
        if (!actor.IsPatient && !actor.Staff!.Has(StaffPermission.AppointmentsManage)) throw ApiException.Forbidden(ErrorCodes.PermissionDenied);
        return a;
    }

    /// <summary>BR-LB4: the second person learns who acted first.</summary>
    internal ApiException AlreadyHandled(Appointment a, string fallback)
    {
        var last = db.AppointmentHistories.AsNoTracking().Where(h => h.AppointmentId == a.Id).OrderByDescending(h => h.At)
            .Select(h => new { h.Action, h.At, Name = h.ByUserId == null ? null : db.Users.Where(u => u.Id == h.ByUserId).Select(u => u.DisplayName).FirstOrDefault() })
            .FirstOrDefault();
        return new ApiException(StatusCodes.Status409Conflict, last is null ? fallback : ErrorCodes.AlreadyHandled)
        {
            Details = new { status = a.Status, action = last?.Action, by = last?.Name, at = last?.At },
        };
    }

    internal void AddHistory(Appointment a, BookingActor? actor, string action, string? from, string? to, string? reason) =>
        db.AppointmentHistories.Add(new AppointmentHistory
        {
            Id = NewId.Next(),
            AppointmentId = a.Id,
            At = Now,
            ByUserId = actor?.UserId,
            ByRole = actor?.HistoryRole ?? "system",
            Action = action,
            FromValue = from,
            ToValue = to,
            Reason = reason,
        });

    internal async Task NotifyStaffAsync(Appointment a, string titleAr, string titleEn, CancellationToken ct)
    {
        // Assistants who see the branch; the doctor only if they switched booking alerts on (spec 10.1).
        var doctorWants = await db.Users.Where(u => u.Id == a.DoctorId).Select(u => u.NotifyBookings).FirstAsync(ct);
        var to = await recipients.StaffAsync(a.DoctorId, StaffPermission.AppointmentsView, a.BranchId, includeDoctor: doctorWants, ct);
        var name = a.PatientId is { } pid
            ? await db.DoctorPatients.Where(l => l.DoctorId == a.DoctorId && l.PatientId == pid).Select(l => l.PatientName).FirstAsync(ct)
            : a.GuestName!;
        var when = AppointmentTexts.When(a);
        foreach (var userId in to)
            notifications.Add(userId, NotificationTemplates.StaffBookingActivity(titleAr, titleEn, $"{name} — {when.Ar}", $"{name}: {when.En}", a.Id));
    }

    internal async Task<Guid> PatientUserIdAsync(Guid patientId, CancellationToken ct) =>
        await db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).FirstAsync(ct);

    private async Task<int> FreeCancelMinutesAsync(Guid branchId, CancellationToken ct) =>
        await db.Branches.Where(b => b.Id == branchId).Select(b => b.FreeCancelMinutes).FirstAsync(ct);

    internal static string Describe(Appointment a) =>
        $"{a.BranchId:N}|{a.LocalDate:yyyy-MM-dd}|{CairoTime.ToCairo(a.StartUtc):HH:mm}|{a.QueueNumber}";

    private static string? Clean(string? text) => string.IsNullOrWhiteSpace(text) ? null : text.Trim();

    internal System.Linq.Expressions.Expression<Func<Appointment, AppointmentDto>> Projection(bool forPatient) => a => new AppointmentDto(
        a.Id, a.DoctorId,
        new DoctorRef(a.Doctor.UserId, a.Doctor.FullName, a.Doctor.FullNameEn, a.Doctor.Title, a.Doctor.TitleEn),
        a.BranchId, new BranchRef(a.Branch.Id, a.Branch.NameAr, a.Branch.NameEn),
        a.PatientId,
        a.PatientId == null ? a.GuestName! : db.DoctorPatients.Where(l => l.DoctorId == a.DoctorId && l.PatientId == a.PatientId).Select(l => l.PatientName).FirstOrDefault()!,
        forPatient ? null : (a.PatientId == null ? a.GuestPhone : a.Patient!.Phone),
        a.PatientId == null,
        a.VisitType, a.Mode, a.LocalDate, a.PeriodStartLocal, a.StartUtc, a.EndUtc, a.QueueNumber, a.Status, a.Source, a.BookedByRole,
        forPatient ? null : db.Users.Where(u => u.Id == a.BookedBy).Select(u => u.DisplayName).FirstOrDefault(),
        a.Reason,
        forPatient ? null : a.StaffNotes,   // staff only (spec 8)
        a.Overbooked, a.RescheduleCount, a.CheckedInAt, a.CalledAt, a.SessionId, a.CancelReason ?? a.RejectReason, a.CancelledByRole,
        a.IsPriority, a.FlaggedNoSession, a.CreatedAt,
        false, null, null, null, null, null, null);

    private async Task<AppointmentDto> DecorateAsync(AppointmentDto dto, BookingActor actor, bool includeHistory, CancellationToken ct)
    {
        var branch = await db.Branches.AsNoTracking().Where(b => b.Id == dto.BranchId)
            .Select(b => new
            {
                b.FreeCancelMinutes, b.AvgVisitMinutes,
                Phones = b.BranchPhones.OrderBy(p => p.SortOrder).Select(p => new BranchPhoneDto(p.Number, p.Label, p.IsWhatsapp)).ToList(),
            })
            .FirstAsync(ct);
        var canChange = dto.Status is AppointmentStatuses.Pending or AppointmentStatuses.Confirmed
                        && (!actor.IsPatient || Now <= dto.StartUtc.AddMinutes(-branch.FreeCancelMinutes));

        // Queue mode on the day (BR-AP15, BR-AP16): "now serving" for the period and, from check-in on, how many
        // are ahead and the estimated wait (patients ahead × the branch's average visit time, spec 6.12.2).
        // Before check-in there is no number and no estimate: the turn is given on arrival (BR-AP3).
        int? nowServing = null, ahead = null, waitMinutes = null;
        TimeOnly? estimate = null;
        if (dto.Mode == "queue" && dto.Date == CairoTime.Today(clock))
        {
            nowServing = await db.BranchDayStates.AsNoTracking()
                .Where(s => s.BranchId == dto.BranchId && s.LocalDate == dto.Date && s.PeriodStartLocal == dto.Time)
                .Select(s => s.NowServingNumber).FirstOrDefaultAsync(ct);
            if (dto.Status == AppointmentStatuses.CheckedIn && dto.QueueNumber is not null)
            {
                var order = await db.Appointments.AsNoTracking().Where(a => a.Id == dto.Id).Select(a => a.BoardOrder).FirstAsync(ct);
                ahead = await AheadAsync(dto.Id, dto.BranchId, dto.Date, dto.Time, dto.IsPriority, order, ct);
                waitMinutes = ahead * branch.AvgVisitMinutes;
                var now = CairoTime.Now(clock);
                var periodStart = dto.Date.ToDateTime(dto.Time);
                estimate = TimeOnly.FromDateTime((now > periodStart ? now : periodStart).AddMinutes(waitMinutes.Value));
            }
        }

        IReadOnlyList<AppointmentHistoryDto>? history = null;
        if (includeHistory)
        {
            history = await db.AppointmentHistories.AsNoTracking().Where(h => h.AppointmentId == dto.Id).OrderBy(h => h.At)
                .Select(h => new AppointmentHistoryDto(h.At, h.ByRole,
                    actor.IsPatient ? null : db.Users.Where(u => u.Id == h.ByUserId).Select(u => u.DisplayName).FirstOrDefault(),
                    h.Action, actor.IsPatient ? null : h.FromValue, actor.IsPatient ? null : h.ToValue, h.Reason))
                .ToListAsync(ct);
        }
        return dto with
        {
            CanChange = canChange, NowServing = nowServing, EstimatedTime = estimate, History = history, BranchPhones = branch.Phones,
            Ahead = ahead, EstimatedWaitMinutes = waitMinutes,
        };
    }
}
