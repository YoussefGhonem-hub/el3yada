import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/data/paged.dart';
import '../../../core/network/api_exception.dart';
import '../domain/catalog_models.dart';

/// Upload progress: bytes sent of the total.
typedef SendProgress = void Function(int sent, int total);

/// A file the admin picked for publishCatalog: a path on desktop, bytes
/// where there is no path.
class PickedCatalogFile {
  const PickedCatalogFile({required this.name, required this.sizeBytes, this.path, this.bytes});

  final String name;
  final int sizeBytes;
  final String? path;
  final Uint8List? bytes;
}

/// AD19 and AD20 (backend/docs/api-phase-3-catalogs.md). Any admin. Every
/// method throws [ApiException].
abstract interface class AdminCatalogRepository {
  /// Every version, newest first.
  Future<List<CatalogVersionEntry>> versions();

  /// `publishCatalog`: the builder's `.sqlite.gz` and its manifest JSON.
  /// 409 `CATALOG_COUNT_DROP` (with `drops`) asks to send it again with
  /// [confirmDrop].
  Future<CatalogVersionInfo> publish({
    required PickedCatalogFile file,
    required String manifest,
    bool confirmDrop = false,
    SendProgress? onProgress,
    CancelToken? cancel,
  });

  /// Newest change first.
  Future<Paged<CustomCatalogItem>> customItems({
    CatalogItemType? type,
    bool? active,
    String? search,
    int page = 1,
    int pageSize = 50,
  });

  Future<CustomCatalogItem> createCustomItem(CustomItemDraft draft);

  /// Every field replaced; [CustomItemDraft.active] false disables it.
  Future<CustomCatalogItem> updateCustomItem(String customItemId, CustomItemDraft draft);

  /// [S] [status] is `open`, `done` or `all`; open first, oldest first.
  Future<Paged<CatalogReport>> reports({String status = 'open', int page = 1, int pageSize = 50});

  /// Marks it done. Asking again changes nothing.
  Future<CatalogReport> handleReport(String reportId);

  /// AD19: General first.
  Future<List<SpecialtySummary>> specialties();

  Future<SpecialtyProfile> profile(String specialtyId);

  /// Every list replaced.
  Future<SpecialtyProfile> updateProfile(SpecialtyProfile profile);

  /// "Copy from another specialty": the source's lists and its
  /// `includeGeneral` replace this one's.
  Future<SpecialtyProfile> copyProfile(String specialtyId, {required String fromSpecialtyId});
}

class ApiAdminCatalogRepository implements AdminCatalogRepository {
  ApiAdminCatalogRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<CatalogVersionEntry>> versions() => _call(() async {
    final response = await _dio.get<List<dynamic>>('/admin/catalogVersions');
    return [
      for (final row in response.data ?? const []) CatalogVersionEntry.fromJson((row as Map).cast<String, dynamic>()),
    ];
  });

  @override
  Future<CatalogVersionInfo> publish({
    required PickedCatalogFile file,
    required String manifest,
    bool confirmDrop = false,
    SendProgress? onProgress,
    CancelToken? cancel,
  }) => _call(() async {
    final gzip = DioMediaType('application', 'gzip');
    final form = FormData.fromMap({
      'file': file.path != null
          ? await MultipartFile.fromFile(file.path!, filename: file.name, contentType: gzip)
          : MultipartFile.fromBytes(file.bytes!, filename: file.name, contentType: gzip),
      'manifest': manifest,
      if (confirmDrop) 'confirmDrop': 'true',
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/publishCatalog',
      data: form,
      onSendProgress: onProgress,
      cancelToken: cancel,
      options: Options(sendTimeout: const Duration(minutes: 30), receiveTimeout: const Duration(minutes: 5)),
    );
    return CatalogVersionInfo.fromJson(response.data ?? const {});
  });

  @override
  Future<Paged<CustomCatalogItem>> customItems({
    CatalogItemType? type,
    bool? active,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/catalog/customItems',
      queryParameters: {
        'type': ?type?.name,
        'active': ?active,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'page': page,
        'pageSize': pageSize,
      },
    );
    return Paged.fromJson(response.data ?? const {}, CustomCatalogItem.fromJson);
  });

  @override
  Future<CustomCatalogItem> createCustomItem(CustomItemDraft draft) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/catalog/createCustomItem',
      data: {'type': draft.type.name, ...draft.toJson()},
    );
    return CustomCatalogItem.fromJson(response.data ?? const {});
  });

  @override
  Future<CustomCatalogItem> updateCustomItem(String customItemId, CustomItemDraft draft) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/catalog/updateCustomItem',
      data: {'customItemId': customItemId, ...draft.toJson(), 'active': draft.active},
    );
    return CustomCatalogItem.fromJson(response.data ?? const {});
  });

  @override
  Future<Paged<CatalogReport>> reports({String status = 'open', int page = 1, int pageSize = 50}) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/admin/catalog/reports',
      queryParameters: {'status': status, 'page': page, 'pageSize': pageSize},
    );
    return Paged.fromJson(response.data ?? const {}, CatalogReport.fromJson);
  });

  @override
  Future<CatalogReport> handleReport(String reportId) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>('/admin/catalog/handleReport', data: {'reportId': reportId});
    return CatalogReport.fromJson(response.data ?? const {});
  });

  @override
  Future<List<SpecialtySummary>> specialties() => _call(() async {
    final response = await _dio.get<List<dynamic>>('/admin/specialties');
    return [
      for (final row in response.data ?? const []) SpecialtySummary.fromJson((row as Map).cast<String, dynamic>()),
    ];
  });

  @override
  Future<SpecialtyProfile> profile(String specialtyId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/admin/specialties/$specialtyId/profile');
    return SpecialtyProfile.fromJson(response.data ?? const {});
  });

  @override
  Future<SpecialtyProfile> updateProfile(SpecialtyProfile profile) => _call(() async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/admin/specialties/${profile.specialtyId}/profile',
      data: profile.toRequestJson(),
    );
    return SpecialtyProfile.fromJson(response.data ?? const {});
  });

  @override
  Future<SpecialtyProfile> copyProfile(String specialtyId, {required String fromSpecialtyId}) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/admin/specialties/$specialtyId/copyProfile',
      data: {'fromSpecialtyId': fromSpecialtyId},
    );
    return SpecialtyProfile.fromJson(response.data ?? const {});
  });

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
