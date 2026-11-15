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

import 'phase2_clinic_day.dart';

/// Runs the app's real repositories against a running API, to check that the
/// app reads every answer the way the API sends it. Off by default.
///
/// Phase 1 (sign-in and tokens) is below. Phase 2 (one clinic day: sign-up
/// and approval, branches, prices, patients, sessions, fees, an assistant,
/// the activity log) is in `phase2_clinic_day.dart`. It runs after Phase 1 in
/// this isolate, because both sign in as the seeded admin and the files of a
/// directory run at the same time.
///
/// Use a throwaway database: the test changes the admin's password. Phase 2
/// makes new accounts on every run. To run Phase 1 again on the same
/// database, give the admin a new temporary password (`seed-admin … --reset`).
///
/// ```
/// # backend/, with the throwaway database in the variable for every command
/// # (`dotnet ef database drop` has no --connection option)
/// export ConnectionStrings__Default="Server=(localdb)\MSSQLLocalDB;Database=el3yada_contract_<random>;Trusted_Connection=True;TrustServerCertificate=True"
/// dotnet ef database update --project src/El3yada.Data --startup-project src/El3yada.Api
/// dotnet run --project src/El3yada.Api -- seed-admin contract-admin@el3yada.dev   (prints the temporary password)
/// RateLimits__LoginPerMinute=200 RateLimits__RegistrationPerHour=200 Auth__UserStateCacheSeconds=0 \
///   dotnet run --project src/El3yada.Api --launch-profile http
///
/// # app/
/// EL3YADA_API_URL=http://localhost:5001 EL3YADA_ADMIN_EMAIL=contract-admin@el3yada.dev \
/// EL3YADA_ADMIN_PASSWORD=<temporary password> flutter test test/contract
///
/// # backend/ afterwards: stop the API, then (same variable)
/// dotnet ef database drop --force --project src/El3yada.Data --startup-project src/El3yada.Api
/// ```
///
/// The settings on the API's command line make runs repeatable:
/// - One run signs in ten times and registers once from one IP: the default
///   limits are ten sign-ins a minute and ten registrations an hour.
/// - `seed-admin --reset` changes the admin's security stamp from another
///   process, which the API sees only after `Auth:UserStateCacheSeconds`
///   (30 s by default; until then the new token answers `SESSION_REVOKED`).
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
    // A new identifier each run: five misses in 15 minutes lock one (TOO_MANY_ATTEMPTS).
    await expectLater(
      auth.login(
        identifier: 'nobody-${DateTime.now().microsecondsSinceEpoch}@el3yada.dev',
        password: 'Wrong12345',
        device: device,
      ),
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

  group('Phase 2, one clinic day:', () {
    phase2ClinicDay(
      baseUrl: baseUrl,
      adminEmail: email,
      adminTemporaryPassword: temporaryPassword,
      adminPassword: newPassword,
      skip: skip,
    );
  });
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
