// Timings on the real catalog file (spec A.8 "measured on a real phone";
// this measures the host). The file is never committed (LOINC content), so
// the test is skipped unless EL3YADA_CATALOG_GZ points at the builder's
// `catalog-v<n>.sqlite.gz` (its manifest `.json` next to it):
//
//   $env:EL3YADA_CATALOG_GZ="D:\...\out\catalog-v1.sqlite.gz"; flutter test test/features/catalog/real_catalog_timing_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:el3yada/features/catalog/data/catalog_api.dart';
import 'package:el3yada/features/catalog/data/catalog_db.dart';
import 'package:el3yada/features/catalog/data/catalog_files.dart';
import 'package:el3yada/features/catalog/data/local_catalog_search.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:el3yada/features/catalog/domain/catalog_search.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/catalog_support.dart';

final _gz = Platform.environment['EL3YADA_CATALOG_GZ'];

void main() {
  final skip = _gz == null || !File(_gz!).existsSync()
      ? 'Set EL3YADA_CATALOG_GZ to the real catalog .gz'
      : null;

  // Cardiology + General, from tools/catalog-builder/mappings/specialty-profiles.csv.
  const cardiology = CatalogProfile(
    drugGroups: {
      'antihypertensives',
      'antiplatelets',
      'anticoagulants',
      'lipid_lowering',
      'antiarrhythmics',
      'antianginals',
      'diuretics', 'heart_failure', //
      'analgesics',
      'nsaids',
      'antibiotics',
      'gastric_acid',
      'vitamins',
      'supplements',
      'antihistamines',
    },
    labCodes: {'24331-1', '10839-9', '6598-7', '58410-2', '57021-8'},
    radiologyRegions: {'Heart', 'Coronary arteries'},
    radiologyCodes: {'42148-7', '36643-5'},
  );

  late Directory dir;
  late File database;
  final report = StringBuffer();

  setUpAll(() async {
    if (skip != null) return;
    dir = Directory.systemTemp.createTempSync('el3yada-real-catalog');
    final manifest =
        jsonDecode(
              File(
                _gz!.replaceFirst(RegExp(r'\.sqlite\.gz$'), '.json'),
              ).readAsStringSync(),
            )
            as Map;
    final bytes = File(_gz!).readAsBytesSync();
    final target = CatalogVersionInfo(
      version: 1,
      schemaVersion: 1,
      sha256: manifest['sha256'] as String,
      sizeBytes: bytes.length,
    );
    final watch = Stopwatch()..start();
    database = await CatalogDownloader(
      api: _LocalFileApi(bytes),
      files: CatalogFiles(dir),
    ).fetch(target);
    report.writeln(
      'D0 after the download (sha256 + gunzip + schema check, in isolates): ${watch.elapsedMilliseconds} ms '
      'for ${bytes.length} → ${database.lengthSync()} bytes',
    );
  });

  tearDownAll(() {
    if (skip != null) return;
    // ignore: avoid_print
    print(report);
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still open on Windows.
    }
  });

  Future<void> measure(String label, CatalogDb db) async {
    final opened = Stopwatch()..start();
    await db.open(database.path);
    report.writeln('$label: open ${opened.elapsedMicroseconds / 1000} ms');
    final search = LocalCatalogSearch(
      history: FixedHistory(),
      database: () => db,
      profile: () => cardiology,
    );
    Future<(Duration, int, int)> time(
      Future<CatalogHits<Object?>> Function() run,
    ) async {
      final runs = <Duration>[];
      late CatalogHits<Object?> hits;
      for (var i = 0; i < 7; i++) {
        final watch = Stopwatch()..start();
        hits = await run();
        runs.add(watch.elapsed);
      }
      runs.sort();
      return (
        runs[runs.length ~/ 2],
        hits.mySpecialty.length,
        hits.others.length,
      );
    }

    for (final query in [
      'at',
      'ator',
      'pa',
      'panadol',
      'paracetamol',
      'omep',
      'بنادول',
      'با',
      'amox 500',
    ]) {
      final (took, specialty, others) = await time(() => search.drugs(query));
      report.writeln(
        '  drugs "$query": ${took.inMicroseconds / 1000} ms ($specialty specialty, $others others)',
      );
    }
    for (final (query, category) in [
      ('cb', 'lab'),
      ('CBC', 'lab'),
      ('صورة دم كاملة', 'lab'),
      ('hba1c', 'lab'),
      ('xr chest', 'radiology'),
      ('سونار بطن', 'radiology'),
      ('echo', 'radiology'),
      ('cr', null),
    ]) {
      final (took, specialty, others) = await time(
        () => search.tests(query, category: category),
      );
      report.writeln(
        '  tests "$query" (${category ?? 'both'}): ${took.inMicroseconds / 1000} ms ($specialty specialty, $others others)',
      );
    }
    final hits = await search.drugs('بنادول');
    expect(
      hits.others
          .followedBy(hits.mySpecialty)
          .any((h) => h.name.startsWith('PANADOL')),
      isTrue,
    );
    final cbc = await search.tests('CBC', category: 'lab');
    expect(
      [...cbc.mySpecialty, ...cbc.others].take(5).map((h) => h.code),
      contains('58410-2'),
    );
    await db.dispose();
  }

  test(
    'search timings, background isolate (what the app uses)',
    skip: skip,
    () async {
      await measure('Isolate', IsolateCatalogDb());
    },
  );

  test('search timings, same isolate (SQLite alone)', skip: skip, () async {
    await measure('Direct', DirectCatalogDb());
  });
}

/// Serves the real file from memory, as the API would.
class _LocalFileApi implements CatalogApi {
  _LocalFileApi(this.bytes);

  final List<int> bytes;

  @override
  Future<CatalogFileResponse> file(
    int version, {
    int from = 0,
    String? ifRange,
    CancelToken? cancel,
  }) async => CatalogFileResponse(
    partial: from > 0,
    totalBytes: bytes.length,
    body: Stream.fromIterable([
      for (var i = from; i < bytes.length; i += 65536)
        bytes.sublist(i, (i + 65536).clamp(0, bytes.length)),
    ]),
  );

  @override
  Future<CatalogVersionInfo?> current() => throw UnimplementedError();

  @override
  Future<CustomItemSyncPage> customItems({String? since}) =>
      throw UnimplementedError();

  @override
  Future<CatalogProfile> myProfile() => throw UnimplementedError();
}
