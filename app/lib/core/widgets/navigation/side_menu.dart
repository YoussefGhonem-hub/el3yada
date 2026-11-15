import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../pressable.dart';
import 'nav_item.dart';
import 'sliding_indicator.dart';

/// Desktop navigation (1024 dp and up): every destination in a list, with
/// the same sliding mint indicator as the phone bar and the tablet rail.
/// [header] sits above the items (for example the signed-in name).
class AppSideMenu extends StatelessWidget {
  const AppSideMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.header,
  });

  final List<NavItem> items;

  /// -1 when no item matches the current screen.
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? header;

  static const double width = 256;
  static const double _row = 48;
  static const double _gap = 4;
  static const double _margin = 12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        width: width,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: _margin, vertical: 16),
          children: [
            ?header,
            Stack(
              children: [
                SlidingIndicator(
                  index: selectedIndex,
                  axis: Axis.vertical,
                  pitch: _row + _gap,
                  size: const Size(width - 2 * _margin, _row),
                  color: context.el3yadaColors.navIndicator,
                ),
                Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: SizedBox(
                          height: _row,
                          child: _MenuRow(
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
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.el3yadaColors;
    final textTheme = Theme.of(context).textTheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: navSemanticLabel(item, AppLocalizations.of(context)),
      selected: selected,
      pressedScale: 0.98,
      borderRadius: const BorderRadius.all(Radius.circular(24)),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: selected ? colors.onNavIndicator : scheme.onSurface),
        duration: Motion.fast,
        curve: Motion.enterCurve,
        builder: (context, color, _) => Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
          child: Row(
            children: [
              NavItemIcon(
                item: item,
                showBadge: false,
                selected: selected,
                color: color!,
                badgeRing: scheme.surfaceContainerLow,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              NavBadgeView(
                badge: item.badge,
                ring: selected ? colors.onNavIndicator : scheme.surfaceContainerLow,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
