import 'package:el3yada/core/theme/app_theme.dart';
import 'package:el3yada/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [home] in a themed, localised MaterialApp.
/// [rtl] switches to Arabic; [reduced] turns on the device's reduced motion
/// (`MediaQuery.disableAnimations`).
Future<void> pumpHarness(
  WidgetTester tester,
  Widget home, {
  bool rtl = false,
  bool reduced = false,
  bool dark = false,
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    harness(home, rtl: rtl, reduced: reduced, dark: dark),
  );
}

Widget harness(
  Widget home, {
  bool rtl = false,
  bool reduced = false,
  bool dark = false,
}) => MaterialApp(
  theme: dark ? AppTheme.dark() : AppTheme.light(),
  locale: Locale(rtl ? 'ar' : 'en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: home,
);
