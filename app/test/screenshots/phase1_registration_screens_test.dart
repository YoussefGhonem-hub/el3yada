import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/doctor_registration/data/license_picker.dart';
import 'package:el3yada/features/doctor_registration/data/registration_repository.dart';
import 'package:el3yada/features/doctor_registration/presentation/widgets/search_picker.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_overrides.dart';
import 'capture.dart';

/// A4–A7 in Arabic, light and dark, on a phone and on a 1280 × 800 desktop.
/// See capture.dart.
void main() {
  setUpAll(() async {
    if (screenshotsEnabled) await loadRealFonts();
  });

  const support = PublicSettings(supportPhone: '01000000000', supportWhatsapp: '01000000000', supportEmail: 'help@el3yada.app');
  const phone = Size(390, 844);
  const desktop = Size(1280, 800);

  /// A photo of a syndicate card, drawn here so the thumbnail shows something.
  Future<Uint8List> cardPhoto(WidgetTester tester) async => (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 200), Paint()..color = const Color(0xFFE9EEF4));
        canvas.drawRect(const Rect.fromLTWH(0, 0, 320, 44), Paint()..color = const Color(0xFF1F5F8B));
        canvas.drawRect(const Rect.fromLTWH(20, 64, 90, 112), Paint()..color = const Color(0xFFB8C4D0));
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(Rect.fromLTWH(130, 72 + i * 26.0, 160 - i * 20.0, 10), Paint()..color = const Color(0xFF8A99A8));
        }
        final image = await recorder.endRecording().toImage(320, 200);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    Future<FakeAuthRepository> pumpApp(WidgetTester tester, {Size size = phone, Uint8List? photo}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = FakeAuthRepository(delay: Duration.zero);
      final bytes = photo ?? Uint8List(0);
      await tester.pumpWidget(ProviderScope(
        overrides: await appOverrides(
          prefs: {'settings.locale': 'ar', 'settings.themeMode': theme},
          settings: support,
          auth: auth,
          platform: size.width > 900 ? AppPlatform.desktop : AppPlatform.mobile,
          extra: [
            licensePickerProvider.overrideWithValue(_Picker(bytes)),
            registrationRepositoryProvider.overrideWithValue(FakeRegistrationRepository(auth: auth, delay: Duration.zero)),
          ],
        ),
        child: RepaintBoundary(key: screenshotKey, child: const El3yadaApp()),
      ));
      await settle(tester);
      return auth;
    }

    testWidgets('A4 steps on a phone ($theme)', skip: !screenshotsEnabled, (tester) async {
      final photo = await cardPhoto(tester);
      await pumpApp(tester, photo: photo);
      await tapText(tester, 'تسجيل كطبيب');
      await capture(tester, 'a4_1_account_ar_$theme');

      await tapText(tester, 'التالي');
      await capture(tester, 'a4_1_account_errors_ar_$theme');

      await fillAccount(tester);
      await tester.ensureVisible(find.byType(TextField).first);
      await settle(tester);
      await capture(tester, 'a4_1_account_filled_ar_$theme');
      await tapText(tester, 'التالي');
      await capture(tester, 'a4_2_professional_ar_$theme');

      await openPicker(tester, 'التخصص الأساسي');
      await capture(tester, 'a4_2_specialty_picker_ar_$theme');
      await tapText(tester, 'قلب وأوعية دموية');
      await fillProfessional(tester);
      await decodeImages(tester);
      await tester.ensureVisible(find.text('نقابة الأطباء'));
      await settle(tester);
      await capture(tester, 'a4_2_professional_filled_ar_$theme');

      await tapText(tester, 'التالي');
      await capture(tester, 'a4_3_branch_ar_$theme');
      await fillBranch(tester);
      await tester.ensureVisible(find.text('العنوان بالتفصيل'));
      await settle(tester);
      await capture(tester, 'a4_3_branch_address_ar_$theme');
      await tester.ensureVisible(find.text('أرقام تليفون العيادة'));
      await settle(tester);
      await capture(tester, 'a4_3_branch_phones_ar_$theme');
      await tester.ensureVisible(find.text('أسعار الكشف والاستشارة (اختياري)'));
      await settle(tester);
      await capture(tester, 'a4_3_branch_prices_ar_$theme');

      await tapText(tester, 'التالي');
      await decodeImages(tester);
      await capture(tester, 'a4_4_review_ar_$theme');
      await tester.ensureVisible(find.byType(Checkbox));
      await settle(tester);
      await capture(tester, 'a4_4_review_terms_ar_$theme');
    });

    testWidgets('A4 on desktop ($theme)', skip: !screenshotsEnabled, (tester) async {
      final photo = await cardPhoto(tester);
      await pumpApp(tester, size: desktop, photo: photo);
      await tapText(tester, 'تسجيل كطبيب');
      await fillAccount(tester);
      await tapText(tester, 'التالي');
      await tapText(tester, 'استشاري');
      await openPicker(tester, 'التخصص الأساسي');
      await capture(tester, 'a4_2_specialty_dialog_desktop_ar_$theme');
      await tapText(tester, 'قلب وأوعية دموية');
      await enter(tester, 'رقم النقابة', '45678');
      await tapText(tester, 'كارنيه النقابة أو ترخيص المزاولة');
      await decodeImages(tester);
      await capture(tester, 'a4_2_professional_desktop_ar_$theme');
      await tapText(tester, 'التالي');
      await capture(tester, 'a4_3_branch_desktop_ar_$theme');
      await fillBranch(tester);
      await tester.ensureVisible(find.text('العنوان بالتفصيل'));
      await settle(tester);
      await capture(tester, 'a4_3_branch_address_desktop_ar_$theme');
      await tapText(tester, 'التالي');
      await decodeImages(tester);
      await capture(tester, 'a4_4_review_desktop_ar_$theme');
    });

    testWidgets('A6 pending ($theme)', skip: !screenshotsEnabled, (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'pending@el3yada.dev');
      await capture(tester, 'a6_pending_ar_$theme');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await settle(tester);
      await capture(tester, 'a6_pending_data_ar_$theme');
    });

    testWidgets('A6 pending on desktop ($theme)', skip: !screenshotsEnabled, (tester) async {
      await pumpApp(tester, size: desktop);
      await signIn(tester, 'pending@el3yada.dev');
      await capture(tester, 'a6_pending_desktop_ar_$theme');
    });

    testWidgets('A5 verify email ($theme)', skip: !screenshotsEnabled, (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'pending@el3yada.dev');
      await tapText(tester, 'أكّد بريدك الإلكتروني');
      await capture(tester, 'a5_verify_ar_$theme');
      await tester.ensureVisible(find.text('إعادة إرسال البريد'));
      await tester.tap(find.text('إعادة إرسال البريد'));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await capture(tester, 'a5_verify_cooldown_ar_$theme');
      await tester.pump(const Duration(seconds: 60));
      await tester.enterText(find.byType(TextField), 'abc123');
      await tapText(tester, 'تأكيد');
      await capture(tester, 'a5_verified_ar_$theme');
    });

    testWidgets('A7 rejected and resubmit ($theme)', skip: !screenshotsEnabled, (tester) async {
      await pumpApp(tester);
      await signIn(tester, 'rejected@el3yada.dev');
      await capture(tester, 'a7_rejected_ar_$theme');
      await tapText(tester, 'تعديل وإعادة الإرسال');
      await capture(tester, 'a7_edit_account_ar_$theme');
      await tapText(tester, 'التالي');
      await capture(tester, 'a7_edit_professional_ar_$theme');
    });

    testWidgets('A4 on a 360 × 640 phone ($theme)', skip: !screenshotsEnabled || dark, (tester) async {
      final photo = await cardPhoto(tester);
      await pumpApp(tester, size: const Size(360, 640), photo: photo);
      await tapText(tester, 'تسجيل كطبيب');
      await fillAccount(tester);
      await tapText(tester, 'التالي');
      await openPicker(tester, 'التخصص الأساسي');
      await tester.enterText(find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField)), 'قلب');
      await settle(tester);
      await capture(tester, 'a4_2_specialty_search_360_ar_$theme');
      await tapText(tester, 'قلب وأوعية دموية');
      await fillProfessional(tester);
      await decodeImages(tester);
      await capture(tester, 'a4_2_professional_360_ar_$theme');
      await tapText(tester, 'التالي');
      await fillBranch(tester);
      await tester.ensureVisible(find.text('إضافة رقم'));
      await settle(tester);
      await capture(tester, 'a4_3_branch_360_ar_$theme');
      await tapText(tester, 'التالي');
      await capture(tester, 'a4_4_review_360_ar_$theme');
    });

    testWidgets('A7 rejected on desktop ($theme)', skip: !screenshotsEnabled, (tester) async {
      await pumpApp(tester, size: desktop);
      await signIn(tester, 'rejected@el3yada.dev');
      await capture(tester, 'a7_rejected_desktop_ar_$theme');
    });
  }
}

