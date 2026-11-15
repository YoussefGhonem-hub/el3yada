import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/auth_session.dart';
import '../domain/login_result.dart';
import '../domain/user_role.dart';

/// Sign-in, sessions and passwords (spec 9.1; contract in
/// backend/docs/api-phase-1.md). Every method throws [ApiException].
abstract interface class AuthRepository {
  /// [identifier] is already normalized: a lower-case email or an E.164
  /// Egyptian mobile number (`+201XXXXXXXXX`).
  Future<LoginResult> login({required String identifier, required String password, Map<String, dynamic>? device});

  /// "Log in as" (A3), after [login] answered [ChooseAccount].
  Future<AuthSession> selectAccount({
    required String selectionToken,
    required UserRole role,
    Map<String, dynamic>? device,
  });

  /// New tokens. The old refresh token stops working.
  Future<AuthSession> refresh(String refreshToken);

  /// Ends this device's session. Never throws.
  Future<void> logout(AuthSession session, {String? deviceId});

  /// The account fields of `GET /api/auth/me` (no tokens). Pass [accessToken]
  /// to call it outside the normal client (at start-up, before the session is
  /// in place).
  Future<Map<String, dynamic>> me({String? accessToken});

  /// A9. [acceptTerms] is required for a patient who hasn't accepted the Terms.
  Future<AuthSession> setNewPassword({required String newPassword, bool? acceptTerms, Map<String, dynamic>? device});

  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
    Map<String, dynamic>? device,
  });

  /// A8, doctors and admins. The same answer whether or not the email exists.
  Future<void> requestPasswordResetEmail(String email);

  /// A8, patients and assistants: their doctor is notified.
  Future<void> requestPatientPasswordReset(String phone);

  /// A8, step two: the code (token) from the reset email and the new
  /// password. Signs out every device; the user then signs in.
  Future<void> resetPassword({required String token, required String newPassword});

  /// A5: the token from the verification email.
  Future<void> verifyEmail(String token);

  /// A5 "Resend".
  Future<void> resendVerificationEmail();

  /// Saves the language and appearance on the account (push language).
  Future<void> updatePreferences({String? locale, String? themeMode});
}

