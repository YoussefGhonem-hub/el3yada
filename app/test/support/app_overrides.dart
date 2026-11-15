import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/platform/device_identity.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/core/storage/token_store.dart';
import 'package:el3yada/features/auth/application/auth_controller.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

/// The overrides a test needs to run the whole app (or `AuthController`)
/// without a server, a device or plugins:
/// - preferences in memory (English, language already chosen, unless [prefs]
///   says otherwise),
/// - the offline accounts of [FakeAuthRepository] with no delay, and their
///   clinic from [FakeClinicRepository] (or [clinic]),
/// - public settings from [settings] (or [publicSettings] for more control),
/// - a fixed device on [platform] with [appVersion].
Future<List<Override>> appOverrides({
  AppPlatform platform = AppPlatform.mobile,
  Map<String, Object> prefs = const {'settings.locale': 'en'},
  PublicSettings settings = const PublicSettings(),
  FakePublicSettingsRepository? publicSettings,
  TokenStore? store,
  AuthRepository? auth,
  ClinicRepository? clinic,
  String appVersion = '1.0.0',
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(preferences),
    appPlatformProvider.overrideWithValue(platform),
    tokenStoreProvider.overrideWithValue(store ?? MemoryTokenStore()),
    authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository(delay: Duration.zero)),
    clinicRepositoryProvider.overrideWith(
      (ref) => clinic ?? FakeClinicRepository(ref.watch(authControllerProvider).value, delay: Duration.zero),
    ),
    publicSettingsRepositoryProvider.overrideWithValue(publicSettings ?? FakePublicSettingsRepository(settings)),
    deviceIdentityProvider.overrideWith(
      (ref) async => DeviceIdentity(
        deviceId: 'test-device',
        platform: platform.isDesktop ? 'windows' : 'android',
        appVersion: appVersion,
      ),
    ),
    ...extra,
  ];
}

/// Public settings without the API. Set [offline] to make `fetch` fail like
/// a phone without internet; [cachedCopy] is what `cached` returns then.
class FakePublicSettingsRepository implements PublicSettingsRepository {
  FakePublicSettingsRepository([this.settings = const PublicSettings()]);

  PublicSettings settings;
  bool offline = false;
  PublicSettings? cachedCopy;
  int fetches = 0;

  @override
  Future<PublicSettings> fetch() async {
    fetches++;
    if (offline) throw const ApiException(kind: ApiErrorKind.network);
    return settings;
  }

  @override
  PublicSettings? cached() => cachedCopy;
}
