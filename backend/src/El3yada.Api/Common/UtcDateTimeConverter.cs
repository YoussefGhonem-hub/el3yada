using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace El3yada.Api.Common;

/// <summary>
/// Every timestamp in the API is UTC (spec section 8). SQL Server returns datetime2 values without a kind,
/// so this writes them with a trailing "Z" (<c>2026-11-15T10:00:00.000Z</c>), and turns any offset the app
/// sends into UTC.
/// </summary>
public sealed class UtcDateTimeConverter : JsonConverter<DateTime>
{
    public override DateTime Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        var text = reader.GetString();
        if (!DateTimeOffset.TryParse(text, CultureInfo.InvariantCulture, DateTimeStyles.AssumeUniversal, out var value))
        {
            throw new JsonException("Not a valid date and time.");
        }

        return value.UtcDateTime;
    }

    public override void Write(Utf8JsonWriter writer, DateTime value, JsonSerializerOptions options)
    {
        var utc = value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
        };
        writer.WriteStringValue(utc.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", CultureInfo.InvariantCulture));
    }
}
