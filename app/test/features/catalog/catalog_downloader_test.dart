import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:catalog_core/catalog_core.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart' show CancelToken;
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/catalog/application/catalog_providers.dart';
import 'package:el3yada/features/catalog/data/catalog_api.dart';
import 'package:el3yada/features/catalog/data/catalog_db.dart';
import 'package:el3yada/features/catalog/data/catalog_files.dart';
import 'package:el3yada/features/catalog/data/local_catalog_search.dart';
import 'package:el3yada/features/catalog/data/sample_catalog.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/catalog_support.dart';

/// D0's download (spec 9.5, BR-CAT12): resume with HTTP ranges, the sha256
/// and schema checks, and the atomic swap to a new version.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('el3yada-download-test'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still open on Windows.
    }
  });
  tearDownAll(deleteTestCatalogs);

  List<String> files() => [for (final entry in dir.listSync()) entry.uri.pathSegments.last]..sort();

  test('resumes an interrupted download with a range request, after a restart too', () async {
    final published = _Published.of(const SampleCatalog());
    final api = _ServingApi({1: published})..dropAfter = 1000;
    final target = published.info(1);

    final first = CatalogDownloader(api: api, files: CatalogFiles(dir), run: runInline);
    await expectLater(
      first.fetch(target),
      throwsA(isA<CatalogDownloadException>().having((e) => e.failure, 'failure', CatalogFailure.network)),
    );
    expect(files(), ['download-v1.gz.part']);
    expect(File('${dir.path}/download-v1.gz.part').lengthSync(), 1000);

    // A new downloader, as after an app restart: it asks from byte 1000.
    api.dropAfter = null;
    final progress = <int>[];
    final file = await CatalogDownloader(
      api: api,
      files: CatalogFiles(dir),
      run: runInline,
    ).fetch(target, onProgress: (received, total) => progress.add(received));
    expect(api.requests, [0, 1000]);
    expect(progress.first, 1000);
    expect(progress.last, published.bytes.length);
    expect(file.path, endsWith('catalog-v1.sqlite'));
    expect(files(), ['catalog-v1.sqlite']);
    expect(catalogFileSchemaVersion(file.path), catalogSchemaVersion);
  });

  test('a server that ignores the range sends the whole file, and that works too', () async {
    final published = _Published.of(const SampleCatalog());
    final api = _ServingApi({1: published})..dropAfter = 500;
    final downloader = CatalogDownloader(api: api, files: CatalogFiles(dir), run: runInline);
    await expectLater(downloader.fetch(published.info(1)), throwsA(isA<CatalogDownloadException>()));
    api
      ..dropAfter = null
      ..ignoreRanges = true;
    final file = await downloader.fetch(published.info(1));
    expect(catalogFileSchemaVersion(file.path), catalogSchemaVersion);
  });

  test('a sha256 mismatch deletes the download and asks to try again', () async {
    final published = _Published.of(const SampleCatalog());
    final api = _ServingApi({1: published});
    final wrong = CatalogVersionInfo(version: 1, schemaVersion: 1, sha256: '0' * 64, sizeBytes: published.bytes.length);
    await expectLater(
      CatalogDownloader(api: api, files: CatalogFiles(dir), run: runInline).fetch(wrong),
      throwsA(isA<CatalogDownloadException>().having((e) => e.failure, 'failure', CatalogFailure.checksum)),
    );
    expect(files(), isEmpty);
  });

  test('a schema this app does not read is refused, and nothing is kept', () async {
    final published = _Published.of(const SampleCatalog(schemaVersion: catalogSchemaVersion + 1));
    final api = _ServingApi({1: published});
    await expectLater(
      CatalogDownloader(api: api, files: CatalogFiles(dir), run: runInline).fetch(published.info(1)),
      throwsA(
        isA<CatalogDownloadException>()
            .having((e) => e.failure, 'failure', CatalogFailure.schema)
            .having((e) => e.schemaVersion, 'schemaVersion', catalogSchemaVersion + 1),
      ),
    );
    expect(files(), isEmpty);
  });

  test('a file that is not a gzip-compressed catalog is refused', () async {
    final junk = Uint8List.fromList(gzip.encode(utf8.encode('not a database')));
    final published = _Published(junk);
    await expectLater(
      CatalogDownloader(
        api: _ServingApi({1: published}),
        files: CatalogFiles(dir),
        run: runInline,
      ).fetch(published.info(1)),
      throwsA(isA<CatalogDownloadException>().having((e) => e.failure, 'failure', CatalogFailure.corrupt)),
    );
    expect(files(), isEmpty);
  });

  test('the sha256 and gunzip run in an isolate in the app', () async {
    final published = _Published.of(const SampleCatalog());
    final file = await CatalogDownloader(
      api: _ServingApi({1: published}),
      files: CatalogFiles(dir),
    ).fetch(published.info(1));
    expect(catalogFileSchemaVersion(file.path), catalogSchemaVersion);
  });

  group('CatalogController (the atomic swap)', () {
    late _ServingApi api;
    late ProviderContainer container;
    late DirectCatalogDb db;
    var current = 1;

    setUp(() {
      current = 1;
      api = _ServingApi({1: _Published.of(const SampleCatalog())})..published = () => current;
      db = DirectCatalogDb();
      container = ProviderContainer(
        overrides: [
          catalogEligibleProvider.overrideWithValue(true),
          catalogApiProvider.overrideWithValue(api),
          catalogFilesProvider.overrideWith((ref) async => CatalogFiles(dir)),
          catalogDbProvider.overrideWithValue(db),
          catalogBackgroundRunnerProvider.overrideWithValue(runInline),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.dispose();
      });
    });

    Future<CatalogState> started() async {
      final controller = container.read(catalogControllerProvider.notifier);
      await controller.start();
      return container.read(catalogControllerProvider);
    }

    LocalCatalogSearch search() => LocalCatalogSearch(
      history: FixedHistory(),
      database: () => container.read(catalogControllerProvider.notifier).database,
    );

    test('downloads, checks and opens version 1; nothing else is left behind', () async {
      final state = await started();
      expect(state.phase, CatalogPhase.ready);
      expect(state.installed?.version, 1);
      expect(db.path, endsWith('catalog-v1.sqlite'));
      expect(files(), ['catalog-v1.sqlite', 'state.json']);
      expect((await search().drugs('panadol')).others, isNotEmpty);
    });

    test('a new version replaces the old one only once it is checked and open', () async {
      await started();
      // Version 2 adds a medicine.
      api.versions[2] = _Published.of(
        const SampleCatalog(
          catalogVersion: 2,
          drugs: [
            ...sampleDrugs,
            SampleDrug('NEWDRUG 10 MG 20 TABS.', 'نيودراج', 'NEWINE', 'Pharco', 'other', 'ORAL.SOLID', 'Tablet'),
          ],
        ),
      );
      current = 2;
      final controller = container.read(catalogControllerProvider.notifier);
      final run = controller.start();
      // While it downloads, search still answers from version 1.
      expect(container.read(catalogControllerProvider).installed?.version, 1);
      expect((await search().drugs('panadol')).others, isNotEmpty);
      await run;

      final state = container.read(catalogControllerProvider);
      expect(state.phase, CatalogPhase.ready);
      expect(state.installed?.version, 2);
      expect(db.path, endsWith('catalog-v2.sqlite'));
      expect(files(), ['catalog-v2.sqlite', 'state.json']);
      expect((await search().drugs('newdrug')).others.single.name, 'NEWDRUG 10 MG 20 TABS.');
      final saved = jsonDecode(File('${dir.path}/state.json').readAsStringSync()) as Map;
      expect(saved['fileName'], 'catalog-v2.sqlite');
    });

    test('a failed new version keeps the old one in use', () async {
      await started();
      api.versions[2] = _Published.of(const SampleCatalog(catalogVersion: 2), sha: '1' * 64);
      current = 2;
      await container.read(catalogControllerProvider.notifier).start();
      final state = container.read(catalogControllerProvider);
      expect(state.phase, CatalogPhase.failed);
      expect(state.failure, CatalogFailure.checksum);
      expect(state.installed?.version, 1);
      expect(db.path, endsWith('catalog-v1.sqlite'));
      expect(files(), ['catalog-v1.sqlite', 'state.json']);
    });

    test('at the next start the file on the device opens at once, offline too', () async {
      await started();
      api.offline = true;
      final again = ProviderContainer(
        overrides: [
          catalogEligibleProvider.overrideWithValue(true),
          catalogApiProvider.overrideWithValue(api),
          catalogFilesProvider.overrideWith((ref) async => CatalogFiles(dir)),
          catalogDbProvider.overrideWithValue(db),
          catalogBackgroundRunnerProvider.overrideWithValue(runInline),
        ],
      );
      addTearDown(again.dispose);
      await again.read(catalogControllerProvider.notifier).start();
      final state = again.read(catalogControllerProvider);
      expect(state.phase, CatalogPhase.ready);
      expect(state.installed?.version, 1);
    });

    test('nothing published yet: the editors use the history', () async {
      current = 0;
      final state = await started();
      expect(state.phase, CatalogPhase.notPublished);
      expect(state.ready, isFalse);
    });

    test('offline at the first sign-in: failed with Retry, and Retry finishes it', () async {
      api.offline = true;
      var state = await started();
      expect(state.phase, CatalogPhase.failed);
      expect(state.failure, CatalogFailure.network);
      api.offline = false;
      await container.read(catalogControllerProvider.notifier).retry();
      state = container.read(catalogControllerProvider);
      expect(state.phase, CatalogPhase.ready);
    });
  });
}

