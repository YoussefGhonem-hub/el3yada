/// Admin screen paths (role_shells.dart has the menu items; the screens are
/// registered in app/destination_pages.dart).
abstract final class AdminRoutes {
  /// AD2.
  static const signups = '/admin/signups';

  /// AD3, also the route of the `doctorRegistrationReceived` notification.
  static String signup(String doctorId) => '$signups/$doctorId';

  /// AD13.
  static const settings = '/admin/settings';

  /// AD18: under Settings, opened from the top bar's profile button.
  static const profile = '/admin/settings/profile';

  /// AD14 (super admins).
  static const admins = '/admin/admins';

  /// AD15.
  static const audit = '/admin/audit';
}
