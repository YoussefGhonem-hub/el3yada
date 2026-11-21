import 'package:el3yada/core/theme/motion.dart';
import 'package:el3yada/core/widgets/shake_on_error.dart';
import 'package:el3yada/core/widgets/submit_button.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

Widget _button(SubmitStatus status, {VoidCallback? onPressed}) => Scaffold(
  body: Center(
    child: SizedBox(
      width: 300,
      child: SubmitButton(
        label: 'Sign in',
        status: status,
        onPressed: onPressed ?? () {},
      ),
    ),
  ),
);

final _progress = find.byType(CircularProgressIndicator);
final _check = find.byIcon(Icons.check_rounded);

void main() {
  group('SubmitButton', () {
    testWidgets('morphs label → progress → check, keeping its size', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(tester, _button(SubmitStatus.idle));
      expect(find.text('Sign in'), findsOneWidget);
      final size = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(harness(_button(SubmitStatus.loading)));
      await tester.pump(const Duration(milliseconds: 250));
      expect(_progress, findsNothing, reason: 'no loader in the first 300 ms');
      expect(find.text('Sign in'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(Motion.normal);
      expect(_progress, findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
      expect(find.semantics.byLabel('Loading…'), findsOne);
      expect(tester.getSize(find.byType(FilledButton)), size);

      await tester.pumpWidget(harness(_button(SubmitStatus.success)));
      await tester.pump(Motion.slow);
      await tester.pumpAndSettle();
      expect(_check, findsOneWidget);
      expect(_progress, findsNothing);
      expect(find.semantics.byLabel('Done'), findsOne);
      expect(tester.getSize(find.byType(FilledButton)), size);
      handle.dispose();
    });

    testWidgets(
      'an action that finishes within 300 ms goes straight to the check',
      (tester) async {
        await pumpHarness(tester, _button(SubmitStatus.idle));
        await tester.pumpWidget(harness(_button(SubmitStatus.loading)));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pumpWidget(harness(_button(SubmitStatus.success)));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 60));
          expect(_progress, findsNothing);
        }
        expect(_check, findsOneWidget);
      },
    );

    testWidgets(
      'ignores taps while loading and returns to the label on error',
      (tester) async {
        var presses = 0;
        await pumpHarness(
          tester,
          _button(SubmitStatus.idle, onPressed: () => presses++),
        );
        await tester.tap(find.byType(FilledButton));
        expect(presses, 1);

        await tester.pumpWidget(
          harness(_button(SubmitStatus.loading, onPressed: () => presses++)),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byType(FilledButton), warnIfMissed: false);
        expect(presses, 1);

        // Wrong credentials: back to idle.
        await tester.pumpWidget(
          harness(_button(SubmitStatus.idle, onPressed: () => presses++)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sign in'), findsOneWidget);
        expect(_progress, findsNothing);
      },
    );

    testWidgets('with reduced motion the faces crossfade without scaling', (
      tester,
    ) async {
      await pumpHarness(tester, _button(SubmitStatus.idle), reduced: true);
      await tester.pumpWidget(
        harness(_button(SubmitStatus.success), reduced: true),
      );
      await tester.pump(Motion.fastExit);
      expect(
        find.descendant(
          of: find.byType(SubmitButton),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(_check, findsOneWidget);
    });
  });

  group('ShakeOnError', () {
    Widget form(Object? trigger) => Scaffold(
      body: Center(
        child: ShakeOnError(
          trigger: trigger,
          child: const SizedBox(key: Key('form'), width: 200, height: 100),
        ),
      ),
    );
    double x(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(const Key('form'))).dx;

    testWidgets('shakes sideways once when the trigger changes', (
      tester,
    ) async {
      await pumpHarness(tester, form(0));
      final rest = x(tester);

      await tester.pumpWidget(harness(form(1)));
      await tester.pump();
      await tester.pump(Motion.slow ~/ 12);
      expect((x(tester) - rest).abs(), greaterThan(3));
      expect(
        (x(tester) - rest).abs(),
        lessThanOrEqualTo(ShakeOnError.amplitude),
      );

      await tester.pumpAndSettle();
      expect(x(tester), rest);

      // Same value again: no shake.
      await tester.pumpWidget(harness(form(1)));
      await tester.pump(Motion.slow ~/ 12);
      expect(x(tester), rest);
    });

    testWidgets('does not move with reduced motion, or for a null trigger', (
      tester,
    ) async {
      await pumpHarness(tester, form(0), reduced: true);
      final rest = x(tester);
      await tester.pumpWidget(harness(form(1), reduced: true));
      await tester.pump(Motion.slow ~/ 12);
      expect(x(tester), rest);
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(harness(form(null)));
      await tester.pump(Motion.slow ~/ 12);
      expect(x(tester), rest);
    });
  });
}
