import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/realtime/realtime_service.dart';
import 'package:el3yada/features/appointments/data/appointments_repository.dart';
import 'package:el3yada/features/appointments/presentation/patient_appointment_screens.dart' show QueueStatusCard;
import 'package:el3yada/features/appointments/presentation/waiting_room_screen.dart';
import 'package:el3yada/features/appointments/presentation/live_board_screen.dart';
import 'package:el3yada/features/sessions/presentation/new_session_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/pump_app.dart';

/// Queue mode (BR-AP3, BR-AP16, D34, D36): the number is given at check-in, in order of arrival.
/// The fake clinic: ap-1 (the patient, confirmed, booked first), ap-3 (a guest, pending, booked later)
/// and ap-2 (checked in, number 1), all in today's evening period.
Future<TestRig> _patient(WidgetTester tester, {FakeAppointmentsRepository? repository}) => pumpSignedIn(
      tester,
      identifier: '01000000002',
      overrides: [if (repository != null) appointmentsRepositoryProvider.overrideWithValue(repository)],
    );

Future<TestRig> _doctorDesktop(WidgetTester tester, {FakeAppointmentsRepository? repository}) => pumpSignedIn(
      tester,
      identifier: 'doctor@el3yada.dev',
      platform: AppPlatform.desktop,
      size: const Size(1600, 1000),
      overrides: [if (repository != null) appointmentsRepositoryProvider.overrideWithValue(repository)],
    );

Future<void> _openMyAppointments(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Appointments'));
  await tester.pumpAndSettle();
}

/// Drags a card with the mouse and drops it on [target] (desktop, 6.13).
Future<void> _drag(WidgetTester tester, Finder card, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(card), kind: PointerDeviceKind.mouse);
  await tester.pump();
  await gesture.moveBy(const Offset(20, 0));
  await tester.pump();
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

