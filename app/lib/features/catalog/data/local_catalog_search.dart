import 'dart:math';

import 'package:catalog_core/catalog_core.dart';

import '../domain/catalog_models.dart';
import '../domain/catalog_search.dart';
import 'catalog_db.dart';

/// A medicine from the catalog file, with what [DrugHit] can't carry.
class CatalogDrugHit extends DrugHit {
  const CatalogDrugHit({
    required super.name,
    super.catalogId,
    super.nameAr,
    super.activeIngredient,
    super.route,
    super.manufacturer,
    super.strengthHint,
    super.formHint,
    super.groupId,
    super.custom,
    this.mayBeUnavailable = false,
  });

  /// The drug dataset marks the product "(N/A)" or "(N/A YET)": it comes last
  /// in its section, with a small muted «قد لا يكون متوفرًا».
  final bool mayBeUnavailable;
}

/// True for a catalog medicine that may not be on the market (see
/// [CatalogDrugHit.mayBeUnavailable]).
bool mayBeUnavailable(DrugHit hit) => hit is CatalogDrugHit && hit.mayBeUnavailable;

/// The editors' search (D13, D14) over the downloaded catalog file (spec 6.9,
/// A.6), the admin's custom items (BR-CAT9) and the doctor's specialty
/// profile (BR-CAT4).
///
/// "Used before" comes from [history] (the doctor's own items, from the
/// first typed character). This class adds "Your specialty" and «من تخصصات
/// أخرى» from the catalog, never repeating an item:
///
/// * The catalog sections need at least [minCatalogCharacters] typed
///   characters (one letter ranks thousands of rows).
/// * Matching is catalog_core's: every word is a prefix, all words must
///   match, Arabic words also match by their skeleton («بنادول» finds the
///   dataset's «بانادول»).
/// * At most [maxPerSection] per section. Inside a section: the admin's
///   custom items, then the statement's order (`CatalogSearchSql`: for
///   medicines available first and then bm25; for tests the priority
///   (Egypt, then common) and then bm25). Preferred routes of the profile
///   [S] come first among equals. Products marked N/A always come last.
/// * `mySpecialtyOnly` empties «من تخصصات أخرى».
/// * Prices are never read (BR-CAT13).
class LocalCatalogSearch implements CatalogSearch {
  LocalCatalogSearch({
    required this.history,
    required this.database,
    CatalogProfile Function()? profile,
    Iterable<CustomCatalogItem> Function()? customItems,
    this.onTimed,
  }) : _profile = profile ?? (() => CatalogProfile.empty),
       _customItems = customItems ?? (() => const []);

  final CatalogSearch history;

  /// The open catalog, or null until D0 has finished.
  final CatalogDb? Function() database;
  final CatalogProfile Function() _profile;
  final Iterable<CustomCatalogItem> Function() _customItems;

  /// Called after each catalog search with how long it took (measuring).
  final void Function(String kind, String query, Duration took)? onTimed;

  static const maxPerSection = 50;
  static const minCatalogCharacters = 2;

  /// Whether [query] is long enough for the catalog sections.
  static bool searchesCatalog(String query) =>
      normalizeForSearch(query).replaceAll(' ', '').length >= minCatalogCharacters;

