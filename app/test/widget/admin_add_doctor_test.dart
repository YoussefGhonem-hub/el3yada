import 'dart:typed_data';

import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin/application/admin_controllers.dart';
import 'package:el3yada/features/admin/data/fake_admin_repository.dart';
import 'package:el3yada/features/admin/domain/admin_models.dart';
import 'package:el3yada/features/admin/presentation/signups/doctor_filter_bar.dart';
import 'package:el3yada/features/doctor_registration/data/license_picker.dart';
import 'package:el3yada/features/doctor_registration/data/registration_repository.dart';
import 'package:el3yada/features/doctor_registration/presentation/widgets/search_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';

const _desktop = Size(1400, 900);
const _phone = Size(400, 860);

/// A 1×1 PNG, enough for the license field.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, 0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, //
  0x1F, 0x15, 0xC4, 0x89, 0, 0, 0, 10, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0, 1, 0, 0, 5, 0, 1, 0x0D, 0x0A, 0x2D, 0xB4, //
  0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class _Picker implements LicensePicker {
  @override
  Future<PickedLicense?> pick(LicenseSource source) async =>
      PickedLicense(name: 'card.png', size: _png.length, read: () async => _png);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _signedInAdmin(
  WidgetTester tester, {
  Size size = _desktop,
  void Function(FakeAdminRepository fake)? configure,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: await appOverrides(
        platform: size.width >= 1024 ? AppPlatform.desktop : AppPlatform.mobile,
        extra: [
          fakeAdminOverride(configure: configure),
          registrationRepositoryProvider.overrideWithValue(FakeRegistrationRepository(delay: Duration.zero)),
          licensePickerProvider.overrideWithValue(_Picker()),
        ],
      ),
      child: const El3yadaApp(),
    ),
  );
  await _settle(tester);
  await tester.enterText(find.byType(TextFormField).at(0), 'admin@el3yada.dev');
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await _settle(tester);
}

Future<void> _open(WidgetTester tester, String path) async {
  goTo(tester, path);
  await _settle(tester);
}

Finder _inFilters(String text) => find.descendant(of: find.byType(DoctorFilterBar), matching: find.text(text));

Finder _inSheet(String text) => find.descendant(of: find.byType(ListTile), matching: find.text(text));

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await _settle(tester);
}

Future<void> _openPicker(WidgetTester tester, String label) async {
  final picker = find.widgetWithText(PickerField, label);
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await _settle(tester);
}

/// The three A4 steps, as an admin fills them.
Future<void> _fillDoctor(WidgetTester tester, {String email = 'hala@example.com'}) async {
  await _enter(tester, 'Full name', 'Hala Mahmoud');
  await _enter(tester, 'Email', email);
  await _enter(tester, 'Mobile number', '010 2345 6789');
  await _tapText(tester, 'Next');
  await _tapText(tester, 'Consultant');
  await _openPicker(tester, 'Primary specialty');
  await _tapText(tester, 'Cardiology');
  await _enter(tester, 'Syndicate number', '77889');
  await _tapText(tester, 'Syndicate card or license');
  final photo = find.text('Take a photo');
  if (photo.evaluate().isNotEmpty) await _tapText(tester, 'Take a photo');
  await _tapText(tester, 'Next');
  await _enter(tester, 'Branch name', 'Dokki branch');
  await _openPicker(tester, 'Governorate');
  await _tapText(tester, 'Giza');
  await _enter(tester, 'City or area', 'Dokki');
  await _enter(tester, 'Detailed address', '5 Tahrir Street');
  await _enter(tester, 'Number 1', '01012345678');
  await _tapText(tester, 'Next');
}

