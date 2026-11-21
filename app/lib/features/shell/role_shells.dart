import 'package:material_ui/material_ui.dart';

import '../../l10n/gen/app_localizations.dart';
import '../auth/domain/auth_session.dart';
import '../auth/domain/user_role.dart';
import '../clinic/domain/clinic_context.dart';
import '../clinic/domain/clinic_permissions.dart';

typedef L10nLabel = String Function(AppLocalizations l10n);

/// One menu item. [screenId] points to the screen in spec.md.
class NavDestinationSpec {
  NavDestinationSpec({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.screenId,
    this.primary = false,
    this.barLabel,
    this.visibleTo,
    this.visibleInClinic,
  });

  final String path;

  /// Outline icon; [selectedIcon] is the filled one shown when selected.
  final IconData icon;
  final IconData selectedIcon;
  final L10nLabel label;
  final String screenId;

  /// Shorter label for the phone bottom bar, when [label] doesn't fit there.
  final L10nLabel? barLabel;

  /// Shown in the phone's bottom bar. Others go under "More" on phones and
  /// tablets. Desktop shows every item in the side menu.
  final bool primary;

  /// Who sees this item; null for everyone in the role. A hidden item keeps
  /// its route, so its screen must still refuse a user who opens the
  /// address directly.
  final bool Function(AuthSession session)? visibleTo;

  /// For doctor and assistant items: who sees it, by the clinic's
  /// permissions (spec 6.10, 7.6: "hidden, not just disabled"). Hidden until
  /// the clinic has loaded.
  final bool Function(ClinicContext clinic)? visibleInClinic;

  bool isVisibleTo(AuthSession? session, {ClinicContext? clinic}) =>
      (visibleTo == null || session != null && visibleTo!(session)) &&
      (visibleInClinic == null || clinic != null && visibleInClinic!(clinic));

  /// The address is this item or one of its detail screens.
  bool covers(String location) => location == path || location.startsWith('$path/');
}

/// The area each role lands in after sign-in (spec section 7.1).
class RoleShell {
  RoleShell({required this.role, required this.basePath, required this.destinations, this.profilePath});

  final UserRole role;
  final String basePath;
  final List<NavDestinationSpec> destinations;

  /// The user's own profile, opened from the account button in the top
  /// bar. Null when the role has no such button yet.
  final String? profilePath;

  String get homePath => destinations.first.path;
  String get morePath => '$basePath/more';

  List<NavDestinationSpec> get primary => destinations.where((d) => d.primary).toList();
  List<NavDestinationSpec> get secondary => destinations.where((d) => !d.primary).toList();

  /// The items [session] may see (see [NavDestinationSpec.visibleTo] and
  /// [NavDestinationSpec.visibleInClinic]).
  List<NavDestinationSpec> visibleTo(AuthSession? session, {ClinicContext? clinic}) =>
      destinations.where((d) => d.isVisibleTo(session, clinic: clinic)).toList();

  /// The menu item [location] belongs to, or null (More, or outside the shell).
  NavDestinationSpec? destinationAt(String location) {
    for (final d in destinations) {
      if (d.covers(location)) return d;
    }
    return null;
  }

  /// Where the top bar's Back goes from [location], or null for no Back:
  /// - a screen below a menu item → that item (when there's nothing to pop);
  /// - an item that lives under More (phones and tablets) → More;
  /// - a menu root in the bar (also its middle logo, [center]) or the side
  ///   menu ([menuShowsAll]) → none.
  String? backTarget(String location, {required bool menuShowsAll, String? center}) {
    final destination = destinationAt(location);
    if (destination == null) return null;
    if (location != destination.path) return destination.path;
    if (!destination.primary && !menuShowsAll && destination.path != center) return morePath;
    return null;
  }

  /// The menu item behind the logo in the middle of the phone's bottom bar:
  /// the dashboard when the user may see it, otherwise the home.
  NavDestinationSpec centerOf(List<NavDestinationSpec> visible) =>
      visible.firstWhere((d) => d.path == '$basePath/dashboard', orElse: () => visible.first);

  static RoleShell forRole(UserRole role) => all.firstWhere((shell) => shell.role == role);

  static final List<RoleShell> all = [admin, doctor, assistant, patient];

