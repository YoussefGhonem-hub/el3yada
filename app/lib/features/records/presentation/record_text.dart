import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../domain/record_models.dart';

/// Labels for the medical files screens (D6 Files tab, D10–D12).
extension RecordText on AppLocalizations {
  String recordCategoryName(RecordCategory? category) => switch (category) {
        null => recordCategoryAll,
        RecordCategory.radiology => recordCategoryRadiology,
        RecordCategory.lab => recordCategoryLab,
        RecordCategory.prescription => recordCategoryPrescription,
        RecordCategory.other => recordCategoryOther,
      };

  String recordOtherTypeName(RecordOtherType type) => switch (type) {
        RecordOtherType.report => recordOtherReport,
        RecordOtherType.referral => recordOtherReferral,
        RecordOtherType.sickLeave => recordOtherSickLeave,
        RecordOtherType.ecg => recordOtherEcg,
        RecordOtherType.eegEmg => recordOtherEegEmg,
        RecordOtherType.endoscopy => recordOtherEndoscopy,
        RecordOtherType.consent => recordOtherConsent,
        RecordOtherType.custom => recordOtherCustom,
      };

  /// The label on an Other record: its type, or the typed text.
  String? recordTypeLabel(MedicalRecordView record) {
    if (record.category != RecordCategory.other) return null;
    if (record.otherType == RecordOtherType.custom) return record.otherTypeText;
    return record.otherType == null ? null : recordOtherTypeName(record.otherType!);
  }

  String recordSourceName(RecordSource source) => switch (source) {
        RecordSource.scan => recordSourceScan,
        RecordSource.upload => recordSourceUpload,
        RecordSource.chat => recordSourceChat,
      };

  /// «610 ك.ب», «4.2 ميجا» / "610 KB", "4.2 MB" (Western digits, like
  /// the amounts in AppFormat).
  String fileSize(int bytes) {
    if (bytes < 1024) return sizeBytes('$bytes');
    if (bytes < 1024 * 1024) return sizeKb(NumberFormat('#,##0', 'en').format(bytes / 1024));
    return sizeMb(NumberFormat('#,##0.#', 'en').format(bytes / (1024 * 1024)));
  }

  /// A record call's error as one message, with the files-specific codes.
  String recordError(Object error, {int? maxMb}) {
    if (error is ApiException) {
      final codes = {...error.fieldCodes.values, ?error.code};
      if (codes.contains('FILE_TOO_LARGE')) {
        final limit = (error.details['maxMb'] as num?)?.toInt() ?? maxMb;
        return limit == null ? regErrorFileTooLarge : recordTooLarge(limit);
      }
      if (codes.contains('UPLOAD_NOT_FOUND')) return recordUploadExpired;
      if (codes.contains('INVALID_SESSION')) return recordErrorInvalidSession;
      if (codes.contains('INVALID_DATE')) return recordErrorInvalidDate;
      if (codes.contains('TOO_MANY')) return recordErrorTooMany;
    }
    return apiError(error);
  }
}

/// The icon for a file type.
IconData fileIcon(String mimeType, {String? fileName}) {
  final name = (fileName ?? '').toLowerCase();
  if (mimeType.startsWith('image/')) return Icons.image_outlined;
  if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mimeType.startsWith('video/')) return Icons.movie_outlined;
  if (mimeType.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mimeType.contains('zip') || name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.7z')) {
    return Icons.folder_zip_outlined;
  }
  if (mimeType.contains('word') || name.endsWith('.doc') || name.endsWith('.docx')) return Icons.description_outlined;
  if (mimeType.contains('sheet') || mimeType.contains('excel') || name.endsWith('.csv')) return Icons.table_chart_outlined;
  if (mimeType.contains('dicom') || name.endsWith('.dcm')) return Icons.monitor_heart_outlined;
  return Icons.insert_drive_file_outlined;
}

/// The icon for a category.
IconData recordCategoryIcon(RecordCategory category) => switch (category) {
      RecordCategory.radiology => Icons.radio_button_checked_outlined,
      RecordCategory.lab => Icons.biotech_outlined,
      RecordCategory.prescription => Icons.receipt_long_outlined,
      RecordCategory.other => Icons.description_outlined,
    };
