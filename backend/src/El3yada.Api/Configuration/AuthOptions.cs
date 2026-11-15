using System.ComponentModel.DataAnnotations;

namespace El3yada.Api.Configuration;

/// <summary>
/// Sign-in and account rules (section "Auth"). Token lifetimes for access and refresh tokens are in
/// <see cref="JwtOptions"/>. None of these values is a secret.
/// </summary>
public sealed class AuthOptions
{
    public const string SectionName = "Auth";

    /// <summary>Failed passwords in a row before the account (and the identifier) is locked.</summary>
    [Range(1, 100)]
    public int MaxFailedLogins { get; set; } = 5;

    /// <summary>How long a lock lasts, in minutes.</summary>
    [Range(1, 1440)]
    public int LockoutMinutes { get; set; } = 15;

    /// <summary>Lifetime of the emailed password-reset link (A8), in minutes.</summary>
    [Range(5, 1440)]
    public int PasswordResetTokenMinutes { get; set; } = 60;

    /// <summary>Lifetime of the email verification link (A5), in hours.</summary>
    [Range(1, 720)]
    public int EmailVerificationTokenHours { get; set; } = 48;

    /// <summary>Wait between two verification emails (A5: 60-second cooldown), in seconds.</summary>
    [Range(0, 3600)]
    public int VerificationEmailCooldownSeconds { get; set; } = 60;

    /// <summary>Lifetime of the "log in as" selection token (same number, two accounts), in minutes.</summary>
    [Range(1, 30)]
    public int AccountSelectionMinutes { get; set; } = 5;

    /// <summary>
    /// How long the per-request account check (security stamp, status, role) is cached, in seconds.
    /// Changes made by this API instance clear the cache at once; other instances see them after this delay.
    /// </summary>
    [Range(0, 300)]
    public int UserStateCacheSeconds { get; set; } = 30;
}
