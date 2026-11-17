import 'dart:convert';
import 'dart:io';

import 'package:catalog_builder/catalog_builder.dart';
import 'package:catalog_core/catalog_core.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'paths.dart';

/// End-to-end builds on the fixture: real rows of the CC0 drug dataset and a
/// synthetic LOINC release (no LOINC content is committed).
void main() {
  late Directory out;
  setUp(() => out = Directory.systemTemp.createTempSync('catalog_build_'));
  tearDown(() => out.deleteSync(recursive: true));

  BuildResult build({String? drugs, bool allowDrop = false, int? version}) => buildCatalog(
    BuildOptions(
      sourcesDir: fixtureSources,
      drugsCsv: drugs ?? fixtureDrugs,
      drugSourceDate: '2026-01-15',
      mappingsDir: fixtureMappings,
      outDir: out.path,
      catalogVersion: version,
      allowDrop: allowDrop,
      builtAt: DateTime.utc(2026, 11, 17, 10),
    ),
  );

  test('builds the file, the gzip copy and a matching manifest', () {
    final result = build();
    expect(result.checks.where((c) => !c.passed), isEmpty, reason: result.checks.join('\n'));
    expect(result.passed, isTrue);

    final manifestFile = File(p.join(out.path, 'catalog-v1.json'));
    final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    final gz = File(result.gzipPath!).readAsBytesSync();
    expect(manifest['catalog_version'], 1);
    expect(manifest['schema_version'], catalogSchemaVersion);
    expect(manifest['sha256'], sha256.convert(gz).toString());
    expect(manifest['size_bytes'], gz.length);
    expect(manifest['counts'], {'drugs': 16, 'labs': 3, 'radiology': 3, 'ingredients': 13});
    expect(manifest['drug_source_date'], '2026-01-15');
    expect(manifest['loinc_release'], '9.99');
    expect(manifest['built_at'], '2026-11-17T10:00:00.000Z');
    // The .gz is the .sqlite file, compressed.
    expect(GZipCodec().decode(gz), File(result.databasePath).readAsBytesSync());
  });

  test('passes every AC-18 search on the fixture', () {
    final result = build();
    final ac18 = result.checks.where((c) => c.name.startsWith('AC-18')).toList();
    expect(ac18, hasLength(7));
    expect(ac18.where((c) => !c.passed), isEmpty, reason: ac18.join('\n'));
  });

  test('writes the tables of spec 9.5 with clean names and the added columns', () {
    final result = build();
    final db = sqlite3.open(result.databasePath, mode: OpenMode.readOnly);
    addTearDown(db.close);

    final meta = db.select('SELECT * FROM meta').single;
    expect(meta['schema_version'], catalogSchemaVersion);
    expect(meta['catalog_version'], 1);
    expect(meta['loinc_release'], '9.99');

    final abilify = db.select("SELECT * FROM drugs WHERE trade_name_en LIKE 'ABILIFY 10%'").single;
    expect(abilify['trade_name_en'], 'ABILIFY 10 MG 10 DISCMELT ORALLY DIS.TABS.');
    expect(abilify['status'], DrugStatus.notAvailable);
    expect(abilify['strength_hint'], '10 MG');
    expect(abilify['group_id'], 'antipsychotics');

    // Withdrawn products are not in the file.
    expect(db.select("SELECT * FROM drugs WHERE trade_name_en LIKE 'ACILIGHT%'"), isEmpty);

    // Route-specific class rows and the ingredient fallback.
    expect(
      db.select("SELECT group_id FROM drugs WHERE trade_name_en LIKE 'BETADERM%'").single['group_id'],
      'topical_steroids',
    );
    expect(
      db.select("SELECT group_id FROM drugs WHERE trade_name_en LIKE 'FIXTURE STATIN%'").single['group_id'],
      'lipid_lowering',
    );

    // Every product containing paracetamol is linked to that ingredient.
    final paracetamol = db.select('''
      SELECT COUNT(*) AS n FROM drug_ingredients di JOIN ingredients i ON i.id = di.ingredient_id
      WHERE i.name = 'PARACETAMOL(ACETAMINOPHEN)' ''').single['n'];
    expect(paracetamol, 4);

    final cbc = db.select('SELECT * FROM lab_tests WHERE id = ?', [loincToId('99001-0')]).single;
    expect(cbc['loinc_code'], '99001-0');
    expect(cbc['name_en'], 'Fixture complete blood panel - Blood'); // LOINC name unchanged (BR-CAT10)
    expect(cbc['name_ar'], 'صورة دم كاملة');
    expect(cbc['aliases'], 'CBC');
    expect(cbc['priority'], CatalogPriority.egypt);
    expect(cbc['order_rank'], 3);

    final sugar = db.select('SELECT priority FROM lab_tests WHERE loinc_code = ?', ['99002-8']).single;
    expect(sugar['priority'], CatalogPriority.egypt);
    final kidney = db.select('SELECT priority FROM lab_tests WHERE loinc_code = ?', ['99010-1']).single;
    expect(kidney['priority'], CatalogPriority.none);

    final heart = db.select('SELECT * FROM radiology WHERE loinc_code = ?', ['99022-6']).single;
    expect(heart['modality'], 'US');
    expect(heart['region'], 'Chest');
    expect(heart['focus'], 'Heart');
    expect(heart['name_ar'], 'إيكو على القلب');

    expect(db.select('SELECT code FROM modalities ORDER BY code').map((r) => r['code']), ['CT', 'US', 'XR']);
  });

  test('finds radiology by Arabic modality and region words', () {
    final result = build();
    final db = sqlite3.open(result.databasePath, mode: OpenMode.readOnly);
    addTearDown(db.close);
    final codes = db
        .select(CatalogSearchSql.radiology, [ftsPrefixQuery('سونار بطن'), 5])
        .map((r) => r['loinc_code'])
        .toList();
    expect(codes, ['99021-8']);
  });

  test('fails when too many products land in "other", and writes no .gz', () {
    final drugs = File(p.join(out.path, 'drugs.csv'))
      ..writeAsStringSync(
        [
          File(fixtureDrugs).readAsStringSync().trimRight(),
          'NEW ONE 10 TABS.,نيو,ZZZ,X,A BRAND NEW CLASS,ORAL.SOLID,1',
          'NEW TWO 10 TABS.,نيو,YYY,X,A BRAND NEW CLASS,ORAL.SOLID,1',
        ].join('\n'),
      );
    final result = build(drugs: drugs.path);
    expect(result.passed, isFalse);
    expect(result.gzipPath, isNull);
    expect(File(p.join(out.path, 'catalog-v1.json')).existsSync(), isFalse);
    final other = result.checks.firstWhere((c) => c.name.contains('"other"'));
    expect(other.passed, isFalse);
    expect(File(result.reportPath).readAsStringSync(), contains('A BRAND NEW CLASS'));
  });

  test('numbers versions and refuses a drop of more than 5% unless allowed', () {
    expect(build().passed, isTrue);
    final fewer = File(p.join(out.path, 'fewer.csv'))
      ..writeAsStringSync(File(fixtureDrugs).readAsLinesSync().where((l) => !l.startsWith('OMEZ')).join('\n'));

    final second = build(drugs: fewer.path);
    expect(second.passed, isFalse);
    expect(second.checks.firstWhere((c) => c.name.contains('Count of drugs')).passed, isFalse);
    expect(p.basename(second.databasePath), 'catalog-v2.sqlite');

    final allowed = build(drugs: fewer.path, allowDrop: true);
    expect(allowed.passed, isTrue);
    expect(allowed.manifest['catalog_version'], 2);
  });

  test('stops with a clear error when a profile points at a missing item', () {
    final mappings = copyToTemp(fixtureMappings);
    addTearDown(() => mappings.deleteSync(recursive: true));
    File(
      p.join(mappings.path, 'specialty-profiles.csv'),
    ).writeAsStringSync('Cardiology,labCode,12345-6\n', mode: FileMode.append);
    expect(
      () => buildCatalog(
        BuildOptions(
          sourcesDir: fixtureSources,
          drugsCsv: fixtureDrugs,
          drugSourceDate: '2026-01-15',
          mappingsDir: mappings.path,
          outDir: out.path,
        ),
      ),
      throwsA(isA<MappingDataErrors>().having((e) => e.toString(), 'message', contains('12345-6'))),
    );
  });
}
