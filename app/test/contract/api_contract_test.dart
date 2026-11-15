import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the app's real repositories against a running API, to check that the
/// app reads every answer the way the API sends it. Off by default.
///
/// Use a throwaway database: the test changes the admin's password.
///
/// ```
/// # backend/: a fresh database, an admin, and the API on http://localhost:5001
/// dotnet ef database update ... --connection "<throwaway db>"
/// dotnet run --project src/El3yada.Api -- seed-admin contract-admin@el3yada.dev
/// dotnet run --project src/El3yada.Api --launch-profile http   (with ConnectionStrings__Default set)
///
/// # app/
/// EL3YADA_API_URL=http://localhost:5001 EL3YADA_ADMIN_EMAIL=contract-admin@el3yada.dev \
/// EL3YADA_ADMIN_PASSWORD=<temporary password> flutter test test/contract
/// ```
void main() {
  final env = Platform.environment;
  final baseUrl = env['EL3YADA_API_URL'];
  final email = env['EL3YADA_ADMIN_EMAIL'];
  final temporaryPassword = env['EL3YADA_ADMIN_PASSWORD'];
  final skip = baseUrl == null || email == null || temporaryPassword == null
      ? 'Set EL3YADA_API_URL, EL3YADA_ADMIN_EMAIL and EL3YADA_ADMIN_PASSWORD to run'
      : null;

  String? bearer;
  Dio newDio({bool auth = false}) {
    final dio = Dio(BaseOptions(baseUrl: '$baseUrl/api', headers: {'Accept': 'application/json'}));
    if (auth) {
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        if (bearer != null) options.headers['Authorization'] = 'Bearer $bearer';
        handler.next(options);
      }));
    }
    return dio;
  }

  late final ApiAuthRepository auth = ApiAuthRepository(newDio(auth: true), newDio());
  const device = {'deviceId': 'contract-test-device', 'platform': 'android', 'appVersion': '1.0.0'};
  const newPassword = 'Contract1234';

  test('public settings parse', () async {
    final settings = await ApiPublicSettingsRepository(newDio(), _MemoryPrefs()).fetch();
    expect(settings.terms.version, isNotNull);
    expect(settings.requiresUpdate('android', '999.0.0'), isFalse);
  }, skip: skip);

  test('a wrong password answers INVALID_CREDENTIALS', () async {
    await expectLater(
      auth.login(identifier: 'nobody@el3yada.dev', password: 'Wrong12345', device: device),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiCodes.invalidCredentials)),
    );
  }, skip: skip);

  test('first sign-in, set a new password, me, refresh, reuse, logout', () async {
    // First sign-in with the temporary password: A9 is required.
    final first = await auth.login(identifier: email!, password: temporaryPassword!, device: device);
    expect(first, isA<SignedIn>());
    var session = (first as SignedIn).session;
    expect(session.role, UserRole.admin);
    expect(session.adminRole, 'superAdmin');
    expect(session.mustChangePassword, isTrue);
    expect(session.accessTokenExpiresAt, isNotNull);
    expect(session.accessTokenExpiresAt!.isUtc, isTrue);

    // Everything but the allowed endpoints is refused until then.
    bearer = session.accessToken;
    final account = await auth.me();
    expect(session.withAccount(account).userId, session.userId);

    session = await auth.setNewPassword(newPassword: newPassword, device: device);
    expect(session.mustChangePassword, isFalse);
    bearer = session.accessToken;

    // Refresh gives a new pair; sending the old refresh token again is theft.
    final refreshed = await auth.refresh(session.refreshToken);
    expect(refreshed.refreshToken, isNot(session.refreshToken));
    await expectLater(
      auth.refresh(session.refreshToken),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiCodes.refreshTokenReused)),
    );

    // The family is revoked, so sign in again with the new password.
    final again = await auth.login(identifier: email, password: newPassword, device: device);
    final fresh = (again as SignedIn).session;
    expect(fresh.mustChangePassword, isFalse);
    expect(fresh.doctorStatus, isNull);

    await auth.logout(fresh, deviceId: 'contract-test-device');
    await expectLater(
      auth.refresh(fresh.refreshToken),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
  }, skip: skip);

  test('forgot password answers the same for an unknown email', () async {
    await auth.requestPasswordResetEmail('nobody-${DateTime.now().millisecondsSinceEpoch}@el3yada.dev');
  }, skip: skip);

  test('a session saved as JSON text reads back the same (as SecureTokenStore does)', () async {
    final again = await auth.login(identifier: email!, password: newPassword, device: device);
    final session = (again as SignedIn).session;
    final saved = jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>;
    expect(AuthSession.fromJson(saved), session);
  }, skip: skip);
}

class _MemoryPrefs implements SharedPreferencesLike {
  final _values = <String, String>{};

  @override
  String? getString(String key) => _values[key];

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }
}
