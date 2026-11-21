import 'package:el3yada/core/widgets/navigation/app_back_button.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/presentation/prices/visit_prices_screen.dart';
import 'package:el3yada/features/clinic_admin/presentation/profile/doctor_profile_screen.dart';
import 'package:el3yada/features/clinic_admin/presentation/settings/clinic_settings_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// D24 and AS12 settings, D22 profile, D37 / AS19 visit prices.
void main() {
  Future<void> signedIn(
    WidgetTester tester,
    String account, {
    void Function(FakeClinicAdminRepository fake)? configure,
  }) async {
    await pumpApp(
      tester,
      extra: [fakeClinicAdminOverride(configure: configure)],
    );
    await signIn(tester, account);
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  bool switchValue(WidgetTester tester, String title) => tester
      .widget<Switch>(
        find.descendant(
          of: find
              .ancestor(of: find.text(title), matching: find.byType(Row))
              .first,
          matching: find.byType(Switch),
        ),
      )
      .value;

  group('D24 doctor settings', () {
    testWidgets(
      'shows the profile ticket, prices, preferences and notifications',
      (tester) async {
        await signedIn(tester, 'doctor@el3yada.dev');
        await open(tester, '/doctor/settings');

        expect(find.byType(ClinicSettingsScreen), findsOneWidget);
        expect(find.text('Dr. تجريبي'), findsOneWidget);
        expect(find.text('Visit prices'), findsWidgets);
        expect(find.text('Chat messages'), findsOneWidget);
        expect(find.text('Bookings'), findsOneWidget);
        expect(find.text('Show message text in notifications'), findsOneWidget);
        expect(find.text('Version 1.0.0'), findsOneWidget);
      },
    );

    testWidgets(
      'a notification switch saves at once, off by default for the message text',
      (tester) async {
        await signedIn(tester, 'doctor@el3yada.dev');
        await open(tester, '/doctor/settings');

        expect(
          switchValue(tester, 'Show message text in notifications'),
          isFalse,
        );
        await tester.ensureVisible(
          find.text('Show message text in notifications'),
        );
        await tester.tap(find.text('Show message text in notifications'));
        await settle(tester);

        expect(
          switchValue(tester, 'Show message text in notifications'),
          isTrue,
        );
        expect(clinicAdminFake(tester).calls['updateNotificationPrefs'], 1);
      },
    );

    testWidgets('a failed save puts the switch back and says why', (
      tester,
    ) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings');

      clinicAdminFake(tester).failNext(
        'updateNotificationPrefs',
        const ApiException(kind: ApiErrorKind.network),
      );
      await tester.ensureVisible(find.text('Chat messages'));
      await tester.tap(find.text('Chat messages'));
      await settle(tester);

      expect(switchValue(tester, 'Chat messages'), isTrue);
      expect(find.text('No internet connection'), findsOneWidget);
    });

    testWidgets(
      'change password opens in a dialog and checks the current one',
      (tester) async {
        await signedIn(tester, 'doctor@el3yada.dev');
        await open(tester, '/doctor/settings');

        await tester.ensureVisible(find.text('Change password').first);
        await tester.tap(find.text('Change password').first);
        await settle(tester);
        await tester.enterText(find.byType(TextFormField).at(0), 'wrong');
        await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
        await tester.enterText(find.byType(TextFormField).at(2), 'newpass123');
        await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
        await settle(tester);

        expect(find.text('The current password is wrong.'), findsOneWidget);
      },
    );

    testWidgets('the top bar profile button opens D22', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');

      await tester.tap(find.byTooltip('My profile'));
      await settle(tester);

      expect(find.byType(DoctorProfileScreen), findsOneWidget);
      expect(find.text('doctor@el3yada.dev'), findsOneWidget);
      expect(find.text('45678'), findsOneWidget);
    });
  });

  group('D22 profile', () {
    testWidgets(
      'saves the name, and a specialty change says the admin was told',
      (tester) async {
        await signedIn(tester, 'doctor@el3yada.dev');
        await open(tester, '/doctor/settings/profile');

        await tester.enterText(find.byType(TextFormField).first, 'أحمد تجريبي');
        await settle(tester);
        expect(find.text('1 change not saved'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        expect(find.text('Profile saved'), findsOneWidget);

        await tester.ensureVisible(find.text('Add a specialty'));
        await tester.tap(find.text('Add a specialty'));
        await settle(tester);
        await tester.tap(find.text('Cardiology'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        expect(
          find.text(
            'Profile saved. Your new specialty applies now, and the admin team was told.',
          ),
          findsOneWidget,
        );
        expect(clinicAdminFake(tester).calls['updateDoctorProfile'], 2);
      },
    );

    testWidgets('a one-word name is refused next to the field', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings/profile');

      await tester.enterText(find.byType(TextFormField).first, 'أحمد');
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(
        find.text('Write at least a first and a last name, in letters only.'),
        findsOneWidget,
      );
      expect(clinicAdminFake(tester).calls['updateDoctorProfile'], isNull);
    });

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings');
      await tester.tap(find.text('Profile'));
      await settle(tester);

      await tester.enterText(find.byType(TextFormField).first, 'أحمد تجريبي');
      await settle(tester);
      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await settle(tester);
      expect(find.byType(DoctorProfileScreen), findsNothing);
      expect(find.byType(ClinicSettingsScreen), findsOneWidget);
    });
  });

  group('D37 visit prices', () {
    testWidgets('the doctor changes a price and the history shows old → new', (
      tester,
    ) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings/prices');

      expect(
        find.text('New prices apply to future visits only.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('doctor-examination')),
        '350.5',
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save').first);
      await settle(tester);

      expect(find.text('Examination: EGP 300 → EGP 350.50'), findsOneWidget);
      expect(clinicAdminFake(tester).calls['updatePrices'], 1);
    });

    testWidgets('an amount with three decimals is refused before sending', (
      tester,
    ) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings/prices');

      await tester.enterText(
        find.byKey(const ValueKey('doctor-consultation')),
        '1.234',
      );
      await settle(tester);

      expect(
        find.text(
          'Enter an amount from 0 to 100,000, with at most 2 decimals.',
        ),
        findsOneWidget,
      );
    });

    testWidgets("an empty doctor price explains what patients see", (
      tester,
    ) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings/prices');

      await tester.enterText(
        find.byKey(const ValueKey('doctor-consultation')),
        '',
      );
      await settle(tester);

      expect(
        find.text(
          'Empty: patients see «Ask the clinic», and the amount is typed at each visit.',
        ),
        findsOneWidget,
      );
    });

    testWidgets("a branch goes back to the doctor's prices", (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      await open(tester, '/doctor/settings/prices');

      final toggle = find.byKey(
        const ValueKey('${FakeClinicAdminRepository.nasrCityBranchId}-doctor'),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save').first);
      await settle(tester);

      final history = find.text('Examination: EGP 400 → not set');
      await tester.scrollUntilVisible(
        history,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(history, findsOneWidget);
    });
  });

  group('AS12 assistant settings', () {
    testWidgets(
      'a reception assistant reads their permissions and branches, and has no Visit prices',
      (tester) async {
        await signedIn(tester, '01000000001');
        await open(tester, '/assistant/settings');

        expect(find.text('My permissions'), findsOneWidget);
        expect(find.text('Manage patients'), findsOneWidget);
        expect(find.text('Manage visit prices'), findsNothing);
        expect(find.text('My branches'), findsOneWidget);
        expect(find.text('Maadi'), findsWidgets);
        expect(find.text('Visit prices'), findsNothing);
        expect(find.text('Bookings'), findsNothing);
      },
    );

    testWidgets("a reception assistant can't open Visit prices by address", (
      tester,
    ) async {
      await signedIn(tester, '01000000001');
      await open(tester, '/assistant/settings/prices');

      expect(find.byType(VisitPricesScreen), findsNothing);
      expect(find.byType(ClinicSettingsScreen), findsOneWidget);
      expect(clinicAdminFake(tester).calls['prices'], isNull);
    });

    testWidgets('an office manager edits prices only for their branches', (
      tester,
    ) async {
      await signedIn(
        tester,
        '01000000005',
        configure: (fake) => fake.setAssistantBranches(
          FakeClinicAdminRepository.officeManagerUserId,
          allBranches: false,
          branchIds: {FakeClinicAdminRepository.maadiBranchId},
        ),
      );
      await open(tester, '/assistant/settings');
      await tester.tap(find.text('Visit prices'));
      await settle(tester);

      expect(find.byType(VisitPricesScreen), findsOneWidget);
      final nasr = find.byKey(
        const ValueKey(
          '${FakeClinicAdminRepository.nasrCityBranchId}-examination',
        ),
      );
      await tester.ensureVisible(nasr);
      expect(tester.widget<TextField>(nasr).enabled, isFalse);
      expect(
        find.text(
          "Only the doctor or this branch's assistants can change these prices.",
        ),
        findsOneWidget,
      );

      final maadi = find.byKey(
        const ValueKey('${FakeClinicAdminRepository.maadiBranchId}-doctor'),
      );
      await tester.ensureVisible(maadi);
      await tester.tap(maadi);
      await settle(tester);
      await tester.enterText(
        find.byKey(
          const ValueKey(
            '${FakeClinicAdminRepository.maadiBranchId}-examination',
          ),
        ),
        '320',
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save').first);
      await settle(tester);
      expect(clinicAdminFake(tester).calls['updatePrices'], 1);
      expect(
        find.text('Prices saved. They apply to visits from now on.'),
        findsOneWidget,
      );
    });
  });
}
