import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_session.dart';
import '../domain/user_role.dart';

abstract interface class AuthRepository {
  /// [identifier] is already normalized: a lower-case email or an E.164
  /// Egyptian mobile number (`+201XXXXXXXXX`).
  Future<AuthSession> login({required String identifier, required String password});

  Future<void> logout(AuthSession session);
}

/// Talks to the ASP.NET Core API (`login` endpoint, spec section 9.1).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<AuthSession> login({required String identifier, required String password}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'identifier': identifier, 'password': password},
      );
      final data = response.data;
      if (data == null) throw const UnknownAuthException();
      // TODO(A3): handle the "choose account" answer when one mobile number
      // has both a patient account and an assistant account.
      return AuthSession.fromJson(data);
    } on DioException catch (error) {
      throw _map(error);
    }
  }

  @override
  Future<void> logout(AuthSession session) async {
    try {
      await _dio.post<void>('/auth/logout', data: {'refreshToken': session.refreshToken});
    } on DioException {
      // Best effort: the local session is cleared anyway.
    }
  }

  AuthException _map(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException();
      default:
        return switch (error.response?.statusCode) {
          400 || 401 => const InvalidCredentialsException(),
          429 => const TooManyAttemptsException(),
          _ => UnknownAuthException(error),
        };
    }
  }
}

/// Offline test accounts for development, before the API exists.
/// Never used in prod builds (see [Env.useFakeAuth]).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  /// Shown on the login screen in dev builds. Keys are normalized identifiers.
  static const accounts = <String, (UserRole, String)>{
    'admin@el3yada.dev': (UserRole.admin, 'Admin'),
    'doctor@el3yada.dev': (UserRole.doctor, 'د. تجريبي'),
    '+201000000001': (UserRole.assistant, 'مساعد تجريبي'),
    '+201000000002': (UserRole.patient, 'مريض تجريبي'),
  };

  @override
  Future<AuthSession> login({required String identifier, required String password}) async {
    await Future<void>.delayed(delay);
    final account = accounts[identifier];
    if (account == null || password.isEmpty || password == 'wrong') {
      throw const InvalidCredentialsException();
    }
    final (role, name) = account;
    return AuthSession(
      userId: 'dev-${role.name}',
      displayName: name,
      role: role,
      accessToken: 'dev-access-token',
      refreshToken: 'dev-refresh-token',
      doctorId: role == UserRole.assistant ? 'dev-doctor' : null,
    );
  }

  @override
  Future<void> logout(AuthSession session) async {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useFakeAuth) return FakeAuthRepository();
  return ApiAuthRepository(ref.watch(dioProvider));
});
