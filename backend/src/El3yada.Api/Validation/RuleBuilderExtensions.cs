using System.Text.RegularExpressions;
using El3yada.Api.Auth;
using FluentValidation;

namespace El3yada.Api.Validation;

/// <summary>Shared FluentValidation rules from spec section 11. Each rule sets its error code.</summary>
public static partial class RuleBuilderExtensions
{
    // Two or more words of letters (Arabic or Latin, with marks such as Arabic diacritics), one space between.
    [GeneratedRegex(@"^[\p{L}\p{M}]+( [\p{L}\p{M}]+)+\z", RegexOptions.CultureInvariant)]
    private static partial Regex FullNamePattern();

    // Same rule as the app's validators.dart: something@something.something, no spaces.
    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+\z", RegexOptions.CultureInvariant)]
    private static partial Regex EmailPattern();

    /// <summary>
    /// An Egyptian mobile number in any accepted form (see <see cref="Validation.EgyptianMobile.Normalize"/>).
    /// Null passes, so add <c>NotEmpty()</c> when the field is required. The endpoint stores
    /// <c>EgyptianMobile.Normalize(value)</c>, the E.164 form.
    /// </summary>
    public static IRuleBuilderOptions<T, string?> EgyptianMobile<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(value => value is null || Validation.EgyptianMobile.Normalize(value) is not null)
            .WithErrorCode(ErrorCodes.InvalidMobile)
            .WithMessage("Enter a valid Egyptian mobile number.");

    /// <summary>Not null, not empty and not only spaces.</summary>
    public static IRuleBuilderOptions<T, TProperty> Required<T, TProperty>(this IRuleBuilder<T, TProperty> rule) =>
        rule.NotEmpty().WithErrorCode(ErrorCodes.Required).WithMessage("This field is required.");

    public static IRuleBuilderOptions<T, string?> MaxChars<T>(this IRuleBuilder<T, string?> rule, int max) =>
        rule.Must(value => value is null || value.Trim().Length <= max)
            .WithErrorCode(ErrorCodes.TooLong)
            .WithMessage($"At most {max} characters.");

    /// <summary>2–60 characters, at least two words, letters and spaces only (Arabic or English).</summary>
    public static IRuleBuilderOptions<T, string?> FullName<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(value => value is null || IsFullName(value))
            .WithErrorCode(ErrorCodes.InvalidName)
            .WithMessage("Enter at least a first and a last name (letters only).");

    /// <summary>A standard email address of at most 254 characters. Store <see cref="Text.NormalizeEmail"/>.</summary>
    public static IRuleBuilderOptions<T, string?> Email<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(value => value is null || IsEmail(value))
            .WithErrorCode(ErrorCodes.InvalidEmail)
            .WithMessage("Enter a valid email address.");

    /// <summary>At least 8 characters with a letter and a number (spec section 11).</summary>
    public static IRuleBuilderOptions<T, string?> StrongPassword<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(value => value is null || Passwords.MeetsPolicy(value))
            .WithErrorCode(ErrorCodes.WeakPassword)
            .WithMessage("The password must be at least 8 characters and contain a letter and a number.");

    /// <summary>A Google Maps link (<see cref="MapLinks.IsGoogleMaps"/>). Null and empty pass.</summary>
    public static IRuleBuilderOptions<T, string?> GoogleMapsLink<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(value => string.IsNullOrWhiteSpace(value) || MapLinks.IsGoogleMaps(value))
            .WithErrorCode(ErrorCodes.InvalidMapLink)
            .WithMessage("Paste a Google Maps link (maps.app.goo.gl/…, google.com/maps/…).");

    /// <summary>One of <paramref name="allowed"/> (case-sensitive, as stored).</summary>
    public static IRuleBuilderOptions<T, string?> OneOf<T>(this IRuleBuilder<T, string?> rule, params string[] allowed) =>
        rule.Must(value => value is null || allowed.Contains(value, StringComparer.Ordinal))
            .WithErrorCode(ErrorCodes.InvalidValue)
            .WithMessage($"Must be one of: {string.Join(", ", allowed)}.");

    public static bool IsFullName(string value)
    {
        var name = Text.CollapseSpaces(value);
        return name.Length is >= 2 and <= 60 && FullNamePattern().IsMatch(name);
    }

    public static bool IsEmail(string value)
    {
        var email = value.Trim();
        return email.Length <= 254 && EmailPattern().IsMatch(email);
    }
}
