import 'package:dio/dio.dart';
import 'package:el3yada/core/network/api_client.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/platform/device_identity.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/core/storage/token_store.dart';
import 'package:el3yada/features/auth/application/auth_controller.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:el3yada/features/clinic/application/clinic_providers.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:el3yada/features/clinic_admin/data/clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/domain/assistant_models.dart';
import 'package:el3yada/features/patients/data/patients_repository.dart';
import 'package:el3yada/features/patients/domain/patient_models.dart';
import 'package:el3yada/features/sessions/data/sessions_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'contract_support.dart';

/// Phase 2 against a running API, through the app's own network stack: the
/// real `dioProvider` with its `AuthInterceptor`, `AuthController`, the token
/// store and `clinicContextProvider`, in a [ProviderContainer] with storage in
/// memory ([AppStack]). The other groups use a bare client; this one checks
/// what the app does by itself when the API refuses a call:
/// - a stale access token is refreshed (the refresh token rotates), and the
///   call goes through;
/// - after `PERMISSION_DENIED` or `DOCTOR_SUSPENDED` the clinic reloads;
/// - `ACCOUNT_DISABLED` signs the user out to A10.
///
/// Called by `api_contract_test.dart` after [ClinicDay] is filled in.
void appClient(ClinicDay day, {required String? skip}) {
  AppStack? doctorApp;
  AppStack? assistantApp;
  tearDownAll(() {
    doctorApp?.container.dispose();
    assistantApp?.container.dispose();
  });

  test('a stale access token is refreshed by the app, and the refresh token rotates', () async {
    final app = doctorApp = await AppStack.start(day.baseUrl!, 'contract-app-doctor-${day.run}');
    final result = await app.auth.login(day.doctorEmail, day.doctorPassword);
    expect(result, isA<SignedIn>());
    final signedIn = app.session!;
    expect(signedIn.role, UserRole.doctor);
    expect(signedIn.doctorId, day.doctorId);
    expect(await app.store.read(), signedIn);
    expect((await app.container.read(clinicContextProvider.future))!.doctor.id, day.doctorId);

    // Expired by the clock: refreshed before sending, so the API never sees it.
    await app.auth.acceptSession(
        signedIn.copyWith(accessTokenExpiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1))));
    app.calls.clear();
    final profile = await app.container.read(clinicAdminRepositoryProvider).doctorProfile();
    expect(profile.doctorId, day.doctorId);
    final refreshed = app.session!;
    expect(refreshed.refreshToken, isNot(signedIn.refreshToken));
    expect(refreshed.accessTokenExpiresAt!.isAfter(DateTime.now().toUtc()), isTrue);
    expect((await app.store.read())!.refreshToken, refreshed.refreshToken);
    expect(app.calls, ['POST /auth/refresh 200', 'GET /doctor/profile 200']);

    // Refused by the API (expired, outdated or forged: any 401 for a request
    // that carried a token): refreshed once, then sent again.
    await app.auth.acceptSession(refreshed.copyWith(accessToken: _forged(refreshed.accessToken)));
    app.calls.clear();
    final patient = await app.container.read(patientsRepositoryProvider).patient(day.patientId);
    expect(patient.patientId, day.patientId);
    final again = app.session!;
    expect(again.refreshToken, isNot(refreshed.refreshToken));
    expect(again.accessToken, isNot(_forged(refreshed.accessToken)));
    expect((await app.store.read())!.refreshToken, again.refreshToken);
    expect(app.calls, [
      'GET /patients/${day.patientId} 401 UNAUTHENTICATED',
      'POST /auth/refresh 200',
      'GET /patients/${day.patientId} 200',
    ]);
    // A token refresh doesn't reload the clinic.
    expect(app.container.read(clinicContextProvider).value!.doctor.id, day.doctorId);

    await app.auth.logout();
    expect(app.session, isNull);
    expect(await app.store.read(), isNull);
  }, skip: skip);

  late String assistantUserId;
  late String assistantPhone;

  test('an assistant\'s clinic reloads by itself after PERMISSION_DENIED', () async {
    final permissions = {...AssistantPreset.permissions[AssistantPreset.reception]!};
    final created = await day.doctor.clinicAdmin.createAssistant(AssistantDraft(
      fullName: 'ريم عادل',
      phone: contractMobile(),
      allBranches: true,
      branchIds: const {},
      permissions: permissions,
    ));
    assistantUserId = created.assistant.userId;
    assistantPhone = created.assistant.phone;

    final app = assistantApp = await AppStack.start(day.baseUrl!, 'contract-app-assistant-${day.run}');
    await app.auth.login(assistantPhone, created.temporaryPassword);
    expect(app.session!.mustChangePassword, isTrue);
    expect(await app.container.read(clinicContextProvider.future), isNull, reason: 'A9 first');
    await app.auth.setNewPassword('Assist1234');
    expect(app.session!.role, UserRole.assistant);
    final clinic = (await app.container.read(clinicContextProvider.future))!;
    expect(clinic.assistant!.userId, assistantUserId);
    expect(clinic.can(ClinicPermission.sessionsCreate), isTrue);

    permissions.remove(ClinicPermission.sessionsCreate);
    final changed = await day.doctor.clinicAdmin.updateAssistant(assistantUserId, permissions: permissions);
    expect(changed.permissions, permissions);
    final loads = app.clinicLoads;
    await expectLater(
      app.container.read(sessionsRepositoryProvider).newSessionInfo(patientId: day.patientId, branchId: day.maadiId),
      throwsA(apiError(403, ApiCodes.permissionDenied)
          .having((e) => e.details['permission'], 'permission', ClinicPermission.sessionsCreate)),
    );
    await app.until(() => app.container.read(clinicContextProvider).value?.can(ClinicPermission.sessionsCreate) == false);
    expect(app.clinicLoads, loads + 1, reason: 'the interceptor read clinic/me again');
    final reloaded = app.container.read(clinicContextProvider).value!;
    expect(reloaded.permissions, permissions);
    expect(reloaded.can(ClinicPermission.patientsManage), isTrue);
    expect(app.session, isNotNull, reason: 'still signed in');
  }, skip: skip);

  test('an assistant\'s clinic becomes suspended by itself after DOCTOR_SUSPENDED', () async {
    final app = assistantApp!;
    expect(app.container.read(clinicContextProvider).value!.isSuspended, isFalse);
    await day.admin.admin.setDoctorStatus(day.doctorId, suspended: true, reason: 'فاتورة نوفمبر غير مدفوعة');
    try {
      final loads = app.clinicLoads;
      await expectLater(
        app.container.read(patientsRepositoryProvider).createPatient(
            PatientDraft(fullName: 'رامي نبيل', gender: Gender.male, phone: contractMobile(), ageYears: 25)),
        throwsA(apiError(403, ApiCodes.doctorSuspended)),
      );
      await app.until(() => app.container.read(clinicContextProvider).value?.isSuspended == true);
      expect(app.clinicLoads, loads + 1);
      expect(app.container.read(clinicContextProvider).value!.doctor.status, 'suspended');
      expect(app.session, isNotNull, reason: 'a suspension doesn\'t sign anyone out');
    } finally {
      await day.admin.admin.setDoctorStatus(day.doctorId, suspended: false, reason: 'تم السداد');
    }
    // Reactivated: the next reload (on resume, or after the next refusal) shows it.
    await app.container.read(clinicContextProvider.notifier).reload();
    expect(app.container.read(clinicContextProvider).value!.isSuspended, isFalse);
  }, skip: skip);

  test('ACCOUNT_DISABLED signs the assistant out to A10', () async {
    final app = assistantApp!;
    await day.doctor.clinicAdmin.setAssistantStatus(assistantUserId, AssistantStatuses.disabled);
    try {
      await expectLater(
        app.container.read(patientsRepositoryProvider).register(const RegisterQuery()),
        throwsA(apiError(403, ApiCodes.accountDisabled)),
      );
      await app.until(() => app.session == null);
      expect(app.container.read(authBlockProvider), ApiCodes.accountDisabled);
      expect(await app.store.read(), isNull);
      expect(await app.container.read(clinicContextProvider.future), isNull);
      // Signing in again is refused the same way, and A10 stays.
      await expectLater(app.auth.login(assistantPhone, 'Assist1234'), throwsA(apiError(403, ApiCodes.accountDisabled)));
      expect(app.container.read(authBlockProvider), ApiCodes.accountDisabled);
    } finally {
      await day.doctor.clinicAdmin.setAssistantStatus(assistantUserId, AssistantStatuses.removed);
    }
  }, skip: skip);
}

