import 'dart:typed_data';

import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/patients/presentation/patient_profile_screen.dart';
import 'package:el3yada/features/records/domain/record_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import '../support/clinic_records_support.dart';
import '../support/records_support.dart';
import 'capture.dart';

/// Phase 3 medical files (D6 Files tab, D10–D12) in Arabic, light and dark,
/// at phone and desktop width. See capture.dart.
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

    Future<FakeFileSources> signedIn(WidgetTester tester, Size size) async {
      final sources = FakeFileSources()
        ..files = [
          UploadSource(
            name: 'صورة دم.pdf',
            bytes: Uint8List(180000),
            sizeBytes: 180000,
          ),
          UploadSource(
            name: 'IMG_2041.jpg',
            bytes: tinyPng(size: 64),
            sizeBytes: 4200000,
          ),
          UploadSource(
            name: 'ct-series.zip',
            bytes: Uint8List(4),
            sizeBytes: 70 * 1024 * 1024,
          ),
        ]
        ..scans = [
          [tinyPng(size: 40), tinyPng(size: 40), tinyPng(size: 40)],
        ];
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
              ...recordsOverrides(
                sources: sources,
                configure: (r) => r.imageShrink = 0.15,
              ),
            ],
          ),
          child: RepaintBoundary(key: screenshotKey, child: const El3yadaApp()),
        ),
      );
      await settle(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'doctor@el3yada.dev',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
      return sources;
    }

    String mona(WidgetTester tester) =>
        recordsOf(tester).patientIdByName(SeedPatients.mona);

    for (final (width, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets(
        'D6 files, D11 upload, D12 viewer ($width, $theme)',
        skip: !screenshotsEnabled,
        (tester) async {
          await signedIn(tester, size);
          final patient = mona(tester);
          goTo(tester, '/doctor/patients/$patient');
          await settle(tester);
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
          await tester.tap(find.widgetWithText(Tab, 'الملفات'));
          await settle(tester);
          await capture(tester, 'd6_files_${width}_ar_$theme');

          goTo(tester, '/doctor/patients/$patient/files/upload');
          await settle(tester);
          await tester.tap(find.text('اختيار ملفات'));
          await settle(tester);
          await capture(tester, 'd11_upload_${width}_ar_$theme');

          final xray = recordsRepoOf(tester)
              .recordsOf(patient)
              .firstWhere((r) => r.category == RecordCategory.radiology);
          goTo(tester, '/doctor/patients/$patient/files/${xray.recordId}');
          await settle(tester);
          await capture(tester, 'd12_viewer_${width}_ar_$theme');
        },
      );
    }

    testWidgets('D10 scan review (phone, $theme)', skip: !screenshotsEnabled, (
      tester,
    ) async {
      await signedIn(tester, phone);
      goTo(tester, '/doctor/patients/${mona(tester)}/files/upload?scan=1');
      await settle(tester);
      await capture(tester, 'd10_scan_review_phone_ar_$theme');
    });
  }
}
