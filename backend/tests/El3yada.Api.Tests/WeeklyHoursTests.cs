using El3yada.Api.ClinicAdmin;

namespace El3yada.Api.Tests;

/// <summary>Working hours (BR-BR2, spec section 11): order, length, overlaps and next-day periods.</summary>
public sealed class WeeklyHoursTests
{
    private static WeeklyPeriod P(int weekday, string start, string end, bool nextDay = false) =>
        new(weekday, TimeOnly.Parse(start), TimeOnly.Parse(end), nextDay);

    private static IReadOnlyList<string> Codes(params WeeklyPeriod[] periods) =>
        WeeklyHours.Check(periods).Select(p => $"{p.Index}:{p.Code}").ToList();

    [Fact]
    public void Morning_and_evening_on_the_same_day_are_fine_even_when_they_touch()
    {
        Assert.Empty(Codes(P(6, "10:00", "14:00"), P(6, "18:00", "22:00")));
        Assert.Empty(Codes(P(6, "10:00", "14:00"), P(6, "14:00", "18:00")));
    }

    [Fact]
    public void Overlapping_periods_on_the_same_day_are_refused()
    {
        Assert.Equal(["1:PERIODS_OVERLAP"], Codes(P(6, "10:00", "14:00"), P(6, "13:59", "16:00")));
        Assert.Equal(["1:PERIODS_OVERLAP"], Codes(P(6, "10:00", "14:00"), P(6, "11:00", "12:00")));
    }

    [Fact]
    public void The_same_hours_on_different_days_do_not_overlap() =>
        Assert.Empty(Codes(P(1, "10:00", "14:00"), P(2, "10:00", "14:00"), P(7, "10:00", "14:00")));

    [Fact]
    public void A_period_can_end_after_midnight_and_belongs_to_its_start_day()
    {
        Assert.Empty(Codes(P(6, "20:00", "01:00", nextDay: true), P(6, "10:00", "14:00")));
        Assert.Equal(300, WeeklyHours.LengthMinutes(TimeOnly.Parse("20:00"), TimeOnly.Parse("01:00"), true));
    }

    [Fact]
    public void A_next_day_period_overlaps_the_next_morning()
    {
        Assert.Equal(["1:PERIODS_OVERLAP"], Codes(P(6, "22:00", "02:00", nextDay: true), P(7, "01:00", "03:00")));
        Assert.Empty(Codes(P(6, "22:00", "02:00", nextDay: true), P(7, "02:00", "03:00")));
    }

    [Fact]
    public void Sunday_night_runs_into_Monday_morning()
    {
        Assert.Equal(["1:PERIODS_OVERLAP"], Codes(P(7, "23:00", "02:00", nextDay: true), P(1, "01:00", "05:00")));
        Assert.Equal(["1:PERIODS_OVERLAP"], Codes(P(1, "01:00", "05:00"), P(7, "23:00", "02:00", nextDay: true)));
    }

    [Fact]
    public void A_period_that_ends_before_it_starts_must_be_marked_next_day()
    {
        Assert.Equal(["0:PERIOD_END_BEFORE_START"], Codes(P(1, "20:00", "01:00")));
        Assert.Equal(["0:PERIOD_END_BEFORE_START"], Codes(P(1, "10:00", "10:00")));
    }

    [Theory]
    [InlineData("10:00", "10:14", false, false)]
    [InlineData("10:00", "10:15", false, true)]
    [InlineData("06:00", "22:00", false, true)]
    [InlineData("06:00", "22:01", false, false)]
    [InlineData("20:00", "12:00", true, true)]
    [InlineData("20:00", "12:01", true, false)]
    [InlineData("10:00", "10:00", true, false)]
    public void A_period_lasts_15_minutes_to_16_hours(string start, string end, bool nextDay, bool ok) =>
        Assert.Equal(ok, Codes(P(3, start, end, nextDay)).Count == 0);

    [Fact]
    public void A_refused_period_is_not_used_for_the_overlap_check() =>
        Assert.Equal(["0:PERIOD_LENGTH_OUT_OF_RANGE"], Codes(P(1, "06:00", "23:00"), P(1, "10:00", "12:00")));

    [Fact]
    public void At_most_ten_periods_a_day()
    {
        var day = Enumerable.Range(0, 11).Select(i => P(4, $"{i + 8:D2}:00", $"{i + 8:D2}:30")).ToArray();
        Assert.Equal(["-1:INVALID_VALUE"], Codes(day));
        Assert.Empty(Codes(day[..10]));
    }

    [Theory]
    [InlineData("2026-11-16", 1)] // Monday
    [InlineData("2026-11-21", 6)] // Saturday
    [InlineData("2026-11-22", 7)] // Sunday
    public void Weekdays_are_iso(string day, int weekday) =>
        Assert.Equal(weekday, WeeklyHours.IsoWeekday(DateOnly.Parse(day)));

    [Theory]
    [InlineData("09:30", true)]
    [InlineData("٠٩:٣٠", true)]
    [InlineData("9:30", false)]
    [InlineData("24:00", false)]
    [InlineData("09:30:00", false)]
    [InlineData(null, false)]
    public void Times_are_HH_mm(string? value, bool ok) => Assert.Equal(ok, WeeklyHours.ParseTime(value) is not null);

    [Fact]
    public void Today_periods_are_the_day_weekday_earliest_first()
    {
        var periods = new[] { P(6, "18:00", "22:00"), P(7, "10:00", "14:00"), P(6, "10:00", "14:00") };
        Assert.Equal(["10:00", "18:00"], WeeklyHours.ForDay(periods, new DateOnly(2026, 11, 21)).Select(p => WeeklyHours.Format(p.Start)));
    }
}

/// <summary>Visit prices fall back per visit type: the branch's, else the doctor's, else none (BR-PR2, BR-PR6).</summary>
public sealed class BranchPricesTests
{
    [Fact]
    public void Branch_prices_fall_back_to_the_doctor_per_type()
    {
        var prices = BranchPricesView.Of(40000, null, 30000, 15000);
        Assert.False(prices.UsesDoctorPrices);
        Assert.Equal(40000, prices.EffectiveExaminationPricePiasters);
        Assert.Equal(15000, prices.EffectiveConsultationPricePiasters);
    }

    [Fact]
    public void No_price_anywhere_is_null()
    {
        var prices = BranchPricesView.Of(null, null, null, 15000);
        Assert.True(prices.UsesDoctorPrices);
        Assert.Null(prices.EffectiveExaminationPricePiasters);
    }
}
