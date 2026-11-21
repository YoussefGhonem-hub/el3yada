import 'package:catalog_core/catalog_core.dart';
import 'package:el3yada/features/catalog/data/catalog_db.dart';
import 'package:el3yada/features/catalog/data/local_catalog_search.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:el3yada/features/catalog/domain/catalog_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../support/catalog_support.dart';

/// LocalCatalogSearch over a tiny catalog built here with catalog_core's
/// schema (spec 6.9, BR-CAT4–CAT9, A.6, AC-18).
void main() {
  late DirectCatalogDb db;

  setUpAll(() async => db = await openTestCatalog());
  tearDownAll(() async {
    await db.dispose();
    deleteTestCatalogs();
  });

  const cardiology = CatalogProfile(
    drugGroups: {
      'antihypertensives',
      'antiplatelets',
      'lipid_lowering',
      'analgesics',
      'gastric_acid',
    },
    labCodes: {'99006-9', '99007-7'},
    radiologyRegions: {'Heart'},
    includesGeneral: true,
  );
  const dermatology = CatalogProfile(
    drugGroups: {'topical_steroids', 'antihistamines'},
    routes: {'TOPICAL'},
  );

  LocalCatalogSearch search({
    CatalogProfile profile = cardiology,
    CatalogSearch? history,
    List<CustomCatalogItem> custom = const [],
    bool ready = true,
  }) => LocalCatalogSearch(
    history: history ?? FixedHistory(),
    database: () => ready ? db : null,
    profile: () => profile,
    customItems: () => custom,
  );

  List<String> names(List<DrugHit> hits) => [for (final hit in hits) hit.name];

  test('SQLite in flutter test has FTS5', () {
    final memory = sqlite3.openInMemory();
    addTearDown(memory.close);
    expect(
      memory
          .select("SELECT sqlite_compileoption_used('ENABLE_FTS5') AS on_")
          .single['on_'],
      1,
    );
  });

  group('sections (BR-CAT4, AC-18)', () {
    test(
      'a cardiologist types "ator": atorvastatin brands are in "Your specialty"',
      () async {
        final hits = await search().drugs('ator');
        expect(hits.catalogReady, isTrue);
        expect(
          names(hits.mySpecialty),
          containsAll([
            'LIPITOR 20 MG 30 F.C.TABS.',
            'ATOR 20 MG 30 F.C.TABS.',
          ]),
        );
        expect(
          hits.others.where((h) => h.activeIngredient == 'ATORVASTATIN'),
          isEmpty,
        );
      },
    );

    test('"omep" finds omeprazole through the General groups', () async {
      final hits = await search().drugs('omep');
      expect(hits.mySpecialty.map((h) => h.activeIngredient).toSet(), {
        'OMEPRAZOLE',
      });
      expect(hits.mySpecialty, hasLength(3));
    });

    test(
      'a heart medicine is under other specialties for a dermatologist; "my specialty only" hides it',
      () async {
        final hits = await search(profile: dermatology).drugs('concor');
        expect(hits.mySpecialty, isEmpty);
        expect(names(hits.others), ['CONCOR 5 MG 30 F.C.TABS.']);

        final only = await search(
          profile: dermatology,
        ).drugs('concor', mySpecialtyOnly: true);
        expect(only.others, isEmpty);
        expect(only.mySpecialty, isEmpty);
      },
    );

    test(
      'an admin (no profile) gets everything under other specialties',
      () async {
        final hits = await search(profile: CatalogProfile.empty).drugs('ator');
        expect(hits.mySpecialty, isEmpty);
        expect(hits.others, hasLength(4));
      },
    );

    test('nothing is repeated across sections', () async {
      final lipitor = (await search().drugs('lipitor')).mySpecialty.single;
      final history = FixedHistory(
        matchAll: true,
        drugItems: [
          DrugHit(name: lipitor.name, catalogId: lipitor.catalogId),
          // Typed by hand once, with the exact catalog name.
          const DrugHit(name: 'ATOR 20 MG 30 F.C.TABS.'),
        ],
      );
      final hits = await search(history: history).drugs('ator');
      expect(hits.usedBefore, hasLength(2));
      final all = [...hits.usedBefore, ...hits.mySpecialty, ...hits.others];
      expect(names(all).toSet(), hasLength(all.length));
      expect(
        names(hits.mySpecialty),
        isNot(contains('LIPITOR 20 MG 30 F.C.TABS.')),
      );
      expect(
        names(hits.mySpecialty),
        isNot(contains('ATOR 20 MG 30 F.C.TABS.')),
      );
    });

    test('at most 50 per section, and the limit is kept', () async {
      final hits = await search(
        profile: CatalogProfile.empty,
      ).drugs('panadol', limit: 2);
      expect(hits.others, hasLength(2));
      expect(LocalCatalogSearch.maxPerSection, 50);
    });
  });

  group('matching (BR-CAT6)', () {
    test('«بنادول» finds Panadol (the dataset writes «بانادول»)', () async {
      final hits = await search(profile: CatalogProfile.empty).drugs('بنادول');
      expect(names(hits.others), contains('PANADOL 500 MG 24 TABS.'));
      expect(hits.others.every((h) => h.name.startsWith('PANADOL')), isTrue);
    });

    test('"paracetamol" lists every brand that contains it', () async {
      final hits = await search(
        profile: CatalogProfile.empty,
      ).drugs('paracetamol');
      expect(hits.others.map((h) => h.name).toSet(), {
        'PANADOL 500 MG 24 TABS.',
        'PANADOL EXTRA 24 F.C.TABS.',
        'PANADOL COLD & FLU 24 TABS.',
        'ABIMOL 500 MG 20 TABS.',
        'CETAL 250MG/5ML SYRUP 100 ML',
        'PARAMOL 125 MG 5 SUPP.',
      });
    });

    test('every word is a prefix and all must match', () async {
      expect(
        names(
          (await search(profile: CatalogProfile.empty).drugs('pan ext')).others,
        ),
        ['PANADOL EXTRA 24 F.C.TABS.'],
      );
      expect(
        (await search(
          profile: CatalogProfile.empty,
        ).drugs('panadol zzz')).isEmpty,
        isTrue,
      );
    });

    test(
      'the catalog needs 2 typed characters; the history works from the first',
      () async {
        final history = FixedHistory(
          drugItems: const [DrugHit(name: 'Aspocid 75', catalogId: 'drug:16')],
        );
        final one = await search(history: history).drugs('a');
        expect(one.usedBefore, hasLength(1));
        expect(one.mySpecialty, isEmpty);
        expect(one.others, isEmpty);
        expect(one.catalogReady, isTrue);

        final two = await search(history: history).drugs('as');
        expect(two.usedBefore, hasLength(1));
        // ASPOCID is the history's item already.
        expect(
          names(two.mySpecialty),
          isNot(contains('ASPOCID 75 MG 30 TABS.')),
        );
        expect(LocalCatalogSearch.searchesCatalog('a'), isFalse);
        expect(LocalCatalogSearch.searchesCatalog('اب'), isTrue);
      },
    );

    test('before the catalog is ready only the history answers', () async {
      final history = FixedHistory(
        drugItems: const [DrugHit(name: 'Lipitor 20')],
      );
      final hits = await search(
        history: history,
        ready: false,
      ).drugs('lipitor');
      expect(hits.catalogReady, isFalse);
      expect(hits.usedBefore, hasLength(1));
      expect(hits.mySpecialty, isEmpty);
      expect(hits.others, isEmpty);
    });
  });

  group('filling and order (BR-CAT7)', () {
    test(
      'a hit carries the row: id, Arabic name, ingredient, route, maker, strength, form and group',
      () async {
        final hit = (await search().drugs('cetal')).mySpecialty.single;
        expect(hit.catalogId, startsWith('drug:'));
        expect(hit.nameAr, 'سيتال');
        expect(hit.activeIngredient, 'PARACETAMOL(ACETAMINOPHEN)');
        expect(hit.route, 'ORAL.LIQUID');
        expect(hit.manufacturer, 'EIPICO');
        expect(hit.strengthHint, parseStrength('CETAL 250MG/5ML SYRUP 100 ML'));
        expect(hit.strengthHint, '250 MG/5 ML');
        expect(hit.formHint, 'syrup');
        expect(hit.groupId, 'analgesics');
        expect(hit.custom, isFalse);
        expect(mayBeUnavailable(hit), isFalse);
      },
    );

    test('N/A products come last in their section, flagged', () async {
      final hits = await search().drugs('ator');
      expect(hits.mySpecialty.last.name, 'ATORSTAT 40 MG 10 TABS.');
      expect(mayBeUnavailable(hits.mySpecialty.last), isTrue);
      expect(
        hits.mySpecialty
            .take(hits.mySpecialty.length - 1)
            .any(mayBeUnavailable),
        isFalse,
      );

      final paracetamol = await search(
        profile: CatalogProfile.empty,
      ).drugs('paracetamol');
      expect(paracetamol.others.last.name, 'PARAMOL 125 MG 5 SUPP.');
      expect(mayBeUnavailable(paracetamol.others.last), isTrue);
    });

    test('preferred routes come first inside a section [S]', () async {
      const pediatrics = CatalogProfile(
        drugGroups: {'analgesics'},
        routes: {'ORAL.LIQUID', 'RECTAL'},
      );
      final hits = await search(profile: pediatrics).drugs('paracetamol');
      expect(hits.mySpecialty.first.name, 'CETAL 250MG/5ML SYRUP 100 ML');
      // The suppository is preferred too, but N/A YET stays last.
      expect(hits.mySpecialty.last.name, 'PARAMOL 125 MG 5 SUPP.');
    });

    test('the editor forms', () {
      expect(editorFormOf('Tablet', 'ORAL.SOLID'), 'tablet');
      expect(editorFormOf('Eye drops', 'EYE'), 'drops');
      expect(editorFormOf('Suspension', 'ORAL.LIQUID'), 'syrup');
      expect(editorFormOf('Ampoule', 'INJECTION'), 'injection');
      expect(editorFormOf('Effervescent tablet', 'EFF'), 'tablet');
      expect(editorFormOf(null, 'RECTAL'), 'suppository');
      expect(editorFormOf('Soap', 'SOAP'), isNull);
      expect(editorFormOf(null, 'UNKNOWN'), isNull);
    });
  });

  group('custom items (BR-CAT9)', () {
    final custom = [
      const CustomCatalogItem(
        customItemId: 'c1',
        type: CatalogItemType.drug,
        nameEn: 'NEWCILLIN 500 MG 12 CAPS.',
        nameAr: 'نيوسيلين',
        activeIngredient: 'AMOXICILLIN',
        drugGroupId: 'antibiotics',
        route: 'ORAL.SOLID',
      ),
      const CustomCatalogItem(
        customItemId: 'c2',
        type: CatalogItemType.drug,
        nameEn: 'ATORLIFE 10 MG',
        activeIngredient: 'ATORVASTATIN',
        drugGroupId: 'lipid_lowering',
      ),
      const CustomCatalogItem(
        customItemId: 'c3',
        type: CatalogItemType.drug,
        nameEn: 'ATOROLD',
        active: false,
      ),
      const CustomCatalogItem(
        customItemId: 'c4',
        type: CatalogItemType.lab,
        nameEn: 'H. pylori antigen in stool',
        nameAr: 'جرثومة المعدة في البراز',
      ),
    ];

    test(
      'merged first into their section; inactive ones are left out',
      () async {
        final hits = await search(custom: custom).drugs('ator');
        expect(hits.mySpecialty.first.name, 'ATORLIFE 10 MG');
        expect(hits.mySpecialty.first.custom, isTrue);
        expect(hits.mySpecialty.first.catalogId, 'custom:c2');
        expect(hits.mySpecialty.first.strengthHint, '10 MG');
        expect(
          names([...hits.mySpecialty, ...hits.others]),
          isNot(contains('ATOROLD')),
        );
      },
    );

    test(
      'found by Arabic name, ingredient and skeleton; outside the profile in other specialties',
      () async {
        final arabic = await search(custom: custom).drugs('نيوسلين');
        expect(names(arabic.others), ['NEWCILLIN 500 MG 12 CAPS.']);
        final ingredient = await search(custom: custom).drugs('amoxi');
        expect(names(ingredient.others), contains('NEWCILLIN 500 MG 12 CAPS.'));
      },
    );

    test('custom tests appear in D14', () async {
      final hits = await search(
        custom: custom,
      ).tests('جرثومة', category: 'lab');
      expect(hits.others.single.name, 'H. pylori antigen in stool');
      expect(hits.others.single.custom, isTrue);
    });
  });

  group('lab tests and radiology (D14, BR-CAT10)', () {
    test(
      '"CBC" and «صورة دم كاملة» find the blood count first, with our Arabic name and aliases',
      () async {
        for (final typed in ['CBC', 'صورة دم كاملة', 'صوره دم']) {
          final hits = await search(
            profile: CatalogProfile.empty,
          ).tests(typed, category: 'lab');
          final first = hits.others.first;
          expect(first.code, '99001-0', reason: typed);
          expect(first.name, 'Complete blood count panel - Blood');
          expect(first.nameAr, 'صورة دم كاملة');
          expect(first.aliases, ['CBC']);
          expect(first.category, 'lab');
        }
      },
    );

    test('recommended lab codes go under "Your specialty"', () async {
      final hits = await search().tests('trop');
      expect(hits.mySpecialty.single.code, '99007-7');
    });

    test('radiology by region or focus, with modality and region', () async {
      final hits = await search().tests('echo', category: 'radiology');
      final echo = hits.mySpecialty.single;
      expect(echo.code, '99103-4');
      expect(echo.modality, 'US');
      expect(echo.region, 'Chest');
      expect(echo.nameAr, 'إيكو على القلب');

      final xray = await search().tests('X-ray', category: 'radiology');
      expect(xray.mySpecialty, isEmpty);
      expect(
        xray.others.map((h) => h.code),
        containsAll(['99101-8', '99106-7']),
      );
      // Egypt priority first.
      expect(xray.others.first.code, '99101-8');
    });

    test('Arabic modality words find procedures', () async {
      final hits = await search(
        profile: CatalogProfile.empty,
      ).tests('سونار', category: 'radiology');
      expect(
        hits.others.map((h) => h.code),
        containsAll(['99102-6', '99103-4', '99108-3']),
      );
    });

    test('both kinds together when no category is given', () async {
      final hits = await search(profile: CatalogProfile.empty).tests('cr');
      final kinds = hits.others.map((h) => h.category).toSet();
      expect(kinds, contains('lab'));
    });
  });
}
