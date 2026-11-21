import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/catalog/application/catalog_providers.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/clinic/domain/clinic_context.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart' show appContainer, goTo;
import '../support/app_flow.dart';
import '../support/clinic_records_support.dart';
import '../support/rx_support.dart';

/// "Report a missing or wrong item" [S] (BR-CAT8) from D13's and D14's
/// search: it reaches AD20's doctor reports (the offline catalog server is
/// shared with AD20).
void main() {
  const desktop = Size(1400, 1000);
  const phone = Size(400, 860);

  Future<void> start(WidgetTester tester, String account, {ClinicRepository? clinic, Size size = desktop}) async {
    await pumpApp(
      tester,
      size: size,
      extra: [
        fakeRecordsOverride(),
        ...rxOverrides(printer: RecordingPrinter(), search: FakeCatalogSearch()),
      ],
      clinic: clinic,
    );
    await signIn(tester, account);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  /// Opens a new prescription ([request]: an investigations request) from
  /// Mona's first visit, and its Add sheet.
  Future<void> openSheet(WidgetTester tester, {bool request = false}) async {
    final records = recordsOf(tester);
    final patient = records.patientIdByName(SeedPatients.mona);
    goTo(tester, '/doctor/patients/$patient/sessions/${records.sessionIdsOf(patient).first}');
    await settle(tester);
    await tap(tester, find.widgetWithText(FilledButton, request ? 'New request' : 'New prescription'));
    await tap(tester, find.widgetWithText(FilledButton, request ? 'Add test' : 'Add medicine'));
  }

  Future<void> typeSearch(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
  }

  List<CatalogReport> reportsOf(WidgetTester tester) =>
      appContainer(tester).read(fakeCatalogBackendProvider).reports.values.where((r) => r.reportId.startsWith('cr-doctor')).toList();

  testWidgets('D13: a name the catalog doesn\'t have is reported from the search, typed text included', (tester) async {
    await start(tester, 'doctor@el3yada.dev');
    await openSheet(tester);

    await tester.enterText(
      find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).first,
      'Ketofan 50 mg',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    await tap(tester, find.text('Report a missing or wrong item'));

    expect(find.text('Report to the admin'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Missing item')).selected, isTrue);
    expect(find.widgetWithText(TextField, 'Details'), findsOneWidget);
    expect(find.text('Ketofan 50 mg'), findsWidgets, reason: 'the typed name is filled in');
    await tap(tester, find.widgetWithText(FilledButton, 'Send report'));

    expect(find.text('Report to the admin'), findsNothing);
    expect(find.text('Sent to the admin. Thank you!'), findsOneWidget);
    final report = reportsOf(tester).single;
    expect(report.type, CatalogReportType.missing);
    expect(report.text, 'Ketofan 50 mg');
    expect(report.itemRef, 'search:Ketofan 50 mg');
    expect(report.done, isFalse, reason: 'open in AD20 until an admin handles it');
    expect(find.text('Add medicine'), findsWidgets, reason: 'the medicine sheet stays open');
  });

  testWidgets('D14 on a phone: a picked test that is wrong, with its code; the details are required', (tester) async {
    await start(tester, 'doctor@el3yada.dev', size: phone);
    await openSheet(tester, request: true);
    await typeSearch(tester, 'cbc');
    await tap(tester, find.text('CBC panel'));

    await tap(tester, find.text('Something wrong with this item? Report it'));
    expect(find.text('About: CBC panel'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Wrong details')).selected, isTrue);
    await tap(tester, find.widgetWithText(FilledButton, 'Send report'));
    expect(find.text("Write what's missing or wrong."), findsOneWidget);
    expect(reportsOf(tester), isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Details'), 'الاسم العربي ناقص');
    await tap(tester, find.widgetWithText(FilledButton, 'Send report'));
    final report = reportsOf(tester).single;
    expect(report.type, CatalogReportType.wrong);
    expect(report.itemRef, 'loinc:58410-2');
    expect(report.text, 'الاسم العربي ناقص');
  });

  testWidgets('AS7: an assistant drafting a prescription has no report option (doctor only)', (tester) async {
    await start(tester, '01000000001', clinic: _ClinicalAssistantClinic());
    final records = recordsOf(tester);
    final patient = records.patientIdByName(SeedPatients.mona);
    goTo(tester, '/assistant/patients/$patient/sessions/${records.sessionIdsOf(patient).first}');
    await settle(tester);
    await tap(tester, find.widgetWithText(FilledButton, 'New prescription'));
    await tap(tester, find.widgetWithText(FilledButton, 'Add medicine'));
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)).first, 'Ketofan');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Use “Ketofan”'), findsOneWidget);
    expect(find.text('Report a missing or wrong item'), findsNothing);
    await tap(tester, find.text('Atorstat 20'));
    expect(find.text('Something wrong with this item? Report it'), findsNothing);
  });
}

/// A clinical assistant (prescriptionsDraft) of the offline doctor.
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

  static final _session = FakeAuthRepository.accounts['+201000000001']!.session('+201000000001');
}
