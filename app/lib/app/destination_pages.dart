import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_routes.dart';
import '../features/admin/presentation/admins/admin_users_screen.dart';
import '../features/admin/presentation/audit/audit_log_screen.dart';
import '../features/admin/presentation/profile/admin_profile_screen.dart';
import '../features/admin/presentation/settings/admin_settings_screen.dart';
import '../features/admin/presentation/signups/signup_requests_screen.dart';
import '../features/admin/presentation/signups/signup_review.dart';
import '../features/patients/clinic_routes.dart';
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
  ...clinicDestinationRoutes,
};

Widget destinationPage(BuildContext context, NavDestinationSpec destination) =>
    _destinationScreens[destination.path]?.call(context) ?? PlaceholderPage(destination: destination);

List<RouteBase> destinationRoutes(NavDestinationSpec destination) => _destinationRoutes[destination.path] ?? const [];
