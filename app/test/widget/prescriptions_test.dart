import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/clinic/domain/clinic_context.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:el3yada/features/prescriptions/domain/prescription_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart' show goTo;
import '../support/app_flow.dart';
import '../support/clinic_records_support.dart';
import '../support/rx_support.dart';

/// Prescriptions and requests (D9, D6 tab, D13–D15, D22, D23, AS7, AS8)
/// through the offline clinic, which answers like the API
/// (api-phase-3-prescriptions.md).
void main() {
  const desktop = Size(1400, 1000);
  late RecordingPrinter printer;
  late FakeCatalogSearch search;

  Future<void> start(
    WidgetTester tester,
    String account, {
    ClinicRepository? clinic,
    Size size = desktop,
  }) async {
    printer = RecordingPrinter();
    search = FakeCatalogSearch();
    await pumpApp(
      tester,
      size: size,
      extra: [
        fakeRecordsOverride(),
        ...rxOverrides(printer: printer, search: search),
      ],
      clinic: clinic,
    );
    await signIn(tester, account);
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(Dialog), matching: find.text(text));

  Finder fieldInDialog(String label) => find.descendant(
    of: find.byType(Dialog),
    matching: find.widgetWithText(TextField, label),
  );

  Finder inAlert(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  /// Types in the open sheet's search box (a dialog at this width) and waits
  /// for the results.
  Future<void> typeSearch(WidgetTester tester, String text) async {
    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .first,
      text,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
  }

  String mona(WidgetTester tester) =>
      recordsOf(tester).patientIdByName(SeedPatients.mona);

  String monaSession(WidgetTester tester) =>
      recordsOf(tester).sessionIdsOf(mona(tester)).first;

  /// Lets a snack bar close: it sits over the action bar for 4 seconds.
  Future<void> snackGone(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
  }

  group('D13 medication prescription', () {
    testWidgets(
      'from D9: search sections, the specialty chip, free text, then send (BR-RX4)',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        await open(
          tester,
          '/doctor/patients/${mona(tester)}/sessions/${monaSession(tester)}',
        );
        expect(find.text('Prescriptions and requests'), findsOneWidget);
        await tap(
          tester,
          find.widgetWithText(FilledButton, 'New prescription'),
        );

        // D13, pre-filled from the session.
        expect(find.text('Medication prescription'), findsWidgets);
        await tap(tester, find.widgetWithText(FilledButton, 'Add medicine'));

        // BR-CAT4: three sections, "other specialties" hidden by the chip.
        await typeSearch(tester, 'ator');
        expect(find.text('Used before'), findsOneWidget);
        expect(find.text('Your specialty'), findsOneWidget);
        expect(find.text('From other specialties'), findsOneWidget);
        expect(search.calls.last, (query: 'ator', mySpecialtyOnly: false));
        await tap(tester, find.widgetWithText(FilterChip, 'My specialty only'));
        expect(search.calls.last.mySpecialtyOnly, isTrue);
        expect(find.text('From other specialties'), findsNothing);

        // BR-CAT7: picking fills the name and suggests the strength and form.
        await tap(tester, find.text('Atorstat 20'));
        expect(fieldInDialog('20 mg'), findsOneWidget);
        await tap(tester, find.text('After food'));
        await tester.enterText(fieldInDialog('Number'), '30');
        await tap(tester, find.widgetWithText(ChoiceChip, 'Days'));
        await tap(tester, inDialog('Add'));
        expect(find.text('Atorstat 20 · 20 mg · Tablet'), findsOneWidget);
        expect(find.text('30 days'), findsOneWidget);

        // BR-CAT8: a name that isn't in the catalog.
        await tap(tester, find.widgetWithText(FilledButton, 'Add medicine'));
        await typeSearch(tester, 'Custom syrup 250MG');
        await tap(tester, find.text('Use “Custom syrup 250MG”'));
        expect(
          fieldInDialog('250 MG'),
          findsOneWidget,
          reason: 'the strength read from the typed name',
        );
        await tap(tester, inDialog('Add'));

        // Swipe or ✕ removes, with Undo.
        await tap(tester, find.byTooltip('Remove').last);
        expect(find.text('Item removed.'), findsOneWidget);
        await tap(tester, find.text('Undo'));
        await snackGone(tester);

        await tap(tester, find.widgetWithText(OutlinedButton, 'Save draft'));
        final draft = prescriptionsOf(tester).ofPatient(mona(tester)).first;
        expect(draft.status, PrescriptionStatus.draft);
        expect(
          [for (final item in draft.medications) item.drugName],
          ['Atorstat 20', 'Custom syrup 250MG'],
        );
        expect(draft.medications.first.catalogId, 'drug:1');
        expect(draft.medications.first.timing, MedicationTiming.afterFood);
        expect(draft.medications.last.catalogId, isNull);

        // D15: preview, then send with its PDF.
        await tap(tester, find.widgetWithText(FilledButton, 'Preview'));
        expect(find.textContaining('PDF '), findsOneWidget);
        await tap(tester, find.widgetWithText(FilledButton, 'Send to patient'));
        expect(find.text('Send to the patient?'), findsOneWidget);
        await tap(tester, inAlert('Send to patient'));
        final sent = prescriptionsOf(tester).stored(draft.prescriptionId)!;
        expect(sent.status, PrescriptionStatus.sent);
        expect(
          prescriptionsOf(tester).sentPdfs[draft.prescriptionId]!.sublist(0, 5),
          '%PDF-'.codeUnits,
        );
        expect(printer.printed, isEmpty);
        expect(find.widgetWithText(FilledButton, 'Print'), findsOneWidget);
      },
    );

    testWidgets('a draft with no items can’t be previewed (BR-RX3)', (
      tester,
    ) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(
        tester,
        '/doctor/patients/${mona(tester)}/sessions/${monaSession(tester)}',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'New prescription'));
      await tap(tester, find.widgetWithText(FilledButton, 'Preview'));
      expect(find.text('Add at least one item.'), findsOneWidget);
    });
  });

  group('D15 preview and send', () {
    testWidgets('printing a draft sends it: «إرسال وطباعة؟» (BR-RX5)', (
      tester,
    ) async {
      await start(tester, 'doctor@el3yada.dev');
      final draft = prescriptionsOf(tester)
          .ofPatient(mona(tester))
          .firstWhere((rx) => rx.status == PrescriptionStatus.draft);
      await open(
        tester,
        '/doctor/patients/${mona(tester)}/prescriptions/${draft.prescriptionId}/preview',
      );

      await tap(tester, find.widgetWithText(OutlinedButton, 'Send and print'));
      expect(find.text('Send and print?'), findsOneWidget);
      await tap(tester, inAlert('Send and print'));

      expect(
        prescriptionsOf(tester).stored(draft.prescriptionId)!.status,
        PrescriptionStatus.sent,
      );
      expect(printer.printed, hasLength(1));
    });

    testWidgets(
      'sent: print again, share, print all; cancel with a reason; then a new copy',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        final rxs = prescriptionsOf(tester).ofPatient(mona(tester));
        final sent = rxs.firstWhere(
          (rx) => rx.status == PrescriptionStatus.sent,
        );
        final draft = rxs.firstWhere(
          (rx) => rx.status == PrescriptionStatus.draft,
        );
        // Both kinds sent in the session: Print all appears (BR-RX5).
        await open(
          tester,
          '/doctor/patients/${mona(tester)}/prescriptions/${draft.prescriptionId}/preview',
        );
        await tap(tester, find.widgetWithText(FilledButton, 'Send to patient'));
        await tap(tester, inAlert('Send to patient'));
        await snackGone(tester);

        await open(
          tester,
          '/doctor/patients/${mona(tester)}/prescriptions/${sent.prescriptionId}',
        );
        await tap(tester, find.widgetWithText(FilledButton, 'Print'));
        await tap(tester, find.widgetWithText(OutlinedButton, 'Share PDF'));
        await tap(tester, find.widgetWithText(OutlinedButton, 'Print all'));
        expect(printer.printed, hasLength(1));
        expect(printer.shared.single, startsWith('prescription-'));
        expect(printer.printedAll, [2]);

        // Cancel with a reason: no Print any more.
        await tap(tester, find.byTooltip('More'));
        await tap(tester, find.text('Cancel prescription').last);
        await tester.enterText(
          find.widgetWithText(TextField, 'Reason'),
          'جرعة خاطئة',
        );
        await tap(tester, inAlert('Cancel prescription'));
        expect(
          prescriptionsOf(tester).stored(sent.prescriptionId)!.status,
          PrescriptionStatus.cancelled,
        );
        expect(find.text('Cancelled: جرعة خاطئة'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Print'), findsNothing);

        // Issue new copy: a draft pre-filled from the cancelled one.
        await tap(tester, find.widgetWithText(TextButton, 'Issue new copy'));
        final copy = prescriptionsOf(tester).ofPatient(mona(tester)).first;
        expect(copy.status, PrescriptionStatus.draft);
        expect(copy.replacesRxId, sent.prescriptionId);
        expect(copy.medications.length, sent.medications.length);
        expect(find.widgetWithText(FilledButton, 'Preview'), findsOneWidget);
      },
    );
  });

  testWidgets('D14 investigations request: a scan from the radiology search', (
    tester,
  ) async {
    await start(tester, 'doctor@el3yada.dev');
    await open(
      tester,
      '/doctor/patients/${mona(tester)}/sessions/${monaSession(tester)}',
    );
    await tap(tester, find.widgetWithText(FilledButton, 'New request'));
    expect(find.text('Investigations request'), findsWidgets);
    await tap(tester, find.widgetWithText(FilledButton, 'Add test'));
    await tap(tester, inDialog('Radiology'));
    await typeSearch(tester, 'chest');
    expect(find.text('XR · Chest'), findsOneWidget);
    await tap(tester, find.text('XR Chest PA'));
    await tester.enterText(fieldInDialog('Notes'), 'وضع أمامي');
    await tap(tester, inDialog('Add'));
    await tap(tester, find.widgetWithText(OutlinedButton, 'Save draft'));

    final draft = prescriptionsOf(tester).ofPatient(mona(tester)).first;
    expect(draft.kind, PrescriptionKind.investigations);
    final item = draft.investigations.single;
    expect(
      (item.category, item.name, item.loincCode, item.notes),
      (InvestigationCategory.radiology, 'XR Chest PA', '36643-5', 'وضع أمامي'),
    );
  });

  testWidgets('D6 Prescriptions tab: statuses, newest first', (tester) async {
    await start(tester, 'doctor@el3yada.dev');
    await open(tester, '/doctor/patients/${mona(tester)}');
    await tap(tester, find.widgetWithText(Tab, 'Prescriptions'));
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Augmentin 1g, Panadol Extra'), findsOneWidget);
  });

  testWidgets(
    'AS8: a reception assistant sees sent documents only, and prints and shares them',
    (tester) async {
      await start(tester, '01000000001');
      await open(tester, '/assistant/patients/${mona(tester)}');
      await tap(tester, find.widgetWithText(Tab, 'Prescriptions'));
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Draft'), findsNothing);
      expect(
        find.text('New prescription'),
        findsNothing,
        reason: 'no prescriptionsDraft',
      );
      await tap(tester, find.text('Augmentin 1g, Panadol Extra'));
      expect(find.widgetWithText(FilledButton, 'Print'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Send to patient'),
        findsNothing,
      );
      expect(find.byTooltip('More'), findsNothing);
      await tap(tester, find.widgetWithText(FilledButton, 'Print'));
      expect(printer.printed, hasLength(1));
    },
  );

  testWidgets(
    'AS7: an assistant with prescriptionsDraft prepares a draft and sends it for review',
    (tester) async {
      await start(tester, '01000000001', clinic: _ClinicalAssistantClinic());
      await open(
        tester,
        '/assistant/patients/${mona(tester)}/sessions/${monaSession(tester)}',
      );
      await tap(tester, find.widgetWithText(FilledButton, 'New prescription'));
      expect(find.widgetWithText(FilledButton, 'Preview'), findsNothing);
      await tap(tester, find.widgetWithText(FilledButton, 'Add medicine'));
      await typeSearch(tester, 'Paracetamol 500 mg');
      await tap(tester, find.text('Use “Paracetamol 500 mg”'));
      await tap(tester, inDialog('Add'));
      await tap(
        tester,
        find.widgetWithText(FilledButton, 'Send to the doctor for review'),
      );

      final rx = prescriptionsOf(tester).ofPatient(mona(tester)).first;
      expect(rx.status, PrescriptionStatus.readyForReview);
      expect(rx.preparedBy!.isAssistant, isTrue);
      expect(find.text('Sent to the doctor for review.'), findsOneWidget);
    },
  );

  testWidgets(
    'D22 print settings: language, paper and pre-printed margins are saved',
    (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings/rx');
      expect(find.text('Prescription header and printing'), findsWidgets);
      expect(
        find.textContaining('PDF '),
        findsOneWidget,
        reason: 'the live preview',
      );

      await tap(tester, find.text('English'));
      await tap(tester, find.text('A4'));
      await tap(tester, find.text('Pre-printed paper'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Top margin'),
        '42',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Colour code'),
        '#7A1F2B',
      );
      await settle(tester);
      await tap(tester, find.widgetWithText(FilledButton, 'Save'));

      final settings = prescriptionsOf(tester).storedSettings;
      expect(settings.language, 'en');
      expect(settings.paperSize, RxPaperSize.a4);
      expect(settings.preprinted, isTrue);
      expect(settings.marginTopMm, 42);
      expect(settings.accentColor, '#7A1F2B');
      expect(find.text('Print settings saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'D23: save a template from D15, find it in Templates, then delete it',
    (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      final sent = prescriptionsOf(tester)
          .ofPatient(mona(tester))
          .firstWhere((rx) => rx.status == PrescriptionStatus.sent);
      await open(
        tester,
        '/doctor/patients/${mona(tester)}/prescriptions/${sent.prescriptionId}',
      );
      await tap(tester, find.byTooltip('More'));
      await tap(tester, find.text('Save as template').last);
      await tester.enterText(
        find.widgetWithText(TextField, 'Template name'),
        'التهاب الحلق',
      );
      await tap(tester, inAlert('Save'));
      expect(find.text('Template saved.'), findsOneWidget);
      await snackGone(tester);

      await open(tester, '/doctor/settings/templates');
      expect(find.text('التهاب الحلق'), findsOneWidget);
      expect(
        find.text('Augmentin 1g · 1 g'),
        findsOneWidget,
        reason: 'frequently used items come from the history',
      );
      await tap(tester, find.byTooltip('Delete template'));
      await tap(tester, inAlert('Delete template'));
      expect(find.text('التهاب الحلق'), findsNothing);
    },
  );
}

/// The reception assistant's clinic, with the clinical preset instead
/// (`clinicalView` + `prescriptionsDraft`, AS7).
class _ClinicalAssistantClinic implements ClinicRepository {
  @override
  Future<ClinicContext> me() async {
    final base = FakeClinicRepository.contextFor(_session);
    final assistant = base.assistant!;
    return ClinicContext(
      role: base.role,
      doctor: base.doctor,
      assistant: ClinicAssistant(
        userId: assistant.userId,
        fullName: assistant.fullName,
        preset: AssistantPreset.clinical,
        allBranches: true,
        branchIds: const [],
      ),
      permissions: AssistantPreset.permissions[AssistantPreset.clinical]!,
      branches: base.branches,
      defaultBranchId: base.defaultBranchId,
      fees: base.fees,
      limits: base.limits,
      trial: base.trial,
    );
  }

  static final _session = FakeAuthRepository.accounts['+201000000001']!.session(
    '+201000000001',
  );
}
