import 'package:el3yada/core/theme/motion.dart';
import 'package:el3yada/core/widgets/navigation/floating_nav_bar.dart';
import 'package:el3yada/core/widgets/navigation/nav_item.dart';
import 'package:el3yada/core/widgets/navigation/nav_rail.dart';
import 'package:el3yada/core/widgets/navigation/side_menu.dart';
import 'package:el3yada/core/widgets/navigation/sliding_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

const _items = [
  NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  NavItem(icon: Icons.event_note_outlined, selectedIcon: Icons.event_note, label: 'Bookings'),
  NavItem(icon: Icons.folder_shared_outlined, selectedIcon: Icons.folder_shared, label: 'File'),
  NavItem(icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: 'Chats', badge: NavBadge.count(3)),
  NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Account'),
];

/// A scaffold whose bar selection follows taps; [taps] records them.
Widget _app({List<NavItem> items = _items, bool hidden = false, List<int>? taps}) {
  var selected = 0;
  return StatefulBuilder(
    builder: (context, setState) => Scaffold(
      extendBody: true,
      body: const SizedBox.expand(),
      bottomNavigationBar: FloatingNavBar(
        items: items,
        selectedIndex: selected,
        hidden: hidden,
        onSelected: (i) {
          taps?.add(i);
          setState(() => selected = i);
        },
      ),
    ),
  );
}

Rect _indicator(WidgetTester tester) => tester.getRect(
      find.descendant(of: find.byType(SlidingIndicator), matching: find.byType(DecoratedBox)),
    );

