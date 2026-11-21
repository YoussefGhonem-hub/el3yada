// The catalog end to end against a running API (spec 6.9, 9.5, AC-18),
// with the real file from the catalog builder. Off by default; the file and
// LOINC content are never committed. From app/:
//
//   EL3YADA_API_URL=http://localhost:5001 EL3YADA_ADMIN_EMAIL=<super admin> \
//   EL3YADA_ADMIN_PASSWORD=<temporary password> \
//   EL3YADA_CATALOG_GZ=<...>/out/catalog-v1.sqlite.gz \
//   flutter test test/contract/phase3_catalog_e2e_test.dart
//
// The admin's temporary password is replaced on the first run (A9); later
// runs sign in with the new one. Each run publishes the file again as a new
// version and signs up a new cardiologist.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/catalog/data/admin_catalog_repository.dart';
import 'package:el3yada/features/catalog/data/catalog_api.dart';
import 'package:el3yada/features/catalog/data/catalog_db.dart';
import 'package:el3yada/features/catalog/data/catalog_files.dart';
import 'package:el3yada/features/catalog/data/local_catalog_search.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/catalog_support.dart' show FixedHistory;
import 'contract_support.dart';

final _env = Platform.environment;
final _baseUrl = _env['EL3YADA_API_URL'];
final _gz = _env['EL3YADA_CATALOG_GZ'];

