using System.Text.Json;
using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Time;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// <c>updateBranchSchedule</c> (D29 Working hours, Special dates, Booking settings; AS17): weekly
/// periods, date-specific hours, closures and booking settings. Schedule changes never drop
/// bookings silently (BR-AP12): a dry run lists the affected bookings, and the change is applied
/// only with a decision (keep or cancel) for each one.
/// </summary>
public sealed class ScheduleService(
    AppDbContext db,
    StaffAccess staffAccess,
    AppointmentService appointments,
    BoardPublisher publisher,
    INotificationWriter notifications,
    IAuditLogger audit,
    TimeProvider clock)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    public async Task<IReadOnlyList<StaffBranchDto>> BranchesAsync(CancellationToken ct)
    {
        var staff = await staffAccess.GetAsync(ct);
        var ids = staff.BranchIds.ToList();
        return await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == staff.DoctorId && ids.Contains(b.Id) && b.Status != "archived")
            .OrderByDescending(b => b.IsDefault).ThenBy(b => b.CreatedAt)
            .Select(b => new StaffBranchDto(b.Id, b.NameAr, b.NameEn, b.IsDefault, b.Status, b.BookingMode))
            .ToListAsync(ct);
    }

    public async Task<ScheduleDto> GetAsync(Guid branchId, CancellationToken ct)
    {
        var staff = (await staffAccess.GetAsync(ct)).Require(StaffPermission.AppointmentsView).RequireBranch(branchId);
        var branch = await db.Branches.AsNoTracking().FirstAsync(b => b.Id == branchId && b.DoctorId == staff.DoctorId, ct);
        var today = CairoTime.Today(clock);
        var nowLocal = CairoTime.Now(clock);

        var weekly = await db.BranchPeriods.AsNoTracking().Where(p => p.BranchId == branchId)
            .OrderBy(p => p.Weekday).ThenBy(p => p.StartLocal)
            .Select(p => new PeriodInput(p.Weekday, p.StartLocal, p.EndLocal, p.EndsNextDay, p.Label, p.Capacity)).ToListAsync(ct);
        var overrides = await db.BranchDateOverrides.AsNoTracking().Where(o => o.BranchId == branchId && o.Date >= today)
            .OrderBy(o => o.Date)
            .Select(o => new DateOverrideInput(o.Date, o.BranchDateOverridePeriods.OrderBy(p => p.StartLocal)
                .Select(p => new DatePeriodInput(p.StartLocal, p.EndLocal, p.EndsNextDay, p.Label, p.Capacity)).ToList()))
            .ToListAsync(ct);
        var closures = await db.BranchClosures.AsNoTracking()
            .Where(c => c.DoctorId == staff.DoctorId && (c.BranchId == branchId || c.BranchId == null) && c.ToLocal > nowLocal)
            .OrderBy(c => c.FromLocal)
            .Select(c => new ClosureInput(c.Id, c.FromLocal, c.ToLocal, c.Reason, c.BranchId == null)).ToListAsync(ct);

        return new ScheduleDto(branchId, weekly, overrides, closures, SettingsOf(branch));
    }

    public async Task<UpdateScheduleResult> UpdateAsync(Guid branchId, UpdateScheduleRequest r, CancellationToken ct)
    {
        var staff = (await staffAccess.GetAsync(ct)).Require(StaffPermission.ScheduleManage).RequireBranch(branchId);
        var actor = new BookingActor(staff.UserId, staff.Role, null, staff);

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var branch = await db.Branches.FirstOrDefaultAsync(b => b.Id == branchId && b.DoctorId == staff.DoctorId, ct) ?? throw ApiException.NotFound();
        var conflicts = await FindConflictsAsync(branch, r, ct);

        if (r.DryRun) return new UpdateScheduleResult(false, conflicts);

        var decisions = (r.Decisions ?? []).ToDictionary(d => d.AppointmentId, d => d.Action);
        var undecided = conflicts.Where(c => !decisions.ContainsKey(c.AppointmentId)).ToList();
        if (undecided.Count > 0)
            throw new ApiException(StatusCodes.Status409Conflict, ErrorCodes.ScheduleConflicts) { Details = new { conflicts = undecided } };

        var nowLocal = CairoTime.Now(clock);
        var today = CairoTime.Today(clock);

        // Weekly periods are replaced as a whole.
        await db.BranchPeriods.Where(p => p.BranchId == branchId).ExecuteDeleteAsync(ct);
        db.BranchPeriods.AddRange(r.Weekly.Select(p => new BranchPeriod
        {
            Id = NewId.Next(), BranchId = branchId, Weekday = (byte)p.Weekday, StartLocal = p.Start, EndLocal = p.End,
            EndsNextDay = p.EndsNextDay, Label = p.Label, Capacity = p.Capacity,
        }));

        // Future special dates are replaced; past ones are kept as history.
        var oldOverrides = await db.BranchDateOverrides.Where(o => o.BranchId == branchId && o.Date >= today).Select(o => o.Id).ToListAsync(ct);
        await db.BranchDateOverridePeriods.Where(p => oldOverrides.Contains(p.OverrideId)).ExecuteDeleteAsync(ct);
        await db.BranchDateOverrides.Where(o => oldOverrides.Contains(o.Id)).ExecuteDeleteAsync(ct);
        foreach (var o in r.DateOverrides.Where(o => o.Date >= today))
        {
            var entity = new BranchDateOverride { Id = NewId.Next(), BranchId = branchId, Date = o.Date, CreatedBy = staff.UserId, CreatedAt = Now };
            foreach (var p in o.Periods)
                entity.BranchDateOverridePeriods.Add(new BranchDateOverridePeriod
                {
                    Id = NewId.Next(), StartLocal = p.Start, EndLocal = p.End, EndsNextDay = p.EndsNextDay, Label = p.Label, Capacity = p.Capacity,
                });
            db.BranchDateOverrides.Add(entity);
        }

        // Closures still to come for this branch (and the doctor's all-branch ones) are replaced.
        await db.BranchClosures
            .Where(c => c.DoctorId == staff.DoctorId && (c.BranchId == branchId || c.BranchId == null) && c.ToLocal > nowLocal)
            .ExecuteDeleteAsync(ct);
        db.BranchClosures.AddRange(r.Closures.Where(c => c.ToLocal > nowLocal).Select(c => new BranchClosure
        {
            Id = NewId.Next(), DoctorId = staff.DoctorId, BranchId = c.AllBranches ? null : branchId,
            FromLocal = c.FromLocal, ToLocal = c.ToLocal, Reason = c.Reason, CreatedBy = staff.UserId, CreatedAt = Now,
        }));

        ApplySettings(branch, r.Settings);
        branch.UpdatedAt = Now;

        var touched = new HashSet<(Guid, DateOnly)> { (branchId, today) };
        foreach (var (id, action) in decisions.Where(d => d.Value == "cancel"))
        {
            var a = await db.Appointments.FirstOrDefaultAsync(x => x.Id == id && x.DoctorId == staff.DoctorId, ct);
            if (a is null || a.Status is not (AppointmentStatuses.Pending or AppointmentStatuses.Confirmed)) continue;
            a.Status = AppointmentStatuses.Cancelled;
            a.CancelledAt = Now;
            a.CancelledByRole = "clinic";
            a.CancelReason = "scheduleChange";
            a.UpdatedAt = Now;
            appointments.AddHistory(a, actor, "cancelled", null, null, "scheduleChange");
            if (a.PatientId is { } pid)
                notifications.Add(await appointments.PatientUserIdAsync(pid, ct), NotificationTemplates.BookingCancelledByClinic(null, a.Id));
            touched.Add((a.BranchId, a.LocalDate));
        }

        audit.Add("branch.scheduleUpdated", nameof(Branch), branchId, staff.DoctorId, details: new
        {
            periods = r.Weekly.Count, overrides = r.DateOverrides.Count, closures = r.Closures.Count, mode = r.Settings.Mode,
            kept = decisions.Count(d => d.Value == "keep"), cancelled = decisions.Count(d => d.Value == "cancel"),
        });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        foreach (var (b, d) in touched) await publisher.PublishAsync(b, d, ct);
        return new UpdateScheduleResult(true, conflicts);
    }

    /// <summary>Future bookings that would no longer fit the new schedule (mode, hours, slot grid or closures).</summary>
    private async Task<IReadOnlyList<ScheduleConflictDto>> FindConflictsAsync(Branch branch, UpdateScheduleRequest r, CancellationToken ct)
    {
        var anyAllBranch = r.Closures.Any(c => c.AllBranches);
        var future = await db.Appointments.AsNoTracking()
            .Where(a => a.DoctorId == branch.DoctorId && a.StartUtc > Now
                        && (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed)
                        && (a.BranchId == branch.Id || anyAllBranch))
            .Select(a => new
            {
                a.Id, a.BranchId, a.LocalDate, a.PeriodStartLocal, a.StartUtc, a.EndUtc, a.Status, a.Overbooked, a.QueueNumber, a.VisitType,
                Name = a.PatientId == null ? a.GuestName! : db.DoctorPatients.Where(l => l.DoctorId == a.DoctorId && l.PatientId == a.PatientId).Select(l => l.PatientName).FirstOrDefault()!,
            })
            .ToListAsync(ct);

        var settings = new BookingSettings(r.Settings.Mode, r.Settings.SlotMinutes, r.Settings.ExamSlots, r.Settings.ConsultationSlots,
            r.Settings.DefaultCapacity, r.Settings.AvgVisitMinutes, r.Settings.SelfBooking, r.Settings.AutoConfirm, r.Settings.WindowDays,
            r.Settings.MinNoticeMinutes, r.Settings.SameDay, r.Settings.FreeCancelMinutes, r.Settings.MaxReschedules,
            r.Settings.MaxUpcomingPerPatient, r.Settings.NoShowLimitCount, r.Settings.NoShowLimitDays, r.Settings.ReminderMinutes, r.Settings.StaffOverbooking);
        var closures = r.Closures.Select(c => new ClosureWindow(c.FromLocal, c.ToLocal)).ToList();
        var allBranchClosures = r.Closures.Where(c => c.AllBranches).Select(c => new ClosureWindow(c.FromLocal, c.ToLocal)).ToList();

        var conflicts = new List<ScheduleConflictDto>();
        foreach (var a in future)
        {
            var localStart = CairoTime.ToCairo(a.StartUtc);
            bool fits;
            if (a.BranchId != branch.Id)
            {
                // Another branch: only a new all-branch closure (vacation) can affect it.
                var end = a.EndUtc is { } e ? CairoTime.ToCairo(e) : localStart.AddMinutes(1);
                fits = !allBranchClosures.Any(c => c.FromLocal < end && c.ToLocal > localStart);
            }
            else
            {
                var templates = r.DateOverrides.FirstOrDefault(o => o.Date == a.LocalDate) is { } o
                    ? o.Periods.Select(p => new PeriodTemplate(p.Start, p.End, p.EndsNextDay, p.Label, p.Capacity)).ToList()
                    : r.Weekly.Where(p => p.Weekday == CairoTime.IsoWeekday(a.LocalDate))
                        .Select(p => new PeriodTemplate(p.Start, p.End, p.EndsNextDay, p.Label, p.Capacity)).ToList();
                var day = AvailabilityEngine.ForDay(new AvailabilityRequest(a.LocalDate, a.VisitType, false, Now, a.Id),
                    settings, "active", templates, templates, closures, []);
                fits = settings.IsQueue
                    ? branch.BookingMode == "queue" && day.Periods.Any(p => p.Start == a.PeriodStartLocal && !p.Closed)
                    : branch.BookingMode == "timed" && day.Slots.Any(s => s.Start == TimeOnly.FromDateTime(localStart) && s.Unavailable != "BRANCH_CLOSED");
            }
            if (!fits) conflicts.Add(new ScheduleConflictDto(a.Id, a.Name, a.LocalDate, TimeOnly.FromDateTime(localStart), a.QueueNumber, a.Status));
        }
        return conflicts;
    }

    private static void ApplySettings(Branch b, BookingSettingsInput s)
    {
        b.BookingMode = s.Mode;
        b.SlotMinutes = s.SlotMinutes;
        b.ExamSlots = (byte)s.ExamSlots;
        b.ConsultationSlots = (byte)s.ConsultationSlots;
        b.DefaultCapacity = s.DefaultCapacity;
        b.AvgVisitMinutes = s.AvgVisitMinutes;
        b.SelfBooking = s.SelfBooking;
        b.AutoConfirm = s.AutoConfirm;
        b.WindowDays = s.WindowDays;
        b.MinNoticeMinutes = s.MinNoticeMinutes;
        b.SameDay = s.SameDay;
        b.FreeCancelMinutes = s.FreeCancelMinutes;
        b.MaxReschedules = s.MaxReschedules;
        b.MaxUpcomingPerPatient = s.MaxUpcomingPerPatient;
        b.NoShowLimitCount = s.NoShowLimitCount;
        b.NoShowLimitDays = s.NoShowLimitDays;
        b.ReminderMinutesJson = JsonSerializer.Serialize(s.ReminderMinutes);
        b.StaffOverbooking = s.StaffOverbooking;
        b.WaitingOrderByArrival = s.WaitingOrderByArrival;
    }

    private static BookingSettingsInput SettingsOf(Branch b)
    {
        var s = ScheduleLoader.SettingsOf(b);
        return new BookingSettingsInput(s.Mode, s.SlotMinutes, s.ExamSlots, s.ConsultationSlots, s.DefaultCapacity, s.AvgVisitMinutes,
            s.SelfBooking, s.AutoConfirm, s.WindowDays, s.MinNoticeMinutes, s.SameDay, s.FreeCancelMinutes, s.MaxReschedules,
            s.MaxUpcomingPerPatient, s.NoShowLimitCount, s.NoShowLimitDays, s.ReminderMinutes, s.StaffOverbooking, b.WaitingOrderByArrival);
    }
}
