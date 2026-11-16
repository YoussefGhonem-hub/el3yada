import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/gen/app_localizations.dart';
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
///
/// With a [label] (desktop, at the top of the page) it is a pill that names
/// where it goes: the arrow on a filled disc, then the section's name. Under
/// the mouse the pill tints and the arrow leans back.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallback, this.onPressed, this.size = 40, this.label});

  /// Where Back goes when there is nothing to pop.
  final String? fallback;

  /// Replaces the default behaviour.
  final VoidCallback? onPressed;

  final double size;

  /// The section Back returns to, shown next to the arrow.
  final String? label;

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
    final label = this.label;
    if (label != null) {
      return Tooltip(
        message: tooltip,
        child: _BackPill(
          label: label,
          semanticLabel: AppLocalizations.of(context).backToSection(label),
          size: size,
          onTap: onPressed ?? () => goBack(context, fallback: fallback),
        ),
      );
    }
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

/// The arrow sliding in from the far side, once, when Back first shows.
class _EnteringArrow extends StatefulWidget {
  const _EnteringArrow({required this.child, this.lean = 0});

  final Widget child;

  /// Extra travel backwards in dp (the hover lean).
  final double lean;

  @override
  State<_EnteringArrow> createState() => _EnteringArrowState();
}

class _EnteringArrowState extends State<_EnteringArrow> with SingleTickerProviderStateMixin {
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
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // Backwards is to the left in English, to the right in Arabic.
    final back = rtl ? 1.0 : -1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: Motion.of(context).reduced ? 0 : widget.lean),
      duration: Motion.fast,
      curve: Motion.spring,
      builder: (context, lean, child) => AnimatedBuilder(
        animation: _enter,
        builder: (context, child) {
          final t = Motion.springBouncy.transform(_enter.value);
          return Transform.translate(
            offset: Offset((1 - t) * -back * 10 + back * lean, 0),
            child: Opacity(opacity: _enter.value, child: child),
          );
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _BackPill extends StatefulWidget {
  const _BackPill({required this.label, required this.semanticLabel, required this.size, required this.onTap});

  final String label;
  final String semanticLabel;
  final double size;
  final VoidCallback onTap;

  @override
  State<_BackPill> createState() => _BackPillState();
}

class _BackPillState extends State<_BackPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = widget.size;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Pressable(
        onTap: widget.onTap,
        semanticLabel: widget.semanticLabel,
        pressedScale: 0.95,
        borderRadius: BorderRadius.circular(size / 2),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enterCurve,
          height: size,
          padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 18, 5),
          decoration: ShapeDecoration(
            color: _hovered ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.08), scheme.surfaceContainerLow) : scheme.surfaceContainerLow,
            shape: StadiumBorder(
              side: BorderSide(color: _hovered ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size - 10,
                height: size - 10,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary),
                child: _EnteringArrow(
                  lean: _hovered ? 3 : 0,
                  child: Icon(Icons.arrow_back_rounded, size: 18, color: scheme.onPrimary),
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
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
