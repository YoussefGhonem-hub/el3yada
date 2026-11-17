/// The medicine and test search behind D13 and D14 (spec 6.9, BR-CAT4–CAT8).
///
/// The prescription editors only know this interface. Until the local catalog
/// (D0, a sqlite FTS5 file) is on the device, [catalogSearchProvider]
/// (application/catalog_search_provider.dart) answers from the doctor's own
/// history; the catalog feature replaces it with the local-database search.
///
/// **Order (BR-CAT4).** Every implementation returns three sections, in this
/// order, without repeating an item across sections:
///
/// 1. [CatalogHits.usedBefore]: items this doctor has prescribed before
///    (`GET /api/prescriptions/itemHistory`), most used first, then most
///    recent.
/// 2. [CatalogHits.mySpecialty]: items in the doctor's specialty profiles and
///    the General profile (`GET /api/catalog/myProfile`).
/// 3. [CatalogHits.others]: everything else («من تخصصات أخرى»). Empty when
///    `mySpecialtyOnly` is true (the «تخصصي فقط» chip, off by default).
///
/// **Matching (BR-CAT6).** The query matches the start of any word of the
/// trade name (English or Arabic letters) or the active ingredient, ignoring
/// case and Arabic letter variants (`core/search/search_normalizer.dart`, the
/// same rules as the catalog builder, spec A.6). An empty query returns the
/// used-before items only.
///
/// **Filling (BR-CAT7).** Picking a [DrugHit] fills the drug name
/// ([DrugHit.name]), the active ingredient and the catalog ID, and suggests
/// the form ([DrugHit.formHint], from the route) and the strength
/// ([DrugHit.strengthHint], read from the trade name, e.g. "500 MG"). The
/// doctor can change any of them, and can always type a name that isn't in
/// the catalog (BR-CAT8).
abstract class CatalogSearch {
  /// Medicines for D13.
  Future<CatalogHits<DrugHit>> drugs(String query, {bool mySpecialtyOnly = false, int limit = 30});

  /// Lab tests and radiology for D14. [category] is `lab` or `radiology`, or
  /// null for both.
  Future<CatalogHits<TestHit>> tests(String query, {String? category, bool mySpecialtyOnly = false, int limit = 30});
}

/// The three result sections of BR-CAT4.
enum CatalogSection { usedBefore, mySpecialty, others }

/// One medicine in the results.
class DrugHit {
  const DrugHit({
    required this.name,
    this.catalogId,
    this.nameAr,
    this.activeIngredient,
    this.route,
    this.manufacturer,
    this.strengthHint,
    this.formHint,
    this.groupId,
    this.custom = false,
  });

  /// The catalog row (`drug:123`), a custom item (`custom:…`), or null for a
  /// name only known from the doctor's history.
  final String? catalogId;

  /// The trade name as published ("PANADOL 500 MG 24 TABS.").
  final String name;

  /// The trade name in Arabic letters («بنادول»), when known.
  final String? nameAr;
  final String? activeIngredient;
  final String? route;
  final String? manufacturer;

  /// "500 mg", read from the trade name.
  final String? strengthHint;

  /// One of the editor's forms (`tablet`, `syrup` …), from the route.
  final String? formHint;
  final String? groupId;

  /// An admin's custom item (BR-CAT9).
  final bool custom;
}

/// One lab test or radiology procedure in the results.
class TestHit {
  const TestHit({
    required this.name,
    required this.category,
    this.code,
    this.nameAr,
    this.aliases = const [],
    this.modality,
    this.region,
    this.custom = false,
  });

  /// The LOINC code, or null for a name only known from history.
  final String? code;

  /// The name as published by LOINC (BR-CAT10), or the custom item's name.
  final String name;

  /// Our Arabic name («صورة دم كاملة»), when there is one.
  final String? nameAr;

  /// Short names (CBC, HbA1c …).
  final List<String> aliases;

  /// `lab` or `radiology`.
  final String category;

  /// Radiology only.
  final String? modality;
  final String? region;
  final bool custom;
}

/// Search results in the three BR-CAT4 sections.
class CatalogHits<T> {
  const CatalogHits({
    this.usedBefore = const [],
    this.mySpecialty = const [],
    this.others = const [],
    this.catalogReady = false,
  });

  final List<T> usedBefore;
  final List<T> mySpecialty;
  final List<T> others;

  /// False while the catalog is still downloading (D0): only the history is
  /// searched, and the editor says so.
  final bool catalogReady;

  bool get isEmpty => usedBefore.isEmpty && mySpecialty.isEmpty && others.isEmpty;

  List<T> section(CatalogSection section) => switch (section) {
        CatalogSection.usedBefore => usedBefore,
        CatalogSection.mySpecialty => mySpecialty,
        CatalogSection.others => others,
      };
}
