import 'dart:async';

import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/platform/device_identity.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/login_result.dart';
import '../domain/user_role.dart';

/// The current session: `null` when signed out.
///
/// At start-up it reads the saved session and asks the API for the account's
/// current state (A1), so a doctor approved while the app was closed lands on
/// the home screen, not on A6. Offline, the saved session is used as it is.
final authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// Why sign-in is refused (A10): `ACCOUNT_DISABLED` or `CLINIC_NOT_ACTIVE`.
/// Set by a refused login or refresh; cleared when the user leaves A10.
final authBlockProvider = NotifierProvider<AuthBlock, String?>(AuthBlock.new);

class AuthBlock extends Notifier<String?> {
  static const codes = {ApiCodes.accountDisabled, ApiCodes.clinicNotActive};

  @override
  String? build() => null;

  void set(String? code) => state = code;
}

class AuthController extends AsyncNotifier<AuthSession?> {
  Future<AuthSession?>? _refreshing;

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  @override
  Future<AuthSession?> build() async {
    // Language or theme changed while signed in: save it on the account too,
    // so push notifications arrive in the right language.
    ref.listen(appSettingsProvider, (previous, next) {
      if (previous == null || state.value == null) return;
      final locale = next.locale.languageCode == previous.locale.languageCode ? null : next.locale.languageCode;
      final theme = next.themeMode == previous.themeMode ? null : _themeName(next.themeMode);
      if (locale != null || theme != null) {
        _repository.updatePreferences(locale: locale, themeMode: theme).catchError((_) {});
      }
    });

    final saved = await _store.read();
    if (saved == null) return null;
    // A session saved on a platform that no longer allows the role is dropped.
    if (!ref.read(appPlatformProvider).allows(saved.role)) {
      await _store.clear();
      return null;
    }
    return _syncAtStartup(saved);
  }

  /// Signs in. Returns [ChooseAccount] when the user must pick "log in as".
  ///
  /// With [commit] false the session is checked but not yet used: the login
  /// screen shows its check mark first, then calls [acceptSession].
  ///
  /// Throws [ApiException]. For `ACCOUNT_DISABLED` and `CLINIC_NOT_ACTIVE` it
  /// also sets [authBlockProvider], and the router opens A10.
  Future<LoginResult> login(String identifier, String password, {bool commit = true}) async {
    final device = await _device();
    final result = await _guard(() => _repository.login(identifier: identifier, password: password, device: device));
    if (result is SignedIn) await _accept(result.session, commit: commit);
    return result;
  }

  /// "Log in as" (A3). [commit] as in [login].
  Future<AuthSession> selectAccount(String selectionToken, UserRole role, {bool commit = true}) async {
    final device = await _device();
    final session =
        await _guard(() => _repository.selectAccount(selectionToken: selectionToken, role: role, device: device));
    await _accept(session, commit: commit);
    return session;
  }

  /// Starts using [session]: from [login] with `commit: false`, or from
  /// another call that answers with one (doctor registration).
  Future<void> acceptSession(AuthSession session) => _accept(session);

  /// A9.
  Future<void> setNewPassword(String newPassword, {bool? acceptTerms}) async {
    final device = await _device();
    await _accept(await _repository.setNewPassword(newPassword: newPassword, acceptTerms: acceptTerms, device: device));
  }

  /// D22, P14, AS12, AD18. Other devices are signed out.
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final device = await _device();
    await _accept(await _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      device: device,
    ));
  }

  /// Fetches the account again (A6 "Refresh", after a 403 PASSWORD_CHANGE_REQUIRED).
  /// Throws [ApiException].
  Future<void> reloadAccount() async {
    final session = state.value;
    if (session == null) return;
    final account = await _repository.me();
    final current = state.value;
    if (current == null) return;
    final updated = current.withAccount(account);
    await _store.write(updated);
    state = AsyncData(updated);
  }

  /// New tokens for the current session; one refresh at a time, shared by
  /// every caller. Returns null when the session ended (the user is signed
  /// out). Throws [ApiException] when offline or on a server error, and the
  /// session is kept.
  Future<AuthSession?> refreshTokens() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  /// A request answered 403 `ACCOUNT_DISABLED` or `CLINIC_NOT_ACTIVE`: the
  /// session is over, and the router shows A10.
  Future<void> signOutBlocked(String code) => _signOutLocally(blockCode: code);

  Future<void> logout() async {
    final session = state.value;
    if (session != null) {
      final device = ref.read(deviceIdentityProvider).value;
      await _repository.logout(session, deviceId: device?.deviceId);
    }
    await _signOutLocally();
  }

  Future<AuthSession?> _refresh() async {
    final current = state.value;
    if (current == null) return null;
    try {
      final fresh = await _repository.refresh(current.refreshToken);
      await _store.write(fresh);
      state = AsyncData(fresh);
      return fresh;
    } on ApiException catch (error) {
      if (error.isNetwork || error.kind == ApiErrorKind.server) rethrow;
      await _signOutLocally(blockCode: error.code);
      return null;
    }
  }

  /// A1: refresh the saved session's account state before routing.
  Future<AuthSession?> _syncAtStartup(AuthSession saved) async {
    var session = saved;
    try {
      if (session.accessTokenExpiresWithin(const Duration(seconds: 30), DateTime.now().toUtc())) {
        session = await _repository.refresh(session.refreshToken);
      }
      try {
        session = session.withAccount(await _repository.me(accessToken: session.accessToken));
      } on ApiException catch (error) {
        if (error.status != 401) rethrow;
        session = await _repository.refresh(session.refreshToken);
        session = session.withAccount(await _repository.me(accessToken: session.accessToken));
      }
      await _store.write(session);
      return session;
    } on ApiException catch (error) {
      // Offline or the server is down: carry on with what was saved.
      if (error.isNetwork || error.kind == ApiErrorKind.server) return session;
      await _store.clear();
      if (AuthBlock.codes.contains(error.code)) ref.read(authBlockProvider.notifier).set(error.code);
      return null;
    }
  }

  Future<void> _accept(AuthSession session, {bool commit = true}) async {
    // Patients can't use the desktop app (A14). The API refuses too when the
    // device is sent; this covers builds that can't send one.
    if (!ref.read(appPlatformProvider).allows(session.role)) {
      await _repository.logout(session);
      throw const ApiException.local(ApiCodes.patientDesktopNotSupported);
    }
    if (!commit) return;
    ref.read(authBlockProvider.notifier).set(null);
    await _store.write(session);
    state = AsyncData(session);
    _pushPreferences(session);
  }

  /// The language and theme picked on this device win over the account's.
  void _pushPreferences(AuthSession session) {
    final settings = ref.read(appSettingsProvider);
    final locale = settings.locale.languageCode;
    final theme = _themeName(settings.themeMode);
    if (session.locale == locale && session.themeMode == theme) return;
    _repository.updatePreferences(locale: locale, themeMode: theme).catchError((_) {});
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (error) {
      if (AuthBlock.codes.contains(error.code)) ref.read(authBlockProvider.notifier).set(error.code);
      rethrow;
    }
  }

  Future<void> _signOutLocally({String? blockCode}) async {
    await _store.clear();
    ref.read(authBlockProvider.notifier).set(AuthBlock.codes.contains(blockCode) ? blockCode : null);
    state = const AsyncData(null);
  }

  Future<Map<String, dynamic>?> _device() async {
    try {
      return (await ref.read(deviceIdentityProvider.future)).toJson();
    } catch (_) {
      return null;
    }
  }

  static String _themeName(ThemeMode mode) => mode.name;
}
