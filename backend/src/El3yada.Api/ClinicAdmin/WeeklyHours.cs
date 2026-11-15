using System.Globalization;
using El3yada.Api.Validation;

namespace El3yada.Api.ClinicAdmin;

/// <summary>One weekly working period (BranchPeriods). <see cref="Weekday"/> is ISO: 1 = Monday … 7 = Sunday.</summary>
public sealed record WeeklyPeriod(int Weekday, TimeOnly Start, TimeOnly End, bool EndsNextDay, string? Label = null, int? Capacity = null);

/// <summary>A rule a period breaks: which period (its index in the list), which field, the error code.</summary>
public sealed record PeriodProblem(int Index, string Field, string Code, string Message);

/// <summary>
/// Weekly working hours (BR-BR2, spec section 11 "Working hours"). A period may end after midnight
/// (<see cref="WeeklyPeriod.EndsNextDay"/>, for example 20:00–01:00); it still belongs to the day it starts.
/// Times are Cairo local times, "HH:mm".
/// </summary>
public static class WeeklyHours
{
    public const int MinLengthMinutes = 15;
    public const int MaxLengthMinutes = 16 * 60;
    public const int MaxPeriodsPerDay = 10;
    public const int MinCapacity = 1;
    public const int MaxCapacity = 200;
    public const int MaxLabelChars = 30;

    private const int MinutesPerDay = 24 * 60;
    private const int MinutesPerWeek = 7 * MinutesPerDay;

    /// <summary>ISO weekday of a date: 1 = Monday … 7 = Sunday (BranchPeriods.Weekday).</summary>
    public static int IsoWeekday(DateOnly day) => day.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)day.DayOfWeek;

    /// <summary>Reads "HH:mm" (Arabic-Indic digits allowed), or null.</summary>
    public static TimeOnly? ParseTime(string? value) =>
        value is not null
        && TimeOnly.TryParseExact(
            EgyptianMobile.NormalizeDigits(value.Trim()), "HH:mm", CultureInfo.InvariantCulture, DateTimeStyles.None, out var time)
            ? time
            : null;

    public static string Format(TimeOnly time) => time.ToString("HH:mm", CultureInfo.InvariantCulture);

    /// <summary>How long a period lasts, in minutes. A next-day period runs past midnight.</summary>
    public static int LengthMinutes(TimeOnly start, TimeOnly end, bool endsNextDay)
    {
        var from = Minutes(start);
        var to = Minutes(end);
        return endsNextDay ? MinutesPerDay - from + to : to - from;
    }

    /// <summary>
    /// The spec section 11 rules for a whole week, in list order: each period ends after it starts (or ends the
    /// next day), lasts 15 minutes to 16 hours, and no two periods overlap. Overlaps are checked on the real
    /// week, so Saturday 20:00–01:00 (next day) overlaps Sunday 00:30–03:00, and Sunday's late period can
    /// overlap Monday morning. Periods that touch (one ends at 14:00, the next starts at 14:00) are fine.
    /// </summary>
    public static IReadOnlyList<PeriodProblem> Check(IReadOnlyList<WeeklyPeriod> periods)
    {
        var problems = new List<PeriodProblem>();
        var valid = new List<(int Index, int Start, int End)>();
        for (var i = 0; i < periods.Count; i++)
        {
            var period = periods[i];
            var length = LengthMinutes(period.Start, period.End, period.EndsNextDay);
            if (!period.EndsNextDay && length <= 0)
            {
                problems.Add(new PeriodProblem(i, "endLocal", ErrorCodes.PeriodEndBeforeStart,
                    "The period ends before it starts. Mark it as ending the next day if it runs past midnight."));
                continue;
            }

            if (length is < MinLengthMinutes or > MaxLengthMinutes)
            {
                problems.Add(new PeriodProblem(i, "endLocal", ErrorCodes.PeriodLengthOutOfRange,
                    "A period lasts between 15 minutes and 16 hours."));
                continue;
            }

            var start = ((period.Weekday - 1) * MinutesPerDay) + Minutes(period.Start);
            var end = start + length;
            var clash = valid.FindIndex(other => Overlap(other.Start, other.End, start, end));
            if (clash >= 0)
            {
                problems.Add(new PeriodProblem(i, "", ErrorCodes.PeriodsOverlap,
                    $"This period overlaps period {valid[clash].Index + 1}."));
                continue;
            }

            valid.Add((i, start, end));
        }

        foreach (var day in periods.GroupBy(p => p.Weekday).Where(day => day.Count() > MaxPeriodsPerDay))
        {
            problems.Add(new PeriodProblem(-1, "", ErrorCodes.InvalidValue, $"At most {MaxPeriodsPerDay} periods per day (weekday {day.Key})."));
        }

        return problems;
    }

    /// <summary>The periods that belong to <paramref name="day"/> (its weekday), earliest first.</summary>
    public static IReadOnlyList<WeeklyPeriod> ForDay(IEnumerable<WeeklyPeriod> periods, DateOnly day)
    {
        var weekday = IsoWeekday(day);
        return periods.Where(p => p.Weekday == weekday).OrderBy(p => p.Start).ToList();
    }

    private static int Minutes(TimeOnly time) => (time.Hour * 60) + time.Minute;

    // Half-open ranges on a circular week: Sunday's late period can run into Monday morning.
    private static bool Overlap(int aStart, int aEnd, int bStart, int bEnd) =>
        Linear(aStart, aEnd, bStart, bEnd)
        || Linear(aStart, aEnd, bStart + MinutesPerWeek, bEnd + MinutesPerWeek)
        || Linear(aStart + MinutesPerWeek, aEnd + MinutesPerWeek, bStart, bEnd);

    private static bool Linear(int aStart, int aEnd, int bStart, int bEnd) => aStart < bEnd && bStart < aEnd;
}
