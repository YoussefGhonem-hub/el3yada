/// Paths of the clinic's own admin screens (role_shells.dart has the menu
/// items; the screens are registered in app/destination_pages.dart).
abstract final class ClinicAdminRoutes {
  /// D24.
  static const doctorSettings = '/doctor/settings';

  /// D22: under Settings, also the top bar's profile button.
  static const doctorProfile = '/doctor/settings/profile';

  /// D37.
  static const doctorPrices = '/doctor/settings/prices';

  /// D22 prescription header and print settings.
  static const doctorRxSettings = '/doctor/settings/rx';

  /// D23 [S] templates and favourites.
  static const doctorTemplates = '/doctor/settings/templates';

  /// AS12.
  static const assistantSettings = '/assistant/settings';

  /// AS19 (`pricesManage`).
  static const assistantPrices = '/assistant/settings/prices';

  /// D28.
  static const branches = '/doctor/branches';

  /// D29 for a new branch.
  static const newBranch = '/doctor/branches/new';

  /// D29, optionally on one tab (`?tab=hours`).
  static String branch(String branchId, {String? tab}) => tab == null ? '$branches/$branchId' : '$branches/$branchId?tab=$tab';

  /// D25.
  static const assistants = '/doctor/assistants';

  /// D26 for a new assistant.
  static const newAssistant = '/doctor/assistants/new';

  /// D26.
  static String assistant(String assistantId) => '$assistants/$assistantId';

  /// D27.
  static const activity = '/doctor/activity';

  /// Visit prices for the signed-in role.
  static String pricesFor({required bool doctor}) => doctor ? doctorPrices : assistantPrices;
}
