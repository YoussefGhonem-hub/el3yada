import 'package:catalog_builder/catalog_builder.dart';
import 'package:test/test.dart';

import 'paths.dart';

/// Uses the synthetic LOINC release in test/fixtures (codes 99xxx, invented
/// names). Real LOINC files are never committed (spec A.7).
void main() {
  final release = LoincRelease.find(fixtureSources);
  final terms = readLoincTable(release.mainTable);

  test('finds the release folder and its version', () {
    expect(release.version, '9.99');
  });

  group('lab filter (A.4.3)', () {
    final kept = terms.values.where((t) => t.isOrderableLab).map((t) => t.code).toSet();

    test('keeps active laboratory terms that can be ordered', () {
      expect(kept, containsAll(['99001-0', '99002-8', '99010-1']));
    });

    test('drops observation-only result lines', () => expect(kept, isNot(contains('99003-6'))));
    test('drops deprecated, discouraged and trial terms', () {
      expect(kept, isNot(contains('99004-4')));
      expect(kept, isNot(contains('99005-1')));
      expect(kept, isNot(contains('99009-3')));
    });
    test('drops surveys, claims attachments and clinical terms', () {
      expect(kept, isNot(contains('99006-9')));
      expect(kept, isNot(contains('99007-7')));
      expect(kept, isNot(contains('99008-5')));
    });
    test('does not take radiology terms as labs', () => expect(kept, isNot(contains('99020-0'))));

    test('leaves out terms with a third-party copyright notice (licence 10.2)', () {
      expect(terms['99011-9']!.hasThirdPartyCopyright, isTrue);
      final content = _assemble(release, terms);
      expect(content.labs.map((l) => l.term.code), isNot(contains('99011-9')));
      expect(content.thirdPartyExcluded, ['99011-9']);
    });
  });

  group('radiology (A.5)', () {
    final playbook = readPlaybook(release.playbook);

    test('reads modality, region and imaging focus', () {
      final heart = playbook['99022-6']!;
      expect(heart.modalities, {'US'});
      expect(heart.regions, {'Chest'});
      expect(heart.foci, {'Heart'});
    });

    test('treats the "XXX" placeholder as no region', () {
      expect(playbook['99023-4']!.regions, isEmpty);
    });

    test('keeps active Playbook procedures and drops deprecated ones', () {
      final content = _assemble(release, terms);
      expect(content.radiology.map((r) => r.term.code), ['99020-0', '99021-8', '99022-6']);
      expect(content.labs.map((l) => l.term.code), ['99001-0', '99002-8', '99010-1']);
    });
  });

  group('Arabic names (A.4.4)', () {
    test('finds the Arabic variant through the index', () {
      expect(release.variantFile('ar'), endsWith('arXX99LinguisticVariant.csv'));
      expect(release.variantFile('xx'), isNull);
    });

    test('our aliases win over the LOINC translation', () {
      final content = _assemble(release, terms);
      final byCode = {for (final l in content.labs) l.term.code: l};
      expect(byCode['99002-8']!.nameAr, 'سكر صائم'); // aliases.csv, not «سكر تجريبي في المصل»
      expect(byCode['99010-1']!.nameAr, 'وظائف كلى');
      expect(byCode['99001-0']!.priority, 2); // priority alias
    });
  });

  test('a release without Arabic has no variant file', () {
    expect(LoincRelease(fixtureSources, 'none').variantFile('ar'), isNull);
  });
}

CatalogContent _assemble(LoincRelease release, Map<String, LoincTerm> terms) {
  final mappings = Mappings.load(fixtureMappings);
  return assembleCatalog(
    drugs: readDrugs(fixtureDrugs, mappings).drugs,
    mappings: mappings,
    loinc: terms,
    universalLabOrders: readUniversalLabOrders(release.universalLabOrders),
    arabic: readVariant(release.variantFile('ar')!),
    playbook: readPlaybook(release.playbook),
  );
}
