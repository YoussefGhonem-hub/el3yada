import 'package:catalog_core/catalog_core.dart';

import '../domain/catalog_search.dart';
import 'catalog_db.dart';

/// A value of the catalog with how many rows have it (AD19's checklists).
class CatalogValueCount {
  const CatalogValueCount(this.value, this.count, {this.nameEn, this.nameAr});

  final String value;
  final int count;
  final String? nameEn;
  final String? nameAr;

  String label(String languageCode) => (languageCode == 'ar' ? nameAr : nameEn) ?? nameEn ?? value;
}

/// The `meta` row of a catalog file.
class CatalogFileMeta {
  const CatalogFileMeta({
    required this.schemaVersion,
    required this.catalogVersion,
    this.drugSourceDate,
    this.loincRelease,
  });

  final int schemaVersion;
  final int catalogVersion;
  final String? drugSourceDate;
  final String? loincRelease;
}

/// Lookups in the open catalog for AD19 (the lists an admin picks from) and
/// AD20. Simple reads by key or group; searches go through
/// `LocalCatalogSearch` and catalog_core's SQL.
class CatalogReader {
  const CatalogReader(this.db);

  final CatalogDb db;

  Future<CatalogFileMeta> meta() async {
    final row = (await db.select('SELECT * FROM ${MetaTable.name} LIMIT 1')).single;
    return CatalogFileMeta(
      schemaVersion: (row[MetaTable.schemaVersion] as int?) ?? 0,
      catalogVersion: (row[MetaTable.catalogVersion] as int?) ?? 0,
      drugSourceDate: row[MetaTable.drugSourceDate] as String?,
      loincRelease: row[MetaTable.loincRelease] as String?,
    );
  }

  /// The clean medicine groups (BR-CAT5) with their product counts, largest
  /// first; groups without products are left out.
  Future<List<CatalogValueCount>> drugGroups() async => [
    for (final row in await db.select(
      'SELECT g.${DrugGroupsTable.id} AS id, g.${DrugGroupsTable.nameEn} AS en, g.${DrugGroupsTable.nameAr} AS ar, '
      'COUNT(d.${DrugsTable.id}) AS n FROM ${DrugGroupsTable.name} g '
      'JOIN ${DrugsTable.name} d ON d.${DrugsTable.groupId} = g.${DrugGroupsTable.id} '
      'GROUP BY g.${DrugGroupsTable.id} ORDER BY n DESC, en',
    ))
      CatalogValueCount(
        row['id']! as String,
        row['n']! as int,
        nameEn: row['en'] as String?,
        nameAr: row['ar'] as String?,
      ),
  ];

  /// The dataset's routes (`ORAL.SOLID` …) with product counts.
  Future<List<CatalogValueCount>> routes() async => [
    for (final row in await db.select(
      'SELECT ${DrugsTable.route} AS route, COUNT(*) AS n FROM ${DrugsTable.name} '
      'GROUP BY ${DrugsTable.route} ORDER BY n DESC',
    ))
      CatalogValueCount(row['route']! as String, row['n']! as int),
  ];

  /// Radiology modalities with their names (A.5.3) and procedure counts.
  Future<List<CatalogValueCount>> modalities() async {
    final names = {
      for (final row in await db.select('SELECT * FROM ${ModalitiesTable.name}'))
        row[ModalitiesTable.code]! as String: (
          row[ModalitiesTable.nameEn] as String?,
          row[ModalitiesTable.nameAr] as String?,
        ),
    };
    final counts = <String, int>{};
    for (final row in await db.select(
      'SELECT ${RadiologyTable.modality} AS m, COUNT(*) AS n FROM ${RadiologyTable.name} '
      'WHERE ${RadiologyTable.modality} IS NOT NULL GROUP BY m',
    )) {
      for (final value in (row['m']! as String).split(';')) {
        counts[value] = (counts[value] ?? 0) + (row['n']! as int);
      }
    }
    final codes = {...names.keys, ...counts.keys}.toList()..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    return [
      for (final code in codes)
        CatalogValueCount(code, counts[code] ?? 0, nameEn: names[code]?.$1, nameAr: names[code]?.$2),
    ];
  }

  /// Every region imaged and imaging focus (profile `radiologyRegion`
  /// values match either), with procedure counts, largest first.
  Future<List<CatalogValueCount>> radiologyRegions() async {
    final counts = <String, int>{};
    for (final row in await db.select(
      'SELECT ${RadiologyTable.region} AS r, ${RadiologyTable.focus} AS f, COUNT(*) AS n FROM ${RadiologyTable.name} '
      'GROUP BY r, f',
    )) {
      final values = {
        for (final column in [row['r'], row['f']])
          if (column is String)
            for (final value in column.split(';'))
              if (value.trim().isNotEmpty) value.trim(),
      };
      for (final value in values) {
        counts[value] = (counts[value] ?? 0) + (row['n']! as int);
      }
    }
    final values = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.compareTo(b);
      });
    return [for (final value in values) CatalogValueCount(value, counts[value]!)];
  }

  /// The lab tests with these LOINC codes, as hits (unknown codes are left out).
  Future<List<TestHit>> labs(Iterable<String> codes) => _tests(codes, lab: true);

  Future<List<TestHit>> radiology(Iterable<String> codes) => _tests(codes, lab: false);

  Future<List<TestHit>> _tests(Iterable<String> codes, {required bool lab}) async {
    final ids = <int>[];
    for (final code in codes) {
      try {
        ids.add(loincToId(code));
      } on FormatException {
        // Not a LOINC code: nothing to look up.
      }
    }
    if (ids.isEmpty) return const [];
    final marks = List.filled(ids.length, '?').join(', ');
    final rows = lab
        ? await db.select(
            'SELECT ${LabTestsTable.loincCode} AS code, ${LabTestsTable.nameEn} AS en, ${LabTestsTable.nameAr} AS ar, '
            '${LabTestsTable.aliases} AS aliases, NULL AS modality, NULL AS region '
            'FROM ${LabTestsTable.name} WHERE ${LabTestsTable.id} IN ($marks)',
            ids,
          )
        : await db.select(
            'SELECT ${RadiologyTable.loincCode} AS code, ${RadiologyTable.nameEn} AS en, ${RadiologyTable.nameAr} AS ar, '
            '${RadiologyTable.aliases} AS aliases, ${RadiologyTable.modality} AS modality, '
            'COALESCE(${RadiologyTable.region}, ${RadiologyTable.focus}) AS region '
            'FROM ${RadiologyTable.name} WHERE ${RadiologyTable.id} IN ($marks)',
            ids,
          );
    return [
      for (final row in rows)
        TestHit(
          name: row['en']! as String,
          code: row['code'] as String?,
          category: lab ? 'lab' : 'radiology',
          nameAr: row['ar'] as String?,
          aliases: (row['aliases'] as String?)?.split('; ') ?? const [],
          modality: (row['modality'] as String?)?.replaceAll(';', ', '),
          region: (row['region'] as String?)?.replaceAll(';', ', '),
        ),
    ];
  }
}
