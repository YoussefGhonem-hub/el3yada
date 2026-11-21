import 'package:material_ui/material_ui.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';

/// One destination in the bottom bar, the rail or the side menu.
@immutable
class NavItem {
  const NavItem({required this.icon, required this.selectedIcon, required this.label, this.badge});

  /// Outline icon, shown when not selected.
  final IconData icon;

  /// Filled icon, shown when selected.
  final IconData selectedIcon;
  final String label;
  final NavBadge? badge;
}

/// An unread count or a "new" dot on a [NavItem].
@immutable
sealed class NavBadge {
  const NavBadge();

  /// A count; 0 or less shows nothing, more than 99 shows "99+". [label] is
  /// what screen readers hear ("3 unread" when null).
  const factory NavBadge.count(int count, {NavCountLabel? label}) = NavCountBadge;

  /// A dot without a number.
  const factory NavBadge.dot() = NavDotBadge;

  /// What screen readers hear after the item's label, or null for nothing.
  String? describe(AppLocalizations l10n);
}

/// What a count badge means, for screen readers ("3 waiting for review").
typedef NavCountLabel = String Function(AppLocalizations l10n, int count);

final class NavCountBadge extends NavBadge {
  const NavCountBadge(this.count, {this.label});

  final int count;
  final NavCountLabel? label;

  String get text => count > 99 ? '99+' : '$count';

  @override
  String? describe(AppLocalizations l10n) =>
      count > 0 ? (label?.call(l10n, count) ?? l10n.navBadgeUnread(count)) : null;

  @override
  bool operator ==(Object other) => other is NavCountBadge && other.count == count && other.label == label;

  @override
  int get hashCode => Object.hash(count, label);
}

final class NavDotBadge extends NavBadge {
  const NavDotBadge();

  @override
  String? describe(AppLocalizations l10n) => l10n.navBadgeNew;

  @override
  bool operator ==(Object other) => other is NavDotBadge;

  @override
  int get hashCode => 0;
}

/// Screen-reader label for an item: "Chats, 3 unread".
String navSemanticLabel(NavItem item, AppLocalizations l10n) {
  final badge = item.badge?.describe(l10n);
  return badge == null ? item.label : l10n.navItemWithBadge(item.label, badge);
}

/// The item's icon: outline when idle, filled with a small bounce when it
/// becomes selected, and its badge in the top end corner.
class NavItemIcon extends StatefulWidget {
  const NavItemIcon({
    super.key,
    required this.item,
    required this.selected,
    required this.color,
    required this.badgeRing,
    this.showBadge = true,
    this.size = 24,
    this.shadows,
  });

  final NavItem item;
  final bool selected;
  final Color color;

  final double size;

  /// A glow around the icon (the bottom bar's selected icon).
  final List<Shadow>? shadows;

  /// False when the badge is shown elsewhere (the side menu puts it at the end).
  final bool showBadge;

  /// Colour of the thin ring that separates the badge from what is behind it.
  final Color badgeRing;

  @override
  State<NavItemIcon> createState() => _NavItemIconState();
}

class _NavItemIconState extends State<NavItemIcon> with SingleTickerProviderStateMixin {
  // A quick swell then a spring back: 1 → 1.18 → 1.
  late final AnimationController _bounce = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _scale = _bounce.drive(
    TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Motion.enterCurve)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0).chain(CurveTween(curve: Motion.springBouncy)), weight: 70),
    ]),
  );

  @override
  void didUpdateWidget(NavItemIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected && !Motion.of(context).reduced) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = AnimatedSwitcher(
      duration: Motion.fast,
      reverseDuration: Motion.fastExit,
      switchInCurve: Motion.enterCurve,
      switchOutCurve: Motion.exitCurveReversed,
      child: Icon(
        widget.selected ? widget.item.selectedIcon : widget.item.icon,
        key: ValueKey(widget.selected),
        color: widget.color,
        size: widget.size,
        shadows: widget.shadows,
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ScaleTransition(scale: _scale, child: icon),
        if (widget.showBadge)
          PositionedDirectional(
            top: -3,
            end: -6,
            child: NavBadgeView(badge: widget.item.badge, ring: widget.badgeRing),
          ),
      ],
    );
  }
}

/// A coral badge that pops in with a spring when it appears and pops again
/// when its count changes. With reduced motion it fades instead.
class NavBadgeView extends StatefulWidget {
  const NavBadgeView({super.key, required this.badge, required this.ring});

  final NavBadge? badge;
  final Color ring;

  static bool isVisible(NavBadge? badge) => switch (badge) {
        NavCountBadge(:final count) => count > 0,
        NavDotBadge() => true,
        null => false,
      };

  @override
  State<NavBadgeView> createState() => _NavBadgeViewState();
}

class _NavBadgeViewState extends State<NavBadgeView> {
  /// The last visible badge, kept on screen while it pops out.
  NavBadge? _shown;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final reduced = Motion.of(context).reduced;
    final ring = widget.ring;
    final visible = NavBadgeView.isVisible(widget.badge);
    if (visible) _shown = widget.badge;

    final Widget face = switch (_shown) {
      NavCountBadge(:final text) => Container(
          key: ValueKey(text),
          constraints: const BoxConstraints(minWidth: 18),
          height: 18,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: colors.attention,
            shape: StadiumBorder(side: BorderSide(color: ring, width: 2)),
          ),
          child: Text(
            text,
            // Numbers read left to right in both languages.
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: colors.onAttention,
              fontSize: 10,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      NavDotBadge() || null => Container(
          key: const ValueKey('dot'),
          width: 10,
          height: 10,
          decoration: ShapeDecoration(
            color: colors.attention,
            shape: CircleBorder(side: BorderSide(color: ring, width: 2)),
          ),
        ),
    };

    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: visible ? 1 : 0),
        duration: visible ? Motion.slow : Motion.fastExit,
        curve: visible ? (reduced ? Motion.enterCurve : Motion.springBouncy) : Motion.exitCurve,
        builder: (context, t, child) {
          if (t <= 0) return const SizedBox.shrink();
          final opacity = t.clamp(0.0, 1.0);
          return reduced
              ? Opacity(opacity: opacity, child: child)
              : Opacity(opacity: opacity, child: Transform.scale(scale: t, child: child));
        },
        child: AnimatedSwitcher(
          duration: Motion.fast,
          reverseDuration: Motion.fastExit,
          switchInCurve: reduced ? Motion.enterCurve : Motion.springBouncy,
          switchOutCurve: Motion.exitCurveReversed,
          transitionBuilder: (child, animation) => reduced
              ? FadeTransition(opacity: animation, child: child)
              : ScaleTransition(scale: animation, child: child),
          child: face,
        ),
      ),
    );
  }
}

/// Nav labels stay readable at large text sizes without breaking the bar.
TextScaler navTextScaler(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
