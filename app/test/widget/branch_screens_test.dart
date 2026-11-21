import 'package:el3yada/core/widgets/navigation/app_back_button.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/core/platform/external_links.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/presentation/branches/branch_editor_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// D28 branches and D29 branch editor, through the offline clinic.
void main() {
  // Links "Open in Google Maps" opened; the opener answers [opens].
  late List<Uri> opened;
  var opens = true;
  setUp(() {
    opened = [];
    opens = true;
  });

  Future<void> doctor(
    WidgetTester tester, {
    void Function(FakeClinicAdminRepository fake)? configure,
    Size size = const Size(1400, 900),
  }) async {
    await pumpApp(
      tester,
      size: size,
      extra: [
        fakeClinicAdminOverride(configure: configure),
        externalLinkOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return opens;
        }),
      ],
    );
    await signIn(tester, 'doctor@el3yada.dev');
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  group('D28 branches', () {
    testWidgets(
      'shows each branch with its status, the default badge and the count',
      (tester) async {
        await doctor(tester);
        await open(tester, '/doctor/branches');

        expect(find.text('Maadi'), findsWidgets);
        expect(find.text('Nasr City'), findsWidgets);
        expect(find.text('Dokki'), findsOneWidget);
        expect(find.text('Default'), findsOneWidget);
        expect(find.text('Archived'), findsOneWidget);
        expect(find.text('2 of 5 branches'), findsOneWidget);
        expect(find.text('2 upcoming bookings'), findsOneWidget);
        final add = tester.widget<ButtonStyleButton>(
          find.widgetWithText(FilledButton, 'Add branch'),
        );
        expect(add.onPressed, isNotNull);
      },
    );

    testWidgets('the limit disables Add branch and says why', (tester) async {
      await doctor(tester, configure: (fake) => fake.branchLimit = 2);
      await open(tester, '/doctor/branches');

      expect(find.text('2 of 2 branches'), findsOneWidget);
      final add = tester.widget<ButtonStyleButton>(
        find.widgetWithText(FilledButton, 'Add branch'),
      );
      expect(add.onPressed, isNull);
      expect(
        find.text(
          "You've reached the most branches you can have. Archive one to add another.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a new branch is added, then opens on its working hours', (
      tester,
    ) async {
      await doctor(tester);
      await open(tester, '/doctor/branches/new');

      await tester.enterText(
        find.byKey(const ValueKey('info.nameAr')),
        'فرع الزمالك',
      );
      await tester.tap(find.text('Choose the governorate'));
      await settle(tester);
      await tester.tap(find.text('Cairo').last);
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('address.city')),
        'الزمالك',
      );
      await tester.enterText(
        find.byKey(const ValueKey('address.details')),
        '15 شارع 26 يوليو، الدور الرابع',
      );
      await tester.enterText(
        find.byKey(const ValueKey('contact.phones.0')),
        '01012345678',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add branch'));
      await settle(tester);

      expect(find.byType(BranchEditorScreen), findsOneWidget);
      expect(find.text('Copy Saturday to all days'), findsOneWidget);
      expect(clinicAdminFake(tester).calls['createBranch'], 1);
    });

    testWidgets('a new branch needs a name, an address and a phone', (
      tester,
    ) async {
      await doctor(tester);
      await open(tester, '/doctor/branches/new');

      await tester.tap(find.widgetWithText(FilledButton, 'Add branch'));
      await settle(tester);

      expect(
        find.text('Fix the highlighted fields, then save.'),
        findsOneWidget,
      );
      expect(find.text('Add at least one phone number.'), findsOneWidget);
      expect(clinicAdminFake(tester).calls['createBranch'], isNull);
    });
  });

  group('D29 branch editor', () {
    testWidgets('archiving the default branch shows the refusal', (
      tester,
    ) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/branches/${FakeClinicAdminRepository.maadiBranchId}',
      );

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Archive'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Archive'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await settle(tester);

      expect(find.text('Not possible yet'), findsOneWidget);
      expect(
        find.text(
          "The default branch can't be archived. Make another branch the default first.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('closing a branch with bookings lists them', (tester) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}',
      );

      await tester.ensureVisible(find.text('Close temporarily'));
      await tester.tap(find.text('Close temporarily'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('closedMessage')),
        'مغلق للتجديدات',
      );
      await tester.tap(find.text('Close the branch'));
      await settle(tester);

      expect(find.text('2 upcoming bookings'), findsOneWidget);
      expect(find.text('ضيف: كريم عادل (guest)'), findsOneWidget);
      expect(find.text('منى حسن'), findsOneWidget);
    });

    testWidgets(
      'closing a branch without bookings shows the message patients see',
      (tester) async {
        await doctor(tester, configure: (fake) => fake.bookings.clear());
        await open(
          tester,
          '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}',
        );

        await tester.ensureVisible(find.text('Close temporarily'));
        await tester.tap(find.text('Close temporarily'));
        await settle(tester);
        await tester.enterText(
          find.byKey(const ValueKey('closedMessage')),
          'مغلق للتجديدات',
        );
        await tester.tap(find.text('Close the branch'));
        await settle(tester);

        expect(find.text('Temporarily closed'), findsWidgets);
        expect(find.text('مغلق للتجديدات'), findsOneWidget);
        expect(find.text('Reopen'), findsOneWidget);
      },
    );

    testWidgets('leaving with unsaved changes asks first', (tester) async {
      await doctor(tester);
      await open(tester, '/doctor/branches');
      await tester.tap(find.text('Nasr City').first);
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey('info.nameAr')),
        'فرع مدينة نصر الجديد',
      );
      await tester.pump();
      expect(find.text('1 change not saved'), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byType(BranchEditorScreen), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await settle(tester);
      expect(find.byType(BranchEditorScreen), findsNothing);
    });

    testWidgets('saving the info tab sends only that group', (tester) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}',
      );

      await tester.enterText(
        find.byKey(const ValueKey('info.nameAr')),
        'فرع العباسية',
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(clinicAdminFake(tester).calls['updateBranch'], 1);
      expect(find.text('1 change not saved'), findsNothing);
      expect(find.text('فرع العباسية'), findsWidgets);
    });

    group('the address tab\'s Google Maps link', () {
      final mapField = find.byKey(const ValueKey('address.mapUrl'));
      final openButton = find.ancestor(
        of: find.text('Open in Google Maps'),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      );
      String linkText(WidgetTester tester) =>
          tester.widget<TextField>(mapField).controller!.text;

      Future<void> openAddressTab(WidgetTester tester) async {
        await doctor(tester);
        await open(
          tester,
          '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}?tab=address',
        );
        await tester.ensureVisible(mapField);
      }

      testWidgets(
        'a pasted share text keeps only the link, which opens and is saved',
        (tester) async {
          await openAddressTab(tester);
          expect(find.text('Detailed address'), findsOneWidget);

          await tester.enterText(
            mapField,
            'عيادة مدينة نصر\nhttps://maps.app.goo.gl/NasrCity42',
          );
          await tester.pump();
          expect(linkText(tester), 'https://maps.app.goo.gl/NasrCity42');

          await tester.ensureVisible(openButton);
          await tester.tap(openButton);
          await settle(tester);
          expect(opened, [Uri.parse('https://maps.app.goo.gl/NasrCity42')]);

          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await settle(tester);
          expect(clinicAdminFake(tester).calls['updateBranch'], 1);
          expect(linkText(tester), 'https://maps.app.goo.gl/NasrCity42');
          expect(find.text('1 change not saved'), findsNothing);
        },
      );

      testWidgets(
        'a link that is not Google Maps shows the error and is not sent',
        (tester) async {
          await openAddressTab(tester);

          await tester.enterText(
            mapField,
            'https://www.facebook.com/nasr.clinic',
          );
          await settle(tester);
          expect(
            tester.widget<ButtonStyleButton>(openButton).onPressed,
            isNull,
          );

          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await settle(tester);
          expect(find.text("That's not a Google Maps link."), findsOneWidget);
          expect(clinicAdminFake(tester).calls['updateBranch'], isNull);

          // The server's answer for the field lands on it too.
          clinicAdminFake(tester).failNext(
            'updateBranch',
            const ApiException(
              kind: ApiErrorKind.http,
              status: 400,
              code: ApiCodes.validationFailed,
              fieldCodes: {'address.mapUrl': 'INVALID_MAP_LINK'},
            ),
          );
          await tester.enterText(
            mapField,
            'https://maps.app.goo.gl/NasrCity42',
          );
          await settle(tester);
          expect(find.text("That's not a Google Maps link."), findsNothing);
          await tester.tap(find.widgetWithText(FilledButton, 'Save'));
          await settle(tester);
          expect(find.text("That's not a Google Maps link."), findsOneWidget);
        },
      );

      testWidgets('says so when Google Maps could not open', (tester) async {
        opens = false;
        await openAddressTab(tester);

        await tester.ensureVisible(openButton);
        await tester.tap(openButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(opened, [
          Uri.parse('https://maps.google.com/?q=30.0729,31.3456'),
        ]);
        expect(
          find.text("Couldn't open Google Maps on this device."),
          findsOneWidget,
        );
      });
    });

    testWidgets('the server'
        's errors show on their period', (tester) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/branches/${FakeClinicAdminRepository.maadiBranchId}?tab=hours',
      );

      clinicAdminFake(tester).failNext(
        'updateBranchHours',
        const ApiException(
          kind: ApiErrorKind.http,
          status: 400,
          code: ApiCodes.validationFailed,
          fieldCodes: {
            'periods[1]': 'PERIODS_OVERLAP',
            'periods[2].endLocal': 'PERIOD_LENGTH_OUT_OF_RANGE',
          },
        ),
      );
      // A third Saturday period (23:00, ending the next day), then Save.
      await tester.tap(find.widgetWithText(TextButton, 'Add period').first);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(find.text('The periods overlap.'), findsOneWidget);
      expect(
        find.text('A period lasts from 15 minutes to 16 hours.'),
        findsOneWidget,
      );
      expect(
        find.text('Fix the highlighted fields, then save.'),
        findsOneWidget,
      );
    });

    testWidgets('a new period after the last one is saved with the week', (
      tester,
    ) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/branches/${FakeClinicAdminRepository.maadiBranchId}?tab=hours',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Add period').first);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      final saturday = clinicAdminFake(
        tester,
      ).lastHours!.where((p) => p.weekday == DateTime.saturday).toList();
      expect(saturday, hasLength(3));
      expect(
        (
          saturday.last.startLocal,
          saturday.last.endLocal,
          saturday.last.endsNextDay,
        ),
        ('23:00', '03:00', true),
      );
    });

    testWidgets('copy Saturday to all days fills every day', (tester) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}?tab=hours',
      );

      await tester.tap(find.text('Copy Saturday to all days'));
      await settle(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Copy Saturday to all days'),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      final hours = clinicAdminFake(tester).lastHours!;
      expect(hours, hasLength(7));
      expect(hours.map((p) => p.startLocal).toSet(), {'17:00'});
    });
  });
}
