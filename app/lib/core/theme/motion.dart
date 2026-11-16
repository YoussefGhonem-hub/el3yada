import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Motion tokens (spec section 12, "Motion and visual polish").
///
/// Every duration and curve in the app comes from here; never type a
/// `Duration` or a curve inline in a widget. Read the reduced-motion switch
/// with [Motion.of]:
///
/// ```dart
/// final motion = Motion.of(context);
/// if (motion.reduced) { /* plain fade or nothing */ }
/// ```
///
/// When the device asks for reduced motion (`MediaQuery.disableAnimations`),
/// entrances and decorative motion become a plain fade or nothing, while
/// state changes (loading → content, selection) still crossfade.
@immutable
final class Motion {
  const Motion._({required this.reduced});

  /// Motion as designed.
  static const full = Motion._(reduced: false);

  /// The device asked for reduced motion.
  static const reducedMotion = Motion._(reduced: true);

  /// The single reduced-motion switch. Every animated widget reads it.
  static Motion of(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ? reducedMotion : full;

  /// True when entrances and decorative motion must be skipped.
  final bool reduced;

  /// Whether endless decorative loops run: the brand backdrop's drifting
  /// lights and the logo's heartbeat. Tests turn it off
  /// (test/flutter_test_config.dart) so `pumpAndSettle` can settle.
  static bool ambientLoops = true;

  /// True when an endless decorative loop may run here.
  bool get loops => ambientLoops && !reduced;

  // ---------------------------------------------------------------------------
  // Durations

  /// Presses and toggles.
  static const fast = Duration(milliseconds: 150);

  /// State changes and the navigation bar.
  static const normal = Duration(milliseconds: 250);

  /// Screen entrances and signature moments.
  static const slow = Duration(milliseconds: 400);

  /// Exits take about 65% of the matching entrance.
  static const fastExit = Duration(milliseconds: 100);
  static const normalExit = Duration(milliseconds: 160);
  static const slowExit = Duration(milliseconds: 260);

  /// Pressed feedback lands within 100 ms.
  static const press = fastExit;

  /// Gap between list or grid items entering. Only the first
  /// [staggerCount] items stagger.
  static const staggerStep = Duration(milliseconds: 40);
  static const staggerCount = 8;

  /// How long after a list appears its items still play their entrance.
  /// Items built later (scrolled into view) appear without one.
  static const staggerWindow = Duration(milliseconds: 40 * staggerCount + 250);

  /// Actions that finish faster than this show no loader.
  static const loaderDelay = Duration(milliseconds: 300);

  /// How far content travels when it enters (spec: 8–16 dp).
  static const double entranceDistance = 12;

  // ---------------------------------------------------------------------------
  // Curves

  /// Arrivals: decelerate (Material emphasized decelerate).
  static const Curve enterCurve = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Exits on an animation that runs forward: accelerate.
  static const Curve exitCurve = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Exits on an animation that runs in reverse, such as the outgoing child
  /// of an `AnimatedSwitcher` (`switchOutCurve`) or a `reverseCurve`.
  static const Curve exitCurveReversed = FlippedCurve(exitCurve);

  /// Moves between two places on screen.
  static const Curve standardCurve = Curves.easeInOutCubicEmphasized;

  /// Arrivals with a gentle settle: the navigation indicator, presses.
  static const Curve spring = SpringCurve(bounce: 0.25);

  /// A small, visible bounce: badges, the selected icon, the logo's plus.
  static const Curve springBouncy = SpringCurve(bounce: 0.5);

  // ---------------------------------------------------------------------------
  // Helpers that respect reduced motion

  /// Delay before item [index] enters. Zero with reduced motion.
  Duration staggerDelay(int index) =>
      reduced ? Duration.zero : staggerStep * math.min(index, staggerCount - 1);

  /// Whether item [index] of a list plays an entrance at all.
  bool staggers(int index) => index < staggerCount;

  /// Entrance length: [slow] for screens, [normal] for items. With reduced
  /// motion, entrances are a short plain fade.
  Duration entrance({bool item = false}) => reduced ? fast : (item ? normal : slow);

  /// Entrance travel in dp; zero with reduced motion.
  double get entranceOffset => reduced ? 0 : entranceDistance;
}

/// A spring as a [Curve], so it can drive any tween.
///
/// [bounce] 0 is critically damped (no overshoot); 0.25 overshoots by about
/// 3%, 0.5 by about 16%. The spring settles within the animation's duration
/// and always ends exactly at 1.
class SpringCurve extends Curve {
  const SpringCurve({this.bounce = 0.25}) : assert(bounce >= 0 && bounce < 1);

  final double bounce;

  static const double _omega = 2 * math.pi;

  double _position(double t) {
    final zeta = 1 - bounce;
    if (zeta >= 1) {
      return 1 - math.exp(-_omega * t) * (1 + _omega * t);
    }
    final damped = _omega * math.sqrt(1 - zeta * zeta);
    final decay = math.exp(-zeta * _omega * t);
    return 1 - decay * (math.cos(damped * t) + (zeta * _omega / damped) * math.sin(damped * t));
  }

  @override
  double transformInternal(double t) => _position(t) + t * (1 - _position(1));
}
