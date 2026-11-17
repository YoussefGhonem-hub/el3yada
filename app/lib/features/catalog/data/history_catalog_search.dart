import '../../../core/search/search_normalizer.dart';
import '../../prescriptions/domain/prescription_models.dart';
import '../domain/catalog_search.dart';

/// The search while the catalog isn't on the device yet (D0): "until it
/// finishes, the editors suggest only the doctor's own history and accept
/// free text". Every hit is in [CatalogHits.usedBefore], most used first, and
/// [CatalogHits.catalogReady] is false.
class HistoryOnlyCatalogSearch implements CatalogSearch {
  HistoryOnlyCatalogSearch(this._history);

  /// `GET /api/prescriptions/itemHistory`, already sorted by the API.
  final Future<List<ItemHistoryEntry>> Function() _history;

  @override
  Future<CatalogHits<DrugHit>> drugs(String query, {bool mySpecialtyOnly = false, int limit = 30}) async {
    final rows = await _matching(query, (entry) => entry.isDrug);
    return CatalogHits(
      usedBefore: [
        for (final entry in rows.take(limit))
          DrugHit(
            name: entry.name,
            catalogId: entry.catalogId,
            strengthHint: entry.strength.isEmpty ? null : entry.strength,
            formHint: entry.form.isEmpty ? null : entry.form,
          ),
      ],
    );
  }

  @override
  Future<CatalogHits<TestHit>> tests(String query, {String? category, bool mySpecialtyOnly = false, int limit = 30}) async {
    final rows = await _matching(
      query,
      (entry) => !entry.isDrug && (category == null || entry.kind == category),
    );
    return CatalogHits(
      usedBefore: [
        for (final entry in rows.take(limit)) TestHit(name: entry.name, category: entry.kind, code: entry.catalogId),
      ],
    );
  }

  Future<List<ItemHistoryEntry>> _matching(String query, bool Function(ItemHistoryEntry entry) kind) async {
    List<ItemHistoryEntry> history;
    try {
      history = await _history();
    } on Object {
      // Offline or refused: the editor still takes typed names (BR-CAT8).
      return const [];
    }
    final words = SearchNormalizer.normalize(query).split(' ').where((word) => word.isNotEmpty).toList();
    return [
      for (final entry in history)
        if (kind(entry) && matchesWordStarts(entry.name, words)) entry,
    ];
  }
}

/// BR-CAT6: every typed word starts some word of [text] (after A.6
/// normalization). No words matches everything.
bool matchesWordStarts(String text, List<String> words) {
  if (words.isEmpty) return true;
  final target = SearchNormalizer.normalize(text).split(' ');
  return words.every((word) => target.any((part) => part.startsWith(word)));
}
