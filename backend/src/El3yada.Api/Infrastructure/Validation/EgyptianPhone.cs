using System.Diagnostics.CodeAnalysis;
using System.Text.RegularExpressions;

namespace El3yada.Api.Infrastructure.Validation;

/// <summary>
/// Egyptian mobile numbers (spec 11): accepts <c>01XXXXXXXXX</c>, <c>+201XXXXXXXXX</c> or
/// <c>00201XXXXXXXXX</c>, with spaces or dashes, and Arabic-Indic digits. Stored as E.164.
/// Same rule as the app's <c>validators.dart</c>.
/// </summary>
public static partial class EgyptianPhone
{
    [GeneratedRegex(@"^01[0125]\d{8}$")]
    private static partial Regex LocalPattern();

    public static bool TryNormalize(string? input, [NotNullWhen(true)] out string? e164)
    {
        e164 = null;
        if (string.IsNullOrWhiteSpace(input)) return false;

        var chars = new List<char>(input.Length);
        foreach (var c in input)
        {
            if (c is >= '0' and <= '9' or '+') chars.Add(c);
            else if (c is >= '٠' and <= '٩') chars.Add((char)('0' + (c - '٠')));   // Arabic-Indic
            else if (c is >= '۰' and <= '۹') chars.Add((char)('0' + (c - '۰')));   // Persian
            else if (c is ' ' or '-' or '(' or ')') continue;
            else return false;
        }

        var digits = new string([.. chars]);
        if (digits.StartsWith("+20")) digits = "0" + digits[3..];
        else if (digits.StartsWith("0020")) digits = "0" + digits[4..];

        if (!LocalPattern().IsMatch(digits)) return false;
        e164 = "+2" + digits;
        return true;
    }
}
