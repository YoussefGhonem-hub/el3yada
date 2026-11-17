/// Search normalization shared by the catalog builder and the app
/// (spec Appendix A.6). Both sides must call [normalizeForSearch], otherwise
/// what the doctor types will not match what was indexed.
library;

/// Normalizes [input] for indexing and for querying the catalog.
///
/// Steps, in order (A.6, plus the extras marked *):
/// 1. Lower case.
/// 2. Arabic-Indic digits ٠–٩ (and the Persian ۰–۹*) become 0–9. The Arabic
///    decimal separator ٫ becomes `.`*.
/// 3. Arabic diacritics U+064B–U+065F* and U+0670, and tatweel U+0640, are
///    removed. (A.6 lists U+064B–U+0652; the rest of the block are rarer
///    combining marks.)
/// 4. أ إ آ ٱ → ا; ة → ه; ى → ي. The Persian keyboard letters ی → ي and
///    ک → ك*. Latin accents are folded (é → e)*.
/// 5. Every character that is not a letter or a digit becomes a space, except
///    `/` and `.` between two digits ("250/5", "0.1").
/// 6. A space is inserted between a digit and a letter*, so "500MG" and
///    "500 MG" give the same words ("500 mg").
/// 7. Runs of spaces collapse to one; no leading or trailing space.
String normalizeForSearch(String input) {
  if (input.isEmpty) return '';
  final runes = <int>[];
  for (final rune in input.toLowerCase().runes) {
    final mapped = _mapRune(rune);
    if (mapped >= 0) runes.add(mapped);
  }

  final out = StringBuffer();
  var pendingSpace = false;
  var previousKind = _Kind.none;
  for (var i = 0; i < runes.length; i++) {
    final rune = runes[i];
    var kind = _kindOf(rune);
    if (kind == _Kind.other &&
        (rune == _slash || rune == _dot) &&
        i > 0 &&
        i + 1 < runes.length &&
        _isAsciiDigit(runes[i - 1]) &&
        _isAsciiDigit(runes[i + 1])) {
      kind = _Kind.numberJoiner;
    }
    if (kind == _Kind.other) {
      pendingSpace = true;
      continue;
    }
    final boundary = (previousKind == _Kind.digit && kind == _Kind.letter) ||
        (previousKind == _Kind.letter && kind == _Kind.digit);
    if ((pendingSpace || boundary) && out.isNotEmpty) out.writeCharCode(_space);
    pendingSpace = false;
    out.writeCharCode(rune);
    previousKind = kind == _Kind.numberJoiner ? _Kind.digit : kind;
  }
  return out.toString();
}

/// Splits [input] into normalized search words.
List<String> searchWords(String input) {
  final normalized = normalizeForSearch(input);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ');
}

/// Joins several values into one normalized string, dropping repeated words
/// while keeping the first-seen order. Used by the builder to keep the FTS
/// index small when names, short names and synonyms repeat the same words.
String normalizeAndDedupe(Iterable<String?> values) {
  final seen = <String>{};
  final out = <String>[];
  for (final value in values) {
    if (value == null || value.isEmpty) continue;
    for (final word in searchWords(value)) {
      if (seen.add(word)) out.add(word);
    }
  }
  return out.join(' ');
}

/// The Arabic "skeleton" of a normalized word: the word without the
/// long-vowel letters ا و ي and the hamza letters ء ؤ ئ after its first
/// letter, so that spellings that differ only in long vowels match.
///
/// The drug dataset spells trade names phonetically («بانادول»), while
/// doctors often write them the colloquial way («بنادول»); both have the
/// skeleton «بندل». Returns null when [word] has no Arabic letters, or when
/// its skeleton is the word itself or shorter than three letters: a short
/// skeleton such as «اك» (from «ايكو») would prefix-match far too much
/// («اكس راي»).
///
/// This is an addition to A.6: the builder indexes the skeletons next to the
/// normalized words ([withArabicSkeletons]), and [ftsPrefixQuery] searches
/// each Arabic word as "word or its skeleton".
String? arabicSkeleton(String word) {
  if (word.isEmpty) return null;
  final runes = word.runes.toList();
  if (!runes.any(_isArabicLetter)) return null;
  final out = StringBuffer()..writeCharCode(runes.first);
  var length = 1;
  for (final rune in runes.skip(1)) {
    if (_skeletonDrops.contains(rune)) continue;
    out.writeCharCode(rune);
    length++;
  }
  final skeleton = out.toString();
  return length < 3 || skeleton == word ? null : skeleton;
}

