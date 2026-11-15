using System.ComponentModel.DataAnnotations;

namespace El3yada.Api.Configuration;

/// <summary>
/// Limits for the public endpoints (section "RateLimits", spec section 12). Requests over a limit get
/// 429 with code TOO_MANY_ATTEMPTS and a Retry-After header. Per-IP limits use the connection's IP:
/// behind a reverse proxy, enable forwarded headers so the client IP is used (backend/README.md).
/// </summary>
public sealed class RateLimitOptions
{
    public const string SectionName = "RateLimits";

    /// <summary><c>login</c> and <c>selectAccount</c>: requests per IP per minute.</summary>
    [Range(1, 100_000)]
    public int LoginPerMinute { get; set; } = 10;

    /// <summary>Forgot password (email and mobile): requests per IP per 15 minutes.</summary>
    [Range(1, 100_000)]
    public int PasswordResetPer15Minutes { get; set; } = 5;

    /// <summary>Forgot password: requests per email or mobile number per hour, whether or not it has an account.</summary>
    [Range(1, 100_000)]
    public int PasswordResetPerIdentifierPerHour { get; set; } = 3;

    /// <summary><c>completeDoctorRegistration</c>: requests per IP per hour.</summary>
    [Range(1, 100_000)]
    public int RegistrationPerHour { get; set; } = 10;

    /// <summary><c>refresh</c> and <c>logout</c>: requests per IP per minute.</summary>
    [Range(1, 100_000)]
    public int RefreshPerMinute { get; set; } = 60;

    /// <summary>Endpoints that take an emailed token (reset password, verify email): requests per IP per 15 minutes.</summary>
    [Range(1, 100_000)]
    public int EmailTokenPer15Minutes { get; set; } = 20;
}
