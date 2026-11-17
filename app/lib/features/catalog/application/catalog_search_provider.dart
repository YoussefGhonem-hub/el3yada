import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prescriptions/application/prescriptions_providers.dart';
import '../data/history_catalog_search.dart';
import '../domain/catalog_search.dart';

/// The search D13 and D14 use (spec 6.9). Until the local catalog (D0) is on
/// the device this is the doctor's history only; the catalog feature
/// replaces the body with the local-database search, which keeps the same
/// [CatalogSearch] contract (BR-CAT4 sections, BR-CAT7 filling).
final catalogSearchProvider = Provider<CatalogSearch>(
  (ref) => HistoryOnlyCatalogSearch(() => ref.read(itemHistoryProvider.future)),
);
