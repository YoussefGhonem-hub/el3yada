import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/patients/presentation/patient_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import '../support/clinic_records_support.dart';
import 'capture.dart';

/// Phase 2 patient, session and fee screens (D1–D9, AS1–AS5) in Arabic,
/// light and dark, at phone and desktop width. See capture.dart.
void main() {
  setUpAll(() async {
    if (screenshotsEnabled) await loadRealFonts();
  });

  const phone = Size(390, 844);
  const desktop = Size(1366, 860);

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    Future<void> signedIn(
      WidgetTester tester,
      Size size,
      String account,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appOverrides(
            prefs: {'settings.locale': 'ar', 'settings.themeMode': theme},
            platform: size.width > 900
                ? AppPlatform.desktop
                : AppPlatform.mobile,
            extra: [fakeRecordsOverride()],
          ),
          child: RepaintBoundary(key: screenshotKey, child: const El3yadaApp()),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).at(0), account);
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
    }

    String id(WidgetTester tester, String name) =>
        recordsOf(tester).patientIdByName(name);

    for (final (width, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets(
        'home, D1, D2, D3 ($width, $theme)',
        skip: !screenshotsEnabled,
        (tester) async {
          await signedIn(tester, size, 'doctor@el3yada.dev');
          await capture(tester, 'home_doctor_${width}_ar_$theme');
          goTo(tester, '/doctor/dashboard');
          await settle(tester);
          await capture(tester, 'd1_dashboard_${width}_ar_$theme');
          goTo(tester, '/doctor/dashboard/today');
          await settle(tester);
          await capture(tester, 'd2_today_${width}_ar_$theme');
          goTo(tester, '/doctor/dashboard/month');
          await settle(tester);
          await capture(tester, 'd3_month_${width}_ar_$theme');
        },
      );

      testWidgets('D4, D6 ($width, $theme)', skip: !screenshotsEnabled, (
        tester,
      ) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/patients');
        await settle(tester);
        await capture(tester, 'd4_register_${width}_ar_$theme');
        if (width == 'desktop') {
          await tester.tap(find.text('منى حسن إبراهيم').first);
          await settle(tester);
          await capture(tester, 'd4_master_detail_${width}_ar_$theme');
        }
        goTo(tester, '/doctor/patients/${id(tester, SeedPatients.mona)}');
        await settle(tester);
        await capture(tester, 'd6_profile_overview_${width}_ar_$theme');
        await tester.scrollUntilVisible(
          find.byType(TabBar),
          300,
          scrollable: find
              .descendant(
                of: find.byType(PatientProfileView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await settle(tester);
        await tester.tap(find.widgetWithText(Tab, 'الزيارات'));
        await settle(tester);
        await capture(tester, 'd6_profile_sessions_${width}_ar_$theme');
        goTo(tester, '/doctor/patients/${id(tester, SeedPatients.noura)}');
        await settle(tester);
        await capture(tester, 'd6_profile_linked_${width}_ar_$theme');
      });

      testWidgets('D5, D7 ($width, $theme)', skip: !screenshotsEnabled, (
        tester,
      ) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/patients/new');
        await settle(tester);
        await capture(tester, 'd5_add_${width}_ar_$theme');
        await tester.enterText(find.byType(TextFormField).first, '01122223333');
        await tester.pump(const Duration(seconds: 1));
        await settle(tester);
        await capture(tester, 'd5_link_dialog_${width}_ar_$theme');
        await tester.tap(find.text('إلغاء'));
        await settle(tester);
        await capture(tester, 'd5_elsewhere_${width}_ar_$theme');

        goTo(tester, '/doctor/patients/${id(tester, SeedPatients.mona)}/edit');
        await settle(tester);
        await capture(tester, 'd7_identity_${width}_ar_$theme');
        await tester.tap(find.text('الملف الطبي').first);
        await settle(tester);
        await capture(tester, 'd7_medical_${width}_ar_$theme');
      });

      testWidgets('D8, D9 ($width, $theme)', skip: !screenshotsEnabled, (
        tester,
      ) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(
          tester,
          '/doctor/patients/${id(tester, SeedPatients.mona)}/sessions/new',
        );
        await settle(tester);
        await capture(tester, 'd8_blocked_${width}_ar_$theme');

        goTo(
          tester,
          '/doctor/patients/${id(tester, SeedPatients.sara)}/sessions/new',
        );
        await settle(tester);
        await capture(tester, 'd8_first_visit_${width}_ar_$theme');

        goTo(
          tester,
          '/doctor/patients/${id(tester, SeedPatients.laila)}/sessions/new',
        );
        await settle(tester);
        await tester.tap(find.text('استشارة').first);
        await settle(tester);
        await capture(tester, 'd8_type_${width}_ar_$theme');
        await tester.tap(find.text('التالي'));
        await settle(tester);
        await capture(tester, 'd8_details_${width}_ar_$theme');
        await tester.tap(find.text('حفظ الزيارة'));
        await settle(tester);
        await capture(tester, 'd8_confirm_${width}_ar_$theme');
        await tester.tap(find.text('حفظ'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 600));
        await settle(tester);
        await capture(tester, 'd8_after_save_${width}_ar_$theme');
        await tester.tap(find.text('عرض الزيارة'));
        await settle(tester);
        await capture(tester, 'd9_details_${width}_ar_$theme');
      });

      testWidgets(
        'AS1, AS5 reception ($width, $theme)',
        skip: !screenshotsEnabled,
        (tester) async {
          await signedIn(tester, size, '01000000001');
          await capture(tester, 'as1_home_${width}_ar_$theme');
          goTo(tester, '/assistant/patients/${id(tester, SeedPatients.laila)}');
          await settle(tester);
          await capture(tester, 'as4_profile_${width}_ar_$theme');
          goTo(
            tester,
            '/assistant/patients/${id(tester, SeedPatients.laila)}/sessions/new',
          );
          await settle(tester);
          await tester.tap(find.text('كشف').first);
          await settle(tester);
          await tester.tap(find.text('التالي'));
          await settle(tester);
          await capture(tester, 'as5_details_${width}_ar_$theme');
        },
      );
    }
  }
}
