import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/shell/placeholder_pages.dart';
import '../features/shell/role_scaffold.dart';
import '../features/shell/role_shells.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
}

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
                pageBuilder: (context, state) =>
                    NoTransitionPage(child: PlaceholderPage(destination: destination)),
              ),
            GoRoute(
              path: shell.morePath,
              pageBuilder: (context, state) => NoTransitionPage(child: MorePage(shell: shell)),
            ),
          ],
        ),
    ],
  );
});

/// Re-runs the router's redirect whenever the session changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}
