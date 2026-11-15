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

/// The password policy (spec section 11), the same as the API's
/// `Passwords.MeetsPolicy`: 8 to 128 characters, at least one letter (any
/// script) and one digit. Arabic-Indic digits count as digits.
abstract final class PasswordRules {
  static const minLength = 8;
  static const maxLength = 128;
  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _digit = RegExp('[0-9]');

  static bool hasLength(String value) => value.length >= minLength;
  static bool hasLetter(String value) => _letter.hasMatch(value);
  static bool hasNumber(String value) => _digit.hasMatch(Validators.normalizeDigits(value));

  static bool isStrong(String value) =>
      hasLength(value) && value.length <= maxLength && hasLetter(value) && hasNumber(value);
}