void main() {
  testWidgets('selection slides the indicator to the tapped item', (tester) async {
    final taps = <int>[];
    await pumpHarness(tester, _app(taps: taps));
    await tester.pumpAndSettle();
    expect(_indicator(tester).center.dx, closeTo(tester.getCenter(find.text('Home')).dx, 1));

    await tester.tap(find.text('Chats'));
    await tester.pump();
    await tester.pump(Motion.normal ~/ 4);
    final midway = _indicator(tester).center.dx;
    expect(midway, greaterThan(tester.getCenter(find.text('Home')).dx + 1));
    expect(midway, lessThan(tester.getCenter(find.text('Chats')).dx));

    await tester.pumpAndSettle();
    expect(taps, [3]);
    expect(_indicator(tester).center.dx, closeTo(tester.getCenter(find.text('Chats')).dx, 1));
  });

  testWidgets('the selected label turns bold and the icon filled', (tester) async {
    await pumpHarness(tester, _app());
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('Home')).style?.fontWeight, FontWeight.w700);
    expect(tester.widget<Text>(find.text('Bookings')).style?.fontWeight, FontWeight.w500);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.event_note), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('badges pop in: counts, 99+ and dots', (tester) async {
    await pumpHarness(
      tester,
      _app(items: [
        ..._items.take(3),
        const NavItem(icon: Icons.chat_bubble_outline, selectedIcon: Icons.chat_bubble, label: 'Chats', badge: NavBadge.count(150)),
        const NavItem(icon: Icons.more_horiz, selectedIcon: Icons.more_horiz, label: 'More', badge: NavBadge.dot()),
      ]),
    );
    // Starts at scale 0, then springs in.
    expect(find.text('99+'), findsNothing);
    await tester.pump(Motion.fast);
    expect(find.text('99+'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot')), findsOneWidget);
  });

  testWidgets('in Arabic the item order and the slide direction mirror', (tester) async {
    await pumpHarness(tester, _app(), rtl: true);
    await tester.pumpAndSettle();
    final home = tester.getCenter(find.text('Home')).dx;
    final bookings = tester.getCenter(find.text('Bookings')).dx;
    expect(home, greaterThan(bookings), reason: 'the first item is on the right');
    final start = _indicator(tester).center.dx;
    expect(start, closeTo(home, 1));

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(_indicator(tester).center.dx, closeTo(bookings, 1));
    expect(_indicator(tester).center.dx, lessThan(start), reason: 'slides to the left');
  });

  testWidgets('hides while the keyboard is open', (tester) async {
    final taps = <int>[];
    final handle = tester.ensureSemantics();
    await pumpHarness(tester, _app(taps: taps));
    await tester.pumpAndSettle();
    expect(_barIgnoresPointer(tester), isFalse);
    expect(find.semantics.byLabel('Home'), findsOne);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(_barIgnoresPointer(tester), isTrue);
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset, const Offset(0, 1));
    expect(tester.widget<AnimatedOpacity>(_barOpacity).opacity, 0);
    expect(find.semantics.byLabel('Home'), findsNothing);
    await tester.tap(find.text('Chats'), warnIfMissed: false);
    expect(taps, isEmpty);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(_barIgnoresPointer(tester), isFalse);
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset, Offset.zero);
    expect(find.semantics.byLabel('Home'), findsOne);
    handle.dispose();
  });

  testWidgets('hidden (content scrolling down) slides the bar away', (tester) async {
    await pumpHarness(tester, _app(hidden: true));
    await tester.pumpAndSettle();
    expect(_barIgnoresPointer(tester), isTrue);
    expect(tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset, const Offset(0, 1));
  });

  testWidgets('semantics: buttons with selected state and the badge in the label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHarness(tester, _app());
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Home')),
      isSemantics(label: 'Home', isButton: true, hasSelectedState: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Chats, 3 unread')),
      isSemantics(isButton: true, hasSelectedState: true, isSelected: false, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('semantics in Arabic use the Arabic badge wording', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHarness(tester, _app(), rtl: true);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Chats، 3 غير مقروءة'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a tap gives a light haptic', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpHarness(tester, _app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.method == 'HapticFeedback.vibrate').map((c) => c.arguments),
      ['HapticFeedbackType.lightImpact'],
    );
  });

  testWidgets('with reduced motion the indicator crossfades instead of sliding', (tester) async {
    await pumpHarness(tester, _app(), reduced: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chats'));
    await tester.pump();
    await tester.pump(Motion.fastExit);
    // Mid-crossfade: one pill at the old item, one at the new; none in between.
    final pills = find.descendant(of: find.byType(SlidingIndicator), matching: find.byType(DecoratedBox));
    expect(pills, findsNWidgets(2));
    final xs = [for (final e in pills.evaluate()) tester.getRect(find.byWidget(e.widget)).center.dx]..sort();
    expect(xs.first, closeTo(tester.getCenter(find.text('Home')).dx, 1));
    expect(xs.last, closeTo(tester.getCenter(find.text('Chats')).dx, 1));
    await tester.pumpAndSettle();
    expect(pills, findsOneWidget);
  });

  testWidgets('the largest system text fits a 320 dp phone without overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpHarness(tester, _app(), rtl: true, size: const Size(320, 640));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final item in _items) {
      final label = tester.getRect(find.text(item.label));
      final bar = tester.getRect(find.byType(FloatingNavBar));
      expect(bar.contains(label.topLeft) && bar.contains(label.bottomRight), isTrue);
    }
    // Every item stays a comfortable touch target.
    for (final pressable in find.byType(GestureDetector).evaluate()) {
      final size = tester.getSize(find.byWidget(pressable.widget));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('the tablet rail and the desktop menu have the same sliding indicator', (tester) async {
    for (final vertical in [
      (int selected, ValueChanged<int> onSelected) =>
          AppNavRail(items: _items, selectedIndex: selected, onSelected: onSelected),
      (int selected, ValueChanged<int> onSelected) =>
          AppSideMenu(items: _items, selectedIndex: selected, onSelected: onSelected),
    ]) {
      var selected = 0;
      await pumpHarness(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Row(children: [vertical(selected, (i) => setState(() => selected = i))]),
          ),
        ),
        size: const Size(1100, 800),
      );
      await tester.pumpAndSettle();
      // The pill covers the selected item (icon and label).
      bool covers(String label) => _indicator(tester).contains(tester.getCenter(find.text(label)));
      expect(covers('Home'), isTrue);
      final start = _indicator(tester).center.dy;

      await tester.tap(find.text('File'));
      await tester.pump();
      await tester.pump(Motion.normal ~/ 4);
      final midway = _indicator(tester).center.dy;
      await tester.pumpAndSettle();
      final end = _indicator(tester).center.dy;
      expect(covers('File'), isTrue);
      expect(covers('Home'), isFalse);
      expect(midway, greaterThan(start));
      expect(midway, lessThan(end));
    }
  });
}

Finder get _barOpacity => find.descendant(of: find.byType(FloatingNavBar), matching: find.byType(AnimatedOpacity)).first;

bool _barIgnoresPointer(WidgetTester tester) => tester
    .widget<IgnorePointer>(find.descendant(of: find.byType(FloatingNavBar), matching: find.byType(IgnorePointer)).first)
    .ignoring;
