import 'package:material_ui/material_ui.dart';

import '../../theme/motion.dart';
import 'side_menu.dart';

/// The top of every page on desktop, beside the side menu: Back at the start,
/// right above the page it leaves, and [trailing] controls (the branch
/// picker, quick settings) at the end. On a menu root there is no Back and
/// the start stays empty: the page's own title follows below.
///
/// Back arrives with a short fade and grow, and leaves the same way (a fade
/// alone with reduced motion).
class DesktopPageHeader extends StatelessWidget {
  const DesktopPageHeader({super.key, this.back, this.trailing = const []});

  /// The Back pill (`AppBackButton` with a label), or null on a menu root.
  final Widget? back;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context).reduced;
    return Padding(
      // Lines up with the side menu's top edge.
      padding: const EdgeInsetsDirectional.fromSTEB(24, AppSideMenu.margin, 20, 4),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.normal,
                reverseDuration: Motion.fastExit,
                switchInCurve: Motion.spring,
                switchOutCurve: Motion.exitCurveReversed,
                // With reduced motion Back only fades.
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: reduced
                      ? child
                      : ScaleTransition(
                          alignment: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
                          scale: animation.drive(Tween(begin: 0.85, end: 1)),
                          child: child,
                        ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [...previous, ?current],
                ),
                child: back ?? const SizedBox.shrink(key: ValueKey('no-back')),
              ),
            ),
            for (var i = 0; i < trailing.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              trailing[i],
            ],
          ],
        ),
      ),
    );
  }
}
