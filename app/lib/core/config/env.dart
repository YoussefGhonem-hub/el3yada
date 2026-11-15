/// Build-time configuration, passed with `--dart-define-from-file`.
///
/// ```
/// flutter run --dart-define-from-file=config/dev.json
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
}
