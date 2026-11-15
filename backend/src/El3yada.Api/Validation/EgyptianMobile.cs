using System.Text;
using System.Text.RegularExpressions;

namespace El3yada.Api.Validation;

/// <summary>
/// Egyptian mobile numbers (spec section 11). Same rules as the app's
/// <c>Validators.normalizeEgyptianMobile</c> (app/lib/core/validation/validators.dart): change both together.
/// </summary>
public static partial class EgyptianMobile
{
    // [0-9], not \d: in .NET \d also matches other scripts' digits.
    // \z, not $: in .NET $ also matches before a final newline.
    [GeneratedRegex(@"^01[0125][0-9]{8}\z", RegexOptions.CultureInvariant)]
    private static partial Regex LocalPattern();

    [GeneratedRegex(@"[\s\-()]", RegexOptions.CultureInvariant)]
    private static partial Regex Separators();

    /// <summary>Turns Arabic-Indic (٠-٩) and Persian (۰-۹) digits into 0-9.</summary>
    public static string NormalizeDigits(string input)
    {
        var builder = new StringBuilder(input.Length);
        foreach (var c in input)
        {
            builder.Append(c switch
            {
                >= '٠' and <= '٩' => (char)('0' + (c - '٠')),
                >= '۰' and <= '۹' => (char)('0' + (c - '۰')),
                _ => c,
            });
        }

        return builder.ToString();
    }

    /// <summary>
    /// Accepts <c>01XXXXXXXXX</c>, <c>+201XXXXXXXXX</c>, <c>00201XXXXXXXXX</c> or <c>201XXXXXXXXX</c>
    /// (spaces, dashes and brackets allowed) and returns E.164 (<c>+201XXXXXXXXX</c>), or null if invalid.
    /// </summary>
    public static string? Normalize(string? input)
    {
        if (input is null)
        {
            return null;
        }

        var digits = Separators().Replace(NormalizeDigits(input), "");
        if (digits.StartsWith("+20", StringComparison.Ordinal))
        {
            digits = "0" + digits[3..];
        }
        else if (digits.StartsWith("0020", StringComparison.Ordinal))
        {
            digits = "0" + digits[4..];
        }
        else if (digits.StartsWith("20", StringComparison.Ordinal) && digits.Length == 12)
        {
            digits = "0" + digits[2..];
        }

        return LocalPattern().IsMatch(digits) ? "+20" + digits[1..] : null;
    }
}