/// The app's providers against the API at a base URL, with preferences and
/// the token store in memory and a fixed Android device. Only what a test
/// can't use is replaced: the build-time API address (`apiBaseUrlProvider`),
/// and the repositories, which dev and test builds point at the offline data
/// (`USE_FAKE_AUTH`): here they are the real `Api…` ones on `dioProvider`.
class AppStack {
  AppStack._(this.container, this.store);

  final ProviderContainer container;
  final MemoryTokenStore store;

  /// Every answer of both clients, oldest first: `GET /doctor/profile 200`,
  /// or `GET /patients/… 401 UNAUTHENTICATED` for a refusal.
  final calls = <String>[];

  /// How many times `GET /clinic/me` was answered.
  var clinicLoads = 0;

  AuthController get auth => container.read(authControllerProvider.notifier);

  AuthSession? get session => container.read(authControllerProvider).value;

  static Future<AppStack> start(String baseUrl, String deviceId) async {
    SharedPreferences.setMockInitialValues({'settings.locale': 'ar', 'settings.languageChosen': true});
    final preferences = await SharedPreferences.getInstance();
    final store = MemoryTokenStore();
    final container = ProviderContainer(overrides: [
      apiBaseUrlProvider.overrideWithValue(baseUrl),
      sharedPreferencesProvider.overrideWithValue(preferences),
      appPlatformProvider.overrideWithValue(AppPlatform.mobile),
      tokenStoreProvider.overrideWithValue(store),
      deviceIdentityProvider.overrideWith(
        (ref) async => DeviceIdentity(deviceId: deviceId, platform: 'android', appVersion: '1.0.0'),
      ),
      authRepositoryProvider.overrideWith((ref) => ApiAuthRepository(ref.watch(dioProvider), ref.watch(plainDioProvider))),
      clinicRepositoryProvider.overrideWith((ref) => ApiClinicRepository(ref.watch(dioProvider))),
      clinicAdminRepositoryProvider.overrideWith((ref) => ApiClinicAdminRepository(ref.watch(dioProvider))),
      patientsRepositoryProvider.overrideWith((ref) => ApiPatientsRepository(ref.watch(dioProvider))),
      sessionsRepositoryProvider.overrideWith((ref) => ApiSessionsRepository(ref.watch(dioProvider))),
    ]);
    final app = AppStack._(container, store);
    // First in line, so it sees every answer before AuthInterceptor acts on it.
    final recorder = InterceptorsWrapper(
      onResponse: (response, handler) {
        app._record(response.requestOptions, response.statusCode, null);
        handler.next(response);
      },
      onError: (error, handler) {
        app._record(error.requestOptions, error.response?.statusCode, ApiException.fromDio(error).code);
        handler.next(error);
      },
    );
    container.read(dioProvider).interceptors.insert(0, recorder);
    container.read(plainDioProvider).interceptors.insert(0, recorder);
    expect(await container.read(authControllerProvider.future), isNull);
    container.listen(clinicContextProvider, (previous, next) {});
    return app;
  }

  void _record(RequestOptions request, int? status, String? code) {
    if (request.path == '/clinic/me') clinicLoads++;
    calls.add([request.method, request.path, status, ?code].join(' '));
  }

  /// Waits (up to 10 seconds) for what the app does by itself after a call.
  Future<void> until(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) fail('The app did not get there in 10 seconds. Calls: $calls');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

/// The same token with another signature: the API refuses it (401
/// `UNAUTHENTICATED`), as it refuses an expired or outdated one.
String _forged(String token) {
  final parts = token.split('.');
  final signature = parts[2];
  parts[2] = '${signature[0] == 'A' ? 'B' : 'A'}${signature.substring(1)}';
  return parts.join('.');
}
