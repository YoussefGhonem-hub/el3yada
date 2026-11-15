using System.Text.RegularExpressions;

namespace El3yada.Api.Validation;

/// <summary>
/// Clinic and support phone numbers, which may be landlines or hotlines as well as mobiles
/// (branch phones, AD13 support phone). Patient and assistant logins use <see cref="EgyptianMobile"/> only.
/// </summary>
public static partial class EgyptianPhone
{
    // Landline: 0 + area code (2 for Cairo and Giza, 3 for Alexandria, 2-digit codes elsewhere) + subscriber.
    [GeneratedRegex(@"^0[2-9][0-9]{7,8}\z", RegexOptions.CultureInvariant)]
    private static partial Regex LandlinePattern();

    // Short hotline numbers, for example 19xxx.
    [GeneratedRegex(@"^1[0-9]{4}\z", RegexOptions.CultureInvariant)]
    private static partial Regex HotlinePattern();

    // Any country, E.164: + and 8–15 digits.
    [GeneratedRegex(@"^\+[1-9][0-9]{7,14}\z", RegexOptions.CultureInvariant)]
    private static partial Regex InternationalPattern();

    [GeneratedRegex(@"[\s\-().]", RegexOptions.CultureInvariant)]
    private static partial Regex Separators();

    /// <summary>
    /// A mobile or landline in E.164 (<c>+201XXXXXXXXX</c>, <c>+2023XXXXXXX</c>), a hotline as typed (<c>19xxx</c>),
    /// or null when it is none of these.
    /// </summary>
    public static string? Normalize(string? input)
    {
        if (input is null)
        {
            return null;
        }

        if (EgyptianMobile.Normalize(input) is { } mobile)
        {
            return mobile;
        }

        var digits = Separators().Replace(EgyptianMobile.NormalizeDigits(input), "");
        if (digits.StartsWith("+20", StringComparison.Ordinal))
        {
            digits = "0" + digits[3..];
        }
        else if (digits.StartsWith("0020", StringComparison.Ordinal))
        {
            digits = "0" + digits[4..];
        }

        if (LandlinePattern().IsMatch(digits))
        {
            return "+20" + digits[1..];
        }

        return HotlinePattern().IsMatch(digits) ? digits : null;
    }

    /// <summary>An Egyptian number as in <see cref="Normalize"/>, or any international number in E.164 (WhatsApp).</summary>
    public static string? NormalizeWithInternational(string? input)
    {
        if (Normalize(input) is { } local)
        {
            return local;
        }

        if (input is null)
        {
            return null;
        }

        var digits = Separators().Replace(EgyptianMobile.NormalizeDigits(input), "");
        if (digits.StartsWith("00", StringComparison.Ordinal))
        {
            digits = "+" + digits[2..];
        }

        return InternationalPattern().IsMatch(digits) ? digits : null;
    }
}