/// Talks to the ASP.NET Core API.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._plain);

  /// With the auth interceptor (token, refresh on 401).
  final Dio _dio;

  /// Without it: for refresh and logout, which must never trigger a refresh.
  final Dio _plain;

  @override
  Future<LoginResult> login({required String identifier, required String password, Map<String, dynamic>? device}) =>
      _call(() async {
        final data = await _post(_plain, '/auth/login', {
          'identifier': identifier,
          'password': password,
          'device': ?device,
        });
        return data['result'] == 'chooseAccount' ? ChooseAccount.fromJson(data) : SignedIn(AuthSession.fromJson(data));
      });

  @override
  Future<AuthSession> selectAccount({
    required String selectionToken,
    required UserRole role,
    Map<String, dynamic>? device,
  }) =>
      _call(() async => AuthSession.fromJson(await _post(_plain, '/auth/selectAccount', {
            'selectionToken': selectionToken,
            'role': role.name,
            'device': ?device,
          })));

  @override
  Future<AuthSession> refresh(String refreshToken) =>
      _call(() async => AuthSession.fromJson(await _post(_plain, '/auth/refresh', {'refreshToken': refreshToken})));

  @override
  Future<void> logout(AuthSession session, {String? deviceId}) async {
    try {
      await _plain.post<void>('/auth/logout', data: {'refreshToken': session.refreshToken, 'deviceId': ?deviceId});
    } on DioException {
      // Best effort: the local session is cleared anyway.
    }
  }

  @override
  Future<Map<String, dynamic>> me({String? accessToken}) => _call(() async {
        final client = accessToken == null ? _dio : _plain;
        final response = await client.get<Map<String, dynamic>>(
          '/auth/me',
          options: accessToken == null ? null : Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
        return response.data ?? const {};
      });

  @override
  Future<AuthSession> setNewPassword({required String newPassword, bool? acceptTerms, Map<String, dynamic>? device}) =>
      _call(() async => AuthSession.fromJson(await _post(_dio, '/auth/setNewPassword', {
            'newPassword': newPassword,
            'acceptTerms': ?acceptTerms,
            'device': ?device,
          })));

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
    Map<String, dynamic>? device,
  }) =>
      _call(() async => AuthSession.fromJson(await _post(_dio, '/auth/changePassword', {
            'currentPassword': currentPassword,
            'newPassword': newPassword,
            'device': ?device,
          })));

  @override
  Future<void> requestPasswordResetEmail(String email) =>
      _call(() => _post(_plain, '/auth/requestPasswordResetEmail', {'email': email}));

  @override
  Future<void> requestPatientPasswordReset(String phone) =>
      _call(() => _post(_plain, '/auth/requestPatientPasswordReset', {'phone': phone}));

  @override
  Future<void> resetPassword({required String token, required String newPassword}) =>
      _call(() => _post(_plain, '/auth/resetPassword', {'token': token, 'newPassword': newPassword}));

  @override
  Future<void> verifyEmail(String token) => _call(() => _post(_plain, '/auth/verifyEmail', {'token': token}));

  @override
  Future<void> resendVerificationEmail() => _call(() => _post(_dio, '/auth/resendVerificationEmail', const {}));

  @override
  Future<void> updatePreferences({String? locale, String? themeMode}) =>
      _call(() => _post(_dio, '/auth/updatePreferences', {'locale': ?locale, 'themeMode': ?themeMode}));

  Future<Map<String, dynamic>> _post(Dio client, String path, Map<String, dynamic> body) async {
    final response = await client.post<Map<String, dynamic>>(path, data: body);
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

/// Offline accounts for development and tests, used when `USE_FAKE_AUTH` is
/// true. Never used in prod builds (see [Env.useFakeAuth]). Every password
/// works except `wrong`.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  /// Shown on the login screen in dev builds. Keys are normalized identifiers.
  static final accounts = <String, FakeAccount>{
    'admin@el3yada.dev': const FakeAccount(UserRole.admin, 'Admin', adminRole: 'superAdmin'),
    'doctor@el3yada.dev': const FakeAccount(UserRole.doctor, 'د. تجريبي', doctorStatus: DoctorStatus.active),
    'pending@el3yada.dev': const FakeAccount(UserRole.doctor, 'د. قيد المراجعة',
        doctorStatus: DoctorStatus.pendingApproval, emailVerified: false),
    'rejected@el3yada.dev': const FakeAccount(UserRole.doctor, 'د. مرفوض',
        doctorStatus: DoctorStatus.rejected, reason: 'صورة الكارنيه غير واضحة، ارفع صورة أوضح.'),
    'disabled@el3yada.dev': const FakeAccount(UserRole.doctor, 'د. موقوف', blockCode: ApiCodes.accountDisabled),
    '+201000000001': const FakeAccount(UserRole.assistant, 'مساعد تجريبي', doctorStatus: DoctorStatus.active),
    '+201000000002': const FakeAccount(UserRole.patient, 'مريض تجريبي'),
    '+201000000003': const FakeAccount(UserRole.patient, 'مريض بحسابين', alsoAssistant: true),
    '+201000000004': const FakeAccount(UserRole.patient, 'مريض جديد', mustChangePassword: true, mustAcceptTerms: true),
  };

  AuthSession? _last;

  /// The signed-in account, which `me` and `refresh` answer with. Other
  /// fakes change it (doctor registration: `FakeRegistrationRepository`).
  // ignore: unnecessary_getters_setters
  AuthSession? get current => _last;
  set current(AuthSession? session) => _last = session;

  @override
  Future<LoginResult> login({required String identifier, required String password, Map<String, dynamic>? device}) async {
    await Future<void>.delayed(delay);
    final account = accounts[identifier];
    if (account == null || password.isEmpty || password == 'wrong') {
      throw const ApiException(kind: ApiErrorKind.http, status: 401, code: ApiCodes.invalidCredentials);
    }
    if (account.blockCode != null) {
      throw ApiException(kind: ApiErrorKind.http, status: 403, code: account.blockCode);
    }
    if (account.alsoAssistant) {
      return ChooseAccount(selectionToken: 'fake:$identifier', accounts: [
        AccountChoice(role: UserRole.patient, displayName: account.name),
        AccountChoice(role: UserRole.assistant, displayName: account.name, doctorName: 'د. تجريبي'),
      ]);
    }
    return SignedIn(_last = account.session(identifier));
  }

  @override
  Future<AuthSession> selectAccount({
    required String selectionToken,
    required UserRole role,
    Map<String, dynamic>? device,
  }) async {
    await Future<void>.delayed(delay);
    final identifier = selectionToken.replaceFirst('fake:', '');
    final account = accounts[identifier]!;
    final chosen = role == UserRole.assistant
        ? FakeAccount(UserRole.assistant, account.name, doctorStatus: DoctorStatus.active)
        : account;
    return _last = chosen.session(identifier);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async => _last ?? (throw const ApiException(
        kind: ApiErrorKind.http,
        status: 401,
        code: ApiCodes.refreshTokenInvalid,
      ));

  @override
  Future<void> logout(AuthSession session, {String? deviceId}) async => _last = null;

  @override
  Future<Map<String, dynamic>> me({String? accessToken}) async {
    final last = _last;
    if (last == null) return const {};
    final json = last.toJson()
      ..remove('accessToken')
      ..remove('refreshToken');
    return json;
  }

  @override
  Future<AuthSession> setNewPassword({required String newPassword, bool? acceptTerms, Map<String, dynamic>? device}) async {
    await Future<void>.delayed(delay);
    final last = _last!;
    if (last.mustAcceptTerms && acceptTerms != true) {
      throw const ApiException(
        kind: ApiErrorKind.http,
        status: 400,
        code: ApiCodes.validationFailed,
        fieldCodes: {'acceptTerms': 'TERMS_NOT_ACCEPTED'},
      );
    }
    return _last = last.copyWith(mustChangePassword: false, mustAcceptTerms: false);
  }

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
    Map<String, dynamic>? device,
  }) async {
    await Future<void>.delayed(delay);
    if (currentPassword == 'wrong') {
      throw const ApiException(
        kind: ApiErrorKind.http,
        status: 400,
        code: ApiCodes.validationFailed,
        fieldCodes: {'currentPassword': 'CURRENT_PASSWORD_INCORRECT'},
      );
    }
    return _last!;
  }

  @override
  Future<void> requestPasswordResetEmail(String email) => Future<void>.delayed(delay);

  @override
  Future<void> requestPatientPasswordReset(String phone) => Future<void>.delayed(delay);

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    await Future<void>.delayed(delay);
    if (token.trim() == 'expired') {
      throw const ApiException(kind: ApiErrorKind.http, status: 400, code: 'EMAIL_TOKEN_EXPIRED');
    }
  }

  /// Any code works except `expired`, and verifies the signed-in account.
  @override
  Future<void> verifyEmail(String token) async {
    await Future<void>.delayed(delay);
    if (token.trim() == 'expired') {
      throw const ApiException(kind: ApiErrorKind.http, status: 400, code: 'EMAIL_TOKEN_EXPIRED');
    }
    _last = _last?.copyWith(emailVerified: true);
  }

  @override
  Future<void> resendVerificationEmail() => Future<void>.delayed(delay);

  @override
  Future<void> updatePreferences({String? locale, String? themeMode}) async {}
}

