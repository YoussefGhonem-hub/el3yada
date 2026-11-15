import 'package:doctory/core/platform/app_platform.dart';
import 'package:doctory/core/storage/token_store.dart';
import 'package:doctory/features/auth/application/auth_controller.dart';
import 'package:doctory/features/auth/data/auth_repository.dart';
import 'package:doctory/features/auth/domain/auth_exceptions.dart';
import 'package:doctory/features/auth/domain/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer makeContainer({required AppPlatform platform, TokenStore? store}) {
  final container = ProviderContainer(
    overrides: [
      appPlatformProvider.overrideWithValue(platform),
      tokenStoreProvider.overrideWithValue(store ?? MemoryTokenStore()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(delay: Duration.zero)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts signed out', () async {
    final container = makeContainer(platform: AppPlatform.mobile);
    expect(await container.read(authControllerProvider.future), isNull);
  });

  test('a doctor can sign in on desktop, and the session is saved', () async {
    final store = MemoryTokenStore();
    final container = makeContainer(platform: AppPlatform.desktop, store: store);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).login('doctor@doctory.dev', 'dev');

    expect(container.read(authControllerProvider).value?.role, UserRole.doctor);
    expect((await store.read())?.role, UserRole.doctor);
  });

  test('a patient cannot sign in on desktop', () async {
    final store = MemoryTokenStore();
    final container = makeContainer(platform: AppPlatform.desktop, store: store);
    await container.read(authControllerProvider.future);

    await expectLater(
      container.read(authControllerProvider.notifier).login('+201000000002', 'dev'),
      throwsA(isA<RoleNotAllowedOnPlatformException>()),
    );
    expect(container.read(authControllerProvider).value, isNull);
    expect(await store.read(), isNull);
  });

  test('a patient can sign in on mobile', () async {
    final container = makeContainer(platform: AppPlatform.mobile);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).login('+201000000002', 'dev');

    expect(container.read(authControllerProvider).value?.role, UserRole.patient);
  });

  test('wrong password throws InvalidCredentialsException', () async {
    final container = makeContainer(platform: AppPlatform.mobile);
    await container.read(authControllerProvider.future);

    await expectLater(
      container.read(authControllerProvider.notifier).login('doctor@doctory.dev', 'wrong'),
      throwsA(isA<InvalidCredentialsException>()),
    );
  });

  test('a saved patient session is dropped on desktop', () async {
    final store = MemoryTokenStore();
    final mobile = makeContainer(platform: AppPlatform.mobile, store: store);
    await mobile.read(authControllerProvider.future);
    await mobile.read(authControllerProvider.notifier).login('+201000000002', 'dev');

    final desktop = makeContainer(platform: AppPlatform.desktop, store: store);
    expect(await desktop.read(authControllerProvider.future), isNull);
    expect(await store.read(), isNull);
  });
}
