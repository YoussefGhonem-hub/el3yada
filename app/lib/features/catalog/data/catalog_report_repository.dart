import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog_models.dart';
import 'fake_catalog_backend.dart';

/// "Report a missing or wrong item" [S] (BR-CAT8): `POST
/// /api/catalog/reportCatalogItem`, doctor only
/// (backend/docs/api-phase-3-catalogs.md). The admins see it in AD20's
/// doctor reports. Throws [ApiException].
abstract interface class CatalogReportRepository {
  /// [text] 1–500 characters; [itemRef] at most 100, for example
  /// `drug:123`, `loinc:2093-3` or `search:ketofan`.
  Future<CatalogReport> report({required CatalogReportType type, required String text, String? itemRef});
}

final catalogReportRepositoryProvider = Provider<CatalogReportRepository>((ref) {
  if (Env.useFakeAuth) {
    return FakeCatalogReportRepository(
      ref.watch(fakeCatalogBackendProvider),
      doctorName: () => ref.read(authControllerProvider).value?.displayName ?? '',
    );
  }
  return ApiCatalogReportRepository(ref.watch(dioProvider));
});

class ApiCatalogReportRepository implements CatalogReportRepository {
  ApiCatalogReportRepository(this._dio);

  final Dio _dio;

  @override
  Future<CatalogReport> report({required CatalogReportType type, required String text, String? itemRef}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/catalog/reportCatalogItem', data: {
        'type': type.name,
        'text': text,
        'itemRef': ?itemRef,
      });
      return CatalogReport.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// Offline: the report joins [FakeCatalogBackend.reports], so AD20 lists it.
class FakeCatalogReportRepository implements CatalogReportRepository {
  FakeCatalogReportRepository(this.backend, {required this.doctorName});

  final FakeCatalogBackend backend;
  final String Function() doctorName;

  @override
  Future<CatalogReport> report({required CatalogReportType type, required String text, String? itemRef}) async {
    await backend.step('reportCatalogItem');
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 500 || (itemRef?.length ?? 0) > 100) {
      throw ApiException(
        kind: ApiErrorKind.http,
        status: 400,
        code: ApiCodes.validationFailed,
        fieldCodes: {if (trimmed.isEmpty) 'text': 'REQUIRED' else if (trimmed.length > 500) 'text': 'TOO_LONG' else 'itemRef': 'TOO_LONG'},
      );
    }
    final report = CatalogReport(
      reportId: 'cr-doctor-${backend.reports.length + 1}',
      type: type,
      text: trimmed,
      itemRef: itemRef,
      done: false,
      doctorName: doctorName(),
      createdAt: DateTime.now().toUtc(),
    );
    backend.reports[report.reportId] = report;
    return report;
  }
}
