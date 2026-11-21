import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/record_models.dart';
import 'fake_records_repository.dart';

/// Upload progress: bytes sent of the total.
typedef ProgressCallback = void Function(int sent, int total);

/// Medical files (backend/docs/api-phase-3-files.md). Every method throws
/// [ApiException].
abstract interface class RecordsRepository {
  /// D10/D11 step 1: one file, checked and optimized by the server, kept 24
  /// hours for [createRecord].
  Future<UploadedFile> uploadFile(UploadSource file, {ProgressCallback? onProgress, CancelToken? cancel});

  /// D10/D11 step 2: the record, with the uploads as its files in this order.
  Future<MedicalRecordView> createRecord(
    String patientId,
    RecordDraft draft, {
    required RecordSource source,
    required List<String> uploadIds,
  });

  /// D6 Files tab and AS6: newest first, with the category counts.
  Future<RecordPage> records(String patientId, {RecordCategory? category, int page = 1, int pageSize = 25});

  /// D12.
  Future<MedicalRecordView> record(String recordId);

  /// D12 "edit details": every field replaced.
  Future<MedicalRecordView> updateRecord(String recordId, RecordDraft draft);

  /// D12 Delete (doctor only): soft.
  Future<void> deleteRecord(String recordId);

  /// The original bytes of one file.
  Future<Uint8List> download(String recordId, String attachmentId, {ProgressCallback? onProgress});

  /// The list's small JPEG, or null when there is none.
  Future<Uint8List?> thumbnail(String recordId, String attachmentId);
}

class ApiRecordsRepository implements RecordsRepository {
  ApiRecordsRepository(this._dio);

  final Dio _dio;

  @override
  Future<UploadedFile> uploadFile(UploadSource file, {ProgressCallback? onProgress, CancelToken? cancel}) =>
      _call(() async {
        final form = FormData.fromMap({
          'file': file.bytes != null
              ? MultipartFile.fromBytes(file.bytes!, filename: file.name, contentType: _type(file.mimeType))
              : await MultipartFile.fromFile(file.path!, filename: file.name, contentType: _type(file.mimeType)),
          if (file.thumbnail != null)
            'thumbnail': MultipartFile.fromBytes(file.thumbnail!, filename: 'thumbnail.jpg', contentType: DioMediaType('image', 'jpeg')),
          if (file.pageCount != null) 'pageCount': '${file.pageCount}',
        });
        final response = await _dio.post<Map<String, dynamic>>(
          '/records/uploadFile',
          data: form,
          onSendProgress: onProgress,
          cancelToken: cancel,
          // A big file on a slow line takes longer than the usual timeouts.
          options: Options(sendTimeout: const Duration(minutes: 30), receiveTimeout: const Duration(minutes: 5)),
        );
        return UploadedFile.fromJson(response.data ?? const {});
      });

  @override
  Future<MedicalRecordView> createRecord(
    String patientId,
    RecordDraft draft, {
    required RecordSource source,
    required List<String> uploadIds,
  }) =>
      _call(() async => MedicalRecordView.fromJson(await _post('/records/createRecord', {
            'patientId': patientId,
            ...draft.toJson(),
            'source': source.name,
            'uploadIds': uploadIds,
          })));

  @override
  Future<RecordPage> records(String patientId, {RecordCategory? category, int page = 1, int pageSize = 25}) =>
      _call(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/patients/$patientId/records',
          queryParameters: {'category': ?category?.name, 'page': page, 'pageSize': pageSize},
        );
        return RecordPage.fromJson(response.data ?? const {});
      });

  @override
  Future<MedicalRecordView> record(String recordId) => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>('/records/$recordId');
        return MedicalRecordView.fromJson(response.data ?? const {});
      });

  @override
  Future<MedicalRecordView> updateRecord(String recordId, RecordDraft draft) => _call(
      () async => MedicalRecordView.fromJson(await _post('/records/updateRecord', {'recordId': recordId, ...draft.toJson()})));

  @override
  Future<void> deleteRecord(String recordId) => _call(() => _dio.post<void>('/records/deleteRecord', data: {'recordId': recordId}));

  @override
  Future<Uint8List> download(String recordId, String attachmentId, {ProgressCallback? onProgress}) => _call(() async {
        final response = await _dio.get<List<int>>(
          '/records/$recordId/attachments/$attachmentId',
          queryParameters: {'download': true},
          onReceiveProgress: onProgress,
          options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 10)),
        );
        final data = response.data ?? const <int>[];
        return data is Uint8List ? data : Uint8List.fromList(data);
      });

  @override
  Future<Uint8List?> thumbnail(String recordId, String attachmentId) async {
    try {
      final response = await _dio.get<List<int>>(
        '/records/$recordId/attachments/$attachmentId/thumbnail',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null || data.isEmpty) return null;
      return data is Uint8List ? data : Uint8List.fromList(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  static DioMediaType? _type(String? mimeType) {
    if (mimeType == null) return null;
    final parts = mimeType.split('/');
    return parts.length == 2 ? DioMediaType(parts[0], parts[1]) : null;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: body);
    return response.data ?? const {};
  }

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// The real API, or the offline records when `USE_FAKE_AUTH` is on (dev
/// builds and tests).
final recordsRepositoryProvider = Provider<RecordsRepository>((ref) {
  if (Env.useFakeAuth) return ref.watch(fakeRecordsRepositoryProvider);
  return ApiRecordsRepository(ref.watch(dioProvider));
});
