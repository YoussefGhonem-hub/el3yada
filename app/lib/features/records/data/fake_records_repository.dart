import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;

import '../../../core/network/api_exception.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/data/fake_clinic_records.dart';
import '../../sessions/domain/session_models.dart';
import '../domain/record_models.dart';
import 'records_repository.dart';

/// The offline medical files for `config/dev-offline.json` and the tests,
/// with the API's rules (backend/docs/api-phase-3-files.md): `filesManage`,
/// delete for the doctor only, blocked while suspended, the size limit, and
/// uploads waiting for createRecord.
class FakeRecordsRepository implements RecordsRepository {
  FakeRecordsRepository({
    required this.caller,
    required this.clinic,
    this.delay = const Duration(milliseconds: 250),
    DateTime Function()? now,
    this.maxUploadMb = 50,
    this.seed = true,
  }) : _now = now ?? DateTime.now;

  /// The signed-in doctor or assistant, or null.
  final FakeCaller? Function() caller;

  /// The offline patients and sessions.
  final FakeClinicRecords clinic;
  final Duration delay;
  final DateTime Function() _now;

  /// The admin's per-file limit (AppSettings.MaxUploadMb).
  int maxUploadMb;

  /// Seeds a few records for the seeded patients the first time they're read.
  final bool seed;

  /// The next uploads fail with a network error (tests try Retry).
  int failNextUploads = 0;

  /// The server "optimizes" images to this share of their size, like the
  /// API's resize and JPEG (tests read the saving message).
  double imageShrink = 1;

  final _records = <String, _Record>{};
  final _uploads = <String, _Upload>{};
  final _seeded = <String>{};
  int _nextId = 1;

  /// Every upload's name, in order (tests).
  final uploadedNames = <String>[];

  // ---------------------------------------------------------------------------

  @override
  Future<UploadedFile> uploadFile(UploadSource file, {ProgressCallback? onProgress, CancelToken? cancel}) async {
    final who = _require();
    _blockWhileSuspended(who);
    final bytes = file.bytes ?? Uint8List(file.sizeBytes);
    final total = bytes.length;
    for (var step = 1; step <= 4; step++) {
      await _wait(quarter: true);
      if (cancel?.isCancelled ?? false) throw const ApiException(kind: ApiErrorKind.cancelled);
      onProgress?.call(total * step ~/ 4, total);
    }
    if (failNextUploads > 0) {
      failNextUploads--;
      throw const ApiException(kind: ApiErrorKind.network);
    }
    if (total == 0) _invalid({'file': 'REQUIRED'});
    if (total > maxUploadMb * 1024 * 1024) {
      throw ApiException(
        kind: ApiErrorKind.http,
        status: 400,
        code: ApiCodes.validationFailed,
        fieldCodes: const {'file': 'FILE_TOO_LARGE'},
        details: {'maxMb': maxUploadMb},
      );
    }
    final id = 'dev-upload-${_nextId++}';
    final mime = file.isPdf ? 'application/pdf' : (file.isImage ? 'image/jpeg' : (file.mimeType ?? 'application/octet-stream'));
    final size = file.isImage ? (total * imageShrink).round().clamp(1, total) : total;
    _uploads[id] = _Upload(
      id: id,
      name: file.name,
      mimeType: mime,
      bytes: bytes,
      sizeBytes: size,
      pageCount: file.isPdf ? file.pageCount : null,
      thumbnail: file.isImage ? _thumbnailOf(bytes) : file.thumbnail,
    );
    uploadedNames.add(file.name);
    return UploadedFile(
      uploadId: id,
      fileName: file.name,
      mimeType: mime,
      sizeBytes: size,
      storedSizeBytes: size,
      originalSizeBytes: total,
      pageCount: _uploads[id]!.pageCount,
      hasThumbnail: _uploads[id]!.thumbnail != null,
      optimized: size < total,
    );
  }

  @override
  Future<MedicalRecordView> createRecord(
    String patientId,
    RecordDraft draft, {
    required RecordSource source,
    required List<String> uploadIds,
  }) async {
    await _wait();
    final who = _require();
    _blockWhileSuspended(who);
    if (!clinic.hasPatient(patientId)) _notFound();
    _checkDraft(patientId, draft);
    if (uploadIds.isEmpty) _invalid({'uploadIds': 'REQUIRED'});
    if (uploadIds.length > 20) _invalid({'uploadIds': 'TOO_MANY'});
    for (final id in uploadIds) {
      if (!_uploads.containsKey(id)) {
        throw ApiException(
          kind: ApiErrorKind.http,
          status: 400,
          code: ApiCodes.validationFailed,
          fieldCodes: const {'uploadIds': 'UPLOAD_NOT_FOUND'},
          details: {'uploadId': id},
        );
      }
    }
    final now = _now().toUtc();
    final record = _Record(
      id: 'dev-record-${_nextId++}',
      patientId: patientId,
      source: source,
      createdAt: now,
      createdBy: who.userId,
      createdByAssistant: !who.isDoctor,
      creatorName: who.name,
      files: [for (final id in uploadIds) _uploads.remove(id)!],
    )..apply(draft);
    _records[record.id] = record;
    return _view(record);
  }

