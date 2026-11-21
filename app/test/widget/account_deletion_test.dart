import 'dart:convert';

import 'package:el3yada/app/app.dart';
import 'package:el3yada/app/router.dart';
import 'package:el3yada/core/notifications/local_notifier.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/realtime/realtime_service.dart';
import 'package:el3yada/features/account_deletion/data/account_deletion_repository.dart';
import 'package:el3yada/features/account_deletion/data/fake_account_deletion_repository.dart';
import 'package:el3yada/features/account_deletion/domain/account_deletion_models.dart';
import 'package:el3yada/features/account_deletion/presentation/account_deletion_text.dart';
import 'package:el3yada/features/account_deletion/presentation/restore_account_screen.dart';
import 'package:el3yada/features/admin_support/data/admin_support_repository.dart';
import 'package:el3yada/features/auth/application/auth_controller.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/billing/data/billing_repository.dart';
import 'package:el3yada/features/billing/data/fake_billing_repository.dart';
import 'package:el3yada/features/patient/data/fake_patient_repository.dart';
import 'package:el3yada/features/patient/data/patient_repository.dart';
import 'package:el3yada/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart' show settle;
import '../support/app_overrides.dart';
import '../support/clinic_records_support.dart';

/// Account deletion (spec 6.17, backend/docs/api-account-deletion.md): the
/// flow from each role's settings, the restore screen (A16), AD12 with its
/// filters and Cancel and restore, AD11's Delete account, the D6 banner and
/// the «… محذوف» names.
const _phone = Size(400, 1400);
const _desktop = Size(1400, 1000);

Future<void> _pump(WidgetTester tester, {AppPlatform platform = AppPlatform.mobile, Size size = _phone}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await appOverrides(platform: platform),
        accountDeletionRepositoryProvider.overrideWith(
          (ref) => FakeAccountDeletionRepository(ref.watch(authRepositoryProvider) as FakeAuthRepository, delay: Duration.zero),
        ),
        patientRepositoryProvider.overrideWithValue(FakePatientRepository(delay: Duration.zero)),
        billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
        adminSupportRepositoryProvider.overrideWithValue(FakeAdminSupportRepository()),
        fakeAdminOverride(),
        fakeRecordsOverride(),
        realtimeServiceProvider.overrideWithValue(FakeRealtimeService()),
        localNotifierProvider.overrideWithValue(SilentLocalNotifier()),
      ],
      child: const El3yadaApp(),
    ),
  );
  await settle(tester);
}

Future<void> _signIn(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byType(TextFormField).at(0), identifier);
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.byType(FilledButton).first);
  await settle(tester);
  if (find.byType(CheckboxListTile).evaluate().isNotEmpty) {
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await settle(tester);
  }
}

Future<void> _openDeleteFlow(WidgetTester tester) async {
  final keyed = find.byKey(const Key('deleteAccountTile'));
  final tile = keyed.evaluate().isNotEmpty ? keyed : find.text('Delete account').first;
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await settle(tester);
}

