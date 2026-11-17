import 'package:catalog_core/catalog_core.dart';

import 'csv.dart';
import 'mappings.dart';

/// Columns of data/egyptian-drugs.csv (spec A.3.2).
const drugColumns = [
  'commercial_name_en',
  'commercial_name_ar',
  'scientific_name',
  'manufacturer',
  'drug_class',
  'route',
  'price_egp',
];

/// The availability marker the dataset writes in brackets in the trade
/// name, e.g. "ABILIFY 10 MG 10 DISCMELT ORALLY DIS.TABS. (N/A)".
enum DrugMarker {
  none,
  notAvailable,
  notAvailableYet,
  cancelled,
  illegalImport,
  withdrawn;

  /// Cancelled registrations, illegal imports and withdrawn products are left
  /// out of the catalog unless the build is told to keep them.
  bool get withdrawnFromMarket => this == cancelled || this == illegalImport || this == withdrawn;

  int get status => switch (this) {
    notAvailable => DrugStatus.notAvailable,
    notAvailableYet => DrugStatus.notAvailableYet,
    _ => DrugStatus.available,
  };
}

final _markerPattern = RegExp(
  r'\s*\((N/A YET|N/A|CANCELLED|ILLEGAL IMPORT|WITHDRAWAL|WITHDRAWN)\)',
  caseSensitive: false,
);

/// Removes the availability markers from [tradeName] and returns the clean
/// name with the strongest marker found.
(String, DrugMarker) stripMarkers(String tradeName) {
  var marker = DrugMarker.none;
  final clean = tradeName.replaceAllMapped(_markerPattern, (match) {
    final found = switch (match.group(1)!.toUpperCase()) {
      'N/A YET' => DrugMarker.notAvailableYet,
      'N/A' => DrugMarker.notAvailable,
      'CANCELLED' => DrugMarker.cancelled,
      'ILLEGAL IMPORT' => DrugMarker.illegalImport,
      _ => DrugMarker.withdrawn,
    };
    if (found.index > marker.index) marker = found;
    return ' ';
  });
  return (clean.replaceAll(RegExp(r'\s+'), ' ').trim(), marker);
}

