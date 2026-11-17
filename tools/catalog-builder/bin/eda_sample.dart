import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:catalog_builder/catalog_builder.dart';

/// Writes the checklist for the EDA spot check (spec A.3.8): a reproducible
/// random sample of the products that go into the catalog, with empty
/// result columns for the person doing the check.
///
///     dart run bin/eda_sample.dart --drugs <csv> --out verification/<date>-drugs-vs-eda.md
void main(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('drugs', help: 'The drug CSV.')
    ..addOption('out', help: 'The Markdown file to write.')
    ..addOption('count', defaultsTo: '200')
    ..addOption('seed', defaultsTo: '20261117', help: 'Random seed, so the same sample can be drawn again.')
    ..addOption('source', defaultsTo: '', help: 'Text describing the dataset version, for the header.');
  final args = parser.parse(arguments);
  final drugs = args.option('drugs');
  final out = args.option('out');
  if (drugs == null || out == null) {
    stderr.writeln('Usage: dart run bin/eda_sample.dart --drugs <csv> --out <file.md>\n${parser.usage}');
    exit(64);
  }
  final count = int.parse(args.option('count')!);
  final seed = int.parse(args.option('seed')!);

  final table = CsvTable.read(drugs)..requireColumns(drugColumns);
  final rows = [
    for (final row in table.rows)
      if (!stripMarkers(CsvTable.cell(row, table.column('commercial_name_en'))).$2.withdrawnFromMarket) row,
  ];
  final sample = [...rows]..shuffle(Random(seed));
  final picked = sample.take(count).toList()..sort((a, b) => CsvTable.cell(a, 0).compareTo(CsvTable.cell(b, 0)));

  String cell(List<String> row, String column) =>
      CsvTable.cell(row, table.column(column)).trim().replaceAll('|', '\\|');

  final md = StringBuffer()
    ..writeln('# Drug dataset vs EDA: spot check (to do)')
    ..writeln()
    ..writeln(
      'Spec Appendix A.3.8 and open question 19. **Not done yet**: every result below is empty until a '
      'person checks it. Do not fill it from memory or from another dataset.',
    )
    ..writeln()
    ..writeln('- Dataset: ${args.option('source')!.isEmpty ? drugs : args.option('source')}')
    ..writeln(
      '- Sample: $count products drawn at random (seed $seed) from the ${rows.length} rows the catalog keeps '
      '(rows marked CANCELLED, ILLEGAL IMPORT or WITHDRAWAL are left out of both). Sorted by trade name.',
    )
    ..writeln('- Regenerate: `dart run bin/eda_sample.dart --drugs <csv> --out <this file> --seed $seed`')
    ..writeln()
    ..writeln('## How to check')
    ..writeln()
    ..writeln(
      '1. Look up each trade name in the EDA drug search '
      '([how to use it](https://www.edaegypt.gov.eg/media/ajqiccqc/np-ppma-18-mechanism-of-egyptian-drug-database-eddb-searching-tool.pdf)).',
    )
    ..writeln('2. In **Result** write one of: `found`, `not found`, `different`.')
    ..writeln(
      '3. For `different`, write what differs in **Notes**: name, active ingredient or company (and the EDA value).',
    )
    ..writeln(
      '4. Fill in the summary. If more than 5% (more than ${(count * 0.05).floor()} of $count) are `not found` '
      'or `different`, escalate open question 19 before launch.',
    )
    ..writeln()
    ..writeln('## Summary (fill in)')
    ..writeln()
    ..writeln('- Checked by: ')
    ..writeln('- Date: ')
    ..writeln('- Found: __ / $count')
    ..writeln('- Not found: __')
    ..writeln('- Different: __')
    ..writeln('- Decision: ')
    ..writeln()
    ..writeln('## Sample')
    ..writeln()
    ..writeln('| # | Trade name (dataset) | Active ingredient | Manufacturer | Result | Notes |')
    ..writeln('|---|---|---|---|---|---|');
  for (var i = 0; i < picked.length; i++) {
    final row = picked[i];
    md.writeln(
      '| ${i + 1} | ${cell(row, 'commercial_name_en')} | ${cell(row, 'scientific_name')} | '
      '${cell(row, 'manufacturer')} |  |  |',
    );
  }
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(md.toString());
  stdout.writeln('Wrote ${picked.length} rows to $out');
}
