import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../auth/domain/user_role.dart';

typedef L10nLabel = String Function(AppLocalizations l10n);

/// One menu item. [screenId] points to the screen in spec.md.
class NavDestinationSpec {
  NavDestinationSpec({
    required this.path,
    required this.icon,
    required this.label,
    required this.screenId,
    this.primary = false,
  });

  final String path;
  final IconData icon;
  final L10nLabel label;
  final String screenId;

  /// Shown in the phone's bottom bar. Others go under "More" on phones and
  /// tablets. Desktop shows every item in the side menu.
  final bool primary;
}

/// The area each role lands in after sign-in (spec section 7.1).
class RoleShell {
  RoleShell({required this.role, required this.basePath, required this.destinations});

  final UserRole role;
  final String basePath;
  final List<NavDestinationSpec> destinations;

  String get homePath => destinations.first.path;
  String get morePath => '$basePath/more';

  List<NavDestinationSpec> get primary => destinations.where((d) => d.primary).toList();
  List<NavDestinationSpec> get secondary => destinations.where((d) => !d.primary).toList();

  static RoleShell forRole(UserRole role) => all.firstWhere((shell) => shell.role == role);

  static final List<RoleShell> all = [admin, doctor, assistant, patient];

  static final doctor = RoleShell(
    role: UserRole.doctor,
    basePath: '/doctor',
    destinations: [
      NavDestinationSpec(path: '/doctor/live', icon: Icons.monitor_heart_outlined, label: (l) => l.navLive, screenId: 'D34', primary: true),
      NavDestinationSpec(path: '/doctor/patients', icon: Icons.people_alt_outlined, label: (l) => l.navPatients, screenId: 'D4', primary: true),
      NavDestinationSpec(path: '/doctor/dashboard', icon: Icons.insights_outlined, label: (l) => l.navDashboard, screenId: 'D1', primary: true),
      NavDestinationSpec(path: '/doctor/chats', icon: Icons.chat_bubble_outline, label: (l) => l.navChats, screenId: 'D16', primary: true),
      NavDestinationSpec(path: '/doctor/appointments', icon: Icons.event_note_outlined, label: (l) => l.navAppointments, screenId: 'D30'),
      NavDestinationSpec(path: '/doctor/revenue', icon: Icons.trending_up, label: (l) => l.navRevenue, screenId: 'D35'),
      NavDestinationSpec(path: '/doctor/billing', icon: Icons.receipt_long_outlined, label: (l) => l.navBilling, screenId: 'D18'),
      NavDestinationSpec(path: '/doctor/branches', icon: Icons.store_mall_directory_outlined, label: (l) => l.navBranches, screenId: 'D28'),
      NavDestinationSpec(path: '/doctor/assistants', icon: Icons.badge_outlined, label: (l) => l.navAssistants, screenId: 'D25'),
      NavDestinationSpec(path: '/doctor/settings', icon: Icons.settings_outlined, label: (l) => l.navSettings, screenId: 'D24'),
    ],
  );

  // TODO(Phase 2): hide items the assistant has no permission for (section 6.10).
  static final assistant = RoleShell(
    role: UserRole.assistant,
    basePath: '/assistant',
    destinations: [
      NavDestinationSpec(path: '/assistant/live', icon: Icons.monitor_heart_outlined, label: (l) => l.navLive, screenId: 'AS1', primary: true),
      NavDestinationSpec(path: '/assistant/patients', icon: Icons.people_alt_outlined, label: (l) => l.navPatients, screenId: 'AS2', primary: true),
      NavDestinationSpec(path: '/assistant/chats', icon: Icons.chat_bubble_outline, label: (l) => l.navChats, screenId: 'AS9', primary: true),
      NavDestinationSpec(path: '/assistant/appointments', icon: Icons.event_note_outlined, label: (l) => l.navAppointments, screenId: 'AS13'),
      NavDestinationSpec(path: '/assistant/dashboard', icon: Icons.insights_outlined, label: (l) => l.navDashboard, screenId: 'AS18'),
      NavDestinationSpec(path: '/assistant/billing', icon: Icons.receipt_long_outlined, label: (l) => l.navBilling, screenId: 'AS10'),
      NavDestinationSpec(path: '/assistant/settings', icon: Icons.settings_outlined, label: (l) => l.navSettings, screenId: 'AS12'),
    ],
  );

  static final patient = RoleShell(
    role: UserRole.patient,
    basePath: '/patient',
    destinations: [
      NavDestinationSpec(path: '/patient/home', icon: Icons.home_outlined, label: (l) => l.navHome, screenId: 'P1', primary: true),
      NavDestinationSpec(path: '/patient/appointments', icon: Icons.event_note_outlined, label: (l) => l.navAppointments, screenId: 'P16', primary: true),
      NavDestinationSpec(path: '/patient/file', icon: Icons.folder_shared_outlined, label: (l) => l.navMedicalFile, screenId: 'P4', primary: true),
      NavDestinationSpec(path: '/patient/chat', icon: Icons.chat_bubble_outline, label: (l) => l.navChats, screenId: 'P11', primary: true),
      NavDestinationSpec(path: '/patient/account', icon: Icons.person_outline, label: (l) => l.navAccount, screenId: 'P14', primary: true),
    ],
  );

  static final admin = RoleShell(
    role: UserRole.admin,
    basePath: '/admin',
    destinations: [
      NavDestinationSpec(path: '/admin/dashboard', icon: Icons.insights_outlined, label: (l) => l.navDashboard, screenId: 'AD1', primary: true),
      NavDestinationSpec(path: '/admin/doctors', icon: Icons.medical_services_outlined, label: (l) => l.navDoctors, screenId: 'AD4', primary: true),
      NavDestinationSpec(path: '/admin/payments', icon: Icons.payments_outlined, label: (l) => l.navPayments, screenId: 'AD7', primary: true),
      NavDestinationSpec(path: '/admin/invoices', icon: Icons.receipt_long_outlined, label: (l) => l.navInvoices, screenId: 'AD9', primary: true),
      NavDestinationSpec(path: '/admin/signups', icon: Icons.how_to_reg_outlined, label: (l) => l.navSignups, screenId: 'AD2'),
      NavDestinationSpec(path: '/admin/accounts', icon: Icons.manage_search, label: (l) => l.navAccounts, screenId: 'AD11'),
      NavDestinationSpec(path: '/admin/specialties', icon: Icons.category_outlined, label: (l) => l.navSpecialties, screenId: 'AD19'),
      NavDestinationSpec(path: '/admin/catalogs', icon: Icons.library_books_outlined, label: (l) => l.navCatalogs, screenId: 'AD20'),
      NavDestinationSpec(path: '/admin/admins', icon: Icons.admin_panel_settings_outlined, label: (l) => l.navAdmins, screenId: 'AD14'),
      NavDestinationSpec(path: '/admin/audit', icon: Icons.history, label: (l) => l.navAuditLog, screenId: 'AD15'),
      NavDestinationSpec(path: '/admin/settings', icon: Icons.settings_outlined, label: (l) => l.navSettings, screenId: 'AD13'),
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