  @override
  Future<CatalogHits<DrugHit>> drugs(String query, {bool mySpecialtyOnly = false, int limit = 30}) async {
    final used = await _usedBefore(() => history.drugs(query, mySpecialtyOnly: mySpecialtyOnly, limit: limit));
    final db = _openDatabase();
    final match = ftsPrefixQuery(query);
    if (!searchesCatalog(query) || match == null) return CatalogHits(usedBefore: used, catalogReady: db != null);

    final watch = Stopwatch()..start();
    final perSection = min(limit, maxPerSection);
    final profile = _profile();
    final seen = _Seen()..addAll(used.map(_drugKeys));
    final words = searchWords(query);

    final specialty = <DrugHit>[];
    final others = <DrugHit>[];
    for (final item in _customItems()) {
      if (!item.active || item.type != CatalogItemType.drug || !_customMatches(item, words)) continue;
      final hit = DrugHit(
        name: item.nameEn,
        catalogId: item.catalogId,
        nameAr: item.nameAr,
        activeIngredient: item.activeIngredient,
        route: item.route,
        groupId: item.drugGroupId,
        formHint: editorFormOf(null, item.route),
        strengthHint: parseStrength(item.nameEn),
        custom: true,
      );
      if (!seen.add(_drugKeys(hit))) continue;
      (profile.drugGroups.contains(item.drugGroupId) ? specialty : others).add(hit);
    }

    if (db != null) {
      final skip = <Object>{for (final hit in used) ?_drugRowId(hit.catalogId)};
      // With preferred routes, read more rows so they can move up.
      final room = profile.routes.isEmpty ? perSection : perSection * 4;
      final rows = await db.sectioned(
        SectionedQuery(
          sql: CatalogSearchSql.drugs,
          parameters: [match, -1],
          rule: DrugSectionRule(profile.drugGroups),
          keyColumn: DrugsTable.id,
          skip: skip,
          specialtyLimit: room,
          othersLimit: mySpecialtyOnly ? 0 : room,
        ),
      );
      final arabic = await _arabicNames(db, [...rows.specialty, ...rows.others]);
      DrugHit hitOf(CatalogRow row) => _drugHit(row, arabic[row[DrugsTable.id]]);
      for (final (rowsOf, section) in [(rows.specialty, specialty), (rows.others, others)]) {
        for (final hit in _byRoute(rowsOf.map(hitOf), profile.routes)) {
          if (seen.add(_drugKeys(hit))) section.add(hit);
        }
      }
    }
    onTimed?.call('drugs', query, watch.elapsed);
    return CatalogHits(
      usedBefore: used,
      mySpecialty: specialty.take(perSection).toList(),
      others: mySpecialtyOnly ? const [] : others.take(perSection).toList(),
      catalogReady: db != null,
    );
  }

  @override
  Future<CatalogHits<TestHit>> tests(
    String query, {
    String? category,
    bool mySpecialtyOnly = false,
    int limit = 30,
  }) async {
    final used = await _usedBefore(
      () => history.tests(query, category: category, mySpecialtyOnly: mySpecialtyOnly, limit: limit),
    );
    final db = _openDatabase();
    final match = ftsPrefixQuery(query);
    if (!searchesCatalog(query) || match == null) return CatalogHits(usedBefore: used, catalogReady: db != null);

    final watch = Stopwatch()..start();
    final perSection = min(limit, maxPerSection);
    final profile = _profile();
    final seen = _Seen()..addAll(used.map(_testKeys));
    final words = searchWords(query);
    final kinds = [
      if (category == null || category == CatalogItemType.lab.name) CatalogItemType.lab,
      if (category == null || category == CatalogItemType.radiology.name) CatalogItemType.radiology,
    ];

    final specialty = <TestHit>[];
    final others = <TestHit>[];
    for (final item in _customItems()) {
      if (!item.active || !kinds.contains(item.type) || !_customMatches(item, words)) continue;
      final hit = TestHit(
        name: item.nameEn,
        category: item.type.name,
        code: item.loincCode,
        nameAr: item.nameAr,
        aliases: item.aliases,
        custom: true,
      );
      if (!seen.add(_testKeys(hit))) continue;
      final codes = item.type == CatalogItemType.lab ? profile.labCodes : profile.radiologyCodes;
      (codes.contains(item.loincCode) ? specialty : others).add(hit);
    }

    if (db != null) {
      final skip = <Object>{for (final hit in used) ?hit.code};
      final catalogSpecialty = <(int, TestHit)>[];
      final catalogOthers = <(int, TestHit)>[];
      for (final kind in kinds) {
        final lab = kind == CatalogItemType.lab;
        final rows = await db.sectioned(
          SectionedQuery(
            sql: lab ? CatalogSearchSql.labs : CatalogSearchSql.radiology,
            parameters: [match, -1],
            rule: lab
                ? LabSectionRule(profile.labCodes)
                : RadiologySectionRule(
                    codes: profile.radiologyCodes,
                    regions: profile.radiologyRegions,
                    modalities: profile.radiologyModalities,
                  ),
            keyColumn: lab ? LabTestsTable.loincCode : RadiologyTable.loincCode,
            skip: skip,
            specialtyLimit: perSection,
            othersLimit: mySpecialtyOnly ? 0 : perSection,
          ),
        );
        catalogSpecialty.addAll(rows.specialty.map((row) => (_priority(row), _testHit(row, kind))));
        catalogOthers.addAll(rows.others.map((row) => (_priority(row), _testHit(row, kind))));
      }
      for (final (rowsOf, section) in [(catalogSpecialty, specialty), (catalogOthers, others)]) {
        // Lab tests and radiology together: by priority, each table's order kept.
        for (final (_, hit) in _stableSorted(rowsOf, (a, b) => b.$1.compareTo(a.$1))) {
          if (seen.add(_testKeys(hit))) section.add(hit);
        }
      }
    }
    onTimed?.call('tests', query, watch.elapsed);
    return CatalogHits(
      usedBefore: used,
      mySpecialty: specialty.take(perSection).toList(),
      others: mySpecialtyOnly ? const [] : others.take(perSection).toList(),
      catalogReady: db != null,
    );
  }

