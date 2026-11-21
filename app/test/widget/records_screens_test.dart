import 'dart:typed_data';

import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/records/domain/record_models.dart';
import 'package:el3yada/features/records/presentation/record_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart' show goTo;
import '../support/app_flow.dart';
import '../support/app_overrides.dart';
import '../support/clinic_records_support.dart';
import '../support/records_support.dart';

/// Medical files (spec 6.3, D6 Files tab, D10–D12, AS6, AC-14) through the
/// offline records, which apply the API's rules (FakeRecordsRepository).
void main() {
  const desktop = Size(1400, 900);
  const doctor = 'doctor@el3yada.dev';
  const reception = '01000000001';

  Future<void> start(
    WidgetTester tester,
    String account, {
    Size size = desktop,
    AppPlatform platform = AppPlatform.mobile,
    FakeFileSources? sources,
    RecordingFileActions? actions,
    Duration delay = Duration.zero,
  }) async {
    await pumpApp(
      tester,
      size: size,
      platform: platform,
      extra: [
        fakeRecordsOverride(),
        ...recordsOverrides(sources: sources, actions: actions, delay: delay),
      ],
    );
    await signIn(tester, account);
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  String mona(WidgetTester tester) =>
      recordsOf(tester).patientIdByName(SeedPatients.mona);

  /// The seeded records of a patient (they're made on the first read).
  Future<List<MedicalRecordView>> seeded(
    WidgetTester tester,
    String patientId,
  ) async {
    await tester.runAsync(() => recordsRepoOf(tester).records(patientId));
    return recordsRepoOf(tester).recordsOf(patientId);
  }

  Future<void> openFilesTab(
    WidgetTester tester,
    String base,
    String patientId,
  ) async {
    await open(tester, '$base/patients/$patientId');
    await tester.tap(find.widgetWithText(Tab, 'Files'));
    await settle(tester);
  }

  /// Chips scroll sideways: bring one into view first.
  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(ChoiceChip, label);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await settle(tester);
  }

  UploadSource file(String name, {int size = 2048}) => UploadSource(
    name: name,
    bytes: Uint8List(size)..fillRange(0, size, 7),
    sizeBytes: size,
  );

  group('D6 Files tab', () {
    testWidgets('category chips with counts, and a chip filters the cards', (
      tester,
    ) async {
      await start(tester, doctor);
      await openFilesTab(tester, '/doctor', mona(tester));

      expect(find.widgetWithText(ChoiceChip, 'All 3'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Lab tests 1'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Radiology 1'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Prescriptions 0'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ChoiceChip, 'Other 1'), findsOneWidget);
      expect(find.byType(RecordCard), findsNWidgets(3));
      expect(find.text('صورة دم كاملة'), findsOneWidget);
      // The sick leave was scanned at reception: the doctor sees who added it.
      expect(find.textContaining('Recorded by'), findsOneWidget);

      await tapChip(tester, 'Lab tests 1');
      expect(find.byType(RecordCard), findsOneWidget);
      expect(find.text('صورة دم كاملة'), findsOneWidget);

      await tapChip(tester, 'Prescriptions 0');
      expect(find.text('No files in this category'), findsOneWidget);
    });

    testWidgets('an assistant without filesManage has no Files tab (AS6)', (
      tester,
    ) async {
      tester.view.physicalSize = desktop;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appOverrides(
            clinic: LimitedClinicRepository(
              '+201000000001',
              remove: {'filesManage'},
            ),
            extra: [fakeRecordsOverride(), ...recordsOverrides()],
          ),
          child: const El3yadaApp(),
        ),
      );
      await settle(tester);
      await signIn(tester, reception);
      await open(tester, '/assistant/patients/${mona(tester)}');

      expect(find.widgetWithText(Tab, 'Sessions'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Files'), findsNothing);
    });

    testWidgets(
      'a suspended doctor still sees the files, without Upload or Scan',
      (tester) async {
        await start(tester, 'suspended@el3yada.dev');
        final patient = mona(tester);
        await openFilesTab(tester, '/doctor', patient);

        expect(find.byType(RecordCard), findsWidgets);
        expect(find.text('Upload files'), findsNothing);
        expect(find.text('Scan'), findsNothing);
      },
    );
  });

  group('D11 upload', () {
    testWidgets(
      'three files get three progress bars, a failed one retries, then Save (AC-14)',
      (tester) async {
        final sources = FakeFileSources()
          ..files = [file('cbc.pdf'), file('xray.jpg'), file('report.docx')];
        await start(
          tester,
          doctor,
          sources: sources,
          delay: const Duration(milliseconds: 80),
        );
        final patient = mona(tester);
        await seeded(tester, patient);
        recordsRepoOf(tester).failNextUploads = 1;
        await open(tester, '/doctor/patients/$patient/files/upload');

        await tester.tap(find.text('Choose files'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.byType(UploadItemRow), findsNWidgets(3));
        expect(find.byType(LinearProgressIndicator), findsNWidgets(3));

        await settle(tester);
        expect(
          find.text('Upload failed'),
          findsNothing,
          reason: 'the network error shows as no internet',
        );
        expect(find.byTooltip('Try again'), findsOneWidget);
        expect(find.text('Uploaded'), findsNWidgets(2));

        await tester.tap(find.byTooltip('Try again'));
        await settle(tester);
        expect(find.text('Uploaded'), findsNWidgets(3));

        // Save needs a category first.
        await tester.tap(find.text("Save to the patient's file"));
        await settle(tester);
        expect(find.text('Choose a category'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Lab tests'));
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Notes (optional)'),
          'صائم',
        );
        await tester.tap(find.text("Save to the patient's file"));
        await settle(tester);

        final records = recordsRepoOf(tester).recordsOf(patient);
        expect(records, hasLength(4));
        final added = records.last;
        expect(added.category, RecordCategory.lab);
        expect(added.source, RecordSource.upload);
        expect(added.notes, 'صائم');
        expect(
          [for (final a in added.attachments) a.fileName],
          ['cbc.pdf', 'xray.jpg', 'report.docx'],
        );
        expect(find.text("Saved to the patient's file"), findsOneWidget);
      },
    );

    testWidgets('a file over the admin limit is never sent, and Save waits', (
      tester,
    ) async {
      final sources = FakeFileSources()
        ..files = [
          UploadSource(
            name: 'ct-series.dcm',
            bytes: Uint8List(4),
            sizeBytes: 60 * 1024 * 1024,
          ),
        ];
      await start(tester, doctor, sources: sources);
      final patient = mona(tester);
      await open(tester, '/doctor/patients/$patient/files/upload');

      await tester.tap(find.text('Choose files'));
      await settle(tester);

      expect(find.text('File larger than allowed (50 MB)'), findsOneWidget);
      expect(recordsRepoOf(tester).uploadedNames, isEmpty);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Radiology'));
      await tester.tap(find.text("Save to the patient's file"));
      await settle(tester);
      expect(
        find.text(
          'Wait for every file to upload, or remove the ones that failed.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Remove'));
      await settle(tester);
      expect(find.byType(UploadItemRow), findsNothing);
    });

    testWidgets('the server\'s saving is shown under the file', (tester) async {
      final sources = FakeFileSources()
        ..files = [
          UploadSource(
            name: 'photo.jpg',
            bytes: tinyPng(size: 64),
            sizeBytes: tinyPng(size: 64).length,
          ),
        ];
      await pumpApp(
        tester,
        size: desktop,
        extra: [
          fakeRecordsOverride(),
          ...recordsOverrides(
            sources: sources,
            configure: (r) => r.imageShrink = 0.25,
          ),
        ],
      );
      await signIn(tester, doctor);
      await open(tester, '/doctor/patients/${mona(tester)}/files/upload');

      await tester.tap(find.text('Choose files'));
      await settle(tester);

      expect(find.textContaining('Reduced from'), findsOneWidget);
    });

    testWidgets('D10: scanned pages are reviewed, then go up as one PDF', (
      tester,
    ) async {
      final sources = FakeFileSources()
        ..scans = [
          [tinyPng(), tinyPng(), tinyPng()],
        ];
      await start(tester, doctor, sources: sources);
      final patient = mona(tester);
      await seeded(tester, patient);
      await open(tester, '/doctor/patients/$patient/files/upload?scan=1');

      expect(find.text('Check the pages'), findsOneWidget);
      expect(find.text('Page 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete page').last);
      await settle(tester);
      expect(find.text('Page 3'), findsNothing);
      await tester.tap(find.text('Make one PDF'));
      await settle(tester);

      expect(find.textContaining('.pdf'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Other'));
      await settle(tester);
      await tester.tap(find.text("Save to the patient's file"));
      await settle(tester);

      final added = recordsRepoOf(tester).recordsOf(patient).last;
      expect(added.source, RecordSource.scan);
      expect(added.attachments.single.pageCount, 2);
      expect(added.attachments.single.mimeType, 'application/pdf');
    });

    testWidgets('desktop has no Scan, Camera or Photos', (tester) async {
      await start(tester, doctor, platform: AppPlatform.desktop);
      await open(tester, '/doctor/patients/${mona(tester)}/files/upload');

      expect(find.text('Choose files'), findsOneWidget);
      expect(find.text('Scan'), findsNothing);
      expect(find.text('Camera'), findsNothing);
      expect(find.text('Drop the files to upload them'), findsWidgets);
    });
  });

  group('D12 viewer', () {
    testWidgets('edit details replaces them', (tester) async {
      await start(tester, doctor);
      final patient = mona(tester);
      final lab = (await seeded(
        tester,
        patient,
      )).firstWhere((r) => r.category == RecordCategory.lab);
      await open(
        tester,
        '/doctor/patients/$patient/files/${lab.recordId}/edit',
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Radiology'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title (optional)'),
        'أشعة صدر',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      final updated = recordsRepoOf(tester).recordById(lab.recordId)!;
      expect(updated.category, RecordCategory.radiology);
      expect(updated.title, 'أشعة صدر');
      expect(updated.notes, isNull);
    });

    testWidgets('the doctor deletes; an assistant can edit but never delete', (
      tester,
    ) async {
      final actions = RecordingFileActions();
      await start(tester, doctor, actions: actions);
      final patient = mona(tester);
      final records = await seeded(tester, patient);
      final xray = records.firstWhere(
        (r) => r.category == RecordCategory.radiology,
      );
      await open(tester, '/doctor/patients/$patient/files/${xray.recordId}');

      expect(find.text('1 of 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Share'));
      await settle(tester);
      expect(actions.calls, ['share sinus-xray.jpg']);

      await tester.tap(find.byTooltip('More actions'));
      await settle(tester);
      expect(find.text('Edit details'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(recordsRepoOf(tester).recordById(xray.recordId), isNull);
    });

    testWidgets('an assistant with filesManage has no Delete', (tester) async {
      await start(tester, reception);
      final patient = mona(tester);
      final lab = (await seeded(
        tester,
        patient,
      )).firstWhere((r) => r.category == RecordCategory.lab);
      await open(tester, '/assistant/patients/$patient/files/${lab.recordId}');

      await tester.tap(find.byTooltip('More actions'));
      await settle(tester);
      expect(find.text('Edit details'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
    });

    testWidgets('other file types offer Open with and Download (BR-F4)', (
      tester,
    ) async {
      final actions = RecordingFileActions();
      final sources = FakeFileSources()..files = [file('ecg.dcm')];
      await start(tester, doctor, sources: sources, actions: actions);
      final patient = mona(tester);
      await open(tester, '/doctor/patients/$patient/files/upload');
      await tester.tap(find.text('Choose files'));
      await settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Other'));
      await tester.tap(find.text("Save to the patient's file"));
      await settle(tester);
      final record = recordsRepoOf(tester)
          .recordsOf(patient)
          .firstWhere((r) => r.attachments.first.fileName == 'ecg.dcm');

      await open(tester, '/doctor/patients/$patient/files/${record.recordId}');
      expect(
        find.text('This type of file opens in another app.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Open with…'));
      await settle(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Download'));
      await settle(tester);
      expect(actions.calls, ['open ecg.dcm', 'save ecg.dcm']);
    });
  });
}
