import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/core/storage/token_store.dart';
import 'package:el3yada/core/theme/motion.dart';
import 'package:el3yada/core/widgets/navigation/floating_nav_bar.dart';
import 'package:el3yada/core/widgets/navigation/nav_item.dart';
import 'package:el3yada/core/widgets/navigation/nav_rail.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/shell/role_scaffold.dart';
import 'package:el3yada/features/shell/role_shells.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/harness.dart';

Future<List<Override>> _overrides({List<Override> extra = const []}) async {
  SharedPreferences.setMockInitialValues({'settings.locale': 'en'});
  final prefs = await SharedPreferences.getInstance();
  return [
    sharedPreferencesProvider.overrideWithValue(prefs),
    appPlatformProvider.overrideWithValue(AppPlatform.mobile),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
    authRepositoryProvider.overrideWithValue(FakeAuthRepository(delay: Duration.zero)),
    ...extra,
  ];
}

Future<void> _pumpScaffold(
  WidgetTester tester, {
  required RoleShell shell,
  required String location,
  Size size = const Size(400, 800),
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: await _overrides(extra: extra),
      child: harness(
        RoleScaffold(
          shell: shell,
          location: location,
          child: ListView(children: [for (var i = 0; i < 60; i++) SizedBox(height: 50, child: Text('Row $i'))]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _barHidden(WidgetTester tester) => tester
    .widget<IgnorePointer>(find.descendant(of: find.byType(FloatingNavBar), matching: find.byType(IgnorePointer)).first)
    .ignoring;

void main() {
  testWidgets('[S] the phone bar slides away while scrolling down and returns on scroll up', (tester) async {
    await _pumpScaffold(tester, shell: RoleShell.patient, location: '/patient/home');
    expect(_barHidden(tester), isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_barHidden(tester), isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(_barHidden(tester), isFalse);
  });

  testWidgets('content scrolls behind the floating bar and lists get its height as padding', (tester) async {
    await _pumpScaffold(tester, shell: RoleShell.patient, location: '/patient/home');
    final bar = tester.getRect(find.byType(FloatingNavBar));
    final list = tester.getRect(find.byType(ListView));
    expect(list.bottom, greaterThanOrEqualTo(bar.bottom), reason: 'extendBody');
    expect(bar.height, FloatingNavBar.barHeight + FloatingNavBar.edgeMargin);

    // Scrolled to the end, the last row stops above the bar.
    await tester.fling(find.byType(ListView), const Offset(0, -6000), 4000);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Row 59')).bottom, lessThanOrEqualTo(bar.top + 0.5));
  });

  testWidgets('badges come from navBadgeProvider; More shows a dot for what it holds', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpScaffold(
      tester,
      shell: RoleShell.doctor,
      location: '/doctor/live',
      extra: [
        navBadgeProvider.overrideWith((ref, path) => switch (path) {
              '/doctor/chats' => const NavBadge.count(4),
              '/doctor/billing' => const NavBadge.dot(),
              _ => null,
            }),
      ],
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.semantics.byLabel('Chats, 4 unread'), findsOne);
    expect(find.semantics.byLabel('More, New'), findsOne);
    expect(find.text('Live'), findsOneWidget, reason: 'the bar uses the short label');
    handle.dispose();
  });

  testWidgets('the tablet rail runs the full height with the full labels', (tester) async {
    await _pumpScaffold(tester, shell: RoleShell.doctor, location: '/doctor/patients', size: const Size(800, 1000));
    expect(find.byType(FloatingNavBar), findsNothing);
    final rail = tester.getRect(find.byType(AppNavRail));
    final body = tester.getRect(find.byType(ListView));
    expect(rail.height, body.height);
    expect(find.text('Live board'), findsOneWidget);
  });

  testWidgets('switching tabs in the app fades through and keeps the old tab alive', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: await _overrides(), child: const El3yadaApp()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '01000000002');
    await tester.enterText(find.byType(TextFormField).at(1), 'dev');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Screen P1 in spec.md'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(FloatingNavBar), matching: find.text('Appointments')));
    await tester.pump();
    await tester.pump(Motion.normal ~/ 5);
    expect(find.text('Screen P1 in spec.md'), findsOneWidget, reason: 'old tab fading out');
    expect(find.text('Screen P16 in spec.md'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Screen P1 in spec.md'), findsNothing);
    expect(find.text('Screen P1 in spec.md', skipOffstage: false), findsOneWidget);
    expect(find.text('Screen P16 in spec.md'), findsOneWidget);
  });
}
