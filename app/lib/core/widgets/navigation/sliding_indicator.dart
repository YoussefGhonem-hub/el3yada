import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';

/// The mint pill behind the selected navigation item. It slides between
/// slots on a spring ([Motion.spring], [Motion.normal]), along [axis]; on a
/// horizontal axis it follows the reading direction, so in Arabic it slides
/// the mirrored way. With reduced motion it crossfades between slots.
///
/// Place it first in a `Stack` that also holds the items. Slot `i` starts at
/// `i × pitch` from the start edge, plus [inset].
class SlidingIndicator extends StatelessWidget {
  const SlidingIndicator({
    super.key,
    required this.index,
    required this.axis,
    required this.pitch,
    required this.size,
    required this.color,
    this.inset = EdgeInsetsDirectional.zero,
  });

  /// Selected slot, or -1 for none (the pill fades out).
  final int index;
  final Axis axis;

  /// Distance from one slot's start to the next.
  final double pitch;
  final Size size;
  final Color color;

  /// Offset of slot 0's pill from the stack's top-start corner.
  final EdgeInsetsDirectional inset;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context).reduced;
    final sign = axis == Axis.horizontal && Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    Offset offsetFor(double slot) =>
        axis == Axis.horizontal ? Offset(sign * slot * pitch, 0) : Offset(0, slot * pitch);

    final pill = RepaintBoundary(
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
        ),
      ),
    );

    final Widget moving;
    if (reduced) {
      moving = AnimatedSwitcher(
        duration: Motion.fast,
        reverseDuration: Motion.fastExit,
        switchInCurve: Motion.enterCurve,
        switchOutCurve: Motion.exitCurveReversed,
        child: Transform.translate(
          key: ValueKey(index),
          offset: offsetFor(index.toDouble()),
          child: pill,
        ),
      );
    } else {
      moving = TweenAnimationBuilder<double>(
        tween: Tween(end: index < 0 ? 0 : index.toDouble()),
        duration: Motion.normal,
        curve: Motion.spring,
        builder: (context, slot, child) => Transform.translate(offset: offsetFor(slot), child: child),
        child: pill,
      );
    }

    return PositionedDirectional(
      start: inset.start,
      top: inset.top,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: index < 0 ? 0 : 1,
          duration: Motion.fast,
          child: moving,
        ),
      ),
    );
  }
}
