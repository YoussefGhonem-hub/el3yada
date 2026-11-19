namespace El3yada.Api.Infrastructure.Time;

/// <summary>Days and months are calculated in Africa/Cairo (spec D11).</summary>
public static class CairoTime
{
    public static readonly TimeZoneInfo Zone = TimeZoneInfo.FindSystemTimeZoneById("Africa/Cairo");

    public static DateTime ToCairo(DateTime utc) =>
        TimeZoneInfo.ConvertTimeFromUtc(DateTime.SpecifyKind(utc, DateTimeKind.Utc), Zone);

    public static DateOnly Today(TimeProvider clock) => DateOnly.FromDateTime(ToCairo(clock.GetUtcNow().UtcDateTime));
}
