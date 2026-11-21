import 'dart:io';

import 'package:animations/animations.dart';
import 'package:el3yada/core/theme/motion.dart';
import 'package:el3yada/core/widgets/app_logo.dart';
import 'package:el3yada/core/widgets/container_transform.dart';
import 'package:el3yada/core/widgets/empty_state.dart';
import 'package:el3yada/core/widgets/pressable.dart';
import 'package:el3yada/core/widgets/skeleton_loading.dart';
import 'package:el3yada/core/widgets/staggered_entrance.dart';
import 'package:el3yada/core/widgets/state_switcher.dart';
import 'package:el3yada/core/widgets/success_check.dart';
import 'package:el3yada/features/shell/fade_through_branches.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../support/harness.dart';

void main() {
  group('Pressable', () {
    Widget card(VoidCallback onTap) => Scaffold(
      body: Center(
        child: Pressable(
          onTap: onTap,
          child: const SizedBox(
            key: Key('card'),
            width: 200,
            height: 80,
            child: Text('Card'),
          ),
        ),
      ),
    );

    testWidgets('scales to 0.97 within 100 ms and springs back on release', (
      tester,
    ) async {
      var taps = 0;
      await pumpHarness(tester, card(() => taps++));
      final width = tester.getRect(find.byKey(const Key('card'))).width;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('card'))),
      );
      await tester.pump();
      await tester.pump(Motion.press);
      expect(
        tester.getRect(find.byKey(const Key('card'))).width,
        closeTo(width * 0.97, 0.5),
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(
        tester.getRect(find.byKey(const Key('card'))).width,
        closeTo(width, 0.01),
      );
    });

    testWidgets('with reduced motion it dims instead of scaling', (
      tester,
    ) async {
      await pumpHarness(tester, card(() {}), reduced: true);
      expect(find.byType(AnimatedScale), findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('card'))),
      );
      await tester.pump();
      await tester.pump(Motion.press);
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        lessThan(1),
      );
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('is a button for screen readers and works from the keyboard', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpHarness(tester, card(() => taps++));
      expect(
        tester.getSemantics(find.byType(Pressable)),
        isSemantics(
          label: 'Card',
          isButton: true,
          hasTapAction: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
      handle.dispose();
    });
  });

  group('StaggeredEntrance', () {
    Finder fadeOf(int i) => find.descendant(
      of: find.byKey(ValueKey('item $i')),
      matching: find.byType(FadeTransition),
    );
    double opacity(WidgetTester tester, int i) =>
        tester.widget<FadeTransition>(fadeOf(i)).opacity.value;

    Widget list({int count = 10}) => Scaffold(
      body: StaggerGroup(
        child: ListView(
          children: [
            for (var i = 0; i < count; i++)
              StaggeredEntrance(
                key: ValueKey('item $i'),
                index: i,
                child: SizedBox(height: 40, child: Text('Item $i')),
              ),
          ],
        ),
      ),
    );

    testWidgets(
      'items fade and rise in one after another; only the first 8 animate',
      (tester) async {
        await pumpHarness(tester, list());
        final restingTop = 40.0 * 0; // item 0 sits at the top of the list
        expect(opacity(tester, 0), 0);
        expect(
          tester.getTopLeft(find.text('Item 0')).dy,
          restingTop + Motion.entranceDistance,
        );

        await tester.pump(Motion.staggerStep * 3);
        expect(opacity(tester, 0), greaterThan(0));
        expect(opacity(tester, 5), 0, reason: 'item 5 waits 5 × 40 ms');
        expect(
          fadeOf(8),
          findsNothing,
          reason: 'items after the first 8 just appear',
        );

        await tester.pumpAndSettle();
        for (var i = 0; i < 8; i++) {
          expect(opacity(tester, i), 1);
        }
        expect(tester.getTopLeft(find.text('Item 0')).dy, restingTop);
      },
    );

    testWidgets('a tap finishes the entrance at once', (tester) async {
      await pumpHarness(tester, list());
      await tester.pump(Motion.staggerStep);
      expect(opacity(tester, 7), 0);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Item 0')),
      );
      await tester.pump();
      expect(opacity(tester, 7), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'items built after the entrance window appear without animating',
      (tester) async {
        await pumpHarness(tester, list(count: 2));
        await tester.pumpAndSettle();
        await tester.pumpWidget(harness(list(count: 3)));
        expect(find.text('Item 2'), findsOneWidget);
        expect(fadeOf(2), findsNothing);
      },
    );

    testWidgets('with reduced motion items fade in together without moving', (
      tester,
    ) async {
      await pumpHarness(tester, list(), reduced: true);
      expect(tester.getTopLeft(find.text('Item 0')).dy, 0);
      await tester.pump(Motion.fast ~/ 2);
      expect(opacity(tester, 0), greaterThan(0));
      expect(opacity(tester, 0), opacity(tester, 5), reason: 'no stagger');
      await tester.pumpAndSettle();
    });
  });

  group('StateSwitcher', () {
    Widget switcher(ViewState state) => Scaffold(
      body: StateSwitcher(
        state: state,
        loading: (_) => const Text('loading'),
        content: (_) => const Text('content'),
        empty: (_) => const Text('empty'),
        error: (_) => const Text('error'),
      ),
    );

    for (final reduced in [false, true]) {
      testWidgets(
        'crossfades loading → content → empty → error (reduced motion: $reduced)',
        (tester) async {
          await pumpHarness(
            tester,
            switcher(ViewState.loading),
            reduced: reduced,
          );
          expect(find.text('loading'), findsOneWidget);

          for (final (from, to) in [
            ('loading', ViewState.content),
            ('content', ViewState.empty),
            ('empty', ViewState.error),
          ]) {
            await tester.pumpWidget(harness(switcher(to), reduced: reduced));
            await tester.pump(Motion.normalExit ~/ 2);
            expect(
              find.text(from),
              findsOneWidget,
              reason: 'outgoing state still fading out',
            );
            expect(find.text(to.name), findsOneWidget);
            await tester.pumpAndSettle();
            expect(find.text(from), findsNothing);
          }
        },
      );
    }

    testWidgets(
      'AsyncStateSwitcher maps loading, data, empty data and errors',
      (tester) async {
        Widget async(AsyncValue<List<int>> value) => Scaffold(
          body: AsyncStateSwitcher<List<int>>(
            value: value,
            isEmpty: (list) => list.isEmpty,
            loading: (_) => const Text('loading'),
            data: (_, list) => Text('items ${list.length}'),
            empty: (_) => const Text('empty'),
            error: (_, error) => Text('error $error'),
          ),
        );

        await pumpHarness(tester, async(const AsyncValue.loading()));
        expect(find.text('loading'), findsOneWidget);
        await tester.pumpWidget(harness(async(const AsyncValue.data([1, 2]))));
        await tester.pumpAndSettle();
        expect(find.text('items 2'), findsOneWidget);
        await tester.pumpWidget(harness(async(const AsyncValue.data([]))));
        await tester.pumpAndSettle();
        expect(find.text('empty'), findsOneWidget);
        await tester.pumpWidget(
          harness(async(AsyncValue.error('offline', StackTrace.empty))),
        );
        await tester.pumpAndSettle();
        expect(find.text('error offline'), findsOneWidget);
      },
    );
  });

  group('SkeletonLoading', () {
    Widget skeleton({required bool loading}) =>
        const Scaffold(body: _SkeletonCard()).withLoading(loading);

    testWidgets(
      'shows content-shaped bones with a shimmer, announced as loading',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHarness(tester, skeleton(loading: true));
        await tester.pump();
        expect(
          tester
              .widget<Skeletonizer>(
                find.byWidgetPredicate((w) => w is Skeletonizer),
              )
              .enabled,
          isTrue,
        );
        expect(find.semantics.byLabel('Loading…'), findsOne);
        expect(find.semantics.byLabel(RegExp('Patient name')), findsNothing);
        expect(
          tester.hasRunningAnimations,
          isTrue,
          reason: 'the shimmer sweeps',
        );
        await tester.pumpWidget(harness(skeleton(loading: false)));
        await tester.pumpAndSettle();
        expect(find.semantics.byLabel(RegExp('Patient name')), findsOne);
        handle.dispose();
      },
    );

    testWidgets('with reduced motion the bones stay still', (tester) async {
      await pumpHarness(tester, skeleton(loading: true), reduced: true);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('EmptyState', () {
    testWidgets('shows the illustration, message and action', (tester) async {
      var actions = 0;
      await pumpHarness(
        tester,
        Scaffold(
          body: EmptyState(
            title: 'No bookings yet',
            message: 'Book your next visit and it shows up here.',
            actionLabel: 'Book a visit',
            onAction: () => actions++,
          ),
        ),
        rtl: true,
      );
      await tester.pumpAndSettle();
      expect(find.byType(EmptyIllustration), findsOneWidget);
      expect(find.text('No bookings yet'), findsOneWidget);
      expect(
        find.text('Book your next visit and it shows up here.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Book a visit'));
      expect(actions, 1);
    });
  });

  group('SuccessCheck', () {
    test('the Lottie file is 1.5 s or less and 100 KB or less', () {
      final file = File('assets/lottie/success_check.json');
      expect(file.lengthSync(), lessThanOrEqualTo(100 * 1024));
      final composition = LottieComposition.parseJsonBytes(
        file.readAsBytesSync(),
      );
      expect(
        composition.duration,
        lessThanOrEqualTo(const Duration(milliseconds: 1500)),
      );
    });

    testWidgets('plays once, says "Done" and reports when finished', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var done = 0;
      await pumpHarness(
        tester,
        Scaffold(
          body: Center(child: SuccessCheck(onCompleted: () => done++)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.semantics.byLabel('Done'), findsOne);
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(done, 1);
      await tester.pumpAndSettle();
      expect(done, 1);
      handle.dispose();
    });

    testWidgets('with reduced motion the finished check shows at once', (
      tester,
    ) async {
      var done = 0;
      await pumpHarness(
        tester,
        Scaffold(
          body: Center(child: SuccessCheck(onCompleted: () => done++)),
        ),
        reduced: true,
      );
      await tester.pump();
      await tester.pump(Motion.fast);
      expect(done, 1);
      await tester.pumpAndSettle();
    });
  });

  group('AppLogoMark', () {
    testWidgets(
      'writes the stroke, pops the plus, spreads the rings, and can fly as a Hero',
      (tester) async {
        var drawn = 0;
        await pumpHarness(
          tester,
          Center(
            child: AppLogoMark(
              animate: true,
              hero: true,
              onDrawn: () => drawn++,
            ),
          ),
        );
        expect(tester.widget<Hero>(find.byType(Hero)).tag, AppLogoMark.heroTag);
        expect(
          find.descendant(
            of: find.byType(AppLogoMark),
            matching: find.byType(RepaintBoundary),
          ),
          findsOneWidget,
        );
        await tester.pump(); // the ticker starts on this frame
        await tester.pump(AppLogoMark.drawDuration * 0.6);
        expect(
          tester.hasRunningAnimations,
          isTrue,
          reason: 'the plus and the rings are still going',
        );
        expect(drawn, 0);
        await tester.pump(AppLogoMark.drawDuration * 0.4);
        await tester.pump(
          Motion.fast,
        ); // completion is reported on a frame after the end
        expect(drawn, 1);
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('beats on a loop only while ambient loops are on', (
      tester,
    ) async {
      await pumpHarness(tester, const Center(child: AppLogoMark(beat: true)));
      await tester.pump();
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'tests turn ambient loops off',
      );

      Motion.ambientLoops = true;
      addTearDown(() => Motion.ambientLoops = false);
      await pumpHarness(
        tester,
        const Center(child: AppLogoMark(key: ValueKey('beating'), beat: true)),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with reduced motion the static mark shows', (tester) async {
      var drawn = 0;
      await pumpHarness(
        tester,
        Center(child: AppLogoMark(animate: true, onDrawn: () => drawn++)),
        reduced: true,
      );
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pump();
      expect(drawn, 1);
    });
  });

  group('page transitions', () {
    Widget opener() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Center(child: Text('Detail'))),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    for (final rtl in [false, true]) {
      testWidgets(
        'forward and back slide on the shared axis, mirrored in Arabic (rtl: $rtl)',
        (tester) async {
          await pumpHarness(tester, opener(), rtl: rtl);
          await tester.tap(find.text('Open'));
          await tester.pump();
          await tester.pump(Motion.slow ~/ 2);
          expect(find.byType(SharedAxisTransition), findsWidgets);
          final enterShift = tester.getCenter(find.text('Detail')).dx - 200;
          expect(
            rtl ? enterShift < -1 : enterShift > 1,
            isTrue,
            reason: 'comes from the end side: $enterShift',
          );

          await tester.pump(Motion.slow ~/ 2);
          await tester.pump();
          expect(tester.getCenter(find.text('Detail')).dx, closeTo(200, 0.01));

          tester.state<NavigatorState>(find.byType(Navigator)).pop();
          await tester.pump();
          await tester.pump(Motion.slowExit ~/ 4);
          final exitShift = tester.getCenter(find.text('Detail')).dx - 200;
          expect(
            rtl ? exitShift < -0.5 : exitShift > 0.5,
            isTrue,
            reason: 'goes back the way it came: $exitShift',
          );
          await tester.pumpAndSettle();
          expect(find.text('Detail'), findsNothing);
        },
      );
    }

    testWidgets('with reduced motion pages fade in place', (tester) async {
      await pumpHarness(tester, opener(), reduced: true);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(Motion.slow ~/ 2);
      expect(find.byType(SharedAxisTransition), findsNothing);
      expect(tester.getCenter(find.text('Detail')).dx, closeTo(200, 0.01));
      await tester.pumpAndSettle();
    });
  });

  group('FadeThroughBranches', () {
    Widget tabs(int index) => Scaffold(
      body: FadeThroughBranches(
        currentIndex: index,
        children: const [
          Center(child: Text('A')),
          Center(child: Text('B')),
          Center(child: Text('C')),
        ],
      ),
    );

    for (final reduced in [false, true]) {
      testWidgets(
        'switching tabs fades through and keeps every tab alive (reduced: $reduced)',
        (tester) async {
          await pumpHarness(tester, tabs(0), reduced: reduced);
          expect(find.text('A'), findsOneWidget);
          expect(find.text('B'), findsNothing);

          await tester.pumpWidget(harness(tabs(1), reduced: reduced));
          await tester.pump(Motion.fastExit ~/ 2);
          expect(
            find.text('A'),
            findsOneWidget,
            reason: 'the old tab is fading out',
          );
          expect(find.text('B'), findsOneWidget);
          expect(
            find.byType(FadeThroughTransition),
            reduced ? findsNothing : findsWidgets,
          );

          await tester.pumpAndSettle();
          expect(find.text('A'), findsNothing);
          expect(
            find.text('A', skipOffstage: false),
            findsOneWidget,
            reason: 'kept alive offstage',
          );
          expect(find.text('B'), findsOneWidget);
        },
      );
    }
  });

  group('ContainerTransform', () {
    for (final reduced in [false, true]) {
      testWidgets(
        'opens the detail from the card and returns its result (reduced: $reduced)',
        (tester) async {
          String? result;
          await pumpHarness(
            tester,
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 80,
                  child: ContainerTransform<String>(
                    onClosed: (value) => result = value,
                    closedBuilder: (context, open) =>
                        const Center(child: Text('Patient card')),
                    openBuilder: (context, close) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => close(returnValue: 'saved'),
                          child: const Text('Close'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            reduced: reduced,
          );
          expect(
            find.byType(OpenContainer<String>),
            reduced ? findsNothing : findsOneWidget,
          );
          await tester.tap(find.text('Patient card'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          expect(result, 'saved');
          expect(find.text('Patient card'), findsOneWidget);
        },
      );
    }
  });
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(Icons.person)),
      title: Text('Patient name'),
      subtitle: Text('10:30'),
    ),
  );
}

extension on Widget {
  Widget withLoading(bool loading) => _Loading(loading: loading, child: this);
}

class _Loading extends StatelessWidget {
  const _Loading({required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SkeletonLoading(loading: loading, child: child);
}