  static final doctor = RoleShell(
    role: UserRole.doctor,
    basePath: '/doctor',
    // D22, under Settings.
    profilePath: '/doctor/settings/profile',
    destinations: [
      NavDestinationSpec(path: '/doctor/live', icon: Icons.monitor_heart_outlined, selectedIcon: Icons.monitor_heart, label: (l) => l.navLive, barLabel: (l) => l.navLiveShort, screenId: 'D34', primary: true),
      NavDestinationSpec(path: '/doctor/patients', icon: Icons.people_alt_outlined, selectedIcon: Icons.people_alt, label: (l) => l.navPatients, screenId: 'D4', primary: true),
      NavDestinationSpec(path: '/doctor/dashboard', icon: Icons.insights_outlined, selectedIcon: Icons.insights, label: (l) => l.navDashboard, screenId: 'D1', primary: true),
      NavDestinationSpec(path: '/doctor/chats', icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: (l) => l.navChats, screenId: 'D16', primary: true),
      NavDestinationSpec(path: '/doctor/appointments', icon: Icons.event_note_outlined, selectedIcon: Icons.event_note, label: (l) => l.navAppointments, screenId: 'D30'),
      NavDestinationSpec(path: '/doctor/revenue', icon: Icons.trending_up, selectedIcon: Icons.trending_up, label: (l) => l.navRevenue, screenId: 'D35'),
      NavDestinationSpec(path: '/doctor/billing', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: (l) => l.navBilling, screenId: 'D18'),
      NavDestinationSpec(path: '/doctor/branches', icon: Icons.store_mall_directory_outlined, selectedIcon: Icons.store_mall_directory, label: (l) => l.navBranches, screenId: 'D28'),
      NavDestinationSpec(path: '/doctor/assistants', icon: Icons.badge_outlined, selectedIcon: Icons.badge, label: (l) => l.navAssistants, screenId: 'D25'),
      NavDestinationSpec(path: '/doctor/activity', icon: Icons.manage_history_outlined, selectedIcon: Icons.manage_history, label: (l) => l.navActivityLog, screenId: 'D27'),
      NavDestinationSpec(path: '/doctor/notifications', icon: Icons.notifications_outlined, selectedIcon: Icons.notifications, label: (l) => l.navNotifications, screenId: 'D21'),
      NavDestinationSpec(path: '/doctor/settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: (l) => l.navSettings, screenId: 'D24'),
    ],
  );

  /// Items the assistant has no permission for are hidden (spec 7.1, 7.6).
  /// Home (AS1) shows the live board or today's sessions by permission.
  static final assistant = RoleShell(
    role: UserRole.assistant,
    basePath: '/assistant',
    destinations: [
      NavDestinationSpec(path: '/assistant/live', icon: Icons.monitor_heart_outlined, selectedIcon: Icons.monitor_heart, label: (l) => l.navLive, barLabel: (l) => l.navLiveShort, screenId: 'AS1', primary: true),
      NavDestinationSpec(path: '/assistant/patients', icon: Icons.people_alt_outlined, selectedIcon: Icons.people_alt, label: (l) => l.navPatients, screenId: 'AS2', primary: true),
      NavDestinationSpec(path: '/assistant/chats', icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: (l) => l.navChats, screenId: 'AS9', primary: true, visibleInClinic: (c) => c.can(ClinicPermission.chat)),
      NavDestinationSpec(path: '/assistant/appointments', icon: Icons.event_note_outlined, selectedIcon: Icons.event_note, label: (l) => l.navAppointments, screenId: 'AS13', visibleInClinic: (c) => c.can(ClinicPermission.appointmentsView)),
      NavDestinationSpec(path: '/assistant/dashboard', icon: Icons.insights_outlined, selectedIcon: Icons.insights, label: (l) => l.navDashboard, screenId: 'AS18', visibleInClinic: (c) => c.can(ClinicPermission.billingView) || c.can(ClinicPermission.revenueView) || c.can(ClinicPermission.appointmentsView)),
      NavDestinationSpec(path: '/assistant/billing', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: (l) => l.navBilling, screenId: 'AS10', visibleInClinic: (c) => c.can(ClinicPermission.billingView)),
      NavDestinationSpec(path: '/assistant/schedule', icon: Icons.schedule_outlined, selectedIcon: Icons.schedule, label: (l) => l.navSchedule, screenId: 'AS17', visibleInClinic: (c) => c.can(ClinicPermission.scheduleManage)),
      NavDestinationSpec(path: '/assistant/notifications', icon: Icons.notifications_outlined, selectedIcon: Icons.notifications, label: (l) => l.navNotifications, screenId: 'AS11'),
      NavDestinationSpec(path: '/assistant/settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: (l) => l.navSettings, screenId: 'AS12'),
    ],
  );

  static final patient = RoleShell(
    role: UserRole.patient,
    basePath: '/patient',
    destinations: [
      NavDestinationSpec(path: '/patient/home', icon: Icons.home_outlined, selectedIcon: Icons.home, label: (l) => l.navHome, screenId: 'P1', primary: true),
      NavDestinationSpec(path: '/patient/appointments', icon: Icons.event_note_outlined, selectedIcon: Icons.event_note, label: (l) => l.navAppointments, screenId: 'P16', primary: true),
      NavDestinationSpec(path: '/patient/file', icon: Icons.folder_shared_outlined, selectedIcon: Icons.folder_shared, label: (l) => l.navMedicalFile, screenId: 'P4', primary: true),
      NavDestinationSpec(path: '/patient/chat', icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: (l) => l.navChats, screenId: 'P11', primary: true),
      NavDestinationSpec(path: '/patient/account', icon: Icons.person_outline, selectedIcon: Icons.person, label: (l) => l.navAccount, screenId: 'P14', primary: true),
      NavDestinationSpec(path: '/patient/notifications', icon: Icons.notifications_outlined, selectedIcon: Icons.notifications, label: (l) => l.navNotifications, screenId: 'P13'),
    ],
  );

  static final admin = RoleShell(
    role: UserRole.admin,
    basePath: '/admin',
    profilePath: '/admin/settings/profile',
    destinations: [
      NavDestinationSpec(path: '/admin/dashboard', icon: Icons.insights_outlined, selectedIcon: Icons.insights, label: (l) => l.navDashboard, screenId: 'AD1', primary: true),
      NavDestinationSpec(path: '/admin/doctors', icon: Icons.medical_services_outlined, selectedIcon: Icons.medical_services, label: (l) => l.navDoctors, screenId: 'AD4', primary: true),
      NavDestinationSpec(path: '/admin/payments', icon: Icons.payments_outlined, selectedIcon: Icons.payments, label: (l) => l.navPayments, screenId: 'AD7', primary: true),
      NavDestinationSpec(path: '/admin/invoices', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: (l) => l.navInvoices, screenId: 'AD9', primary: true),
      NavDestinationSpec(path: '/admin/signups', icon: Icons.medical_information_outlined, selectedIcon: Icons.medical_information, label: (l) => l.navSignups, screenId: 'AD2'),
      NavDestinationSpec(path: '/admin/accounts', icon: Icons.manage_search, selectedIcon: Icons.manage_search, label: (l) => l.navAccounts, screenId: 'AD11'),
      NavDestinationSpec(path: '/admin/deletion-requests', icon: Icons.person_remove_outlined, selectedIcon: Icons.person_remove, label: (l) => l.navDeletionRequests, screenId: 'AD12'),
      NavDestinationSpec(path: '/admin/specialties', icon: Icons.category_outlined, selectedIcon: Icons.category, label: (l) => l.navSpecialties, screenId: 'AD19'),
      NavDestinationSpec(path: '/admin/catalogs', icon: Icons.library_books_outlined, selectedIcon: Icons.library_books, label: (l) => l.navCatalogs, screenId: 'AD20'),
      NavDestinationSpec(path: '/admin/admins', icon: Icons.admin_panel_settings_outlined, selectedIcon: Icons.admin_panel_settings, label: (l) => l.navAdmins, screenId: 'AD14', visibleTo: (s) => s.isSuperAdmin),
      NavDestinationSpec(path: '/admin/audit', icon: Icons.history, selectedIcon: Icons.history, label: (l) => l.navAuditLog, screenId: 'AD15'),
      NavDestinationSpec(path: '/admin/notifications', icon: Icons.notifications_outlined, selectedIcon: Icons.notifications, label: (l) => l.navNotifications, screenId: 'AD17'),
      NavDestinationSpec(path: '/admin/settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: (l) => l.navSettings, screenId: 'AD13'),
    ],
  );
}

extension UserRoleLabel on UserRole {
  String label(AppLocalizations l10n) => switch (this) {
        UserRole.admin => l10n.roleAdmin,
        UserRole.doctor => l10n.roleDoctor,
        UserRole.assistant => l10n.roleAssistant,
        UserRole.patient => l10n.rolePatient,
      };
}
