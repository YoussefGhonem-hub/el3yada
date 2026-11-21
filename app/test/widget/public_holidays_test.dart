import 'package:el3yada/features/admin/data/public_holidays_repository.dart';
import 'package:el3yada/features/admin/presentation/settings/public_holidays_screen.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// AD13 [C]: the public holidays the admin keeps, and D29's suggestions to
/// close on them (BR-AP13). A holiday closes nothing by itself.
void main() {
  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  Finder inDialog(Finder finder) => find.descendant(of: find.byType(AlertDialog), matching: finder);

  testWidgets('the admin adds a holiday, one a date, and removes one', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'admin@el3yada.dev');

    await open(tester, '/admin/settings');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Public holidays'));
    await settle(tester);
    expect(find.byType(PublicHolidaysScreen), findsOneWidget);
    expect(find.text('Sinai Liberation Day'), findsOneWidget);
    expect(find.text('Labour Day'), findsOneWidget);

    // Today, named in both languages.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add holiday'));
    await settle(tester);
    await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Add holiday')));
    await settle(tester);
    expect(inDialog(find.text('This field is required')), findsWidgets);
    await tester.tap(inDialog(find.text('Choose the date')));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.enterText(inDialog(find.byType(TextField).at(0)), 'يوم العيادة');
    await tester.enterText(inDialog(find.byType(TextField).at(1)), 'Clinic Day');
    await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Add holiday')));
    await settle(tester);
    expect(find.text('Holiday added'), findsOneWidget);
    expect(find.text('Clinic Day'), findsOneWidget);

    // The same date again is refused.
    await tester.pump(const Duration(seconds: 5)); // the snack bar goes
    await settle(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add holiday'));
    await settle(tester);
    await tester.tap(inDialog(find.text('Choose the date')));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.enterText(inDialog(find.byType(TextField).at(0)), 'مكرر');
    await tester.enterText(inDialog(find.byType(TextField).at(1)), 'Again');
    await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Add holiday')));
    await settle(tester);
    expect(find.text('That date is already on the list.'), findsOneWidget);
    await tester.tap(inDialog(find.text('Cancel')));
    await settle(tester);

    await tester.tap(find.byTooltip('Remove').first);
    await settle(tester);
    expect(find.text('Remove Clinic Day?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await settle(tester);
    expect(find.text('Clinic Day'), findsNothing);
    expect(
      (await (appContainer(tester).read(publicHolidaysRepositoryProvider) as FakePublicHolidaysRepository).list()).map((h) => h.nameEn),
      ['Sinai Liberation Day', 'Labour Day'],
    );
  });

  testWidgets('D29 suggests the coming holidays; closing on one is a closure saved with the schedule', (tester) async {
    await pumpApp(tester, extra: [fakeClinicAdminOverride()]);
    await signIn(tester, 'doctor@el3yada.dev');
    await open(tester, '/doctor/branches/${FakeClinicAdminRepository.maadiBranchId}?tab=dates');

    expect(find.text('Public holidays'), findsOneWidget);
    expect(find.text('Sinai Liberation Day'), findsOneWidget);
    expect(find.text('Close this day'), findsNWidgets(2));
    // Nothing is closed until the doctor chooses.
    expect(find.text('No closures coming up.'), findsOneWidget);

    await tester.tap(find.text('Close this day').first);
    await settle(tester);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Close this day'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);

    final closure = appointmentsFake(tester).lastSchedule!.closures.single;
    final now = DateTime.now();
    final holiday = DateTime(now.year, now.month, now.day).add(const Duration(days: 9));
    expect((closure.from, closure.to, closure.allBranches), (holiday, holiday.add(const Duration(days: 1)), false));
    expect(closure.reason, 'عيد تحرير سيناء');
    expect(find.text('Schedule saved'), findsOneWidget);
  });
}
