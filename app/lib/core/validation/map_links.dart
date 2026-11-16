/// A branch's Google Maps link («لينك جوجل ماب»), checked like the API's
/// `MapLinks.cs`: only the form of the link, nothing is fetched. Change both
/// together.
abstract final class MapLinks {
  static const maxLength = 500;

  // A link runs to the next space or invisible format mark (the direction
  // marks an Arabic share text may carry, the byte-order mark).
  static final _link = RegExp(r'https?://[^\s\p{Cf}]+', caseSensitive: false, unicode: true);
  static final _anyLink = RegExp('https?://', caseSensitive: false);
  static final _space = RegExp(r'\s');

  // google.com, google.de, google.com.eg, google.co.uk …
  static final _googleHost = RegExp(r'^(www\.)?google\.(com|[a-z]{2}|com\.[a-z]{2}|co\.[a-z]{2})$');
  static final _mapsGoogleHost = RegExp(r'^maps\.google\.(com|[a-z]{2}|com\.[a-z]{2}|co\.[a-z]{2})$');

  /// Punctuation a sentence may put right after a link.
  static const _trailing = '.,;:!?»"\'،؛';

  /// True when [text] has an `http://` or `https://` link in it.
  static bool hasLink(String text) => _anyLink.hasMatch(text);

  /// The link in [text], or [text] trimmed when it has none. The Google Maps
  /// share sheet sends «Clinic name https://maps.app.goo.gl/…»; only the
  /// link is kept (a Google Maps one first, when there are several).
  static String extract(String text) {
    final links = [for (final match in _link.allMatches(text)) _trimEnd(match.group(0)!)];
    if (links.isEmpty) return text.trim();
    return links.firstWhere(isGoogleMaps, orElse: () => links.first);
  }

  /// True for an http or https link to Google Maps: `maps.app.goo.gl/…`,
  /// `goo.gl/maps/…`, `maps.google.<tld>/…` or `(www.)google.<tld>/maps…`.
  /// The value is trimmed first.
  static bool isGoogleMaps(String value) {
    final text = value.trim();
    if (text.isEmpty || _space.hasMatch(text)) return false;
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.userInfo.isNotEmpty || uri.hasPort) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final path = uri.path;
    if (host == 'maps.app.goo.gl') return path.length > 1;
    if (host == 'goo.gl') return path.startsWith('/maps/') && path.length > '/maps/'.length;
    if (_mapsGoogleHost.hasMatch(host)) return true;
    return _googleHost.hasMatch(host) && (path == '/maps' || path.startsWith('/maps/'));
  }

  static String _trimEnd(String link) {
    var end = link.length;
    while (end > 0) {
      final last = link[end - 1];
      // A ")" belongs to the link only when it closes a "(" of the link.
      final kept = link.substring(0, end);
      final unopened = last == ')' && ')'.allMatches(kept).length > '('.allMatches(kept).length;
      if (!_trailing.contains(last) && !unopened) break;
      end--;
    }
    return link.substring(0, end);
  }
}
