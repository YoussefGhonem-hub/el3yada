using El3yada.Api.Auth;
using El3yada.Data.Entities;

namespace El3yada.Api.Infrastructure.Auth;

/// <summary>
/// Issues an access token for a user without a password check, with the same claims as <c>login</c>
/// (it wraps <see cref="TokenService"/>). Used by the Development token endpoint and by the API tests.
/// </summary>
public sealed class JwtTokenFactory(TokenService tokens)
{
    /// <param name="user">The user to sign in as.</param>
    /// <param name="doctorId">For assistants: <c>Assistants.DoctorId</c>.</param>
    public (string Token, DateTime ExpiresAt) CreateAccessToken(User user, Guid? doctorId = null) =>
        tokens.CreateAccessToken(
            new AccountState
            {
                UserId = user.Id,
                Role = user.Role,
                AdminRole = user.AdminRole,
                UserStatus = user.Status,
                SecurityStamp = user.SecurityStamp,
                MustChangePassword = user.MustChangePassword,
                DisplayName = user.DisplayName,
                Locale = user.Locale,
                ThemeMode = user.ThemeMode,
                DoctorId = user.Role == Roles.Doctor ? user.Id : doctorId,
            },
            Guid.NewGuid());
}
