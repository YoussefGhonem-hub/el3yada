using System.Buffers.Binary;
using System.Security.Cryptography;

namespace El3yada.Api.Infrastructure.Ids;

/// <summary>
/// New primary keys. The EF model does not generate GUID keys (they are <c>ValueGeneratedNever</c>),
/// so every insert must set <c>Id</c> itself; an unset key would be <see cref="Guid.Empty"/>.
/// <para>
/// The ids are ordered the way SQL Server sorts <c>uniqueidentifier</c> (it compares the last six
/// bytes first), like <c>NEWSEQUENTIALID()</c>: new rows go to the end of the clustered index instead of
/// splitting pages. The first ten bytes are random, so ids can't be guessed.
/// </para>
/// </summary>
public static class NewId
{
    public static Guid Next() => Next(DateTimeOffset.UtcNow);

    public static Guid Next(DateTimeOffset now)
    {
        Span<byte> bytes = stackalloc byte[16];
        RandomNumberGenerator.Fill(bytes[..10]);

        // Milliseconds since 1970 in the last six bytes, big-endian (enough until the year 10889).
        Span<byte> time = stackalloc byte[8];
        BinaryPrimitives.WriteInt64BigEndian(time, now.ToUnixTimeMilliseconds());
        time[2..].CopyTo(bytes[10..]);

        return new Guid(bytes);
    }
}
