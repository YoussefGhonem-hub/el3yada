import 'dart:io';

import 'package:el3yada/features/catalog/data/catalog_db.dart';
import 'package:el3yada/features/catalog/data/sample_catalog.dart';
import 'package:el3yada/features/catalog/domain/catalog_search.dart';

/// A tiny catalog in the real schema (catalog_core), written to a new
/// temporary folder that is deleted after the test file. Returns its path.
String writeTestCatalog({SampleCatalog catalog = const SampleCatalog(), String name = 'catalog.sqlite'}) {
  final dir = Directory.systemTemp.createTempSync('el3yada-catalog-test');
  _temporary.add(dir);
  final path = '${dir.path}${Platform.pathSeparator}$name';
  catalog.writeTo(path);
  return path;
}

/// [writeTestCatalog], opened in the calling isolate.
Future<DirectCatalogDb> openTestCatalog({SampleCatalog catalog = const SampleCatalog()}) async {
  final db = DirectCatalogDb();
  await db.open(writeTestCatalog(catalog: catalog));
  return db;
}

final _temporary = <Directory>[];

/// Deletes what [writeTestCatalog] made (call from `tearDownAll`).
void deleteTestCatalogs() {
  for (final dir in _temporary) {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still open on Windows: the system cleans temp folders.
    }
  }
  _temporary.clear();
}

/// "Used before" with fixed items, like `HistoryOnlyCatalogSearch`: every
/// item whose name contains what was typed (case-insensitive).
class FixedHistory implements CatalogSearch {
  FixedHistory({this.drugItems = const [], this.testItems = const [], this.matchAll = false});

  final List<DrugHit> drugItems;
  final List<TestHit> testItems;

  /// Every item for any query.
  final bool matchAll;
  int calls = 0;

  @override
  Future<CatalogHits<DrugHit>> drugs(String query, {bool mySpecialtyOnly = false, int limit = 30}) async {
    calls++;
    final typed = query.trim().toLowerCase();
    return CatalogHits(
      usedBefore: [
        for (final hit in drugItems)
          if (matchAll || hit.name.toLowerCase().contains(typed)) hit,
      ],
    );
  }

  @override
  Future<CatalogHits<TestHit>> tests(
    String query, {
    String? category,
    bool mySpecialtyOnly = false,
    int limit = 30,
  }) async {
    calls++;
    final typed = query.trim().toLowerCase();
    return CatalogHits(
      usedBefore: [
        for (final hit in testItems)
          if ((category == null || hit.category == category) && (matchAll || hit.name.toLowerCase().contains(typed)))
            hit,
      ],
    );
  }
}
