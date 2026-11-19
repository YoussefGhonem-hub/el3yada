import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/notifications/local_notifier.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/realtime/realtime_service.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/core/storage/token_store.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/patient/data/fake_patient_repository.dart';
import 'package:el3yada/features/patient/data/patient_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fakes shared by the widget tests of Phases 5 and 6.
class TestRig {
  final realtime = FakeRealtimeService();
  final notifier = SilentLocalNotifier();
}

/// Pumps the app and signs in with a dev test account. Patients also accept the terms.
Future<TestRig> pumpSignedIn(
  WidgetTester tester, {
  required String identifier,
  AppPlatform platform = AppPlatform.mobile,
  Size size = const Size(400, 860),
  String locale = 'en',
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'settings.locale': locale});
  final prefs = await SharedPreferences.getInstance();
  final rig = TestRig();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appPlatformProvider.overrideWithValue(platform),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(delay: Duration.zero)),
      patientRepositoryProvider.overrideWithValue(FakePatientRepository(delay: Duration.zero)),
      realtimeServiceProvider.overrideWithValue(rig.realtime),
      localNotifierProvider.overrideWithValue(rig.notifier),
      ...overrides,
    ],
    child: const El3yadaApp(),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), identifier);
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();

  if (find.byType(CheckboxListTile).evaluate().isNotEmpty) {
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, locale == 'ar' ? 'متابعة' : 'Continue'));
    await tester.pumpAndSettle();
  }
  return rig;
}
