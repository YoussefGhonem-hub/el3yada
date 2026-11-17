using El3yada.Api.Audit;
using El3yada.Api.Configuration;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Auth;

/// <summary>
/// Sessions: one sign-in on one device is a refresh-token family.
/// <list type="bullet">
/// <item>Sign-in creates a family and its first refresh token (only the SHA-256 hash is stored).</item>
/// <item>Refresh rotates: the presented token is revoked and replaced by a new one in the same family.</item>
/// <item>A rotated token that comes back is reuse (it was copied): the whole family is revoked.</item>
/// <item>Logout revokes the family and removes the device's push token.</item>
/// <item>A password change rotates Users.SecurityStamp and revokes every family, so other devices are out
/// (their access tokens fail the stamp check on the next request).</item>
/// </list>
/// </summary>
public sealed class SessionService(
    AppDbContext db,
    TokenService tokens,
    AccountStateCache stateCache,
    Auditor auditor,
    TimeProvider time,
    IOptions<JwtOptions> jwtOptions,
    ILogger<SessionService> logger)
{
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>
    /// Starts a session for <paramref name="user"/> (tracked by <see cref="db"/>): a new refresh-token family,
    /// the device's push token, LastLoginAt. Saves all pending changes, including the caller's.
    /// <paramref name="fallbackDeviceId"/> ties the session to a device when <paramref name="device"/> is not sent
    /// (a password change keeps the device of the session that made it).
    /// </summary>
    public async Task<SignedInResponse> SignInAsync(
        User user, DeviceInfo? device, string? fallbackDeviceId, string? ipAddress, CancellationToken cancellationToken)
    {
        var familyId = Guid.NewGuid();
        var (refreshToken, refreshExpires) = AddRefreshToken(user.Id, familyId, device?.DeviceId ?? fallbackDeviceId, ipAddress);
        if (device is not null)
        {
            await RegisterDeviceAsync(user.Id, device, cancellationToken);
        }

        user.LastLoginAt = Now;
        await db.SaveChangesAsync(cancellationToken);

        var account = await AccountState.LoadAsync(db, user.Id, cancellationToken)
            ?? throw new InvalidOperationException("The user disappeared while signing in.");
        var (accessToken, accessExpires) = tokens.CreateAccessToken(account, familyId);
        return new SignedInResponse(SessionView.Of(account, Now), accessToken, accessExpires, refreshToken, refreshExpires);
    }

    /// <summary>Rotates a refresh token. See <see cref="RefreshOutcome"/> for the answers.</summary>
    public async Task<RefreshOutcome> RefreshAsync(string presented, string? ipAddress, CancellationToken cancellationToken)
    {
        var hash = SecretTokens.Hash(presented);
        var current = await db.RefreshTokens.AsNoTracking().SingleOrDefaultAsync(t => t.TokenHash == hash, cancellationToken);
        if (current is null)
        {
            return RefreshOutcome.Invalid;
        }

        if (current.RevokedAt is not null)
        {
            if (current.ReplacedByTokenId is null)
            {
                return RefreshOutcome.Invalid; // logged out or revoked by a password change
            }

            await ReportReuseAsync(current, cancellationToken);
            return RefreshOutcome.Reused;
        }

        if (current.ExpiresAt <= Now)
        {
            await RevokeFamilyAsync(current.FamilyId, cancellationToken);
            return RefreshOutcome.Invalid;
        }

        var account = await AccountState.LoadAsync(db, current.UserId, cancellationToken);
        if (account is null)
        {
            return RefreshOutcome.Invalid;
        }

        if (account.BlockCode is { } blockCode)
        {
            await RevokeFamilyAsync(current.FamilyId, cancellationToken);
            return RefreshOutcome.Blocked(blockCode);
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var (newToken, newExpires) = AddRefreshToken(current.UserId, current.FamilyId, current.DeviceId, ipAddress, out var newId);

        // Only one caller can rotate a token: two refreshes with the same token at once means it was copied.
        var now = Now;
        var rotated = await db.RefreshTokens
            .Where(t => t.Id == current.Id && t.RevokedAt == null)
            .ExecuteUpdateAsync(set => set.SetProperty(t => t.RevokedAt, now).SetProperty(t => t.ReplacedByTokenId, newId), cancellationToken);
        if (rotated == 0)
        {
            await transaction.RollbackAsync(cancellationToken);
            db.ChangeTracker.Clear();
            await ReportReuseAsync(current, cancellationToken);
            return RefreshOutcome.Reused;
        }

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        var (accessToken, accessExpires) = tokens.CreateAccessToken(account, current.FamilyId);
        return RefreshOutcome.Success(new SignedInResponse(SessionView.Of(account, now), accessToken, accessExpires, newToken, newExpires));
    }

    /// <summary>
    /// Ends the session of <paramref name="presented"/> (its whole family) and removes the device's push token.
    /// Unknown tokens are ignored, so logout always succeeds.
    /// </summary>
    public async Task LogoutAsync(string presented, string? deviceId, string? pushToken, CancellationToken cancellationToken)
    {
        var hash = SecretTokens.Hash(presented);
        var token = await db.RefreshTokens.AsNoTracking().SingleOrDefaultAsync(t => t.TokenHash == hash, cancellationToken);
        if (token is null)
        {
            return;
        }

        await RevokeFamilyAsync(token.FamilyId, cancellationToken);

        var device = deviceId ?? token.DeviceId;
        if (device is not null)
        {
            await db.UserDevices.Where(d => d.UserId == token.UserId && d.DeviceId == device).ExecuteDeleteAsync(cancellationToken);
        }

        if (pushToken is not null)
        {
            await db.UserDevices.Where(d => d.UserId == token.UserId && d.FcmToken == pushToken).ExecuteDeleteAsync(cancellationToken);
        }
    }

    public Task<int> RevokeFamilyAsync(Guid familyId, CancellationToken cancellationToken)
    {
        var now = Now;
        return db.RefreshTokens
            .Where(t => t.FamilyId == familyId && t.RevokedAt == null)
            .ExecuteUpdateAsync(set => set.SetProperty(t => t.RevokedAt, now), cancellationToken);
    }

    /// <summary>Revokes every refresh token of the user (all devices).</summary>
    public Task<int> RevokeAllAsync(Guid userId, CancellationToken cancellationToken)
    {
        var now = Now;
        return db.RefreshTokens
            .Where(t => t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(set => set.SetProperty(t => t.RevokedAt, now), cancellationToken);
    }

    /// <summary>
    /// Signs the user out everywhere: a new security stamp (existing access tokens stop working at their next
    /// request) and every refresh token revoked. Saves pending changes.
    /// </summary>
    public async Task SignOutEverywhereAsync(User user, CancellationToken cancellationToken)
    {
        user.SecurityStamp = Guid.NewGuid();
        user.UpdatedAt = Now;
        await db.SaveChangesAsync(cancellationToken);
        await RevokeAllAsync(user.Id, cancellationToken);
        stateCache.Invalidate(user.Id);
    }

    private (string Token, DateTime ExpiresAt) AddRefreshToken(Guid userId, Guid familyId, string? deviceId, string? ipAddress) =>
        AddRefreshToken(userId, familyId, deviceId, ipAddress, out _);

    private (string Token, DateTime ExpiresAt) AddRefreshToken(
        Guid userId, Guid familyId, string? deviceId, string? ipAddress, out Guid id)
    {
        var (token, hash) = SecretTokens.Create();
        var now = Now;
        // Sliding: every rotation gives another RefreshTokenDays, so an active user stays signed in (spec 7.2).
        var expires = now.AddDays(jwtOptions.Value.RefreshTokenDays);
        id = Guid.NewGuid();
        db.RefreshTokens.Add(new RefreshToken
        {
            Id = id,
            UserId = userId,
            FamilyId = familyId,
            DeviceId = deviceId,
            TokenHash = hash,
            CreatedAt = now,
            ExpiresAt = expires,
            CreatedByIp = ipAddress is { Length: <= 45 } ? ipAddress : null,
        });
        return (token, expires);
    }

    private async Task RegisterDeviceAsync(Guid userId, DeviceInfo device, CancellationToken cancellationToken)
    {
        var deviceId = device.DeviceId!;
        var row = await db.UserDevices.SingleOrDefaultAsync(d => d.UserId == userId && d.DeviceId == deviceId, cancellationToken);
        if (row is null)
        {
            row = new UserDevice { Id = Guid.NewGuid(), UserId = userId, DeviceId = deviceId };
            db.UserDevices.Add(row);
        }

        row.Platform = device.Platform!;
        row.AppVersion = device.AppVersion!;
        row.FcmToken = device.PushToken;
        row.UpdatedAt = Now;

        // A push token belongs to one signed-in account: the previous account on this device stops getting pushes.
        if (device.PushToken is { } pushToken)
        {
            await db.UserDevices.Where(d => d.FcmToken == pushToken && d.UserId != userId).ExecuteDeleteAsync(cancellationToken);
        }
    }

    private async Task ReportReuseAsync(RefreshToken token, CancellationToken cancellationToken)
    {
        var revoked = await RevokeFamilyAsync(token.FamilyId, cancellationToken);
        logger.LogWarning(
            "Refresh token reuse for user {UserId}: session {FamilyId} revoked ({Count} active tokens)",
            token.UserId, token.FamilyId, revoked);
        auditor.Add(
            AuditActions.RefreshTokenReuseDetected, AuditTargets.User, token.UserId,
            new { sessionId = token.FamilyId, deviceId = token.DeviceId },
            actor: AuditActor.System);
        await db.SaveChangesAsync(cancellationToken);
    }
}

/// <summary>The answer to a refresh: a new session, or why not.</summary>
public sealed record RefreshOutcome(SignedInResponse? Session, string? ErrorCode)
{
    public static readonly RefreshOutcome Invalid = new(null, ErrorCodes.RefreshTokenInvalid);
    public static readonly RefreshOutcome Reused = new(null, ErrorCodes.RefreshTokenReused);

    public static RefreshOutcome Success(SignedInResponse session) => new(session, null);

    /// <summary>ACCOUNT_DISABLED or CLINIC_NOT_ACTIVE (403).</summary>
    public static RefreshOutcome Blocked(string code) => new(null, code);
}
