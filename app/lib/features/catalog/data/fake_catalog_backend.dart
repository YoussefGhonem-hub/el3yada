import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:catalog_core/catalog_core.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart' show CancelToken;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/data/paged.dart';
import '../../../core/network/api_exception.dart';
import '../../doctor_registration/data/registration_repository.dart';
import '../domain/catalog_models.dart';
import 'admin_catalog_repository.dart';
import 'catalog_api.dart';
import 'catalog_files.dart' show catalogFileSchemaVersion;
import 'sample_catalog.dart';

/// The offline catalog server (`USE_FAKE_AUTH`): published versions with
/// their files, custom items, doctor reports and specialty profiles, shared
/// by the device API ([FakeCatalogApi]) and AD19/AD20
/// ([FakeAdminCatalogRepository]), with the API's rules and error codes. What
/// the admin changes, the offline doctor's search sees.
///
/// Version 1 is [SampleCatalog]: 24 medicines, 12 lab tests and 10
/// radiology procedures.
class FakeCatalogBackend {
  FakeCatalogBackend({
    this.delay = const Duration(milliseconds: 300),
    this.chunkDelay = const Duration(milliseconds: 40),
    this.chunkSize = 4096,
    this.published = true,
    DateTime? now,
  }) : _seededAt = (now ?? DateTime.now()).toUtc() {
    _seed();
  }

  final Duration delay;

  /// Between download chunks, so D0's progress can be seen offline.
  final Duration chunkDelay;
  final int chunkSize;

  /// False: no version yet (`CATALOG_NOT_PUBLISHED`).
  bool published;
  final DateTime _seededAt;

  /// The offline doctor's specialty (Internal Medicine), for `myProfile`.
  String doctorSpecialtyId = 'sp-internal';

  final _versions = <_Version>[];
  final customItems = <String, CustomCatalogItem>{};
  final reports = <String, CatalogReport>{};
  final specialties = <SpecialtySummary>[];
  final profiles = <String, SpecialtyProfile>{};
  final calls = <String, int>{};
  final _failures = <String, ApiException>{};
  int _nextId = 1;

  /// Makes the next call to [method] throw [error] (tests).
  void failNext(String method, ApiException error) => _failures[method] = error;

  static const generalId = 'sp-general';

  Future<void> step(String method) async {
    calls[method] = (calls[method] ?? 0) + 1;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = _failures.remove(method);
    if (failure != null) throw failure;
  }

  _Version? get _current => published && _versions.isNotEmpty ? _versions.firstWhere((v) => v.current) : null;

  DateTime get _now => DateTime.now().toUtc();

  // ---------------------------------------------------------------------------
  // Seed

