using System.Security.Claims;
using System.Text;
using El3yada.Api.Configuration;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace El3yada.Api.Auth;

/// <summary>
/// Signs and checks JWTs (HMAC-SHA256 with Jwt:SigningKey): the access token, and the short-lived
/// selection token of the "log in as" step. They have different audiences, so one can never be used as the other.
/// </summary>
public sealed class TokenService(
    IOptions<JwtOptions> jwtOptions, IOptions<AuthOptions> authOptions, TimeProvider time, IMemoryCache cache)
{
    private readonly JwtOptions _jwt = jwtOptions.Value;
    private readonly JsonWebTokenHandler _handler = new() { SetDefaultTimesOnTokenCreation = false };

    private SymmetricSecurityKey SigningKey => new(Encoding.UTF8.GetBytes(_jwt.SigningKey));

    private string SelectionAudience => $"{_jwt.Audience}/account-selection";

    /// <summary>The parameters JwtBearer uses to check access tokens.</summary>
    public static TokenValidationParameters AccessTokenParameters(JwtOptions jwt) => new()
    {
        ValidIssuer = jwt.Issuer,
        ValidAudience = jwt.Audience,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
        ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
        ValidateIssuerSigningKey = true,
        RequireExpirationTime = true,
        ClockSkew = TimeSpan.FromSeconds(30),
        NameClaimType = ClaimNames.Subject,
        RoleClaimType = ClaimNames.Role,
    };

    public (string Token, DateTime ExpiresAt) CreateAccessToken(AccountState account, Guid sessionFamilyId)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var expires = now.AddMinutes(_jwt.AccessTokenMinutes);
        var claims = new Dictionary<string, object>
        {
            [ClaimNames.Subject] = account.UserId.ToString(),
            [ClaimNames.Role] = account.Role,
            [ClaimNames.SecurityStamp] = account.StampHash,
            [ClaimNames.Session] = sessionFamilyId.ToString(),
            [ClaimNames.TokenId] = Guid.NewGuid().ToString("N"),
        };
        if (account.AdminRole is not null)
        {
            claims[ClaimNames.AdminRole] = account.AdminRole;
        }

        if (account.DoctorId is { } doctorId)
        {
            claims[ClaimNames.DoctorId] = doctorId.ToString();
        }

        var token = _handler.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = _jwt.Issuer,
            Audience = _jwt.Audience,
            IssuedAt = now,
            NotBefore = now,
            Expires = expires,
            Claims = claims,
            SigningCredentials = new SigningCredentials(SigningKey, SecurityAlgorithms.HmacSha256),
        });
        return (token, expires);
    }

    /// <summary>
    /// The "log in as" token: proof that the password matched every listed account. It names the accounts
    /// and their security stamps, lasts Auth:AccountSelectionMinutes, and can be used once.
    /// </summary>
    public (string Token, DateTime ExpiresAt) CreateSelectionToken(IEnumerable<AccountState> accounts)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var expires = now.AddMinutes(authOptions.Value.AccountSelectionMinutes);
        var token = _handler.CreateToken(new SecurityTokenDescriptor
        {
            Issuer = _jwt.Issuer,
            Audience = SelectionAudience,
            IssuedAt = now,
            NotBefore = now,
            Expires = expires,
            Claims = new Dictionary<string, object>
            {
                [ClaimNames.TokenId] = Guid.NewGuid().ToString("N"),
                // "userId.stampHash,userId.stampHash"
                ["accounts"] = string.Join(',', accounts.Select(a => $"{a.UserId:N}.{a.StampHash}")),
            },
            SigningCredentials = new SigningCredentials(SigningKey, SecurityAlgorithms.HmacSha256),
        });
        return (token, expires);
    }

    /// <summary>
    /// Checks a selection token and marks it used. Returns the (user ID, stamp hash) pairs it names,
    /// or null when it is invalid, expired or already used.
    /// </summary>
    public async Task<IReadOnlyList<(Guid UserId, string StampHash)>?> RedeemSelectionTokenAsync(string token)
    {
        var parameters = AccessTokenParameters(_jwt);
        parameters.ValidAudience = SelectionAudience;
        parameters.LifetimeValidator = (notBefore, expires, _, _) =>
        {
            var now = time.GetUtcNow().UtcDateTime;
            return expires is { } e && e > now.AddSeconds(-30) && (notBefore is not { } nb || nb <= now.AddSeconds(30));
        };

        var result = await _handler.ValidateTokenAsync(token, parameters);
        if (!result.IsValid
            || result.ClaimsIdentity.FindFirst(ClaimNames.TokenId)?.Value is not { } tokenId
            || result.ClaimsIdentity.FindFirst("accounts")?.Value is not { } accounts)
        {
            return null;
        }

        // One use only: remember the ID until the token would expire anyway.
        var usedKey = $"selection-token-used:{tokenId}";
        if (cache.TryGetValue(usedKey, out _))
        {
            return null;
        }

        cache.Set(usedKey, true, TimeSpan.FromMinutes(authOptions.Value.AccountSelectionMinutes + 1));

        var pairs = new List<(Guid, string)>();
        foreach (var entry in accounts.Split(',', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = entry.Split('.', 2);
            if (parts.Length != 2 || !Guid.TryParseExact(parts[0], "N", out var userId))
            {
                return null;
            }

            pairs.Add((userId, parts[1]));
        }

        return pairs;
    }

    /// <summary>The session family named in an access token (<c>sid</c>), if any.</summary>
    public static Guid? SessionOf(ClaimsPrincipal user) =>
        Guid.TryParse(user.FindFirstValue(ClaimNames.Session), out var id) ? id : null;
}
