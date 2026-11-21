import 'package:el3yada/app/app.dart';
import 'package:el3yada/app/router.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/core/theme/app_theme.dart';
import 'package:el3yada/core/theme/motion.dart';
import 'package:el3yada/core/widgets/app_logo.dart';
import 'package:el3yada/core/widgets/navigation/app_back_button.dart';
import 'package:el3yada/core/widgets/navigation/desktop_page_header.dart';
import 'package:el3yada/core/widgets/navigation/nav_item.dart';
import 'package:el3yada/core/widgets/navigation/side_menu.dart';
import 'package:el3yada/core/widgets/settings_actions.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:el3yada/l10n/gen/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/app_overrides.dart';
import '../support/clinic_admin_support.dart';

const _items = [
  NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
  NavItem(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'Patients',
  ),
  NavItem(
    icon: Icons.chat_bubble_outline,
    selectedIcon: Icons.chat_bubble,
    label: 'Chats',
  ),
  NavItem(
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: 'Billing',
  ),
];

/// [home] in the desktop theme, at a 1280 × 800 window.
Future<void> _pumpDesktop(
  WidgetTester tester,
  Widget home, {
  bool rtl = false,
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.desktopLight(),
      locale: Locale(rtl ? 'ar' : 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// A side menu whose selection follows taps, with a group break before
/// Chats and an account card.
Widget _menu({List<String>? log}) {
  var selected = 0;
  return StatefulBuilder(
    builder: (context, setState) => Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSideMenu(
            items: _items,
            selectedIndex: selected,
            onSelected: (i) => setState(() => selected = i),
            breaks: const {2},
            header: const SideMenuBrand(
              title: 'el3yada',
              subtitle: "Dr Sara's clinic",
            ),
            footer: SideMenuAccount(
              name: 'Dr Sara Ali',
              initial: 'S',
              role: 'Doctor',
              onProfile: () => log?.add('profile'),
              onSignOut: () => log?.add('sign out'),
            ),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    ),
  );
}

List<Rect> _marker(WidgetTester tester) => [
  for (final element
      in find
          .descendant(
            of: find.byKey(AppSideMenu.indicatorKey),
            matching: find.byType(DecoratedBox),
          )
          .evaluate())
    tester.getRect(find.byWidget(element.widget)),
];

String _path(WidgetTester tester) =>
    appContainer(tester).read(routerProvider).routerDelegate.state.uri.path;

void main() {
  group('desktop themes', () {
    testWidgets('light by default on desktop, with the desktop themes', (
      tester,
    ) async {
      await pumpApp(tester, platform: AppPlatform.desktop);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
      expect(app.theme, same(AppTheme.desktopLight()));
      expect(app.darkTheme, same(AppTheme.desktopDark()));
    });

    testWidgets('phones keep following the device, with the phone themes', (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(400, 800));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
      expect(app.theme, same(AppTheme.light()));
      expect(app.darkTheme, same(AppTheme.dark()));
    });

    test('a saved appearance wins over the desktop default', () async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'dark'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appPlatformProvider.overrideWithValue(AppPlatform.desktop),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
    });

    test('desktop: larger type, built once, graphite dark surfaces', () {
      expect(AppTheme.desktopLight(), same(AppTheme.desktopLight()));
      expect(AppTheme.desktopDark(), same(AppTheme.desktopDark()));
      final phone = AppTheme.light().textTheme;
      final desktop = AppTheme.desktopLight().textTheme;
      expect(
        desktop.bodyMedium!.fontSize,
        greaterThan(phone.bodyMedium!.fontSize!),
      );
      expect(
        desktop.headlineSmall!.fontSize,
        greaterThan(phone.headlineSmall!.fontSize!),
      );
      expect(AppTheme.desktopLight().visualDensity, VisualDensity.standard);

      // Phones' dark mode is tinted green; desktop's is a near-neutral grey,
      // and green stays for the menu, the selection and actions.
      double saturation(Color color) => HSLColor.fromColor(color).saturation;
      final dark = AppTheme.desktopDark().colorScheme;
      expect(saturation(AppTheme.dark().colorScheme.surface), greaterThan(0.4));
      for (final surface in [
        dark.surface,
        dark.surfaceContainerLow,
        dark.surfaceContainerHigh,
        dark.outlineVariant,
      ]) {
        expect(saturation(surface), lessThan(0.12), reason: '$surface');
      }
      expect(saturation(dark.onSurfaceVariant), lessThan(0.1));
      expect(dark.primary, AppColors.mint);
    });
  });

  group('side menu (the ticket stub)', () {
    testWidgets(
      'shows the brand, the groups and the account; the pill and the punch follow the selection',
      (tester) async {
        final log = <String>[];
        await _pumpDesktop(tester, _menu(log: log));
        expect(find.text('el3yada'), findsOneWidget);
        expect(find.text("Dr Sara's clinic"), findsOneWidget);
        expect(find.text('Dr Sara Ali'), findsOneWidget);

        final stub = tester.getRect(
          find
              .descendant(
                of: find.byType(AppSideMenu),
                matching: find.byType(PhysicalShape),
              )
              .first,
        );
        expect(stub.left, AppSideMenu.margin);
        expect(stub.width, AppSideMenu.width);

        bool onRow(Rect rect, String label) =>
            (rect.center.dy - tester.getCenter(find.text(label)).dy).abs() < 1;
        var [pill, punch] = _marker(tester);
        expect(pill.contains(tester.getCenter(find.text('Home'))), isTrue);
        expect(onRow(punch, 'Home'), isTrue);
        // The punch sits on the tear line, near the stub's inner edge.
        expect(
          punch.center.dx,
          closeTo(stub.right - AppSideMenu.tearInset, 0.5),
        );

        // The group break puts more space before Chats than between rows.
        final gapBefore =
            tester.getTopLeft(find.text('Chats')).dy -
            tester.getTopLeft(find.text('Patients')).dy;
        final gapAfter =
            tester.getTopLeft(find.text('Billing')).dy -
            tester.getTopLeft(find.text('Chats')).dy;
        expect(gapBefore, greaterThan(gapAfter + 10));

        await tester.tap(find.text('Chats'));
        await tester.pump();
        await tester.pump(Motion.normal ~/ 3);
        [pill, punch] = _marker(tester);
        expect(
          pill.contains(tester.getCenter(find.text('Chats'))),
          isFalse,
          reason: 'still sliding',
        );
        await tester.pumpAndSettle();
        [pill, punch] = _marker(tester);
        expect(pill.contains(tester.getCenter(find.text('Chats'))), isTrue);
        expect(onRow(punch, 'Chats'), isTrue);

        await tester.tap(find.byTooltip('Log out'));
        await tester.tap(find.text('Dr Sara Ali'));
        expect(log, ['sign out', 'profile']);
      },
    );

    testWidgets(
      'in Arabic the stub sits on the right with its tear line towards the page',
      (tester) async {
        await _pumpDesktop(tester, _menu(), rtl: true);
        final stub = tester.getRect(
          find
              .descendant(
                of: find.byType(AppSideMenu),
                matching: find.byType(PhysicalShape),
              )
              .first,
        );
        expect(stub.right, 1280 - AppSideMenu.margin);
        final [_, punch] = _marker(tester);
        expect(
          punch.center.dx,
          closeTo(stub.left + AppSideMenu.tearInset, 0.5),
        );
      },
    );

    testWidgets(
      'with reduced motion the marker appears on the new row instead of sliding',
      (tester) async {
        await _pumpDesktop(tester, _menu(), reduced: true);
        await tester.tap(find.text('Billing'));
        await tester.pump();
        final billing = tester.getCenter(find.text('Billing'));
        expect(_marker(tester).any((rect) => rect.contains(billing)), isTrue);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('rows answer the mouse and the keyboard', (tester) async {
      await _pumpDesktop(tester, _menu());
      Color? labelColor(String label) =>
          tester.widget<Text>(find.text(label)).style?.color;
      final idle = labelColor('Billing');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Billing')));
      await tester.pumpAndSettle();
      expect(labelColor('Billing'), isNot(idle));
      expect(labelColor('Billing'), Colors.white);

      // Tab moves through the rows; Enter opens one.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final [pill, _] = _marker(tester);
      expect(pill.contains(tester.getCenter(find.text('Billing'))), isTrue);
    });

    testWidgets(
      'the mark writes itself once, then beats once under the mouse',
      (tester) async {
        await _pumpDesktop(
          tester,
          const Center(child: AppLogoMark(animate: true, beatOnHover: true)),
        );
        expect(tester.hasRunningAnimations, isFalse);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(AppLogoMark)));
        await tester.pump();
        expect(tester.hasRunningAnimations, isTrue);
        await tester.pumpAndSettle();

        // With reduced motion it stays still.
        await _pumpDesktop(
          tester,
          const Center(
            child: AppLogoMark(key: ValueKey('still'), beatOnHover: true),
          ),
          reduced: true,
        );
        await mouse.moveTo(Offset.zero);
        await mouse.moveTo(tester.getCenter(find.byType(AppLogoMark)));
        await tester.pump();
        expect(tester.hasRunningAnimations, isFalse);
      },
    );
  });

  group('desktop page header', () {
    testWidgets(
      'no top bar; Back sits at the top of the page, named after its section',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpApp(
          tester,
          platform: AppPlatform.desktop,
          size: const Size(1280, 800),
          extra: [fakeClinicAdminOverride()],
        );
        await signIn(tester, 'doctor@el3yada.dev');
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(DesktopQuickSettings), findsOneWidget);

        goTo(tester, '/doctor/branches');
        await settle(tester);
        expect(find.byType(AppBackButton), findsNothing, reason: 'a menu root');

        goTo(
          tester,
          '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}',
        );
        await settle(tester);
        final back = find.byType(AppBackButton);
        expect(
          find.descendant(of: find.byType(DesktopPageHeader), matching: back),
          findsOneWidget,
        );
        expect(
          find.descendant(of: back, matching: find.text('Branches')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Back to Branches'), findsOneWidget);

        // At the page's start edge, right beside the menu, above the content.
        final menu = tester.getRect(find.byType(AppSideMenu));
        final pill = tester.getRect(back);
        expect(pill.left - menu.right, inInclusiveRange(0, 32));
        expect(pill.top, lessThan(40));

        await tester.tap(back);
        await settle(tester);
        expect(_path(tester), '/doctor/branches');
        expect(find.byType(AppBackButton), findsNothing);
        handle.dispose();
      },
    );

    testWidgets(
      'in Arabic Back sits on the right, beside the menu; Alt+Left goes back',
      (tester) async {
        await pumpApp(
          tester,
          platform: AppPlatform.desktop,
          size: const Size(1280, 800),
          prefs: const {'settings.locale': 'ar'},
          extra: [fakeClinicAdminOverride()],
        );
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'doctor@el3yada.dev',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'dev');
        await tester.tap(find.byType(FilledButton).first);
        await settle(tester);
        goTo(
          tester,
          '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}',
        );
        await settle(tester);
        final menu = tester.getRect(find.byType(AppSideMenu));
        final pill = tester.getRect(find.byType(AppBackButton));
        expect(menu.left - pill.right, inInclusiveRange(0, 32));

        // Focus the Back pill, then use the shortcut.
        Focus.of(
          tester.element(
            find
                .descendant(
                  of: find.byType(AppBackButton),
                  matching: find.byType(Text),
                )
                .first,
          ),
        ).requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await settle(tester);
        expect(_path(tester), '/doctor/branches');
      },
    );

    testWidgets('quick settings switch the appearance and the language', (
      tester,
    ) async {
      await pumpApp(
        tester,
        platform: AppPlatform.desktop,
        size: const Size(1280, 800),
      );
      await signIn(tester, 'doctor@el3yada.dev');
      await tester.tap(find.byTooltip('Appearance: Dark'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.tap(find.byTooltip('Switch language'));
      await tester.pumpAndSettle();
      expect(find.text('ع'), findsNothing);
      expect(find.text('EN'), findsOneWidget);
    });
  });

  group('desktop login (a queue ticket)', () {
    for (final arabic in [false, true]) {
      testWidgets(
        'the brand sits on the stub at the start, the form beside it (arabic: $arabic)',
        (tester) async {
          await pumpApp(
            tester,
            platform: AppPlatform.desktop,
            size: const Size(1280, 800),
            prefs: {'settings.locale': arabic ? 'ar' : 'en'},
          );
          final brand = tester.getCenter(
            find.text(arabic ? 'العيادة' : 'el3yada'),
          );
          final form = tester.getCenter(find.byType(TextFormField).first);
          expect(arabic ? brand.dx > form.dx : brand.dx < form.dx, isTrue);
          expect(find.byType(DesktopQuickSettings), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'after the splash the pine gathers into the stub before the form shows',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: await appOverrides(platform: AppPlatform.desktop),
            child: const El3yadaApp(),
          ),
        );
        // The splash: the mark writes itself, no form yet.
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(TextFormField), findsNothing);
        for (
          var i = 0;
          i < 80 && find.byType(TextFormField).evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        // The form arrives while the ticket's body slides out (still faint).
        final opacity = tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byType(TextFormField).first,
                matching: find.byType(Opacity),
              )
              .first,
        );
        expect(opacity.opacity, lessThan(1));
        await settle(tester);
        expect(
          tester
              .widget<Opacity>(
                find
                    .ancestor(
                      of: find.byType(TextFormField).first,
                      matching: find.byType(Opacity),
                    )
                    .first,
              )
              .opacity,
          1,
        );
      },
    );
  });

  // A desktop window made narrow keeps the desktop type scale with the
  // tablet rail or the phone bar; nothing may overflow.
  for (final size in [const Size(900, 700), const Size(520, 800)]) {
    testWidgets(
      'a narrow desktop window (${size.width.toInt()} wide) lays out without overflow',
      (tester) async {
        await pumpApp(
          tester,
          platform: AppPlatform.desktop,
          size: size,
          prefs: const {'settings.locale': 'ar'},
          extra: [fakeClinicAdminOverride()],
        );
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'doctor@el3yada.dev',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'dev');
        await tester.tap(find.byType(FilledButton).first);
        await settle(tester);
        expect(tester.takeException(), isNull);
        for (final path in [
          '/doctor/patients',
          '/doctor/branches',
          '/doctor/settings',
          '/doctor/more',
        ]) {
          goTo(tester, path);
          await settle(tester);
          expect(tester.takeException(), isNull, reason: path);
        }
      },
    );
  }
}