  void _seed() {
    _versions.add(_Version.sample(const SampleCatalog(), number: 1, at: _seededAt.subtract(const Duration(days: 9))));

    specialties.add(
      const SpecialtySummary(specialtyId: generalId, nameAr: 'عام', nameEn: 'General', active: false, isGeneral: true),
    );
    const doctorCounts = [42, 18, 11, 9, 14, 6, 4, 23, 7, 5, 8, 10, 12, 3, 2, 5, 9, 1, 20];
    for (final (i, specialty) in FakeRegistrationRepository.specialtyList.indexed) {
      specialties.add(
        SpecialtySummary(
          specialtyId: specialty.id,
          nameAr: specialty.nameAr,
          nameEn: specialty.nameEn,
          doctorCount: doctorCounts[i % doctorCounts.length],
        ),
      );
    }

    SpecialtyProfile profile(
      String id, {
      List<String> groups = const [],
      List<String> routes = const [],
      List<String> labs = const [],
      List<String> regions = const [],
      List<String> modalities = const [],
      List<String> procedures = const [],
    }) {
      final summary = specialties.firstWhere((s) => s.specialtyId == id);
      return SpecialtyProfile(
        specialtyId: id,
        nameAr: summary.nameAr,
        nameEn: summary.nameEn,
        isGeneral: summary.isGeneral,
        includeGeneral: !summary.isGeneral,
        drugGroups: groups,
        routes: routes,
        labCodes: labs,
        radiologyRegions: regions,
        radiologyModalities: modalities,
        radiologyCodes: procedures,
        updatedAt: _seededAt.subtract(const Duration(days: 9)),
      );
    }

    for (final seeded in [
      profile(
        generalId,
        groups: ['analgesics', 'nsaids', 'antibiotics', 'gastric_acid', 'vitamins', 'antihistamines'],
        labs: ['99001-0', '99011-9', '99004-4', '99010-1'],
      ),
      profile(
        'sp-internal',
        groups: ['antihypertensives', 'antidiabetics_oral', 'gastric_acid', 'antibiotics', 'lipid_lowering'],
        labs: ['99001-0', '99003-6', '99004-4', '99005-1', '99006-9', '99008-5', '99009-3', '99010-1'],
        procedures: ['99101-8', '99102-6'],
      ),
      profile(
        'sp-cardio',
        groups: ['antihypertensives', 'antiplatelets', 'lipid_lowering'],
        labs: ['99006-9', '99007-7', '99008-5'],
        regions: ['Heart', 'Coronary arteries'],
        procedures: ['99103-4', '99101-8', '99110-9'],
      ),
      profile(
        'sp-pediatrics',
        groups: ['analgesics', 'antibiotics', 'antihistamines', 'vitamins', 'cold_flu'],
        routes: ['ORAL.LIQUID', 'RECTAL'],
        labs: ['99001-0', '99011-9', '99010-1'],
        procedures: ['99101-8', '99102-6'],
      ),
      profile('sp-derma', groups: ['topical_steroids', 'antihistamines'], routes: ['TOPICAL'], labs: ['99001-0']),
      profile(
        'sp-ortho',
        groups: ['nsaids', 'vitamins'],
        labs: ['99012-7', '99011-9'],
        regions: ['Lower extremity', 'Spine.lumbar', 'Knee'],
        modalities: ['DXA'],
      ),
      profile(
        'sp-obgyn',
        groups: ['vitamins', 'antibiotics'],
        labs: ['99001-0'],
        regions: ['Pelvis', 'Breast'],
        modalities: ['MG'],
      ),
      profile('sp-endo', groups: ['antidiabetics_oral'], labs: ['99003-6', '99004-4', '99005-1', '99012-7']),
      profile('sp-neuro', regions: ['Brain', 'Spine.lumbar'], procedures: ['99104-2', '99105-9']),
    ]) {
      profiles[seeded.specialtyId] = seeded;
    }
    _refreshCounts();

    for (final item in [
      CustomCatalogItem(
        customItemId: 'ci-${_nextId++}',
        type: CatalogItemType.drug,
        nameEn: 'NEWCILLIN 500 MG 12 CAPS.',
        nameAr: 'نيوسيلين',
        activeIngredient: 'AMOXICILLIN',
        drugGroupId: 'antibiotics',
        route: 'ORAL.SOLID',
        aliases: const ['newcil'],
        createdAt: _seededAt.subtract(const Duration(days: 3)),
        updatedAt: _seededAt.subtract(const Duration(days: 3)),
      ),
      CustomCatalogItem(
        customItemId: 'ci-${_nextId++}',
        type: CatalogItemType.lab,
        nameEn: 'H. pylori antigen in stool',
        nameAr: 'جرثومة المعدة في البراز',
        aliases: const ['H pylori Ag'],
        createdAt: _seededAt.subtract(const Duration(days: 2)),
        updatedAt: _seededAt.subtract(const Duration(days: 2)),
      ),
      CustomCatalogItem(
        customItemId: 'ci-${_nextId++}',
        type: CatalogItemType.radiology,
        nameEn: 'Panoramic dental X-ray',
        nameAr: 'أشعة بانوراما على الأسنان',
        active: false,
        createdAt: _seededAt.subtract(const Duration(days: 6)),
        updatedAt: _seededAt.subtract(const Duration(days: 1)),
      ),
    ]) {
      customItems[item.customItemId] = item;
    }

    for (final report in [
      CatalogReport(
        reportId: 'cr-${_nextId++}',
        type: CatalogReportType.missing,
        text: 'مش لاقي «Ketofan 50 mg» في البحث',
        itemRef: 'search:ketofan',
        done: false,
        doctorName: 'د. أحمد سمير',
        createdAt: _seededAt.subtract(const Duration(hours: 5)),
      ),
      CatalogReport(
        reportId: 'cr-${_nextId++}',
        type: CatalogReportType.wrong,
        text: 'التركيز مكتوب 40 والعلبة 20 مجم',
        itemRef: 'drug:9',
        done: false,
        doctorName: 'د. منى عادل',
        createdAt: _seededAt.subtract(const Duration(days: 1, hours: 2)),
      ),
      CatalogReport(
        reportId: 'cr-${_nextId++}',
        type: CatalogReportType.other,
        text: 'ياريت يبقى فيه اسم عربي لتحليل فيتامين ب12',
        done: true,
        doctorName: 'د. كريم فؤاد',
        createdAt: _seededAt.subtract(const Duration(days: 4)),
        handledAt: _seededAt.subtract(const Duration(days: 3)),
      ),
    ]) {
      reports[report.reportId] = report;
    }
  }

