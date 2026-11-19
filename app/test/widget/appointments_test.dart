import 'package:el3yada/core/network/api_error.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/realtime/realtime_service.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/features/appointments/application/appointment_providers.dart';
import 'package:el3yada/features/appointments/data/appointments_repository.dart';
import 'package:el3yada/features/appointments/domain/appointment_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';

Future<void> signInDoctorDesktop(WidgetTester tester, {String locale = 'en'}) =>
    pumpSignedIn(tester, identifier: 'doctor@el3yada.dev', platform: AppPlatform.desktop, size: const Size(1600, 1000), locale: locale);

/// Board reads fail after the first one, like a lost connection.
class _FlakyRepository extends FakeAppointmentsRepository {
  int calls = 0;

  @override
  Future<BoardSnapshot> board(String branchId, {DateTime? date}) {
    calls++;
    if (calls > 1) throw const ApiError(ApiError.network);
    return super.board(branchId, date: date);
  }
}

void main() {
  testWidgets('live board on desktop: columns, check in, call in, now serving', (tester) async {
    await signInDoctorDesktop(tester);

    expect(find.text('Expected (2)'), findsOneWidget);
    expect(find.text('Waiting (1)'), findsOneWidget);
    expect(find.text('محمد إبراهيم'), findsOneWidget);

    // The first expected card is confirmed: its main action is Check in.
    await tester.tap(find.widgetWithText(FilledButton, 'Check in').first);
    await tester.pumpAndSettle();
    expect(find.text('Waiting (2)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Call in').first);
    await tester.pumpAndSettle();
    expect(find.text('With the doctor (1)'), findsOneWidget);
    expect(find.text('Now serving'), findsOneWidget);
  });

  testWidgets('the side panel shows the patient and its actions', (tester) async {
    await signInDoctorDesktop(tester);
    await tester.tap(find.text('محمد إبراهيم'));
    await tester.pumpAndSettle();

    expect(find.textContaining('البنسلين'), findsOneWidget);   // allergies, doctor view
    expect(find.widgetWithText(FilledButton, 'Mark no-show'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Mark no-show'));
    await tester.pumpAndSettle();
    expect(find.text('Missed (1)'), findsOneWidget);
  });

  testWidgets('a guest walk-in is checked in at once', (tester) async {
    await signInDoctorDesktop(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Walk-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guest').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'زائر سريع');
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '01122334455');
    await tester.tap(find.widgetWithText(FilledButton, 'Check in').last);
    await tester.pumpAndSettle();

    expect(find.text('Waiting (2)'), findsOneWidget);
    expect(find.text('زائر سريع'), findsOneWidget);
  });

  testWidgets('phone: stages are tabs with counts', (tester) async {
    await pumpSignedIn(tester, identifier: 'doctor@el3yada.dev', size: const Size(400, 860));
    expect(find.text('Expected (2)'), findsOneWidget);
    await tester.tap(find.text('Waiting (1)'));
    await tester.pumpAndSettle();
    expect(find.text('خالد يوسف'), findsOneWidget);
  });

  testWidgets('Arabic board renders right to left', (tester) async {
    await signInDoctorDesktop(tester, locale: 'ar');
    expect(find.text('الدور الحالي'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('الدور الحالي'))), TextDirection.rtl);
  });

  testWidgets('patient books from P16 through P15 and sees the result', (tester) async {
    await pumpSignedIn(tester, identifier: '01000000002');
    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);

    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Ahmed Samy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maadi branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Examination').first);
    await tester.pumpAndSettle();

    // The first open day is selected; pick its evening period.
    await tester.scrollUntilVisible(find.textContaining('مسائي').first, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('مسائي').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(find.text('Booking confirmed'), findsOneWidget);
  });

  testWidgets('patient cancels an upcoming booking from P17', (tester) async {
    await pumpSignedIn(tester, identifier: '01000000002');
    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Ahmed Samy').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel booking').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.text('Your booking was cancelled.'), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets);
  });

  testWidgets('staff book a quick guest (D32)', (tester) async {
    await signInDoctorDesktop(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quick guest'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'زائر جديد تماماً');
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '01099887766');
    await tester.pumpAndSettle();
    expect(find.text('The first visit is always an examination.'), findsOneWidget);

    await tester.tap(find.textContaining('صباحي').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    expect(find.text('Booking details'), findsOneWidget);
    expect(find.text('زائر جديد تماماً'), findsOneWidget);
  });

  testWidgets('schedule editor saves after copying Saturday to every day', (tester) async {
    await signInDoctorDesktop(tester);
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Saturday to all days'));
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule saved'), findsOneWidget);
  });

  test('the board goes offline when refreshing fails, and keeps the last data (BR-LB5)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = _FlakyRepository();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appointmentsRepositoryProvider.overrideWithValue(repository),
      realtimeServiceProvider.overrideWithValue(FakeRealtimeService()),
    ]);
    addTearDown(container.dispose);
    final sub = container.listen(boardProvider('br-a1'), (previous, next) {});
    addTearDown(sub.close);

    final first = await container.read(boardProvider('br-a1').future);
    expect(first.offline, isFalse);
    await container.read(boardProvider('br-a1').notifier).refresh();
    final after = container.read(boardProvider('br-a1')).value!;
    expect(after.offline, isTrue);
    expect(after.snapshot.entries, isNotEmpty);
  });
}
