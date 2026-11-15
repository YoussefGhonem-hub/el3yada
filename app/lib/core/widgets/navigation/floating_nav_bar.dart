import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../pressable.dart';
import 'nav_item.dart';
import 'sliding_indicator.dart';

/// The phone's bottom navigation (spec section 12): a floating pill 16 dp
/// from the screen edges and above the system gesture area.
///
/// - Pine in light mode, an elevated surface in dark mode, soft shadow.
/// - Every item keeps its icon and label. The selected item sits on a mint
///   pill that slides on a spring; its icon turns filled with a small bounce
///   and its label turns bold.
/// - Badges pop in; a tap gives a light haptic on Android and iOS.
/// - Item order and slide direction mirror in Arabic.
/// - Hides while the keyboard is open, and when [hidden] is set (the shell
///   sets it while content scrolls down).
///
/// Use it as `Scaffold.bottomNavigationBar` with `extendBody: true`, so
/// content scrolls behind the bar and lists get bottom padding from
/// `MediaQuery`.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.hidden = false,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool hidden;

  static const double barHeight = 64;
  static const double edgeMargin = 16;
  static const double maxBarWidth = 480;

  /// Space between the pill's edge and the indicator; it makes the
  /// indicator's round ends concentric with the bar's.
  static const double _padding = 6;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context).reduced;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final away = hidden || keyboardOpen;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final duration = away ? Motion.normalExit : Motion.normal;
    final curve = away ? Motion.exitCurve : Motion.enterCurve;

    return IgnorePointer(
      ignoring: away,
      child: ExcludeSemantics(
        excluding: away,
        child: AnimatedSlide(
          offset: away && !reduced ? const Offset(0, 1) : Offset.zero,
          duration: duration,
          curve: curve,
          child: AnimatedOpacity(
            opacity: away ? 0 : 1,
            duration: duration,
            curve: curve,
            child: Padding(
              padding: EdgeInsets.fromLTRB(edgeMargin, 0, edgeMargin, edgeMargin + bottomInset),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxBarWidth),
                  child: _pill(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context) {
    final colors = context.el3yadaColors;
    final shadow = Theme.of(context).colorScheme.shadow;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.navBar,
        shape: const StadiumBorder(),
        shadows: [
          BoxShadow(color: shadow.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: shadow.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: SizedBox(
        height: barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = (constraints.maxWidth - 2 * _padding) / items.length;
            return Stack(
              children: [
                SlidingIndicator(
                  index: selectedIndex,
                  axis: Axis.horizontal,
                  pitch: slot,
                  size: Size(slot, barHeight - 2 * _padding),
                  color: colors.navIndicator,
                  inset: const EdgeInsetsDirectional.only(start: _padding, top: _padding),
                ),
                Padding(
                  padding: const EdgeInsets.all(_padding),
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _BarItem(
                            item: items[i],
                            selected: i == selectedIndex,
                            onTap: () => _select(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _select(int index) {
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.lightImpact();
    }
    onSelected(index);
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final textTheme = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: navSemanticLabel(item, AppLocalizations.of(context)),
      selected: selected,
      pressedScale: 0.92,
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: selected ? colors.onNavIndicator : colors.onNavBar),
        duration: Motion.fast,
        curve: Motion.enterCurve,
        builder: (context, color, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NavItemIcon(
              item: item,
              selected: selected,
              color: color!,
              badgeRing: selected ? colors.onNavIndicator : colors.navBar,
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  maxLines: 1,
                  textScaler: navTextScaler(context),
                  style: textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
