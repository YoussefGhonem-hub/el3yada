import 'package:catalog_core/catalog_core.dart';
import 'package:test/test.dart';

/// Trade names below are real rows from the Egyptian drug dataset
/// (data/egyptian-drugs.csv), except where marked.
void main() {
  group('parseStrength finds the strength', () {
    final cases = {
      'ABILIFY 15 MG 10 TABS.': '15 MG',
      'ABSTRAL 100MCG 10 SUBLINGUAL TABS.': '100 MCG',
      'ALFACIDOCAL 0.25 MCG 30 S.G. CAPS.': '0.25 MCG',
      'ALEMOX 1 GM 12 F.C.TABS.': '1 GM',
      'AMEROPEM 1 GM I.V. VIAL': '1 GM',
      'ACTIHER 10 SACHETS * 3 GM': '3 GM',
      'ABIMOL 150MG/5ML SYRUP 125ML': '150 MG/5 ML',
      'A.T.G FRESENIUS 20MG/ML CONC. VIAL 5 ML': '20 MG/ML',
      'ALFABONID 1MCG/0.5ML 10 AMP. 0.5 ML': '1 MCG/0.5 ML',
      'ALZMENDA 10MG/GM ORAL DROPS 20 ML': '10 MG/GM',
      'ACTRAPID HM 100 I.U./ML 10 ML VIAL': '100 IU/ML',
      'ACCOFIL 30 MIU/0.5ML 5 PREFILLED SYRINGES': '30 MIU/0.5 ML',
      'ABIVIT-A 50.000 I.U. 20 CAPS.': '50.000 IU',
      'ALVESCO 160MCG/ACTUATION INHALER 60 DOSES': '160 MCG/ACTUATION',
      'AEROLIN 100MCG/DOSE INHALER': '100 MCG/DOSE',
      'ALLERGICASONE 125/50 MCG NASAL SPRAY 140 ACTUATIONS': '125/50 MCG',
      'ADAPALENE 0.1% GEL 30 GM': '0.1%',
      'ACNE FREE 0.025% GEL 30 GM': '0.025%',
      'ACESOLV 2% SYRUP 60ML': '2%',
      'ECONAZOLE 1%TOPICAL SPRAY 120 ML': '1%',
      'CLEAR FACE 10%W/W TOPICAL SOLUTION': '10%',
      'DOXY M.R.100 MG 10 CAPS.': '100 MG',
      // Spec A.3.4 examples (not all are real rows).
      'PANADOL 500 MG 24 TABS.': '500 MG',
      'AUGMENTIN 875/125 MG 14 F.C.TABS.': '875/125 MG',
      'AMOXIL 250 MG/5 ML SUSP. 100 ML': '250 MG/5 ML',
      'BETADERM 0.1 % CREAM 15 GM': '0.1%',
    };
    cases.forEach((name, strength) {
      test(name, () => expect(parseStrength(name), strength));
    });
  });

  group('parseStrength leaves the strength empty rather than guess', () {
    final cases = [
      // A volume alone is the pack size.
      '1 2 3 (ONE TWO THREE) SUSP. 120 ML',
      'ACETAPROFEN 100ML SUSP.',
      'AFRIN NASAL SPRAY 20 ML',
      // Grams of a cream, gel, ointment, soap or powder are the pack size.
      'A1 CREAM 50 GM',
      'ACAVIO MASSAGE GEL 50 GM',
      'AD-MUC ORAL OINT. 10 GM',
      'ACLESS SOAP 100 GM',
      'AMINOLEBAN ORAL POWDER 450 GM',
      // "G" must be a whole word.
      'ADVANCED VITAMIN C 30 GUMMIES',
      // A number glued to letters is not read: "D3" + "10000IU" written together.
      'G.XIR (D310000IU)30 TABLETS',
      // Numbers without a unit.
      '1 2 3 (ONE TWO THREE) 20 F.C.TABS.',
      'PANADOL EXTRA 24 TABS.',
    ];
    for (final name in cases) {
      test(name, () => expect(parseStrength(name), isNull));
    }
  });

  test('a strength wins over the pack volume that follows it', () {
    expect(parseStrength('ACULAR LS 0.4% EYE DROPS 5 ML'), '0.4%');
  });

  test('is case-insensitive', () {
    expect(parseStrength('Abilify 15 mg 10 tabs.'), '15 MG');
  });
}