  @override
  Future<RecordPage> records(String patientId, {RecordCategory? category, int page = 1, int pageSize = 25}) async {
    await _wait();
    _require();
    if (!clinic.hasPatient(patientId)) _notFound();
    await _seedFor(patientId);
    final all = _records.values.where((r) => r.patientId == patientId && !r.deleted).toList()
      ..sort((a, b) {
        final byDate = b.documentDate.compareTo(a.documentDate);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
    final shown = category == null ? all : all.where((r) => r.category == category).toList();
    int count(RecordCategory c) => all.where((r) => r.category == c).length;
    return RecordPage(
      items: [for (final r in shown.skip((page - 1) * pageSize).take(pageSize)) _view(r)],
      page: page,
      pageSize: pageSize,
      totalCount: shown.length,
      counts: RecordCounts(
        radiology: count(RecordCategory.radiology),
        lab: count(RecordCategory.lab),
        prescription: count(RecordCategory.prescription),
        other: count(RecordCategory.other),
      ),
    );
  }

  @override
  Future<MedicalRecordView> record(String recordId) async {
    await _wait();
    _require();
    return _view(_recordOf(recordId));
  }

  @override
  Future<MedicalRecordView> updateRecord(String recordId, RecordDraft draft) async {
    await _wait();
    final who = _require();
    _blockWhileSuspended(who);
    final record = _recordOf(recordId);
    _checkDraft(record.patientId, draft);
    record.apply(draft);
    return _view(record);
  }

  @override
  Future<void> deleteRecord(String recordId) async {
    await _wait();
    final who = _require();
    if (!who.isDoctor) {
      throw const ApiException(
        kind: ApiErrorKind.http,
        status: 403,
        code: ApiCodes.permissionDenied,
        details: {'permission': 'doctorOnly'},
      );
    }
    _blockWhileSuspended(who);
    _recordOf(recordId).deleted = true;
  }

  @override
  Future<Uint8List> download(String recordId, String attachmentId, {ProgressCallback? onProgress}) async {
    await _wait();
    _require();
    final file = _fileOf(recordId, attachmentId);
    onProgress?.call(file.bytes.length, file.bytes.length);
    return file.bytes;
  }

  @override
  Future<Uint8List?> thumbnail(String recordId, String attachmentId) async {
    await _wait();
    _require();
    return _fileOf(recordId, attachmentId).thumbnail;
  }

  // ---------------------------------------------------------------------------

  /// A record by ID (tests).
  MedicalRecordView? recordById(String recordId) {
    final record = _records[recordId];
    return record == null || record.deleted ? null : _view(record);
  }

  /// A patient's live records, newest first (tests).
  List<MedicalRecordView> recordsOf(String patientId) => [
        for (final r in _records.values.where((r) => r.patientId == patientId && !r.deleted)) _view(r),
      ];

  MedicalRecordView _view(_Record r) {
    final session = r.sessionId == null ? null : clinic.sessionInfo(r.sessionId!);
    return MedicalRecordView(
      recordId: r.id,
      patientId: r.patientId,
      category: r.category,
      otherType: r.otherType,
      otherTypeText: r.otherTypeText,
      title: r.title,
      documentDate: r.documentDate,
      notes: r.notes,
      session: session == null ? null : RecordSession(sessionId: r.sessionId!, type: session.type, createdAt: session.at),
      source: r.source,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      createdBy: RecordCreator(userId: r.createdBy, isAssistant: r.createdByAssistant, name: r.creatorName),
      attachments: [
        for (final f in r.files)
          RecordAttachment(
            attachmentId: f.id,
            fileName: f.name,
            mimeType: f.mimeType,
            sizeBytes: f.sizeBytes,
            storedSizeBytes: f.sizeBytes,
            pageCount: f.pageCount,
            hasThumbnail: f.thumbnail != null,
            previewable: f.mimeType.startsWith('image/') || f.mimeType == 'application/pdf',
          ),
      ],
    );
  }

  void _checkDraft(String patientId, RecordDraft draft) {
    final fields = <String, String>{};
    if (draft.otherType != null && draft.category != RecordCategory.other) fields['otherType'] = 'INVALID_VALUE';
    if (draft.category == RecordCategory.other &&
        draft.otherType == RecordOtherType.custom &&
        (draft.otherTypeText?.trim().isEmpty ?? true)) {
      fields['otherTypeText'] = 'REQUIRED';
    }
    final cairoToday = _cairoToday();
    if (draft.documentDate.isAfter(cairoToday)) fields['documentDate'] = 'INVALID_DATE';
    if ((draft.title?.length ?? 0) > 120) fields['title'] = 'TOO_LONG';
    if ((draft.notes?.length ?? 0) > 1000) fields['notes'] = 'TOO_LONG';
    if (draft.sessionId != null && !clinic.hasSession(patientId, draft.sessionId!)) fields['sessionId'] = 'INVALID_SESSION';
    if (fields.isNotEmpty) _invalid(fields);
  }

  DateTime _cairoToday() {
    final cairo = _now().toUtc().add(const Duration(hours: 2));
    return DateTime.utc(cairo.year, cairo.month, cairo.day);
  }

  _Record _recordOf(String recordId) {
    final record = _records[recordId];
    if (record == null || record.deleted) _notFound();
    return record;
  }

  _Upload _fileOf(String recordId, String attachmentId) {
    for (final f in _recordOf(recordId).files) {
      if (f.id == attachmentId) return f;
    }
    _notFound();
  }

  FakeCaller _require() {
    final who = caller();
    if (who == null) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.forbidden);
    if (who.trialEnded) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.trialEnded);
    if (!who.can(ClinicPermission.filesManage)) {
      throw const ApiException(
        kind: ApiErrorKind.http,
        status: 403,
        code: ApiCodes.permissionDenied,
        details: {'permission': ClinicPermission.filesManage},
      );
    }
    return who;
  }

