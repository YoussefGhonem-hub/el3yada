import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// The app's page transition (spec section 12, "Screen transitions"), set for
/// every platform in `AppTheme`. Any `MaterialPage` or `MaterialPageRoute`
/// (a go_router `GoRoute` with `builder:`) gets it automatically:
/// forward and back slide along a horizontal shared axis, mirrored in Arabic.
/// With reduced motion it is a plain fade.
///
/// Note: replacing the platform default also replaces the iOS edge swipe to go
/// back. Put `CupertinoPageTransitionsBuilder` back for `TargetPlatform.iOS`
/// in `AppTheme` if that gesture matters more than the shared axis.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.slow;

  @override
  Duration get reverseTransitionDuration => Motion.slowExit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      DirectionalSharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        child: child,
      );
}

/// Horizontal shared-axis transition from the `animations` package that
/// follows the reading direction: new screens come from the end side
/// (the left in Arabic) and back goes the other way.
///
/// The package always slides as in left-to-right, so in right-to-left the
/// transition is mirrored and the child mirrored back: only the movement flips,
/// never the content.
class DirectionalSharedAxisTransition extends StatelessWidget {
  const DirectionalSharedAxisTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.of(context).reduced) {
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: Motion.enterCurve)),
        child: child,
      );
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    Widget mirror(Widget widget) => rtl ? Transform.flip(flipX: true, child: widget) : widget;
    return mirror(
      SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondaryAnimation,
        transitionType: SharedAxisTransitionType.horizontal,
        fillColor: Theme.of(context).colorScheme.surface,
        child: mirror(child),
      ),
    );
  }
}
