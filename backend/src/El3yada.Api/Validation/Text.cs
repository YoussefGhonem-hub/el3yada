using System.Text.RegularExpressions;

namespace El3yada.Api.Validation;

/// <summary>How text fields are cleaned before they are stored.</summary>
public static partial class Text
{
    [GeneratedRegex(@"\s+", RegexOptions.CultureInvariant)]
    private static partial Regex Whitespace();

    /// <summary>Trims and turns every run of spaces, tabs or new lines into one space.</summary>
    public static string CollapseSpaces(string value) => Whitespace().Replace(value.Trim(), " ");

    /// <summary>Trimmed, lower case (spec section 11: emails are stored in lower case).</summary>
    public static string NormalizeEmail(string value) => value.Trim().ToLowerInvariant();

    /// <summary>Trimmed, or null when empty (optional text fields).</summary>
    public static string? TrimToNull(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