  void _blockWhileSuspended(FakeCaller who) {
    if (who.suspended) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.doctorSuspended);
  }

  Never _notFound() => throw const ApiException(kind: ApiErrorKind.http, status: 404, code: ApiCodes.notFound);

  Never _invalid(Map<String, String> fields) =>
      throw ApiException(kind: ApiErrorKind.http, status: 400, code: ApiCodes.validationFailed, fieldCodes: fields);

  Future<void> _wait({bool quarter = false}) =>
      delay == Duration.zero ? Future<void>.value() : Future<void>.delayed(quarter ? delay ~/ 4 : delay);

  /// A small JPEG of an image, like the server's 320 px thumbnail.
  static Uint8List? _thumbnailOf(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return null;
      final small = image.width >= image.height ? img.copyResize(image, width: 320) : img.copyResize(image, height: 320);
      return img.encodeJpg(small, quality: 70);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Seed: a few records for the seeded patients.

  Future<void> _seedFor(String patientId) async {
    if (!seed || !_seeded.add(patientId)) return;
    String? idOf(String name) {
      try {
        return clinic.patientIdByName(name);
      } catch (_) {
        return null;
      }
    }

    final today = _cairoToday();
    if (patientId == idOf('منى حسن إبراهيم')) {
      final sessions = clinic.sessionIdsOf(patientId);
      _add(
        patientId,
        RecordDraft(
          category: RecordCategory.lab,
          title: 'صورة دم كاملة',
          documentDate: today.subtract(const Duration(days: 5)),
          sessionId: sessions.length > 1 ? sessions[1] : null,
        ),
        [await _pdf('CBC', pages: 2)],
        source: RecordSource.scan,
      );
      _add(
        patientId,
        RecordDraft(
          category: RecordCategory.radiology,
          title: 'أشعة على الجيوب الأنفية',
          documentDate: today.subtract(const Duration(days: 12)),
          notes: 'قبل بدء العلاج',
        ),
        [_image('sinus-xray.jpg', 0xFF37474F), await _pdf('report')],
        source: RecordSource.upload,
      );
      _add(
        patientId,
        RecordDraft(category: RecordCategory.other, otherType: RecordOtherType.sickLeave, documentDate: today),
        [_image('sick-leave.jpg', 0xFFE0E0E0)],
        source: RecordSource.scan,
        byAssistant: true,
      );
    } else if (patientId == idOf('أحمد محمود عبد الرحمن')) {
      _add(
        patientId,
        RecordDraft(category: RecordCategory.lab, title: 'سكر تراكمي', documentDate: today.subtract(const Duration(days: 20))),
        [_image('hba1c.jpg', 0xFFFFFFFF)],
        source: RecordSource.upload,
      );
    }
  }

  void _add(String patientId, RecordDraft draft, List<_Upload> files, {required RecordSource source, bool byAssistant = false}) {
    final reception = FakeClinicRecords.receptionAssistant;
    final record = _Record(
      id: 'dev-record-${_nextId++}',
      patientId: patientId,
      source: source,
      createdAt: draft.documentDate.add(const Duration(hours: 9)),
      createdBy: byAssistant ? reception.userId : FakeClinicRecords.doctorUserId,
      createdByAssistant: byAssistant,
      creatorName: byAssistant ? reception.name : FakeClinicRecords.doctorName,
      files: files,
    )..apply(draft);
    _records[record.id] = record;
  }

  _Upload _image(String name, int argb) {
    final image = img.Image(width: 900, height: 1200);
    img.fill(image, color: img.ColorRgb8((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF));
    final bytes = img.encodeJpg(image, quality: 60);
    return _Upload(
      id: 'dev-file-${_nextId++}',
      name: name,
      mimeType: 'image/jpeg',
      bytes: bytes,
      sizeBytes: bytes.length,
      thumbnail: _thumbnailOf(bytes),
    );
  }

  Future<_Upload> _pdf(String title, {int pages = 1}) async {
    final document = pw.Document();
    for (var i = 1; i <= pages; i++) {
      document.addPage(pw.Page(build: (context) => pw.Center(child: pw.Text('$title — $i / $pages'))));
    }
    final bytes = await document.save();
    final cover = img.Image(width: 240, height: 340);
    img.fill(cover, color: img.ColorRgb8(255, 255, 255));
    return _Upload(
      id: 'dev-file-${_nextId++}',
      name: '$title.pdf',
      mimeType: 'application/pdf',
      bytes: bytes,
      sizeBytes: bytes.length,
      pageCount: pages,
      thumbnail: img.encodeJpg(cover, quality: 60),
    );
  }
}

class _Upload {
  _Upload({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.bytes,
    required this.sizeBytes,
    this.pageCount,
    this.thumbnail,
  });

  final String id;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final int sizeBytes;
  final int? pageCount;
  final Uint8List? thumbnail;
}

class _Record {
  _Record({
    required this.id,
    required this.patientId,
    required this.source,
    required this.createdAt,
    required this.createdBy,
    required this.createdByAssistant,
    required this.creatorName,
    required this.files,
  }) : updatedAt = createdAt;

  final String id;
  final String patientId;
  final RecordSource source;
  final DateTime createdAt;
  DateTime updatedAt;
  final String createdBy;
  final bool createdByAssistant;
  final String creatorName;
  final List<_Upload> files;

  RecordCategory category = RecordCategory.other;
  RecordOtherType? otherType;
  String? otherTypeText;
  String title = '';
  DateTime documentDate = DateTime.utc(2026);
  String? notes;
  String? sessionId;
  bool deleted = false;

  void apply(RecordDraft draft) {
    final json = draft.toJson();
    category = draft.category;
    otherType = category == RecordCategory.other ? draft.otherType : null;
    otherTypeText = json['otherTypeText'] as String?;
    documentDate = draft.documentDate;
    notes = json['notes'] as String?;
    sessionId = draft.sessionId;
    title = (json['title'] as String?) ?? _defaultTitle();
    updatedAt = DateTime.now().toUtc();
  }

  String _defaultTitle() {
    final name = otherTypeText ??
        switch (otherType) {
          RecordOtherType.report => 'تقرير طبي',
          RecordOtherType.referral => 'تحويل',
          RecordOtherType.sickLeave => 'إجازة مرضية',
          RecordOtherType.ecg => 'رسم قلب',
          RecordOtherType.eegEmg => 'رسم مخ / أعصاب',
          RecordOtherType.endoscopy => 'منظار',
          RecordOtherType.consent => 'إقرار',
          _ => null,
        } ??
        switch (category) {
          RecordCategory.radiology => 'أشعة',
          RecordCategory.lab => 'تحاليل',
          RecordCategory.prescription => 'روشتة',
          RecordCategory.other => 'ملف',
        };
    return '$name ${dayKey(documentDate)}';
  }
}

/// The offline records, sharing the offline clinic's patients and sessions.
final fakeRecordsRepositoryProvider = Provider<FakeRecordsRepository>(
  (ref) => FakeRecordsRepository(caller: () => fakeCallerOf(ref), clinic: ref.watch(fakeClinicRecordsProvider)),
);