/// [normalizedText] followed by the skeletons ([arabicSkeleton]) of its
/// Arabic words that are new, for indexing.
String withArabicSkeletons(String normalizedText) {
  if (normalizedText.isEmpty) return normalizedText;
  final words = normalizedText.split(' ');
  final seen = words.toSet();
  final extra = <String>[];
  for (final word in words) {
    final skeleton = arabicSkeleton(word);
    if (skeleton != null && seen.add(skeleton)) extra.add(skeleton);
  }
  return extra.isEmpty ? normalizedText : '$normalizedText ${extra.join(' ')}';
}

bool _isArabicLetter(int rune) => rune >= 0x0621 && rune <= 0x064A;

/// ا و ي ء ؤ ئ
const _skeletonDrops = {0x0627, 0x0648, 0x064A, 0x0621, 0x0624, 0x0626};

const _space = 0x20;
const _slash = 0x2F;
const _dot = 0x2E;

enum _Kind { none, letter, digit, numberJoiner, other }

bool _isAsciiDigit(int rune) => rune >= 0x30 && rune <= 0x39;

_Kind _kindOf(int rune) {
  if (_isAsciiDigit(rune)) return _Kind.digit;
  if ((rune >= 0x61 && rune <= 0x7A) || (rune >= 0x41 && rune <= 0x5A)) {
    return _Kind.letter;
  }
  if (rune < 0x80) return _Kind.other;
  // Arabic letters (after _mapRune, diacritics and tatweel are already gone).
  if (rune >= 0x0621 && rune <= 0x064A) return _Kind.letter;
  final char = String.fromCharCode(rune);
  if (_unicodeLetter.hasMatch(char)) return _Kind.letter;
  if (_unicodeDigit.hasMatch(char)) return _Kind.digit;
  return _Kind.other;
}

final _unicodeLetter = RegExp(r'^\p{L}$', unicode: true);
final _unicodeDigit = RegExp(r'^\p{N}$', unicode: true);

/// Returns the replacement for [rune], or -1 to drop it.
int _mapRune(int rune) {
  if (rune < 0x80) return rune;
  // Arabic-Indic and Persian digits.
  if (rune >= 0x0660 && rune <= 0x0669) return 0x30 + rune - 0x0660;
  if (rune >= 0x06F0 && rune <= 0x06F9) return 0x30 + rune - 0x06F0;
  if (rune == 0x066B) return _dot; // ٫ Arabic decimal separator
  // Diacritics, superscript alef, tatweel.
  if (rune >= 0x064B && rune <= 0x065F) return -1;
  if (rune == 0x0670 || rune == 0x0640) return -1;
  switch (rune) {
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0622: // آ
    case 0x0671: // ٱ
      return 0x0627; // ا
    case 0x0629: // ة
      return 0x0647; // ه
    case 0x0649: // ى
    case 0x06CC: // ی Persian yeh
      return 0x064A; // ي
    case 0x06A9: // ک Persian keheh
      return 0x0643; // ك
  }
  return _latinFold[rune] ?? rune;
}

/// Lower-case Latin letters with accents and their plain letter.
const Map<int, int> _latinFold = {
  0xE0: 0x61, 0xE1: 0x61, 0xE2: 0x61, 0xE3: 0x61, 0xE4: 0x61, 0xE5: 0x61, //
  0xE7: 0x63, //
  0xE8: 0x65, 0xE9: 0x65, 0xEA: 0x65, 0xEB: 0x65, //
  0xEC: 0x69, 0xED: 0x69, 0xEE: 0x69, 0xEF: 0x69, //
  0xF1: 0x6E, //
  0xF2: 0x6F, 0xF3: 0x6F, 0xF4: 0x6F, 0xF5: 0x6F, 0xF6: 0x6F, 0xF8: 0x6F, //
  0xF9: 0x75, 0xFA: 0x75, 0xFB: 0x75, 0xFC: 0x75, //
  0xFD: 0x79, 0xFF: 0x79,
};
