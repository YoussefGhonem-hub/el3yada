import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings/app_settings.dart';
import '../core/theme/motion.dart';
import '../features/admin_support/presentation/admin_support_screens.dart';
import '../features/appointments/presentation/appointments_routes.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/auth_session.dart';
import '../features/auth/domain/user_role.dart';
import '../features/auth/presentation/blocked_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/language_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/set_password_screen.dart';
import '../features/auth/presentation/trial_ended_screen.dart';
import '../features/catalog/presentation/catalog_setup_screen.dart';
import '../features/catalog/presentation/catalog_sources_screen.dart';
import '../features/clinic/application/clinic_providers.dart';
import '../features/doctor_registration/presentation/registration_status_screens.dart';
import '../features/chat/chat_routes.dart';
import '../features/patient/presentation/patient_routes.dart';
import '../features/patients/domain/patient_models.dart' show LastVisitFilter;
import '../features/patients/presentation/patients_register_screen.dart';
import '../features/shell/fade_through_branches.dart';
import '../features/shell/placeholder_pages.dart';
import '../features/shell/role_scaffold.dart';
import '../features/shell/role_shells.dart';
import '../features/shell/shell_navigator_watch.dart';
import '../features/startup/presentation/legal_screen.dart';
import '../features/startup/presentation/maintenance_screen.dart';
import '../features/startup/presentation/update_screen.dart';
import '../features/startup/startup.dart';
import 'destination_pages.dart';
import 'routes.dart';

export 'routes.dart';

/// Screens built in Phases 4–6, by menu path. They take precedence over [destinationPage], so
/// the live board replaces the interim home of Phase 2. Menu items without an entry in either
/// show their placeholder.
final Map<String, GoRouterWidgetBuilder> _shellPages = {
  // D4 / AS2, optionally with a last-visit filter (`?lastVisit=notSeen6m`, the dashboard's C11 bars).
  for (final base in ['/doctor', '/assistant'])
    '$base/patients': (context, state) =>
        PatientsRegisterScreen(initialLastVisit: LastVisitFilter.values.asNameMap()[state.uri.queryParameters['lastVisit']]),
  ...PatientRoutes.shellPages,
  ...ChatRoutes.shellPages,
  ...AppointmentsRoutes.shellPages,
  '/admin/accounts': (context, state) => const AccountsSupportScreen(),
  '/admin/deletion-requests': (context, state) => const DeletionRequestsScreen(),
};

Widget _destinationScreen(BuildContext context, GoRouterState state, NavDestinationSpec destination) =>
    _shellPages[destination.path]?.call(context, state) ?? destinationPage(context, destination);

