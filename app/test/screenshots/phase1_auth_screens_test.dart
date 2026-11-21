import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_overrides.dart';
import 'capture.dart';

/// Phase 1 sign-in screens in Arabic, light and dark. See capture.dart.
void main() {
  setUpAll(() async {
    if (screenshotsEnabled) await loadRealFonts();
  });

  const support = PublicSettings(
    supportPhone: '01000000000',
    supportWhatsapp: '01000000000',
    supportEmail: 'help@el3yada.app',
  );

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    Future<void> pumpApp(
      WidgetTester tester, {
      Map<String, Object>? prefs,
      PublicSettings settings = support,
      String appVersion = '1.0.0',
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appOverrides(
            prefs:
                prefs ?? {'settings.locale': 'ar', 'settings.themeMode': theme},
            settings: settings,
            appVersion: appVersion,
            platform: size.width > 900
                ? AppPlatform.desktop
                : AppPlatform.mobile,
          ),
          child: RepaintBoundary(key: screenshotKey, child: const El3yadaApp()),
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    Future<void> signIn(
      WidgetTester tester,
      String identifier, {
      String password = 'dev',
    }) async {
      await tester.enterText(find.byType(TextFormField).at(0), identifier);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
    }

    testWidgets('splash and login ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await capture(tester, 'a1_splash_drawing_ar_$theme');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 180));
      await capture(tester, 'a1_to_a3_rising_ar_$theme');
      await settle(tester);
      await capture(tester, 'a3_login_ar_$theme');

      await signIn(tester, 'doctor@el3yada.dev', password: 'wrong');
      await capture(tester, 'a3_login_error_ar_$theme');

      await signIn(tester, '01000000003');
      await capture(tester, 'a3_choose_account_ar_$theme');
    });

    testWidgets('login on desktop ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(tester, size: const Size(1280, 800));
      await settle(tester);
      await capture(tester, 'a3_login_desktop_ar_$theme');
    });

    testWidgets('language choice ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(tester, prefs: {'settings.themeMode': theme});
      await settle(tester);
      await capture(tester, 'a2_language_$theme');
    });

    testWidgets('set new password ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(tester);
      await settle(tester);
      await signIn(tester, '01000000004');
      await tester.enterText(find.byType(TextFormField).at(0), 'abcdefgh');
      await tester.tap(find.text('حفظ كلمة المرور'));
      await settle(tester);
      await capture(tester, 'a9_set_password_ar_$theme');
    });

    testWidgets('forgot password ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(tester);
      await settle(tester);
      await tester.tap(find.text('نسيت كلمة المرور؟'));
      await settle(tester);
      await capture(tester, 'a8_forgot_ar_$theme');
      await tester.enterText(find.byType(TextFormField), '01000000002');
      await tester.tap(find.text('إرسال'));
      await settle(tester);
      await capture(tester, 'a8_sent_phone_ar_$theme');
    });

    testWidgets('status screens ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(tester);
      await settle(tester);
      await signIn(tester, 'disabled@el3yada.dev');
      await capture(tester, 'a10_disabled_ar_$theme');
    });

    testWidgets('free trial ended ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(tester);
      await settle(tester);
      await signIn(tester, 'trial-ended@el3yada.dev');
      await capture(tester, 'a15_trial_ended_ar_$theme');
    });

    testWidgets('maintenance ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(
        tester,
        settings: const PublicSettings(
          maintenanceEnabled: true,
          maintenanceMessageAr: 'نجري تحديثاً للنظام، وسنعود الساعة 10 مساءً.',
        ),
      );
      await settle(tester);
      await capture(tester, 'a13_maintenance_ar_$theme');
    });

    testWidgets('force update ($theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await pumpApp(
        tester,
        settings: const PublicSettings(minAppVersion: {'android': '2.0.0'}),
      );
      await settle(tester);
      await capture(tester, 'a11_update_ar_$theme');
    });
  }
}
