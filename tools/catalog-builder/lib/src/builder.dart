import 'dart:convert';
import 'dart:io';

import 'package:catalog_core/catalog_core.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'catalog.dart';
import 'checks.dart';
import 'csv.dart';
import 'database.dart';
import 'drugs.dart';
import 'loinc.dart';
import 'mappings.dart';

/// Inputs of one build.
class BuildOptions {
  BuildOptions({
    required this.sourcesDir,
    required this.drugsCsv,
    required this.drugSourceDate,
    required this.mappingsDir,
    required this.outDir,
    this.loincVersion,
    this.catalogVersion,
    this.allowDrop = false,
    this.keepWithdrawn = false,
    this.builtAt,
    this.pageSize = defaultPageSize,
  });

  /// Folder holding `loinc/<release>/`.
  final String sourcesDir;
  final String drugsCsv;

  /// When the drug dataset was last changed, e.g. "2026-06-20".
  final String drugSourceDate;
  final String mappingsDir;
  final String outDir;
  final String? loincVersion;

  /// Defaults to the highest version in [outDir] plus one.
  final int? catalogVersion;

  /// Accept a drop of more than 5% in a count against the previous version.
  final bool allowDrop;

  /// Keep cancelled, illegal-import and withdrawn products.
  final bool keepWithdrawn;
  final DateTime? builtAt;
  final int pageSize;
}

/// What a build produced.
class BuildResult {
  BuildResult({
    required this.passed,
    required this.manifest,
    required this.databasePath,
    required this.gzipPath,
    required this.reportPath,
    required this.checks,
  });

  /// False when any check failed; the .gz and manifest are then not written.
  final bool passed;
  final Map<String, Object?> manifest;
  final String databasePath;
  final String? gzipPath;
  final String reportPath;
  final List<CheckResult> checks;
}

