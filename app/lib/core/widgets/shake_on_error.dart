import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Shakes its child sideways once whenever [trigger] changes, for example
/// a form after wrong credentials (spec A3). Pass a counter you increment on
/// each failure so the same error twice still shakes.
///
/// ```dart
/// ShakeOnError(trigger: _failedAttempts, child: form)
/// ```
///
/// With reduced motion it doesn't move; show the error message as usual.
class ShakeOnError extends StatefulWidget {
  const ShakeOnError({super.key, required this.trigger, required this.child});

  /// Any value; a change starts one shake. Null never shakes.
  final Object? trigger;
  final Widget child;

  /// Widest swing in dp.
  static const double amplitude = 10;

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void didUpdateWidget(ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger && widget.trigger != null && !Motion.of(context).reduced) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Three swings that die away: sin(3 × 2π t) × (1 − t).
        final dx = math.sin(t * 6 * math.pi) * (1 - t) * ShakeOnError.amplitude;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
