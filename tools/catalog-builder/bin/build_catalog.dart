import 'dart:io';

import 'package:args/args.dart';
import 'package:catalog_builder/catalog_builder.dart';
import 'package:path/path.dart' as p;

/// Builds the catalog. Run from tools/catalog-builder:
///
///     dart run bin/build_catalog.dart --sources <dir> [--drugs <csv>]
///
/// See README.md.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('sources', help: 'Folder with loinc/<release>/ (and optionally drugs/<date>/egyptian-drugs.csv).')
    ..addOption('drugs', help: 'The drug CSV. Default: the newest <sources>/drugs/*/egyptian-drugs.csv.')
    ..addOption('drug-source-date',
        help: 'When the drug dataset last changed (YYYY-MM-DD). Default: the name of the folder holding the CSV.')
    ..addOption('loinc-release', help: 'LOINC release folder under <sources>/loinc. Default: the highest one.')
    ..addOption('mappings', defaultsTo: 'mappings', help: 'Folder with the mapping CSV files.')
    ..addOption('out', defaultsTo: 'out', help: 'Output folder.')
    ..addOption('catalog-version', help: 'Catalog version number. Default: the last one in --out plus 1.')
    ..addOption('page-size', defaultsTo: '$defaultPageSize', help: 'SQLite page size.')
    ..addFlag('allow-drop', negatable: false, help: 'Accept counts more than 5% lower than the previous version.')
    ..addFlag('keep-withdrawn',
        negatable: false, help: 'Keep products marked (CANCELLED), (ILLEGAL IMPORT) or (WITHDRAWAL).')
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exit(64);
  }
  if (args.flag('help') || args.option('sources') == null) {
    stdout.writeln('Usage: dart run bin/build_catalog.dart --sources <dir> [options]\n\n${parser.usage}');
    exit(args.flag('help') ? 0 : 64);
  }

  final sources = args.option('sources')!;
  final drugs = args.option('drugs') ?? _findDrugCsv(sources);
  if (drugs == null || !File(drugs).existsSync()) {
    stderr.writeln('Drug CSV not found. Pass --drugs <path> or put it at <sources>/drugs/<date>/egyptian-drugs.csv.');
    exit(66);
  }
  final drugDate = args.option('drug-source-date') ?? p.basename(p.dirname(drugs));
  final version = args.option('catalog-version');

  try {
    final result = buildCatalog(
      BuildOptions(
        sourcesDir: sources,
        drugsCsv: drugs,
        drugSourceDate: drugDate,
        mappingsDir: args.option('mappings')!,
        outDir: args.option('out')!,
        loincVersion: args.option('loinc-release'),
        catalogVersion: version == null ? null : int.parse(version),
        allowDrop: args.flag('allow-drop'),
        keepWithdrawn: args.flag('keep-withdrawn'),
        pageSize: int.parse(args.option('page-size')!),
      ),
      log: stdout.writeln,
    );
    stdout.writeln('Report: ${result.reportPath}');
    if (!result.passed) {
      stderr.writeln('Build failed: ${result.checks.where((c) => !c.passed).length} check(s) did not pass.');
      exit(1);
    }
  } on MappingDataErrors catch (e) {
    stderr.writeln(e);
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('${e.message}: ${e.path}');
    exit(1);
  }
}

/// The newest `<sources>/drugs/<folder>/egyptian-drugs.csv`, by folder name.
String? _findDrugCsv(String sources) {
  final dir = Directory(p.join(sources, 'drugs'));
  if (!dir.existsSync()) return null;
  final candidates = dir
      .listSync()
      .whereType<Directory>()
      .map((d) => p.join(d.path, 'egyptian-drugs.csv'))
      .where((f) => File(f).existsSync())
      .toList()
    ..sort();
  return candidates.isEmpty ? null : candidates.last;
}
