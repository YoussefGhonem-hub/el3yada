import 'package:catalog_core/catalog_core.dart';

import 'drugs.dart';
import 'loinc.dart';
import 'mappings.dart';

/// A lab test row ready for the database (A.4).
class LabRow {
  LabRow({
    required this.term,
    required this.nameAr,
    required this.aliases,
    required this.priority,
    required this.ftsName,
    required this.ftsAlias,
    required this.ftsRelated,
  });

  final LoincTerm term;
  final String? nameAr;

  /// Our English aliases, for display.
  final List<String> aliases;
  final int priority;
  final String ftsName;
  final String ftsAlias;
  final String ftsRelated;

  int get id => loincToId(term.code);
}

/// A radiology procedure row ready for the database (A.5).
class RadiologyRow {
  RadiologyRow({
    required this.term,
    required this.entry,
    required this.nameAr,
    required this.aliases,
    required this.priority,
    required this.ftsName,
    required this.ftsAlias,
    required this.ftsRelated,
  });

  final LoincTerm term;
  final PlaybookEntry entry;
  final String? nameAr;
  final List<String> aliases;
  final int priority;
  final String ftsName;
  final String ftsAlias;
  final String ftsRelated;

  int get id => loincToId(term.code);
}

/// Everything that goes into one catalog file.
class CatalogContent {
  CatalogContent({
    required this.drugs,
    required this.groups,
    required this.labs,
    required this.radiology,
    required this.modalities,
  });

  /// Sorted by trade name; a drug's id is its position + 1.
  final List<Drug> drugs;
  final List<DrugGroup> groups;
  final List<LabRow> labs;
  final List<RadiologyRow> radiology;
  final List<RadiologyTerm> modalities;
}

/// Problems that stop the build: mapping rows that point at data that does
/// not exist.
class MappingDataErrors implements Exception {
  MappingDataErrors(this.problems);
  final List<String> problems;
  @override
  String toString() => 'The mapping files do not match the source data:\n  ${problems.join('\n  ')}';
}

