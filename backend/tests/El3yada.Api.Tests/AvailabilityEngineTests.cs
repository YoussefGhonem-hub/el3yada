using El3yada.Api.Features.Appointments;
using El3yada.Api.Infrastructure.Time;

namespace El3yada.Api.Tests;

/// <summary>BR-AP1: the availability rules, without a database.</summary>
public sealed class AvailabilityEngineTests
{
    private static readonly DateOnly Day = new(2026, 12, 5);   // a Saturday
    private static readonly DateTime NowUtc = CairoTime.ToUtc(new DateOnly(2026, 12, 4), new TimeOnly(12, 0));   // the day before, noon

    private static BookingSettings Settings(string mode = "queue", int capacity = 3, int notice = 60, bool sameDay = true, int window = 30, int examSlots = 1) =>
        new(mode, 15, examSlots, 1, capacity, 10, true, true, window, notice, sameDay, 120, 2, 1, 3, 90, [1440, 120], true);

    private static readonly PeriodTemplate Evening = new(new TimeOnly(18, 0), new TimeOnly(20, 0), false, "مساءً", null);

    private static ExistingBooking Booking(TimeOnly period, string status = "confirmed", DateTime? startUtc = null, DateTime? endUtc = null) =>
        new(Guid.NewGuid(), Day, period, startUtc ?? CairoTime.ToUtc(Day, period), endUtc, status, false);

    [Fact]
    public void Queue_period_counts_places_and_gives_no_time_before_check_in()
    {
        var day = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", true, NowUtc), Settings(), "active",
            [Evening], null, [], [Booking(Evening.Start), Booking(Evening.Start, "completed"), Booking(Evening.Start, "cancelled")]);

        var p = Assert.Single(day.Periods);
        Assert.Equal(3, p.Capacity);
        Assert.Equal(2, p.Booked);                                // cancelled places don't count
        Assert.Equal(1, p.Remaining);
        Assert.Null(day.Reason);
    }

    [Fact]
    public void Full_period_reports_period_full()
    {
        var day = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", true, NowUtc), Settings(capacity: 1), "active",
            [Evening], null, [], [Booking(Evening.Start)]);
        Assert.Equal("PERIOD_FULL", day.Periods[0].Unavailable);
        Assert.True(day.Closed);
    }

    [Fact]
    public void Special_date_replaces_the_week_and_closures_close_periods()
    {
        var special = new PeriodTemplate(new TimeOnly(10, 0), new TimeOnly(12, 0), false, null, 5);
        var day = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", true, NowUtc), Settings(), "active",
            [Evening], [special], [], []);
        Assert.Equal(new TimeOnly(10, 0), Assert.Single(day.Periods).Start);
        Assert.Equal(5, day.Periods[0].Capacity);

        var closed = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", true, NowUtc), Settings(), "active",
            [Evening], null, [new ClosureWindow(Day.ToDateTime(new TimeOnly(19, 0)), Day.ToDateTime(new TimeOnly(19, 30)))], []);
        Assert.Equal("BRANCH_CLOSED", closed.Periods[0].Unavailable);
        Assert.Equal("BRANCH_CLOSED", closed.Reason);

        var noHours = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", true, NowUtc), Settings(), "active", [], null, [], []);
        Assert.Equal("OUTSIDE_HOURS", noHours.Reason);
    }

    [Theory]
    [InlineData(31, true, "TOO_FAR_AHEAD")]
    [InlineData(1, false, null)]
    public void Patient_limits_apply_but_not_to_staff(int daysAhead, bool sameDay, string? reason)
    {
        var date = new DateOnly(2026, 12, 4).AddDays(daysAhead);
        var weekly = new[] { Evening };
        var patient = AvailabilityEngine.ForDay(new AvailabilityRequest(date, "examination", true, NowUtc), Settings(sameDay: sameDay), "active", weekly, null, [], []);
        Assert.Equal(reason, patient.Reason);
        var staff = AvailabilityEngine.ForDay(new AvailabilityRequest(date, "examination", false, NowUtc), Settings(sameDay: sameDay), "active", weekly, null, [], []);
        Assert.Null(staff.Reason);
    }

    [Fact]
    public void Same_day_off_and_minimum_notice_for_patients()
    {
        var today = new DateOnly(2026, 12, 4);
        var sameDayOff = AvailabilityEngine.ForDay(new AvailabilityRequest(today, "examination", true, NowUtc), Settings(sameDay: false), "active", [Evening], null, [], []);
        Assert.Equal("SAME_DAY_OFF", sameDayOff.Reason);

        // 17:30 period, now 12:00, notice 6 hours: too soon for a patient, fine for staff.
        var soon = new PeriodTemplate(new TimeOnly(17, 30), new TimeOnly(19, 0), false, null, null);
        var patient = AvailabilityEngine.ForDay(new AvailabilityRequest(today, "examination", true, NowUtc), Settings(notice: 360), "active", [soon], null, [], []);
        Assert.Equal("TOO_SOON", patient.Periods[0].Unavailable);
        var staff = AvailabilityEngine.ForDay(new AvailabilityRequest(today, "examination", false, NowUtc), Settings(notice: 360), "active", [soon], null, [], []);
        Assert.Null(staff.Periods[0].Unavailable);
    }

    [Fact]
    public void Timed_slots_skip_taken_ones_and_exams_can_take_two_slots()
    {
        var taken = CairoTime.ToUtc(Day, new TimeOnly(18, 15));
        var day = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", true, NowUtc), Settings("timed"), "active",
            [Evening], null, [], [Booking(Evening.Start, startUtc: taken, endUtc: taken.AddMinutes(15))]);
        Assert.Equal(8, day.Slots.Count);   // 18:00–20:00 in 15-minute slots
        Assert.Equal("SLOT_TAKEN", day.Slots.Single(s => s.Start == new TimeOnly(18, 15)).Unavailable);
        Assert.True(day.Slots.Single(s => s.Start == new TimeOnly(18, 30)).Available);

        // A two-slot examination can't start at 18:00, because 18:15 is taken.
        var exam = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", true, NowUtc), Settings("timed", examSlots: 2), "active",
            [Evening], null, [], [Booking(Evening.Start, startUtc: taken, endUtc: taken.AddMinutes(15))]);
        Assert.Equal("SLOT_TAKEN", exam.Slots.Single(s => s.Start == new TimeOnly(18, 0)).Unavailable);
        Assert.Equal(new TimeOnly(19, 0), exam.Slots.Single(s => s.Start == new TimeOnly(18, 30)).End);
    }

    [Fact]
    public void A_period_after_midnight_belongs_to_its_start_day()
    {
        var late = new PeriodTemplate(new TimeOnly(22, 0), new TimeOnly(1, 0), true, null, null);
        var day = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", false, NowUtc), Settings("timed"), "active", [late], null, [], []);
        Assert.Equal(12, day.Slots.Count);
        Assert.Equal(CairoTime.ToUtc(Day, new TimeOnly(1, 0), nextDay: true), day.Periods[0].EndUtc);
    }

    [Fact]
    public void Closed_branch_is_closed()
    {
        var day = AvailabilityEngine.ForDay(new AvailabilityRequest(Day, "examination", false, NowUtc), Settings(), "temporarilyClosed", [Evening], null, [], []);
        Assert.Equal("BRANCH_CLOSED", day.Reason);
    }
}
