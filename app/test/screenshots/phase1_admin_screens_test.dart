import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin/presentation/signups/license_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import 'capture.dart';

/// Phase 1 admin screens (AD2, AD3, AD13, AD14, AD15, AD18) in Arabic,
/// light and dark, at phone width and at desktop width. See capture.dart.
void main() {
  setUpAll(() async {
    if (screenshotsEnabled) await loadRealFonts();
  });

  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    Future<void> settle(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    /// Decodes the pictures on screen (real async work, so in runAsync).
    Future<void> decodeImages(WidgetTester tester) async {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pump();
    }

    Future<void> signedIn(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: await appOverrides(
          prefs: {'settings.locale': 'ar', 'settings.themeMode': theme},
          platform: size.width > 900 ? AppPlatform.desktop : AppPlatform.mobile,
          extra: [fakeAdminOverride()],
        ),
        child: RepaintBoundary(key: screenshotKey, child: const El3yadaApp()),
      ));
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'admin@el3yada.dev');
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
    }

    for (final (width, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets('AD2 and AD3 sign-ups ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size);
        goTo(tester, '/admin/signups');
        await settle(tester);
        await decodeImages(tester);
        await capture(tester, 'ad2_signups_${width}_ar_$theme');

        if (width == 'phone') {
          await tester.tap(find.textContaining('منى حسن'));
          await settle(tester);
          await capture(tester, 'ad3_review_pdf_${width}_ar_$theme');
          await tester.tap(find.byType(BackButton));
          await settle(tester);
        }
        await tester.tap(find.textContaining('سامي عبد الله').first);
        await settle(tester);
        await decodeImages(tester);
        await capture(tester, 'ad3_review_image_${width}_ar_$theme');

        // The full-screen license viewer.
        await tester.ensureVisible(find.text('تكبير').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('تكبير').first);
        await settle(tester);
        await decodeImages(tester);
        expect(find.byType(LicenseViewer), findsOneWidget);
        await capture(tester, 'ad3_license_viewer_${width}_ar_$theme');
        await tester.tap(find.byTooltip('إغلاق'));
        await settle(tester);

        await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -700));
        await settle(tester);
        await capture(tester, 'ad3_review_details_${width}_ar_$theme');

        // Reject asks for a reason (at the end of the page on phones).
        await tester.ensureVisible(find.text('رفض').last);
        await tester.pumpAndSettle();
        if (width == 'phone') await capture(tester, 'ad3_review_actions_${width}_ar_$theme');
        await tester.tap(find.text('رفض').last);
        await settle(tester);
        await tester.tap(find.byType(ActionChip).first);
        await tester.pumpAndSettle();
        await capture(tester, 'ad3_reject_dialog_${width}_ar_$theme');
        await tester.tap(find.text('إلغاء'));
        await settle(tester);
      });

      testWidgets('AD13 settings ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size);
        goTo(tester, '/admin/settings');
        await settle(tester);
        await capture(tester, 'ad13_settings_${width}_ar_$theme');

        await tester.enterText(find.byType(TextFormField).at(0), '45');
        await tester.enterText(find.byType(TextFormField).at(2), '40');
        await tester.pumpAndSettle();
        await capture(tester, 'ad13_settings_dirty_${width}_ar_$theme');

        await tester.tap(find.byTooltip('سجل تغييرات: رسوم الكشف'));
        await settle(tester);
        await capture(tester, 'ad13_history_${width}_ar_$theme');
      });

      testWidgets('AD14 admins ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size);
        goTo(tester, '/admin/admins');
        await settle(tester);
        await capture(tester, 'ad14_admins_${width}_ar_$theme');

        await tester.tap(find.text('إضافة مسؤول').first);
        await settle(tester);
        await tester.enterText(find.byType(TextFormField).at(0), 'هالة سمير');
        await tester.enterText(find.byType(TextFormField).at(1), 'hala@el3yada.dev');
        await tester.pumpAndSettle();
        await capture(tester, 'ad14_add_admin_${width}_ar_$theme');
        await tester.tap(find.text('إضافة مسؤول').last);
        await settle(tester);
        await capture(tester, 'ad14_temporary_password_${width}_ar_$theme');
      });

      testWidgets('AD15 audit log ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size);
        goTo(tester, '/admin/audit');
        await settle(tester);
        await capture(tester, 'ad15_audit_${width}_ar_$theme');
        await tester.tap(find.textContaining('أكّد بريده').first);
        await settle(tester);
        await capture(tester, 'ad15_audit_expanded_${width}_ar_$theme');
      });

      testWidgets('AD18 profile ($width, $theme)', skip: !screenshotsEnabled, (tester) async {
        await signedIn(tester, size);
        await tester.tap(find.byTooltip('ملفي الشخصي'));
        await settle(tester);
        await capture(tester, 'ad18_profile_${width}_ar_$theme');
      });
    }
  }
}