class _Published {
  _Published(this.bytes, {String? sha}) : sha256 = sha ?? crypto.sha256.convert(bytes).toString();

  factory _Published.of(SampleCatalog catalog, {String? sha}) {
    final path = writeTestCatalog(catalog: catalog);
    return _Published(Uint8List.fromList(gzip.encode(File(path).readAsBytesSync())), sha: sha);
  }

  final Uint8List bytes;
  final String sha256;

  CatalogVersionInfo info(int version) => CatalogVersionInfo(
    version: version,
    schemaVersion: catalogSchemaVersion,
    sha256: sha256,
    sizeBytes: bytes.length,
  );
}

/// Serves versions from memory like `GET /api/catalog/file/{n}`, with HTTP
/// ranges; can drop the connection after some bytes or be offline.
class _ServingApi implements CatalogApi {
  _ServingApi(this.versions);

  final Map<int, _Published> versions;
  int Function() published = () => 1;
  int? dropAfter;
  bool ignoreRanges = false;
  bool offline = false;
  final requests = <int>[];

  @override
  Future<CatalogVersionInfo?> current() async {
    if (offline) throw const ApiException(kind: ApiErrorKind.network);
    final number = published();
    return number == 0 ? null : versions[number]!.info(number);
  }

  @override
  Future<CatalogFileResponse> file(int version, {int from = 0, String? ifRange, CancelToken? cancel}) async {
    if (offline) throw const ApiException(kind: ApiErrorKind.network);
    requests.add(from);
    final bytes = versions[version]!.bytes;
    final start = ignoreRanges ? 0 : from;
    final drop = dropAfter;
    Stream<List<int>> body() async* {
      var sent = 0;
      for (var i = start; i < bytes.length; i += 256) {
        final chunk = bytes.sublist(i, (i + 256).clamp(0, bytes.length));
        if (drop != null && sent + chunk.length > drop) {
          yield chunk.sublist(0, drop - sent);
          throw const SocketException('Connection reset');
        }
        sent += chunk.length;
        yield chunk;
      }
    }

    return CatalogFileResponse(partial: start > 0, totalBytes: bytes.length, body: body());
  }

  @override
  Future<CustomItemSyncPage> customItems({String? since}) async => const CustomItemSyncPage(items: []);

  @override
  Future<CatalogProfile> myProfile() async => CatalogProfile.empty;
}
