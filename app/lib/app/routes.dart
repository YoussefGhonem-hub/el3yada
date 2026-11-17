/// Paths outside the role areas. Screens import this file, not router.dart.
///
/// Sign-in screens hang under `/login` so Back returns to the login form.
abstract final class AppRoutes {
  /// A1 (the same screen as the login, see `EntranceScreen`).
  static const splash = '/splash';

  /// A2, first launch only.
  static const language = '/language';

  /// A3.
  static const login = '/login';

  /// A8.
  static const forgotPassword = '/login/forgot-password';

  /// A4.
  static const register = '/login/register';

  /// A5 [S].
  static const verifyEmail = '/verify-email';

  /// A6.
  static const pending = '/pending';

  /// A7.
  static const rejected = '/rejected';

  /// A7 "Edit and resubmit": A4 filled with the submitted data.
  static const resubmit = '/rejected/edit';

  /// A9.
  static const setPassword = '/set-password';

  /// A10.
  static const blocked = '/blocked';

  /// A15: the clinic's free trial ended (spec 6.16).
  static const trialEnded = '/trial-ended';

  /// A11.
  static const update = '/update';

  /// A13.
  static const maintenance = '/maintenance';

  /// A12: `/legal/terms` or `/legal/privacy`. Reachable from any screen.
  static const legal = '/legal';
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';
}
