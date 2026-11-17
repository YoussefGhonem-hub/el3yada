import 'dart:io';

import 'package:catalog_core/catalog_core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'catalog.dart';

/// Values for the `meta` row.
class CatalogMeta {
  const CatalogMeta({
    required this.catalogVersion,
    required this.builtAt,
    required this.drugSourceDate,
    required this.loincRelease,
  });

  final int catalogVersion;
  final DateTime builtAt;
  final String drugSourceDate;
  final String loincRelease;
}

/// Page size of the catalog file. Measured on the real data: 4096 gave the
/// smallest file once FTS segments are merged (see README).
const defaultPageSize = 4096;

/// Writes [content] to a new SQLite file at [path] (spec 9.5), then merges
/// the FTS segments and vacuums so the file is as small as possible.
void writeCatalogDatabase(String path, CatalogContent content, CatalogMeta meta, {int pageSize = defaultPageSize}) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA page_size = $pageSize');
    db.execute('PRAGMA journal_mode = OFF');
    db.execute('PRAGMA synchronous = OFF');
    for (final statement in CatalogSchema.createStatements) {
      db.execute(statement);
    }
    db.execute('BEGIN');
    _insertAll(db, content, meta);
    db.execute('COMMIT');
    for (final fts in [FtsTables.drugs, FtsTables.labs, FtsTables.radiology]) {
      db.execute("INSERT INTO $fts($fts) VALUES ('optimize')");
    }
    db.execute('VACUUM');
    db.execute('PRAGMA journal_mode = DELETE');
  } finally {
    db.close();
  }
}

void _insertAll(Database db, CatalogContent content, CatalogMeta meta) {
  void insertEach<T>(String sql, Iterable<T> items, List<Object?> Function(T item) values) {
    final statement = db.prepare(sql);
    try {
      for (final item in items) {
        statement.execute(values(item));
      }
    } finally {
      statement.close();
    }
  }

  db.execute('INSERT INTO ${MetaTable.name} VALUES (?, ?, ?, ?, ?)', [
    catalogSchemaVersion,
    meta.catalogVersion,
    meta.builtAt.toUtc().toIso8601String(),
    meta.drugSourceDate,
    meta.loincRelease,
  ]);

  insertEach('INSERT INTO ${DrugGroupsTable.name} VALUES (?, ?, ?)', content.groups, (g) => [g.id, g.nameEn, g.nameAr]);

  // Drugs: ids follow the sorted order, so similar names sit together.
  final drugs = content.drugs;
  insertEach(
    'INSERT INTO ${DrugsTable.name} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    Iterable<int>.generate(drugs.length),
    (i) {
      final d = drugs[i];
      return [
        i + 1,
        d.tradeNameEn,
        _nullIfEmpty(d.tradeNameAr),
        _nullIfEmpty(d.activeIngredient),
        _nullIfEmpty(d.manufacturer),
        d.groupId,
        d.route,
        d.form,
        d.strength,
        d.priceEgp,
        d.marker.status,
      ];
    },
  );
  insertEach(
    'INSERT INTO ${FtsTables.drugs}(rowid, name, ingredient) VALUES (?, ?, ?)',
    Iterable<int>.generate(drugs.length),
    (i) {
      final d = drugs[i];
      final name = withArabicSkeletons(normalizeAndDedupe([d.tradeNameEn, d.tradeNameAr]));
      final ingredientWords = normalizeAndDedupe([d.activeIngredient]);
      return [i + 1, name, ingredientWords];
    },
  );

  // Ingredients (A.3.3).
  final ingredientIds = <String, int>{};
  final names = {for (final d in drugs) ...d.ingredients}.toList()..sort();
  for (var i = 0; i < names.length; i++) {
    ingredientIds[names[i]] = i + 1;
  }
  insertEach('INSERT INTO ${IngredientsTable.name} VALUES (?, ?)', names, (n) => [ingredientIds[n], n]);
  final links = <(int, int)>{};
  for (var i = 0; i < drugs.length; i++) {
    for (final ingredient in drugs[i].ingredients) {
      links.add((ingredientIds[ingredient]!, i + 1));
    }
  }
  insertEach('INSERT INTO ${DrugIngredientsTable.name} VALUES (?, ?)', links, (l) => [l.$1, l.$2]);

  insertEach(
    'INSERT INTO ${LabTestsTable.name} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    content.labs,
    (l) => [
      l.id,
      l.term.code,
      l.term.longName,
      _nullIfEmpty(l.term.shortName),
      l.nameAr,
      l.aliases.isEmpty ? null : l.aliases.join('; '),
      _nullIfEmpty(l.term.loincClass),
      l.priority,
      l.term.commonOrderRank > 0 ? l.term.commonOrderRank : null,
    ],
  );
  insertEach(
    'INSERT INTO ${FtsTables.labs}(rowid, name, alias, related) VALUES (?, ?, ?, ?)',
    content.labs,
    (l) => [l.id, l.ftsName, l.ftsAlias, l.ftsRelated],
  );

  insertEach(
    'INSERT INTO ${RadiologyTable.name} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    content.radiology,
    (r) => [
      r.id,
      r.term.code,
      r.term.longName,
      r.nameAr,
      _joined(r.entry.modalities),
      _joined(r.entry.regions),
      r.aliases.isEmpty ? null : r.aliases.join('; '),
      _joined(r.entry.subtypes),
      _joined(r.entry.foci),
      r.priority,
    ],
  );
  insertEach(
    'INSERT INTO ${FtsTables.radiology}(rowid, name, alias, related) VALUES (?, ?, ?, ?)',
    content.radiology,
    (r) => [r.id, r.ftsName, r.ftsAlias, r.ftsRelated],
  );

  insertEach(
    'INSERT INTO ${ModalitiesTable.name} VALUES (?, ?, ?)',
    content.modalities,
    (m) => [m.value, m.nameEn, m.nameAr],
  );
}

String? _nullIfEmpty(String value) => value.isEmpty ? null : value;

/// Several Playbook values joined with ";", sorted so the file is stable.
String? _joined(Set<String> values) => values.isEmpty ? null : (values.toList()..sort()).join(';');
