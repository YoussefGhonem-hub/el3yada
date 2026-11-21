import 'package:el3yada/core/theme/motion.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'durations follow the spec and exits take about 65% of the entrance',
    () {
      expect(Motion.fast, const Duration(milliseconds: 150));
      expect(Motion.normal, const Duration(milliseconds: 250));
      expect(Motion.slow, const Duration(milliseconds: 400));
      for (final (enter, exit) in [
        (Motion.fast, Motion.fastExit),
        (Motion.normal, Motion.normalExit),
        (Motion.slow, Motion.slowExit),
      ]) {
        expect(exit.inMilliseconds / enter.inMilliseconds, closeTo(0.65, 0.03));
      }
      expect(Motion.press.inMilliseconds, lessThanOrEqualTo(100));
    },
  );

  test(
    'stagger is 30–50 ms for the first 8 items and zero with reduced motion',
    () {
      expect(Motion.staggerStep.inMilliseconds, inInclusiveRange(30, 50));
      expect(Motion.full.staggerDelay(1), Motion.staggerStep);
      expect(Motion.full.staggers(7), isTrue);
      expect(Motion.full.staggers(8), isFalse);
      expect(Motion.full.staggerDelay(20), Motion.staggerStep * 7);
      expect(Motion.reducedMotion.staggerDelay(5), Duration.zero);
      expect(Motion.reducedMotion.entranceOffset, 0);
      expect(Motion.full.entranceOffset, inInclusiveRange(8, 16));
    },
  );

  test('spring curves start at 0, end exactly at 1 and overshoot a little', () {
    for (final curve in [
      Motion.spring,
      Motion.springBouncy,
      const SpringCurve(bounce: 0),
    ]) {
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      expect(curve.transform(0.999), closeTo(1, 0.01));
    }
    double peak(Curve curve) => [
      for (var i = 1; i < 100; i++) curve.transform(i / 100),
    ].reduce((a, b) => a > b ? a : b);
    expect(peak(Motion.spring), inInclusiveRange(1.0, 1.06));
    expect(peak(Motion.springBouncy), inInclusiveRange(1.08, 1.2));
    expect(peak(const SpringCurve(bounce: 0)), lessThanOrEqualTo(1.0));
  });

  testWidgets('Motion.of reads MediaQuery.disableAnimations', (tester) async {
    late Motion motion;
    Widget probe(bool disable) => MediaQuery(
      data: MediaQueryData(disableAnimations: disable),
      child: Builder(
        builder: (context) {
          motion = Motion.of(context);
          return const SizedBox();
        },
      ),
    );

    await tester.pumpWidget(probe(false));
    expect(motion.reduced, isFalse);
    await tester.pumpWidget(probe(true));
    expect(motion.reduced, isTrue);
  });
}
