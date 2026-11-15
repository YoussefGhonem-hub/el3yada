import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Grows and shrinks with its child (spec section 12: content that appears
/// or goes away resizes smoothly). With reduced motion the size simply
/// changes: an `AnimatedSize` with a zero duration asserts when its child
/// changes size, so it isn't used then.
class MotionSize extends StatelessWidget {
  const MotionSize({
    super.key,
    required this.child,
    this.alignment = AlignmentDirectional.topStart,
    this.curve = Motion.standardCurve,
  });

  final Widget child;
  final AlignmentGeometry alignment;
  final Curve curve;

  @override
  Widget build(BuildContext context) => Motion.of(context).reduced
      ? child
      : AnimatedSize(duration: Motion.normal, curve: curve, alignment: alignment, child: child);
}
