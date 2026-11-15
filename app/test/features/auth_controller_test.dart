import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/storage/token_store.dart';
import 'package:el3yada/features/auth/application/auth_controller.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_overrides.dart';

Future<ProviderContainer> makeContainer({
  AppPlatform platform = AppPlatform.mobile,
  TokenStore? store,
  AuthRepository? auth,
}) async {
  final container = ProviderContainer(
    overrides: await appOverrides(platform: platform, store: store, auth: auth),
  );
  addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  return container;
}

Matcher throwsCode(String code) => throwsA(isA<ApiException>().having((e) => e.code, 'code', code));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('starts signed out', () async {
    final container = await makeContainer();
    expect(container.read(authControllerProvider).value, isNull);
  });

  test('a doctor can sign in on desktop, and the session is saved', () async {
    final store = MemoryTokenStore();
    final container = await makeContainer(platform: AppPlatform.desktop, store: store);

    final result = await container.read(authControllerProvider.notifier).login('doctor@el3yada.dev', 'dev');

    expect(result, isA<SignedIn>());
    expect(container.read(authControllerProvider).value?.role, UserRole.doctor);
    expect((await store.read())?.role, UserRole.doctor);
  });

  test('a patient cannot sign in on desktop (A14)', () async {
    final store = MemoryTokenStore();
    final container = await makeContainer(platform: AppPlatform.desktop, store: store);

    await expectLater(
      container.read(authControllerProvider.notifier).login('+201000000002', 'dev'),
      throwsCode(ApiCodes.patientDesktopNotSupported),
    );
    expect(container.read(authControllerProvider).value, isNull);
    expect(await store.read(), isNull);
  });

  test('a patient can sign in on mobile', () async {
    final container = await makeContainer();
    await container.read(authControllerProvider.notifier).login('+201000000002', 'dev');
    expect(container.read(authControllerProvider).value?.role, UserRole.patient);
  });

  test('wrong password throws INVALID_CREDENTIALS', () async {
    final container = await makeContainer();
    await expectLater(
      container.read(authControllerProvider.notifier).login('doctor@el3yada.dev', 'wrong'),
      throwsCode(ApiCodes.invalidCredentials),
    );
  });

  test('login with commit: false checks the session but does not sign in yet', () async {
    final container = await makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    final result = await controller.login('doctor@el3yada.dev', 'dev', commit: false);
    expect(container.read(authControllerProvider).value, isNull);

    await controller.acceptSession((result as SignedIn).session);
    expect(container.read(authControllerProvider).value?.role, UserRole.doctor);
  });

  test('one number with two accounts asks "log in as", then signs in as the chosen role', () async {
    final container = await makeContainer();
    final controller = container.read(authControllerProvider.notifier);

    final result = await controller.login('+201000000003', 'dev');
    expect(result, isA<ChooseAccount>());
    final choice = result as ChooseAccount;
    expect(choice.accounts.map((a) => a.role), [UserRole.patient, UserRole.assistant]);
    expect(container.read(authControllerProvider).value, isNull);

    await controller.selectAccount(choice.selectionToken, UserRole.assistant);
    expect(container.read(authControllerProvider).value?.role, UserRole.assistant);
  });

  test('a disabled account is refused and A10 is set', () async {
    final container = await makeContainer();
    await expectLater(
      container.read(authControllerProvider.notifier).login('disabled@el3yada.dev', 'dev'),
      throwsCode(ApiCodes.accountDisabled),
    );
    expect(container.read(authBlockProvider), ApiCodes.accountDisabled);
    expect(container.read(authControllerProvider).value, isNull);
  });

  test('setting a new password clears mustChangePassword (A9)', () async {
    final container = await makeContainer();
    final controller = container.read(authControllerProvider.notifier);
    await controller.login('+201000000004', 'dev');
    expect(container.read(authControllerProvider).value?.mustChangePassword, isTrue);

    await expectLater(controller.setNewPassword('newpass123'), throwsA(isA<ApiException>()));
    await controller.setNewPassword('newpass123', acceptTerms: true);

    expect(container.read(authControllerProvider).value?.mustChangePassword, isFalse);
  });

  test('a saved patient session is dropped on desktop', () async {
    final store = MemoryTokenStore();
    final mobile = await makeContainer(store: store);
    await mobile.read(authControllerProvider.notifier).login('+201000000002', 'dev');

    final desktop = await makeContainer(platform: AppPlatform.desktop, store: store);
    expect(desktop.read(authControllerProvider).value, isNull);
    expect(await store.read(), isNull);
  });

  group('at start-up', () {
    test('the saved session takes the account state from the API', () async {
      final store = MemoryTokenStore();
      await store.write(_doctor(status: DoctorStatus.pendingApproval));
      final auth = _ScriptedAuth(account: {'doctorStatus': 'active'});

      final container = await makeContainer(store: store, auth: auth);

      expect(container.read(authControllerProvider).value?.doctorStatus, DoctorStatus.active);
      expect((await store.read())?.doctorStatus, DoctorStatus.active);
    });

    test('offline, the saved session is used as it is', () async {
      final store = MemoryTokenStore();
      await store.write(_doctor(status: DoctorStatus.pendingApproval));
      final auth = _ScriptedAuth(meError: const ApiException(kind: ApiErrorKind.network));

      final container = await makeContainer(store: store, auth: auth);

      expect(container.read(authControllerProvider).value?.doctorStatus, DoctorStatus.pendingApproval);
    });

    test('an expired access token is refreshed, then the account is read', () async {
      final store = MemoryTokenStore();
      await store.write(_doctor(status: DoctorStatus.active));
      final auth = _ScriptedAuth(account: const {}, meError: const ApiException(kind: ApiErrorKind.http, status: 401));

      final container = await makeContainer(store: store, auth: auth);

      expect(auth.refreshes, 1);
      expect(container.read(authControllerProvider).value?.accessToken, 'fresh-access');
    });

    test('a disabled account is signed out and sent to A10', () async {
      final store = MemoryTokenStore();
      await store.write(_doctor(status: DoctorStatus.active));
      final auth = _ScriptedAuth(
        meError: const ApiException(kind: ApiErrorKind.http, status: 401),
        refreshError: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.accountDisabled),
      );

      final container = await makeContainer(store: store, auth: auth);

      expect(container.read(authControllerProvider).value, isNull);
      expect(container.read(authBlockProvider), ApiCodes.accountDisabled);
      expect(await store.read(), isNull);
    });
  });

  test('requests failing together share one refresh', () async {
    final store = MemoryTokenStore();
    await store.write(_doctor(status: DoctorStatus.active));
    final auth = _ScriptedAuth(account: const {});
    final container = await makeContainer(store: store, auth: auth);
    final controller = container.read(authControllerProvider.notifier);

    final results = await Future.wait([controller.refreshTokens(), controller.refreshTokens()]);

    expect(auth.refreshes, 1);
    expect(results.every((s) => s?.accessToken == 'fresh-access'), isTrue);
  });

  test('a refused refresh signs out', () async {
    final store = MemoryTokenStore();
    await store.write(_doctor(status: DoctorStatus.active));
    final auth = _ScriptedAuth(
      account: const {},
      refreshError: const ApiException(kind: ApiErrorKind.http, status: 401, code: ApiCodes.refreshTokenInvalid),
    );
    final container = await makeContainer(store: store, auth: auth);

    expect(await container.read(authControllerProvider.notifier).refreshTokens(), isNull);
    expect(container.read(authControllerProvider).value, isNull);
    expect(container.read(authBlockProvider), isNull);
  });
}

AuthSession _doctor({required DoctorStatus status}) => AuthSession(
      userId: 'u1',
      displayName: 'Dr. Test',
      role: UserRole.doctor,
      doctorStatus: status,
      accessToken: 'old-access',
      refreshToken: 'old-refresh',
    );

/// Answers `me` and `refresh` as scripted. `me` fails with [meError] only
/// the first time, like an expired token.
class _ScriptedAuth extends FakeAuthRepository {
  _ScriptedAuth({this.account = const {}, this.meError, this.refreshError}) : super(delay: Duration.zero);

  final Map<String, dynamic> account;
  ApiException? meError;
  final ApiException? refreshError;
  int refreshes = 0;

  @override
  Future<Map<String, dynamic>> me({String? accessToken}) async {
    final error = meError;
    if (error != null) {
      if (error.isNetwork) throw error;
      meError = null;
      throw error;
    }
    return account;
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    refreshes++;
    await Future<void>.delayed(Duration.zero);
    if (refreshError != null) throw refreshError!;
    return _doctor(status: DoctorStatus.active).copyWith(accessToken: 'fresh-access', refreshToken: 'fresh-refresh');
  }
}
