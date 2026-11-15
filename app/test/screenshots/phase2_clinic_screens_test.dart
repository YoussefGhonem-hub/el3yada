import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import '../support/clinic_admin_support.dart';
import 'capture.dart';

/// Phase 2 clinic settings screens (D22, D24–D29, D37, AS12, AS19) in
/// Arabic, light and dark, at phone width and at desktop width. See
/// capture.dart.
void main() {
  setUpAll(() async {
    if (screenshotsEnabled) await loadRealFonts();
  });

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    Future<void> signedIn(WidgetTester tester, Size size, String account) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: await appOverrides(
          prefs: {'settings.locale': 'ar', 'settings.themeMode': theme},
          platform: size.width > 900 ? AppPlatform.desktop : AppPlatform.mobile,
          extra: [fakeClinicAdminOverride()],
        ),
        child: RepaintBoundary(key: screenshotKey, child: const El3yadaApp()),
      ));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).at(0), account);
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
    }

    for (final (width, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets('D24 settings ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/settings');
        await settle(tester);
        await capture(tester, 'd24_settings_${width}_ar_$theme');
        if (width == 'phone') {
          await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -900));
          await settle(tester);
          await capture(tester, 'd24_settings_end_${width}_ar_$theme');
        }
      });

      testWidgets('AS12 settings ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, '01000000005');
        goTo(tester, '/assistant/settings');
        await settle(tester);
        await capture(tester, 'as12_settings_${width}_ar_$theme');
      });

      testWidgets('D22 profile ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/settings/profile');
        await settle(tester);
        await capture(tester, 'd22_profile_${width}_ar_$theme');
      });

      testWidgets('D37 prices ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/settings/prices');
        await settle(tester);
        await capture(tester, 'd37_prices_${width}_ar_$theme');
        await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -900));
        await settle(tester);
        await capture(tester, 'd37_prices_end_${width}_ar_$theme');
      });

      testWidgets('D28 branches ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/branches');
        await settle(tester);
        await capture(tester, 'd28_branches_${width}_ar_$theme');
      });

      testWidgets('D29 branch editor ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}');
        await settle(tester);
        await capture(tester, 'd29_info_${width}_ar_$theme');
        for (final tab in ['address', 'contact', 'hours', 'clinic']) {
          goTo(tester, '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}?tab=$tab');
          await settle(tester);
          await capture(tester, 'd29_${tab}_${width}_ar_$theme');
        }
        // The BR-BR9 refusal: Nasr City has bookings.
        goTo(tester, '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}');
        await settle(tester);
        await tester.ensureVisible(find.text('أرشفة').first);
        await tester.tap(find.text('أرشفة').first);
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'أرشفة'));
        await settle(tester);
        await capture(tester, 'd29_bookings_refusal_${width}_ar_$theme');
      });

      testWidgets('D25 and D26 assistants ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/assistants');
        await settle(tester);
        await capture(tester, 'd25_assistants_${width}_ar_$theme');

        goTo(tester, '/doctor/assistants/${FakeClinicAdminRepository.disabledAssistantId}');
        await settle(tester);
        await capture(tester, 'd26_edit_${width}_ar_$theme');

        goTo(tester, '/doctor/assistants/new');
        await settle(tester);
        await tester.enterText(find.byType(TextField).at(0), 'سارة محمود');
        await tester.enterText(find.byType(TextField).at(1), '01112223334');
        await tester.pumpAndSettle();
        await capture(tester, 'd26_new_${width}_ar_$theme');
        // A box with a dependency, to show the note under it.
        final edit = find.text('تعديل التاريخ المرضي');
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        await tester.tap(edit);
        await settle(tester);
        await capture(tester, 'd26_permissions_${width}_ar_$theme');

        await tester.ensureVisible(find.text('كل الفروع').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('كل الفروع').first);
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'إضافة مساعد').last);
        await settle(tester);
        await capture(tester, 'd26_temporary_password_${width}_ar_$theme');
      });

      testWidgets('D27 activity log ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/activity');
        await settle(tester);
        await capture(tester, 'd27_activity_${width}_ar_$theme');
      });

      testWidgets('AS19 prices for an office manager ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, '01000000005');
        goTo(tester, '/assistant/settings/prices');
        await settle(tester);
        await capture(tester, 'as19_prices_${width}_ar_$theme');
      });

      testWidgets('D29 new branch ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size, 'doctor@el3yada.dev');
        goTo(tester, '/doctor/branches/new');
        await settle(tester);
        await capture(tester, 'd29_new_${width}_ar_$theme');
      });
    }
  }
}
