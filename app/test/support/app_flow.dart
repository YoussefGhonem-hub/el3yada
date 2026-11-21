import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'app_overrides.dart';

/// The whole app with [appOverrides], at [size], settled on its first screen.
Future<void> pumpApp(
  WidgetTester tester, {
  AppPlatform platform = AppPlatform.mobile,
  Size size = const Size(1400, 900),
  Map<String, Object> prefs = const {'settings.locale': 'en'},
  PublicSettings settings = const PublicSettings(),
  FakePublicSettingsRepository? publicSettings,
  String appVersion = '1.0.0',
  ClinicRepository? clinic,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: await appOverrides(
        platform: platform,
        prefs: prefs,
        settings: settings,
        publicSettings: publicSettings,
        appVersion: appVersion,
        clinic: clinic,
        extra: extra,
      ),
      child: const El3yadaApp(),
    ),
  );
  await settle(tester);
}

/// Fills the login form and taps Sign in, then waits for the check mark and
/// the next screen.
Future<void> signIn(
  WidgetTester tester,
  String identifier, {
  String password = 'dev',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), identifier);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await settle(tester);
}

/// pumpAndSettle, plus the short timers (the check mark's hold) it skips.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}