  void _refreshCounts() {
    for (final (i, summary) in specialties.indexed) {
      final profile = profiles[summary.specialtyId];
      specialties[i] = SpecialtySummary(
        specialtyId: summary.specialtyId,
        nameAr: summary.nameAr,
        nameEn: summary.nameEn,
        active: summary.active,
        isGeneral: summary.isGeneral,
        includeGeneral: !summary.isGeneral && (profile?.includeGeneral ?? true),
        doctorCount: summary.doctorCount,
        itemCounts: {
          ProfileItemType.drugGroup: profile?.drugGroups.length ?? 0,
          ProfileItemType.route: profile?.routes.length ?? 0,
          ProfileItemType.labCode: profile?.labCodes.length ?? 0,
          ProfileItemType.radiologyRegion: profile?.radiologyRegions.length ?? 0,
          ProfileItemType.radiologyModality: profile?.radiologyModalities.length ?? 0,
          ProfileItemType.radiologyCode: profile?.radiologyCodes.length ?? 0,
        },
      );
    }
  }

  SpecialtyProfile profileOf(String specialtyId) {
    final summary = specialties.where((s) => s.specialtyId == specialtyId).firstOrNull;
    if (summary == null) throw _error(404, ApiCodes.notFound);
    return profiles[specialtyId] ??
        SpecialtyProfile(
          specialtyId: specialtyId,
          nameAr: summary.nameAr,
          nameEn: summary.nameEn,
          isGeneral: summary.isGeneral,
          includeGeneral: !summary.isGeneral,
        );
  }

  /// `myProfile`: the doctor's specialty with General (BR-CAT3).
  CatalogProfile doctorProfile() {
    final own = profileOf(doctorSpecialtyId);
    return CatalogProfile.ofSpecialty(own, general: profileOf(generalId));
  }

  static ApiException _error(
    int status,
    String code, [
    Map<String, String> fields = const {},
    Map<String, Object?> details = const {},
  ]) => ApiException(
    kind: ApiErrorKind.http,
    status: status,
    code: code,
    fieldCodes: fields,
    details: {'code': code, ...details},
  );

  static ApiException _field(String field, String code, [Map<String, Object?> details = const {}]) =>
      _error(400, ApiCodes.validationFailed, {field: code}, details);

  // ---------------------------------------------------------------------------
  // Publishing (AD20), with the API's checks in order.

  CatalogVersionInfo publish(Uint8List file, String manifest, {required bool confirmDrop, String by = 'Admin'}) {
    String? manifestSha;
    try {
      final json = jsonDecode(manifest);
      if (json is Map && json['sha256'] is String) manifestSha = (json['sha256'] as String).trim().toLowerCase();
    } on FormatException {
      manifestSha = null;
    }
    if (manifestSha == null || manifestSha.length != 64) throw _field('manifest', 'INVALID_REQUEST');
    if (crypto.sha256.convert(file).toString() != manifestSha) throw _field('file', 'CATALOG_SHA_MISMATCH');

    final info = _inspect(file);
    if (info == null) throw _field('file', 'CATALOG_FILE_INVALID');
    if (info.schema != catalogSchemaVersion) {
      throw _field('file', 'CATALOG_SCHEMA_UNSUPPORTED', {'expected': catalogSchemaVersion, 'actual': info.schema});
    }
    final previous = _current?.info;
    if (previous != null && !confirmDrop) {
      final drops = [
        for (final (table, before, after) in [
          ('drugs', previous.counts.drugs, info.counts.drugs),
          ('labs', previous.counts.labs, info.counts.labs),
          ('radiology', previous.counts.radiology, info.counts.radiology),
        ])
          if (after < before * 0.95) {'table': table, 'previous': before, 'current': after},
      ];
      if (drops.isNotEmpty) throw _error(409, 'CATALOG_COUNT_DROP', const {}, {'drops': drops});
    }
    final number = _versions.isEmpty ? 1 : _versions.map((v) => v.info.version).reduce((a, b) => a > b ? a : b) + 1;
    final version = _Version(
      CatalogVersionInfo(
        version: number,
        schemaVersion: info.schema,
        sha256: manifestSha,
        sizeBytes: file.length,
        uncompressedSizeBytes: info.uncompressedBytes,
        counts: info.counts,
        drugSourceDate: info.drugSourceDate,
        loincRelease: info.loincRelease,
        publishedAt: _now,
      ),
      file,
      publishedBy: by,
    );
    for (final v in _versions) {
      v.current = false;
    }
    _versions.insert(0, version);
    published = true;
    return version.info;
  }