/// Builds a catalog. Progress and the report go to [log].
BuildResult buildCatalog(BuildOptions options, {void Function(String line)? log}) {
  final report = StringBuffer();
  void say(String line) {
    report.writeln(line);
    log?.call(line);
  }

  final started = DateTime.now();
  final builtAt = (options.builtAt ?? DateTime.now()).toUtc();
  Directory(options.outDir).createSync(recursive: true);
  final previous = _previousManifest(options.outDir);
  final version = options.catalogVersion ?? ((previous?['catalog_version'] as int?) ?? 0) + 1;

  say('el3yada catalog builder — catalog v$version, schema v$catalogSchemaVersion');

  final mappings = Mappings.load(options.mappingsDir);
  say('Mappings: ${mappings.groups.length} groups, ${mappings.classToGroup.length} class rows, '
      '${mappings.formTokens.length} form tokens, ${mappings.aliases.length} aliases, '
      '${mappings.profiles.length} specialty profile rows');

  // Medicines.
  final drugSet = readDrugs(options.drugsCsv, mappings, keepWithdrawn: options.keepWithdrawn);
  assignGroups(drugSet.drugs, mappings);
  final drugs = drugSet.drugs;
  say('');
  say('Medicines: ${drugSet.rowsRead} rows read from ${p.basename(options.drugsCsv)}');
  if (drugSet.excluded.isNotEmpty) {
    say('  left out: ${drugSet.excluded.entries.map((e) => '${e.value} ${e.key.name}').join(', ')}'
        '${options.keepWithdrawn ? '' : ' (use --keep-withdrawn to keep them)'}');
  }
  final byStatus = <int, int>{};
  for (final d in drugs) {
    byStatus[d.marker.status] = (byStatus[d.marker.status] ?? 0) + 1;
  }
  say('  kept: ${drugs.length} (${byStatus[DrugStatus.notAvailable] ?? 0} marked N/A, '
      '${byStatus[DrugStatus.notAvailableYet] ?? 0} marked N/A YET)');
  final otherDrugs = drugs.where((d) => d.groupId == DrugGroupsTable.otherId).toList();
  final fallback = drugs.where((d) => d.groupSource == GroupSource.ingredientFallback).length;
  final unmapped = <String, int>{};
  for (final d in drugs.where((d) => d.groupSource == GroupSource.unmapped)) {
    unmapped[d.rawClass] = (unmapped[d.rawClass] ?? 0) + 1;
  }
  final otherShare = drugs.isEmpty ? 0.0 : otherDrugs.length / drugs.length;
  say('  group "other": ${otherDrugs.length} (${_percent(otherShare)}); '
      '$fallback placed by the ingredient fallback');
  if (unmapped.isNotEmpty) {
    final list = unmapped.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    say('  classes not in class-to-group.csv (${list.length}): '
        '${list.map((e) => '"${e.key}" ${e.value}').join(', ')}');
  }
  final withStrength = drugs.where((d) => d.strength != null).length;
  final withForm = drugs.where((d) => d.form != null).length;
  say('  strength found: $withStrength (${_percent(withStrength / drugs.length)}); '
      'form suggested: $withForm (${_percent(withForm / drugs.length)})');

  // LOINC.
  final release = LoincRelease.find(options.sourcesDir, version: options.loincVersion);
  final loinc = readLoincTable(release.mainTable);
  final ulo = readUniversalLabOrders(release.universalLabOrders);
  final arabicFile = release.variantFile('ar');
  final arabic = arabicFile == null ? <String, VariantNames>{} : readVariant(arabicFile);
  final playbook = readPlaybook(release.playbook);
  say('');
  say('LOINC ${release.version}: ${loinc.length} terms; Universal Lab Orders: ${ulo.length}; '
      'Arabic variant: ${arabicFile == null ? 'none' : '${arabic.length} terms (${p.basename(arabicFile)})'}; '
      'Playbook: ${playbook.length} procedures');

  final warnings = <String>[];
  final content = assembleCatalog(
    drugs: drugs,
    mappings: mappings,
    loinc: loinc,
    universalLabOrders: ulo,
    arabic: arabic,
    playbook: playbook,
    warn: warnings.add,
  );
  for (final w in warnings) {
    say('  warning: $w');
  }
  final labsArabic = content.labs.where((l) => l.nameAr != null).length;
  final labsLoincArabic = content.labs.where((l) => arabic.containsKey(l.term.code)).length;
  final radiologyArabic = content.radiology.where((r) => r.nameAr != null).length;
  final labPriority = <int, int>{};
  for (final l in content.labs) {
    labPriority[l.priority] = (labPriority[l.priority] ?? 0) + 1;
  }
  final labClasses = <String, int>{};
  for (final l in content.labs) {
    labClasses[l.term.loincClass] = (labClasses[l.term.loincClass] ?? 0) + 1;
  }
  final topClasses = labClasses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  say('  lab tests kept: ${content.labs.length} '
      '(${labPriority[CatalogPriority.egypt] ?? 0} Egypt priority, ${labPriority[CatalogPriority.common] ?? 0} common); '
      'largest classes: ${topClasses.take(8).map((e) => '${e.key} ${e.value}').join(', ')}');
  say('  radiology procedures kept: ${content.radiology.length}');
  if (content.thirdPartyExcluded.isNotEmpty) {
    say('  left out for third-party copyright (LOINC licence 10.2): ${content.thirdPartyExcluded.join(', ')}');
  }
  say('  Arabic names: labs $labsArabic of ${content.labs.length} '
      '($labsLoincArabic from the LOINC Arabic variant), radiology $radiologyArabic of ${content.radiology.length}');

  // Database.
  final base = 'catalog-v$version';
  final dbPath = p.join(options.outDir, '$base.sqlite');
  writeCatalogDatabase(
    dbPath,
    content,
    CatalogMeta(
      catalogVersion: version,
      builtAt: builtAt,
      drugSourceDate: options.drugSourceDate,
      loincRelease: release.version,
    ),
    pageSize: options.pageSize,
  );

  final counts = <String, int>{
    'drugs': content.drugs.length,
    'labs': content.labs.length,
    'radiology': content.radiology.length,
    'ingredients': {for (final d in content.drugs) ...d.ingredients}.length,
  };

  // Checks (A.8).
  final checks = <CheckResult>[];
  checks.add(CheckResult(
    'Share of medicines in group "other" is at most 5%',
    otherShare <= 0.05,
    '${otherDrugs.length} of ${drugs.length} (${_percent(otherShare)})',
  ));
  final previousCounts = (previous?['counts'] as Map?)?.cast<String, Object?>();
  for (final entry in counts.entries) {
    final before = previousCounts?[entry.key];
    if (before is! int || before == 0) continue;
    final drop = (before - entry.value) / before;
    checks.add(CheckResult(
      'Count of ${entry.key} did not drop by more than 5% since v${previous!['catalog_version']}',
      drop <= 0.05 || options.allowDrop,
      '$before → ${entry.value}${drop > 0.05 && options.allowDrop ? ' (allowed with --allow-drop)' : ''}',
    ));
  }
  // FTS5 'integrity-check' is issued as an INSERT, so it needs a writable
  // connection; it does not change the file.
  final db = sqlite3.open(dbPath);
  try {
    for (final (name, run) in [
      ('integrity checks', () => runIntegrityChecks(db)),
      ('AC-18 searches', () => runSearchChecks(db, mappings)),
      ('alias searches', () => [runAliasCheck(db, mappings)]),
    ]) {
      try {
        checks.addAll(run());
      } on SqliteException catch (e) {
        checks.add(CheckResult(name, false, 'SQLite error: ${e.message} (${e.causingStatement ?? ''})'));
      }
    }
  } finally {
    db.close();
  }
  say('');
  say('Checks:');
  for (final c in checks) {
    say('  $c');
  }
  final passed = checks.every((c) => c.passed);

  // Compress and describe.
  final rawBytes = File(dbPath).lengthSync();
  String? gzipPath;
  Map<String, Object?> manifest = {};
  if (passed) {
    gzipPath = p.join(options.outDir, '$base.sqlite.gz');
    final gz = GZipCodec(level: 9).encode(File(dbPath).readAsBytesSync());
    File(gzipPath).writeAsBytesSync(gz);
    manifest = {
      'catalog_version': version,
      'schema_version': catalogSchemaVersion,
      'file': p.basename(gzipPath),
      'sha256': sha256.convert(gz).toString(),
      'size_bytes': gz.length,
      'uncompressed_size_bytes': rawBytes,
      'counts': counts,
      'drug_source_date': options.drugSourceDate,
      'loinc_release': release.version,
      'built_at': builtAt.toIso8601String(),
    };
    File(p.join(options.outDir, '$base.json')).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');
    say('');
    say('Size: ${_size(rawBytes)} uncompressed, ${_size(gz.length)} gzip -9 '
        '(${(gz.length * 100 / rawBytes).toStringAsFixed(1)}%)');
    say('Wrote $gzipPath and $base.json');
  } else {
    say('');
    say('Size: ${_size(rawBytes)} uncompressed. Checks failed: the .gz and manifest were not written.');
  }
  _writeSizeBreakdown(dbPath, say);
  _writeClassReport(p.join(options.outDir, '$base-drug-classes.csv'), drugs);
  say('Build took ${DateTime.now().difference(started).inSeconds} s');

  final reportPath = p.join(options.outDir, '$base-report.txt');
  File(reportPath).writeAsStringSync(report.toString());
  return BuildResult(
    passed: passed,
    manifest: manifest,
    databasePath: dbPath,
    gzipPath: gzipPath,
    reportPath: reportPath,
    checks: checks,
  );
}