Future<void> _confirm(WidgetTester tester, String password) async {
  final field = find.widgetWithText(TextFormField, 'Current password');
  await tester.ensureVisible(field);
  await tester.enterText(field, password);
  final button = find.byKey(const Key('confirmAccountDeletion'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await settle(tester);
}

void main() {
  testWidgets('P14: a patient checks the password, deletes, signs out, and restores from A16', (tester) async {
    await _pump(tester);
    await _signIn(tester, '01000000002');
    await tester.tap(find.byTooltip('Account'));
    await settle(tester);

    await _openDeleteFlow(tester);
    expect(find.text('Delete your account'), findsOneWidget);
    expect(find.textContaining('Your upcoming appointments are cancelled'), findsOneWidget);
    expect(find.textContaining('under "Deleted patient"'), findsOneWidget);
    expect(find.textContaining('For 30 days, until'), findsOneWidget);
    // The danger style: the confirm button uses the theme's error colours.
    final button = tester.widget<FilledButton>(find.byKey(const Key('confirmAccountDeletion')));
    final scheme = Theme.of(tester.element(find.byKey(const Key('confirmAccountDeletion')))).colorScheme;
    expect(button.style?.backgroundColor?.resolve({}), scheme.error);

    await _confirm(tester, 'wrong');
    expect(find.text('The current password is wrong.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'مش محتاج التطبيق');
    await _confirm(tester, 'dev');
    expect(find.text('Your account is closed'), findsOneWidget);
    expect(find.textContaining('It will be permanently deleted on'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    // Signing in again opens only A16.
    await _signIn(tester, '01000000002');
    expect(find.byType(RestoreAccountScreen), findsOneWidget);
    expect(find.text('Your account is being deleted'), findsOneWidget);
    expect(find.text('Appointments cancelled when the deletion started stay cancelled.'), findsOneWidget);
    expect(find.text('Reason: مش محتاج التطبيق'), findsOneWidget);
    expect(find.byKey(const Key('restoreInvoices')), findsNothing);

    await tester.tap(find.text('Restore my account'));
    await settle(tester);
    expect(find.byType(RestoreAccountScreen), findsNothing);
    expect(find.byTooltip('Account'), findsOneWidget);
    expect(appContainer(tester).read(authControllerProvider).value!.isPendingDeletion, isFalse);
  });

  testWidgets('A16: the offline account in its grace period sees the date, its invoices with Pay, and Sign out', (tester) async {
    await _pump(tester, platform: AppPlatform.desktop, size: _desktop);
    await _signIn(tester, 'deleting@el3yada.dev');

    expect(find.byType(RestoreAccountScreen), findsOneWidget);
    expect(find.textContaining('Your account will be permanently deleted on'), findsOneWidget);
    expect(find.text('Invoices to pay'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsWidgets);
    expect(find.text('Restore my account'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    // Other areas send it back here.
    goTo(tester, '/doctor/patients');
    await settle(tester);
    expect(find.byType(RestoreAccountScreen), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await settle(tester);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('A16 fits a phone, and restoring opens the doctor home', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    await _signIn(tester, 'deleting@el3yada.dev');
    expect(find.byType(RestoreAccountScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Restore my account'));
    await tester.tap(find.text('Restore my account'));
    await settle(tester);
    expect(find.byType(RestoreAccountScreen), findsNothing);
    expect(appContainer(tester).read(authControllerProvider).value!.accountStatus, 'active');
  });

  testWidgets('D24: a doctor sees the final invoice first; one who owes an invoice is refused with a link to D18', (tester) async {
    await _pump(tester, platform: AppPlatform.desktop, size: _desktop);
    await _signIn(tester, 'doctor@el3yada.dev');
    goTo(tester, '/doctor/settings');
    await settle(tester);

    await _openDeleteFlow(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('A final invoice of EGP 45 will be issued, and it must be paid before the final deletion.'), findsOneWidget);
    expect(find.textContaining('Your clinic stops'), findsOneWidget);
    expect(find.textContaining('the final deletion waits until every invoice is paid'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Cancel'));
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester);
    expect(find.byType(Dialog), findsNothing);
    await appContainer(tester).read(authControllerProvider.notifier).logout();
    await settle(tester);

    await _signIn(tester, 'suspended@el3yada.dev');
    goTo(tester, '/doctor/settings');
    await settle(tester);
    await _openDeleteFlow(tester);
    expect(find.text('Pay your outstanding invoices first'), findsOneWidget);
    expect(find.byKey(const Key('confirmAccountDeletion')), findsNothing);
    await tester.ensureVisible(find.text('Open invoices'));
    await tester.tap(find.text('Open invoices'));
    await settle(tester);
    expect(appContainer(tester).read(routerProvider).routerDelegate.currentConfiguration.uri.path, '/doctor/billing');
  });

  testWidgets('AS12: an assistant deletes; the doctor-side explanation is theirs', (tester) async {
    await _pump(tester);
    await _signIn(tester, '01000000001');
    goTo(tester, '/assistant/settings');
    await settle(tester);

    await _openDeleteFlow(tester);
    expect(find.text("You leave the clinic's assistants, and the doctor is told."), findsOneWidget);
    expect(find.textContaining('A final invoice'), findsNothing);
    await _confirm(tester, 'dev');
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await settle(tester);

    await _signIn(tester, '01000000001');
    expect(find.byType(RestoreAccountScreen), findsOneWidget);
  });

  testWidgets('AD18: the last active super admin is refused', (tester) async {
    await _pump(tester, platform: AppPlatform.desktop, size: _desktop);
    await _signIn(tester, 'admin@el3yada.dev');
    goTo(tester, '/admin/settings/profile');
    await settle(tester);

    await _openDeleteFlow(tester);
    expect(find.text('There must always be at least one active super admin.'), findsOneWidget);
    expect(find.byKey(const Key('confirmAccountDeletion')), findsNothing);
  });

  testWidgets('AD12: every deletion with role and status filters; Cancel and restore needs a reason', (tester) async {
    await _pump(tester, platform: AppPlatform.desktop, size: _desktop);
    await _signIn(tester, 'admin@el3yada.dev');
    await tester.tap(find.text('Account deletions'));
    await settle(tester);

    expect(find.text('د. هشام فؤاد'), findsOneWidget);
    expect(find.text('خالد يوسف'), findsOneWidget);
    expect(find.text('ريم صلاح'), findsOneWidget);
    // The erased patient reads in the app's language.
    expect(find.text('Deleted patient'), findsOneWidget);
    expect(find.textContaining('Owes EGP 45'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Doctor'));
    await settle(tester);
    expect(find.text('د. هشام فؤاد'), findsOneWidget);
    expect(find.text('خالد يوسف'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All').first);
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Restored'));
    await settle(tester);
    expect(find.text('ريم صلاح'), findsOneWidget);
    expect(find.text('خالد يوسف'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All').last);
    await settle(tester);

    final card = find.ancestor(of: find.text('خالد يوسف'), matching: find.byType(Card));
    await tester.tap(find.descendant(of: card, matching: find.widgetWithText(OutlinedButton, 'Cancel and restore')));
    await settle(tester);
    final confirm = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Cancel and restore'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'المريض غيّر رأيه');
    await tester.pump();
    await tester.tap(confirm);
    await settle(tester);

    final restored = find.ancestor(of: find.text('خالد يوسف'), matching: find.byType(Card));
    expect(find.descendant(of: restored, matching: find.text('Restored')), findsOneWidget);
    expect(find.descendant(of: restored, matching: find.text('Restore reason: المريض غيّر رأيه')), findsOneWidget);
  });

  testWidgets('AD11: Delete account starts a deletion with a reason, then offers Cancel and restore', (tester) async {
    await _pump(tester, platform: AppPlatform.desktop, size: _desktop);
    await _signIn(tester, 'admin@el3yada.dev');
    await tester.tap(find.text('Accounts'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '01000000002');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);

    await tester.tap(find.byKey(const Key('adminDeleteAccount-u-pat')));
    await settle(tester);
    expect(find.text('Delete محمد إبراهيم\'s account?'), findsOneWidget);
    final start = find.widgetWithText(FilledButton, 'Start deletion');
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'طلب بالتليفون');
    await tester.pump();
    await tester.tap(start);
    await settle(tester);

    expect(find.text('The deletion started'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cancel and restore'), findsOneWidget);
  });

  testWidgets('D6: a patient in the grace period shows the banner; an erased one reads «Deleted patient»', (tester) async {
    await _pump(tester, platform: AppPlatform.desktop, size: _desktop);
    await _signIn(tester, 'doctor@el3yada.dev');
    final records = recordsOf(tester);
    final mona = records.patientIdOf(SeedPatients.mona);
    final laila = records.patientIdOf(SeedPatients.laila);
    records
      ..setAccountStatus(SeedPatients.mona, 'pendingDeletion')
      ..setAccountStatus(SeedPatients.laila, 'deleted');

    goTo(tester, '/doctor/patients/$mona');
    await settle(tester);
    expect(find.byKey(const Key('patientPendingDeletionBanner')), findsOneWidget);
    expect(find.text("This patient's account is scheduled for deletion"), findsOneWidget);

    goTo(tester, '/doctor/patients/$laila');
    await settle(tester);
    expect(find.text('Deleted patient'), findsWidgets);
    expect(find.byKey(const Key('patientPendingDeletionBanner')), findsNothing);
    // No number to call: the phone row is gone.
    expect(find.byTooltip('Call'), findsNothing);
  });

  test('the «… محذوف» names read in the current language, other names unchanged', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(en.personName(DeletedNames.patient), 'Deleted patient');
    expect(en.personName(DeletedNames.doctor), 'Deleted doctor');
    expect(en.personName(DeletedNames.doctorEn), 'Deleted doctor');
    expect(en.personName(DeletedNames.assistant), 'Deleted assistant');
    expect(en.personName(DeletedNames.admin), 'Deleted admin');
    expect(ar.personName(DeletedNames.patient), 'مريض محذوف');
    expect(ar.personName(DeletedNames.doctorEn), 'طبيب محذوف');
    expect(en.personName('منى حسن'), 'منى حسن');
  });

  test('the API state and AD12 rows parse as the contract shows them', () {
    final state = AccountDeletionState.fromJson({
      'role': 'doctor', 'graceDays': 30, 'scheduledForIfNow': '2026-12-21T10:04:00.000Z', 'pending': null,
      'unpaidInvoices': [
        {'id': 'i', 'monthKey': '2026-10', 'totalDuePiasters': 18000, 'status': 'overdue', 'dueDate': '2026-11-07'},
      ],
      'finalInvoice': null, 'refusal': 'UNPAID_INVOICES',
    });
    expect(state.refusal, DeletionRefusal.unpaidInvoices);
    expect(state.canRequest, isFalse);
    expect(state.unpaidInvoices.single.month, DateTime.utc(2026, 10));

    final item = AccountDeletionItem.fromJson({
      'id': 'd', 'userId': 'u', 'role': 'patient', 'displayName': 'مريض محذوف', 'phone': null, 'email': null,
      'status': 'waitingPayment', 'reason': null, 'requestedAt': '2026-11-21T10:00:00.000Z', 'requestedByAdmin': true,
      'requestedByName': 'Admin', 'scheduledFor': '2026-12-21T10:00:00.000Z', 'restoredAt': null, 'restoredByName': null,
      'restoreReason': null, 'completedAt': null, 'patientId': 'p', 'doctorId': null, 'assistantId': null,
      'unpaidInvoices': 0, 'outstandingPiasters': 0,
    });
    expect(item.status, DeletionStatus.waitingPayment);
    expect(item.status.open, isTrue);
    expect(DeletedNames.isDeleted(item.displayName), isTrue);
  });

  test('a session in the grace period carries pendingDeletion', () {
    final store = FakeDeletionStore();
    final session = store.apply(
      'deleting@el3yada.dev',
      FakeAuthRepository.accounts['deleting@el3yada.dev']!.session('deleting@el3yada.dev'),
    );
    expect(session.isPendingDeletion, isTrue);
    expect(session.accountStatus, 'pendingDeletion');
    expect(session.pendingDeletion!.waitsForPayment, isTrue);
    final json = jsonDecode(jsonEncode(session.toJson())) as Map<String, dynamic>;
    expect((json['pendingDeletion'] as Map)['status'], 'scheduled');
    expect(AuthSession.fromJson(json).pendingDeletion, session.pendingDeletion);
  });

  test('AppLocalizations has every new string in both languages', () {
    for (final l10n in [lookupAppLocalizations(const Locale('en')), lookupAppLocalizations(const Locale('ar'))]) {
      expect(l10n.navAccountDeletions, isNotEmpty);
      expect(l10n.accountDeletionStepGrace(7, 'x'), contains('x'));
      expect(l10n.adminDeletionOwed('EGP 45', 2), isNotEmpty);
    }
  });
}
