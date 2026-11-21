import 'package:el3yada/features/appointments/domain/appointment_models.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/presentation/branches/branch_editor_screen.dart';
import 'package:el3yada/features/clinic_admin/presentation/branches/schedule_conflicts_sheet.dart';
import 'package:el3yada/features/patient/domain/patient_models.dart' show BranchRef, DoctorRef;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// D29's Working hours, Special dates and Booking settings tabs, the one place
/// hours change (updateBranchSchedule, BR-AP12), and AS17 for an assistant.
void main() {
  const maadi = FakeClinicAdminRepository.maadiBranchId;

  Future<void> signedIn(WidgetTester tester, String who) async {
    await pumpApp(tester, size: const Size(1400, 900), extra: [fakeClinicAdminOverride()]);
    await signIn(tester, who);
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  /// The next Saturday (not today), when Maadi works 10–14 and 18–22.
  DateTime nextSaturday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var days = (DateTime.saturday - today.weekday) % 7;
    if (days == 0) days = 7;
    return today.add(Duration(days: days));
  }

  Appointment booking(String id, String name, DateTime date, String time) => Appointment(
        id: id,
        doctor: const DoctorRef(id: 'dev-doctor', fullName: 'د. أحمد سامي', title: 'استشاري'),
        branch: const BranchRef(id: maadi, nameAr: 'فرع المعادي', nameEn: 'Maadi'),
        displayName: name,
        isGuest: true,
        visitType: 'examination',
        mode: 'queue',
        date: date,
        time: time,
        startUtc: DateTime(date.year, date.month, date.day, int.parse(time.substring(0, 2))).toUtc(),
        status: AppointmentStatus.confirmed,
        source: 'staff',
        canChange: true,
      );

  Finder inDialog(Finder finder) => find.descendant(of: find.byType(AlertDialog), matching: finder);

  group('D29 schedule tabs', () {
    testWidgets('dropping a period that has bookings opens the conflicts sheet: move one, cancel one (BR-AP12)', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      final saturday = nextSaturday();
      appointmentsFake(tester).addBookings([
        booking('ap-sat-1', 'منى حسن', saturday, '18:00'),
        booking('ap-sat-2', 'كريم علي', saturday, '18:00'),
      ]);
      await open(tester, '/doctor/branches/$maadi?tab=hours');

      // Saturday's evening period goes: its two bookings have no place left.
      await tester.tap(find.byTooltip('Remove this period').at(1));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.byType(ScheduleConflictsSheet), findsOneWidget);
      expect(find.text('2 bookings are affected'), findsOneWidget);
      expect(find.text('منى حسن'), findsOneWidget);
      // Nothing is dropped by default, and nothing is saved yet.
      expect(find.text('Stays at its time, as an exception'), findsNWidgets(2));
      expect(appointmentsFake(tester).lastDecisions, isEmpty);

      await tester.tap(find.text('Move').first);
      await settle(tester);
      expect(find.textContaining('Moves to'), findsOneWidget);
      await tester.tap(find.text('Cancel').at(1));
      await settle(tester);
      expect(find.text('The patient is told, with a link to book again'), findsOneWidget);
      await tester.tap(find.text('Apply changes'));
      await settle(tester);

      final fake = appointmentsFake(tester);
      expect(fake.lastDecisions['ap-sat-1']!.action, ConflictDecision.moveAction);
      // The server's suggestion: the same day's morning period.
      expect(fake.lastDecisions['ap-sat-1']!.to, MovePlace(branchId: maadi, date: saturday, time: '10:00'));
      expect(fake.lastDecisions['ap-sat-2']!.action, ConflictDecision.cancelAction);
      final moved = await fake.appointment('ap-sat-1');
      expect(moved.time, '10:00');
      expect((await fake.appointment('ap-sat-2')).status, AppointmentStatus.cancelled);
      expect(find.text('Schedule saved, 1 booking moved, 1 booking cancelled'), findsOneWidget);
      expect(
        clinicAdminFake(tester).weeklyOf(maadi)!.where((p) => p.weekday == DateTime.saturday).map((p) => p.start),
        ['10:00'],
      );
    });

    testWidgets('closing the conflicts sheet saves nothing', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      appointmentsFake(tester).addBookings([booking('ap-sat-1', 'منى حسن', nextSaturday(), '18:00')]);
      await open(tester, '/doctor/branches/$maadi?tab=hours');

      await tester.tap(find.byTooltip('Remove this period').at(1));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.text('1 booking is affected'), findsOneWidget);
      await tester.tap(find.text('Back to editing'));
      await settle(tester);

      expect(find.text('Nothing was saved.'), findsOneWidget);
      expect(clinicAdminFake(tester).weeklyOf(maadi)!.where((p) => p.weekday == DateTime.saturday), hasLength(2));
      expect((await appointmentsFake(tester).appointment('ap-sat-1')).status, AppointmentStatus.confirmed);
      // The change is still there to save or discard.
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    });

    testWidgets('special dates: a closed date and a vacation for every branch are saved with the schedule', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/branches/$maadi?tab=dates');

      expect(find.text('No special dates coming up.'), findsOneWidget);
      await tester.tap(find.text('Add a date'));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      // A new date starts closed.
      expect(inDialog(find.text('Closed that day')), findsOneWidget);
      await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Save')));
      await settle(tester);
      expect(find.text('Closed all day'), findsOneWidget);

      await tester.tap(find.text('Add closure'));
      await settle(tester);
      // Part of today, by default 6 to 8 in the evening.
      await tester.tap(inDialog(find.text('Part of a day')));
      await settle(tester);
      await tester.tap(inDialog(find.text('Choose the day')));
      await settle(tester);
      await tester.tap(find.text('OK'));
      await settle(tester);
      await tester.tap(inDialog(find.text('All branches')));
      await tester.enterText(inDialog(find.byType(TextField)), 'إجازة');
      await tester.tap(inDialog(find.widgetWithText(FilledButton, 'Add closure')));
      await settle(tester);
      expect(find.textContaining('إجازة'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      final saved = appointmentsFake(tester).lastSchedule!;
      expect(saved.overrides.single.periods, isEmpty);
      expect(saved.closures.single.allBranches, isTrue);
      expect(saved.closures.single.reason, 'إجازة');
      expect(find.text('Schedule saved'), findsOneWidget);
    });

    testWidgets('booking settings: switching to timed slots warns, then saves every setting', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/branches/$maadi?tab=booking');

      expect(find.text('Places per period'), findsOneWidget);
      await tester.tap(find.widgetWithText(SegmentedButton<String>, 'Timed slots'));
      await settle(tester);
      expect(find.textContaining('Changing the mode affects every upcoming booking'), findsOneWidget);
      expect(find.text('Slot length (minutes)'), findsOneWidget);
      await tester.ensureVisible(find.text('Reminder 2 hours before, on the day'));
      await settle(tester);
      await tester.tap(find.text('Reminder 2 hours before, on the day'));
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      final settings = appointmentsFake(tester).lastSchedule!.settings;
      expect(settings.mode, 'timed');
      expect(settings.reminderMinutes, [1440]);
      expect(find.text('Schedule saved'), findsOneWidget);
    });

    testWidgets('the old Schedule page opens D29 of the current branch on Working hours', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/schedule');

      expect(find.byType(BranchEditorScreen), findsOneWidget);
      expect(find.text('Copy Saturday to all days'), findsOneWidget);

      await open(tester, '/doctor/schedule?tab=dates');
      expect(find.text('Special hours'), findsOneWidget);
    });
  });

  group('AS17 branch schedule', () {
    testWidgets('an assistant with scheduleManage edits the schedule tabs and reads the others', (tester) async {
      await signedIn(tester, '+201000000005');
      await open(tester, '/assistant/schedule');

      expect(find.byType(BranchEditorScreen), findsOneWidget);
      // No Back to D28, and no clinic info for patients: that's the doctor's (BR-AS5).
      expect(find.text('Clinic info for patients'), findsNothing);
      expect(find.text('Copy Saturday to all days'), findsOneWidget);

      await open(tester, '/assistant/schedule?tab=info');
      expect(find.text('Only the doctor can change this.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await open(tester, '/assistant/schedule?tab=hours');
      await tester.tap(find.widgetWithText(TextButton, 'Add period').first);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.text('Schedule saved'), findsOneWidget);
      expect(appointmentsFake(tester).lastSchedule, isNotNull);
    });

    testWidgets('an assistant without scheduleManage has no Schedule item and is turned away by address', (tester) async {
      await signedIn(tester, '+201000000001');
      await open(tester, '/assistant/schedule');

      expect(find.byType(BranchEditorScreen), findsNothing);
    });
  });
}