/// Builds the lab and radiology rows from LOINC and our aliases, and checks
/// that every alias and specialty profile row points at a real item.
CatalogContent assembleCatalog({
  required List<Drug> drugs,
  required Mappings mappings,
  required Map<String, LoincTerm> loinc,
  required Set<String> universalLabOrders,
  required Map<String, VariantNames> arabic,
  required Map<String, PlaybookEntry> playbook,
  void Function(String warning)? warn,
}) {
  final problems = <String>[];

  // Labs: A.4.3 filter.
  final labTerms = loinc.values.where((t) => t.isOrderableLab).toList()
    ..sort((a, b) => loincToId(a.code).compareTo(loincToId(b.code)));
  final labCodes = {for (final t in labTerms) t.code};

  // Radiology: Playbook procedures that are active in the main table (A.5.3).
  final radiologyTerms = <LoincTerm>[];
  for (final code in playbook.keys) {
    final term = loinc[code];
    if (term != null && term.isActive) radiologyTerms.add(term);
  }
  radiologyTerms.sort((a, b) => loincToId(a.code).compareTo(loincToId(b.code)));
  final radiologyCodes = {for (final t in radiologyTerms) t.code};

  // Aliases grouped by code, in file order.
  final labAliases = <String, List<Alias>>{};
  final radiologyAliases = <String, List<Alias>>{};
  for (final alias in mappings.aliases) {
    final known = alias.type == 'lab' ? labCodes : radiologyCodes;
    if (!known.contains(alias.code)) {
      final term = loinc[alias.code];
      final why = term == null
          ? 'not in LOINC'
          : alias.type == 'lab'
              ? 'not an active orderable lab term (CLASSTYPE ${term.classType}, ${term.status}, ${term.orderObs})'
              : 'not an active Radiology Playbook procedure (${term.status})';
      problems.add('aliases.csv: ${alias.type} ${alias.code} "${alias.aliasEn}" is $why');
      continue;
    }
    ((alias.type == 'lab' ? labAliases : radiologyAliases)[alias.code] ??= []).add(alias);
  }

  // Search words for Playbook attributes.
  final termWords = <String, RadiologyTerm>{
    for (final t in mappings.radiologyTerms) '${t.kind}|${t.value}': t,
  };

  final labs = [
    for (final term in labTerms)
      _labRow(term, labAliases[term.code] ?? const [], arabic[term.code], universalLabOrders),
  ];

  final radiology = <RadiologyRow>[];
  for (final term in radiologyTerms) {
    final entry = playbook[term.code]!;
    final aliases = radiologyAliases[term.code] ?? const <Alias>[];
    final attributeTerms = [
      for (final m in entry.modalities) termWords['modality|$m'],
      for (final s in entry.subtypes) termWords['subtype|$s'],
      for (final r in entry.regions) termWords['region|$r'],
      for (final f in entry.foci) termWords['focus|$f'],
      for (final m in entry.modalities)
        for (final f in entry.foci) termWords['modality_focus|$m/$f'],
    ].whereType<RadiologyTerm>();
    final nameAr = _firstArabic(aliases);
    final ftsName = normalizeAndDedupe([term.longName, term.shortName]);
    final ftsAlias = _without(
      withArabicSkeletons(normalizeAndDedupe([
        for (final a in aliases) ...[a.aliasEn, a.nameAr],
        for (final t in attributeTerms) ...[t.nameEn, t.nameAr, t.searchTerms],
        arabic[term.code]?.displayName,
        ...?arabic[term.code]?.relatedNames,
      ])),
      ftsName,
    );
    radiology.add(RadiologyRow(
      term: term,
      entry: entry,
      nameAr: nameAr,
      aliases: _englishAliases(aliases),
      priority: aliases.any((a) => a.priority) ? CatalogPriority.egypt : CatalogPriority.none,
      ftsName: ftsName,
      ftsAlias: ftsAlias,
      ftsRelated: _relatedWords(term, '$ftsName $ftsAlias'),
    ));
  }

  // Specialty profiles must point at real items.
  final drugRoutes = {for (final d in drugs) d.route};
  final regionsAndFoci = {
    for (final e in playbook.values) ...[...e.regions, ...e.foci],
  };
  final modalities = {for (final e in playbook.values) ...e.modalities};
  for (final item in mappings.profiles) {
    final ok = switch (item.itemType) {
      'labCode' => labCodes.contains(item.value),
      'radiologyCode' => radiologyCodes.contains(item.value),
      'radiologyRegion' => regionsAndFoci.contains(item.value),
      'radiologyModality' => modalities.contains(item.value),
      'route' => drugRoutes.contains(item.value),
      _ => true, // drugGroup is checked when the mappings are loaded
    };
    if (!ok) {
      problems.add('specialty-profiles.csv: ${item.specialty} ${item.itemType} "${item.value}" '
          'is not in the catalog');
    }
  }

  // radiology-terms.csv rows that match nothing are harmless but suspicious.
  final subtypes = {for (final e in playbook.values) ...e.subtypes};
  final regions = {for (final e in playbook.values) ...e.regions};
  final foci = {for (final e in playbook.values) ...e.foci};
  final pairs = {
    for (final e in playbook.values)
      for (final m in e.modalities) ...[for (final f in e.foci) '$m/$f'],
  };
  for (final t in mappings.radiologyTerms) {
    final present = switch (t.kind) {
      'modality' => modalities.contains(t.value),
      'subtype' => subtypes.contains(t.value),
      'region' => regions.contains(t.value),
      'modality_focus' => pairs.contains(t.value),
      _ => foci.contains(t.value),
    };
    if (!present) warn?.call('radiology-terms.csv: ${t.kind} "${t.value}" does not occur in the Playbook');
  }

  if (problems.isNotEmpty) throw MappingDataErrors(problems);

  final sortedDrugs = [...drugs]..sort((a, b) {
      final byName = a.tradeNameEn.compareTo(b.tradeNameEn);
      return byName != 0 ? byName : a.activeIngredient.compareTo(b.activeIngredient);
    });
  return CatalogContent(
    drugs: sortedDrugs,
    groups: mappings.groups,
    labs: labs,
    radiology: radiology,
    modalities: [for (final t in mappings.radiologyTerms) if (t.kind == 'modality') t],
  );
}