void main() {
  group('AD6 add doctor', () {
    testWidgets(
      'phone, from AD2: the A4 steps without a password; the doctor is active with no trial and gets the email',
      (tester) async {
        await _signedInAdmin(tester, size: _phone);
        await _open(tester, '/admin/signups');

        await tester.tap(find.byTooltip('Add doctor'));
        await _settle(tester);
        expect(find.text('Step 1 of 4'), findsOneWidget);
        expect(_field('Password'), findsNothing, reason: 'the doctor chooses it from the email');
        expect(find.text("The doctor signs in with this email. We'll send a link to it for choosing a password."), findsOneWidget);

        // Next checks the step, as in A4.
        await _tapText(tester, 'Next');
        expect(find.text('Step 1 of 4'), findsOneWidget);
        expect(find.text('Check the highlighted fields.'), findsOneWidget);

        // The doctor reads emails in English.
        await tester.ensureVisible(find.text('English'));
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        await _fillDoctor(tester);

        expect(find.text('Check the details, then add the doctor. Their clinic opens right away.'), findsOneWidget);
        expect(find.textContaining('I accept'), findsNothing, reason: 'no Terms checkbox for the admin');
        await tester.tap(find.widgetWithText(FilledButton, 'Add doctor'));
        await _settle(tester);

        expect(find.text('Dr. Hala Mahmoud is added'), findsOneWidget);
        expect(find.textContaining('hala@example.com'), findsWidgets);
        final fake = adminFake(tester);
        expect(fake.invitesSent, ['hala@example.com']);
        await tester.tap(find.text("Open the doctor's page"));
        await _settle(tester);

        // AD3 opens on the new doctor: active, service on, nothing to approve.
        expect(find.text('Doctor account'), findsOneWidget);
        expect(find.text('Service active'), findsWidgets);
        expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
        final created = (await fake.doctorRegistrations(search: 'hala')).items.single;
        expect(created.status, DoctorStatuses.active);
        expect(created.trial, isNull);
        final detail = await fake.doctorRegistration(created.doctorId);
        expect(detail.registration.locale, 'en');
        expect(detail.registration.specialty.nameEn, 'Cardiology');
        expect(detail.registration.branch?.governorate, 'الجيزة');
        final audit = await fake.auditLogs(const AuditFilter());
        expect(audit.items.map((e) => e.action), contains('doctorCreated'));
      },
    );

    testWidgets('an email in use takes the admin back to it, marked', (tester) async {
      await _signedInAdmin(tester, size: _phone);
      await _open(tester, '/admin/signups/new');

      await _fillDoctor(tester, email: FakeRegistrationRepository.takenEmail);
      await tester.tap(find.widgetWithText(FilledButton, 'Add doctor'));
      await _settle(tester);

      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('An account with this email already exists.'), findsOneWidget);
      expect(adminFake(tester).invitesSent, isEmpty);
    });

    testWidgets('desktop, from AD4: the button opens it, and Back returns to the list', (tester) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/doctors');

      await tester.tap(find.widgetWithText(FilledButton, 'Add doctor'));
      await _settle(tester);
      expect(find.text('The account is active at once, with no free trial. The doctor gets an email to choose a password.'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);

      await tester.tap(find.byTooltip('Back').first);
      await _settle(tester);
      expect(find.text('Step 1 of 4'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Add doctor'), findsOneWidget);
    });
  });

  group('AD2 filters and badge', () {
    testWidgets('specialty, governorate and dates narrow the list, and Clear filters resets them', (tester) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/signups');
      expect(find.text('8 doctors'), findsOneWidget);
      final fake = adminFake(tester);

      // The Filters button by the search opens the three filters.
      await tester.tap(find.byTooltip('Filters'));
      await _settle(tester);
      await tester.tap(_inSheet('Specialty'));
      await _settle(tester);
      await tester.tap(find.text('Pediatrics').last);
      await _settle(tester);
      expect(fake.lastRegistrationFilters['specialtyId'], 'sp-pediatrics');
      expect(_inSheet('Pediatrics'), findsOneWidget, reason: 'the sheet shows the choice');
      await tester.tap(_inSheet('Governorate'));
      await _settle(tester);
      await tester.tap(find.text('Alexandria').last);
      await _settle(tester);
      expect(fake.lastRegistrationFilters['governorate'], 'الإسكندرية');
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await _settle(tester);

      // The list behind followed; the set filters show as pills.
      expect(find.byTooltip('Filters, 2 set'), findsOneWidget);
      expect(_inFilters('Pediatrics'), findsOneWidget);
      expect(_inFilters('Alexandria'), findsOneWidget);
      expect(find.text('No doctors match your search'), findsOneWidget);
      expect(find.text('No doctor matches these filters. Clear one to see more.'), findsOneWidget);

      // Clearing the governorate brings back the pediatricians.
      await tester.ensureVisible(find.descendant(of: find.byType(DoctorFilterBar), matching: find.byTooltip('Clear')).last);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DoctorFilterBar), matching: find.byTooltip('Clear')).last);
      await _settle(tester);
      expect(fake.lastRegistrationFilters['governorate'], isNull);
      final pediatrics = (await fake.doctorRegistrations(specialtyId: 'sp-pediatrics')).totalCount;
      expect(find.text(pediatrics == 1 ? '1 doctor' : '$pediatrics doctors'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Clear filters'));
      await _settle(tester);
      expect(fake.lastRegistrationFilters.values.every((v) => v == null), isTrue);
      expect(find.text('8 doctors'), findsOneWidget);
      expect(find.byType(DoctorFilterBar), findsNothing);

      // The dates open the range picker.
      await tester.tap(find.byTooltip('Filters'));
      await _settle(tester);
      await tester.tap(_inSheet('Sign-up date'));
      await _settle(tester);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });

    testWidgets('the menu counts the legacy sign-ups waiting for review, and a review updates it', (tester) async {
      final handle = tester.ensureSemantics();
      await _signedInAdmin(tester);
      await _open(tester, '/admin/signups');
      final pending = await adminFake(tester).pendingSignupsCount();
      expect(pending, greaterThan(1));

      expect(find.semantics.byLabel('Doctors, $pending waiting for review'), findsOne);
      expect(find.text('$pending'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Approve')));
      await _settle(tester);
      expect(find.text('${pending - 1}'), findsOneWidget);
      expect(find.semantics.byLabel('Doctors, ${pending - 1} waiting for review'), findsOne);
      handle.dispose();
    });

    testWidgets('no badge when nothing waits', (tester) async {
      await _signedInAdmin(tester);
      final fake = adminFake(tester);
      for (final row in (await fake.doctorRegistrations(status: DoctorStatuses.pendingApproval)).items) {
        await fake.reviewDoctorRegistration(doctorId: row.doctorId, decision: ReviewDecision.approve);
      }
      appContainer(tester).invalidate(pendingSignupsProvider);
      await _open(tester, '/admin/dashboard');
      expect(await fake.pendingSignupsCount(), 0);
      expect(find.bySemanticsLabel(RegExp('waiting for review')), findsNothing);
    });
  });
}
