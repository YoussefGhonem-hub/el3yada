using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace El3yada.Api.Infrastructure.Json;

/// <summary>
/// Every timestamp in the database is UTC, but EF Core reads it back with <c>Kind = Unspecified</c>,
/// which would serialize without the trailing <c>Z</c> and be read as local time by the app.
/// This writes every <see cref="DateTime"/> as ISO 8601 UTC (<c>2026-11-19T10:15:00.000Z</c>).
/// </summary>
public sealed class UtcDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var value = reader.GetDateTime();
        return value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
        };
    }

    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
    {
        var utc = value.Kind == DateTimeKind.Local ? value.ToUniversalTime() : DateTime.SpecifyKind(value, DateTimeKind.Utc);
        writer.WriteStringValue(utc.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", CultureInfo.InvariantCulture));
    }
}