void main() {
  group('the offline fake follows the API queue rules', () {
    test('no number at booking; check-in and walk-ins number by arrival; numbers are never reused', () async {
      final repository = FakeAppointmentsRepository();
      final today = DateTime.now();
      final booked = await repository.book(
          BookingRequest(branchId: 'br-a1', guestName: 'زائر', guestPhone: '01111111111', visitType: 'examination',
              date: DateTime(today.year, today.month, today.day), time: '17:00'),
          staff: true);
      expect(booked.queueNumber, isNull);
      expect(booked.awaitsCheckIn, isTrue);

      expect((await repository.act('ap-1', 'check-in')).queueNumber, 2);
      expect((await repository.act('ap-1', 'left-without-seen')).queueNumber, 2);
      expect((await repository.act(booked.id, 'check-in')).queueNumber, 3);
      final walkIn = await repository.walkIn(branchId: 'br-a1', guestName: 'حضور', guestPhone: '01122222222', visitType: 'examination');
      expect(walkIn.queueNumber, 4);
      expect(walkIn.ahead, 2); // ap-2 and the booking; number 2 left
    });

    test('undoing a no-show gives a new number; priority keeps the number and goes first', () async {
      final repository = FakeAppointmentsRepository();
      await repository.act('ap-1', 'no-show');
      expect((await repository.act('ap-1', 'undo-no-show')).queueNumber, 2);
      final moved = await repository.act('ap-1', 'priority', reason: 'مسن');
      expect(moved.queueNumber, 2);
      expect(moved.ahead, 0);
      final board = await repository.board('br-a1');
      expect(board.nextNumbers, [2, 1]);
      expect(board.stage('waiting').first.priority, isTrue);
    });

    test('rescheduling keeps the booking without a number', () async {
      final repository = FakeAppointmentsRepository();
      final today = DateTime.now();
      final moved = await repository.reschedule('ap-1', branchId: 'br-a1', date: DateTime(today.year, today.month, today.day + 2), time: '10:00', staff: false);
      expect(moved.queueNumber, isNull);
      expect(moved.rescheduleCount, 1);
    });
  });

  group('patient app', () {
    testWidgets('P15: a queue period says turns go by arrival, with no number or estimate', (tester) async {
      await _patient(tester);
      await _openMyAppointments(tester);
      await tester.tap(find.text('Book'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dr. Ahmed Samy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maadi branch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Examination').first);
      await tester.pumpAndSettle();

      expect(find.text('Turns go in order of arrival at the clinic'), findsOneWidget);
      expect(find.textContaining('About'), findsNothing);

      await tester.scrollUntilVisible(find.textContaining('مسائي').first, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.textContaining('مسائي').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Confirm booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm booking'));
      await tester.pumpAndSettle();

      expect(find.text('Booking confirmed'), findsOneWidget);
      expect(find.text('Turns go in order of arrival: check in at reception when you arrive'), findsOneWidget);
      expect(find.textContaining('Evening period from'), findsOneWidget);
      expect(find.textContaining('No. '), findsNothing);
    });

    testWidgets('P16 and P17 before check-in: check in at reception, no number', (tester) async {
      await _patient(tester);
      await _openMyAppointments(tester);

      expect(find.textContaining('Check in at reception when you arrive'), findsOneWidget);
      expect(find.textContaining('No. '), findsNothing);

      await tester.tap(find.text('Dr. Ahmed Samy').first);
      await tester.pumpAndSettle();
      expect(find.text('Turns go in order of arrival: check in at reception when you arrive'), findsOneWidget);
      expect(find.text('Your number'), findsNothing);
    });

    testWidgets('P16 and P17 from check-in: the number, who is ahead, the wait, and now serving live', (tester) async {
      final repository = FakeAppointmentsRepository();
      await repository.act('ap-1', 'check-in'); // after ap-2 (number 1)
      final rig = await _patient(tester, repository: repository);
      await _openMyAppointments(tester);

      expect(find.textContaining('No. 2 · 1 patient ahead of you · Estimated wait about 10 minutes'), findsOneWidget);
      expect(find.textContaining('Check in at reception'), findsNothing);

      await tester.tap(find.text('Dr. Ahmed Samy').first);
      await tester.pumpAndSettle();
      final card = find.byType(QueueStatusCard);
      expect(find.descendant(of: card, matching: find.text('Your number')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('2')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('1 patient ahead of you')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Estimated wait about 10 minutes')), findsOneWidget);

      // The patient before goes in: the branch's queue moves, and P17 follows it live (BR-AP15).
      await repository.act('ap-2', 'call-in');
      rig.realtime.emit(const RealtimeEvent(RealtimeEvents.queueChanged, {'branchId': 'br-a1'}));
      await tester.pumpAndSettle();
      expect(find.text('Now serving 1 — your number 2'), findsOneWidget);
      expect(find.text("You're next"), findsOneWidget);
    });

    testWidgets('P1: the next appointment says to check in at reception, then shows the turn', (tester) async {
      await _patient(tester);
      expect(find.text('Next appointment'), findsOneWidget);
      expect(find.text('Turns go in order of arrival: check in at reception when you arrive'), findsOneWidget);
      expect(find.text('Your number'), findsNothing);
    });

    testWidgets('P1 in Arabic, checked in: number, patients ahead and the wait', (tester) async {
      final repository = FakeAppointmentsRepository();
      await repository.act('ap-1', 'check-in');
      await pumpSignedIn(tester, identifier: '01000000002', locale: 'ar',
          overrides: [appointmentsRepositoryProvider.overrideWithValue(repository)]);

      expect(find.text('موعدك القادم'), findsOneWidget);
      expect(find.text('دورك'), findsOneWidget);
      expect(find.text('قبلك مريض واحد'), findsOneWidget);
      expect(find.text('الانتظار المتوقع حوالي 10 دقائق'), findsOneWidget);
      expect(find.textContaining('سجّل حضورك'), findsNothing);
    });
  });

  group('live board', () {
    testWidgets('Expected shows «Booked» in booking order; check-in numbers by arrival; Waiting puts priority first', (tester) async {
      final repository = FakeAppointmentsRepository();
      final rig = await _doctorDesktop(tester, repository: repository);

      // Booked before check-in: no number, ordered by booking time (ap-1 before ap-3).
      expect(find.text('Booked'), findsNWidgets(2));
      expect(_top(tester, 'محمد إبراهيم'), lessThan(_top(tester, 'زائر جديد')));

      // ap-3 arrives first (checked in at another desk) and gets 2; ap-1 arrives after and gets 3.
      await repository.act('ap-3', 'check-in');
      rig.realtime.emit(const RealtimeEvent(RealtimeEvents.boardChanged, {'branchId': 'br-a1'}));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();

      expect(find.text('Booked'), findsNothing);
      expect(_column('Waiting (3)'), findsOneWidget);
      expect(_onCard('2'), findsOneWidget);
      expect(_onCard('3'), findsOneWidget);
      expect(_top(tester, 'خالد يوسف'), lessThan(_top(tester, 'زائر جديد')));
      expect(_top(tester, 'زائر جديد'), lessThan(_top(tester, 'محمد إبراهيم')));

      // Moved up (an elderly patient): keeps number 3 and goes first.
      await repository.act('ap-1', 'priority', reason: 'مسن');
      rig.realtime.emit(const RealtimeEvent(RealtimeEvents.boardChanged, {'branchId': 'br-a1'}));
      await tester.pumpAndSettle();
      expect(_onCard('3'), findsOneWidget);
      expect(_top(tester, 'محمد إبراهيم'), lessThan(_top(tester, 'خالد يوسف')));
      expect(find.text('Priority'), findsOneWidget);
    });

    testWidgets('drag and drop on desktop runs the same actions, and Done opens the session form', (tester) async {
      await _doctorDesktop(tester);

      // Two columns at once is not a move: nothing happens.
      await _drag(tester, find.text('محمد إبراهيم'), _column('With the doctor (0)'));
      expect(_column('Expected (2)'), findsOneWidget);

      // Expected → Waiting: check in, with the next number.
      await _drag(tester, find.text('محمد إبراهيم'), _column('Waiting (1)'));
      expect(_column('Waiting (2)'), findsOneWidget);
      expect(_onCard('2'), findsOneWidget);

      // Waiting → With the doctor: call in; and back.
      await _drag(tester, find.text('خالد يوسف'), _column('With the doctor (0)'));
      expect(_column('With the doctor (1)'), findsOneWidget);
      await _drag(tester, find.text('خالد يوسف'), _column('Waiting (1)'));
      expect(_column('Waiting (2)'), findsOneWidget);
      await _drag(tester, find.text('خالد يوسف'), _column('With the doctor (0)'));

      // With the doctor → Done: the session form for the booking (BR-LB3).
      await _drag(tester, find.text('خالد يوسف'), _column('Done (0)'));
      expect(find.byType(NewSessionScreen), findsOneWidget);
      final form = tester.widget<NewSessionScreen>(find.byType(NewSessionScreen));
      expect(form.appointmentId, 'ap-2');
      expect(form.patientId, 'pat-2');
      expect(form.branchId, 'br-a1');
    });

    testWidgets("the doctor's board adds the next patient, bookings to confirm and check-ins without a session", (tester) async {
      await _doctorDesktop(tester);

      expect(find.text('Next patient'), findsOneWidget);
      expect(find.text('1 · خالد يوسف'), findsOneWidget);
      expect(find.text('1 waiting for confirmation'), findsOneWidget);
      expect(find.text('1 checked in, no session'), findsOneWidget);

      // Yesterday's check-in without a session, to fix from its booking (BR-AP11).
      await tester.tap(find.text('1 checked in, no session'));
      await tester.pumpAndSettle();
      expect(find.text('Checked in, no session'), findsOneWidget);
      expect(find.text('سعاد كامل'), findsOneWidget);
    });

    testWidgets('Start session on the next patient opens the session form for that booking', (tester) async {
      await _doctorDesktop(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Start session'));
      await tester.pumpAndSettle();
      final form = tester.widget<NewSessionScreen>(find.byType(NewSessionScreen));
      expect(form.appointmentId, 'ap-2');
      expect(form.patientId, 'pat-2');
    });

    testWidgets('D36 waiting-room screen: now serving and the next numbers, no names, live', (tester) async {
      final repository = FakeAppointmentsRepository();
      await repository.act('ap-1', 'check-in'); // 2
      await repository.act('ap-2', 'call-in'); // now serving 1
      final rig = await _doctorDesktop(tester, repository: repository);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Waiting-room screen'));
      await tester.pumpAndSettle();

      expect(find.byType(WaitingRoomScreen), findsOneWidget);
      expect(find.text('Now serving'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      for (final name in ['محمد إبراهيم', 'خالد يوسف', 'زائر جديد']) {
        expect(find.text(name), findsNothing);
      }

      // Number 2 goes in: the screen follows the board.
      await repository.act('ap-1', 'call-in');
      rig.realtime.emit(const RealtimeEvent(RealtimeEvents.boardChanged, {'branchId': 'br-a1'}));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('No one is waiting'), findsOneWidget);

      await tester.tap(find.byTooltip('Exit full screen'));
      await tester.pumpAndSettle();
      expect(find.byType(WaitingRoomScreen), findsNothing);
    });
  });
}

/// A board column's header, read as one label such as "Waiting (3)": its name and the count badge.
Finder _column(String label) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

/// A queue number on a board card (the column headers' count badges show numbers too).
Finder _onCard(String number) => find.descendant(of: find.byType(BoardCard), matching: find.text(number));