class FakeAccount {
  const FakeAccount(
    this.role,
    this.name, {
    this.adminRole,
    this.doctorStatus,
    this.reason,
    this.blockCode,
    this.emailVerified = true,
    this.mustChangePassword = false,
    this.mustAcceptTerms = false,
    this.alsoAssistant = false,
  });

  final UserRole role;
  final String name;
  final String? adminRole;
  final DoctorStatus? doctorStatus;
  final String? reason;
  final String? blockCode;
  final bool emailVerified;
  final bool mustChangePassword;
  final bool mustAcceptTerms;

  /// The same number also has an assistant account ("log in as").
  final bool alsoAssistant;

  AuthSession session(String identifier) => AuthSession(
        userId: 'dev-${role.name}-${identifier.hashCode.abs()}',
        displayName: name,
        role: role,
        adminRole: adminRole,
        doctorId: switch (role) {
          UserRole.doctor => 'dev-doctor-${identifier.hashCode.abs()}',
          UserRole.assistant => 'dev-doctor',
          _ => null,
        },
        doctorStatus: doctorStatus,
        doctorStatusReason: reason,
        mustChangePassword: mustChangePassword,
        mustAcceptTerms: mustAcceptTerms,
        email: identifier.contains('@') ? identifier : null,
        emailVerified: emailVerified,
        phone: identifier.startsWith('+') ? identifier : null,
        accessToken: 'dev-access-token',
        refreshToken: 'dev-refresh-token',
      );
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useFakeAuth) return FakeAuthRepository();
  return ApiAuthRepository(ref.watch(dioProvider), ref.watch(plainDioProvider));
});
