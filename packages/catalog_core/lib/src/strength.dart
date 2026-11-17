/// Reads the strength out of an Egyptian trade name (spec A.3.4,
/// BR-CAT7), for example "ABILIFY 15 MG 10 TABS." → "15 MG".
library;

/// Returns the strength written in [tradeName], or null when there is none.
///
/// The result is only a suggestion the doctor can change, so the parser
/// prefers no answer to a wrong one ("never guess", A.3.4):
///
/// * A volume on its own is a pack size, not a strength: "SYRUP 120 ML" →
///   null. ML only counts after a slash: "250MG/5ML" → "250 MG/5 ML".
/// * Grams on their own are a pack size for creams, gels, ointments, soaps
///   and similar ("CREAM 50 GM" → null), but a strength otherwise
///   ("ALEMOX 1 GM 12 F.C.TABS." → "1 GM").
/// * Mass, units and percentages win over grams: the first one in the name
///   is returned.
/// * A unit must be a whole word: "30 GUMMIES" has no strength.
///
/// Units are written in a fixed way: MG, MCG (also for µG/UG), GM (also for
/// G/GRAM), IU (also for I.U.), MIU, MMOL, MEQ, %, and ML as a denominator.
/// Numbers are kept exactly as written ("50.000 IU", "875/125 MG").
String? parseStrength(String tradeName) {
  final name = tradeName.toUpperCase();
  String? firstGrams;
  for (final match in _strengthPattern.allMatches(name)) {
    final unit = _canonicalUnit(match.group(2) ?? match.group(3)!);
    final denominatorUnit = match.group(5);
    final amount = _tidyNumbers(match.group(1)!);
    var text = unit == '%' ? '$amount%' : '$amount $unit';
    if (denominatorUnit != null) {
      final denominatorAmount = match.group(4);
      final den = _canonicalUnit(denominatorUnit);
      text += denominatorAmount == null || denominatorAmount.isEmpty
          ? '/$den'
          : '/${_tidyNumbers(denominatorAmount)} $den';
    }
    if (unit == 'ML') {
      // "10 ML" on its own is a volume; only "X ML/Y ML"-style ratios count,
      // and those are not useful either, so skip all ML numerators.
      continue;
    }
    if (unit == 'GM' && denominatorUnit == null) {
      firstGrams ??= text;
      continue;
    }
    return text;
  }
  if (firstGrams != null && !_semiSolidPack.hasMatch(name)) return firstGrams;
  return null;
}

/// Numbers, optionally several joined by "/" ("875/125"); a unit; then an
/// optional denominator ("/5 ML", "/ML", "/G", "/DOSE").
final _strengthPattern = RegExp(
  // Not glued to a letter or another number ("B12", "D310000IU"); a dot
  // before is fine ("M.R.100 MG").
  r'(?<![A-Z0-9,])'
  r'(\d+(?:[.,]\d+)?(?:\s*/\s*\d+(?:[.,]\d+)?)*)'
  r'\s*'
  r'(?:(MCG|µG|UG|MG|GM|GRAMS?|G|M\.I\.U\.?|MIU|I\.U\.?|IU|MMOL|MEQ|ML)(?![A-Z])|(%))'
  r'(?:\s*/\s*(\d+(?:[.,]\d+)?)?\s*(ML|GM|G|L|DOSE|ACTUATION)(?![A-Z]))?',
);

/// Words that mean the grams in the name are the size of a tube, jar, bar
/// or tin, not a strength.
final _semiSolidPack = RegExp(
  r'(?<![A-Z])(CREAM|CR\.|OINT\.?|OINTMENT|EMULGEL|GEL\.?|JELLY|PASTE|BALM|'
  r'SOAP|BAR|POWDER|PWD\.?|SHAMPOO|MASK|SCRUB|WAX|LOTION|SERUM|BUTTER|'
  r'HERBS?|TEA|MILK|FORMULA|SUGAR|SWEETENER|HONEY|CHOCOLATE|'
  r'BISCUITS?|CEREALS?)(?![A-Z])',
);

String _canonicalUnit(String unit) {
  switch (unit) {
    case 'MCG':
    case 'µG':
    case 'UG':
      return 'MCG';
    case 'GM':
    case 'G':
    case 'GRAM':
    case 'GRAMS':
      return 'GM';
    case 'I.U.':
    case 'I.U':
    case 'IU':
      return 'IU';
    case 'M.I.U.':
    case 'M.I.U':
    case 'MIU':
      return 'MIU';
    case 'L':
      return 'L';
  }
  return unit;
}

String _tidyNumbers(String numbers) => numbers.replaceAll(RegExp(r'\s*/\s*'), '/');
