using System.ComponentModel.DataAnnotations;

namespace El3yada.Api.Configuration;

/// <summary>
/// Outgoing email (section "Email"): password reset (A8) and email verification (A5).
/// Development writes each message as an .eml file to <see cref="PickupDirectory"/>; production sends
/// through SMTP. The SMTP password is a secret: the Email__Smtp__Password environment variable.
/// </summary>
public sealed class EmailOptions : IValidatableObject
{
    public const string SectionName = "Email";

    /// <summary><c>Pickup</c> (write .eml files) or <c>Smtp</c>. Production must use <c>Smtp</c>.</summary>
    [Required]
    public EmailDelivery Delivery { get; set; } = EmailDelivery.Pickup;

    /// <summary>Folder for .eml files when <see cref="Delivery"/> is Pickup. Relative paths use the content root.</summary>
    public string PickupDirectory { get; set; } = "App_Data/mail";

    /// <summary>Sender address, for example <c>no-reply@el3yada.app</c>.</summary>
    [Required, EmailAddress]
    public string FromAddress { get; set; } = "no-reply@el3yada.local";

    [Required]
    public string FromName { get; set; } = "el3yada";

    /// <summary>
    /// The page or app link that opens "set a new password". The API adds <c>?token=…</c>.
    /// It should be an App Link / Universal Link that opens the app (A8).
    /// </summary>
    [Required]
    public string ResetPasswordUrl { get; set; } = "https://localhost:7001/reset-password";

    /// <summary>The link that verifies an email address (A5). The API adds <c>?token=…</c>.</summary>
    [Required]
    public string VerifyEmailUrl { get; set; } = "https://localhost:7001/verify-email";

    public SmtpSettings Smtp { get; set; } = new();

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Delivery == EmailDelivery.Smtp && string.IsNullOrWhiteSpace(Smtp.Host))
        {
            yield return new ValidationResult(
                "Email:Smtp:Host is missing. Production: set Email__Smtp__Host (and Email__Smtp__Port, "
                + "Email__Smtp__Username, Email__Smtp__Password).",
                [nameof(Smtp)]);
        }

        if (Delivery == EmailDelivery.Pickup && string.IsNullOrWhiteSpace(PickupDirectory))
        {
            yield return new ValidationResult("Email:PickupDirectory is missing.", [nameof(PickupDirectory)]);
        }

        if (Smtp.Port is < 1 or > 65535)
        {
            yield return new ValidationResult("Email:Smtp:Port must be between 1 and 65535.", [nameof(Smtp)]);
        }

        // An App Link (https://…) or a custom scheme (el3yada://…); the API appends ?token=….
        foreach (var (name, value) in new[] { (nameof(ResetPasswordUrl), ResetPasswordUrl), (nameof(VerifyEmailUrl), VerifyEmailUrl) })
        {
            if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || !string.IsNullOrEmpty(uri.Query) || !string.IsNullOrEmpty(uri.Fragment))
            {
                yield return new ValidationResult($"Email:{name} must be an absolute link without a query string.", [name]);
            }
        }
    }
}

public enum EmailDelivery
{
    Pickup,
    Smtp,
}

public sealed class SmtpSettings
{
    public string Host { get; set; } = "";

    public int Port { get; set; } = 587;

    /// <summary>
    /// <c>StartTls</c> (port 587, the default), <c>SslOnConnect</c> (port 465) or <c>None</c> (local relay only).
    /// </summary>
    public SmtpSecurity Security { get; set; } = SmtpSecurity.StartTls;

    /// <summary>Leave empty for a relay without authentication.</summary>
    public string Username { get; set; } = "";

    /// <summary>A secret: environment variable Email__Smtp__Password, never appsettings.</summary>
    public string Password { get; set; } = "";
}

public enum SmtpSecurity
{
    StartTls,
    SslOnConnect,
    None,
}
