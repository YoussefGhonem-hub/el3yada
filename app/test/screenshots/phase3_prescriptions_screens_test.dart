import 'dart:io';
import 'dart:typed_data';

import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/prescriptions/domain/prescription_models.dart';
import 'package:el3yada/features/prescriptions/pdf/rx_pdf.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import '../support/clinic_records_support.dart';
import '../support/rx_support.dart';
import 'capture.dart';

/// Phase 3 prescription screens (D6 tab, D9, D13–D15, D22, D23) in Arabic,
/// light and dark, at phone and desktop width, and sample prescription PDFs
/// (6.4.1) next to them in `build/screenshots/`. See capture.dart.
///
/// The PDF pane shows a stand-in here: drawing PDF pages needs the
/// platform's renderer, which the test host doesn't have. Open the .pdf
/// files to check the printed layout.
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

  test('sample prescription PDFs', skip: !screenshotsEnabled, () async {
    ByteData font(String file) =>
        ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync());
    final fonts = RxPdfFonts.fromBytes(
      arabic: font('NotoSansArabic-Regular.ttf'),
      arabicBold: font('NotoSansArabic-Bold.ttf'),
      latin: font('Alexandria-Regular.ttf'),
      latinBold: font('Alexandria-Bold.ttf'),
    );
    RxPdfData sample(
      RxSettings settings, {
      int medicines = 4,
      PrescriptionKind kind = PrescriptionKind.medication,
    }) => RxPdfData(
      settings: settings,
      doctor: const RxDoctor(
        nameAr: 'د. سارة عادل',
        titleAr: 'استشاري',
        specialtyAr: 'الباطنة',
        degreesAr: 'دكتوراه الباطنة — جامعة القاهرة',
        nameEn: 'Dr Sara Adel',
        titleEn: 'Consultant',
        specialtyEn: 'Internal Medicine',
        degreesEn: 'MD, Cairo University',
      ),
      patient: RxPatient(
        name: 'منى حسن إبراهيم',
        ageYears: 34,
        fileNumber: 12,
        visitDay: DateTime.utc(2026, 11, 17),
        visitType: SessionType.examination,
      ),
      kind: kind,
      diagnosis: 'التهاب الحلق الحاد',
      advice: 'راحة تامة ومشروبات دافئة، والإكثار من السوائل',
      followUpDate: DateTime.utc(2026, 11, 24),
      medications: [
        for (var i = 0; i < medicines; i++)
          [
            const MedicationItem(
              drugName: 'Augmentin',
              strength: '1 g',
              form: DrugForms.tablet,
              dose: 'قرص',
              frequency: 'كل 12 ساعة',
              timing: MedicationTiming.afterFood,
              duration: '7 أيام',
            ),
            const MedicationItem(
              drugName: 'Panadol Extra',
              strength: '500 mg',
              form: DrugForms.tablet,
              dose: 'قرص',
              frequency: 'عند اللزوم',
              duration: '5 أيام',
              instructions: 'بحد أقصى 4 أقراص في اليوم',
            ),
            const MedicationItem(
              drugName: 'Strepsils',
              form: DrugForms.other,
              dose: 'قرص استحلاب',
              frequency: 'كل 3 ساعات',
              duration: '5 أيام',
            ),
            const MedicationItem(
              drugName: 'Otrivin',
              strength: '0.1%',
              form: DrugForms.drops,
              dose: 'نقطتين',
              frequency: 'مرتين يومياً',
              duration: 'أسبوع',
            ),
          ][i % 4],
      ],
      investigations: const [
        InvestigationItem(
          category: InvestigationCategory.lab,
          name: 'CBC',
          notes: 'صائم 8 ساعات',
        ),
        InvestigationItem(category: InvestigationCategory.lab, name: 'HbA1c'),
        InvestigationItem(
          category: InvestigationCategory.lab,
          name: 'Lipid profile',
        ),
        InvestigationItem(category: InvestigationCategory.lab, name: 'TSH'),
        InvestigationItem(
          category: InvestigationCategory.radiology,
          name: 'Chest X-ray PA view',
          notes: 'وضع أمامي خلفي',
        ),
        InvestigationItem(
          category: InvestigationCategory.radiology,
          name: 'US Abdomen',
        ),
      ],
      qrUrl: 'https://el3yada.app/rx/aZ3kP0qLm9Xc',
      branches: const [
        RxBranch(
          nameAr: 'فرع المعادي',
          nameEn: 'Maadi',
          address: '12 شارع 9، المعادي',
          landmark: 'بجوار محطة المترو',
          phones: ['0223581234'],
          whatsapp: ['01001234567'],
          hours: ['السبت – الأربعاء: 5:00 م – 10:00 م'],
        ),
        RxBranch(
          nameAr: 'فرع مدينة نصر',
          nameEn: 'Nasr City',
          address: 'عباس العقاد، مدينة نصر',
          phones: ['0224011234'],
        ),
      ],
    );

    Future<void> write(String name, RxPdfData data) async {
      File('build/screenshots/$name.pdf')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(await buildRxPdf(data, fonts));
    }

    await write('rx_a5_ar', sample(const RxSettings()));
    await write(
      'rx_a5_ar_12_items',
      sample(const RxSettings(accentColor: '#7A1F2B'), medicines: 12),
    );
    await write('rx_a5_en', sample(const RxSettings(language: 'en')));
    await write(
      'rx_a5_investigations',
      sample(const RxSettings(), kind: PrescriptionKind.investigations),
    );
    await write(
      'rx_a5_preprinted',
      sample(
        const RxSettings(preprinted: true, marginTopMm: 45, marginBottomMm: 35),
      ),
    );
    await write(
      'rx_a4_ar',
      sample(const RxSettings(paperSize: RxPaperSize.a4)),
    );
  });

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
            extra: [
              fakeRecordsOverride(),
              ...rxOverrides(
                printer: RecordingPrinter(),
                search: FakeCatalogSearch(),
              ),
            ],
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

    Future<void> open(WidgetTester tester, String path) async {
      goTo(tester, path);
      await settle(tester);
    }

    /// Scrolls [finder] into view and clear of the phone's floating bar.
    Future<void> reveal(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await settle(tester);
    }

    for (final (width, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets(
        'D6 tab, D9, D13, D14, D15 ($width, $theme)',
        skip: !screenshotsEnabled,
        (tester) async {
          await signedIn(tester, size, 'doctor@el3yada.dev');
          final mona = recordsOf(tester).patientIdByName(SeedPatients.mona);
          final rxs = prescriptionsOf(tester).ofPatient(mona);
          final sent = rxs.firstWhere(
            (rx) => rx.status == PrescriptionStatus.sent,
          );
          final draft = rxs.firstWhere(
            (rx) => rx.status == PrescriptionStatus.draft,
          );

          await open(tester, '/doctor/patients/$mona');
          await reveal(tester, find.widgetWithText(Tab, 'الروشتات'));
          await tester.tap(find.widgetWithText(Tab, 'الروشتات'));
          await settle(tester);
          await capture(tester, 'd6_prescriptions_${width}_ar_$theme');

          await open(
            tester,
            '/doctor/patients/$mona/sessions/${sent.sessionId}',
          );
          await reveal(tester, find.text('الروشتات والطلبات'));
          await capture(tester, 'd9_prescriptions_${width}_ar_$theme');

          // D14: the seeded draft request.
          await open(
            tester,
            '/doctor/patients/$mona/prescriptions/${draft.prescriptionId}',
          );
          await capture(tester, 'd14_editor_${width}_ar_$theme');
          await tester.tap(find.text('إضافة فحص'));
          await settle(tester);
          await tester.enterText(find.byType(TextField).last, 'cbc');
          await tester.pump(const Duration(milliseconds: 300));
          await settle(tester);
          await capture(tester, 'd14_add_test_${width}_ar_$theme');
          await tester.tap(find.byTooltip('إغلاق').last);
          await settle(tester);

          await open(
            tester,
            '/doctor/patients/$mona/prescriptions/${sent.prescriptionId}',
          );
          await capture(tester, 'd15_sent_${width}_ar_$theme');
        },
      );

      testWidgets(
        'D13 new prescription and the add sheet ($width, $theme)',
        skip: !screenshotsEnabled,
        (tester) async {
          await signedIn(tester, size, 'doctor@el3yada.dev');
          final mona = recordsOf(tester).patientIdByName(SeedPatients.mona);
          final session = recordsOf(tester).sessionIdsOf(mona).first;
          await open(tester, '/doctor/patients/$mona/sessions/$session');
          await reveal(tester, find.text('روشتة علاج جديدة'));
          await tester.tap(find.text('روشتة علاج جديدة'));
          await settle(tester);
          await tester.tap(find.text('إضافة دواء'));
          await settle(tester);
          await tester.enterText(find.byType(TextField).last, 'ator');
          await tester.pump(const Duration(milliseconds: 300));
          await settle(tester);
          await capture(tester, 'd13_add_medicine_${width}_ar_$theme');
          await tester.tap(find.text('Atorstat 20'));
          await settle(tester);
          await capture(tester, 'd13_medicine_fields_${width}_ar_$theme');
          await tester.tap(find.text('إضافة').last);
          await settle(tester);
          await capture(tester, 'd13_editor_${width}_ar_$theme');
        },
      );

      testWidgets(
        'D22 print settings, D23 templates ($width, $theme)',
        skip: !screenshotsEnabled,
        (tester) async {
          await signedIn(tester, size, 'doctor@el3yada.dev');
          await open(tester, '/doctor/settings/rx');
          await capture(tester, 'd22_rx_settings_${width}_ar_$theme');
          await open(tester, '/doctor/settings/templates');
          await capture(tester, 'd23_templates_${width}_ar_$theme');
        },
      );
    }
  }
}
