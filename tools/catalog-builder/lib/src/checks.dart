import 'package:catalog_core/catalog_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'mappings.dart';

/// The result of one output check.
class CheckResult {
  CheckResult(this.name, this.passed, this.detail);
  final String name;
  final bool passed;
  final String detail;

  @override
  String toString() => '${passed ? 'PASS' : 'FAIL'}  $name — $detail';
}

/// The drug groups a doctor of [specialty] sees in the specialty section:
/// the specialty's own groups plus the General profile's (BR-CAT3, BR-CAT4).
Set<String> specialtyGroups(Mappings mappings, String specialty) => {
      for (final item in mappings.profiles)
        if (item.itemType == 'drugGroup' && (item.specialty == specialty || item.specialty == 'General')) item.value,
    };

class _DrugHit {
  _DrugHit(this.id, this.tradeName, this.ingredient, this.groupId);
  final int id;
  final String tradeName;
  final String ingredient;
  final String groupId;
}

/// Runs the searches of acceptance criteria AC-18 against a built catalog,
/// using the same normalization and SQL the app uses (catalog_core).
List<CheckResult> runSearchChecks(Database db, Mappings mappings) {
  List<_DrugHit> searchDrugs(String typed, {int limit = 100000}) {
    final query = ftsPrefixQuery(typed);
    if (query == null) return const [];
    return [
      for (final row in db.select(CatalogSearchSql.drugs, [query, limit]))
        _DrugHit(
          row[DrugsTable.id] as int,
          row[DrugsTable.tradeNameEn] as String,
          (row[DrugsTable.activeIngredient] as String?) ?? '',
          row[DrugsTable.groupId] as String,
        ),
    ];
  }

  List<String> searchCodes(String sql, String typed, int limit) {
    final query = ftsPrefixQuery(typed);
    if (query == null) return const [];
    return [for (final row in db.select(sql, [query, limit])) row['loinc_code'] as String];
  }

  /// The results in the specialty section, in order (BR-CAT4 group 2),
  /// capped at 50 like the app (A.6).
  List<_DrugHit> specialtySection(List<_DrugHit> hits, String specialty) {
    final groups = specialtyGroups(mappings, specialty);
    return hits.where((h) => groups.contains(h.groupId)).take(50).toList();
  }

  final results = <CheckResult>[];

  // 1. A cardiologist types "ator": atorvastatin brands in "Your specialty".
  {
    final hits = searchDrugs('ator');
    final section = specialtySection(hits, 'Cardiology');
    final atorvastatin = section.where((h) => h.ingredient.toUpperCase().contains('ATORVASTATIN')).toList();
    final outside = hits.where((h) =>
        h.ingredient.toUpperCase().contains('ATORVASTATIN') &&
        !specialtyGroups(mappings, 'Cardiology').contains(h.groupId));
    results.add(CheckResult(
      'AC-18 "ator" (Cardiology) finds atorvastatin brands in the specialty section',
      atorvastatin.isNotEmpty && outside.isEmpty,
      '${hits.length} results; ${atorvastatin.length} atorvastatin products in the first ${section.length} of the '
          'specialty section, e.g. ${atorvastatin.take(3).map((h) => h.tradeName).join(' | ')}; '
          '${outside.length} atorvastatin products outside it',
    ));
  }

  // 2. The same doctor types "omep": omeprazole through the General profile.
  {
    final hits = searchDrugs('omep');
    final section = specialtySection(hits, 'Cardiology');
    final omeprazole = section.where((h) => h.ingredient.toUpperCase().contains('OMEPRAZOLE')).toList();
    results.add(CheckResult(
      'AC-18 "omep" (Cardiology) finds omeprazole through the General profile',
      omeprazole.isNotEmpty,
      '${hits.length} results; ${omeprazole.length} omeprazole products in the specialty section, '
          'e.g. ${omeprazole.take(3).map((h) => h.tradeName).join(' | ')}',
    ));
  }

  // 3. A dermatologist searches a heart medicine: it is under "other specialties".
  {
    final hits = searchDrugs('bisoprolol');
    final dermatology = specialtyGroups(mappings, 'Dermatology');
    final inSection = hits.where((h) => dermatology.contains(h.groupId)).length;
    results.add(CheckResult(
      'AC-18 a heart medicine ("bisoprolol") is under other specialties for Dermatology',
      hits.isNotEmpty && inSection == 0,
      '${hits.length} results, $inSection of them in the Dermatology specialty section',
    ));
  }

  // 4. «بنادول» finds Panadol.
  {
    final hits = searchDrugs('بنادول', limit: 50);
    final panadol = hits.where((h) => h.tradeName.toUpperCase().startsWith('PANADOL')).toList();
    results.add(CheckResult(
      'AC-18 «بنادول» finds Panadol',
      panadol.isNotEmpty,
      '${hits.length} results, ${panadol.length} Panadol products, e.g. '
          '${panadol.take(3).map((h) => h.tradeName).join(' | ')}',
    ));
  }

  // 5. "paracetamol" lists every brand that contains paracetamol.
  {
    final hits = searchDrugs('paracetamol').map((h) => h.id).toSet();
    final expected = {
      for (final row in db.select(
        'SELECT ${DrugsTable.id} FROM ${DrugsTable.name} WHERE ${DrugsTable.activeIngredient} LIKE ?',
        ['%PARACETAMOL%'],
      ))
        row[DrugsTable.id] as int,
    };
    final missing = expected.difference(hits);
    results.add(CheckResult(
      'AC-18 "paracetamol" lists every product containing paracetamol',
      expected.isNotEmpty && missing.isEmpty,
      '${expected.length} products contain paracetamol; the search returns ${hits.length}; ${missing.length} missing',
    ));
  }

  // 6. "CBC" and «صورة دم كاملة» find the complete blood count.
  for (final typed in ['CBC', 'صورة دم كاملة']) {
    final codes = searchCodes(CatalogSearchSql.labs, typed, 5);
    results.add(CheckResult(
      'AC-18 "$typed" finds the complete blood count (58410-2) in the top 5',
      codes.contains('58410-2'),
      'top 5: ${codes.join(', ')}',
    ));
  }

  return results;
}

