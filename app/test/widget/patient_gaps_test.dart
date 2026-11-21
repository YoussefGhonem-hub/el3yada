import 'dart:convert';
import 'dart:typed_data';

import 'package:el3yada/features/appointments/data/appointments_repository.dart';
import 'package:el3yada/features/appointments/domain/appointment_models.dart';
import 'package:el3yada/features/chat/chat_data.dart';
import 'package:el3yada/features/patient/data/fake_patient_repository.dart';
import 'package:el3yada/features/patient/data/patient_repository.dart';
import 'package:el3yada/features/patient/domain/patient_models.dart' as patient;
import 'package:el3yada/features/patients/presentation/patients_register_screen.dart' show UnreadChatBadge;
import 'package:el3yada/features/records/data/file_actions.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import '../support/admin_support.dart' show goTo;
import '../support/app_flow.dart';
import '../support/clinic_records_support.dart';

/// The patient-app and patient-profile gaps: P3 Book and Chat, P14 password, legal and support,
/// D4's unread badge, booking columns and CSV export, D6's Appointments tab and Book and Chat.
void main() {
  group('P3 doctor info', () {
    Future<void> openDoctor(WidgetTester tester, {PatientRepository? patients, List<Override> overrides = const []}) async {
      await pumpSignedIn(tester, identifier: '01000000002', size: const Size(400, 1400), patients: patients, overrides: overrides);
      await tester.tap(find.text('My doctors'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dr. Ahmed Samy'));
      await tester.pumpAndSettle();
    }

    testWidgets('Book opens P15 with this doctor chosen; Chat opens the thread', (tester) async {
      await openDoctor(tester);

      expect(find.widgetWithText(FilledButton, 'Book'), findsOneWidget);
      expect(find.text("This doctor's records"), findsOneWidget);
      expect(find.text("The doctor isn't available right now."), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Book'));
      await tester.pumpAndSettle();
      expect(find.text('Book an appointment'), findsOneWidget);
      expect(find.text('Choose the branch'), findsOneWidget);
      // The doctor step is skipped: Dr Ahmed is already chosen.
      expect(
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dr. Ahmed Samy')).selected,
        isTrue,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Chat'));
      await tester.pumpAndSettle();
      expect(find.text('صباح الخير يا دكتور'), findsOneWidget);
    });

    testWidgets('a suspended doctor: Book and Chat are off and say why', (tester) async {
      await openDoctor(tester, patients: _SuspendedDoctorRepository(), overrides: [
        chatRepositoryProvider.overrideWith((ref) => _ClosedChatRepository()),
      ]);

      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Book')).onPressed, isNull);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Chat')).onPressed, isNull);
      expect(find.textContaining("Online booking isn't available right now."), findsOneWidget);
      expect(find.textContaining("The doctor isn't available right now."), findsOneWidget);
      // The records stay open.
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, "This doctor's records")).onPressed, isNotNull);
    });
  });

  group('P14 account', () {
    testWidgets('change password, the legal texts and the support contact', (tester) async {
      await pumpSignedIn(
        tester,
        identifier: '01000000002',
        size: const Size(400, 1800),
        settings: const PublicSettings(supportWhatsapp: '+201012345678', supportEmail: 'help@el3yada.app'),
      );
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();

      // The rest of the P14 row is still there.
      expect(find.text('Show message text in notifications'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNWidgets(3));
      expect(find.text('Delete account'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Current password'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, 'Current password'), 'dev');
      await tester.enterText(find.widgetWithText(TextFormField, 'New password'), 'Passw0rd1');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirm password'), 'Passw0rd1');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await settle(tester);
      expect(find.widgetWithText(TextFormField, 'Current password'), findsNothing);

      await tester.tap(find.text('Terms of use'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Terms of use'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Privacy Policy'), findsOneWidget);
    });

    testWidgets('Arabic: no support card when the admin set none', (tester) async {
      await pumpSignedIn(tester, identifier: '01000000002', size: const Size(400, 1800), locale: 'ar');
      await tester.tap(find.byTooltip('الحساب'));
      await tester.pumpAndSettle();

      expect(find.text('تغيير كلمة المرور'), findsOneWidget);
      expect(find.text('الشروط والأحكام'), findsOneWidget);
      expect(find.text('تواصل مع الدعم'), findsNothing);
    });
  });

  group('D4 register', () {
    const desktop = Size(1400, 900);

    Future<_SavedFiles> start(WidgetTester tester, String account, {Size size = desktop}) async {
      final saved = _SavedFiles();
      await pumpApp(tester, size: size, extra: [fakeRecordsOverride(), fileActionsProvider.overrideWithValue(saved)]);
      await signIn(tester, account);
      goTo(tester, account.contains('@') ? '/doctor/patients' : '/assistant/patients');
      await settle(tester);
      return saved;
    }

    testWidgets('the doctor sees the unread badge and the files column, and exports CSV', (tester) async {
      // Wide enough for the files column too.
      final saved = await start(tester, 'doctor@el3yada.dev', size: const Size(1700, 900));

      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Files'), findsWidgets);
      final badges = tester.widgetList<UnreadChatBadge>(find.byType(UnreadChatBadge)).map((b) => b.count).where((c) => c > 0);
      expect(badges, unorderedEquals([2, 1]));
      // The row reads it out (the table row is one semantics node).
      expect(find.bySemanticsLabel(RegExp('2 unread messages')), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Export CSV'));
      await settle(tester);
      expect(saved.files, hasLength(1));
      final (name, mime, bytes) = saved.files.single;
      expect(name, startsWith('patients-'));
      expect(name, endsWith('.csv'));
      expect(mime, 'text/csv');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(bytes.sublist(3));
      expect(text, startsWith('File number,Name,Mobile,Gender,Age,First visit'));
      expect(text, contains('منى حسن إبراهيم'));
      expect(find.text('The patient list is exported.'), findsOneWidget);
    });

    testWidgets('sort by unread messages puts them first', (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      await tester.tap(find.widgetWithText(TextButton, 'Unread'));
      await settle(tester);

      final names = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList();
      expect(names.indexOf('منى حسن إبراهيم'), lessThan(names.indexOf('كريم سامي فؤاد')));
      expect(names.indexOf('كريم سامي فؤاد'), lessThan(names.indexOf('هدى عبد الله محمد')));
    });

    testWidgets('a reception assistant: no unread column (no chat) and no export', (tester) async {
      await start(tester, '01000000001');
      expect(find.text('Unread'), findsNothing);
      expect(find.text('Export CSV'), findsNothing);
      expect(find.byTooltip('Export CSV'), findsNothing);
    });

    testWidgets('phones: cards carry the badge, and export is an icon', (tester) async {
      await start(tester, 'doctor@el3yada.dev', size: const Size(360, 800));
      expect(find.byTooltip('Export CSV'), findsOneWidget);
      expect(find.byType(UnreadChatBadge), findsWidgets);
    });
  });

  group('D6 profile', () {
    Future<String> start(WidgetTester tester, {Size size = const Size(1400, 1000), String account = 'doctor@el3yada.dev'}) async {
      await pumpApp(tester, size: size, extra: [
        fakeRecordsOverride(),
        appointmentsRepositoryProvider.overrideWithValue(_PatientBookings()),
      ]);
      await signIn(tester, account);
      final mona = recordsOf(tester).patientIdByName(SeedPatients.mona);
      _PatientBookings.patientId = mona;
      goTo(tester, '${account.contains('@') ? '/doctor' : '/assistant'}/patients/$mona');
      await settle(tester);
      return mona;
    }

    testWidgets('the Appointments tab lists upcoming then past bookings, and no-shows', (tester) async {
      await start(tester);
      await tester.tap(find.widgetWithText(Tab, 'Appointments'));
      await settle(tester);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('No-show'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      final upcoming = tester.getTopLeft(find.text('Confirmed')).dy;
      expect(upcoming, lessThan(tester.getTopLeft(find.text('No-show')).dy));
      expect(upcoming, lessThan(tester.getTopLeft(find.text('Completed')).dy));
    });

    testWidgets('Book opens D32 with the patient picked; Chat opens the thread', (tester) async {
      await start(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Book'));
      await settle(tester);
      expect(find.text('Book an appointment'), findsOneWidget);
      expect(find.text(SeedPatients.mona), findsOneWidget);
      expect(find.text('Examination'), findsWidgets);

      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Chat'));
      await settle(tester);
      expect(find.text('صباح الخير يا دكتور'), findsOneWidget);
    });

    testWidgets('phones: five tabs scroll, and the actions sit two to a row', (tester) async {
      await start(tester, size: const Size(360, 900));
      final book = tester.getRect(find.widgetWithText(FilledButton, 'Book'));
      final session = tester.getRect(find.widgetWithText(FilledButton, 'New session'));
      expect(book.top, session.top);
      await tester.scrollUntilVisible(find.byType(TabBar), 300, scrollable: find.byType(Scrollable).first);
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.isScrollable, isTrue);
      expect(bar.tabs, hasLength(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets("a reception assistant books but can't chat", (tester) async {
      await start(tester, account: '01000000001', size: const Size(420, 1000));
      expect(find.widgetWithText(FilledButton, 'Book'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Chat'), findsNothing);
    });
  });
}

/// Dr Ahmed is suspended: booking is refused (BOOKING_UNAVAILABLE).
class _SuspendedDoctorRepository extends FakePatientRepository {
  _SuspendedDoctorRepository() : super(delay: Duration.zero);

  @override
  Future<patient.DoctorInfo> doctor(String doctorId) async {
    final info = await super.doctor(doctorId);
    return patient.DoctorInfo(
      doctor: info.doctor, specialty: info.specialty, degreesAr: info.degreesAr, degreesEn: info.degreesEn,
      doctorStatus: 'suspended', fileNumber: info.fileNumber, branches: info.branches,
    );
  }
}

/// Every conversation can't take messages (P12: suspended doctor or chat switched off).
class _ClosedChatRepository extends FakeChatRepository {
  _ClosedChatRepository() : super(staff: false);

  @override
  Future<List<ChatSummary>> inbox({String? search}) async => [
        for (final c in await super.inbox(search: search))
          ChatSummary(
            id: c.id, doctorId: c.doctorId, patientId: c.patientId, name: c.name, nameEn: c.nameEn,
            canSend: false, unavailableReason: 'CHAT_UNAVAILABLE',
          ),
      ];
}

/// The files D4 saved, instead of a save dialog or the share sheet.
class _SavedFiles implements FileActions {
  final files = <(String, String, Uint8List)>[];

  @override
  Future<bool> save(Uint8List bytes, {required String fileName, required String mimeType}) async {
    files.add((fileName, mimeType, bytes));
    return true;
  }

  @override
  Future<bool> openWith(Uint8List bytes, {required String fileName, required String mimeType}) async => true;

  @override
  Future<void> share(Uint8List bytes, {required String fileName, required String mimeType}) async {}
}

/// The offline bookings plus three of one patient's: a confirmed one next week, a no-show and a
/// completed visit in the past.
class _PatientBookings extends FakeAppointmentsRepository {
  static String patientId = '';

  @override
  Future<SearchResult> search(SearchFilter filter) async {
    if (filter.patientId == null) return super.search(filter);
    final today = DateTime.now();
    Appointment make(String id, int days, String status) {
      final day = DateTime(today.year, today.month, today.day).add(Duration(days: days));
      return Appointment(
        id: id,
        doctor: const patient.DoctorRef(id: 'doc-a', fullName: 'د. أحمد سامي', title: 'استشاري'),
        branch: const patient.BranchRef(id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch'),
        patientId: patientId,
        displayName: 'منى حسن إبراهيم',
        isGuest: false,
        visitType: 'examination',
        mode: 'queue',
        date: day,
        time: '17:00',
        startUtc: day.add(const Duration(hours: 15)).toUtc(),
        status: status,
        source: 'staff',
      );
    }

    final items = filter.patientId == patientId
        ? [make('ap-next', 7, AppointmentStatus.confirmed), make('ap-miss', -5, AppointmentStatus.noShow), make('ap-done', -20, AppointmentStatus.completed)]
        : <Appointment>[];
    return SearchResult(items: items, totalCount: items.length, statusCounts: const {});
  }
}
