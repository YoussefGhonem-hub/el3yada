import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../app_logo.dart';
import '../pressable.dart';
import 'nav_item.dart';

/// Desktop navigation (1024 dp and up): the stub of the queue ticket.
///
/// A pine panel that floats beside the page, cut from it by a perforated
/// tear line along its inner edge, with a notch where the line meets the
/// top and the bottom (the tear line of `TicketCard`). The selected item
/// sits on the mint pill, and a hole punched in the tear line marks its
/// row; both slide to a new item on a spring (with reduced motion they
/// crossfade). A short dashed rule splits the items before each index in
/// [breaks].
///
/// [header] (the brand, [SideMenuBrand]) sits above the items and [footer]
/// (the account, [SideMenuAccount]) below them; the items scroll between
/// the two when the window is short.
class AppSideMenu extends StatelessWidget {
  const AppSideMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.header,
    this.footer,
    this.breaks = const {},
  });

  final List<NavItem> items;

  /// -1 when no item matches the current screen.
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget? header;
  final Widget? footer;

  /// Item indexes that start a new group.
  final Set<int> breaks;

  /// The stub's width, without the space around it.
  static const double width = 264;

  /// Space between the stub and the window's edges.
  static const double margin = 12;

  /// The tear line runs this far in from the stub's inner edge.
  static const double tearInset = 14;

  /// Half-circle notches where the tear line meets the top and the bottom.
  static const double notchRadius = 9;

  /// The selected pill and the punched hole, for tests.
  static const indicatorKey = ValueKey('side-menu-indicator');

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(margin, margin, 0, margin),
      child: SizedBox(
        width: width,
        child: PhysicalShape(
          clipper: _StubShape(rtl: rtl),
          color: colors.navBar,
          elevation: 4,
          shadowColor: AppColors.pine.withValues(alpha: 0.3),
          child: CustomPaint(
            painter: _TearLinePainter(rtl: rtl, color: colors.onNavBar.withValues(alpha: 0.32)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?header,
                Expanded(
                  child: _MenuItems(
                    items: items,
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                    breaks: breaks,
                  ),
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded panel with two notches on the tear line.
class _StubShape extends CustomClipper<Path> {
  const _StubShape({required this.rtl});

  final bool rtl;

  static const _outer = Radius.circular(26);
  static const _inner = Radius.circular(6);

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    // The inner edge (towards the page) has small corners, so the notches
    // sit on a straight edge; the outer corners are round.
    final panel = Path()
      ..addRRect(RRect.fromRectAndCorners(
        rect,
        topLeft: rtl ? _inner : _outer,
        bottomLeft: rtl ? _inner : _outer,
        topRight: rtl ? _outer : _inner,
        bottomRight: rtl ? _outer : _inner,
      ));
    final x = _tearX(size.width, rtl);
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: AppSideMenu.notchRadius))
      ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: AppSideMenu.notchRadius));
    return Path.combine(PathOperation.difference, panel, notches);
  }

  @override
  bool shouldReclip(_StubShape oldClipper) => oldClipper.rtl != rtl;
}

double _tearX(double width, bool rtl) => rtl ? AppSideMenu.tearInset : width - AppSideMenu.tearInset;

/// The dashed tear line between the two notches.
class _TearLinePainter extends CustomPainter {
  const _TearLinePainter({required this.rtl, required this.color});

  final bool rtl;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final x = _tearX(size.width, rtl);
    final dash = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashLength = 6.0;
    const gap = 5.0;
    var y = AppSideMenu.notchRadius + 8;
    while (y + dashLength < size.height - AppSideMenu.notchRadius - 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dashLength), dash);
      y += dashLength + gap;
    }
  }

  @override
  bool shouldRepaint(_TearLinePainter oldDelegate) => oldDelegate.rtl != rtl || oldDelegate.color != color;
}

