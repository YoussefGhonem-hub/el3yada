import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/analytics_models.dart';
import 'fake_analytics_repository.dart';

/// The doctor's dashboard and revenue report (backend/docs/api-phase-7.md,
/// "Dashboard" and "Revenue"). Every method throws [ApiException].
abstract interface class AnalyticsRepository {
  /// D1 / AS18 (`getDashboard`).
  Future<Dashboard> dashboard(AnalyticsFilter filter);

  /// D35 by month (`getRevenueReport`), with the branch, type and payment tabs.
  Future<RevenueReport> revenue(RevenueFilter filter);

  /// D35: the days of a month.
  Future<RevenueMonth> revenueMonth(
    String month, {
    String? branchId,
    SessionType? type,
  });

  /// D35: the sessions of a day.
  Future<RevenueDay> revenueDay(
    DateTime day, {
    String? branchId,
    SessionType? type,
  });
}

class ApiAnalyticsRepository implements AnalyticsRepository {
  ApiAnalyticsRepository(this._dio);

  final Dio _dio;

  @override
  Future<Dashboard> dashboard(AnalyticsFilter filter) => _call(
    () async => Dashboard.fromJson(await _get('/dashboard', filter.toQuery())),
  );

  @override
  Future<RevenueReport> revenue(RevenueFilter filter) => _call(
    () async =>
        RevenueReport.fromJson(await _get('/revenue', filter.toQuery())),
  );

  @override
  Future<RevenueMonth> revenueMonth(
    String month, {
    String? branchId,
    SessionType? type,
  }) => _call(
    () async => RevenueMonth.fromJson(
      await _get('/revenue/month', {
        'month': month,
        'branchId': ?branchId,
        if (type != null) 'type': type.wire,
      }),
    ),
  );

  @override
  Future<RevenueDay> revenueDay(
    DateTime day, {
    String? branchId,
    SessionType? type,
  }) => _call(
    () async => RevenueDay.fromJson(
      await _get('/revenue/day', {
        'day': dayKey(day),
        'branchId': ?branchId,
        if (type != null) 'type': type.wire,
      }),
    ),
  );

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
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

/// The real API, or the offline numbers when `USE_FAKE_AUTH` is on.
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  if (Env.useFakeAuth) return FakeAnalyticsRepository();
  return ApiAnalyticsRepository(ref.watch(dioProvider));
});
