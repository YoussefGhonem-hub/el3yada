/// Admin screen paths (role_shells.dart has the menu items; the screens are
/// registered in app/destination_pages.dart).
abstract final class AdminRoutes {
  /// AD2.
  static const signups = '/admin/signups';

  /// AD3, also the route of the `doctorRegistrationReceived` notification.
  static String signup(String doctorId) => '$signups/$doctorId';

  /// AD1.
  static const dashboard = '/admin/dashboard';

  /// AD4, and one doctor (AD5).
  static const doctors = '/admin/doctors';

  static String doctor(String doctorId) => '$doctors/$doctorId';

  /// AD7, and one payment's review (AD8).
  static const payments = '/admin/payments';

  static String payment(String paymentId) => '$payments/$paymentId';

  /// AD9, and one invoice (AD10).
  static const invoices = '/admin/invoices';

  static String invoice(String invoiceId) => '$invoices/$invoiceId';

  /// AD13.
  static const settings = '/admin/settings';

  /// AD18: under Settings, opened from the top bar's profile button.
  static const profile = '/admin/settings/profile';

  /// AD14 (super admins).
  static const admins = '/admin/admins';

  /// AD15.
  static const audit = '/admin/audit';

  /// AD19: specialty profiles, and one specialty's editor.
  static const specialties = '/admin/specialties';

  static String specialty(String specialtyId) => '$specialties/$specialtyId';

  /// AD20: catalog versions, custom items and doctor reports (also the route
  /// of the «بلاغ عن عنصر في الكتالوج» notification).
  static const catalogs = '/admin/catalogs';
}
