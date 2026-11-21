import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/network/api_client.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin/data/fake_admin_repository.dart';
import 'package:el3yada/features/admin/domain/admin_models.dart';
import 'package:el3yada/features/auth/application/auth_controller.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:el3yada/features/auth/presentation/trial_ended_screen.dart';
import 'package:el3yada/features/clinic/presentation/clinic_shell_parts.dart';
import 'package:el3yada/features/doctor_registration/presentation/verify_email_screen.dart';
import 'package:el3yada/features/startup/public_settings.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart' show settle, signIn;
import '../support/app_overrides.dart';
import '../support/clinic_records_support.dart';

/// The free trial (spec 6.16, backend/docs/api-free-trial.md): A15 after it
/// ends, the countdown banner, free sessions in D8, and the admin's AD2
/// filter, AD3 actions and AD13 setting.
const _support = PublicSettings(
  supportPhone: '0223581234',
  supportWhatsapp: '01000000000',
  supportEmail: 'help@el3yada.app',
);

const _desktop = Size(1400, 900);

/// The offline accounts, where `me` can answer as the server would after
/// the admin activated the service ([activated]) or after the trial ended
/// ([endTrial]); [loginAs] signs in any identifier as that account.
class _TrialAuth extends FakeAuthRepository {
  _TrialAuth({this.loginAs}) : super(delay: Duration.zero);

  final FakeAccount? loginAs;
  bool activated = false;
  bool endTrial = false;
  int meCalls = 0;

  @override
  Future<LoginResult> login({
    required String identifier,
    required String password,
    Map<String, dynamic>? device,
  }) async {
    final account = loginAs;
    if (account == null) {
      return super.login(
        identifier: identifier,
        password: password,
        device: device,
      );
    }
    return SignedIn(current = account.session(identifier));
  }

  @override
  Future<Map<String, dynamic>> me({String? accessToken}) async {
    meCalls++;
    final json = await super.me(accessToken: accessToken);
    if (activated) return {...json, 'trial': null};
    if (endTrial) {
      return {
        ...json,
        'trial': {
          'endsAt': DateTime.now().toUtc().toIso8601String(),
          'ended': true,
          'daysLeft': 0,
        },
      };
    }
    return json;
  }
}

/// Answers every request with 403 and [code], like the API.
class _Refuse implements HttpClientAdapter {
  _Refuse(this.code);

  final String code;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'status': 403, 'code': code, 'title': 'Refused'}),
    403,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Future<void> _pump(
  WidgetTester tester, {
  PublicSettings settings = _support,
  AuthRepository? auth,
  Size size = _desktop,
  bool arabic = false,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: await appOverrides(
        platform: size.width >= 1024 ? AppPlatform.desktop : AppPlatform.mobile,
        prefs: {'settings.locale': arabic ? 'ar' : 'en'},
        settings: settings,
        auth: auth,
        extra: extra,
      ),
      child: const El3yadaApp(),
    ),
  );
  await settle(tester);
}

Finder _inAlert(Finder finder) =>
    find.descendant(of: find.byType(AlertDialog), matching: finder);

Finder _inList(Finder finder) =>
    find.descendant(of: find.byType(ListView), matching: finder);

