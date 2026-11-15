import 'validators.dart';

/// Clinic and support phone numbers, which may be landlines or hotlines as
/// well as mobiles (branch phones, the support phone). Same rules as the
/// API's `EgyptianPhone.Normalize` (backend/src/El3yada.Api/Validation/
/// EgyptianPhone.cs): change both together. Logins use
/// [Validators.normalizeEgyptianMobile] only.
abstract final class EgyptianPhone {
  // 0 + area code (2 Cairo and Giza, 3 Alexandria, two digits elsewhere) + subscriber.
  static final _landline = RegExp(r'^0[2-9][0-9]{7,8}$');

  // Short hotlines such as 19xxx.
  static final _hotline = RegExp(r'^1[0-9]{4}$');

  static final _separators = RegExp(r'[\s\-().]');

  /// A mobile or landline in E.164 (`+201XXXXXXXXX`, `+2023XXXXXXX`), a
  /// hotline as typed (`19xxx`), or null when it is none of these.
  static String? normalize(String input) {
    final mobile = Validators.normalizeEgyptianMobile(input);
    if (mobile != null) return mobile;

    var digits = Validators.normalizeDigits(input).replaceAll(_separators, '');
    if (digits.startsWith('+20')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('0020')) {
      digits = '0${digits.substring(4)}';
    }
    if (_landline.hasMatch(digits)) return '+20${digits.substring(1)}';
    return _hotline.hasMatch(digits) ? digits : null;
  }

  /// How to show a stored number: `+201012345678` → `01012345678`,
  /// `+20223581234` → `0223581234`; anything else as it is.
  static String display(String number) => number.startsWith('+20') ? '0${number.substring(3)}' : number;
}
