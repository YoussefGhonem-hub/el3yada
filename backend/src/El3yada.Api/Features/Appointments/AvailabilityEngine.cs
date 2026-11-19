using El3yada.Api.Infrastructure.Time;

namespace El3yada.Api.Features.Appointments;

/// <summary>Booking statuses (spec 6.12.4).</summary>
public static class AppointmentStatuses
{
    public const string Pending = "pending";
    public const string Confirmed = "confirmed";
    public const string CheckedIn = "checkedIn";
    public const string WithDoctor = "withDoctor";
    public const string Completed = "completed";
    public const string Cancelled = "cancelled";
    public const string NoShow = "noShow";
    public const string Rejected = "rejected";

    /// <summary>Hold a timed slot (the unique index UQ_Appointments_TimedSlot uses the same list).</summary>
    public static readonly string[] Holding = [Pending, Confirmed, CheckedIn, WithDoctor];

    /// <summary>Count toward a queue period's capacity: a finished visit still used its place.</summary>
    public static readonly string[] UsingCapacity = [Pending, Confirmed, CheckedIn, WithDoctor, Completed];

    /// <summary>Upcoming for the patient (UPCOMING_LIMIT, P16 "Upcoming").</summary>
    public static readonly string[] Upcoming = [Pending, Confirmed];
}

/// <summary>A branch's booking settings (spec 6.12.2), read from <c>Branches</c>.</summary>
public sealed record BookingSettings(
    string Mode,
    int SlotMinutes,
    int ExamSlots,
    int ConsultationSlots,
    int DefaultCapacity,
    int AvgVisitMinutes,
    bool SelfBooking,
    bool AutoConfirm,
    int WindowDays,
    int MinNoticeMinutes,
    bool SameDay,
    int FreeCancelMinutes,
    int MaxReschedules,
    int MaxUpcomingPerPatient,
    int NoShowLimitCount,
    int NoShowLimitDays,
    IReadOnlyList<int> ReminderMinutes,
    bool StaffOverbooking)
{
    public bool IsQueue => Mode == "queue";

    public int SlotsFor(string visitType) => visitType == "consultation" ? ConsultationSlots : ExamSlots;
}

/// <summary>One working period on a day: weekly, or a special date that replaces the week (BR-AP13).</summary>
public sealed record PeriodTemplate(TimeOnly Start, TimeOnly End, bool EndsNextDay, string? Label, int? Capacity);

/// <summary>A closure or blocked time, in Cairo local time.</summary>
public sealed record ClosureWindow(DateTime FromLocal, DateTime ToLocal);

/// <summary>An existing booking, enough to compute what's left.</summary>
public sealed record ExistingBooking(Guid Id, DateOnly LocalDate, TimeOnly PeriodStartLocal, DateTime StartUtc, DateTime? EndUtc, string Status, bool Overbooked);

/// <param name="Unavailable">Null when bookable; otherwise BRANCH_CLOSED, TOO_SOON, PERIOD_FULL, or the day's reason.</param>
/// <param name="EstimatedTime">Queue mode: the estimated time for the next place (spec 6.12.1).</param>
public sealed record PeriodAvailability(
    TimeOnly Start, TimeOnly End, bool EndsNextDay, string? Label,
    int Capacity, int Booked, int Remaining,
    DateTime StartUtc, DateTime EndUtc,
    bool Closed, TimeOnly? EstimatedTime, string? Unavailable);

/// <param name="Unavailable">Null when free; otherwise SLOT_TAKEN, BRANCH_CLOSED, TOO_SOON, or the day's reason.</param>
public sealed record SlotAvailability(
    TimeOnly Start, TimeOnly End, DateTime StartUtc, DateTime EndUtc,
    bool Available, string? PeriodLabel, TimeOnly PeriodStart, string? Unavailable);

/// <param name="Reason">Why the whole day can't be booked by the caller: BRANCH_CLOSED, SAME_DAY_OFF, TOO_FAR_AHEAD, TOO_SOON, OUTSIDE_HOURS.</param>
public sealed record DayAvailability(
    DateOnly Date, bool Closed, string? Reason,
    IReadOnlyList<PeriodAvailability> Periods, IReadOnlyList<SlotAvailability> Slots);

/// <summary>Patients get every self-booking limit (BR-AP7); staff get the raw schedule.</summary>
public sealed record AvailabilityRequest(DateOnly Date, string VisitType, bool ForPatient, DateTime NowUtc, Guid? IgnoreBookingId = null);

