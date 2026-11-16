import '../../../core/validation/map_links.dart';
import '../../../core/validation/validators.dart';

/// A4 field rules (spec section 11), the same as the API's
/// `DoctorRegistrationValidator`. Change both together.
abstract final class RegistrationRules {
  static const maxExtraSpecialties = 2;
  static const maxPhones = 5;
  static const maxTitleLength = 40;
  static const maxEmailLength = 254;

  /// 100,000 EGP (spec section 11, visit prices).
  static const maxPricePiasters = 10000000;

  /// Maximum lengths of the branch fields, by API field name.
  static const branchMaxLength = {
    'nameAr': 60,
    'governorate': 50,
    'city': 60,
    'addressDetails': 300,
    'landmark': 150,
    'mapUrl': MapLinks.maxLength,
  };

  static final _spaces = RegExp(r'\s+');
  static final _fullName = RegExp(r'^[\p{L}\p{M}]+( [\p{L}\p{M}]+)+$', unicode: true);
  static final _licenseNumber = RegExp(r'^[A-Za-z0-9/-]{3,20}$');
  static final _price = RegExp(r'^([0-9]{1,6})(?:\.([0-9]{1,2}))?$');

  /// Trims and turns every run of spaces into one space.
  static String collapseSpaces(String value) => value.trim().replaceAll(_spaces, ' ');

  /// 2–60 characters, at least two words, letters (Arabic or Latin) and
  /// spaces only.
  static bool isFullName(String value) {
    final name = collapseSpaces(value);
    return name.length >= 2 && name.length <= 60 && _fullName.hasMatch(name);
  }

  /// The syndicate number with Western digits and no spaces, or null when it
  /// is not 3–20 letters, digits, `-` or `/`.
  static String? normalizeLicenseNumber(String value) {
    final cleaned = Validators.normalizeDigits(value).replaceAll(' ', '').trim();
    return _licenseNumber.hasMatch(cleaned) ? cleaned : null;
  }

  /// A visit price typed in EGP (`300`, `150.5`, `٣٠٠`) as piasters. Returns
  /// null for an empty field and throws [FormatException] when the amount is
  /// not 0–100,000 EGP with at most 2 decimals.
  static int? parsePrice(String value) {
    final text = Validators.normalizeDigits(value).replaceAll('٫', '.').replaceAll(_spaces, '');
    if (text.isEmpty) return null;
    final match = _price.firstMatch(text);
    if (match == null) throw FormatException('Not an amount', value);
    final whole = int.parse(match.group(1)!);
    final fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));
    final piasters = whole * 100 + fraction;
    if (piasters > maxPricePiasters) throw FormatException('Out of range', value);
    return piasters;
  }

  /// Piasters back to what the price field shows: `30000` → `300`,
  /// `15050` → `150.50`.
  static String formatPriceInput(int piasters) {
    final whole = piasters ~/ 100;
    final fraction = piasters % 100;
    return fraction == 0 ? '$whole' : '$whole.${fraction.toString().padLeft(2, '0')}';
  }
}
