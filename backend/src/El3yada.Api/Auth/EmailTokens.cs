using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Auth;

/// <summary>UserTokens.Purpose values.</summary>
public static class UserTokenPurposes
{
    public const string PasswordReset = "passwordReset";
    public const string EmailVerify = "emailVerify";
}

/// <summary>
/// Single-use, time-limited tokens sent by email (UserTokens): password reset (A8) and email verification (A5).
/// Only the SHA-256 hash is stored. Issuing a new token deletes the user's unused tokens of the same purpose,
/// so only the latest link works.
/// </summary>
public sealed class EmailTokens(AppDbContext db, TimeProvider time)
{
    /// <summary>Adds a token (saved with the caller's SaveChanges) and returns the raw value for the link.</summary>
    public async Task<string> IssueAsync(Guid userId, string purpose, TimeSpan lifetime, CancellationToken cancellationToken)
    {
        await db.UserTokens
            .Where(t => t.UserId == userId && t.Purpose == purpose && t.UsedAt == null)
            .ExecuteDeleteAsync(cancellationToken);

        var (token, hash) = SecretTokens.Create();
        var now = time.GetUtcNow().UtcDateTime;
        db.UserTokens.Add(new UserToken
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Purpose = purpose,
            TokenHash = hash,
            CreatedAt = now,
            ExpiresAt = now + lifetime,
        });
        return token;
    }

    /// <summary>
    /// Checks a token and marks it used (saved with the caller's SaveChanges). On success, returns the tracked
    /// row (its <c>User</c> loaded); otherwise the error code.
    /// </summary>
    public async Task<(UserToken? Token, string? ErrorCode)> RedeemAsync(
        string token, string purpose, CancellationToken cancellationToken)
    {
        var hash = SecretTokens.Hash(token);
        var row = await db.UserTokens.Include(t => t.User)
            .SingleOrDefaultAsync(t => t.TokenHash == hash && t.Purpose == purpose, cancellationToken);
        if (row is null)
        {
            return (null, ErrorCodes.EmailTokenInvalid);
        }

        if (row.UsedAt is not null)
        {
            return (null, ErrorCodes.EmailTokenUsed);
        }

        var now = time.GetUtcNow().UtcDateTime;
        if (row.ExpiresAt <= now)
        {
            return (null, ErrorCodes.EmailTokenExpired);
        }

        row.UsedAt = now;
        return (row, null);
    }

    /// <summary>When the user's latest token of this purpose was issued (for the resend cooldown).</summary>
    public Task<DateTime?> LastIssuedAsync(Guid userId, string purpose, CancellationToken cancellationToken) =>
        db.UserTokens.Where(t => t.UserId == userId && t.Purpose == purpose)
            .MaxAsync(t => (DateTime?)t.CreatedAt, cancellationToken);
}
