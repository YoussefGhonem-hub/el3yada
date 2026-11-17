import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prescriptions/application/prescriptions_providers.dart';
import '../data/history_catalog_search.dart';
import '../domain/catalog_search.dart';
import 'catalog_providers.dart';

/// The search D13 and D14 use (spec 6.9).
///
/// * While the local catalog (D0) is not open, and for anyone who doesn't
///   keep it (patients; assistants without `prescriptionsDraft`), this is the
///   doctor's history only, and [CatalogHits.catalogReady] is false.
/// * Once the catalog file is open, `LocalCatalogSearch` adds "Your
///   specialty" and «من تخصصات أخرى» after the history's "Used before"
///   (BR-CAT4), with the same [CatalogSearch] contract. A new catalog
///   version swaps in under it (BR-CAT12).
final catalogSearchProvider = Provider<CatalogSearch>((ref) {
  final history = HistoryOnlyCatalogSearch(() => ref.read(itemHistoryProvider.future));
  if (!ref.watch(catalogEligibleProvider)) return history;
  if (!ref.watch(catalogControllerProvider.select((state) => state.ready))) return history;
  return localCatalogSearch(ref, history);
});