/// Routes by start-up checks, session, role and status (spec A1). Each role
/// only reaches its own area. The order of the checks is in [appRedirect].
///
/// Transitions (spec section 12):
/// - Pages built with `builder:` (a `MaterialPage`) slide along the
///   horizontal shared axis forward and back, mirrored in Arabic. That comes
///   from `AppPageTransitionsBuilder` in the theme; nothing to add per route.
/// - The splash and the login share one page (see `EntranceScreen`), so the
///   logo can rise from the splash into the login header.
/// - Each menu destination is its own branch of the role's
///   `StatefulShellRoute`, so switching tabs fades through
///   (`FadeThroughBranches`) and every tab keeps its state. Tab roots use
///   `NoTransitionPage`, because the branch container animates them.
/// - Detail screens go under their tab (destination_pages.dart) with
///   `builder:`; list → detail can also use `ContainerTransform`.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  // Each role area's top bar shows Back above a tab's root (RoleScaffold).
  final watches = {for (final shell in RoleShell.all) shell.role: ShellNavigatorWatch()};
  ref.onDispose(() {
    for (final watch in watches.values) {
      watch.dispose();
    }
  });

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(ref, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _entrancePage(showForm: false),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _entrancePage(showForm: true),
        routes: [
          GoRoute(path: 'forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
          GoRoute(path: 'register', builder: (context, state) => const RegistrationScreen()),
        ],
      ),
      GoRoute(path: AppRoutes.language, builder: (context, state) => const LanguageScreen()),
      GoRoute(path: AppRoutes.setPassword, builder: (context, state) => const SetPasswordScreen()),
      GoRoute(path: AppRoutes.verifyEmail, builder: (context, state) => const VerifyEmailScreen()),
      GoRoute(path: AppRoutes.pending, builder: (context, state) => const PendingApprovalScreen()),
      GoRoute(
        path: AppRoutes.rejected,
        builder: (context, state) => const RegistrationRejectedScreen(),
        routes: [
          GoRoute(path: 'edit', builder: (context, state) => const RegistrationScreen(resubmit: true)),
        ],
      ),
      GoRoute(path: AppRoutes.blocked, builder: (context, state) => const BlockedScreen()),
      GoRoute(path: AppRoutes.trialEnded, builder: (context, state) => const TrialEndedScreen()),
      GoRoute(path: AppRoutes.update, builder: (context, state) => const UpdateScreen()),
      GoRoute(path: AppRoutes.maintenance, builder: (context, state) => const MaintenanceScreen()),
      GoRoute(path: AppRoutes.terms, builder: (context, state) => const LegalScreen(document: LegalDocument.terms)),
      GoRoute(path: AppRoutes.privacy, builder: (context, state) => const LegalScreen(document: LegalDocument.privacy)),
      GoRoute(path: AppRoutes.dataSources, builder: (context, state) => const CatalogSourcesScreen()),
      GoRoute(path: AppRoutes.catalogSetup, builder: (context, state) => const CatalogSetupScreen()),
      for (final shell in RoleShell.all)
        StatefulShellRoute(
          builder: (context, state, navigationShell) => RoleScaffold(
            shell: shell,
            location: state.uri.path,
            navigatorWatch: watches[shell.role],
            branchIndex: navigationShell.currentIndex,
            child: navigationShell,
          ),
          navigatorContainerBuilder: (context, navigationShell, children) => FadeThroughBranches(
            currentIndex: navigationShell.currentIndex,
            children: children,
          ),
          branches: [
            for (final (index, destination) in shell.destinations.indexed)
              StatefulShellBranch(
                observers: [watches[shell.role]!.observerFor(index)],
                routes: [
                  GoRoute(
                    path: destination.path,
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: _destinationScreen(context, state, destination),
                    ),
                    routes: destinationRoutes(destination),
                  ),
                ],
              ),
            if (shell.secondary.isNotEmpty)
              StatefulShellBranch(
                observers: [watches[shell.role]!.observerFor(shell.destinations.length)],
                routes: [
                  GoRoute(
                    path: shell.morePath,
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: MorePage(shell: shell),
                    ),
                  ),
                ],
              ),
          ],
        ),
      // Detail screens, pushed full screen over the shell.
      ...PatientRoutes.detailRoutes,
      ...ChatRoutes.detailRoutes,
      ...AppointmentsRoutes.detailRoutes,
    ],
  );
});

