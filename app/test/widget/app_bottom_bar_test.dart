import 'package:el3yada/core/theme/app_theme.dart';
import 'package:el3yada/core/widgets/navigation/app_bottom_bar.dart';
import 'package:el3yada/core/widgets/navigation/nav_item.dart';
import 'package:el3yada/core/widgets/navigation/nav_rail.dart';
import 'package:el3yada/core/widgets/navigation/side_menu.dart';
import 'package:el3yada/core/widgets/navigation/sliding_indicator.dart';
import 'package:el3yada/core/theme/motion.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

const _items = [
  NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  NavItem(
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note,
    label: 'Bookings',
  ),
  NavItem(
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    label: 'Chats',
    badge: NavBadge.count(3),
  ),
  NavItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Account',
  ),
];

/// A scaffold whose bar selection follows taps; [taps] records side taps
/// and [centerTaps] the logo's.
Widget _app({
  List<NavItem> items = _items,
  bool hidden = false,
  List<int>? taps,
  List<int>? centerTaps,
}) {
  var selected = 0;
  return StatefulBuilder(
    builder: (context, setState) => Scaffold(
      extendBody: true,
      body: const SizedBox.expand(),
      bottomNavigationBar: AppBottomBar(
        items: items,
        selectedIndex: selected,
        hidden: hidden,
        onSelected: (i) {
          taps?.add(i);
          setState(() => selected = i);
        },
        center: BottomBarCenter(
          label: 'Dashboard',
          selected: selected == -1,
          onTap: () {
            centerTaps?.add(1);
            setState(() => selected = -1);
          },
        ),
      ),
    ),
  );
}

Icon _icon(WidgetTester tester, IconData data) =>
    tester.widget<Icon>(find.byIcon(data));

