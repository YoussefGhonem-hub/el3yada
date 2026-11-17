import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/catalog_models.dart';

/// The answer of `GET /api/catalog/file/{n}`: the bytes from where the
/// download resumes, or the whole file when the server ignored the range.
class CatalogFileResponse {
  const CatalogFileResponse({required this.partial, required this.body, this.totalBytes});

  /// 206: [body] starts at the requested byte. 200: at byte 0.
  final bool partial;

  /// The whole file's size, when the server says.
  final int? totalBytes;
  final Stream<List<int>> body;
}

/// The catalog endpoints a device calls (backend/docs/api-phase-3-catalogs.md):
/// doctors, admins and assistants with `prescriptionsDraft` (BR-CAT11).
/// Every method throws [ApiException].
abstract interface class CatalogApi {
  /// `GET /api/catalog/current`; null before the first publish
  /// (404 `CATALOG_NOT_PUBLISHED`).
  Future<CatalogVersionInfo?> current();

  /// `GET /api/catalog/file/{version}`, from byte [from] with an HTTP range
  /// request so D0 resumes an interrupted download. [ifRange] is the
  /// version's sha256 (the file's ETag): if the file changed, the server
  /// answers 200 with all of it.
  Future<CatalogFileResponse> file(int version, {int from = 0, String? ifRange, CancelToken? cancel});

  /// `GET /api/catalog/customItems?since=` (BR-CAT9): one page of changes.
  Future<CustomItemSyncPage> customItems({String? since});

  /// `GET /api/catalog/myProfile`: the doctor's specialty profile(s) merged
  /// with General (BR-CAT4). Doctors and `prescriptionsDraft` assistants.
  Future<CatalogProfile> myProfile();
}

class ApiCatalogApi implements CatalogApi {
  ApiCatalogApi(this._dio);

  final Dio _dio;

  static const notPublished = 'CATALOG_NOT_PUBLISHED';

  @override
  Future<CatalogVersionInfo?> current() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/catalog/current');
      return CatalogVersionInfo.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      final api = ApiException.fromDio(error);
      if (api.status == 404 && api.code == notPublished) return null;
      throw api;
    }
  }

  @override
  Future<CatalogFileResponse> file(int version, {int from = 0, String? ifRange, CancelToken? cancel}) async {
    try {
      final response = await _dio.get<ResponseBody>(
        '/catalog/file/$version',
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          // A slow line can take minutes; only a stalled one fails.
          receiveTimeout: const Duration(minutes: 1),
          headers: {
            if (from > 0) 'Range': 'bytes=$from-',
            if (from > 0 && ifRange != null) 'If-Range': '"$ifRange"',
            'Accept': 'application/gzip',
          },
        ),
      );
      final partial = response.statusCode == 206;
      return CatalogFileResponse(
        partial: partial,
        totalBytes: partial
            ? _totalFromContentRange(response.headers.value('content-range'))
            : int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? ''),
        body: response.data!.stream,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<CustomItemSyncPage> customItems({String? since}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/catalog/customItems', queryParameters: {'since': ?since});
      return CustomItemSyncPage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<CatalogProfile> myProfile() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/catalog/myProfile');
      return CatalogProfile.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// `bytes 100-999/1000` → 1000.
  static int? _totalFromContentRange(String? header) {
    if (header == null) return null;
    final slash = header.lastIndexOf('/');
    return slash < 0 ? null : int.tryParse(header.substring(slash + 1).trim());
  }
}