void main() {
  group('A15: the free trial ended', () {
    testWidgets(
      'a doctor sees the message, the support contacts, Check again and Log out',
      (tester) async {
        await _pump(tester);
        await signIn(tester, 'trial-ended@el3yada.dev');

        expect(find.byType(TrialEndedScreen), findsOneWidget);
        expect(find.text('Your free trial has ended'), findsOneWidget);
        expect(
          find.textContaining('Contact us to activate the service'),
          findsOneWidget,
        );
        expect(find.text('Contact support'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
        expect(find.text('Call'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Check again'), findsOneWidget);

        // No clinic screen opens, even by its address.
        goTo(tester, '/doctor/patients');
        await settle(tester);
        expect(find.byType(TrialEndedScreen), findsOneWidget);

        await tester.tap(find.text('Log out'));
        await settle(tester);
        expect(find.byType(TrialEndedScreen), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      },
    );

    testWidgets('without support contacts in the settings, none are shown', (
      tester,
    ) async {
      await _pump(tester, settings: const PublicSettings());
      await signIn(tester, 'trial-ended@el3yada.dev');

      expect(find.text('Your free trial has ended'), findsOneWidget);
      expect(find.text('Contact support'), findsNothing);
      expect(find.text('WhatsApp'), findsNothing);
    });

    testWidgets(
      'an assistant is asked to tell the doctor, without the contacts',
      (tester) async {
        await _pump(tester);
        await signIn(tester, '01000000006');

        expect(find.byType(TrialEndedScreen), findsOneWidget);
        expect(find.text("The clinic's free trial has ended"), findsOneWidget);
        expect(
          find.textContaining('Ask the doctor to contact us'),
          findsOneWidget,
        );
        expect(find.text('Contact support'), findsNothing);
      },
    );

    testWidgets(
      'Check again stays while the trial is over, and opens the clinic once the service is active',
      (tester) async {
        final auth = _TrialAuth();
        await _pump(tester, auth: auth);
        await signIn(tester, 'trial-ended@el3yada.dev');

        await tester.tap(find.text('Check again'));
        await settle(tester);
        expect(auth.meCalls, 1);
        expect(find.text("The service isn't active yet."), findsOneWidget);
        expect(find.byType(TrialEndedScreen), findsOneWidget);

        auth.activated = true;
        await tester.tap(find.text('Check again'));
        await settle(tester);
        expect(find.byType(TrialEndedScreen), findsNothing);
        expect(find.text('Patients'), findsWidgets, reason: 'the clinic shell');
      },
    );
  });

  group('TRIAL_ENDED from the API', () {
    testWidgets(
      'a 403 TRIAL_ENDED reloads the account, and the router opens A15',
      (tester) async {
        final auth = _TrialAuth();
        await _pump(tester, auth: auth);
        await signIn(tester, 'doctor@el3yada.dev');
        expect(find.byType(TrialEndedScreen), findsNothing);

        // The trial ends while the doctor works: the next request is refused.
        auth.endTrial = true;
        final dio = appContainer(tester).read(dioProvider)
          ..httpClientAdapter = _Refuse(ApiCodes.trialEnded);
        Object? error;
        await tester.runAsync(() async {
          try {
            await dio.get<Object>('/patients');
          } on DioException catch (e) {
            error = e;
          }
        });
        await settle(tester);

        expect(
          ApiException.fromDio(error! as DioException).code,
          ApiCodes.trialEnded,
        );
        expect(auth.meCalls, 1);
        expect(
          appContainer(tester).read(authControllerProvider).value!.trialEnded,
          isTrue,
        );
        expect(find.byType(TrialEndedScreen), findsOneWidget);
      },
    );
  });

  group('the countdown banner (BR-T6)', () {
    testWidgets(
      'two days left: the banner, and Contact us opens the contacts',
      (tester) async {
        await _pump(tester);
        await signIn(tester, 'trial@el3yada.dev');

        expect(find.text('2 days left in your free trial'), findsOneWidget);
        await tester.tap(find.text('Contact us'));
        await settle(tester);
        expect(find.text('Contact support'), findsOneWidget);
        expect(find.text('WhatsApp'), findsOneWidget);
      },
    );

    testWidgets('in Arabic the days are counted with the dual', (tester) async {
      await _pump(tester, arabic: true, size: const Size(420, 900));
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'trial@el3yada.dev',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);

      expect(
        find.text('تبقّى يومان على نهاية الفترة التجريبية المجانية'),
        findsOneWidget,
      );
      expect(find.text('تواصل معنا'), findsOneWidget);
    });

    testWidgets(
      'no banner with more than three days left, or without a trial',
      (tester) async {
        await _pump(
          tester,
          auth: _TrialAuth(
            loginAs: const FakeAccount(
              UserRole.doctor,
              'د. تجريبي',
              doctorStatus: DoctorStatus.active,
              trialDaysLeft: 5,
            ),
          ),
        );
        await signIn(tester, 'doctor@el3yada.dev');
        expect(find.byType(TrialBanner), findsOneWidget);
        expect(find.textContaining('left in your free trial'), findsNothing);
      },
    );

    testWidgets('a doctor without a trial has no banner', (tester) async {
      await _pump(tester);
      await signIn(tester, 'doctor@el3yada.dev');
      expect(find.textContaining('free trial'), findsNothing);
    });
  });

  // A new doctor is active at once (no A6), so A5 opens from the shell.
  group('A5 from the shell', () {
    const phone = Size(420, 900);
    _TrialAuth unverified() => _TrialAuth(
      loginAs: const FakeAccount(
        UserRole.doctor,
        'د. جديد',
        doctorStatus: DoctorStatus.active,
        emailVerified: false,
      ),
    );
    Finder inBanner(Finder finder) =>
        find.descendant(of: find.byType(EmailVerifyBanner), matching: finder);

    testWidgets(
      'an unverified doctor sees the banner; Verify opens A5 over the home, and Back returns',
      (tester) async {
        await _pump(tester, auth: unverified(), size: phone);
        await signIn(tester, 'new@el3yada.dev');

        expect(inBanner(find.text('Verify your email')), findsOneWidget);
        expect(
          find.text('Walk-in'),
          findsOneWidget,
          reason: 'the home, not A6',
        );
        await tester.tap(inBanner(find.text('Verify')));
        await settle(tester);
        expect(find.byType(VerifyEmailScreen), findsOneWidget);
        expect(find.text('new@el3yada.dev'), findsOneWidget);

        await tester.pageBack();
        await settle(tester);
        expect(find.byType(VerifyEmailScreen), findsNothing);
        expect(find.text('Walk-in'), findsOneWidget);
        expect(inBanner(find.text('Verify your email')), findsOneWidget);
      },
    );

    testWidgets(
      'a code verifies the email; Continue returns home and the banner is gone',
      (tester) async {
        final auth = unverified();
        await _pump(tester, auth: auth, size: phone);
        await signIn(tester, 'new@el3yada.dev');
        await tester.tap(inBanner(find.text('Verify')));
        await settle(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Code from the email'),
          'abc123',
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Verify'));
        await settle(tester);
        expect(
          find.text('Email verified'),
          findsOneWidget,
          reason: 'A5 stays to show it',
        );
        expect(
          appContainer(
            tester,
          ).read(authControllerProvider).value!.emailVerified,
          isTrue,
        );

        await tester.tap(find.text('Continue'));
        await settle(tester);
        expect(find.byType(VerifyEmailScreen), findsNothing);
        expect(find.text('Walk-in'), findsOneWidget);
        expect(find.text('Verify your email'), findsNothing);
      },
    );

    testWidgets('a verified doctor has no banner', (tester) async {
      await _pump(tester, size: phone);
      await signIn(tester, 'doctor@el3yada.dev');
      expect(find.text('Verify your email'), findsNothing);
    });

    testWidgets('Hide for now closes the banner for this run', (tester) async {
      await _pump(tester, auth: unverified(), size: phone);
      await signIn(tester, 'new@el3yada.dev');

      await tester.tap(find.byTooltip('Hide for now'));
      await settle(tester);
      expect(find.text('Verify your email'), findsNothing);
    });

    testWidgets(
      'D24 settings has «Verify your email address» while unverified, and it opens A5',
      (tester) async {
        await _pump(tester, auth: unverified(), size: phone);
        await signIn(tester, 'new@el3yada.dev');
        goTo(tester, '/doctor/settings');
        await settle(tester);

        final row = find.text('Verify your email address');
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(
          find.text('We sent a link to \u2066new@el3yada.dev\u2069.'),
          findsOneWidget,
        );
        await tester.tap(row);
        await settle(tester);
        expect(find.byType(VerifyEmailScreen), findsOneWidget);
      },
    );

    testWidgets('D24 has no such row for a verified doctor', (tester) async {
      await _pump(tester, size: phone);
      await signIn(tester, 'doctor@el3yada.dev');
      goTo(tester, '/doctor/settings');
      await settle(tester);
      expect(find.text('Verify your email address'), findsNothing);
    });
  });

  group('D8 during the free trial (BR-T3)', () {
    testWidgets(
      'the fee reads "free", the confirmation adds none, and the session is saved without one',
      (tester) async {
        await _pump(tester, extra: [fakeRecordsOverride()]);
        await signIn(tester, 'trial@el3yada.dev');
        final laila = recordsOf(tester).patientIdByName(SeedPatients.laila);
        goTo(tester, '/doctor/patients/$laila/sessions/new');
        await settle(tester);

        expect(find.text('No platform fee (free trial)'), findsNWidgets(2));
        await tester.tap(find.text('Consultation'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        await settle(tester);
        expect(find.text('Free (trial)'), findsOneWidget);

        await tester.enterText(
          find.widgetWithText(TextField, 'Diagnosis'),
          'التهاب لوزتين',
        );
        await tester.tap(find.text('Save session'));
        await settle(tester);
        expect(
          find.text('No fee: the clinic is in its free trial.'),
          findsOneWidget,
        );
        expect(find.textContaining('A fee of'), findsNothing);

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        expect(find.text('Session saved'), findsOneWidget);
        expect(find.textContaining('No fee (free trial).'), findsOneWidget);
      },
    );
  });

  group('admin', () {
    Future<void> signedInAdmin(
      WidgetTester tester, {
      void Function(FakeAdminRepository fake)? configure,
    }) async {
      await _pump(tester, extra: [fakeAdminOverride(configure: configure)]);
      await signIn(tester, 'admin@el3yada.dev');
    }

    Future<void> open(WidgetTester tester, String path) async {
      goTo(tester, path);
      await settle(tester);
    }

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

    testWidgets(
      'AD2 lists every doctor, or those by trial state, with the trial pill',
      (tester) async {
        await signedInAdmin(tester);
        await open(tester, '/admin/signups');
        expect(find.text('8 doctors'), findsOneWidget);
        expect(
          find.widgetWithText(ChoiceChip, 'Waiting for approval'),
          findsNothing,
        );
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'All doctors'),
              )
              .selected,
          isTrue,
        );

        await tester.tap(find.widgetWithText(ChoiceChip, 'Trial ended'));
        await settle(tester);
        expect(adminFake(tester).lastTrialFilter, TrialFilter.ended);
        expect(find.text('1 doctor'), findsOneWidget);
        expect(_inList(find.textContaining('نادية فتحي')), findsOneWidget);
        expect(_inList(find.textContaining('سامي عبد الله')), findsNothing);

        await tester.tap(find.widgetWithText(ChoiceChip, 'In free trial'));
        await settle(tester);
        expect(adminFake(tester).lastTrialFilter, TrialFilter.running);
        expect(_inList(find.textContaining('طارق محمود')), findsOneWidget);
        expect(_inList(find.text('Trial: 5 days left')), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'All doctors'));
        await settle(tester);
        expect(adminFake(tester).lastTrialFilter, isNull);
        expect(find.text('8 doctors'), findsOneWidget);
      },
    );

    testWidgets('AD3 activates the service after the trial ended', (
      tester,
    ) async {
      await signedInAdmin(tester);
      await open(tester, '/admin/signups/doc-nadia');

      expect(find.text('Free trial'), findsOneWidget);
      expect(find.textContaining('The free trial ended on'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Activate service'));
      await tester.pumpAndSettle();
      expect(
        _inAlert(
          find.text('Activate the service for Dr. نادية فتحي عبد الرحمن?'),
        ),
        findsOneWidget,
      );
      await tester.tap(_inAlert(find.text('Activate service')));
      await settle(tester);

      final fake = adminFake(tester);
      expect(fake.calls['activateDoctorService'], 1);
      expect(
        find.text('Service activated for Dr. نادية فتحي عبد الرحمن.'),
        findsOneWidget,
      );
      expect(
        (await fake.doctorRegistration('doc-nadia')).registration.trial,
        isNull,
      );
      expect(find.text('Service active'), findsOneWidget);
    });

    testWidgets(
      'AD3 extends the trial by the chosen days, checking the range',
      (tester) async {
        await signedInAdmin(tester);
        await open(tester, '/admin/signups/doc-nadia');

        await tester.tap(find.widgetWithText(OutlinedButton, 'Extend trial'));
        await tester.pumpAndSettle();
        expect(
          _inAlert(find.text("Extend Dr. نادية فتحي عبد الرحمن's free trial")),
          findsOneWidget,
        );
        await tester.enterText(_inAlert(find.byType(TextField)), '0');
        await tester.tap(_inAlert(find.text('Extend trial')));
        await tester.pumpAndSettle();
        expect(
          _inAlert(find.text('Enter a value from 1 to 90.')),
          findsOneWidget,
        );
        expect(adminFake(tester).calls['extendDoctorTrial'], isNull);

        await tester.enterText(_inAlert(find.byType(TextField)), '10');
        await tester.tap(_inAlert(find.text('Extend trial')));
        await settle(tester);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.textContaining("free trial now ends on"), findsOneWidget);
        final trial = (await adminFake(
          tester,
        ).doctorRegistration('doc-nadia')).registration.trial!;
        expect(trial.ended, isFalse);
        expect(
          trial.daysLeft,
          10,
          reason: 'an ended trial restarts from today',
        );
      },
    );

    testWidgets(
      "extending a doctor whose service is active shows the API's reason",
      (tester) async {
        await signedInAdmin(
          tester,
          configure: (fake) => fake.failNext(
            'extendDoctorTrial',
            const ApiException(
              kind: ApiErrorKind.http,
              status: 409,
              code: ApiCodes.serviceAlreadyActive,
            ),
          ),
        );
        await open(tester, '/admin/signups/doc-tarek');

        expect(find.text('Trial: 5 days left'), findsOneWidget);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Extend trial'));
        await tester.pumpAndSettle();
        await tester.tap(_inAlert(find.text('Extend trial')));
        await settle(tester);
        expect(
          _inAlert(
            find.text(
              "This doctor's service is already active, so there's no trial to extend.",
            ),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('AD13 has the trial length, checked from 1 to 90 days', (
      tester,
    ) async {
      await signedInAdmin(tester);
      await open(tester, '/admin/settings');

      final field = find.widgetWithText(TextFormField, 'Free trial');
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Applies to doctors approved after the change'),
        findsOneWidget,
      );
      await tester.enterText(field, '0');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(find.text('Enter a value from 1 to 90.'), findsOneWidget);
      expect(adminFake(tester).calls['updateSettings'], isNull);

      await tester.enterText(field, '21');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await settle(tester);
      expect(adminFake(tester).lastSettingsUpdate, {'trialDays': 21});
    });
  });
}