  CatalogDb? _openDatabase() {
    final db = database();
    return db?.path == null ? null : db;
  }

  Future<List<T>> _usedBefore<T>(Future<CatalogHits<T>> Function() search) async {
    try {
      return (await search()).usedBefore;
    } on Object {
      // The history is a nice-to-have; the catalog still answers.
      return const [];
    }
  }

  /// `trade_name_ar` is not in `CatalogSearchSql.drugs`: read it for the
  /// few rows shown.
  Future<Map<Object?, String>> _arabicNames(CatalogDb db, List<CatalogRow> rows) async {
    if (rows.isEmpty) return const {};
    final ids = [for (final row in rows) row[DrugsTable.id]];
    final marks = List.filled(ids.length, '?').join(', ');
    final names = await db.select(
      'SELECT ${DrugsTable.id}, ${DrugsTable.tradeNameAr} FROM ${DrugsTable.name} WHERE ${DrugsTable.id} IN ($marks)',
      ids,
    );
    return {
      for (final row in names)
        if (row[DrugsTable.tradeNameAr] case final String name when name.isNotEmpty) row[DrugsTable.id]: name,
    };
  }
}

/// A medicine row of `CatalogSearchSql.drugs` as the editor's hit (BR-CAT7).
DrugHit _drugHit(CatalogRow row, String? nameAr) {
  final name = row[DrugsTable.tradeNameEn] as String;
  final route = row[DrugsTable.route] as String?;
  final status = (row[DrugsTable.status] as int?) ?? DrugStatus.available;
  return CatalogDrugHit(
    name: name,
    catalogId: 'drug:${row[DrugsTable.id]}',
    nameAr: nameAr,
    activeIngredient: row[DrugsTable.activeIngredient] as String?,
    route: route,
    manufacturer: row[DrugsTable.manufacturer] as String?,
    strengthHint: parseStrength(name),
    formHint: editorFormOf(row[DrugsTable.form] as String?, route),
    groupId: row[DrugsTable.groupId] as String?,
    mayBeUnavailable: status != DrugStatus.available,
  );
}

/// A lab or radiology row of `CatalogSearchSql` as the editor's hit. LOINC
/// names are shown as published (BR-CAT10); our Arabic name and aliases
/// come from their own columns.
TestHit _testHit(CatalogRow row, CatalogItemType kind) {
  final lab = kind == CatalogItemType.lab;
  final aliases = row[lab ? LabTestsTable.aliases : RadiologyTable.aliases] as String?;
  return TestHit(
    name: row[lab ? LabTestsTable.nameEn : RadiologyTable.nameEn] as String,
    category: kind.name,
    code: row[lab ? LabTestsTable.loincCode : RadiologyTable.loincCode] as String?,
    nameAr: row[lab ? LabTestsTable.nameAr : RadiologyTable.nameAr] as String?,
    aliases: aliases == null || aliases.isEmpty ? const [] : aliases.split('; '),
    modality: lab ? null : _listed(row[RadiologyTable.modality]),
    region: lab ? null : _listed(row[RadiologyTable.region]) ?? _listed(row[RadiologyTable.focus]),
  );
}

int _priority(CatalogRow row) => (row['priority'] as int?) ?? 0;

String? _listed(Object? joined) {
  if (joined is! String || joined.trim().isEmpty) return null;
  return joined.split(';').map((value) => value.trim()).where((value) => value.isNotEmpty).join(', ');
}