/// The manifest with the highest catalog version in [outDir], if any.
Map<String, Object?>? _previousManifest(String outDir) {
  Map<String, Object?>? best;
  final dir = Directory(outDir);
  if (!dir.existsSync()) return null;
  for (final file in dir.listSync().whereType<File>()) {
    if (!RegExp(r'catalog-v\d+\.json$').hasMatch(file.path)) continue;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      if (best == null || (json['catalog_version'] as int) > (best['catalog_version'] as int)) best = json;
    } on FormatException {
      continue;
    }
  }
  return best;
}

/// Prints how much space each table takes (dbstat), to keep an eye on size.
void _writeSizeBreakdown(String dbPath, void Function(String) say) {
  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  try {
    final rows = db.select('SELECT name, SUM(pgsize) AS bytes FROM dbstat GROUP BY name ORDER BY bytes DESC');
    final byTable = <String, int>{};
    for (final row in rows) {
      final name = row['name'] as String;
      final table = name.startsWith('fts_') ? name.replaceAll(RegExp(r'_(data|idx|docsize|config|content)$'), '') : name;
      byTable[table] = (byTable[table] ?? 0) + (row['bytes'] as int);
    }
    final sorted = byTable.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    say('Space by table: ${sorted.map((e) => '${e.key} ${_size(e.value)}').join(', ')}');
  } on SqliteException catch (e) {
    say('Space by table: unavailable (${e.message})');
  } finally {
    db.close();
  }
}

/// Writes every raw class with its group and product count, for review.
void _writeClassReport(String path, List<Drug> drugs) {
  final counts = <(String, String, String), int>{};
  for (final d in drugs) {
    final key = (d.rawClass, d.groupId, d.groupSource.name);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final rows = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final out = StringBuffer('raw_drug_class,group_id,how,products\n');
  for (final e in rows) {
    out.writeln('${csvField(e.key.$1)},${e.key.$2},${e.key.$3},${e.value}');
  }
  File(path).writeAsStringSync(out.toString());
}

String _percent(double share) => '${(share * 100).toStringAsFixed(1)}%';

String _size(int bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
