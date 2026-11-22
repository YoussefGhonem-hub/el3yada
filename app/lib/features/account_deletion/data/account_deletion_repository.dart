import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/account_deletion_models.dart';
import 'fake_account_deletion_repository.dart';

/// Account deletion (backend/docs/api-account-deletion.md). Every method throws
/// [ApiException].
abstract interface class AccountDeletionRepository {
  /// `getAccountDeletion`: what deleting the signed-in account does now, or
  /// the deletion in progress. Also answers during the grace period (A16).
  Future<AccountDeletionState> state();

  /// `requestAccountDeletion`. 400 `currentPassword: CURRENT_PASSWORD_INCORRECT`;
  /// 409 `UNPAID_INVOICES` (with the invoices), `LAST_SUPER_ADMIN`,
  /// `ACCOUNT_DELETION_SCHEDULED`. Every session is signed out, this one too.
  Future<AccountDeletionStarted> request({required String currentPassword, String? reason});

  /// `restoreAccount` (A16). Answers the account fields (`auth/me`'s shape).
  Future<Map<String, dynamic>> restore();

  /// AD12 `getAccountDeletions`, newest first. [userId]: one account's (AD5, AD11).
  Future<AccountDeletionPage> list({AccountDeletionFilter filter = const AccountDeletionFilter(), String? userId, int page = 1});

  /// `adminScheduleAccountDeletion` (AD5, AD11, AD14). [reason] is required.
  Future<AccountDeletionItem> schedule({required String userId, required String reason});

  /// `adminCancelAccountDeletion`: cancels and restores, with a reason.
  Future<AccountDeletionItem> cancel(String requestId, {required String reason});
}

class ApiAccountDeletionRepository implements AccountDeletionRepository {
  ApiAccountDeletionRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountDeletionState> state() =>
      _call(() async => AccountDeletionState.fromJson(await _send('GET', '/me/accountDeletion')));

  @override
  Future<AccountDeletionStarted> request({required String currentPassword, String? reason}) => _call(() async =>
      AccountDeletionStarted.fromJson(await _send('POST', '/me/requestAccountDeletion', {
        'currentPassword': currentPassword,
        'reason': ?reason,
      })));

  @override
  Future<Map<String, dynamic>> restore() => _call(() => _send('POST', '/me/restoreAccount', const {}));

  @override
  Future<AccountDeletionPage> list({
    AccountDeletionFilter filter = const AccountDeletionFilter(),
    String? userId,
    int page = 1,
  }) =>
      _call(() async => AccountDeletionPage.fromJson(await _send('GET', '/admin/accountDeletions', null, {
            'role': filter.role?.name ?? 'all',
            'status': filter.status?.name ?? 'all',
            'userId': ?userId,
            'page': page,
            'pageSize': 25,
          })));

  @override
  Future<AccountDeletionItem> schedule({required String userId, required String reason}) => _call(() async =>
      AccountDeletionItem.fromJson(await _send('POST', '/admin/accountDeletions/schedule', {'userId': userId, 'reason': reason})));

  @override
  Future<AccountDeletionItem> cancel(String requestId, {required String reason}) => _call(() async =>
      AccountDeletionItem.fromJson(await _send('POST', '/admin/accountDeletions/$requestId/cancel', {'reason': reason})));

  Future<Map<String, dynamic>> _send(String method, String path, [Object? body, Map<String, dynamic>? query]) async {
    final response = await _dio.request<Map<String, dynamic>>(
      path,
      data: body,
      queryParameters: query,
      options: Options(method: method),
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

/// The real API, or the offline accounts (and their deletions) when
/// `USE_FAKE_AUTH` is on.
final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((ref) {
  if (Env.useFakeAuth) {
    final auth = ref.watch(authRepositoryProvider);
    return FakeAccountDeletionRepository(auth is FakeAuthRepository ? auth : FakeAuthRepository());
  }
  return ApiAccountDeletionRepository(ref.watch(dioProvider));
});