/// The row id of a `drug:123` catalog ID.
int? _drugRowId(String? catalogId) {
  if (catalogId == null || !catalogId.startsWith('drug:')) return null;
  return int.tryParse(catalogId.substring(5));
}

/// Medicines in [hits] with a preferred route first, then the rest; N/A
/// products stay last. The order is otherwise kept.
List<DrugHit> _byRoute(Iterable<DrugHit> hits, Set<String> routes) {
  int rank(DrugHit hit) => (mayBeUnavailable(hit) ? 2 : 0) + (routes.isEmpty || routes.contains(hit.route) ? 0 : 1);
  return _stableSorted(hits.toList(), (a, b) => rank(a).compareTo(rank(b)));
}

List<T> _stableSorted<T>(List<T> items, int Function(T a, T b) compare) {
  final indexed = [for (final (i, item) in items.indexed) (i, item)];
  indexed.sort((a, b) {
    final byValue = compare(a.$2, b.$2);
    return byValue != 0 ? byValue : a.$1.compareTo(b.$1);
  });
  return [for (final (_, item) in indexed) item];
}

/// What makes two hits the same item: the catalog ID or LOINC code, and the
/// normalized name (a typed name in the history is the same item as a
/// catalog row with that exact name).
List<String> _drugKeys(DrugHit hit) => [?hit.catalogId, 'name:${normalizeForSearch(hit.name)}'];

List<String> _testKeys(TestHit hit) => [
  if (hit.code case final code?) 'code:$code',
  'name:${normalizeForSearch(hit.name)}',
];

class _Seen {
  final _keys = <String>{};

  /// Adds the item's keys; false when any was already there.
  bool add(List<String> keys) {
    if (keys.any(_keys.contains)) return false;
    _keys.addAll(keys);
    return true;
  }

  void addAll(Iterable<List<String>> items) {
    for (final keys in items) {
      _keys.addAll(keys);
    }
  }
}

/// BR-CAT6 for a custom item, like the FTS query: every typed word starts a
/// word of its names, ingredient, aliases or code (or, for an Arabic word,
/// its skeleton does).
bool _customMatches(CustomCatalogItem item, List<String> words) {
  if (words.isEmpty) return false;
  final indexed = withArabicSkeletons(
    normalizeAndDedupe([item.nameEn, item.nameAr, item.activeIngredient, ...item.aliases, item.loincCode]),
  ).split(' ');
  return words.every((word) {
    final skeleton = arabicSkeleton(word);
    return indexed.any((target) => target.startsWith(word) || (skeleton != null && target.startsWith(skeleton)));
  });
}

/// One of the editor's forms (`tablet`, `syrup` …) for a catalog medicine:
/// from the builder's suggested form (read from the trade name, A.3.5),
/// otherwise from the route. Null when neither says.
String? editorFormOf(String? form, String? route) {
  final text = (form ?? '').toLowerCase();
  if (text.isNotEmpty) {
    for (final (words, editorForm) in _formWords) {
      if (words.any(text.contains)) return editorForm;
    }
  }
  return switch (route) {
    'ORAL.SOLID' => 'tablet',
    'ORAL.LIQUID' => 'syrup',
    'INJECTION' => 'injection',
    'TOPICAL' => 'cream',
    'EFF' => 'sachet',
    'RECTAL' => 'suppository',
    'EYE' || 'EAR' => 'drops',
    _ => null,
  };
}

/// Checked in order: "Eye drops" is drops, "Effervescent tablet" a tablet.
const _formWords = [
  (['drops'], 'drops'),
  (['suppository'], 'suppository'),
  (['capsule'], 'capsule'),
  (['tablet', 'lozenge', 'oral film'], 'tablet'),
  (['syrup', 'suspension', 'oral solution', 'elixir', 'emulsion'], 'syrup'),
  (['injection', 'ampoule', 'vial', 'infusion', 'syringe', 'pen', 'cartridge'], 'injection'),
  (['inhaler', 'nebulizer', 'inhalation'], 'inhaler'),
  (['sachet', 'granules', 'effervescent', 'powder'], 'sachet'),
  (['cream', 'ointment', 'gel', 'lotion', 'balm', 'paste'], 'cream'),
];