void main() {
  final skip =
      _baseUrl == null || _env['EL3YADA_ADMIN_EMAIL'] == null || _gz == null
      ? 'Set EL3YADA_API_URL, EL3YADA_ADMIN_EMAIL, EL3YADA_ADMIN_PASSWORD and EL3YADA_CATALOG_GZ'
      : null;
  final run = contractRunId();
  final report = StringBuffer();
  late ContractAccount admin;
  late ContractAccount doctor;
  late AdminCatalogRepository adminCatalog;
  late CatalogApi doctorCatalog;
  late CatalogVersionInfo published;
  late Directory dir;
  final db = IsolateCatalogDb();

  setUpAll(() async {
    if (skip != null) return;
    dir = Directory.systemTemp.createTempSync('el3yada-catalog-e2e');
    final plain = contractClient(_baseUrl);
    admin = ContractAccount(_baseUrl, plain);
    doctor = ContractAccount(_baseUrl, plain);
    final email = _env['EL3YADA_ADMIN_EMAIL']!;
    final session = await signInAdmin(
      admin,
      email,
      _env['EL3YADA_ADMIN_PASSWORD'] ?? '',
      'CatalogE2e-2026',
      contractDevice('admin', run),
    );
    admin.token = session.accessToken;
    adminCatalog = ApiAdminCatalogRepository(admin.dio);
  });

  tearDownAll(() async {
    if (skip != null) return;
    await db.dispose();
    // ignore: avoid_print
    print(report);
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still open on Windows.
    }
  });

  test(
    'AD20: publishCatalog takes the real file and makes it current',
    skip: skip,
    () async {
      final gz = File(_gz!);
      final manifest = File(
        _gz!.replaceFirst(RegExp(r'\.sqlite\.gz$'), '.json'),
      ).readAsStringSync();
      final watch = Stopwatch()..start();
      var lastSent = 0;
      try {
        published = await adminCatalog.publish(
          file: PickedCatalogFile(
            name: 'catalog-v1.sqlite.gz',
            sizeBytes: gz.lengthSync(),
            path: gz.path,
          ),
          manifest: manifest,
          onProgress: (sent, total) => lastSent = sent,
        );
      } on ApiException catch (error) {
        // A smaller file than the current version: confirm, as AD20 does.
        expect(error.code, 'CATALOG_COUNT_DROP');
        published = await adminCatalog.publish(
          file: PickedCatalogFile(
            name: 'catalog-v1.sqlite.gz',
            sizeBytes: gz.lengthSync(),
            path: gz.path,
          ),
          manifest: manifest,
          confirmDrop: true,
        );
      }
      report.writeln(
        'publishCatalog: ${watch.elapsedMilliseconds} ms, upload progress reached $lastSent bytes',
      );
      expect(published.sha256, (jsonDecode(manifest) as Map)['sha256']);
      expect(published.counts.drugs, 24715);
      expect(published.counts.labs, 43459);
      expect(published.counts.radiology, 6941);
      expect(published.schemaVersion, 1);
      final versions = await adminCatalog.versions();
      expect(versions.first.version.version, published.version);
      expect(versions.first.current, isTrue);
    },
  );

  test(
    'a sha256 that does not match is refused (CATALOG_SHA_MISMATCH)',
    skip: skip,
    () async {
      final gz = File(_gz!);
      await expectLater(
        adminCatalog.publish(
          file: PickedCatalogFile(
            name: 'catalog.sqlite.gz',
            sizeBytes: gz.lengthSync(),
            path: gz.path,
          ),
          manifest: jsonEncode({'sha256': '0' * 64}),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.fieldCodes['file'],
            'file',
            'CATALOG_SHA_MISMATCH',
          ),
        ),
      );
    },
  );

  test(
    'a cardiologist signs up; D0 downloads the current version, resuming after a drop',
    skip: skip,
    () async {
      final specialties = await doctor.registration.specialties();
      final cardiology = specialties.firstWhere(
        (s) => s.nameEn == 'Cardiology',
      );
      final email = 'catalog-e2e-$run@el3yada.dev';
      final device = contractDevice('doctor', run);
      await doctor.registration.register(
        doctorRegistration(
          fullName: 'طبيب كتالوج تجريبي',
          email: email,
          phone: contractMobile(),
          password: 'CatalogE2e-2026',
          licenseNumber: 'K${run.substring(4, 13)}',
          specialtyId: cardiology.id,
          device: device,
        ),
        contractLicense(),
      );
      final signedIn = await doctor.auth.login(
        identifier: email,
        password: 'CatalogE2e-2026',
        device: device,
      );
      expect(signedIn, isA<SignedIn>());
      doctor.token = (signedIn as SignedIn).session.accessToken;
      doctorCatalog = ApiCatalogApi(doctor.dio);

      final current = (await doctorCatalog.current())!;
      expect(current.version, published.version);
      expect(current.sha256, published.sha256);

      final watch = Stopwatch()..start();
      // The connection drops after 2 MB; the next try asks for the rest (206).
      final dropping = _DroppingApi(doctorCatalog, dropAfter: 2 * 1024 * 1024);
      final files = CatalogFiles(dir);
      await expectLater(
        CatalogDownloader(api: dropping, files: files).fetch(current),
        throwsA(isA<CatalogDownloadException>()),
      );
      expect(files.part(current.version).lengthSync(), 2 * 1024 * 1024);
      final file = await CatalogDownloader(
        api: dropping..dropAfter = null,
        files: files,
      ).fetch(current);
      expect(dropping.partials, [false, true]);
      report.writeln(
        'D0 download of ${current.sizeBytes} bytes from localhost, resumed once, checked and unpacked: '
        '${watch.elapsedMilliseconds} ms',
      );
      expect(catalogFileSchemaVersion(file.path), 1);
      await db.open(file.path);
    },
  );

  test(
    'AC-18 against the downloaded file with the cardiologist\'s myProfile',
    skip: skip,
    () async {
      final profile = await doctorCatalog.myProfile();
      expect(
        profile.drugGroups,
        containsAll(['lipid_lowering', 'antihypertensives', 'gastric_acid']),
      );
      expect(profile.includesGeneral, isTrue);
      final search = LocalCatalogSearch(
        history: FixedHistory(),
        database: () => db,
        profile: () => profile,
      );

      final ator = await search.drugs('ator');
      expect(
        ator.mySpecialty.where(
          (h) => (h.activeIngredient ?? '').contains('ATORVASTATIN'),
        ),
        isNotEmpty,
      );
      expect(
        ator.others.where(
          (h) => (h.activeIngredient ?? '').contains('ATORVASTATIN'),
        ),
        isEmpty,
      );
      final omep = await search.drugs('omep');
      expect(
        omep.mySpecialty.where(
          (h) => (h.activeIngredient ?? '').contains('OMEPRAZOLE'),
        ),
        isNotEmpty,
      );
      final panadol = await search.drugs('بنادول');
      expect(
        [
          ...panadol.mySpecialty,
          ...panadol.others,
        ].any((h) => h.name.startsWith('PANADOL')),
        isTrue,
      );
      for (final typed in ['CBC', 'صورة دم كاملة']) {
        final cbc = await search.tests(typed, category: 'lab');
        expect(
          [...cbc.mySpecialty, ...cbc.others].take(5).map((h) => h.code),
          contains('58410-2'),
          reason: typed,
        );
      }
      final only = await search.drugs('omep', mySpecialtyOnly: true);
      expect(only.others, isEmpty);
      report.writeln(
        'AC-18 on the real file: "ator" ${ator.mySpecialty.length} in the specialty section '
        '(first: ${ator.mySpecialty.first.name}); «بنادول» → ${panadol.others.followedBy(panadol.mySpecialty).first.name}',
      );
    },
  );

  test(
    'BR-CAT9: a custom item reaches the doctor\'s sync, and leaves it when disabled',
    skip: skip,
    () async {
      var page = await doctorCatalog.customItems();
      var since = page.nextSince;
      while (page.hasMore) {
        page = await doctorCatalog.customItems(since: since);
        since = page.nextSince;
      }
      final created = await adminCatalog.createCustomItem(
        CustomItemDraft(
          type: CatalogItemType.drug,
          nameEn: 'E2ECILLIN $run',
          nameAr: 'تجربة',
          activeIngredient: 'AMOXICILLIN',
          drugGroupId: 'antibiotics',
          route: 'ORAL.SOLID',
          aliases: const ['e2e'],
        ),
      );
      final added = await doctorCatalog.customItems(since: since);
      expect(
        added.items.map((i) => i.customItemId),
        contains(created.customItemId),
      );
      final search = LocalCatalogSearch(
        history: FixedHistory(),
        database: () => db,
        profile: () => const CatalogProfile(drugGroups: {'antibiotics'}),
        customItems: () => added.items.where((i) => i.active),
      );
      expect(
        (await search.drugs('e2ecillin')).mySpecialty.first.catalogId,
        'custom:${created.customItemId}',
      );

      await adminCatalog.updateCustomItem(
        created.customItemId,
        CustomItemDraft.of(created).copyWith(active: false),
      );
      final removed = await doctorCatalog.customItems(since: added.nextSince);
      expect(removed.items.single.active, isFalse);
    },
  );

  test(
    'AD19: the cardiology profile, edited, reaches myProfile; then restored',
    skip: skip,
    () async {
      final specialties = await adminCatalog.specialties();
      expect(specialties.first.isGeneral, isTrue);
      final cardiology = specialties.firstWhere(
        (s) => s.nameEn == 'Cardiology',
      );
      expect(cardiology.doctorCount, greaterThanOrEqualTo(1));
      final before = await adminCatalog.profile(cardiology.specialtyId);
      final edited = await adminCatalog.updateProfile(
        before.copyWith(drugGroups: [...before.drugGroups, 'gout']),
      );
      expect(edited.drugGroups, contains('gout'));
      expect((await doctorCatalog.myProfile()).drugGroups, contains('gout'));
      final restored = await adminCatalog.updateProfile(before);
      expect(restored.drugGroups, before.drugGroups);
    },
  );

  test(
    'doctor reports [S]: reported by the doctor, handled in AD20',
    skip: skip,
    () async {
      final response = await doctor.dio.post<Map<String, dynamic>>(
        '/catalog/reportCatalogItem',
        data: {'type': 'missing', 'text': 'E2E $run', 'itemRef': 'search:e2e'},
      );
      final reportId = response.data!['reportId'] as String;
      final open = await adminCatalog.reports();
      expect(open.items.map((r) => r.reportId), contains(reportId));
      final handled = await adminCatalog.handleReport(reportId);
      expect(handled.done, isTrue);
    },
  );
}