class _Picker implements LicensePicker {
  _Picker(this.bytes);

  final Uint8List bytes;

  @override
  Future<PickedLicense?> pick(LicenseSource source) async =>
      PickedLicense(name: 'syndicate-card.png', size: bytes.length, read: () async => bytes);
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Decodes the license thumbnails for real (the test clock never finishes it).
Future<void> decodeImages(WidgetTester tester) async {
  for (final element in find.byType(Image).evaluate().toList()) {
    final image = element.widget as Image;
    await tester.runAsync(() => precacheImage(image.image, element));
  }
  await settle(tester);
}

Future<void> signIn(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byType(TextFormField).at(0), identifier);
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.byType(FilledButton).first);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await settle(tester);
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
}

Future<void> openPicker(WidgetTester tester, String label) async {
  final picker = find.widgetWithText(PickerField, label);
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await settle(tester);
}

Future<void> fillAccount(WidgetTester tester) async {
  await enter(tester, 'الاسم بالكامل', 'سامي عبد الله');
  await enter(tester, 'البريد الإلكتروني', 'sami@example.com');
  await enter(tester, 'رقم الموبايل', '01012345678');
  await enter(tester, 'كلمة المرور', 'Doctor123');
  await enter(tester, 'تأكيد كلمة المرور', 'Doctor123');
  await tester.pump();
}

