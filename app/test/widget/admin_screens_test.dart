import 'package:el3yada/core/widgets/navigation/app_back_button.dart';
import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin/data/fake_admin_repository.dart';
import 'package:el3yada/features/admin/domain/admin_models.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';

const _desktop = Size(1400, 900);
const _phone = Size(400, 800);

/// Signs in as the dev admin (a super admin) and leaves the app on the
/// admin home. [configure] sets up the offline admin data.
Future<void> _signedInAdmin(
  WidgetTester tester, {
  Size size = _desktop,
  AuthRepository? auth,
  void Function(FakeAdminRepository fake)? configure,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: await appOverrides(
        platform: size.width >= 1024 ? AppPlatform.desktop : AppPlatform.mobile,
        auth: auth,
        extra: [fakeAdminOverride(configure: configure)],
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

/// pumpAndSettle, plus the short holds after a success check.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String path) async {
  goTo(tester, path);
  await _settle(tester);
}

Finder _inDialog(Finder finder) =>
    find.descendant(of: find.byType(Dialog), matching: finder);

Finder _inAlert(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

/// In the AD2 list (not in a snack bar or the detail pane).
Finder _inList(Finder finder) =>
    find.descendant(of: find.byType(ListView), matching: finder);

const _validation = ApiErrorKind.http;

void main() {
  // Copy uses the system clipboard: answer it here, as the platform would.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // New doctors are active at once (backend/docs/api-free-trial.md); the
  // offline data keeps six legacy sign-ups still waiting for review.
  group('AD2 / AD3 doctors', () {
    testWidgets(
      'desktop: every doctor newest first; approving a legacy sign-up keeps them open, now in a trial',
      (tester) async {
        await _signedInAdmin(tester);
        await _open(tester, '/admin/signups');

        expect(find.text('Doctors'), findsWidgets);
        expect(find.text('8 doctors'), findsOneWidget);
        expect(
          _inList(find.text('Waiting for review')),
          findsWidgets,
          reason: 'legacy sign-ups show their status',
        );
        final mona = tester.getTopLeft(find.textContaining('منى حسن').first);
        final sami = tester.getTopLeft(
          find.textContaining('سامي عبد الله').first,
        );
        expect(mona.dy, lessThan(sami.dy), reason: 'newest first');
        expect(
          find.text('New'),
          findsNWidgets(2),
          reason: 'signed up in the last day',
        );

        // The first request is open in the detail pane, with everything submitted.
        expect(find.text('Sign-up request'), findsOneWidget);
        expect(find.text('Syndicate card (PDF)'), findsOneWidget);
        expect(find.text('78-2201'), findsOneWidget);

        await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
        await tester.pumpAndSettle();
        expect(
          _inAlert(find.text('Approve Dr. منى حسن الشريف?')),
          findsOneWidget,
        );
        await tester.tap(_inAlert(find.text('Approve')));
        await _settle(tester);

        expect(
          find.text('Dr. منى حسن الشريف is approved and can now use el3yada.'),
          findsOneWidget,
        );
        expect(find.text('8 doctors'), findsOneWidget);
        expect(_inList(find.textContaining('منى حسن')), findsOneWidget);
        // She stays open, now an active doctor whose free trial started.
        expect(find.text('Doctor account'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Approve'), findsNothing);
        expect(find.text('78-2201'), findsOneWidget);
        expect(
          find.text('Trial: 14 days left'),
          findsNWidgets(2),
          reason: 'in the list and in the trial section',
        );
        final fake = adminFake(tester);
        expect(
          (await fake.doctorRegistration('doc-mona')).registration.status,
          DoctorStatuses.active,
        );
      },
    );

    testWidgets(
      'reject needs a reason, and the API\'s reason error shows on the field',
      (tester) async {
        await _signedInAdmin(tester);
        await _open(tester, '/admin/signups');

        await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
        await tester.pumpAndSettle();
        final submit = _inAlert(find.widgetWithText(FilledButton, 'Reject'));
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          find.text('Write the reason (at least 3 characters).'),
          findsOneWidget,
        );
        expect(adminFake(tester).calls['reviewDoctorRegistration'], isNull);

        // The server's own check.
        adminFake(tester).failNext(
          'reviewDoctorRegistration',
          const ApiException(
            kind: _validation,
            status: 400,
            code: 'VALIDATION_FAILED',
            fieldCodes: {'reason': 'REASON_REQUIRED'},
          ),
        );
        await tester.enterText(_inAlert(find.byType(TextFormField)), 'Bad');
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(
          find.text('Write the reason (at least 3 characters).'),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);

        // A preset reason fills the field; this time it goes through.
        await tester.tap(
          find.text(
            "The syndicate card photo isn't clear. Upload a clearer photo.",
          ),
        );
        await tester.tap(submit);
        await _settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.text(
            "Dr. منى حسن الشريف's sign-up was rejected. They'll see your reason.",
          ),
          findsOneWidget,
        );
        final rejected = (await adminFake(
          tester,
        ).doctorRegistration('doc-mona')).registration;
        expect(rejected.status, DoctorStatuses.rejected);
        expect(
          rejected.statusReason,
          "The syndicate card photo isn't clear. Upload a clearer photo.",
        );
      },
    );

    testWidgets(
      'a request another admin answered first is dropped with a message',
      (tester) async {
        await _signedInAdmin(
          tester,
          configure: (fake) => fake.failNext(
            'reviewDoctorRegistration',
            const ApiException(
              kind: _validation,
              status: 409,
              code: 'REGISTRATION_NOT_PENDING',
            ),
          ),
        );
        await _open(tester, '/admin/signups');

        await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
        await tester.pumpAndSettle();
        await tester.tap(_inAlert(find.text('Approve')));
        await _settle(tester);

        expect(
          find.text(
            'This request was already reviewed, maybe by another admin.',
          ),
          findsOneWidget,
        );
        expect(find.text('8 doctors'), findsOneWidget);
      },
    );

    testWidgets(
      'search narrows the list and an empty result offers to clear it',
      (tester) async {
        await _signedInAdmin(tester);
        await _open(tester, '/admin/signups');

        await tester.enterText(find.byType(TextField).first, '31207');
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        expect(find.text('1 doctor'), findsOneWidget);
        expect(find.textContaining('كريم مصطفى'), findsWidgets);

        await tester.enterText(find.byType(TextField).first, 'nobody');
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        expect(find.text('No doctors match your search'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Clear search'));
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        expect(find.text('8 doctors'), findsOneWidget);
      },
    );

    testWidgets(
      'phone: a card opens the review; after approving, the list shows the doctor active in a trial',
      (tester) async {
        await _signedInAdmin(tester, size: _phone);
        await _open(tester, '/admin/signups');

        await tester.tap(find.textContaining('سامي عبد الله'));
        await _settle(tester);
        expect(find.text('Sign-up request'), findsOneWidget);
        expect(find.text('010 1234 5678'), findsWidgets);
        expect(find.text('EGP 300'), findsOneWidget);
        expect(find.text('Email not confirmed'), findsWidgets);

        final approve = find.widgetWithText(FilledButton, 'Approve');
        await tester.ensureVisible(approve);
        await tester.pumpAndSettle();
        await tester.tap(approve);
        await tester.pumpAndSettle();
        await tester.tap(_inAlert(find.text('Approve')));
        await _settle(tester);

        expect(find.text('Sign-up request'), findsNothing);
        expect(_inList(find.textContaining('سامي عبد الله')), findsOneWidget);
        expect(find.text('8 doctors'), findsOneWidget);
        expect(
          _inList(find.text('Trial: 14 days left')),
          findsOneWidget,
          reason: 'his trial started',
        );
      },
    );

    testWidgets(
      'with reduced motion the review still opens (a plain fade) and works',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await _signedInAdmin(tester, size: _phone);
        await _open(tester, '/admin/signups');

        await tester.tap(find.textContaining('كريم مصطفى'));
        await _settle(tester);
        expect(find.text('Sign-up request'), findsOneWidget);
        await tester.tap(find.byType(AppBackButton));
        await _settle(tester);
        expect(find.text('Sign-up request'), findsNothing);
        expect(find.text('8 doctors'), findsOneWidget);
      },
    );

    testWidgets('a resubmitted request shows the earlier rejection', (
      tester,
    ) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/signups/doc-karim');

      expect(find.text('Sent again'), findsOneWidget);
      expect(find.text('Rejected before because'), findsOneWidget);
      expect(find.text('Rejected by نور عادل'), findsOneWidget);
    });
  });

  group('AD13 settings', () {
    testWidgets('sends only the changed fields, in piasters', (tester) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/settings');

      expect(
        find.text('Last changed by نور عادل · 2 days ago'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Examination fee'),
        '45.5',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Grace period'),
        '10',
      );
      await tester.pumpAndSettle();
      expect(find.text('2 changes not saved'), findsOneWidget);
      expect(find.text('Saved value: EGP 30'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await _settle(tester);

      final fake = adminFake(tester);
      expect(fake.lastSettingsUpdate, {
        'examFeePiasters': 4550,
        'gracePeriodDays': 10,
      });
      expect(find.text('2 settings saved'), findsOneWidget);
      expect(find.text('2 changes not saved'), findsNothing);
      expect((await fake.settings())['examFeePiasters'], 4550);
    });

    testWidgets(
      'checks the ranges before sending, and shows the API\'s field errors',
      (tester) async {
        await _signedInAdmin(tester);
        await _open(tester, '/admin/settings');

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Grace period'),
          '40',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await _settle(tester);
        expect(find.text('Enter a value from 0 to 31.'), findsOneWidget);
        expect(
          find.text('Fix the highlighted fields, then save.'),
          findsOneWidget,
        );
        expect(adminFake(tester).calls['updateSettings'], isNull);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Grace period'),
          '7',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Support email'),
          'support@el3yada.app',
        );
        adminFake(tester).failNext(
          'updateSettings',
          const ApiException(
            kind: _validation,
            status: 400,
            code: 'VALIDATION_FAILED',
            fieldCodes: {'supportEmail': 'INVALID_EMAIL'},
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await _settle(tester);

        expect(adminFake(tester).lastSettingsUpdate, {
          'supportEmail': 'support@el3yada.app',
        });
        expect(find.text('Enter a valid email address.'), findsOneWidget);
        expect(
          find.text('1 change not saved'),
          findsOneWidget,
          reason: 'nothing was saved',
        );
      },
    );

    testWidgets(
      'discard puts the saved values back; the history lists a field\'s changes',
      (tester) async {
        await _signedInAdmin(tester);
        await _open(tester, '/admin/settings');

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Examination fee'),
          '99',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Discard'));
        await tester.pumpAndSettle();
        await tester.tap(_inAlert(find.text('Discard')));
        await tester.pumpAndSettle();
        expect(find.text('1 change not saved'), findsNothing);
        expect(find.widgetWithText(TextFormField, '30'), findsOneWidget);

        await tester.tap(find.byTooltip('Change history: Examination fee'));
        await _settle(tester);
        expect(_inDialog(find.text('Change history')), findsOneWidget);
        expect(_inDialog(find.text('EGP 25')), findsOneWidget);
        expect(_inDialog(find.text('EGP 30')), findsOneWidget);
      },
    );
  });

  group('AD14 admin users', () {
    testWidgets('add admin shows the temporary password once', (tester) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/admins');

      await tester.tap(find.widgetWithText(FilledButton, 'Add admin'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _inDialog(find.widgetWithText(TextFormField, 'Full name')),
        'Hala Samir',
      );
      await tester.enterText(
        _inDialog(find.widgetWithText(TextFormField, 'Email')),
        'hala@el3yada.dev',
      );
      await tester.tap(
        _inDialog(find.widgetWithText(FilledButton, 'Add admin')),
      );
      await _settle(tester);

      final password = adminFake(tester).lastTemporaryPassword!;
      expect(password, hasLength(12));
      Finder shown() => find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == password,
      );
      expect(shown(), findsOneWidget);
      expect(find.text('Hala Samir was added'), findsOneWidget);
      expect(find.textContaining("It's shown only once"), findsOneWidget);

      await tester.tap(find.text('Copy password'));
      await tester.pumpAndSettle();
      expect(find.text('Copied'), findsOneWidget);

      // Only Done closes it, and the password is gone for good.
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await _settle(tester);
      expect(shown(), findsNothing);
      expect(find.text('Hala Samir'), findsOneWidget);
    });

    testWidgets('an email in use is shown on the email field', (tester) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/admins');

      await tester.tap(find.widgetWithText(FilledButton, 'Add admin'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _inDialog(find.widgetWithText(TextFormField, 'Full name')),
        'Nour Again',
      );
      await tester.enterText(
        _inDialog(find.widgetWithText(TextFormField, 'Email')),
        'nour@el3yada.dev',
      );
      await tester.tap(
        _inDialog(find.widgetWithText(FilledButton, 'Add admin')),
      );
      await _settle(tester);

      expect(
        find.text('An account with this email already exists.'),
        findsOneWidget,
      );
      expect(adminFake(tester).lastTemporaryPassword, isNull);
    });

    testWidgets('demoting the last super admin is refused with the reason', (
      tester,
    ) async {
      await _signedInAdmin(
        tester,
        configure: (fake) => fake.failNext(
          'setAdminRole',
          const ApiException(
            kind: _validation,
            status: 409,
            code: 'LAST_SUPER_ADMIN',
          ),
        ),
      );
      await _open(tester, '/admin/admins');

      await tester.tap(find.byTooltip('Actions for نور عادل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make admin'));
      await tester.pumpAndSettle();
      await tester.tap(_inAlert(find.text('Make admin')));
      await _settle(tester);

      expect(find.text('Not allowed'), findsOneWidget);
      expect(
        find.text('There must always be at least one active super admin.'),
        findsOneWidget,
      );
    });

    testWidgets('disable asks first, and your own row has no actions', (
      tester,
    ) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/admins');

      expect(find.text('Admin (you)'), findsOneWidget);
      expect(
        find.byTooltip(
          "That's you. Another super admin can change your account.",
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Actions for مصطفى كامل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable'));
      await tester.pumpAndSettle();
      expect(find.text('Disable مصطفى كامل?'), findsOneWidget);
      await tester.tap(_inAlert(find.text('Disable')));
      await _settle(tester);

      expect(find.text('مصطفى كامل was disabled.'), findsOneWidget);
      final admins = await adminFake(tester).admins();
      expect(
        admins.firstWhere((a) => a.userId == 'admin-mostafa').isActive,
        isFalse,
      );
    });

    testWidgets(
      'a plain admin has no Admins item and sees why at its address',
      (tester) async {
        await _signedInAdmin(tester, auth: PlainAdminAuthRepository());

        expect(find.text('Audit log'), findsOneWidget);
        expect(find.text('Admins'), findsNothing);
        await _open(tester, '/admin/admins');
        expect(
          find.text('Only super admins can manage admins.'),
          findsOneWidget,
        );
      },
    );
  });

  group('AD15 audit log', () {
    testWidgets('loads more pages while scrolling, newest first', (
      tester,
    ) async {
      await _signedInAdmin(tester, size: _phone);
      await _open(tester, '/admin/audit');

      final fake = adminFake(tester);
      expect(fake.calls['auditLogs'], 1);
      expect(
        find.text('Confirmed their email'),
        findsOneWidget,
        reason: 'the newest row',
      );

      await tester.scrollUntilVisible(
        find.text("That's everything."),
        600,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final total = (await fake.auditLogs(
        const AuditFilter(),
        pageSize: 100,
      )).totalCount;
      expect(
        fake.calls['auditLogs'],
        (total / 25).ceil() + 1,
        reason: 'every page once (+1 for the check above)',
      );
      expect(
        find.text('Created the first super admin'),
        findsOneWidget,
        reason: 'the oldest row',
      );
    });

    testWidgets('filters by action, and a row opens its details', (
      tester,
    ) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/audit');

      await tester.tap(find.byTooltip('Action'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign-up rejected').last);
      await _settle(tester);

      expect(find.text('1 entry'), findsOneWidget);
      await tester.tap(find.text("Rejected a doctor's sign-up"));
      await _settle(tester);
      expect(find.text('Reason'), findsOneWidget);
      expect(
        find.text('صورة كارنيه النقابة غير واضحة، برجاء رفع صورة أوضح.'),
        findsOneWidget,
      );
      expect(find.text('Open the sign-up request'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await _settle(tester);
      expect(find.text('1 entry'), findsNothing);
    });
  });

  group('AD18 admin profile', () {
    testWidgets(
      'opens from the top bar; change password checks the current one',
      (tester) async {
        await _signedInAdmin(tester);
        await tester.tap(find.byTooltip('My profile'));
        await _settle(tester);

        expect(find.text('admin@el3yada.dev'), findsOneWidget);
        expect(find.text('Super admin'), findsOneWidget);

        final fields = find.descendant(
          of: find.byType(Form),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(fields.at(0), 'wrong');
        await tester.enterText(fields.at(1), 'newpass123');
        await tester.enterText(fields.at(2), 'newpass123');
        final submit = find.widgetWithText(FilledButton, 'Change password');
        await tester.tap(submit);
        await _settle(tester);
        expect(find.text('The current password is wrong.'), findsOneWidget);

        await tester.enterText(fields.at(0), 'dev12345');
        await tester.tap(submit);
        await _settle(tester);
        expect(find.text('The current password is wrong.'), findsNothing);
        expect(
          find.text('Password changed. Your other devices were signed out.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('the name can change; language switches the app at once', (
      tester,
    ) async {
      await _signedInAdmin(tester);
      await _open(tester, '/admin/settings/profile');

      await tester.tap(find.text('Edit name'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Nour',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Write at least a first and a last name, in letters only.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'),
        'Nour Adel',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await _settle(tester);
      expect(find.text('Name saved'), findsOneWidget);
      expect(find.text('Nour Adel'), findsWidgets);

      await tester.tap(find.text('العربية'));
      await _settle(tester);
      expect(find.text('ملفي الشخصي'), findsWidgets);
    });
  });
}
