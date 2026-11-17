import 'dart:typed_data';

import '../../sessions/domain/session_models.dart';

/// Medical files (spec 6.3, backend/docs/api-phase-3-files.md).

/// BR-F1: every record has exactly one category.
enum RecordCategory {
  radiology,
  lab,
  prescription,
  other;

  static RecordCategory fromWire(Object? value) =>
      RecordCategory.values.firstWhere((c) => c.name == value, orElse: () => RecordCategory.other);
}

/// [S] BR-F1: the optional type of an Other record.
enum RecordOtherType {
  report,
  referral,
  sickLeave,
  ecg,
  eegEmg,
  endoscopy,
  consent,
  custom;

  static RecordOtherType? fromWire(Object? value) {
    for (final type in values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

/// BR-F3: how the record came in.
enum RecordSource {
  scan,
  upload,
  chat;

  static RecordSource fromWire(Object? value) =>
      RecordSource.values.firstWhere((s) => s.name == value, orElse: () => RecordSource.upload);
}

/// One file in a record.
class RecordAttachment {
  const RecordAttachment({
    required this.attachmentId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.storedSizeBytes,
    this.pageCount,
    this.hasThumbnail = false,
    this.previewable = false,
  });

  factory RecordAttachment.fromJson(Map<String, dynamic> json) => RecordAttachment(
        attachmentId: json['attachmentId'] as String,
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        storedSizeBytes: (json['storedSizeBytes'] as num?)?.toInt() ?? (json['sizeBytes'] as num).toInt(),
        pageCount: (json['pageCount'] as num?)?.toInt(),
        hasThumbnail: json['hasThumbnail'] as bool? ?? false,
        previewable: json['previewable'] as bool? ?? false,
      );

  final String attachmentId;
  final String fileName;
  final String mimeType;

  /// What users download.
  final int sizeBytes;

  /// What the server keeps on disk (smaller when compressed).
  final int storedSizeBytes;
  final int? pageCount;
  final bool hasThumbnail;

  /// Images and PDFs open inside the app (D12); other types get "Open with".
  final bool previewable;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';
}

/// The visit a record is linked to.
class RecordSession {
  const RecordSession({required this.sessionId, required this.type, required this.createdAt});

  factory RecordSession.fromJson(Map<String, dynamic> json) => RecordSession(
        sessionId: json['sessionId'] as String,
        type: SessionType.fromWire(json['type']),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      );

  final String sessionId;
  final SessionType type;
  final DateTime createdAt;
}

/// "Recorded by …" (BR-AS10).
class RecordCreator {
  const RecordCreator({required this.userId, required this.isAssistant, required this.name});

  factory RecordCreator.fromJson(Map<String, dynamic> json) => RecordCreator(
        userId: json['userId'] as String,
        isAssistant: json['role'] == 'assistant',
        name: json['name'] as String? ?? '',
      );

  final String userId;
  final bool isAssistant;
  final String name;
}

/// A medical record (D12): its details and files.
class MedicalRecordView {
  MedicalRecordView({
    required this.recordId,
    required this.patientId,
    required this.category,
    required this.title,
    required this.documentDate,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.attachments,
    this.otherType,
    this.otherTypeText,
    this.notes,
    this.session,
    int? totalSizeBytes,
  }) : totalSizeBytes = totalSizeBytes ?? attachments.fold(0, (sum, a) => sum + a.sizeBytes);

  factory MedicalRecordView.fromJson(Map<String, dynamic> json) => MedicalRecordView(
        recordId: json['recordId'] as String,
        patientId: json['patientId'] as String,
        category: RecordCategory.fromWire(json['category']),
        otherType: RecordOtherType.fromWire(json['otherType']),
        otherTypeText: json['otherTypeText'] as String?,
        title: json['title'] as String,
        documentDate: parseDay(json['documentDate']),
        notes: json['notes'] as String?,
        session: json['session'] == null ? null : RecordSession.fromJson((json['session'] as Map).cast<String, dynamic>()),
        source: RecordSource.fromWire(json['source']),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
        createdBy: RecordCreator.fromJson((json['createdBy'] as Map).cast<String, dynamic>()),
        attachments: [
          for (final a in (json['attachments'] as List? ?? const []))
            RecordAttachment.fromJson((a as Map).cast<String, dynamic>()),
        ],
        totalSizeBytes: (json['totalSizeBytes'] as num?)?.toInt(),
      );

  final String recordId;
  final String patientId;
  final RecordCategory category;
  final RecordOtherType? otherType;
  final String? otherTypeText;
  final String title;

  /// The test or scan date, a Cairo day (UTC midnight).
  final DateTime documentDate;
  final String? notes;
  final RecordSession? session;
  final RecordSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RecordCreator createdBy;
  final List<RecordAttachment> attachments;

  /// What the record's files weigh for users.
  final int totalSizeBytes;

  /// The first attachment with a thumbnail, for the list.
  RecordAttachment? get cover {
    for (final a in attachments) {
      if (a.hasThumbnail) return a;
    }
    return null;
  }

  /// The form's values, for D12 "edit details".
  RecordDraft toDraft() => RecordDraft(
        category: category,
        otherType: otherType,
        otherTypeText: otherTypeText,
        title: title,
        documentDate: documentDate,
        notes: notes,
        sessionId: session?.sessionId,
      );
}

/// The category chips' counts (D6 Files tab).
class RecordCounts {
  const RecordCounts({this.radiology = 0, this.lab = 0, this.prescription = 0, this.other = 0});

  factory RecordCounts.fromJson(Map<String, dynamic> json) => RecordCounts(
        radiology: (json['radiology'] as num?)?.toInt() ?? 0,
        lab: (json['lab'] as num?)?.toInt() ?? 0,
        prescription: (json['prescription'] as num?)?.toInt() ?? 0,
        other: (json['other'] as num?)?.toInt() ?? 0,
      );

  final int radiology;
  final int lab;
  final int prescription;
  final int other;

  int get total => radiology + lab + prescription + other;

  /// The count for one chip; null is "All".
  int of(RecordCategory? category) => switch (category) {
        null => total,
        RecordCategory.radiology => radiology,
        RecordCategory.lab => lab,
        RecordCategory.prescription => prescription,
        RecordCategory.other => other,
      };
}

/// One page of a patient's records, with the counts.
class RecordPage {
  const RecordPage({required this.items, required this.totalCount, required this.counts, this.page = 1, this.pageSize = 30});

  factory RecordPage.fromJson(Map<String, dynamic> json) => RecordPage(
        items: [
          for (final r in (json['items'] as List? ?? const [])) MedicalRecordView.fromJson((r as Map).cast<String, dynamic>()),
        ],
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 30,
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        counts: RecordCounts.fromJson((json['counts'] as Map?)?.cast<String, dynamic>() ?? const {}),
      );

  final List<MedicalRecordView> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final RecordCounts counts;
}

/// The answer to `uploadFile`: a checked, optimized file waiting for
/// `createRecord` (24 hours at most).
class UploadedFile {
  const UploadedFile({
    required this.uploadId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.storedSizeBytes,
    required this.originalSizeBytes,
    this.pageCount,
    this.hasThumbnail = false,
    this.optimized = false,
  });

  factory UploadedFile.fromJson(Map<String, dynamic> json) => UploadedFile(
        uploadId: json['uploadId'] as String,
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String,
        sizeBytes: (json['sizeBytes'] as num).toInt(),
        storedSizeBytes: (json['storedSizeBytes'] as num).toInt(),
        originalSizeBytes: (json['originalSizeBytes'] as num).toInt(),
        pageCount: (json['pageCount'] as num?)?.toInt(),
        hasThumbnail: json['hasThumbnail'] as bool? ?? false,
        optimized: json['optimized'] as bool? ?? false,
      );

  final String uploadId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int storedSizeBytes;
  final int originalSizeBytes;
  final int? pageCount;
  final bool hasThumbnail;
  final bool optimized;
}

/// A file about to be uploaded: from the picker, the camera, a drop, or a
/// scan. Files on disk stream from [path]; scans and compressed images are
/// in [bytes].
class UploadSource {
  const UploadSource({
    required this.name,
    required this.sizeBytes,
    this.path,
    this.bytes,
    this.mimeType,
    this.thumbnail,
    this.pageCount,
  }) : assert(path != null || bytes != null);

  final String name;
  final int sizeBytes;
  final String? path;
  final Uint8List? bytes;

  /// The type the picker reported, if any; the server reads JPEG, PNG,
  /// WebP and PDF from the bytes.
  final String? mimeType;

  /// A first-page image, for a PDF (the server doesn't render PDFs).
  final Uint8List? thumbnail;

  /// Pages of a scan PDF.
  final int? pageCount;

  UploadSource copyWith({String? name, Uint8List? bytes, int? sizeBytes, String? mimeType, Uint8List? thumbnail}) =>
      UploadSource(
        name: name ?? this.name,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        path: bytes != null ? null : path,
        bytes: bytes ?? this.bytes,
        mimeType: mimeType ?? this.mimeType,
        thumbnail: thumbnail ?? this.thumbnail,
        pageCount: pageCount,
      );

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  bool get isImage => const {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'}.contains(extension) ||
      (mimeType?.startsWith('image/') ?? false);

  bool get isPdf => extension == 'pdf' || mimeType == 'application/pdf';
}

/// The BR-F3 fields: createRecord (with the uploads) and updateRecord (all
/// replaced).
class RecordDraft {
  const RecordDraft({
    required this.category,
    required this.documentDate,
    this.otherType,
    this.otherTypeText,
    this.title,
    this.notes,
    this.sessionId,
  });

  final RecordCategory category;
  final RecordOtherType? otherType;
  final String? otherTypeText;

  /// Empty: the server names it after the category and the date.
  final String? title;
  final DateTime documentDate;
  final String? notes;
  final String? sessionId;

  Map<String, Object?> toJson() {
    String? clean(String? value) => value == null || value.trim().isEmpty ? null : value.trim();
    final other = category == RecordCategory.other ? otherType : null;
    return {
      'category': category.name,
      'otherType': other?.name,
      'otherTypeText': other == RecordOtherType.custom ? clean(otherTypeText) : null,
      'title': clean(title),
      'documentDate': dayKey(documentDate),
      'notes': clean(notes),
      'sessionId': sessionId,
    };
  }
}

/// The record list's filter: one category, or all.
typedef RecordFilter = ({String patientId, RecordCategory? category});
