import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../pressable.dart';
import 'nav_item.dart';
import 'sliding_indicator.dart';

/// Tablet navigation (600–1024 dp): a rail on the reading-start side with
/// the same sliding mint indicator, filled-icon bounce and badges as the
/// phone's floating bar.
class AppNavRail extends StatelessWidget {
  const AppNavRail({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double width = 96;
  static const double _slot = 72;
  static const double _gap = 4;
  static const double _margin = 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.el3yadaColors;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Stack(
            children: [
              SlidingIndicator(
                index: selectedIndex,
                axis: Axis.vertical,
                pitch: _slot + _gap,
                size: const Size(width - 2 * _margin, _slot),
                color: colors.navIndicator,
                inset: const EdgeInsetsDirectional.only(start: _margin),
              ),
              Column(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: _gap),
                      child: SizedBox(
                        width: width - 2 * _margin,
                        height: _slot,
                        child: _RailItem(
                          item: items[i],
                          selected: i == selectedIndex,
                          onTap: () => onSelected(i),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.el3yadaColors;
    return Pressable(
      onTap: onTap,
      semanticLabel: navSemanticLabel(item, AppLocalizations.of(context)),
      selected: selected,
      pressedScale: 0.94,
      borderRadius: const BorderRadius.all(Radius.circular(36)),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: selected ? colors.onNavIndicator : scheme.onSurfaceVariant),
        duration: Motion.fast,
        curve: Motion.enterCurve,
        builder: (context, color, _) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NavItemIcon(
              item: item,
              selected: selected,
              color: color!,
              badgeRing: selected ? colors.onNavIndicator : scheme.surfaceContainerLow,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textScaler: navTextScaler(context),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
