import 'package:el3yada/features/clinic_admin/presentation/branches/branch_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// D27 activity log, through the offline clinic.
void main() {
  Future<void> openLog(WidgetTester tester) async {
    await pumpApp(tester, extra: [fakeClinicAdminOverride()]);
    await signIn(tester, 'doctor@el3yada.dev');
    goTo(tester, '/doctor/activity');
    await settle(tester);
  }

  testWidgets('rows read as sentences, with who, the patient and a day heading', (tester) async {
    await openLog(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Changed the working hours of Maadi'), findsOneWidget);
    expect(find.text('Changed the prices of Nasr City'), findsOneWidget);
    expect(find.text('Examination: not set → EGP 400'), findsOneWidget);
    expect(find.text('Changed منى سمير\'s permissions'), findsOneWidget);
    expect(find.text('Added: Chat.'), findsOneWidget);
    // Actions the app doesn't know yet still read.
    expect(find.text('Other action: patient created'), findsWidgets);
    expect(find.text('كريم عادل, file 18'), findsOneWidget);
  });

  testWidgets('filters by person and by action', (tester) async {
    await openLog(tester);

    await tester.tap(find.text('Who'));
    await settle(tester);
    await tester.tap(find.text('مدير العيادة (Assistant)').last);
    await settle(tester);
    expect(find.text('Changed the prices of Nasr City'), findsOneWidget);
    expect(find.text('Changed the working hours of Maadi'), findsNothing);

    await tester.tap(find.text('Clear filters'));
    await settle(tester);
    await tester.tap(find.text('Action'));
    await settle(tester);
    await tester.tap(find.text('Working hours changed').last);
    await settle(tester);
    expect(find.text('Changed the working hours of Maadi'), findsOneWidget);
    expect(find.text('Changed the prices of Nasr City'), findsNothing);
  });

  testWidgets('a patient on a row filters the log to them', (tester) async {
    await openLog(tester);

    await tester.tap(find.text('منى حسن, file 17').first);
    await settle(tester);
    expect(find.byType(InputChip), findsOneWidget);
    expect(find.text('Other action: session created'), findsOneWidget);
    expect(find.text('Changed the working hours of Maadi'), findsNothing);
  });

  testWidgets('a change elsewhere shows up, and a row opens its item', (tester) async {
    await openLog(tester);

    goTo(tester, '/doctor/branches/dev-branch-nasr-city?tab=hours');
    await settle(tester);
    await tester.tap(find.text('Copy Saturday to all days'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Copy Saturday to all days'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    goTo(tester, '/doctor/activity');
    await settle(tester);
    await tester.tap(find.byTooltip('Refresh'));
    await settle(tester);
    expect(find.text('Changed the working hours of Nasr City'), findsOneWidget);
    expect(find.text('7 periods a week'), findsOneWidget);

    await tester.tap(find.text('Changed the working hours of Nasr City'));
    await settle(tester);
    expect(find.byType(BranchEditorScreen), findsOneWidget);
  });
}
