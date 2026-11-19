import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/core/storage/token_store.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester, {required AppPlatform platform, Size size = const Size(1400, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'settings.locale': 'en'});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appPlatformProvider.overrideWithValue(platform),
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(delay: Duration.zero)),
      ],
      child: const El3yadaApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byType(TextFormField).at(0), identifier);
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens on the login screen', (tester) async {
    await pumpApp(tester, platform: AppPlatform.mobile);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('a doctor on desktop lands on the live board with the side menu', (tester) async {
    await pumpApp(tester, platform: AppPlatform.desktop);
    await signIn(tester, 'doctor@el3yada.dev');

    expect(find.text('el3yada · Doctor'), findsOneWidget);
    expect(find.text('Screen D34 in spec.md'), findsOneWidget);
    expect(find.text('Branches'), findsOneWidget); // side menu shows every item
  });

  testWidgets('a patient on desktop sees the "use the mobile app" message', (tester) async {
    await pumpApp(tester, platform: AppPlatform.desktop);
    await signIn(tester, '01000000002');

    expect(find.text('Patient accounts use the mobile app'), findsOneWidget);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('a patient on a phone gets the bottom navigation bar', (tester) async {
    await pumpApp(tester, platform: AppPlatform.mobile, size: const Size(400, 800));
    await signIn(tester, '01000000002');

    expect(find.byType(NavigationBar), findsOneWidget);
    // P1 is built: first login starts with the terms acceptance (A9).
    expect(find.text('Before you start'), findsOneWidget);
  });
}
