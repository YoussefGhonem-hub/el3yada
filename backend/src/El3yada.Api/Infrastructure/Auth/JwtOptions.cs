using System.ComponentModel.DataAnnotations;

namespace El3yada.Api.Infrastructure.Auth;

/// <summary>
/// JWT settings, section <c>Jwt</c> in configuration. The signing key is a secret:
/// keep it in user secrets (development) or the environment (<c>Jwt__SigningKey</c>), never in the repo.
/// </summary>
public sealed class JwtOptions
{
    public const string Section = "Jwt";

    [Required]
    public string Issuer { get; set; } = "el3yada";

    [Required]
    public string Audience { get; set; } = "el3yada-app";

    /// <summary>HMAC-SHA256 key, at least 32 bytes of UTF-8.</summary>
    [Required, MinLength(32)]
    public string SigningKey { get; set; } = "";

    [Range(1, 1440)]
    public int AccessTokenMinutes { get; set; } = 15;
}
