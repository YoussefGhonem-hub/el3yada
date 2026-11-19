using System.Text;
using El3yada.Data.Entities;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace El3yada.Api.Infrastructure.Auth;

/// <summary>
/// Issues access tokens. The Phase 1 <c>login</c> and <c>refresh</c> endpoints use this,
/// so every token carries the same claims (<see cref="AuthClaims"/>).
/// </summary>
public sealed class JwtTokenFactory(IOptions<JwtOptions> options, TimeProvider clock)
{
    private readonly JwtOptions _options = options.Value;

    public static SymmetricSecurityKey CreateKey(string signingKey) => new(Encoding.UTF8.GetBytes(signingKey));

    /// <param name="user">The signed-in user.</param>
    /// <param name="doctorId">For assistants: <c>Assistants.DoctorId</c>.</param>
    public (string Token, DateTime ExpiresAt) CreateAccessToken(User user, Guid? doctorId = null)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var expires = now.AddMinutes(_options.AccessTokenMinutes);

        var claims = new Dictionary<string, object>
        {
            [AuthClaims.UserId] = user.Id.ToString(),
            [AuthClaims.Role] = user.Role,
            [AuthClaims.SecurityStamp] = user.SecurityStamp.ToString(),
            [JwtRegisteredClaimNames.Jti] = Guid.NewGuid().ToString(),
        };
        if (user.AdminRole is not null) claims[AuthClaims.AdminRole] = user.AdminRole;
        if (doctorId is not null) claims[AuthClaims.DoctorId] = doctorId.Value.ToString();

        var descriptor = new SecurityTokenDescriptor
        {
            Issuer = _options.Issuer,
            Audience = _options.Audience,
            Claims = claims,
            IssuedAt = now,
            NotBefore = now,
            Expires = expires,
            SigningCredentials = new SigningCredentials(CreateKey(_options.SigningKey), SecurityAlgorithms.HmacSha256),
        };

        return (new JsonWebTokenHandler().CreateToken(descriptor), expires);
    }
}
