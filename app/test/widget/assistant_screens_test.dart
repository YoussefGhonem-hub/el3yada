import 'package:el3yada/core/widgets/navigation/app_back_button.dart';
import 'package:el3yada/core/widgets/pressable.dart';
import 'package:el3yada/core/widgets/temporary_password_dialog.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/presentation/assistants/assistant_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// D25 assistants and D26 add / edit assistant, through the offline clinic.
void main() {
  const phone = Size(420, 900);
  const desktop = Size(1400, 900);

  Future<void> doctor(
    WidgetTester tester, {
    Size size = phone,
    void Function(FakeClinicAdminRepository fake)? configure,
  }) async {
    await pumpApp(
      tester,
      size: size,
      extra: [fakeClinicAdminOverride(configure: configure)],
    );
    await signIn(tester, 'doctor@el3yada.dev');
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  bool checked(WidgetTester tester, String key) =>
      tester
          .widget<CheckboxListTile>(find.byKey(ValueKey('permission.$key')))
          .value ??
      false;

  Future<void> tick(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey('permission.$key')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('permission.$key')));
    await tester.pumpAndSettle();
  }

  Finder presetSelected(String name) => find.byWidgetPredicate(
    (w) =>
        w is Pressable &&
        w.selected == true &&
        (w.semanticLabel ?? '').startsWith('$name.'),
  );

  group('D25 assistants', () {
    testWidgets(
      'lists each assistant with preset, status and branches, and the count',
      (tester) async {
        await doctor(tester);
        await open(tester, '/doctor/assistants');

        expect(find.text('3 of 5 assistants'), findsOneWidget);
        expect(find.text('مساعد تجريبي'), findsOneWidget);
        expect(find.text('مدير العيادة'), findsWidgets);
        expect(find.text('منى سمير'), findsOneWidget);
        // Removed assistants aren't listed.
        expect(find.text('هبة علي'), findsNothing);
        expect(find.text('Reception'), findsOneWidget);
        expect(find.text('Office manager'), findsOneWidget);
        expect(find.text('Custom'), findsOneWidget);
        expect(find.text('Disabled'), findsOneWidget);
        expect(find.text('All branches'), findsOneWidget);
      },
    );

    testWidgets('the limit disables Add assistant with the reason', (
      tester,
    ) async {
      await doctor(tester, configure: (fake) => fake.assistantLimit = 3);
      await open(tester, '/doctor/assistants');

      final add = tester.widget<ButtonStyleButton>(
        find.widgetWithText(FilledButton, 'Add assistant'),
      );
      expect(add.onPressed, isNull);
      expect(
        find.text("You've reached the most assistants you can have."),
        findsOneWidget,
      );
      expect(find.text('3 of 3 assistants'), findsOneWidget);
    });

    testWidgets('wide screens show the assistant next to the list', (
      tester,
    ) async {
      await doctor(tester, size: desktop);
      await open(tester, '/doctor/assistants');

      // The first one opens by itself.
      expect(find.byType(AssistantEditor), findsOneWidget);
      expect(find.text('Account'), findsWidgets);
      await tester.tap(find.text('منى سمير'));
      await settle(tester);
      expect(find.text('Enable'), findsOneWidget);
    });
  });

  group('D26 add and edit', () {
    testWidgets('creating an assistant shows the temporary password once', (
      tester,
    ) async {
      await doctor(tester);
      await open(tester, '/doctor/assistants/new');

      await tester.enterText(
        find.byKey(const ValueKey('assistant.fullName')),
        'سارة محمود',
      );
      await tester.enterText(
        find.byKey(const ValueKey('assistant.phone')),
        '01112223334',
      );
      await tester.ensureVisible(
        find.byKey(
          const ValueKey(
            'assistant.branch.${FakeClinicAdminRepository.maadiBranchId}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'assistant.branch.${FakeClinicAdminRepository.maadiBranchId}',
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add assistant').last);
      await settle(tester);

      final fake = clinicAdminFake(tester);
      expect(find.byType(TemporaryPasswordDialog), findsOneWidget);
      expect(find.text(fake.lastTemporaryPassword!), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      // Gone for good: the editor of the new assistant shows instead.
      expect(find.byType(TemporaryPasswordDialog), findsNothing);
      expect(find.text(fake.lastTemporaryPassword!), findsNothing);
      expect(find.text('سارة محمود'), findsWidgets);
      expect(find.text('Reset password'), findsOneWidget);
      expect(fake.calls['createAssistant'], 1);
    });

    testWidgets('a taken number shows next to the mobile field', (
      tester,
    ) async {
      await doctor(tester);
      await open(tester, '/doctor/assistants/new');

      await tester.enterText(
        find.byKey(const ValueKey('assistant.fullName')),
        'سارة محمود',
      );
      await tester.enterText(
        find.byKey(const ValueKey('assistant.phone')),
        '01000000005',
      );
      await tester.tap(find.text('All branches'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add assistant').last);
      await settle(tester);

      expect(
        find.text(
          'This number is already an assistant, in this clinic or another.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TemporaryPasswordDialog), findsNothing);
    });

    testWidgets('the preset becomes Custom when a box changes', (tester) async {
      await doctor(tester);
      await open(tester, '/doctor/assistants/new');

      expect(presetSelected('Reception'), findsOneWidget);
      await tick(tester, ClinicPermission.chat);
      expect(presetSelected('Custom'), findsOneWidget);
      expect(presetSelected('Reception'), findsNothing);

      // Picking a preset fills the boxes again.
      await tester.ensureVisible(find.text('Office manager'));
      await tester.tap(find.text('Office manager'));
      await tester.pumpAndSettle();
      expect(presetSelected('Office manager'), findsOneWidget);
      expect(checked(tester, ClinicPermission.pricesManage), isTrue);
      expect(checked(tester, ClinicPermission.clinicalView), isFalse);
    });

    testWidgets('dependencies switch on and off', (tester) async {
      await doctor(tester);
      await open(tester, '/doctor/assistants/new');

      expect(checked(tester, ClinicPermission.clinicalView), isFalse);
      await tick(tester, ClinicPermission.clinicalEditProfile);
      expect(checked(tester, ClinicPermission.clinicalEditProfile), isTrue);
      expect(checked(tester, ClinicPermission.clinicalView), isTrue);
      expect(
        find.text('Also turned on: View the medical file'),
        findsOneWidget,
      );

      await tick(tester, ClinicPermission.prescriptionsDraft);
      await tick(tester, ClinicPermission.clinicalView);
      expect(checked(tester, ClinicPermission.clinicalView), isFalse);
      expect(checked(tester, ClinicPermission.clinicalEditProfile), isFalse);
      expect(checked(tester, ClinicPermission.prescriptionsDraft), isFalse);
      expect(
        find.text(
          'Also turned off: Edit the medical profile, Prepare prescription drafts',
        ),
        findsOneWidget,
      );

      // scheduleManage pulls appointmentsManage and appointmentsView along.
      await tick(tester, ClinicPermission.appointmentsView);
      expect(checked(tester, ClinicPermission.appointmentsManage), isFalse);
      await tick(tester, ClinicPermission.scheduleManage);
      expect(checked(tester, ClinicPermission.appointmentsManage), isTrue);
      expect(checked(tester, ClinicPermission.appointmentsView), isTrue);
    });

    testWidgets('changing permissions saves the whole set', (tester) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/assistants/${FakeClinicAdminRepository.receptionUserId}',
      );

      await tick(tester, ClinicPermission.chat);
      expect(find.text('1 change not saved'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);

      expect(clinicAdminFake(tester).calls['updateAssistant'], 1);
      expect(find.text('1 change not saved'), findsNothing);
      expect(presetSelected('Custom'), findsOneWidget);
    });

    testWidgets('reset password shows the new password', (tester) async {
      await doctor(tester);
      await open(
        tester,
        '/doctor/assistants/${FakeClinicAdminRepository.receptionUserId}',
      );

      await tester.ensureVisible(find.text('Reset password'));
      await tester.tap(find.text('Reset password'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
      await settle(tester);

      expect(find.text('New temporary password'), findsOneWidget);
      expect(
        find.text(clinicAdminFake(tester).lastTemporaryPassword!),
        findsOneWidget,
      );
    });

    testWidgets('disable, then remove after a confirm; history stays', (
      tester,
    ) async {
      await doctor(tester);
      await open(tester, '/doctor/assistants');
      await tester.tap(find.text('مساعد تجريبي'));
      await settle(tester);

      await tester.ensureVisible(find.text('Disable'));
      await tester.tap(find.text('Disable'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
      await settle(tester);
      expect(find.text('Disabled'), findsWidgets);

      await tester.ensureVisible(find.text('Remove'));
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(
        find.textContaining('can be added again as a new assistant'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await settle(tester);

      // Back on the list, without them.
      expect(find.text('مساعد تجريبي'), findsNothing);
      expect(find.text('2 of 5 assistants'), findsOneWidget);
    });

    testWidgets('leaving the new form with typing asks first', (tester) async {
      await doctor(tester);
      await open(tester, '/doctor/assistants');
      await tester.tap(find.widgetWithText(FilledButton, 'Add assistant'));
      await settle(tester);

      await tester.enterText(
        find.byKey(const ValueKey('assistant.fullName')),
        'سارة',
      );
      await tester.pump();
      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      expect(find.text('Discard your changes?'), findsOneWidget);
    });
  });
}