/// Splits an active-ingredient string on top-level "+" signs
/// ("A+B(C+D)" → ["A", "B(C+D)"]), trimming each part (A.3.3).
List<String> splitIngredients(String scientificName) {
  final parts = <String>[];
  final current = StringBuffer();
  var depth = 0;
  for (final rune in scientificName.runes) {
    final char = String.fromCharCode(rune);
    if (char == '(') depth++;
    if (char == ')' && depth > 0) depth--;
    if (char == '+' && depth == 0) {
      parts.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  parts.add(current.toString());
  return [
    for (final part in parts)
      if (part.trim().isNotEmpty) part.trim().replaceAll(RegExp(r'\s+'), ' '),
  ];
}

/// Suggests a form from the words of a trade name, falling back to the
/// route (spec A.3.5).
class FormSuggester {
  FormSuggester(List<FormToken> tokens, this._routeToForm) {
    for (final token in tokens) {
      (_byLastWord[token.words.last] ??= []).add(token);
    }
    // Longer phrases first, then route-specific rows before general ones.
    for (final list in _byLastWord.values) {
      list.sort((a, b) {
        final byLength = b.words.length.compareTo(a.words.length);
        if (byLength != 0) return byLength;
        return (b.route == null ? 0 : 1).compareTo(a.route == null ? 0 : 1);
      });
    }
  }

  final Map<String, List<FormToken>> _byLastWord = {};
  final Map<String, String> _routeToForm;

  /// The form for a product, or null. The last form word in the name wins,
  /// because the pack description comes at the end ("... 20 F.C.TABS.").
  String? suggest(String tradeName, String route) {
    final words = RegExp(r'[A-Z]+').allMatches(tradeName.toUpperCase()).map((m) => m.group(0)!).toList();
    for (var end = words.length - 1; end >= 0; end--) {
      final candidates = _byLastWord[words[end]];
      if (candidates == null) continue;
      for (final token in candidates) {
        if (token.route != null && token.route != route) continue;
        final start = end - token.words.length + 1;
        if (start < 0) continue;
        var matches = true;
        for (var i = 0; i < token.words.length; i++) {
          if (words[start + i] != token.words[i]) {
            matches = false;
            break;
          }
        }
        if (matches) return token.form;
      }
    }
    final fallback = _routeToForm[route];
    return fallback == null || fallback.isEmpty ? null : fallback;
  }
}

/// One product of the drug dataset, cleaned.
class Drug {
  Drug({
    required this.tradeNameEn,
    required this.tradeNameAr,
    required this.activeIngredient,
    required this.manufacturer,
    required this.rawClass,
    required this.route,
    required this.priceEgp,
    required this.marker,
    required this.ingredients,
    required this.form,
    required this.strength,
  });

  final String tradeNameEn;
  final String tradeNameAr;
  final String activeIngredient;
  final String manufacturer;
  final String rawClass;
  final String route;
  final double? priceEgp;
  final DrugMarker marker;
  final List<String> ingredients;
  final String? form;
  final String? strength;

  /// Set by [assignGroups].
  late String groupId;

  /// How [groupId] was chosen.
  late GroupSource groupSource;
}

enum GroupSource {
  /// From class-to-group.csv.
  mapping,

  /// The class is mapped to "other" or not mapped at all, so the group was
  /// taken from other products with the same active ingredients.
  ingredientFallback,

  /// The class is mapped to "other".
  other,

  /// The class is not in class-to-group.csv.
  unmapped,
}

/// The result of reading the drug CSV.
class DrugSet {
  DrugSet(this.drugs, {required this.rowsRead, required this.excluded});

  final List<Drug> drugs;
  final int rowsRead;

  /// Rows left out, by marker.
  final Map<DrugMarker, int> excluded;
}

/// Reads the drug dataset at [path]. Products marked cancelled, illegal
/// import or withdrawn are left out unless [keepWithdrawn] is true.
DrugSet readDrugs(String path, Mappings mappings, {bool keepWithdrawn = false}) {
  final table = CsvTable.read(path)..requireColumns(drugColumns);
  final suggester = FormSuggester(mappings.formTokens, mappings.routeToForm);
  int col(String name) => table.column(name);
  final nameEn = col('commercial_name_en');
  final nameAr = col('commercial_name_ar');
  final scientific = col('scientific_name');
  final manufacturer = col('manufacturer');
  final drugClass = col('drug_class');
  final routeCol = col('route');
  final price = col('price_egp');

  final drugs = <Drug>[];
  final excluded = <DrugMarker, int>{};
  for (final row in table.rows) {
    final rawName = CsvTable.cell(row, nameEn).trim();
    if (rawName.isEmpty) continue;
    final (name, marker) = stripMarkers(rawName);
    if (marker.withdrawnFromMarket && !keepWithdrawn) {
      excluded[marker] = (excluded[marker] ?? 0) + 1;
      continue;
    }
    final route = CsvTable.cell(row, routeCol).trim();
    final ingredientText = CsvTable.cell(row, scientific).trim();
    drugs.add(
      Drug(
        tradeNameEn: name,
        tradeNameAr: stripMarkers(CsvTable.cell(row, nameAr).trim()).$1,
        activeIngredient: ingredientText,
        manufacturer: CsvTable.cell(row, manufacturer).trim(),
        rawClass: CsvTable.cell(row, drugClass).trim(),
        route: route.isEmpty ? 'UNKNOWN' : route,
        priceEgp: double.tryParse(CsvTable.cell(row, price).trim()),
        marker: marker,
        ingredients: splitIngredients(ingredientText),
        form: suggester.suggest(name, route),
        strength: parseStrength(name),
      ),
    );
  }
  return DrugSet(drugs, rowsRead: table.rows.length, excluded: excluded);
}

/// Gives every drug a group from class-to-group.csv (BR-CAT5).
///
/// When a product's class is mapped to "other" or not mapped at all (for
/// example the junk classes "." and ""), the group is taken from the other
/// products with exactly the same active ingredients: first those with the
/// same route, then any route. At least two of them must be mapped to a real
/// group, and at least two thirds of those must agree. Products that still
/// have no group stay in "other".
void assignGroups(List<Drug> drugs, Mappings mappings) {
  final byIngredientAndRoute = <String, Map<String, int>>{};
  final byIngredient = <String, Map<String, int>>{};
  void vote(Map<String, Map<String, int>> votes, String key, String group) {
    final counts = votes[key] ??= {};
    counts[group] = (counts[group] ?? 0) + 1;
  }

  for (final drug in drugs) {
    final group = mappings.groupFor(drug.rawClass, drug.route);
    if (group == null || group == DrugGroupsTable.otherId) {
      drug.groupId = DrugGroupsTable.otherId;
      drug.groupSource = group == null ? GroupSource.unmapped : GroupSource.other;
      continue;
    }
    drug.groupId = group;
    drug.groupSource = GroupSource.mapping;
    final key = normalizeForSearch(drug.activeIngredient);
    if (key.isEmpty) continue;
    vote(byIngredientAndRoute, '$key|${drug.route}', group);
    vote(byIngredient, key, group);
  }

  String? decide(Map<String, int>? counts) {
    if (counts == null) return null;
    final total = counts.values.fold(0, (a, b) => a + b);
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return total >= 2 && best.value * 3 >= total * 2 ? best.key : null;
  }

  for (final drug in drugs) {
    if (drug.groupSource == GroupSource.mapping) continue;
    final key = normalizeForSearch(drug.activeIngredient);
    if (key.isEmpty) continue;
    final group = decide(byIngredientAndRoute['$key|${drug.route}']) ?? decide(byIngredient[key]);
    if (group != null) {
      drug.groupId = group;
      drug.groupSource = GroupSource.ingredientFallback;
    }
  }
}
