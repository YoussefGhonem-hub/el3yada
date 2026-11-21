import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/notifications/local_notifier.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/realtime/realtime_service.dart';
import 'package:el3yada/features/patient/data/fake_patient_repository.dart';
import 'package:el3yada/features/patient/data/patient_repository.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import '../support/app_overrides.dart';
import 'package:material_ui/material_ui.dart';
import '../support/app_flow.dart' show settle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

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
  PublicSettings settings = const PublicSettings(),
  PatientRepository? patients,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rig = TestRig();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await appOverrides(
          platform: platform,
          prefs: {'settings.locale': locale},
          settings: settings,
        ),
        patientRepositoryProvider.overrideWithValue(
          patients ?? FakePatientRepository(delay: Duration.zero),
        ),
        realtimeServiceProvider.overrideWithValue(rig.realtime),
        localNotifierProvider.overrideWithValue(rig.notifier),
        ...overrides,
      ],
      child: const El3yadaApp(),
    ),
  );
  await settle(tester);
  await tester.enterText(find.byType(TextFormField).at(0), identifier);
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();

  if (find.byType(CheckboxListTile).evaluate().isNotEmpty) {
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, locale == 'ar' ? 'متابعة' : 'Continue'),
    );
    await tester.pumpAndSettle();
  }
  return rig;
}
