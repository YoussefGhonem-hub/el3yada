using System.Text.RegularExpressions;

namespace El3yada.Api.Validation;

/// <summary>
/// A branch's Google Maps link («لينك جوجل ماب»). Only the form of the link is checked: nothing is fetched from
/// Google. The app's <c>map_links.dart</c> has the same rule; change both together.
/// </summary>
public static partial class MapLinks
{
    public const int MaxLength = 500;

    // google.com, google.de, google.com.eg, google.co.uk …
    [GeneratedRegex(@"^(www\.)?google\.(com|[a-z]{2}|com\.[a-z]{2}|co\.[a-z]{2})\z", RegexOptions.CultureInvariant)]
    private static partial Regex GoogleHost();

    [GeneratedRegex(@"^maps\.google\.(com|[a-z]{2}|com\.[a-z]{2}|co\.[a-z]{2})\z", RegexOptions.CultureInvariant)]
    private static partial Regex MapsGoogleHost();

    /// <summary>
    /// True for an http or https link to Google Maps: <c>maps.app.goo.gl/…</c>, <c>goo.gl/maps/…</c>,
    /// <c>maps.google.&lt;tld&gt;/…</c> or <c>(www.)google.&lt;tld&gt;/maps…</c>. The value is trimmed first.
    /// </summary>
    public static bool IsGoogleMaps(string value)
    {
        var text = value.Trim();
        if (text.Length == 0 || text.Any(char.IsWhiteSpace)
            || !Uri.TryCreate(text, UriKind.Absolute, out var uri)
            || uri.Scheme is not ("https" or "http")
            || uri.UserInfo.Length > 0 || !uri.IsDefaultPort)
        {
            return false;
        }

        var host = uri.IdnHost.ToLowerInvariant();
        var path = uri.AbsolutePath;
        if (host == "maps.app.goo.gl")
        {
            return path.Length > 1;
        }

        if (host == "goo.gl")
        {
            return path.StartsWith("/maps/", StringComparison.Ordinal) && path.Length > "/maps/".Length;
        }

        if (MapsGoogleHost().IsMatch(host))
        {
            return true;
        }

        return GoogleHost().IsMatch(host) && (path == "/maps" || path.StartsWith("/maps/", StringComparison.Ordinal));
    }
}
