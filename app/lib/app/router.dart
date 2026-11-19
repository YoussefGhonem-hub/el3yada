import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin_support/presentation/admin_support_screens.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/chat/chat_routes.dart';
import '../features/patient/presentation/patient_routes.dart';
import '../features/shell/placeholder_pages.dart';
import '../features/shell/role_scaffold.dart';
import '../features/shell/role_shells.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
}

/// Built screens, by path. Menu items without an entry show their placeholder.
final Map<String, GoRouterWidgetBuilder> _shellPages = {
  ...PatientRoutes.shellPages,
  ...ChatRoutes.shellPages,
  '/admin/accounts': (context, state) => const AccountsSupportScreen(),
  '/admin/deletion-requests': (context, state) => const DeletionRequestsScreen(),
};

/// Routes by session and role (spec A1). Each role only reaches its own area.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (auth.isLoading && !auth.hasValue) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final session = auth.value;
      if (session == null) {
        return location == AppRoutes.login ? null : AppRoutes.login;
      }

      // TODO(A9): send users with mustChangePassword to "Set new password".
      final shell = RoleShell.forRole(session.role);
      if (!location.startsWith(shell.basePath)) return shell.homePath;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      for (final shell in RoleShell.all)
        ShellRoute(
          builder: (context, state, child) => RoleScaffold(
            shell: shell,
            location: state.matchedLocation,
            child: child,
          ),
          routes: [
            for (final destination in shell.destinations)
              GoRoute(
                path: destination.path,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: _shellPages[destination.path]?.call(context, state) ?? PlaceholderPage(destination: destination),
                ),
              ),
            // Shell pages that aren't menu items, such as the patient's account (avatar).
            for (final entry in _shellPages.entries)
              if (entry.key.startsWith('${shell.basePath}/') && !shell.destinations.any((d) => d.path == entry.key))
                GoRoute(
                  path: entry.key,
                  pageBuilder: (context, state) => NoTransitionPage(child: entry.value(context, state)),
                ),
            GoRoute(
              path: shell.morePath,
              pageBuilder: (context, state) => NoTransitionPage(child: MorePage(shell: shell)),
            ),
          ],
        ),
      // Detail screens, pushed full screen over the shell.
      ...PatientRoutes.detailRoutes,
      ...ChatRoutes.detailRoutes,
    ],
  );
});

/// Re-runs the router's redirect whenever the session changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}
