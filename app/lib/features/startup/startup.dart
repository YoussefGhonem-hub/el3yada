import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/platform/device_identity.dart';
import 'public_settings.dart';

/// A1 checks that run before routing: the minimum app version (A11) and
/// maintenance mode (A13). The session is checked by `AuthController`.
class StartupState {
  const StartupState({this.settings, this.settingsAreFresh = false, this.updateRequired = false});

  /// Fresh from the API, or the cached copy when offline (null on a first
  /// launch without internet).
  final PublicSettings? settings;
  final bool settingsAreFresh;

  /// A11: this app version is older than the minimum for the platform.
  final bool updateRequired;

  /// A13. Only from a fresh answer: a cached "maintenance" never locks the app.
  bool get maintenance => settingsAreFresh && (settings?.maintenanceEnabled ?? false);
}

final startupProvider = AsyncNotifierProvider<StartupController, StartupState>(StartupController.new);

class StartupController extends AsyncNotifier<StartupState> {
  static const timeout = Duration(seconds: 8);

  @override
  Future<StartupState> build() async {
    final repository = ref.read(publicSettingsRepositoryProvider);
    final identity = ref.read(deviceIdentityProvider.future).then<DeviceIdentity?>((v) => v, onError: (_) => null);

    PublicSettings? settings;
    var fresh = false;
    try {
      settings = await repository.fetch().timeout(timeout);
      fresh = true;
    } on ApiException {
      settings = repository.cached();
    } on TimeoutException {
      settings = repository.cached();
    }

    final device = await identity;
    return StartupState(
      settings: settings,
      settingsAreFresh: fresh,
      updateRequired: device != null && (settings?.requiresUpdate(device.platform, device.appVersion) ?? false),
    );
  }

  /// A13 "Retry". The previous answer stays on screen while this runs.
  void retry() => ref.invalidateSelf();
}

/// The public settings for screens (support contact, Terms, maintenance
/// message): fresh when start-up reached the API, otherwise the cached copy.
final publicSettingsProvider = Provider<PublicSettings?>(
  (ref) => ref.watch(startupProvider).value?.settings ?? ref.read(publicSettingsRepositoryProvider).cached(),
);

/// Holds the splash until its logo has drawn, so the brand moment plays once
/// in full and the login can pick the logo up where the splash left it.
/// Released at once with reduced motion.
final splashGateProvider = NotifierProvider<SplashGate, bool>(SplashGate.new);

class SplashGate extends Notifier<bool> {
  @override
  bool build() => false;

  void release() => state = true;
}
