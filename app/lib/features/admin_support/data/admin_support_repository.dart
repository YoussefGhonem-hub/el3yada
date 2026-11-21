import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../patient/domain/patient_models.dart' show Json;
import '../domain/admin_support_models.dart';

/// AD11 accounts support (`/api/admin`). No medical data. Account deletions (AD12)
/// are features/account_deletion.
abstract interface class AdminSupportRepository {
  /// [phone] is already normalized (E.164).
  Future<AccountSearchResult> searchAccounts(String phone);

  Future<void> setLoginStatus(String userId, {required bool active, String? reason});
}

class ApiAdminSupportRepository implements AdminSupportRepository {
  ApiAdminSupportRepository(this._dio);

  final Dio _dio;

  Future<Object?> _call(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.request<Object?>(path, data: body, queryParameters: query, options: Options(method: method));
      return response.data;
    } on DioException catch (error) {
      throw ApiError.from(error);
    }
  }

  @override
  Future<AccountSearchResult> searchAccounts(String phone) async =>
      AccountSearchResult.fromJson(await _call('GET', '/admin/accounts', query: {'phone': phone}) as Json);

  @override
  Future<void> setLoginStatus(String userId, {required bool active, String? reason}) =>
      _call('POST', '/admin/accounts/$userId/status', body: {'status': active ? 'active' : 'disabled', 'reason': reason});
}

/// Offline data for dev builds with the test accounts.
class FakeAdminSupportRepository implements AdminSupportRepository {
  FakeAdminSupportRepository({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;
  final Map<String, String> _status = {'u-pat': 'active', 'u-as': 'active'};

  @override
  Future<AccountSearchResult> searchAccounts(String phone) async => AccountSearchResult(
        phone: phone,
        patients: [
          if (phone == '+201000000002')
            SupportPatient(
              userId: 'u-pat', patientId: 'pat-1', fullName: 'محمد إبراهيم', phone: phone, loginStatus: _status['u-pat']!,
              patientStatus: 'active', createdAt: _now.subtract(const Duration(days: 90)),
              doctors: const [LinkedDoctor(doctorId: 'doc-a', fullName: 'د. أحمد سامي'), LinkedDoctor(doctorId: 'doc-b', fullName: 'د. منى حسن')],
            ),
        ],
        assistants: [
          if (phone == '+201000000001')
            SupportAssistant(
              userId: 'u-as', fullName: 'سارة علي', phone: phone, loginStatus: _status['u-as']!, assistantStatus: 'active',
              doctorId: 'doc-a', doctorName: 'د. أحمد سامي', preset: 'reception', lastActiveAt: _now,
            ),
        ],
      );

  @override
  Future<void> setLoginStatus(String userId, {required bool active, String? reason}) async =>
      _status[userId] = active ? 'active' : 'disabled';
}

final adminSupportRepositoryProvider = Provider<AdminSupportRepository>((ref) {
  if (Env.useFakeAuth) return FakeAdminSupportRepository();
  return ApiAdminSupportRepository(ref.watch(dioProvider));
});
