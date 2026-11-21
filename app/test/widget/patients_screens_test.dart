import 'package:el3yada/core/widgets/navigation/app_back_button.dart';
import 'package:el3yada/features/admin/presentation/widgets/admin_widgets.dart'
    show SectionCard;
import 'package:el3yada/features/patients/data/fake_clinic_records.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:el3yada/features/sessions/presentation/new_session_screen.dart'
    show TypeTicket;
import 'package:el3yada/features/sessions/presentation/widgets/session_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart' show goTo;
import '../support/app_flow.dart';
import '../support/clinic_records_support.dart';

/// Patients, sessions and fees (D1–D9, AS1–AS5) through the offline clinic,
/// which applies the API's rules (FakeClinicRecords).
void main() {
  const desktop = Size(1400, 900);
  const phone = Size(420, 900);

  Future<void> start(
    WidgetTester tester,
    String account, {
    Size size = desktop,
    bool arabic = false,
    void Function(FakeClinicRecords records)? configure,
  }) async {
    await pumpApp(
      tester,
      size: size,
      prefs: {'settings.locale': arabic ? 'ar' : 'en'},
      extra: [fakeRecordsOverride(configure: configure)],
    );
    if (arabic) {
      await tester.enterText(find.byType(TextFormField).at(0), account);
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
    } else {
      await signIn(tester, account);
    }
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  String id(WidgetTester tester, String name) =>
      recordsOf(tester).patientIdByName(name);

  /// Scrolls [finder] into view first (long forms).
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> typeMobile(WidgetTester tester, String number) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mobile'),
      number,
    );
    // The lookup waits for the typing to stop.
    await tester.pump(const Duration(milliseconds: 600));
    await settle(tester);
  }

  // Every screen at a small phone and at tablet width: a layout overflow fails the test.
  for (final (name, size) in [
    ('small phone', const Size(360, 740)),
    ('tablet', const Size(820, 1100)),
  ]) {
    testWidgets('the screens lay out on a $name', (tester) async {
      await start(tester, 'doctor@el3yada.dev', size: size);
      final mona = id(tester, SeedPatients.mona);
      final laila = id(tester, SeedPatients.laila);
      final exam = recordsOf(tester).sessionIdsOf(mona).last;
      for (final path in [
        '/doctor/live',
        '/doctor/patients',
        '/doctor/patients/new',
        '/doctor/patients/$mona',
        '/doctor/patients/$mona/edit',
        '/doctor/patients/$mona/edit?part=medical',
        '/doctor/patients/$mona/sessions/new',
        '/doctor/patients/$mona/sessions/$exam',
        '/doctor/live/sessions/new',
        '/doctor/dashboard',
        '/doctor/dashboard/today',
        '/doctor/dashboard/month',
      ]) {
        await open(tester, path);
      }
      await open(tester, '/doctor/patients/$laila/sessions/new');
      await tapVisible(tester, find.text('Consultation'));
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Amount charged'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Amount charged'), findsOneWidget);
    });
  }

  group('D5 add patient', () {
    testWidgets(
      'a new number: the temporary password once, then the profile (BR-P4)',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        await open(tester, '/doctor/patients/new');

        await typeMobile(tester, '01011112222');
        expect(
          find.text('New number. Fill in the patient’s details.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Full name'),
          'سلمى محمد',
        );
        await tester.tap(find.text('Female'));
        await tester.tap(
          find.descendant(
            of: find.byType(SegmentedButton<bool>),
            matching: find.text('Age'),
          ),
        );
        await settle(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Age in years'),
          '31',
        );
        await tapVisible(
          tester,
          find.widgetWithText(FilledButton, 'Add patient'),
        );

        final password = recordsOf(tester).temporaryPasswords.last;
        expect(find.text('Temporary password'), findsOneWidget);
        expect(find.text(password), findsOneWidget);
        await tester.tap(find.text('Done'));
        await settle(tester);

        // D6, with the next file number.
        expect(find.text('سلمى محمد'), findsWidgets);
        expect(find.text('File 16'), findsOneWidget);
        expect(find.text('≈ 31 years, Female'), findsOneWidget);
      },
    );

    testWidgets(
      "another clinic's number asks to link it, identity only (BR-P3, AC-10)",
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        await open(tester, '/doctor/patients/new');

        await typeMobile(tester, '01122223333');
        expect(
          find.text('This patient already has an account'),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Link patient').last,
        );
        await settle(tester);

        expect(
          find.text(
            'This patient already has an account and has been added to your list.',
          ),
          findsOneWidget,
        );
        expect(find.text('Temporary password'), findsNothing);
        await tester.tap(find.text('Open file'));
        await settle(tester);

        expect(find.text('ريم فتحي عبد العزيز'), findsWidgets);
        expect(
          find.textContaining('created by another clinic'),
          findsOneWidget,
        );
        expect(find.text('National ID'), findsNothing);
      },
    );

    testWidgets("one of this clinic's numbers offers its file", (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/patients/new');

      await typeMobile(tester, '010 1234 5678');
      expect(
        find.text('This number is already one of your patients'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Add patient'), findsNothing);
      await tester.tap(find.text('Open file'));
      await settle(tester);
      expect(find.text('منى حسن إبراهيم'), findsWidgets);
    });
  });

  group('D8 new session', () {
    testWidgets('a first visit offers only Examination (BR-S2)', (
      tester,
    ) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(
        tester,
        '/doctor/patients/${id(tester, SeedPatients.sara)}/sessions/new',
      );

      expect(
        find.text('First visit with you: examination only'),
        findsOneWidget,
      );
      expect(find.byType(TypeTicket), findsOneWidget);
      expect(find.text('Consultation'), findsNothing);
      expect(find.text('Examination selected'), findsOneWidget);
    });

    testWidgets(
      'after an examination and two consultations, Consultation is closed with the BR-S4 text (AC-1)',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        await open(
          tester,
          '/doctor/patients/${id(tester, SeedPatients.mona)}/sessions/new',
        );

        expect(
          find.text('Consultation 2 of 2 since the last examination'),
          findsOneWidget,
        );
        expect(
          find.text(
            'This patient has had 2 consultations in a row. Record an examination first.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Consultation'));
        await settle(tester);
        expect(find.text('Choose the visit type.'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
              .onPressed,
          isNull,
        );

        await tester.tap(find.text('Examination'));
        await settle(tester);
        expect(find.text('Examination selected'), findsOneWidget);
      },
    );

    testWidgets('the message follows the limit: 1 in a row (AC-1)', (
      tester,
    ) async {
      await start(
        tester,
        'doctor@el3yada.dev',
        configure: (records) => records.maxConsecutiveConsultations = 1,
      );
      await open(
        tester,
        '/doctor/patients/${id(tester, SeedPatients.laila)}/sessions/new',
      );

      expect(
        find.text(
          'This patient has had 1 consultation in a row. Record an examination first.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Save asks the BR-S6 confirmation with the right fee, then the after-save sheet',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        final laila = id(tester, SeedPatients.laila);
        await open(tester, '/doctor/patients/$laila/sessions/new');

        expect(
          find.text('Consultation 1 of 2 since the last examination'),
          findsOneWidget,
        );
        await tester.tap(find.text('Consultation'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await settle(tester);

        // The amount defaults to the visit price (BR-S10).
        expect(find.widgetWithText(TextField, '150'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextField, 'Diagnosis'),
          'التهاب لوزتين',
        );
        await tester.tap(find.text('Save session'));
        await settle(tester);

        expect(
          find.text('Save as Consultation?', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('A fee of EGP 15 will be added.'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        expect(find.text('Session saved'), findsOneWidget);
        expect(find.text('Write prescription'), findsOneWidget);
        expect(find.text('Later'), findsWidgets);
        await tester.tap(find.text('Done'));
        await settle(tester);

        // Back on D6: the second consultation since the last examination.
        expect(find.text('Session saved'), findsNothing);
        expect(find.text('2 of 2'), findsOneWidget);
        expect(recordsOf(tester).sessionIdsOf(laila), hasLength(4));
      },
    );

    testWidgets(
      'a session saved elsewhere first: the rule is read again (AC-2)',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        final laila = id(tester, SeedPatients.laila);
        await open(tester, '/doctor/patients/$laila/sessions/new');
        await tester.tap(find.text('Consultation'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await settle(tester);

        // Another device records the second consultation meanwhile.
        recordsOf(tester).addSession(laila, SessionType.consultation);
        await tester.tap(find.text('Save session'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);

        expect(
          find.textContaining(
            'A session was just recorded for this patient on another device.',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'This patient has had 2 consultations in a row. Record an examination first.',
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'an assistant records only the complaint and vitals (AS5, BR-AS5)',
      (tester) async {
        await start(tester, '01000000001');
        await open(
          tester,
          '/assistant/patients/${id(tester, SeedPatients.laila)}/sessions/new',
        );
        await tester.tap(find.text('Examination'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await settle(tester);

        expect(find.text('Chief complaint'), findsWidgets);
        expect(find.text('Vitals'), findsOneWidget);
        expect(find.text('Amount charged'), findsOneWidget);
        expect(find.text('Diagnosis'), findsNothing);
        expect(find.text('Examination findings'), findsNothing);
        expect(find.text('Notes for the patient'), findsNothing);
        expect(find.text('Private note'), findsNothing);
        expect(find.text('Follow-up date'), findsNothing);
      },
    );

    testWidgets(
      'a suspended doctor has no New session or Add patient (BR-G5, BR-S8)',
      (tester) async {
        await start(tester, 'suspended@el3yada.dev');
        expect(find.text('Walk-in'), findsOneWidget);
        expect(find.text('Add patient'), findsNothing);
        expect(find.text('New session'), findsNothing);

        await open(tester, '/doctor/patients');
        expect(find.text('Add patient'), findsNothing);
        await open(tester, '/doctor/patients/${id(tester, SeedPatients.mona)}');
        expect(find.text('منى حسن إبراهيم'), findsWidgets);
        expect(find.text('New session'), findsNothing);
        expect(
          find.text('Edit'),
          findsOneWidget,
          reason: 'editing still works while suspended',
        );

        await open(
          tester,
          '/doctor/patients/${id(tester, SeedPatients.mona)}/sessions/new',
        );
        expect(
          find.text('Not available while the service is suspended.'),
          findsOneWidget,
        );
        await open(tester, '/doctor/patients/new');
        expect(
          find.text('Not available while the service is suspended.'),
          findsOneWidget,
        );
      },
    );
  });

  group('D6 profile and D9 details by permission', () {
    testWidgets(
      'a reception assistant has no Overview tab, and no clinical content (AS4)',
      (tester) async {
        await start(tester, '01000000001');
        await open(
          tester,
          '/assistant/patients/${id(tester, SeedPatients.mona)}',
        );

        expect(find.widgetWithText(Tab, 'Sessions'), findsOneWidget);
        expect(find.widgetWithText(Tab, 'Overview'), findsNothing);
        expect(find.text('Allergies'), findsNothing);
        expect(find.text('Total paid'), findsNothing);
        expect(
          find.text('Reset password'),
          findsNothing,
          reason: 'in the closed menu',
        );
      },
    );

    testWidgets(
      'the doctor sees both tabs, allergies in red and the total paid',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        await open(tester, '/doctor/patients/${id(tester, SeedPatients.mona)}');

        expect(find.widgetWithText(Tab, 'Overview'), findsOneWidget);
        expect(find.widgetWithText(Tab, 'Sessions'), findsOneWidget);
        expect(find.text('بنسلين'), findsOneWidget);
        expect(find.text('Total paid'), findsOneWidget);
      },
    );

    testWidgets(
      'an assistant never sees the private note or the clinical fields in D9 (AC-11, AC-19)',
      (tester) async {
        await start(tester, '01000000001');
        final mona = id(tester, SeedPatients.mona);
        // The doctor's examination, with clinical notes and a private note.
        final exam = recordsOf(tester).sessionIdsOf(mona).last;
        await open(tester, '/assistant/patients/$mona/sessions/$exam');

        expect(find.text('Session details'), findsOneWidget);
        expect(find.text('Private note'), findsNothing);
        expect(find.text('Clinical notes'), findsNothing);
        expect(find.text('صداع نصفي'), findsNothing);
        expect(
          find.text('Amount charged'),
          findsNothing,
          reason: "not revenueView, and they didn't record it",
        );
        expect(find.text('Delete session'), findsNothing);
      },
    );

    testWidgets(
      'the doctor sees the private note, and editing the clinical fields clears «waiting» (BR-AS7)',
      (tester) async {
        await start(tester, 'doctor@el3yada.dev');
        final mona = id(tester, SeedPatients.mona);
        await open(
          tester,
          '/doctor/patients/$mona/sessions/${recordsOf(tester).sessionIdsOf(mona).last}',
        );
        expect(find.text('Private note'), findsOneWidget);
        expect(find.textContaining('تتابع مع طبيب نفسي'), findsOneWidget);
        expect(find.text('Recorded by'), findsOneWidget);

        final youssef = id(tester, SeedPatients.youssef);
        await open(
          tester,
          '/doctor/patients/$youssef/sessions/${recordsOf(tester).sessionIdsOf(youssef).first}',
        );
        expect(find.text('Waiting for the doctor'), findsOneWidget);
        expect(find.text('مساعد تجريبي (assistant)'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(SectionCard, 'Clinical notes'),
            matching: find.text('Edit'),
          ),
        );
        await settle(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Diagnosis'),
          'التهاب شعبي',
        );
        await tapVisible(
          tester,
          find.descendant(
            of: find.widgetWithText(SectionCard, 'Clinical notes'),
            matching: find.text('Save'),
          ),
        );

        expect(
          find.byType(EditableText),
          findsNothing,
          reason: 'the form closed',
        );
        expect(find.text('التهاب شعبي'), findsOneWidget);
        expect(find.text('Waiting for the doctor'), findsNothing);
      },
    );

    testWidgets('Delete shows only when BR-S7 allows it, and needs a reason', (
      tester,
    ) async {
      await start(tester, 'doctor@el3yada.dev');
      final mona = id(tester, SeedPatients.mona);
      final sessions = recordsOf(tester).sessionIdsOf(mona);

      await open(tester, '/doctor/patients/$mona/sessions/${sessions.last}');
      expect(find.text('Delete session'), findsNothing);
      expect(
        find.text("Only the patient's latest session can be deleted."),
        findsOneWidget,
      );

      await open(tester, '/doctor/patients/$mona/sessions/${sessions.first}');
      await tester.tap(find.text('Delete session'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);
      expect(
        find.text('Write the reason (3 characters or more).'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason'),
        'سجلت للمريض الخطأ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      expect(find.text('Session deleted'), findsOneWidget);
      expect(recordsOf(tester).sessionIdsOf(mona), hasLength(2));
    });

    testWidgets(
      "an assistant without sessionsDelete never sees Delete, even on today's latest session",
      (tester) async {
        await start(tester, '01000000001');
        final mona = id(tester, SeedPatients.mona);
        await open(
          tester,
          '/assistant/patients/$mona/sessions/${recordsOf(tester).sessionIdsOf(mona).first}',
        );
        expect(find.text('Session details'), findsOneWidget);
        expect(find.text('Delete session'), findsNothing);
        expect(find.textContaining('can be deleted'), findsNothing);
      },
    );
  });

  group('D4 register', () {
    testWidgets('columns follow the permissions; search narrows the list', (
      tester,
    ) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/patients');
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Allergies'), findsOneWidget);
      expect(find.text('هدى عبد الله محمد'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'منى');
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.text('منى حسن إبراهيم'), findsOneWidget);
      expect(find.text('هدى عبد الله محمد'), findsNothing);

      // A row opens D6 on the right.
      await tester.tap(find.text('منى حسن إبراهيم'));
      await settle(tester);
      expect(find.text('File summary'), findsOneWidget);
    });

    testWidgets(
      'a reception assistant has no total paid or allergy column, and Add patient',
      (tester) async {
        await start(tester, '01000000001');
        await open(tester, '/assistant/patients');
        expect(find.text('Paid'), findsNothing);
        expect(find.text('Allergies'), findsNothing);
        expect(find.text('Chronic disease'), findsNothing);
        expect(find.text('Add patient'), findsOneWidget);
      },
    );

    testWidgets('phones show cards that open the profile', (tester) async {
      await start(tester, 'doctor@el3yada.dev', size: phone);
      await open(tester, '/doctor/patients');
      await tester.tap(find.text('هدى عبد الله محمد'));
      await settle(tester);
      expect(find.text('File summary'), findsOneWidget);
    });
  });

  group('D7 edit', () {
    testWidgets('leaving with unsaved changes asks first', (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      final mona = id(tester, SeedPatients.mona);
      await open(tester, '/doctor/patients/$mona/edit');

      expect(find.text('No changes'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'منى حسن على',
      );
      await tester.pump();
      expect(find.text('Changes not saved'), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect(find.text('Edit patient'), findsNothing);
      expect(find.text('منى حسن إبراهيم'), findsWidgets);
    });

    testWidgets('the medical profile: add an allergy and save', (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      final mona = id(tester, SeedPatients.mona);
      await open(tester, '/doctor/patients/$mona/edit?part=medical');

      await tester.enterText(
        find.widgetWithText(TextField, 'Add an item').first,
        'Aspirin',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Aspirin'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('Saved'), findsOneWidget);
      expect(
        find.text('Aspirin'),
        findsOneWidget,
        reason: 'back on D6, in the red block',
      );
    });
  });

  group('fees and homes', () {
    testWidgets(
      "D1's fee card: «2 كشف + 3 استشارة = 105 ج.م», and D2 marks «بانتظار الطبيب» (AC-4, BR-AS7)",
      (tester) async {
        await start(tester, 'doctor@el3yada.dev', arabic: true);
        await open(tester, '/doctor/dashboard');
        expect(find.text('2 كشف + 3 استشارة = 105 ج.م'), findsOneWidget);

        await tester.tap(find.byType(FeeCard).first);
        await settle(tester);
        expect(find.byType(DaySessionRow), findsNWidgets(5));
        expect(find.text('بانتظار الطبيب'), findsNWidgets(2));
        expect(
          find.text('2 كشف + 3 استشارة = 105 ج.م'),
          findsOneWidget,
          reason: 'the footer totals',
        );
      },
    );

    testWidgets('D1 in English', (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/dashboard');
      expect(
        find.text('2 examinations + 3 consultations = EGP 105'),
        findsOneWidget,
      );
      expect(find.text('Compare'), findsOneWidget);
    });

    testWidgets('D2 filters by type', (tester) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/dashboard/today');
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<SessionType?>),
          matching: find.text('Examination'),
        ),
      );
      await settle(tester);
      expect(find.byType(DaySessionRow), findsNWidgets(2));
      expect(
        find.text('2 examinations + 0 consultations = EGP 60'),
        findsOneWidget,
      );
    });

    testWidgets('D3 shows the month with its branches and days', (
      tester,
    ) async {
      await start(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/dashboard/month');
      expect(find.text('Per branch'), findsOneWidget);
      expect(find.text('Maadi'), findsWidgets);
      expect(find.text('Nasr City'), findsWidgets);
    });

    testWidgets("AS1: a reception assistant's home, without the fee card", (
      tester,
    ) async {
      await start(tester, '01000000001');
      expect(find.text('Walk-in'), findsOneWidget);
      expect(find.byType(FeeCard), findsNothing);
    });

    testWidgets(
      "an office manager's dashboard has the fee cards (AS18, billingView)",
      (tester) async {
        await start(tester, '01000000005');
        await open(tester, '/assistant/dashboard');
        expect(find.byType(FeeCard), findsNWidgets(2));
      },
    );
  });
}