void main() {
  testWidgets(
    'icons only: labels are tooltips and screen-reader names, not text',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHarness(tester, _app());
      await tester.pumpAndSettle();
      for (final item in _items) {
        expect(find.text(item.label), findsNothing);
        expect(find.byTooltip(item.label), findsOneWidget);
      }
      expect(find.byTooltip('Dashboard'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home')),
        isSemantics(
          label: 'Home',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(find.bySemanticsLabel('Chats, 3 unread'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('takes the full width, with the logo raised in the middle', (
    tester,
  ) async {
    await pumpHarness(tester, _app(), size: const Size(400, 800));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(AppBottomBar));
    expect(bar.left, 0);
    expect(bar.right, 400);
    final logo = tester.getRect(find.byKey(AppBottomBar.centerKey));
    expect(logo.center.dx, closeTo(200, 0.5));
    expect(logo.top, lessThan(bar.top), reason: 'it rises above the bar');
    // Two icons on each side.
    expect(tester.getCenter(find.byIcon(Icons.home)).dx, lessThan(logo.left));
    expect(
      tester.getCenter(find.byIcon(Icons.chat_bubble_outline)).dx,
      greaterThan(logo.right),
    );
  });

  testWidgets(
    'the selected icon lights up and fills; nothing behind it changes',
    (tester) async {
      await pumpHarness(tester, _app());
      await tester.pumpAndSettle();
      final mint = AppTheme.light().extension<El3yadaColors>()!.navIndicator;
      expect(_icon(tester, Icons.home).color, mint);
      expect(_icon(tester, Icons.home).shadows, isNotEmpty);
      expect(_icon(tester, Icons.event_note_outlined).color, isNot(mint));
      expect(_icon(tester, Icons.event_note_outlined).shadows, isNull);

      await tester.tap(find.byTooltip('Bookings'));
      await tester.pumpAndSettle();
      expect(_icon(tester, Icons.event_note).color, mint);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      // No pill or lens: the bar has no indicator.
      expect(find.byType(SlidingIndicator), findsNothing);
    },
  );

  testWidgets('the logo opens its screen and glows while it is open', (
    tester,
  ) async {
    final centerTaps = <int>[];
    await pumpHarness(tester, _app(centerTaps: centerTaps));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppBottomBar.centerKey));
    await tester.pumpAndSettle();
    expect(centerTaps, [1]);
    expect(
      find.byIcon(Icons.home_outlined),
      findsOneWidget,
      reason: 'no side item is selected',
    );
  });

  testWidgets('in Arabic the item order mirrors', (tester) async {
    await pumpHarness(tester, _app(), rtl: true);
    await tester.pumpAndSettle();
    final home = tester.getCenter(find.byIcon(Icons.home)).dx;
    final bookings = tester
        .getCenter(find.byIcon(Icons.event_note_outlined))
        .dx;
    expect(
      home,
      greaterThan(bookings),
      reason: 'the first item is on the right',
    );
  });

  testWidgets('badges pop in: counts, 99+ and dots', (tester) async {
    await pumpHarness(
      tester,
      _app(
        items: [
          ..._items.take(2),
          const NavItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: 'Chats',
            badge: NavBadge.count(150),
          ),
          const NavItem(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view_rounded,
            label: 'More',
            badge: NavBadge.dot(),
          ),
        ],
      ),
    );
    expect(find.text('99+'), findsNothing);
    await tester.pump(Motion.fast);
    expect(find.text('99+'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dot')), findsOneWidget);
  });

  testWidgets(
    'hides while the keyboard is open, and while content scrolls down',
    (tester) async {
      final taps = <int>[];
      await pumpHarness(tester, _app(taps: taps));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        const Offset(0, 1.5),
      );
      await tester.tap(
        find.byIcon(Icons.chat_bubble_outline),
        warnIfMissed: false,
      );
      expect(taps, isEmpty);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        Offset.zero,
      );

      await pumpHarness(tester, _app(hidden: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedSlide>(find.byType(AnimatedSlide)).offset,
        const Offset(0, 1.5),
      );
    },
  );

  testWidgets('a tap gives a light haptic', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpHarness(tester, _app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(
      calls
          .where((c) => c.method == 'HapticFeedback.vibrate')
          .map((c) => c.arguments),
      ['HapticFeedbackType.lightImpact'],
    );
  });

  testWidgets(
    'fits a 320 dp phone with the largest text, with comfortable targets',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpHarness(tester, _app(), rtl: true, size: const Size(320, 640));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final item in _items) {
        final size = tester.getSize(
          find
              .descendant(
                of: find.byTooltip(item.label),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    },
  );

  testWidgets('the tablet rail and the desktop menu keep the sliding indicator', (
    tester,
  ) async {
    // The rail's SlidingIndicator, or the desktop menu's pill (with its punch).
    Rect pill() {
      final rail = find.byType(SlidingIndicator);
      final indicator = rail.evaluate().isNotEmpty
          ? rail
          : find.byKey(AppSideMenu.indicatorKey);
      return tester.getRect(
        find
            .descendant(of: indicator, matching: find.byType(DecoratedBox))
            .first,
      );
    }

    for (final vertical in [
      (int selected, ValueChanged<int> onSelected) => AppNavRail(
        items: _items,
        selectedIndex: selected,
        onSelected: onSelected,
      ),
      (int selected, ValueChanged<int> onSelected) => AppSideMenu(
        items: _items,
        selectedIndex: selected,
        onSelected: onSelected,
      ),
    ]) {
      var selected = 0;
      await pumpHarness(
        tester,
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Row(
              children: [
                vertical(selected, (i) => setState(() => selected = i)),
              ],
            ),
          ),
        ),
        size: const Size(1100, 800),
      );
      await tester.pumpAndSettle();
      bool covers(String label) =>
          pill().contains(tester.getCenter(find.text(label)));
      expect(covers('Home'), isTrue);
      await tester.tap(find.text('Chats'));
      await tester.pumpAndSettle();
      expect(covers('Chats'), isTrue);
      expect(covers('Home'), isFalse);
    }
  });
}
