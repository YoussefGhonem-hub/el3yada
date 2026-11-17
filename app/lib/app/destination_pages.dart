import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_routes.dart';
import '../features/admin/presentation/admins/admin_users_screen.dart';
import '../features/admin/presentation/audit/audit_log_screen.dart';
import '../features/admin/presentation/profile/admin_profile_screen.dart';
import '../features/admin/presentation/settings/admin_settings_screen.dart';
import '../features/admin/presentation/signups/signup_requests_screen.dart';
import '../features/admin/presentation/signups/signup_review.dart';
import '../features/clinic/application/clinic_providers.dart';
import '../features/clinic/domain/clinic_permissions.dart';
import '../features/clinic_admin/clinic_admin_routes.dart';
import '../features/clinic_admin/presentation/activity/activity_log_screen.dart';
import '../features/clinic_admin/presentation/assistants/assistants_screen.dart';
import '../features/clinic_admin/presentation/branches/branch_editor_screen.dart';
import '../features/clinic_admin/presentation/branches/branches_screen.dart';
import '../features/clinic_admin/presentation/prices/visit_prices_screen.dart';
import '../features/clinic_admin/presentation/profile/doctor_profile_screen.dart';
import '../features/clinic_admin/presentation/settings/clinic_settings_screen.dart';
import '../features/patients/clinic_routes.dart';
import '../features/prescriptions/presentation/rx_settings_screen.dart';
import '../features/prescriptions/presentation/templates_screen.dart';
import '../features/shell/placeholder_pages.dart';
import '../features/shell/role_shells.dart';

/// The real screen behind each menu destination (role_shells.dart). A
/// destination not listed here shows a `PlaceholderPage`.
///
/// To add a screen, add its path here, and its detail screens (opened from
/// it, with Back) to [destinationRoutes]:
///
/// ```dart
/// '/admin/signups': (_) => const SignupRequestsScreen(),
/// ```
final Map<String, WidgetBuilder> _destinationScreens = {
  AdminRoutes.signups: (_) => const SignupRequestsScreen(),
  AdminRoutes.settings: (_) => const AdminSettingsScreen(),
  AdminRoutes.admins: (_) => const AdminUsersScreen(),
  AdminRoutes.audit: (_) => const AuditLogScreen(),
  // Clinic settings (D24, AS12), branches (D28), assistants (D25), activity (D27).
  ClinicAdminRoutes.doctorSettings: (_) => const ClinicSettingsScreen(),
  ClinicAdminRoutes.assistantSettings: (_) => const ClinicSettingsScreen(),
  ClinicAdminRoutes.branches: (_) => const BranchesScreen(),
  ClinicAdminRoutes.assistants: (_) => const AssistantsScreen(),
  ClinicAdminRoutes.activity: (_) => const ActivityLogScreen(),
  // D1–D9, AS1–AS5 (patients, sessions, fees).
  ...clinicDestinationScreens,
};

/// Detail routes under a destination, relative to it, for example
/// `GoRoute(path: ':doctorId', builder: ...)` under `/admin/signups`.
final Map<String, List<RouteBase>> _destinationRoutes = {
  // AD3 by link (the sign-up notification); AD2 opens it in place.
  AdminRoutes.signups: [
    GoRoute(
      path: ':doctorId',
      builder: (context, state) => SignupReviewPage(doctorId: state.pathParameters['doctorId']!),
    ),
  ],
  // AD18, opened from the profile button in the top bar.
  AdminRoutes.settings: [
    GoRoute(path: 'profile', builder: (context, state) => const AdminProfileScreen()),
  ],
  // D22 (also the top bar's profile button) and D37.
  ClinicAdminRoutes.doctorSettings: [
    GoRoute(path: 'profile', builder: (context, state) => const DoctorProfileScreen()),
    GoRoute(path: 'prices', builder: (context, state) => const VisitPricesScreen()),
    // D22 prescription header and print settings, D23 templates.
    GoRoute(path: 'rx', builder: (context, state) => const RxSettingsScreen()),
    GoRoute(path: 'templates', builder: (context, state) => const TemplatesScreen()),
  ],
  // D29: a new branch, or one branch (`?tab=hours` opens a tab).
  ClinicAdminRoutes.branches: [
    GoRoute(path: 'new', builder: (context, state) => const NewBranchScreen()),
    GoRoute(
      path: ':branchId',
      builder: (context, state) => BranchEditorScreen(
        branchId: state.pathParameters['branchId']!,
        initialTab: BranchEditorScreen.tabNamed(state.uri.queryParameters['tab']),
      ),
    ),
  ],
  // D26 on phones and by link (wide screens show it inside D25).
  ClinicAdminRoutes.assistants: [
    GoRoute(path: 'new', builder: (context, state) => const AssistantEditorPage()),
    GoRoute(
      path: ':assistantId',
      builder: (context, state) => AssistantEditorPage(assistantId: state.pathParameters['assistantId']),
    ),
  ],
  // AS19, only with pricesManage (spec 7.6): hidden, and refused by address.
  ClinicAdminRoutes.assistantSettings: [
    GoRoute(
      path: 'prices',
      redirect: (context, state) {
        final clinic = ProviderScope.containerOf(context, listen: false).read(clinicContextProvider).value;
        return clinic != null && !clinic.can(ClinicPermission.pricesManage) ? ClinicAdminRoutes.assistantSettings : null;
      },
      builder: (context, state) => const VisitPricesScreen(),
    ),
  ],
  ...clinicDestinationRoutes,
};

Widget destinationPage(BuildContext context, NavDestinationSpec destination) =>
    _destinationScreens[destination.path]?.call(context) ?? PlaceholderPage(destination: destination);

List<RouteBase> destinationRoutes(NavDestinationSpec destination) => _destinationRoutes[destination.path] ?? const [];
