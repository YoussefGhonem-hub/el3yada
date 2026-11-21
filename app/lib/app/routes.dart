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

  /// A16: the account is in its deletion grace period (spec 6.17): restore,
  /// sign out, and a doctor's invoices (`invoices/{id}`, `invoices/{id}/pay`).
  static const restoreAccount = '/restore-account';

  /// A11.
  static const update = '/update';

  /// A13.
  static const maintenance = '/maintenance';

  /// A12: `/legal/terms` or `/legal/privacy`. Reachable from any screen.
  static const legal = '/legal';
  static const terms = '/legal/terms';
  static const privacy = '/legal/privacy';

  /// BR-CAT14: the data sources and their licences (LOINC, RSNA Playbook,
  /// the Egyptian drug dataset). Under /legal, so it opens from anywhere.
  static const dataSources = '/legal/sources';

  /// D0: the catalog download, over the role's area (doctors, admins and
  /// `prescriptionsDraft` assistants).
  static const catalogSetup = '/catalog-setup';
}
