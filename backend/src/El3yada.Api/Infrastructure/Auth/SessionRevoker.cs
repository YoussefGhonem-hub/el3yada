using El3yada.Api.Auth;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Infrastructure.Auth;

/// <summary>
/// Signs a user out of every device: a new <c>SecurityStamp</c> rejects their access tokens on the next request
/// (<see cref="AuthSetup"/>), refresh tokens are revoked, and push tokens are removed so nothing more is
/// delivered. Used by disable and account deletion.
/// </summary>
public sealed class SessionRevoker(AppDbContext db, TimeProvider clock, AccountStateCache stateCache)
{
    /// <summary>Runs immediately (bulk updates). Call it inside the caller's transaction.</summary>
    public async Task RevokeAllAsync(Guid userId, CancellationToken ct)
    {
        var now = clock.GetUtcNow().UtcDateTime;

        await db.Users.Where(u => u.Id == userId)
            .ExecuteUpdateAsync(u => u
                .SetProperty(x => x.SecurityStamp, Guid.NewGuid())
                .SetProperty(x => x.UpdatedAt, now), ct);

        await db.RefreshTokens.Where(t => t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(u => u.SetProperty(t => t.RevokedAt, now), ct);

        await db.UserDevices.Where(d => d.UserId == userId && d.FcmToken != null)
            .ExecuteUpdateAsync(u => u
                .SetProperty(d => d.FcmToken, (string?)null)
                .SetProperty(d => d.UpdatedAt, now), ct);

        stateCache.Invalidate(userId);
    }
}