/// Where [location] must go instead, or null to stay (spec A1). In order:
///
/// 1. Start-up still running, or the splash logo still drawing → splash.
/// 2. App too old → A11 (nothing else opens).
/// 3. Terms and Privacy (A12) open from anywhere.
/// 4. First launch → A2.
/// 5. Maintenance → A13, except for signed-in admins (and the login, so an
///    admin can sign in to turn it off).
/// 6. Sign-in refused (disabled account, inactive clinic) → A10.
/// 7. Signed out → the login and its sub-screens (A3, A4, A8).
/// 8. `mustChangePassword` → A9.
/// 9. Doctor waiting for approval → A6 (and A5); rejected → A7 (and A4 to resubmit).
/// 10. The clinic's free trial ended (doctor or assistant) → A15 only.
/// 11. A5 can open over the shell for a doctor (the "Verify your email"
///     banner and D24 push it; Back returns home). It stays open once the
///     email is verified, to show the success.
/// 11b. D0 (the catalog download) opens over the shell, except for patients.
/// 12. Otherwise the role's area,
/// 13. except an assistant's menu items without the permission.
String? appRedirect(Ref ref, String location) {
  bool at(String path) => location == path || location.startsWith('$path/');
  String? go(String path) => location == path ? null : path;

  final startup = ref.read(startupProvider);
  final auth = ref.read(authControllerProvider);
  if (!startup.hasValue && !startup.hasError || auth.isLoading && !auth.hasValue || !ref.read(splashGateProvider)) {
    return go(AppRoutes.splash);
  }

  final checks = startup.value ?? const StartupState();
  final session = auth.value;

  if (checks.updateRequired) return go(AppRoutes.update);
  if (at(AppRoutes.legal)) return null;
  if (session == null && !ref.read(appSettingsProvider).languageChosen) return go(AppRoutes.language);

  if (checks.maintenance && session?.role != UserRole.admin) {
    if (at(AppRoutes.maintenance) || session == null && at(AppRoutes.login)) return null;
    return AppRoutes.maintenance;
  }

  if (session == null) {
    if (ref.read(authBlockProvider) != null) return go(AppRoutes.blocked);
    return at(AppRoutes.login) ? null : AppRoutes.login;
  }

  if (session.mustChangePassword) return go(AppRoutes.setPassword);

  if (session.role == UserRole.doctor) {
    switch (session.doctorStatus) {
      case DoctorStatus.pendingApproval:
        return at(AppRoutes.pending) || at(AppRoutes.verifyEmail) ? null : AppRoutes.pending;
      case DoctorStatus.rejected:
        return at(AppRoutes.rejected) ? null : AppRoutes.rejected;
      case _:
        break;
    }
  }

  if ((session.role == UserRole.doctor || session.role == UserRole.assistant) && session.trialEnded) {
    return go(AppRoutes.trialEnded);
  }

  if (session.role == UserRole.doctor && at(AppRoutes.verifyEmail)) return null;

  // D0 opens over the role's area for those who keep the catalog (BR-CAT11).
  if (at(AppRoutes.catalogSetup)) return session.role == UserRole.patient ? RoleShell.forRole(session.role).homePath : null;

  final shell = RoleShell.forRole(session.role);
  if (!location.startsWith(shell.basePath)) return shell.homePath;

  // 13. An assistant's menu item without the permission can't be opened by
  //     its address either (spec 7.6), once the clinic has loaded. (Items
  //     hidden by `visibleTo`, like AD14, explain themselves on their screen.)
  final destination = shell.destinationAt(location);
  final clinic = ref.read(clinicContextProvider).value;
  if (destination?.visibleInClinic case final visible? when clinic != null && !visible(clinic)) {
    return shell.homePath;
  }
  return null;
}

/// The splash and the login page. Same class and same key for both, so the
/// Navigator updates the page in place when the splash becomes the login,
/// and `EntranceScreen` keeps its state to play the rise. Reached from
/// anywhere else (after logging out), it fades in.
Page<void> _entrancePage({required bool showForm}) => CustomTransitionPage<void>(
      key: EntranceScreen.pageKey,
      transitionDuration: Motion.normal,
      reverseTransitionDuration: Motion.normalExit,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      child: EntranceScreen(showForm: showForm),
    );

/// Re-runs the router's redirect whenever anything it reads changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    void notify(Object? previous, Object? next) => notifyListeners();
    ref.listen<AsyncValue<StartupState>>(startupProvider, notify);
    ref.listen<AsyncValue<AuthSession?>>(authControllerProvider, notify);
    ref.listen<String?>(authBlockProvider, notify);
    ref.listen<bool>(splashGateProvider, notify);
    ref.listen<bool>(appSettingsProvider.select((s) => s.languageChosen), notify);
    ref.listen<Set<String>?>(clinicContextProvider.select((c) => c.value?.permissions), notify);
  }
}
