import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/widgets/navigation/floating_nav_bar.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_flow.dart';
import '../support/app_overrides.dart';

void main() {
  testWidgets('opens on the login screen', (tester) async {
    await pumpApp(tester);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('a doctor on desktop lands on the home with the side menu', (tester) async {
    await pumpApp(tester, platform: AppPlatform.desktop);
    await signIn(tester, 'doctor@el3yada.dev');

    expect(find.text('el3yada · Doctor'), findsOneWidget);
    // The home until the live board (D34) arrives in Phase 6.
    expect(find.text('Search patient'), findsOneWidget);
    expect(find.text('Branches'), findsOneWidget); // side menu shows every item
  });

  testWidgets('a patient on desktop sees the "use the mobile app" message (A14)', (tester) async {
    await pumpApp(tester, platform: AppPlatform.desktop);
    await signIn(tester, '01000000002');

    expect(find.text('Patient accounts use the mobile app'), findsOneWidget);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('a patient on a phone gets the bottom navigation bar', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await signIn(tester, '01000000002');

    expect(find.byType(FloatingNavBar), findsOneWidget);
    expect(find.text('Screen P1 in spec.md'), findsOneWidget);
  });

  testWidgets('wrong credentials show the error and keep the form', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await signIn(tester, 'doctor@el3yada.dev', password: 'wrong');

    expect(find.text('Wrong mobile number/email or password'), findsOneWidget);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('one number with two accounts asks "log in as" (A3)', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await signIn(tester, '01000000003');

    expect(find.text('Log in as'), findsOneWidget);
    await tester.tap(find.text('Assistant'));
    await settle(tester);

    // Assistants see their doctor's clinic in the top bar (spec 7.6).
    expect(find.text("Dr تجريبي's clinic"), findsOneWidget);
  });

  testWidgets('first launch asks for the language (A2), then shows the login', (tester) async {
    await pumpApp(tester, size: const Size(400, 800), prefs: const {});

    expect(find.text('العربية'), findsWidgets);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('a too-old app version shows Update required (A11)', (tester) async {
    await pumpApp(
      tester,
      size: const Size(400, 800),
      appVersion: '1.0.0',
      settings: const PublicSettings(minAppVersion: {'android': '1.2.0'}),
    );

    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Mobile number or email'), findsNothing);
  });

  testWidgets('maintenance shows the admin message (A13), and Retry lets the user in once it ends', (tester) async {
    final settings = FakePublicSettingsRepository(
      const PublicSettings(maintenanceEnabled: true, maintenanceMessageEn: 'Back at 10 pm.'),
    );
    await pumpApp(tester, size: const Size(400, 800), publicSettings: settings);

    expect(find.text('Back at 10 pm.'), findsOneWidget);

    settings.settings = const PublicSettings();
    await tester.tap(find.text('Try again'));
    await settle(tester);

    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('offline at start-up still opens the login', (tester) async {
    final settings = FakePublicSettingsRepository()..offline = true;
    await pumpApp(tester, size: const Size(400, 800), publicSettings: settings);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('a doctor waiting for approval lands on A6', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await signIn(tester, 'pending@el3yada.dev');
    expect(find.byIcon(Icons.hourglass_top), findsOneWidget);
  });

  testWidgets('a rejected doctor sees the reason (A7)', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await signIn(tester, 'rejected@el3yada.dev');
    expect(find.text('صورة الكارنيه غير واضحة، ارفع صورة أوضح.'), findsOneWidget);
  });

  testWidgets('a disabled account sees A10, and Log out returns to the login', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await signIn(tester, 'disabled@el3yada.dev');

    expect(find.text('Account disabled'), findsOneWidget);
    await tester.tap(find.text('Log out'));
    await settle(tester);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });

  testWidgets('a first login must set a new password and accept the Terms (A9)', (tester) async {
    await pumpApp(tester, size: const Size(400, 900));
    await signIn(tester, '01000000004');

    expect(find.text('Set a new password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.tap(find.text('Save password'));
    await settle(tester);
    expect(find.text('Accept the Terms and the Privacy Policy to continue.'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Save password'));
    await settle(tester);

    expect(find.text('Screen P1 in spec.md'), findsOneWidget);
  });

  testWidgets('forgot password by email takes the code from the email and a new password (A8)', (tester) async {
    await pumpApp(tester, size: const Size(400, 900));
    await tester.tap(find.text('Forgot password?'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField), 'doctor@el3yada.dev');
    await tester.tap(find.text('Send'));
    await settle(tester);
    expect(find.text('Check your email'), findsOneWidget);

    await tester.tap(find.text('I have a code'));
    await settle(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'expired');
    await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
    await tester.tap(find.text('Save password'));
    await settle(tester);
    expect(find.text('This code has expired. Ask for a new email.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'abc123');
    await tester.tap(find.text('Save password'));
    await settle(tester);
    expect(find.text('Password changed'), findsOneWidget);
  });

  testWidgets('forgot password by mobile tells the user their doctor will reset it (A8)', (tester) async {
    await pumpApp(tester, size: const Size(400, 800));
    await tester.tap(find.text('Forgot password?'));
    await settle(tester);

    await tester.enterText(find.byType(TextFormField), '01000000002');
    await tester.tap(find.text('Send'));
    await settle(tester);

    expect(find.text('Request sent'), findsOneWidget);
    await tester.tap(find.text('Back to sign in'));
    await settle(tester);
    expect(find.text('Mobile number or email'), findsOneWidget);
  });
}
