/// The local catalog database (spec section 9.5): version, table and column
/// names, and the statements that create it. The builder creates the file
/// with [CatalogSchema.createStatements]; the app opens it read-only and
/// refuses a file whose `meta.schema_version` is not [catalogSchemaVersion].
library;

/// Bump when a table or column changes in a way the app must know about.
const int catalogSchemaVersion = 1;

/// `meta`: one row describing the file.
abstract final class MetaTable {
  static const name = 'meta';
  static const schemaVersion = 'schema_version';
  static const catalogVersion = 'catalog_version';
  static const builtAt = 'built_at';
  static const drugSourceDate = 'drug_source_date';
  static const loincRelease = 'loinc_release';
}

/// `drug_groups`: the ~60 clean medicine groups (A.3.6).
abstract final class DrugGroupsTable {
  static const name = 'drug_groups';
  static const id = 'id';
  static const nameEn = 'name_en';
  static const nameAr = 'name_ar';

  /// The group of medicines whose class is not mapped (BR-CAT5).
  static const otherId = 'other';
}

/// `drugs`: one row per product in the Egyptian drug dataset.
abstract final class DrugsTable {
  static const name = 'drugs';
  static const id = 'id';
  static const tradeNameEn = 'trade_name_en';

  /// Arabic transliteration from the dataset. A search alias only; never
  /// shown as the official name (A.3.2).
  static const tradeNameAr = 'trade_name_ar';
  static const activeIngredient = 'active_ingredient';
  static const manufacturer = 'manufacturer';
  static const groupId = 'group_id';

  /// The dataset's route as published, e.g. `ORAL.SOLID` (specialty
  /// profiles of type `route` match this value).
  static const route = 'route';

  /// Added to the 9.5 schema: the suggested form, e.g. "Tablet" (A.3.5).
  static const form = 'form';
  static const strengthHint = 'strength_hint';

  /// Stored, never shown in v1 (BR-CAT13).
  static const priceEgp = 'price_egp';

  /// Added to the 9.5 schema: see [DrugStatus].
  static const status = 'status';
}

/// Values of `drugs.status`, read from the marker at the end of the trade
/// name in the dataset. The marker itself is removed from the name.
abstract final class DrugStatus {
  /// No marker.
  static const available = 0;

  /// "(N/A)": registered but not available on the market.
  static const notAvailable = 1;

  /// "(N/A YET)": registered, not on the market yet.
  static const notAvailableYet = 2;
}

/// `ingredients` and `drug_ingredients` (A.3.3): each active ingredient once,
/// and which products contain it.
abstract final class IngredientsTable {
  static const name = 'ingredients';
  static const id = 'id';

  /// As written in the dataset, e.g. "PARACETAMOL(ACETAMINOPHEN)".
  static const nameColumn = 'name';
}

abstract final class DrugIngredientsTable {
  static const name = 'drug_ingredients';
  static const ingredientId = 'ingredient_id';
  static const drugId = 'drug_id';
}

/// `lab_tests`: LOINC laboratory orders (A.4).
abstract final class LabTestsTable {
  static const name = 'lab_tests';

  /// The LOINC number without its dash (see [loincToId]); also the FTS rowid.
  static const id = 'id';
  static const loincCode = 'loinc_code';

  /// LOINC LONG_COMMON_NAME, exactly as published (BR-CAT10).
  static const nameEn = 'name_en';

  /// LOINC SHORTNAME.
  static const shortName = 'short_name';

  /// Our Arabic name from aliases.csv, else the LOINC Arabic (Jordan)
  /// variant.
  static const nameAr = 'name_ar';

  /// Our English short names from aliases.csv, joined with "; ".
  static const aliases = 'aliases';
  static const loincClass = 'loinc_class';

  /// Added: see [CatalogPriority].
  static const priority = 'priority';

  /// Added: LOINC COMMON_ORDER_RANK (1 = most ordered in US labs), or null.
  static const orderRank = 'order_rank';
}

/// `radiology`: LOINC/RSNA Radiology Playbook procedures (A.5).
abstract final class RadiologyTable {
  static const name = 'radiology';

  /// The LOINC number without its dash (see [loincToId]); also the FTS rowid.
  static const id = 'id';
  static const loincCode = 'loinc_code';

