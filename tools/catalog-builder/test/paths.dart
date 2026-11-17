import 'dart:io';

import 'package:path/path.dart' as p;

/// Tests run from tools/catalog-builder (`dart test`).
const realMappings = 'mappings';
final fixtureMappings = p.join('test', 'fixtures', 'mappings');
final fixtureSources = p.join('test', 'fixtures', 'sources');
final fixtureDrugs = p.join(fixtureSources, 'drugs', '2026-01', 'egyptian-drugs.csv');

/// The real drug dataset, if it has been downloaded to sources/ (it is not
/// committed). Tests that need it are skipped when it is missing.
String? realDrugCsv() {
  final dir = Directory(p.join('sources', 'drugs'));
  if (!dir.existsSync()) return null;
  final files = dir
      .listSync()
      .whereType<Directory>()
      .map((d) => p.join(d.path, 'egyptian-drugs.csv'))
      .where((f) => File(f).existsSync())
      .toList()
    ..sort();
  return files.isEmpty ? null : files.last;
}

/// Copies [from] into a new temporary folder and returns it.
Directory copyToTemp(String from) {
  final dir = Directory.systemTemp.createTempSync('catalog_builder_test_');
  for (final file in Directory(from).listSync(recursive: true).whereType<File>()) {
    final target = File(p.join(dir.path, p.relative(file.path, from: from)));
    target.parent.createSync(recursive: true);
    file.copySync(target.path);
  }
  return dir;
}
