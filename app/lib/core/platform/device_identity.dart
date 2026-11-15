import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../settings/app_settings.dart';

/// This install of the app, sent as `device` with every sign-in call. The API
/// ties the refresh token to it, registers the push token (UserDevices) and
/// refuses a patient on desktop (A14).
class DeviceIdentity {
  const DeviceIdentity({required this.deviceId, required this.platform, required this.appVersion});

  /// A random ID made on first launch and kept in the app's preferences.
  final String deviceId;

  /// `android`, `ios`, `windows` or `macos`; null on platforms the API doesn't
  /// know (Linux, web), and then no `device` is sent.
  final String? platform;

  /// `version` from pubspec.yaml, for example `1.2.0`.
  final String appVersion;

  /// The `device` object for sign-in calls, or null.
  Map<String, dynamic>? toJson({String? pushToken}) => platform == null
      ? null
      : {
          'deviceId': deviceId,
          'platform': platform,
          'appVersion': appVersion,
          'pushToken': ?pushToken,
        };

  static String? platformName(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.windows => 'windows',
        TargetPlatform.macOS => 'macos',
        _ => null,
      };
}

/// Overridden in tests.
final deviceIdentityProvider = FutureProvider<DeviceIdentity>((ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  const key = 'device.id';
  var id = prefs.getString(key);
  if (id == null) {
    final random = Random.secure();
    id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(key, id);
  }
  final info = await PackageInfo.fromPlatform();
  return DeviceIdentity(
    deviceId: id,
    platform: kIsWeb ? null : DeviceIdentity.platformName(defaultTargetPlatform),
    appVersion: info.version,
  );
});
