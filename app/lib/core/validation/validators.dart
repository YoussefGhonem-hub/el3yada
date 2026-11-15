/// Field rules from spec section 11.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _egyptianMobile = RegExp(r'^01[0125]\d{8}$');

  /// Turns Arabic-Indic (٠-٩) and Persian (۰-۹) digits into 0-9.
  static String normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
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

  /// Accepts `01XXXXXXXXX`, `+201XXXXXXXXX`, `00201XXXXXXXXX` or
  /// `201XXXXXXXXX`, and returns E.164 (`+201XXXXXXXXX`), or null if invalid.
  static String? normalizeEgyptianMobile(String input) {
    var digits = normalizeDigits(input).replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.startsWith('+20')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('0020')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('20') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }
    if (!_egyptianMobile.hasMatch(digits)) return null;
    return '+20${digits.substring(1)}';
  }

  static bool isEmail(String input) => _email.hasMatch(input.trim());

  /// Login identifier (A3): with `@` it is an email, otherwise an Egyptian
  /// mobile number. Returns the normalized value, or null if invalid.
  static String? normalizeIdentifier(String input) {
    final value = input.trim();
    if (value.contains('@')) {
      return isEmail(value) ? value.toLowerCase() : null;
    }
    return normalizeEgyptianMobile(value);
  }
}
