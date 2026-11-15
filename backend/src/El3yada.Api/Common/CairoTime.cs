using System.Globalization;

namespace El3yada.Api.Common;

/// <summary>
/// Clinic dates are Cairo dates (spec 6.5: billing time zone Africa/Cairo, fixed). Times are stored in UTC;
/// DayKey (DATE) and MonthKey ('YYYY-MM') are the Cairo calendar day and month of that UTC time, whatever
/// the device's time zone (AC-4). Egypt has daylight saving time, so never add a fixed +2 or +3 hours.
/// </summary>
public static class CairoTime
{
    public static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById("Africa/Cairo");

    public static DateTime ToCairo(DateTime utc) =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Zone);

    /// <summary>The Cairo calendar day of a UTC time (Sessions.DayKey).</summary>
    public static DateOnly DayOf(DateTime utc) => DateOnly.FromDateTime(ToCairo(utc));

    public static DateOnly Today(TimeProvider time) => DayOf(time.GetUtcNow().UtcDateTime);

    /// <summary>'YYYY-MM' (Sessions.MonthKey, Invoices.MonthKey).</summary>
    public static string MonthKey(DateOnly day) => day.ToString("yyyy-MM", CultureInfo.InvariantCulture);

    public static string MonthKey(DateTime utc) => MonthKey(DayOf(utc));

    /// <summary>Reads 'YYYY-MM' as the first day of that month, or null when it isn't one.</summary>
    public static DateOnly? ParseMonthKey(string? monthKey) =>
        DateOnly.TryParseExact(monthKey + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day)
            ? day
            : null;

    /// <summary>
    /// The UTC instant a Cairo day starts. When the clocks go forward at midnight, the day starts at the first
    /// minute that exists (01:00).
    /// </summary>
    public static DateTime StartUtc(DateOnly day)
    {
        var local = day.ToDateTime(TimeOnly.MinValue, DateTimeKind.Unspecified);
        while (Zone.IsInvalidTime(local))
        {
            local = local.AddMinutes(30);
        }

        return TimeZoneInfo.ConvertTimeToUtc(local, Zone);
    }

    /// <summary>[start, end) of a Cairo day in UTC, for range queries on UTC columns.</summary>
    public static (DateTime StartUtc, DateTime EndUtc) DayRangeUtc(DateOnly day) => (StartUtc(day), StartUtc(day.AddDays(1)));
}