  /// LOINC LONG_COMMON_NAME, exactly as published (BR-CAT10).
  static const nameEn = 'name_en';

  /// Our Arabic name from aliases.csv.
  static const nameAr = 'name_ar';

  /// Playbook "Rad.Modality.Modality Type", e.g. XR, CT, MR, US, MG, NM, RF,
  /// PT, PT+CT. Null when the Playbook leaves it unspecified.
  static const modality = 'modality';

  /// Playbook "Rad.Anatomic Location.Region Imaged", e.g. Chest, Abdomen.
  /// Several values are joined with ";". Null when unspecified.
  static const region = 'region';
  static const aliases = 'aliases';

  /// Added: Playbook "Rad.Modality.Modality Subtype", e.g. Doppler, Angio.
  static const modalitySubtype = 'modality_subtype';

  /// Added: Playbook "Rad.Anatomic Location.Imaging Focus", e.g.
  /// "Lumbar spine", "Knee". Several values are joined with ";".
  static const focus = 'focus';

  /// Added: see [CatalogPriority].
  static const priority = 'priority';
}

/// `modalities`: Arabic and English names of the radiology modalities, for
/// filter chips (A.5.3).
abstract final class ModalitiesTable {
  static const name = 'modalities';
  static const code = 'code';
  static const nameEn = 'name_en';
  static const nameAr = 'name_ar';
}

/// Values of `lab_tests.priority` and `radiology.priority`.
abstract final class CatalogPriority {
  /// Not marked.
  static const none = 0;

  /// Common in US labs: in the LOINC Universal Lab Orders Value Set or with
  /// a COMMON_ORDER_RANK (A.4.3). Radiology terms never get this value.
  static const common = 1;

  /// Marked `priority` in aliases.csv: common in Egypt (A.4.4).
  static const egypt = 2;
}

/// Full-text tables. They are contentless (`content=''`): they hold only the
/// index, and the rowid points at the row of the base table.
abstract final class FtsTables {
  /// Columns: name (trade names, English and Arabic), ingredient.
  static const drugs = 'fts_drugs';

  /// Columns: name (LOINC name and short name), alias (our aliases and
  /// Arabic names), related (LOINC RELATEDNAMES2).
  static const labs = 'fts_labs';

  /// Columns: name (LOINC name and short name), alias (our aliases, Arabic
  /// names, modality and region names), related (LOINC RELATEDNAMES2).
  static const radiology = 'fts_radiology';
}

/// The statements that create an empty catalog database, in order.
abstract final class CatalogSchema {
  /// FTS5 options shared by the three full-text tables.
  ///
  /// * Text is normalized by `normalizeForSearch` before it is indexed, so
  ///   the tokenizer only has to split on spaces; `/` and `.` are token
  ///   characters so that "250/5" and "0.1" stay one word.
  /// * `content=''`: the index only; rows are read from the base tables.
  /// * `detail=full` (the default). `detail=column` would save 1.3 MB of
  ///   download, but on a contentless table FTS5 then reports no matches to
  ///   auxiliary functions, so `bm25()` is always 0 and results come back
  ///   unranked.
  /// * No `prefix=` index. Prefix queries ("ator"*) work without one, and on
  ///   the real catalog a `prefix='2 3'` index made the gzip file about 45%
  ///   larger without making searches faster: queries of two letters or more
  ///   took under 15 ms either way on a desktop, and one-letter queries are
  ///   slow because of ranking, not lookup. To add one, append
  ///   `, prefix='2 3'` here and bump [catalogSchemaVersion].
  static const ftsOptions =
      "content='', "
      "tokenize=\"unicode61 remove_diacritics 0 tokenchars './'\"";

