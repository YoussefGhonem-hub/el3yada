import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/shell/fade_through_branches.dart';
import '../features/shell/placeholder_pages.dart';
import '../features/shell/role_scaffold.dart';
import '../features/shell/role_shells.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
}

/// Routes by session and role (spec A1). Each role only reaches its own area.
///
/// Transitions (spec section 12):
/// - Pages built with `builder:` (a `MaterialPage`) slide along the
///   horizontal shared axis forward and back, mirrored in Arabic. That comes
///   from `AppPageTransitionsBuilder` in the theme; nothing to add per route.
/// - Each menu destination is its own branch of the role's
///   `StatefulShellRoute`, so switching tabs fades through
///   (`FadeThroughBranches`) and every tab keeps its state. Tab roots use
///   `NoTransitionPage`, because the branch container animates them.
/// - Detail screens go under their tab's `GoRoute` (`routes: [...]`) with
///   `builder:`; list → detail can also use `ContainerTransform`.
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
        StatefulShellRoute(
          builder: (context, state, navigationShell) => RoleScaffold(
            shell: shell,
            location: state.uri.path,
            child: navigationShell,
          ),
          navigatorContainerBuilder: (context, navigationShell, children) => FadeThroughBranches(
            currentIndex: navigationShell.currentIndex,
            children: children,
          ),
          branches: [
            for (final destination in shell.destinations)
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: destination.path,
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: PlaceholderPage(destination: destination),
                    ),
                  ),
                ],
              ),
            if (shell.secondary.isNotEmpty)
              StatefulShellBranch(
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
    ],
  );
});

/// Re-runs the router's redirect whenever the session changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}
