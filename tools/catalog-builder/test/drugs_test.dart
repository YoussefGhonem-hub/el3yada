import 'package:catalog_builder/catalog_builder.dart';
import 'package:catalog_core/catalog_core.dart';
import 'package:test/test.dart';

import 'paths.dart';

void main() {
  group('stripMarkers', () {
    test('moves the availability marker out of the trade name', () {
      expect(stripMarkers('ABILIFY 10 MG 10 DISCMELT ORALLY DIS.TABS. (N/A)'), (
        'ABILIFY 10 MG 10 DISCMELT ORALLY DIS.TABS.',
        DrugMarker.notAvailable,
      ));
      expect(stripMarkers('ABSTAIN SR 150 MG 20TABS.(N/A YET)'), (
        'ABSTAIN SR 150 MG 20TABS.',
        DrugMarker.notAvailableYet,
      ));
      expect(stripMarkers('A.T.G FRESENIUS 20MG/ML CONC. VIAL 5 ML (CANCELLED)'), (
        'A.T.G FRESENIUS 20MG/ML CONC. VIAL 5 ML',
        DrugMarker.cancelled,
      ));
      expect(stripMarkers('5-HT 200 MG 60 CAPS. (ILLEGAL IMPORT)'), ('5-HT 200 MG 60 CAPS.', DrugMarker.illegalImport));
      expect(stripMarkers('ACOMPLIA 20MG  14F.C.TABLET (WITHDRAWAL)'), (
        'ACOMPLIA 20MG 14F.C.TABLET',
        DrugMarker.withdrawn,
      ));
    });

    test('leaves names without a marker alone, including other brackets', () {
      expect(stripMarkers('GINKGO BILOBA 120 MG 60 CAPS. (NATROL)'), (
        'GINKGO BILOBA 120 MG 60 CAPS. (NATROL)',
        DrugMarker.none,
      ));
    });

    test('maps markers to the stored status, and knows which are left out', () {
      expect(DrugMarker.notAvailable.status, DrugStatus.notAvailable);
      expect(DrugMarker.none.status, DrugStatus.available);
      expect(DrugMarker.cancelled.withdrawnFromMarket, isTrue);
      expect(DrugMarker.illegalImport.withdrawnFromMarket, isTrue);
      expect(DrugMarker.notAvailable.withdrawnFromMarket, isFalse);
    });
  });

  group('splitIngredients', () {
    test('splits on top-level plus signs only (A.3.3)', () {
      expect(splitIngredients('CHLORPHENIRAMINE+PARACETAMOL(ACETAMINOPHEN)+PSEUDOEPHEDRINE'), [
        'CHLORPHENIRAMINE',
        'PARACETAMOL(ACETAMINOPHEN)',
        'PSEUDOEPHEDRINE',
      ]);
      expect(splitIngredients('A+B (C+D) + E'), ['A', 'B (C+D)', 'E']);
      expect(splitIngredients(''), isEmpty);
    });
  });

  group('form suggestion with the real mappings (A.3.5)', () {
    final mappings = Mappings.load(realMappings);
    final suggester = FormSuggester(mappings.formTokens, mappings.routeToForm);
    final cases = <(String, String, String?)>[
      ('ABILIFY 15 MG 10 TABS.', 'ORAL.SOLID', 'Tablet'),
      ('1 2 3 (ONE TWO THREE) 20 F.C.TABS.', 'ORAL.SOLID', 'Tablet'),
      ('1 2 3 (ONE TWO THREE) SUSP. 120 ML', 'ORAL.LIQUID', 'Suspension'),
      ('ACULAR LS 0.4% EYE DROPS 5 ML', 'EYE', 'Eye drops'),
      ('ALFABONID 2MCG/ML ORAL DPS. 10 ML', 'ORAL.LIQUID', 'Oral drops'),
      ('BETADERM 0.1% CREAM 15 GM', 'TOPICAL', 'Cream'),
      ('DEXATROL EYE OINT. 5 GM', 'EYE', 'Eye ointment'),
      ('AMEROPEM 1 GM I.V. VIAL', 'INJECTION', 'Vial'),
      ('ABIMOL 300MG 5 RECTAL SUPP.', 'RECTAL', 'Suppository'),
      ('CYCLOGEST 400MG 15 RECTAL OR VAG. PESSARIES', 'VAGINAL', 'Vaginal suppository'),
      ('ALVEOBREEZE 12 MCG 30 CAPS. FOR INH.+INHALER', 'UNKNOWN', 'Inhaler'),
      ('ACC 200MG 20 SACHETS', 'UNKNOWN', 'Sachet'),
      ('AFRIN 0.05% NASAL SPRAY 20 ML', 'SPRAY', 'Nasal spray'),
      ('DELMONKAST 5MG 14 CHEWABLE TABS.', 'ORAL.SOLID', 'Chewable tablet'),
      // No form word: the route decides (A.3.5 second table) ...
      ('STRENCAL 30', 'ORAL.SOLID', 'Tablet'),
      ('SOMETHING', 'INJECTION', 'Injection'),
      // ... or nothing is suggested.
      ('USERVIVE', 'VAGINAL', null),
      ('SOMETHING', 'UNKNOWN', null),
    ];
    for (final (name, route, form) in cases) {
      test('$name [$route] → $form', () => expect(suggester.suggest(name, route), form));
    }
  });

  group('assignGroups', () {
    final mappings = Mappings.load(fixtureMappings);

    Drug drug(String name, String rawClass, String ingredient, {String route = 'ORAL.SOLID'}) => Drug(
      tradeNameEn: name,
      tradeNameAr: '',
      activeIngredient: ingredient,
      manufacturer: '',
      rawClass: rawClass,
      route: route,
      priceEgp: null,
      marker: DrugMarker.none,
      ingredients: splitIngredients(ingredient),
      form: null,
      strength: null,
    );

    test('uses class-to-group.csv, with route-specific rows first', () {
      final drugs = [
        drug('A', 'GLUCOCORTICOID', 'BETAMETHASONE'),
        drug('B', 'GLUCOCORTICOID', 'BETAMETHASONE', route: 'TOPICAL'),
      ];
      assignGroups(drugs, mappings);
      expect(drugs.map((d) => d.groupId), ['corticosteroids', 'topical_steroids']);
      expect(drugs.every((d) => d.groupSource == GroupSource.mapping), isTrue);
    });

    test('places a junk class through products with the same ingredients', () {
      final drugs = [
        drug('ATOR 20', 'ANTIHYPERLIPIDEMIC.STATINS', 'ATORVASTATIN'),
        drug('ATOR 40', 'ANTIHYPERLIPIDEMIC.STATINS', 'ATORVASTATIN'),
        drug('MYSTERY', '.', 'ATORVASTATIN'),
      ];
      assignGroups(drugs, mappings);
      expect(drugs.last.groupId, 'lipid_lowering');
      expect(drugs.last.groupSource, GroupSource.ingredientFallback);
    });

    test('needs two agreeing products before it guesses', () {
      final drugs = [drug('ONE', 'ANTIHYPERLIPIDEMIC.STATINS', 'ROSUVASTATIN'), drug('MYSTERY', '.', 'ROSUVASTATIN')];
      assignGroups(drugs, mappings);
      expect(drugs.last.groupId, 'other');
      expect(drugs.last.groupSource, GroupSource.other);
    });

    test('puts a class missing from the mapping in "other" and says so', () {
      final drugs = [drug('NEW', 'A BRAND NEW CLASS', 'X')];
      assignGroups(drugs, mappings);
      expect(drugs.single.groupId, 'other');
      expect(drugs.single.groupSource, GroupSource.unmapped);
    });
  });

  group('readDrugs on the fixture', () {
    final mappings = Mappings.load(fixtureMappings);

    test('leaves out cancelled, illegal-import and withdrawn products', () {
      final set = readDrugs(fixtureDrugs, mappings);
      expect(set.rowsRead, 19);
      expect(set.drugs, hasLength(16));
      expect(set.excluded, {DrugMarker.illegalImport: 1, DrugMarker.cancelled: 1, DrugMarker.withdrawn: 1});
    });

    test('keeps them when asked', () {
      final set = readDrugs(fixtureDrugs, mappings, keepWithdrawn: true);
      expect(set.drugs, hasLength(19));
      expect(set.excluded, isEmpty);
    });

    test('cleans the name and fills form, strength and ingredients', () {
      final drugs = readDrugs(fixtureDrugs, mappings).drugs;
      final abilify = drugs.firstWhere((d) => d.tradeNameEn.startsWith('ABILIFY 10'));
      expect(abilify.tradeNameEn, isNot(contains('(N/A)')));
      expect(abilify.marker, DrugMarker.notAvailable);
      final panadol = drugs.firstWhere((d) => d.tradeNameEn.startsWith('PANADOL EXTRA'));
      expect(panadol.ingredients, ['CAFFEINE', 'PARACETAMOL(ACETAMINOPHEN)']);
      expect(panadol.form, 'Tablet');
      final acular = drugs.firstWhere((d) => d.tradeNameEn.startsWith('ACULAR'));
      expect(acular.strength, '0.4%');
      expect(acular.form, 'Eye drops');
    });
  });
}