LabRow _labRow(LoincTerm term, List<Alias> aliases, VariantNames? arabic, Set<String> universalLabOrders) {
  final common = universalLabOrders.contains(term.code) || term.commonOrderRank > 0;
  final ftsName = normalizeAndDedupe([term.longName, term.shortName]);
  final ftsAlias = _without(
    withArabicSkeletons(normalizeAndDedupe([
      for (final a in aliases) ...[a.aliasEn, a.nameAr],
      arabic?.displayName,
      ...?arabic?.relatedNames,
    ])),
    ftsName,
  );
  return LabRow(
    term: term,
    // Our Arabic name wins over the LOINC translation (A.4.4).
    nameAr: _firstArabic(aliases) ?? (arabic?.displayName.isNotEmpty == true ? arabic!.displayName : null),
    aliases: _englishAliases(aliases),
    priority: aliases.any((a) => a.priority)
        ? CatalogPriority.egypt
        : common
            ? CatalogPriority.common
            : CatalogPriority.none,
    ftsName: ftsName,
    ftsAlias: ftsAlias,
    ftsRelated: _relatedWords(term, '$ftsName $ftsAlias'),
  );
}

/// Words of LOINC RELATEDNAMES2 that are worth indexing: not already in the
/// name or alias columns, longer than one character, and not one of the
/// LOINC axis abbreviations and category words that appear in tens of
/// thousands of terms but that nobody types when looking for a test
/// ("Point in time", "Random", "Qnt", "SerPl" ...). Measured on LOINC 2.83,
/// these took about half of the lab index.
String _relatedWords(LoincTerm term, String alreadyIndexed) {
  final taken = alreadyIndexed.split(' ').toSet();
  return normalizeAndDedupe(term.relatedNames)
      .split(' ')
      .where((w) => w.length > 1 && !taken.contains(w) && !relatedStopWords.contains(w))
      .join(' ');
}

/// See [_relatedWords]. Normalized (lower case) LOINC RELATEDNAMES2 words.
const relatedStopWords = {
  // Time, scale and property axes.
  'point', 'random', 'time', 'qnt', 'quan', 'quant', 'quantitative', 'ql', 'qual', 'qualitative', 'ord',
  'ordinal', 'nom', 'nominal', 'nar', 'narrative', 'doc', 'document', 'finding', 'findings', 'sr', 'pr',
  'prid', 'arbitrary', 'substance', 'concentration', 'mcnc', 'scnc', 'acnc', 'ccnc', 'ncnc', 'mscnc', 'mfr',
  'srto', 'mrto', 'rto', 'mcnt', 'mrat', 'srat', 'arat', 'ncnt', 'num', 'unspecified', 'of',
  // Abbreviated systems and synonyms that the long name already spells out.
  'pl', 'plsm', 'serp', 'serplas', 'serpl', 'ua', 'urn', 'wb', 'bld', 'iaa', 'elfa', 'abs', 'aby', 'antby',
  'autoantibodies', 'autoantibody', 'id', 'infectiousdisease', 'testing',
  // Category words (LOINC class names), not test names.
  'microbiology', 'chemistry', 'hematology', 'serology', 'radiology', 'imaging', 'rad', 'coreplaybook',
  'playbook', 'vws', 'vw', 'extr', 'ext', 'contra', 'contrst', 'wc', 'guid', 'cat', 'msk',
};

String? _firstArabic(List<Alias> aliases) {
  for (final a in aliases) {
    if (a.nameAr.isNotEmpty) return a.nameAr;
  }
  return null;
}

List<String> _englishAliases(List<Alias> aliases) {
  final seen = <String>{};
  return [
    for (final a in aliases)
      if (a.aliasEn.isNotEmpty && seen.add(a.aliasEn.toLowerCase())) a.aliasEn,
  ];
}

/// The words of [text] that do not already occur in [other]. A word indexed
/// in one column matches the query anyway, so repeating it in another column
/// only makes the file bigger.
String _without(String text, String other) {
  if (text.isEmpty) return text;
  final taken = other.split(' ').toSet();
  return text.split(' ').where((w) => !taken.contains(w)).join(' ');
}