Future<void> fillProfessional(WidgetTester tester) async {
  await tapText(tester, 'استشاري');
  await tapText(tester, 'إضافة تخصص');
  await tapText(tester, 'باطنة');
  await enter(tester, 'رقم النقابة', '45678');
  await tapText(tester, 'كارنيه النقابة أو ترخيص المزاولة');
  await tapText(tester, 'التقاط صورة');
}

Future<void> fillBranch(WidgetTester tester) async {
  await enter(tester, 'اسم الفرع', 'فرع المعادي');
  await openPicker(tester, 'المحافظة');
  await tapText(tester, 'القاهرة');
  await enter(tester, 'المدينة أو الحي', 'المعادي');
  await enter(tester, 'العنوان بالتفصيل', '12 شارع 9، عمارة النور، الدور التالت، شقة 5');
  await enter(tester, 'علامة مميزة (اختياري)', 'بجوار محطة المترو');
  // The share sheet's text: only the link is kept.
  await enter(tester, 'لينك جوجل ماب (اختياري)', 'عيادة د. سامي\nhttps://maps.app.goo.gl/AbCd1234XyZ');
  await enter(tester, 'الرقم 1', '02 2358 1234');
  await tapText(tester, 'إضافة رقم');
  await enter(tester, 'الرقم 2', '01012345678');
  await tapText(tester, 'واتساب');
  await enter(tester, 'الكشف', '300');
  await enter(tester, 'الاستشارة', '150');
  await tester.pump();
}