  static const List<String> createStatements = [
    'CREATE TABLE ${MetaTable.name} ('
        '${MetaTable.schemaVersion} INTEGER NOT NULL, '
        '${MetaTable.catalogVersion} INTEGER NOT NULL, '
        '${MetaTable.builtAt} TEXT NOT NULL, '
        '${MetaTable.drugSourceDate} TEXT NOT NULL, '
        '${MetaTable.loincRelease} TEXT NOT NULL)',
    'CREATE TABLE ${DrugGroupsTable.name} ('
        '${DrugGroupsTable.id} TEXT PRIMARY KEY, '
        '${DrugGroupsTable.nameEn} TEXT NOT NULL, '
        '${DrugGroupsTable.nameAr} TEXT NOT NULL) WITHOUT ROWID',
    'CREATE TABLE ${DrugsTable.name} ('
        '${DrugsTable.id} INTEGER PRIMARY KEY, '
        '${DrugsTable.tradeNameEn} TEXT NOT NULL, '
        '${DrugsTable.tradeNameAr} TEXT, '
        '${DrugsTable.activeIngredient} TEXT, '
        '${DrugsTable.manufacturer} TEXT, '
        '${DrugsTable.groupId} TEXT NOT NULL, '
        '${DrugsTable.route} TEXT NOT NULL, '
        '${DrugsTable.form} TEXT, '
        '${DrugsTable.strengthHint} TEXT, '
        '${DrugsTable.priceEgp} REAL, '
        '${DrugsTable.status} INTEGER NOT NULL)',
    'CREATE TABLE ${IngredientsTable.name} ('
        '${IngredientsTable.id} INTEGER PRIMARY KEY, '
        '${IngredientsTable.nameColumn} TEXT NOT NULL)',
    'CREATE TABLE ${DrugIngredientsTable.name} ('
        '${DrugIngredientsTable.ingredientId} INTEGER NOT NULL, '
        '${DrugIngredientsTable.drugId} INTEGER NOT NULL, '
        'PRIMARY KEY (${DrugIngredientsTable.ingredientId}, '
        '${DrugIngredientsTable.drugId})) WITHOUT ROWID',
    'CREATE TABLE ${LabTestsTable.name} ('
        '${LabTestsTable.id} INTEGER PRIMARY KEY, '
        '${LabTestsTable.loincCode} TEXT NOT NULL, '
        '${LabTestsTable.nameEn} TEXT NOT NULL, '
        '${LabTestsTable.shortName} TEXT, '
        '${LabTestsTable.nameAr} TEXT, '
        '${LabTestsTable.aliases} TEXT, '
        '${LabTestsTable.loincClass} TEXT, '
        '${LabTestsTable.priority} INTEGER NOT NULL, '
        '${LabTestsTable.orderRank} INTEGER)',
    'CREATE TABLE ${RadiologyTable.name} ('
        '${RadiologyTable.id} INTEGER PRIMARY KEY, '
        '${RadiologyTable.loincCode} TEXT NOT NULL, '
        '${RadiologyTable.nameEn} TEXT NOT NULL, '
        '${RadiologyTable.nameAr} TEXT, '
        '${RadiologyTable.modality} TEXT, '
        '${RadiologyTable.region} TEXT, '
        '${RadiologyTable.aliases} TEXT, '
        '${RadiologyTable.modalitySubtype} TEXT, '
        '${RadiologyTable.focus} TEXT, '
        '${RadiologyTable.priority} INTEGER NOT NULL)',
    'CREATE TABLE ${ModalitiesTable.name} ('
        '${ModalitiesTable.code} TEXT PRIMARY KEY, '
        '${ModalitiesTable.nameEn} TEXT NOT NULL, '
        '${ModalitiesTable.nameAr} TEXT NOT NULL) WITHOUT ROWID',
    'CREATE VIRTUAL TABLE ${FtsTables.drugs} USING fts5('
        'name, ingredient, $ftsOptions)',
    'CREATE VIRTUAL TABLE ${FtsTables.labs} USING fts5('
        'name, alias, related, $ftsOptions)',
    'CREATE VIRTUAL TABLE ${FtsTables.radiology} USING fts5('
        'name, alias, related, $ftsOptions)',
  ];
}

/// The integer key of a LOINC code: its digits without the dash
/// ("58410-2" → 584102). LOINC check digits are always one digit, so the key
/// is unique and [loincFromId] reverses it.
int loincToId(String loincCode) {
  final match = _loincPattern.firstMatch(loincCode.trim());
  if (match == null) {
    throw FormatException('Not a LOINC code', loincCode);
  }
  return int.parse(match.group(1)!) * 10 + int.parse(match.group(2)!);
}

/// The LOINC code of an integer key made by [loincToId].
String loincFromId(int id) => '${id ~/ 10}-${id % 10}';

final _loincPattern = RegExp(r'^(\d{1,7})-(\d)$');
