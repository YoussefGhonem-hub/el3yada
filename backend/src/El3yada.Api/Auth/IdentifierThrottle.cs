using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Memory;

namespace El3yada.Api.Auth;

/// <summary>
/// Counts attempts per email or mobile number in memory, whether or not an account exists, so a limit
/// reached on an identifier never tells an attacker that the account is real. Used for failed logins
/// (next to the account lockout in Users) and for forgot-password requests. Keys are hashes, so the
/// identifiers themselves are not kept in memory.
/// <para>The counts are per API instance and start again when it restarts; the database lockout is the durable part.</para>
/// </summary>
public sealed class IdentifierThrottle(IMemoryCache cache, TimeProvider time)
{
    private readonly Lock _lock = new();

    private sealed class Entry
    {
        public int Count;
        public DateTimeOffset WindowEnd;
        public DateTimeOffset? BlockedUntil;
    }

    /// <summary>When the identifier is blocked, the time the block ends.</summary>
    public DateTimeOffset? BlockedUntil(string purpose, string identifier)
    {
        var now = time.GetUtcNow();
        return cache.TryGetValue(Key(purpose, identifier), out Entry? entry) && entry!.BlockedUntil > now
            ? entry.BlockedUntil
            : null;
    }

    /// <summary>
    /// Records a failure. After <paramref name="limit"/> failures within <paramref name="window"/>,
    /// the identifier is blocked for <paramref name="window"/>.
    /// </summary>
    public void RecordFailure(string purpose, string identifier, int limit, TimeSpan window)
    {
        var key = Key(purpose, identifier);
        var now = time.GetUtcNow();
        lock (_lock)
        {
            if (!cache.TryGetValue(key, out Entry? entry) || entry!.WindowEnd <= now)
            {
                entry = new Entry { WindowEnd = now + window };
            }

            entry.Count++;
            if (entry.Count >= limit)
            {
                entry.BlockedUntil = now + window;
                entry.Count = 0;
                entry.WindowEnd = now + window;
            }

            cache.Set(key, entry, (entry.BlockedUntil ?? entry.WindowEnd) + TimeSpan.FromMinutes(1));
        }
    }

    /// <summary>
    /// Counts one use and says whether it is within <paramref name="limit"/> per <paramref name="window"/>
    /// (forgot password: 3 per hour per identifier).
    /// </summary>
    public bool TryAcquire(string purpose, string identifier, int limit, TimeSpan window)
    {
        var key = Key(purpose, identifier);
        var now = time.GetUtcNow();
        lock (_lock)
        {
            if (!cache.TryGetValue(key, out Entry? entry) || entry!.WindowEnd <= now)
            {
                entry = new Entry { WindowEnd = now + window };
            }

            if (entry.Count >= limit)
            {
                return false;
            }

            entry.Count++;
            cache.Set(key, entry, entry.WindowEnd);
            return true;
        }
    }

    public void Reset(string purpose, string identifier) => cache.Remove(Key(purpose, identifier));

    private static string Key(string purpose, string identifier) =>
        $"throttle:{purpose}:{Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identifier)))}";
}
