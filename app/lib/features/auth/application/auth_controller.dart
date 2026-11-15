import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/app_platform.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/auth_exceptions.dart';
import '../domain/auth_session.dart';

/// The current session: `null` when signed out.
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final store = ref.read(tokenStoreProvider);
    final saved = await store.read();
    if (saved == null) return null;
    // A session saved on a platform that no longer allows the role is dropped.
    if (!ref.read(appPlatformProvider).allows(saved.role)) {
      await store.clear();
      return null;
    }
    return saved;
  }

  /// Throws an [AuthException] when sign-in fails. The state stays signed out.
  Future<void> login(String identifier, String password) async {
    final repository = ref.read(authRepositoryProvider);
    final session = await repository.login(identifier: identifier, password: password);

    // Patients can't use the desktop app (spec section 4).
    if (!ref.read(appPlatformProvider).allows(session.role)) {
      await repository.logout(session);
      throw RoleNotAllowedOnPlatformException(session.role);
    }

    await ref.read(tokenStoreProvider).write(session);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    final session = state.value;
    if (session != null) {
      await ref.read(authRepositoryProvider).logout(session);
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AsyncData(null);
  }
}
