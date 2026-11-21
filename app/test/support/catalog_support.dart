import 'dart:io';

import 'package:el3yada/features/catalog/application/catalog_providers.dart';
import 'package:el3yada/features/catalog/data/catalog_db.dart';
import 'package:el3yada/features/catalog/data/catalog_files.dart';
import 'package:el3yada/features/catalog/data/fake_catalog_backend.dart';
import 'package:el3yada/features/catalog/data/sample_catalog.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:el3yada/features/catalog/domain/catalog_search.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A tiny catalog in the real schema (catalog_core), written to a new
/// temporary folder that is deleted after the test file. Returns its path.
String writeTestCatalog({
  SampleCatalog catalog = const SampleCatalog(),
  String name = 'catalog.sqlite',
}) {
  final dir = Directory.systemTemp.createTempSync('el3yada-catalog-test');
  _temporary.add(dir);
  final path = '${dir.path}${Platform.pathSeparator}$name';
  catalog.writeTo(path);
  return path;
}

/// [writeTestCatalog], opened in the calling isolate.
Future<DirectCatalogDb> openTestCatalog({
  SampleCatalog catalog = const SampleCatalog(),
}) async {
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
  FixedHistory({
    this.drugItems = const [],
    this.testItems = const [],
    this.matchAll = false,
  });

  final List<DrugHit> drugItems;
  final List<TestHit> testItems;

  /// Every item for any query.
  final bool matchAll;
  int calls = 0;

  @override
  Future<CatalogHits<DrugHit>> drugs(
    String query, {
    bool mySpecialtyOnly = false,
    int limit = 30,
  }) async {
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
          if ((category == null || hit.category == category) &&
              (matchAll || hit.name.toLowerCase().contains(typed)))
            hit,
      ],
    );
  }
}

/// A catalog folder with [SampleCatalog] installed as version 1, as if D0 had
/// finished: the editors and AD19 can read it at once.
Directory installedCatalogDir() {
  final dir = Directory.systemTemp.createTempSync('el3yada-installed-catalog');
  _temporary.add(dir);
  const catalog = SampleCatalog();
  final file = File('${dir.path}${Platform.pathSeparator}catalog-v1.sqlite');
  catalog.writeTo(file.path);
  CatalogFiles(dir).writeInstalled(
    InstalledCatalog(
      version: CatalogVersionInfo(
        version: 1,
        schemaVersion: catalog.schemaVersion,
        sha256: '',
        sizeBytes: file.lengthSync(),
        counts: CatalogCounts(
          drugs: catalog.drugs.length,
          labs: catalog.labs.length,
          radiology: catalog.radiology.length,
        ),
        drugSourceDate: catalog.drugSourceDate,
        loincRelease: catalog.loincRelease,
      ),
      fileName: 'catalog-v1.sqlite',
    ),
  );
  return dir;
}

/// The catalog without a device or a server: the offline catalog server with
/// no delays, a temporary folder ([installedCatalogDir] unless [dir]), SQLite
/// in the test's isolate, and the file checks inline.
List<Override> catalogOverrides({
  Directory? dir,
  FakeCatalogBackend? backend,
  CatalogController Function()? controller,
}) => [
  fakeCatalogBackendProvider.overrideWithValue(
    backend ??
        FakeCatalogBackend(delay: Duration.zero, chunkDelay: Duration.zero),
  ),
  catalogFilesProvider.overrideWith(
    (ref) async => CatalogFiles(dir ?? installedCatalogDir()),
  ),
  catalogDbProvider.overrideWith((ref) {
    final db = DirectCatalogDb();
    ref.onDispose(db.dispose);
    return db;
  }),
  catalogBackgroundRunnerProvider.overrideWithValue(runInline),
  if (controller != null) catalogControllerProvider.overrideWith(controller),
];

/// D0's states without downloading anything: [start] does nothing and
/// [retry] is counted; tests move it with [set].
class FixedCatalogController extends CatalogController {
  FixedCatalogController([this.initial = const CatalogState()]);

  final CatalogState initial;
  int retries = 0;

  @override
  CatalogState build() => initial;

  @override
  Future<void> start() async {}

  @override
  Future<void> retry() async => retries++;

  void set(CatalogState next) => state = next;
}
