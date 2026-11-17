import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../data/file_prep.dart';
import '../data/records_repository.dart';
import '../domain/record_models.dart';

/// Where a file is in D10/D11.
enum UploadStatus {
  /// Being made smaller (images) or given a thumbnail (PDFs).
  preparing,
  uploading,
  done,
  failed,

  /// Over the admin's limit: never sent (spec section 11).
  tooLarge,
}

/// One file in the upload list: its own progress bar and Retry (AC-14).
class UploadItem {
  const UploadItem({
    required this.key,
    required this.source,
    required this.pickedBytes,
    this.status = UploadStatus.preparing,
    this.progress = 0,
    this.result,
    this.error,
  });

  final int key;
  final UploadSource source;

  /// The size the user picked, before any optimization (for «تم تقليل
  /// الحجم من … إلى …»).
  final int pickedBytes;
  final UploadStatus status;

  /// 0–1 while uploading.
  final double progress;
  final UploadedFile? result;
  final Object? error;

  String get name => result?.fileName ?? source.name;

  /// The size the server keeps for users, when it's smaller than what was
  /// picked by 5% or more.
  int? get savedTo {
    final size = result?.sizeBytes;
    if (size == null) return null;
    return size < pickedBytes * 0.95 ? size : null;
  }

  UploadItem copyWith({
    UploadSource? source,
    UploadStatus? status,
    double? progress,
    UploadedFile? Function()? result,
    Object? Function()? error,
  }) =>
      UploadItem(
        key: key,
        source: source ?? this.source,
        pickedBytes: pickedBytes,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        result: result == null ? this.result : result(),
        error: error == null ? this.error : error(),
      );
}

class UploadState {
  const UploadState({this.items = const []});

  final List<UploadItem> items;

  bool get isEmpty => items.isEmpty;

  /// Every file is uploaded: the record can be saved.
  bool get ready => items.isNotEmpty && items.every((i) => i.status == UploadStatus.done);

  bool get busy => items.any((i) => i.status == UploadStatus.preparing || i.status == UploadStatus.uploading);

  List<String> get uploadIds => [for (final i in items) ?i.result?.uploadId];
}

/// D10/D11 for one screen: each file is optimized, then uploaded on its
/// own as soon as it's added (`uploadFile`), so the doctor fills in the
/// details meanwhile; [save] then claims the uploads (`createRecord`).
final uploadControllerProvider = NotifierProvider.autoDispose<UploadController, UploadState>(UploadController.new);

class UploadController extends Notifier<UploadState> {
  int _nextKey = 1;
  final _cancels = <int, CancelToken>{};

  @override
  UploadState build() {
    ref.onDispose(() {
      for (final token in _cancels.values) {
        token.cancel();
      }
    });
    return const UploadState();
  }

  /// Adds files and starts each one. [maxBytes] is the admin's limit
  /// (`maxUploadMb`): bigger files are marked and never sent.
  void add(List<UploadSource> files, {required int maxBytes}) {
    final added = [
      for (final file in files) UploadItem(key: _nextKey++, source: file, pickedBytes: file.sizeBytes),
    ];
    state = UploadState(items: [...state.items, ...added]);
    for (final item in added) {
      unawaited(_run(item.key, maxBytes: maxBytes));
    }
  }

  /// Sends a failed file again (from the start).
  void retry(int key, {required int maxBytes}) {
    final item = _item(key);
    if (item == null || item.status != UploadStatus.failed) return;
    _update(key, (i) => i.copyWith(status: UploadStatus.preparing, progress: 0, error: () => null, result: () => null));
    unawaited(_run(key, maxBytes: maxBytes, prepared: true));
  }

  void remove(int key) {
    _cancels.remove(key)?.cancel();
    state = UploadState(items: [for (final i in state.items) if (i.key != key) i]);
  }

  /// D10/D11 Save: the record with every uploaded file, in the list's order.
  /// When the server no longer has an upload (it expired), that file is
  /// marked failed for Retry and the error is rethrown.
  Future<MedicalRecordView> save(String patientId, RecordDraft draft, {required RecordSource source}) async {
    try {
      return await ref.read(recordsRepositoryProvider).createRecord(
            patientId,
            draft,
            source: source,
            uploadIds: state.uploadIds,
          );
    } on ApiException catch (error) {
      if (error.fieldCodes['uploadIds'] == 'UPLOAD_NOT_FOUND') {
        final expired = error.details['uploadId'];
        for (final item in state.items) {
          if (expired == null || item.result?.uploadId == expired) {
            _update(item.key, (i) => i.copyWith(status: UploadStatus.failed, result: () => null, error: () => error));
          }
        }
      }
      rethrow;
    }
  }

  Future<void> _run(int key, {required int maxBytes, bool prepared = false}) async {
    var item = _item(key);
    if (item == null) return;
    try {
      if (!prepared) {
        final source = await ref.read(uploadPrepProvider).prepare(item.source);
        if (!ref.mounted || _item(key) == null) return;
        _update(key, (i) => i.copyWith(source: source));
        item = _item(key)!;
      }
      if (item.source.sizeBytes > maxBytes) {
        _update(key, (i) => i.copyWith(status: UploadStatus.tooLarge));
        return;
      }
      _update(key, (i) => i.copyWith(status: UploadStatus.uploading, progress: 0));
      final cancel = _cancels[key] = CancelToken();
      final result = await ref.read(recordsRepositoryProvider).uploadFile(
            item.source,
            cancel: cancel,
            onProgress: (sent, total) {
              if (!ref.mounted || total <= 0) return;
              _update(key, (i) => i.copyWith(progress: (sent / total).clamp(0.0, 1.0)));
            },
          );
      _cancels.remove(key);
      if (!ref.mounted) return;
      _update(key, (i) => i.copyWith(status: UploadStatus.done, progress: 1, result: () => result));
    } on ApiException catch (error) {
      _cancels.remove(key);
      if (!ref.mounted || error.kind == ApiErrorKind.cancelled) return;
      final tooLarge = error.fieldCodes['file'] == 'FILE_TOO_LARGE';
      _update(key, (i) => i.copyWith(status: tooLarge ? UploadStatus.tooLarge : UploadStatus.failed, error: () => error));
    } catch (error) {
      _cancels.remove(key);
      if (!ref.mounted) return;
      _update(key, (i) => i.copyWith(status: UploadStatus.failed, error: () => error));
    }
  }

  UploadItem? _item(int key) {
    for (final i in state.items) {
      if (i.key == key) return i;
    }
    return null;
  }

  void _update(int key, UploadItem Function(UploadItem item) change) {
    state = UploadState(items: [for (final i in state.items) i.key == key ? change(i) : i]);
  }
}
