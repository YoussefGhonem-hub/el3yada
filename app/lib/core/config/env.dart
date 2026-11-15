import 'package:flutter/services.dart' show appFlavor;

/// Build-time configuration, passed with `--dart-define-from-file`.
///
/// Android also has native flavors (different app ID and name), so pass the
/// matching `--flavor`. Windows has no flavors; the config file decides.
///
/// ```
/// flutter run --flavor dev --dart-define-from-file=config/dev.json
/// flutter build apk --flavor prod --dart-define-from-file=config/prod.json
/// flutter build windows --dart-define-from-file=config/prod.json
/// ```
abstract final class Env {
  /// `dev` or `prod`.
  static const String name = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Base URL of the ASP.NET Core Web API (spec section 9).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7001',
  );

  /// Use the offline test accounts instead of the real API.
  /// Defaults to true in dev, and is always off in prod.
  static const bool _useFakeAuth = bool.fromEnvironment(
    'USE_FAKE_AUTH',
    defaultValue: name != 'prod',
  );

  static bool get isProd => name == 'prod';

  static bool get useFakeAuth => _useFakeAuth && !isProd;

  /// Stops a build that mixes a native flavor with the other environment's
  /// config, for example `--flavor prod` with `config/dev.json`.
  static void checkFlavor() {
    final problem = flavorMismatch(flavor: appFlavor, env: name);
    if (problem != null) throw StateError(problem);
  }

  /// The error message when [flavor] and [env] disagree, otherwise null.
  /// Builds without a flavor (Windows, tests) always pass.
  static String? flavorMismatch({required String? flavor, required String env}) {
    if (flavor == null || flavor == env) return null;
    return 'Built with --flavor $flavor but config/$env.json. '
        'Use --dart-define-from-file=config/$flavor.json.';
  }
}
