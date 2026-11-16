import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/motion.dart';
import '../pressable.dart';

/// The one Back button of the app: a round white button with a rounded arrow
/// that points the reading direction's way back (it mirrors in Arabic).
///
/// Pressing it does what the system Back does: it pops the current screen,
/// asking first when that screen has unsaved changes (`PopScope`). When there
/// is nothing to pop (the screen was opened by link), it goes to [fallback].
///
/// Inside a role area the top bar shows it on every screen that isn't a menu
/// root (see `RoleScaffold`), so screens don't add their own. Screens outside
/// the role areas get it from their `AppBar`.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback, this.onPressed, this.size = 40});

  /// Where Back goes when there is nothing to pop.
  final String? fallback;

  /// Replaces the default behaviour.
  final VoidCallback? onPressed;

  final double size;

  /// Pops like the system Back, or goes to [fallback].
  static Future<void> goBack(BuildContext context, {String? fallback}) async {
    final router = GoRouter.maybeOf(context);
    final popped = router != null
        ? await router.routerDelegate.popRoute()
        : await Navigator.of(context).maybePop();
    if (!popped && fallback != null && context.mounted) context.go(fallback);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed ?? () => goBack(context, fallback: fallback),
        semanticLabel: tooltip,
        pressedScale: 0.88,
        borderRadius: BorderRadius.circular(size / 2),
        child: _BackFace(size: size, scheme: scheme),
      ),
    );
  }
}

class _BackFace extends StatefulWidget {
  const _BackFace({required this.size, required this.scheme});

  final double size;
  final ColorScheme scheme;

  @override
  State<_BackFace> createState() => _BackFaceState();
}

class _BackFaceState extends State<_BackFace> with SingleTickerProviderStateMixin {
  // The arrow slides in from the far side the first time it shows.
  late final AnimationController _enter = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enter.isDismissed) {
      if (Motion.of(context).reduced) {
        _enter.value = 1;
      } else {
        _enter.forward();
      }
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final arrow = AnimatedBuilder(
      animation: _enter,
      builder: (context, child) {
        final t = Motion.springBouncy.transform(_enter.value);
        return Transform.translate(
          offset: Offset((1 - t) * (rtl ? -10 : 10), 0),
          child: Opacity(opacity: _enter.value, child: child),
        );
      },
      child: Icon(Icons.arrow_back_rounded, size: 20, color: scheme.onSurface),
    );
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLowest,
        shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
        shadows: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: arrow,
    );
  }
}

/// Marks the content of a role area, whose top bar already shows Back on
/// every screen above a tab's root, including screens opened without an
/// address (a card that expands into its detail). Screen-level back buttons
/// (`ClinicBackButton`, `AdminBackButton`) hide inside it, so a screen never
/// shows two.
class ShellBackScope extends InheritedWidget {
  const ShellBackScope({super.key, required super.child});

  /// True inside a role area: its top bar handles Back.
  static bool handlesBack(BuildContext context) => context.getInheritedWidgetOfExactType<ShellBackScope>() != null;

  @override
  bool updateShouldNotify(ShellBackScope oldWidget) => false;
}
