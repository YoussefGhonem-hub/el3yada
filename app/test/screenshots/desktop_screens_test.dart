import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import '../support/clinic_admin_support.dart';
import '../support/clinic_records_support.dart';
import 'capture.dart';

/// The desktop design (side menu as the ticket's stub, the page header with
/// Back, the desktop type scale and the graphite dark mode) in a 1280 × 800
/// Windows window, in Arabic and English, light and dark. Files start with
/// `desk_`. See capture.dart.
void main() {
  setUpAll(() async {
    if (screenshotsEnabled) await loadRealFonts();
  });

  const window = Size(1280, 800);

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      final tag = '${language}_${dark ? 'dark' : 'light'}';

      Future<void> pumpApp(
        WidgetTester tester, {
        List<Override> extra = const [],
      }) async {
        tester.view.physicalSize = window;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: await appOverrides(
              prefs: {
                'settings.locale': language,
                'settings.themeMode': dark ? 'dark' : 'light',
              },
              platform: AppPlatform.desktop,
              extra: extra,
            ),
            child: RepaintBoundary(
              key: screenshotKey,
              child: const El3yadaApp(),
            ),
          ),
        );
      }

      Future<void> signIn(WidgetTester tester, String account) async {
        await tester.enterText(find.byType(TextFormField).at(0), account);
        await tester.enterText(find.byType(TextFormField).at(1), 'dev');
        await tester.tap(find.byType(FilledButton).first);
        await settle(tester);
      }

      testWidgets('login ($tag)', skip: !screenshotsEnabled, (tester) async {
        await pumpApp(tester);
        if (tag == 'ar_light') {
          // The signature moment, frame by frame.
          await tester.pump(const Duration(milliseconds: 350));
          await capture(tester, 'desk_login_1_drawing_$tag');
          // The login starts once the mark has drawn and start-up is done.
          for (
            var i = 0;
            i < 80 && find.byType(TextFormField).evaluate().isEmpty;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 50));
          }
          var elapsed = 0;
          for (final (ms, name) in [
            (140, '2_gathering'),
            (380, '3_sliding'),
            (640, '4_stitching'),
          ]) {
            await tester.pump(Duration(milliseconds: ms - elapsed));
            elapsed = ms;
            await capture(tester, 'desk_login_${name}_$tag');
          }
        }
        await settle(tester);
        await capture(tester, 'desk_login_$tag');
      });

      testWidgets('doctor ($tag)', skip: !screenshotsEnabled, (tester) async {
        await pumpApp(
          tester,
          extra: [fakeRecordsOverride(), fakeClinicAdminOverride()],
        );
        await settle(tester);
        await signIn(tester, 'doctor@el3yada.dev');
        await capture(tester, 'desk_home_doctor_$tag');

        goTo(tester, '/doctor/patients');
        await settle(tester);
        await capture(tester, 'desk_patients_$tag');

        goTo(
          tester,
          '/doctor/patients/${recordsOf(tester).patientIdByName(SeedPatients.mona)}',
        );
        await settle(tester);
        await capture(tester, 'desk_profile_$tag');

        goTo(tester, '/doctor/branches');
        await settle(tester);
        await capture(tester, 'desk_branches_$tag');

        goTo(
          tester,
          '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}',
        );
        await settle(tester);
        await capture(tester, 'desk_branch_editor_$tag');

        goTo(tester, '/doctor/settings');
        await settle(tester);
        await capture(tester, 'desk_settings_$tag');
      });

      testWidgets('admin ($tag)', skip: !screenshotsEnabled, (tester) async {
        await pumpApp(tester, extra: [fakeAdminOverride()]);
        await settle(tester);
        await signIn(tester, 'admin@el3yada.dev');
        await capture(tester, 'desk_admin_home_$tag');
        goTo(tester, '/admin/signups');
        await settle(tester);
        await capture(tester, 'desk_admin_signups_$tag');
      });
    }
  }
}
