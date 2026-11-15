using System.ComponentModel.DataAnnotations;
using System.Text;

namespace El3yada.Api.Configuration;

/// <summary>
/// Access and refresh token settings (section "Jwt"). The signing key is a secret: user-secrets in
/// Development, the Jwt__SigningKey environment variable in production. Never put it in appsettings*.json.
/// </summary>
public sealed class JwtOptions : IValidatableObject
{
    public const string SectionName = "Jwt";

    /// <summary>HMAC-SHA256 needs a key of at least 256 bits.</summary>
    public const int MinSigningKeyBytes = 32;

    [Required]
    public string Issuer { get; set; } = "";

    [Required]
    public string Audience { get; set; } = "";

    public string SigningKey { get; set; } = "";

    [Range(1, 1440)]
    public int AccessTokenMinutes { get; set; } = 15;

    [Range(1, 365)]
    public int RefreshTokenDays { get; set; } = 30;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        // The message never contains the key itself.
        if (Encoding.UTF8.GetByteCount(SigningKey ?? "") < MinSigningKeyBytes)
        {
            yield return new ValidationResult(
                $"Jwt:SigningKey is missing or shorter than {MinSigningKeyBytes} bytes. "
                + "Development: dotnet user-secrets set Jwt:SigningKey <random value> --project src/El3yada.Api. "
                + "Production: set the Jwt__SigningKey environment variable.",
                [nameof(SigningKey)]);
        }
    }
}