/// Extra searches that are not in AC-18 but guard the Egyptian aliases and
/// Arabic radiology words. They fail the build like the others.
List<CheckResult> runExtraSearchChecks(Database db) {
  final cases = [
    (CatalogSearchSql.labs, 'HbA1c', '4548-4'),
    (CatalogSearchSql.labs, 'السكر التراكمي', '4548-4'),
    (CatalogSearchSql.labs, 'وظائف كلى', '24362-6'),
    (CatalogSearchSql.labs, 'ESR', '30341-2'),
    (CatalogSearchSql.radiology, 'سونار بطن', '24558-9'),
    (CatalogSearchSql.radiology, 'chest x-ray', '36643-5'),
    (CatalogSearchSql.radiology, 'إيكو', '42148-7'),
  ];
  return [
    for (final (sql, typed, code) in cases)
      () {
        final query = ftsPrefixQuery(typed)!;
        final codes = [for (final row in db.select(sql, [query, 5])) row['loinc_code'] as String];
        return CheckResult('Search "$typed" finds $code in the top 5', codes.contains(code), 'top 5: ${codes.join(', ')}');
      }(),
  ];
}

/// Structural checks on the built file.
List<CheckResult> runIntegrityChecks(Database db) {
  final results = <CheckResult>[];
  for (final fts in [FtsTables.drugs, FtsTables.labs, FtsTables.radiology]) {
    try {
      db.execute("INSERT INTO $fts($fts) VALUES ('integrity-check')");
      results.add(CheckResult('FTS integrity of $fts', true, 'ok'));
    } on SqliteException catch (e) {
      results.add(CheckResult('FTS integrity of $fts', false, e.message));
    }
  }
  final orphanGroups = db.select('SELECT COUNT(*) AS n FROM ${DrugsTable.name} d '
      'LEFT JOIN ${DrugGroupsTable.name} g ON g.${DrugGroupsTable.id} = d.${DrugsTable.groupId} '
      'WHERE g.${DrugGroupsTable.id} IS NULL').first['n'] as int;
  results.add(CheckResult('Every drug has a known group', orphanGroups == 0, '$orphanGroups drugs without one'));
  final quick = db.select('PRAGMA quick_check').first.values.first;
  results.add(CheckResult('SQLite quick_check', quick == 'ok', '$quick'));
  return results;
}
