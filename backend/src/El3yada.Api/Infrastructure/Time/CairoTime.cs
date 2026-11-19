namespace El3yada.Api.Infrastructure.Time;

/// <summary>Days and months are calculated in Africa/Cairo (spec D11).</summary>
public static class CairoTime
{
    public static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById("Africa/Cairo");

    public static DateTime ToCairo(DateTime utc) =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Zone);

    public static DateOnly Today(TimeProvider clock) => DateOnly.FromDateTime(ToCairo(clock.GetUtcNow().UtcDateTime));

    public static DateTime Now(TimeProvider clock) => ToCairo(clock.GetUtcNow().UtcDateTime);

    /// <summary>
    /// A Cairo wall-clock time to UTC (BR-AP19: slots are built in local time, so 10:00 stays 10:00
    /// across daylight-saving changes). A time skipped by a DST jump moves forward by the gap.
    /// </summary>
    public static DateTime ToUtc(DateOnly date, TimeOnly time, bool nextDay = false)
    {
        var local = date.ToDateTime(time, DateTimeKind.Unspecified);
        if (nextDay) local = local.AddDays(1);
        while (Zone.IsInvalidTime(local)) local = local.AddMinutes(30);
        return TimeZoneInfo.ConvertTimeToUtc(local, Zone);
    }

    public static DateTime ToUtc(DateTime local)
    {
        var unspecified = DateTime.SpecifyKind(local, DateTimeKind.Unspecified);
        while (Zone.IsInvalidTime(unspecified)) unspecified = unspecified.AddMinutes(30);
        return TimeZoneInfo.ConvertTimeToUtc(unspecified, Zone);
    }

    /// <summary>ISO weekday: 1 = Monday … 7 = Sunday (spec 8, branchPeriods).</summary>
    public static int IsoWeekday(DateOnly date) => date.DayOfWeek == DayOfWeek.Sunday ? 7 : (int)date.DayOfWeek;
}