class _MenuItems extends StatelessWidget {
  const _MenuItems({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.breaks,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Set<int> breaks;

  static const double row = 44;
  static const double gap = 2;
  static const double groupGap = 19;

  /// Items start here; they end before the tear line's lane.
  static const double start = 12;
  static const double end = AppSideMenu.tearInset * 2;

  @override
  Widget build(BuildContext context) {
    final tops = <double>[];
    var y = 0.0;
    for (var i = 0; i < items.length; i++) {
      if (i > 0 && breaks.contains(i)) y += groupGap;
      tops.add(y);
      y += row + gap;
    }
    final height = items.isEmpty ? 0.0 : y - gap;
    final ruleColor = context.el3yadaColors.onNavBar.withValues(alpha: 0.28);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            _Indicator(index: selectedIndex, tops: tops),
            for (final i in breaks)
              if (i > 0 && i < items.length)
                PositionedDirectional(
                  top: tops[i] - groupGap / 2 - gap / 2,
                  start: start + 16,
                  end: end + 16,
                  height: 1.5,
                  child: CustomPaint(painter: _RulePainter(ruleColor)),
                ),
            for (var i = 0; i < items.length; i++)
              PositionedDirectional(
                top: tops[i],
                start: start,
                end: end,
                height: row,
                child: _MenuRow(
                  item: items[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A short dashed rule between groups of items.
class _RulePainter extends CustomPainter {
  const _RulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 0.0; x + 4 <= size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RulePainter oldDelegate) => oldDelegate.color != color;
}

/// The mint pill behind the selected row and the hole punched in the tear
/// line beside it. They travel together.
class _Indicator extends StatefulWidget {
  const _Indicator({required this.index, required this.tops});

  final int index;
  final List<double> tops;

  @override
  State<_Indicator> createState() => _IndicatorState();
}

class _IndicatorState extends State<_Indicator> {
  /// Where the marker rests while nothing is selected (it fades out there).
  double _lastTop = 0;

  static const double _punch = 5.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final ground = Theme.of(context).colorScheme.surface;
    final reduced = Motion.of(context).reduced;
    final index = widget.index;
    if (index >= 0 && index < widget.tops.length) _lastTop = widget.tops[index];
    final top = _lastTop;

    Widget marker(double y) => Stack(
          children: [
            PositionedDirectional(
              top: y,
              start: _MenuItems.start,
              end: _MenuItems.end,
              height: _MenuItems.row,
              child: DecoratedBox(
                decoration: ShapeDecoration(color: colors.navIndicator, shape: const StadiumBorder()),
              ),
            ),
            // The punched hole shows the page through the stub.
            PositionedDirectional(
              top: y + _MenuItems.row / 2 - _punch,
              end: AppSideMenu.tearInset - _punch,
              width: _punch * 2,
              height: _punch * 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ground,
                  border: Border.all(color: colors.navIndicator, width: 2),
                ),
              ),
            ),
          ],
        );

    final Widget moving = reduced
        ? AnimatedSwitcher(
            duration: Motion.fast,
            reverseDuration: Motion.fastExit,
            switchInCurve: Motion.enterCurve,
            switchOutCurve: Motion.exitCurveReversed,
            child: KeyedSubtree(key: ValueKey(top), child: marker(top)),
          )
        : TweenAnimationBuilder<double>(
            tween: Tween(end: top),
            duration: Motion.normal,
            curve: Motion.spring,
            builder: (context, y, _) => marker(y),
          );

    return Positioned.fill(
      key: AppSideMenu.indicatorKey,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: index < 0 ? 0 : 1,
          duration: Motion.fast,
          child: RepaintBoundary(child: moving),
        ),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final textTheme = Theme.of(context).textTheme;
    final selected = widget.selected;
    final idle = _hovered ? Colors.white : colors.onNavBar;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _OnPine(
        child: Pressable(
          onTap: widget.onTap,
          semanticLabel: navSemanticLabel(widget.item, AppLocalizations.of(context)),
          selected: selected,
          pressedScale: 0.98,
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Motion.enterCurve,
            decoration: ShapeDecoration(
              // The mint pill (the indicator) shows through when selected.
              color: !selected && _hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: selected ? colors.onNavIndicator : idle),
              duration: Motion.fast,
              curve: Motion.enterCurve,
              builder: (context, color, _) => Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
                child: Row(
                  children: [
                    NavItemIcon(
                      item: widget.item,
                      showBadge: false,
                      selected: selected,
                      color: color!,
                      size: 22,
                      badgeRing: colors.navBar,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    NavBadgeView(
                      badge: widget.item.badge,
                      ring: selected ? colors.navIndicator : colors.navBar,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mint focus rings and light hover tints for controls on the pine stub.
class _OnPine extends StatelessWidget {
  const _OnPine({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.el3yadaColors;
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(primary: colors.navIndicator),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: colors.onNavBar,
            hoverColor: Colors.white.withValues(alpha: 0.1),
            highlightColor: Colors.white.withValues(alpha: 0.14),
            focusColor: Colors.white.withValues(alpha: 0.14),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// The top of the stub: the mark, which writes itself when the menu first
/// appears and beats once under the mouse, the app's name, and what the
/// user is working in (the clinic, or the admin area).
class SideMenuBrand extends StatelessWidget {
  const SideMenuBrand({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 22, AppSideMenu.tearInset * 2 + 4, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const AppLogoMark(
              size: 40,
              animate: true,
              beatOnHover: true,
              letterColor: Colors.white,
              plusColor: AppColors.mint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(color: Colors.white, height: 1.25),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: colors.navIndicator),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The bottom of the stub: who is signed in, their profile (when the role
/// has one) and Log out.
class SideMenuAccount extends StatefulWidget {
  const SideMenuAccount({
    super.key,
    required this.name,
    required this.initial,
    required this.role,
    required this.onSignOut,
    this.onProfile,
  });

  final String name;

  /// The letter in the avatar.
  final String initial;
  final String role;
  final VoidCallback onSignOut;

  /// Opens the user's profile; null when the role has none.
  final VoidCallback? onProfile;

  @override
  State<SideMenuAccount> createState() => _SideMenuAccountState();
}

class _SideMenuAccountState extends State<SideMenuAccount> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.el3yadaColors;
    final textTheme = Theme.of(context).textTheme;

    final person = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.navIndicator),
          child: Text(
            widget.initial,
            style: textTheme.titleMedium?.copyWith(color: colors.onNavIndicator, fontWeight: FontWeight.w600, height: 1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              Text(
                widget.role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: colors.onNavBar),
              ),
            ],
          ),
        ),
      ],
    );

    final onProfile = widget.onProfile;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, AppSideMenu.tearInset * 2, 16),
      child: _OnPine(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: onProfile == null
                      ? Padding(padding: const EdgeInsets.all(4), child: person)
                      : MouseRegion(
                          onEnter: (_) => setState(() => _hovered = true),
                          onExit: (_) => setState(() => _hovered = false),
                          child: Tooltip(
                            message: l10n.profileTopBarTooltip,
                            child: Pressable(
                              onTap: onProfile,
                              semanticLabel: '${widget.name}, ${l10n.profileTopBarTooltip}',
                              pressedScale: 0.97,
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: Motion.fast,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: person,
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l10n.logout,
                  onPressed: widget.onSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