/// Passes requests through, dropping the connection after [dropAfter] bytes.
class _DroppingApi implements CatalogApi {
  _DroppingApi(this.inner, {this.dropAfter});

  final CatalogApi inner;
  int? dropAfter;
  final partials = <bool>[];

  @override
  Future<CatalogFileResponse> file(
    int version, {
    int from = 0,
    String? ifRange,
    CancelToken? cancel,
  }) async {
    final response = await inner.file(
      version,
      from: from,
      ifRange: ifRange,
      cancel: cancel,
    );
    partials.add(response.partial);
    final limit = dropAfter;
    if (limit == null) return response;
    Stream<List<int>> cut() async* {
      var sent = 0;
      await for (final chunk in response.body) {
        if (sent + chunk.length >= limit) {
          yield chunk.sublist(0, limit - sent);
          throw const SocketException('Connection reset (test)');
        }
        sent += chunk.length;
        yield chunk;
      }
    }

    return CatalogFileResponse(
      partial: response.partial,
      totalBytes: response.totalBytes,
      body: cut(),
    );
  }

  @override
  Future<CatalogVersionInfo?> current() => inner.current();

  @override
  Future<CustomItemSyncPage> customItems({String? since}) =>
      inner.customItems(since: since);

  @override
  Future<CatalogProfile> myProfile() => inner.myProfile();
}
