/// Search normalization from spec Appendix A.6. The catalog builder and the
/// app must apply exactly the same steps, or typed words will miss matches.
abstract final class SearchNormalizer {
  static final _diacritics = RegExp('[ً-ْٰـ]');
  static final _alef = RegExp('[أإآٱ]');
  static final _symbol = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
  static final _spaces = RegExp(r'\s+');
  static final _digit = RegExp(r'\d');

  /// Steps 1–5 of A.6, then collapses spaces.
  static String normalize(String input) {
    var text = input.toLowerCase();
    text = _arabicIndicToLatin(text);
    text = text.replaceAll(_diacritics, '');
    text = text
        .replaceAll(_alef, 'ا') // أ إ آ ٱ → ا
        .replaceAll('ة', 'ه') // ة → ه
        .replaceAll('ى', 'ي'); // ى → ي
    text = text.replaceAllMapped(_symbol, (match) {
      final char = match[0]!;
      final start = match.start;
      final keep = (char == '.' || char == '/') &&
          start > 0 &&
          start < text.length - 1 &&
          _digit.hasMatch(text[start - 1]) &&
          _digit.hasMatch(text[start + 1]);
      return keep ? char : ' ';
    });
    return text.replaceAll(_spaces, ' ').trim();
  }

  /// An FTS5 query where every typed word is a prefix and all must match
  /// (A.6, Querying). Returns null when nothing searchable was typed.
  static String? toFtsQuery(String input) {
    final words = normalize(input).split(' ').where((word) => word.isNotEmpty);
    if (words.isEmpty) return null;
    return words.map((word) => '"${word.replaceAll('"', '')}"*').join(' ');
  }

  static String _arabicIndicToLatin(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