/// <summary>
/// BR-AP1: availability is calculated on the server only. Pure and deterministic (no database, no
/// clock), so every rule is unit tested: working hours, special dates, closures, existing bookings
/// and the booking settings. Times are Cairo wall-clock; a period that crosses midnight belongs to
/// the day it starts (BR-AP19).
/// </summary>
public static class AvailabilityEngine
{
    public static DayAvailability ForDay(
        AvailabilityRequest request,
        BookingSettings settings,
        string branchStatus,
        IReadOnlyList<PeriodTemplate> weekly,
        IReadOnlyList<PeriodTemplate>? dateOverride,
        IReadOnlyList<ClosureWindow> closures,
        IReadOnlyList<ExistingBooking> bookings)
    {
        var date = request.Date;
        var nowLocal = CairoTime.ToCairo(request.NowUtc);
        var today = DateOnly.FromDateTime(nowLocal);

        string? dayReason = null;
        if (branchStatus != "active") dayReason = "BRANCH_CLOSED";
        else if (date < today) dayReason = "TOO_SOON";
        else if (request.ForPatient && date == today && !settings.SameDay) dayReason = "SAME_DAY_OFF";
        else if (request.ForPatient && date > today.AddDays(settings.WindowDays)) dayReason = "TOO_FAR_AHEAD";

        // Special hours for a date replace that weekday's hours.
        var templates = dateOverride ?? weekly;
        var minStartLocal = request.ForPatient ? nowLocal.AddMinutes(settings.MinNoticeMinutes) : nowLocal;
        var sameDay = bookings.Where(b => b.Id != request.IgnoreBookingId && b.LocalDate == date).ToList();

        var periods = new List<PeriodAvailability>();
        var slots = new List<SlotAvailability>();

        foreach (var p in templates.OrderBy(t => t.Start))
        {
            var startLocal = date.ToDateTime(p.Start);
            var endLocal = date.ToDateTime(p.End).AddDays(p.EndsNextDay ? 1 : 0);
            var startUtc = CairoTime.ToUtc(date, p.Start);
            var endUtc = CairoTime.ToUtc(date, p.End, p.EndsNextDay);
            var fullyClosed = closures.Any(c => c.FromLocal <= startLocal && c.ToLocal >= endLocal);

            if (settings.IsQueue)
            {
                var capacity = p.Capacity ?? settings.DefaultCapacity;
                var booked = sameDay.Count(b => b.PeriodStartLocal == p.Start && AppointmentStatuses.UsingCapacity.Contains(b.Status));
                // Places have no exact time, so any closure inside a queue period closes it.
                var closed = closures.Any(c => c.FromLocal < endLocal && c.ToLocal > startLocal);
                // Patients book at least the minimum notice before the period starts; staff until it ends.
                var tooLate = request.ForPatient ? startLocal < minStartLocal : endLocal <= nowLocal;
                var remaining = Math.Max(0, capacity - booked);
                var why = dayReason ?? (closed ? "BRANCH_CLOSED" : tooLate ? "TOO_SOON" : remaining == 0 ? "PERIOD_FULL" : null);
                var estimate = TimeOnly.FromDateTime(startLocal.AddMinutes(booked * settings.AvgVisitMinutes));
                periods.Add(new PeriodAvailability(p.Start, p.End, p.EndsNextDay, p.Label, capacity, booked,
                    why is null ? remaining : 0, startUtc, endUtc, closed, estimate, why));
                continue;
            }

            var length = settings.SlotMinutes * settings.SlotsFor(request.VisitType);
            var taken = sameDay
                .Where(b => AppointmentStatuses.Holding.Contains(b.Status))
                .Select(b => (Start: b.StartUtc, End: b.EndUtc ?? b.StartUtc.AddMinutes(settings.SlotMinutes)))
                .ToList();

            for (var s = startLocal; s.AddMinutes(length) <= endLocal; s = s.AddMinutes(settings.SlotMinutes))
            {
                var e = s.AddMinutes(length);
                var sUtc = CairoTime.ToUtc(s);
                var eUtc = CairoTime.ToUtc(e);
                var blocked = closures.Any(c => c.FromLocal < e && c.ToLocal > s);
                var isTaken = taken.Any(r => r.Start < eUtc && r.End > sUtc);
                var why = dayReason ?? (blocked ? "BRANCH_CLOSED" : s < minStartLocal ? "TOO_SOON" : isTaken ? "SLOT_TAKEN" : null);
                slots.Add(new SlotAvailability(TimeOnly.FromDateTime(s), TimeOnly.FromDateTime(e), sUtc, eUtc, why is null, p.Label, p.Start, why));
            }
            var total = slots.Count(x => x.PeriodStart == p.Start);
            var free = slots.Count(x => x.PeriodStart == p.Start && x.Available);
            periods.Add(new PeriodAvailability(p.Start, p.End, p.EndsNextDay, p.Label, total, total - free, free,
                startUtc, endUtc, fullyClosed, null, dayReason ?? (fullyClosed ? "BRANCH_CLOSED" : free == 0 ? "PERIOD_FULL" : null)));
        }

        if (dayReason is null && periods.Count == 0) dayReason = "OUTSIDE_HOURS";
        if (dayReason is null && periods.All(p => p.Closed)) dayReason = "BRANCH_CLOSED";
        return new DayAvailability(date, dayReason is not null || periods.All(p => p.Remaining == 0), dayReason, periods, slots);
    }
}
