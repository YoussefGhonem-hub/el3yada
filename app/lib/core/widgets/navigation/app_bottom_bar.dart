import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../app_logo.dart';
import '../pressable.dart';
import 'nav_item.dart';

/// The phone's bottom navigation (spec section 12): a full-width pine bar
/// with rounded top corners, icons only, and the app's logo raised in the
/// middle.
///
/// - The logo opens [center] (the dashboard, or the home when the user has
///   none). It sits in a white disc cut into the bar's top edge, and glows
///   when its screen is open.
/// - Side items show their icon only (the label is the tooltip and what
///   screen readers hear). The selected icon turns filled and lights up in
///   mint with a soft glow and a small bounce; nothing behind it changes.
/// - Badges pop in; a tap gives a light haptic on Android and iOS.
/// - The items split evenly around the logo; order mirrors in Arabic.
/// - Hides while the keyboard is open, and when [hidden] is set (the shell
///   sets it while content scrolls down).
///
/// Use it as `Scaffold.bottomNavigationBar` with `extendBody: true`, so
/// content scrolls behind the bar and lists get bottom padding from
/// `MediaQuery`.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.center,
    this.hidden = false,
  });

  /// The icons on both sides of the logo, start side first.
  final List<NavItem> items;

  /// The selected side item, or -1 when none is (the logo's screen is open).
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The logo in the middle.
  final BottomBarCenter center;
  final bool hidden;

  static const double barHeight = 64;

  /// How far the logo's disc rises above the bar.
  static const double centerRise = 22;
  static const double centerSize = 62;

  /// The logo in the middle (for tests).
  static const centerKey = ValueKey('bottom-bar-center');

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context).reduced;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final away = hidden || keyboardOpen;
    final duration = away ? Motion.normalExit : Motion.slow;
    final curve = away ? Motion.exitCurve : Motion.spring;

    return IgnorePointer(
      ignoring: away,
      child: ExcludeSemantics(
        excluding: away,
        child: AnimatedSlide(
          offset: away && !reduced ? const Offset(0, 1.5) : Offset.zero,
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: away ? 0 : 1,
            duration: away ? Motion.normalExit : Motion.normal,
            curve: away ? Motion.exitCurve : Motion.enterCurve,
            child: _bar(context),
          ),
        ),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    final colors = context.el3yadaColors;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final half = (items.length + 1) ~/ 2;

    Widget side(int from, int to) => Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = from; i < to; i++)
                _BarIcon(item: items[i], selected: i == selectedIndex, onTap: () => _select(i)),
            ],
          ),
        );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.navBar,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, -4)),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SizedBox(
              height: barHeight,
              child: Row(
                children: [
                  side(0, half),
                  const SizedBox(width: centerSize + 16),
                  side(half, items.length),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -centerRise,
          child: _CenterLogo(center: center),
        ),
      ],
    );
  }

  void _select(int index) {
    if (index != selectedIndex) _haptic();
    onSelected(index);
  }
}

void _haptic() {
  if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
    HapticFeedback.lightImpact();
  }
}

/// What the logo in the middle of [AppBottomBar] opens.
@immutable
class BottomBarCenter {
  const BottomBarCenter({required this.label, required this.selected, required this.onTap});

  /// The screen's name: the tooltip, and what screen readers hear.
  final String label;

  /// Its screen is open.
  final bool selected;
  final VoidCallback onTap;
}

/// The app's logo in a white disc cut into the bar's top edge. It glows mint
/// and grows a little while its screen is open.
class _CenterLogo extends StatelessWidget {
  const _CenterLogo({required this.center});

  final BottomBarCenter center;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.el3yadaColors;
    final selected = center.selected;
    return Tooltip(
      message: center.label,
      child: Pressable(
        key: AppBottomBar.centerKey,
        onTap: () {
          if (!selected) _haptic();
          center.onTap();
        },
        semanticLabel: center.label,
        selected: selected,
        pressedScale: 0.9,
        borderRadius: BorderRadius.circular(AppBottomBar.centerSize / 2),
        child: AnimatedScale(
          scale: selected ? 1.06 : 1,
          duration: Motion.slow,
          curve: Motion.springBouncy,
          child: AnimatedContainer(
            duration: Motion.normal,
            curve: Motion.enterCurve,
            width: AppBottomBar.centerSize,
            height: AppBottomBar.centerSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerLowest,
              // The page colour around the disc makes it look cut into the bar.
              border: Border.all(color: scheme.surface, width: 5),
              boxShadow: [
                BoxShadow(
                  color: selected ? colors.navIndicator.withValues(alpha: 0.75) : colors.navBar.withValues(alpha: 0.28),
                  blurRadius: selected ? 22 : 12,
                  spreadRadius: selected ? 1 : 0,
                  offset: Offset(0, selected ? 0 : 4),
                ),
              ],
            ),
            child: const AppLogoMark(size: 34),
          ),
        ),
      ),
    );
  }
}

/// A side icon: outline when idle; filled, mint and glowing when selected.
class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    return Tooltip(
      message: item.label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: navSemanticLabel(item, AppLocalizations.of(context)),
        selected: selected,
        pressedScale: 0.85,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: SizedBox(
          width: 52,
          height: AppBottomBar.barHeight,
          child: Center(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: selected ? colors.navIndicator : colors.onNavBar.withValues(alpha: 0.75)),
              duration: Motion.normal,
              curve: Motion.enterCurve,
              builder: (context, color, _) => NavItemIcon(
                item: item,
                selected: selected,
                color: color!,
                size: 27,
                badgeRing: colors.navBar,
                shadows: selected ? [Shadow(color: colors.navIndicator.withValues(alpha: 0.8), blurRadius: 14)] : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