  static _Inspected? _inspect(Uint8List gz) {
    final List<int> raw;
    try {
      raw = gzip.decode(gz);
    } on FormatException {
      return null;
    }
    final dir = Directory.systemTemp.createTempSync('el3yada-fake-publish');
    final path = '${dir.path}${Platform.pathSeparator}catalog.sqlite';
    try {
      File(path).writeAsBytesSync(raw);
      final schema = catalogFileSchemaVersion(path);
      if (schema == null) return null;
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        int count(String table) => db.select('SELECT COUNT(*) AS n FROM $table').first['n'] as int;
        final meta = db.select('SELECT * FROM ${MetaTable.name} LIMIT 1').first;
        return _Inspected(
          schema: schema,
          uncompressedBytes: raw.length,
          counts: CatalogCounts(
            drugs: count(DrugsTable.name),
            labs: count(LabTestsTable.name),
            radiology: count(RadiologyTable.name),
          ),
          drugSourceDate: meta[MetaTable.drugSourceDate] as String?,
          loincRelease: meta[MetaTable.loincRelease] as String?,
        );
      } finally {
        db.close();
      }
    } on SqliteException {
      return null;
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // A temp folder; the system cleans it.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Custom items (BR-CAT9) and reports

  CustomCatalogItem saveCustomItem(String? id, CustomItemDraft draft) {
    final fields = <String, String>{};
    final name = draft.nameEn.trim();
    if (name.isEmpty) fields['nameEn'] = 'REQUIRED';
    if (name.length > 200) fields['nameEn'] = 'TOO_LONG';
    if ((draft.nameAr ?? '').length > 200) fields['nameAr'] = 'TOO_LONG';
    if ((draft.loincCode ?? '').length > 20) fields['loincCode'] = 'TOO_LONG';
    if (draft.aliases.length > 10 || draft.aliases.any((a) => a.trim().length > 100)) {
      fields['aliases'] = 'INVALID_VALUE';
    }
    if (fields.isNotEmpty) throw _error(400, ApiCodes.validationFailed, fields);
    final old = id == null ? null : customItems[id];
    if (id != null && old == null) throw _error(404, ApiCodes.notFound);
    final now = _now;
    final aliases = <String>[];
    for (final alias in draft.aliases.map((a) => a.trim()).where((a) => a.isNotEmpty)) {
      if (!aliases.any((a) => a.toLowerCase() == alias.toLowerCase())) aliases.add(alias);
    }
    final drug = (old?.type ?? draft.type) == CatalogItemType.drug;
    String? clean(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
    final item = CustomCatalogItem(
      customItemId: old?.customItemId ?? 'ci-${_nextId++}',
      type: old?.type ?? draft.type,
      nameEn: name,
      nameAr: clean(draft.nameAr),
      activeIngredient: drug ? clean(draft.activeIngredient) : null,
      drugGroupId: drug ? clean(draft.drugGroupId) : null,
      route: drug ? clean(draft.route) : null,
      loincCode: drug ? null : clean(draft.loincCode),
      aliases: aliases,
      active: old == null ? true : draft.active,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    // Newest change last, like the sync's order.
    customItems.remove(item.customItemId);
    customItems[item.customItemId] = item;
    return item;
  }

  CatalogReport handleReport(String id) {
    final report = reports[id];
    if (report == null) throw _error(404, ApiCodes.notFound);
    if (report.done) return report;
    final done = CatalogReport(
      reportId: report.reportId,
      type: report.type,
      text: report.text,
      itemRef: report.itemRef,
      done: true,
      doctorName: report.doctorName,
      createdAt: report.createdAt,
      handledAt: _now,
    );
    reports[id] = done;
    return done;
  }

  SpecialtyProfile saveProfile(SpecialtyProfile profile) {
    final summary = specialties.where((s) => s.specialtyId == profile.specialtyId).firstOrNull;
    if (summary == null) throw _error(404, ApiCodes.notFound);
    List<String> sorted(List<String> values) => (values.map((v) => v.trim()).toSet().toList()..sort());
    final saved = SpecialtyProfile(
      specialtyId: profile.specialtyId,
      nameAr: summary.nameAr,
      nameEn: summary.nameEn,
      isGeneral: summary.isGeneral,
      includeGeneral: !summary.isGeneral && profile.includeGeneral,
      drugGroups: sorted(profile.drugGroups),
      routes: sorted(profile.routes),
      labCodes: sorted(profile.labCodes),
      radiologyRegions: sorted(profile.radiologyRegions),
      radiologyModalities: sorted(profile.radiologyModalities),
      radiologyCodes: sorted(profile.radiologyCodes),
      updatedAt: _now,
    );
    profiles[profile.specialtyId] = saved;
    _refreshCounts();
    return saved;
  }

  SpecialtyProfile copyProfile(String specialtyId, String fromId) {
    if (fromId == specialtyId || specialties.every((s) => s.specialtyId != fromId)) {
      throw _field('fromSpecialtyId', 'INVALID_VALUE');
    }
    final target = profileOf(specialtyId);
    final source = profileOf(fromId);
    return saveProfile(
      target.copyWith(
        includeGeneral: source.isGeneral || source.includeGeneral,
        drugGroups: source.drugGroups,
        routes: source.routes,
        labCodes: source.labCodes,
        radiologyRegions: source.radiologyRegions,
        radiologyModalities: source.radiologyModalities,
        radiologyCodes: source.radiologyCodes,
      ),
    );
  }
}

class _Inspected {
  const _Inspected({
    required this.schema,
    required this.counts,
    required this.uncompressedBytes,
    this.drugSourceDate,
    this.loincRelease,
  });

  final int schema;
  final int uncompressedBytes;
  final CatalogCounts counts;
  final String? drugSourceDate;
  final String? loincRelease;
}

class _Version {
  _Version(this.info, this.bytes, {this.publishedBy = 'Admin'});

  /// [catalog] written to a temporary file, gzipped, and described.
  factory _Version.sample(SampleCatalog catalog, {required int number, required DateTime at}) {
    final dir = Directory.systemTemp.createTempSync('el3yada-sample-catalog');
    try {
      final path = '${dir.path}${Platform.pathSeparator}catalog.sqlite';
      catalog.writeTo(path);
      final raw = File(path).readAsBytesSync();
      final gz = Uint8List.fromList(gzip.encode(raw));
      return _Version(
        CatalogVersionInfo(
          version: number,
          schemaVersion: catalog.schemaVersion,
          sha256: crypto.sha256.convert(gz).toString(),
          sizeBytes: gz.length,
          uncompressedSizeBytes: raw.length,
          counts: CatalogCounts(
            drugs: catalog.drugs.length,
            labs: catalog.labs.length,
            radiology: catalog.radiology.length,
          ),
          drugSourceDate: catalog.drugSourceDate,
          loincRelease: catalog.loincRelease,
          publishedAt: at,
        ),
        gz,
        publishedBy: 'مصطفى كامل',
      );
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // A temp folder; the system cleans it.
      }
    }
  }

  final CatalogVersionInfo info;
  final Uint8List bytes;
  final String publishedBy;
  bool current = true;
}

/// The device endpoints over [FakeCatalogBackend].
class FakeCatalogApi implements CatalogApi {
  FakeCatalogApi(this.backend);

  final FakeCatalogBackend backend;

  /// The `from` of every file request (tests check the resume).
  final fileRequests = <int>[];

  @override
  Future<CatalogVersionInfo?> current() async {
    await backend.step('current');
    return backend._current?.info;
  }

  @override
  Future<CatalogFileResponse> file(int version, {int from = 0, String? ifRange, CancelToken? cancel}) async {
    await backend.step('file');
    fileRequests.add(from);
    final match = backend._versions.where((v) => v.info.version == version).firstOrNull;
    if (match == null) throw FakeCatalogBackend._error(404, ApiCodes.notFound);
    final bytes = match.bytes;
    final start = from.clamp(0, bytes.length);
    Stream<List<int>> body() async* {
      for (var offset = start; offset < bytes.length; offset += backend.chunkSize) {
        if (cancel?.isCancelled ?? false) {
          throw const ApiException(kind: ApiErrorKind.cancelled);
        }
        if (backend.chunkDelay > Duration.zero) await Future<void>.delayed(backend.chunkDelay);
        yield bytes.sublist(offset, (offset + backend.chunkSize).clamp(0, bytes.length));
      }
    }

    return CatalogFileResponse(partial: start > 0, totalBytes: bytes.length, body: body());
  }

  @override
  Future<CustomItemSyncPage> customItems({String? since}) async {
    await backend.step('customItems');
    final after = since == null ? null : DateTime.tryParse(since);
    final changed = [
      for (final item in backend.customItems.values)
        if (after == null || (item.updatedAt?.isAfter(after) ?? false)) item,
    ]..sort((a, b) => (a.updatedAt ?? DateTime(0)).compareTo(b.updatedAt ?? DateTime(0)));
    return CustomItemSyncPage(
      items: changed,
      nextSince: changed.isEmpty ? since : changed.last.updatedAt?.toUtc().toIso8601String(),
    );
  }

  @override
  Future<CatalogProfile> myProfile() async {
    await backend.step('myProfile');
    return backend.doctorProfile();
  }
}

/// AD19 and AD20 over [FakeCatalogBackend].
class FakeAdminCatalogRepository implements AdminCatalogRepository {
  FakeAdminCatalogRepository(this.backend, {this.adminName = 'Admin'});

  final FakeCatalogBackend backend;
  final String adminName;

  /// The `confirmDrop` of the last publish (tests).
  bool? lastConfirmDrop;

  @override
  Future<List<CatalogVersionEntry>> versions() async {
    await backend.step('versions');
    return [
      for (final v in backend._versions)
        CatalogVersionEntry(version: v.info, current: backend.published && v.current, publishedByName: v.publishedBy),
    ];
  }

  @override
  Future<CatalogVersionInfo> publish({
    required PickedCatalogFile file,
    required String manifest,
    bool confirmDrop = false,
    SendProgress? onProgress,
    CancelToken? cancel,
  }) async {
    lastConfirmDrop = confirmDrop;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    // Upload in a few steps, for the progress bar.
    for (var i = 1; i <= 4; i++) {
      if (backend.chunkDelay > Duration.zero) await Future<void>.delayed(backend.chunkDelay * 3);
      onProgress?.call(bytes.length * i ~/ 4, bytes.length);
    }
    await backend.step('publish');
    return backend.publish(bytes, manifest, confirmDrop: confirmDrop, by: adminName);
  }

  @override
  Future<Paged<CustomCatalogItem>> customItems({
    CatalogItemType? type,
    bool? active,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    await backend.step('customItems');
    final query = (search ?? '').trim().toLowerCase();
    final rows = [
      for (final item in backend.customItems.values.toList().reversed)
        if ((type == null || item.type == type) &&
            (active == null || item.active == active) &&
            (query.isEmpty ||
                [
                  item.nameEn,
                  item.nameAr,
                  item.activeIngredient,
                  item.loincCode,
                ].any((text) => text?.toLowerCase().contains(query) ?? false)))
          item,
    ];
    return Paged.single(rows);
  }

  @override
  Future<CustomCatalogItem> createCustomItem(CustomItemDraft draft) async {
    await backend.step('createCustomItem');
    return backend.saveCustomItem(null, draft);
  }

  @override
  Future<CustomCatalogItem> updateCustomItem(String customItemId, CustomItemDraft draft) async {
    await backend.step('updateCustomItem');
    return backend.saveCustomItem(customItemId, draft);
  }

  @override
  Future<Paged<CatalogReport>> reports({String status = 'open', int page = 1, int pageSize = 50}) async {
    await backend.step('reports');
    final rows = backend.reports.values.where((r) => status == 'all' || (status == 'done') == r.done).toList()
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return a.createdAt.compareTo(b.createdAt);
      });
    return Paged.single(rows);
  }

  @override
  Future<CatalogReport> handleReport(String reportId) async {
    await backend.step('handleReport');
    return backend.handleReport(reportId);
  }

  @override
  Future<List<SpecialtySummary>> specialties() async {
    await backend.step('specialties');
    return List.of(backend.specialties);
  }

  @override
  Future<SpecialtyProfile> profile(String specialtyId) async {
    await backend.step('profile');
    return backend.profileOf(specialtyId);
  }

  @override
  Future<SpecialtyProfile> updateProfile(SpecialtyProfile profile) async {
    await backend.step('updateProfile');
    return backend.saveProfile(profile);
  }

  @override
  Future<SpecialtyProfile> copyProfile(String specialtyId, {required String fromSpecialtyId}) async {
    await backend.step('copyProfile');
    return backend.copyProfile(specialtyId, fromSpecialtyId);
  }
}
