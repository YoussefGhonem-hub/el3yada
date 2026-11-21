import 'package:el3yada/features/appointments/data/appointments_repository.dart';
import 'package:el3yada/features/patients/presentation/add_patient_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_records_support.dart';

/// D32 "New patient": the mobile number first, then the patient is created
/// (or linked) through D5 and the booking goes on with them; a guest stays
/// a quick option (spec D32, BR-P3, BR-P4, BR-AP4).
void main() {
  Future<void> openBooking(WidgetTester tester) async {
    await pumpApp(tester, extra: [fakeRecordsOverride()]);
    await signIn(tester, 'doctor@el3yada.dev');
    goTo(tester, '/doctor/appointments/book');
    await settle(tester);
    await tester.tap(find.text('New patient'));
    await settle(tester);
  }

  Future<void> typeNumber(WidgetTester tester, String number) async {
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), number);
    // The lookup waits for the typing to stop.
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
  }

  testWidgets('a new number is created through D5, then booked as an examination', (tester) async {
    await openBooking(tester);
    expect(find.text('Type the mobile number first'), findsOneWidget);
    await typeNumber(tester, '01011113333');
    expect(find.text('A new number'), findsOneWidget);
    expect(find.text('Quick guest'), findsOneWidget);

    await tester.tap(find.text('Create patient now'));
    await settle(tester);

    // D5, with the number already typed and checked.
    expect(find.byType(AddPatientScreen), findsOneWidget);
    expect(find.text('New number. Fill in the patient’s details.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'سلمى محمد');
    await tester.tap(find.text('Female'));
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<bool>), matching: find.text('Age')));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Age in years'), '31');
    final add = find.widgetWithText(FilledButton, 'Add patient');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await settle(tester);

    // The temporary password is shown once (BR-P4), then the booking goes on.
    final password = recordsOf(tester).temporaryPasswords.last;
    expect(find.text(password), findsOneWidget);
    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.byType(AddPatientScreen), findsNothing);
    expect(find.text('سلمى محمد'), findsOneWidget);
    expect(find.text('The first visit is always an examination.'), findsOneWidget);

    await tester.tap(find.textContaining('صباحي').first);
    await settle(tester);
    await tester.tap(find.text('Confirm booking'));
    await settle(tester);
    expect(find.text('Booking details'), findsOneWidget);
    final created = (await tester.runAsync(() => recordsOf(tester).lookupPhone('01011113333')))!.patientId;
    expect(created, isNotNull);
    final booked = await (appContainer(tester).read(appointmentsRepositoryProvider) as FakeAppointmentsRepository)
        .search(const SearchFilter());
    expect(booked.items.where((a) => a.patientId == created && a.visitType == 'examination'), hasLength(1));
  });

  testWidgets("one of the doctor's patients is offered straight away", (tester) async {
    await openBooking(tester);
    await typeNumber(tester, '010 1234 5678');

    expect(find.text('This number is already one of your patients'), findsOneWidget);
    await tester.tap(find.text('Book for this patient'));
    await settle(tester);
    expect(find.text('Type the mobile number first'), findsNothing);
    expect(find.byType(AddPatientScreen), findsNothing);
    expect(find.textContaining('File'), findsWidgets);
  });

  testWidgets('a new number can still be a quick guest', (tester) async {
    await openBooking(tester);
    await typeNumber(tester, '01055554444');
    await tester.tap(find.text('Quick guest'));
    await settle(tester);

    expect(find.text('Quick guest: the name and number only. The account is made when they check in.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'زائر سريع');
    await settle(tester);
    expect(find.text('The first visit is always an examination.'), findsOneWidget);
  });
}
