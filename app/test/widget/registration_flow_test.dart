import 'dart:typed_data';

import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/doctor_registration/data/license_picker.dart';
import 'package:el3yada/features/doctor_registration/data/registration_repository.dart';
import 'package:el3yada/features/doctor_registration/domain/doctor_registration.dart';
import 'package:el3yada/features/doctor_registration/domain/license_file.dart';
import 'package:el3yada/features/doctor_registration/presentation/widgets/search_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_overrides.dart';

/// pumpAndSettle, plus the short timers (the check mark's hold) it skips.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byType(TextFormField).at(0), identifier);
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await settle(tester);
}

final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4]);

/// Hands back [file] for any source and remembers which one was asked for.
class FakeLicensePicker implements LicensePicker {
  FakeLicensePicker([this.file]);

  PickedLicense? file;
  LicenseSource? lastSource;

  @override
  Future<PickedLicense?> pick(LicenseSource source) async {
    lastSource = source;
    return file;
  }
}

/// Registration that answers with the API errors a test sets.
class FailingRegistrationRepository extends FakeRegistrationRepository {
  FailingRegistrationRepository({super.auth, required this.error}) : super(delay: Duration.zero);

  ApiException? error;

  @override
  Future<AuthSession> register(RegistrationData data, LicenseFile license) async {
    final failure = error;
    if (failure != null) {
      lastData = data;
      throw failure;
    }
    return super.register(data, license);
  }
}

/// A5 with a resend that the server refuses for [retryAfter].
class CooldownAuthRepository extends FakeAuthRepository {
  CooldownAuthRepository() : super(delay: Duration.zero);

  int resends = 0;

  @override
  Future<void> resendVerificationEmail() async {
    resends++;
    throw const ApiException(
      kind: ApiErrorKind.http,
      status: 429,
      code: ApiCodes.verificationEmailCooldown,
      retryAfter: Duration(seconds: 42),
    );
  }
}

class _Harness {
  _Harness({FakeAuthRepository? auth, FakeRegistrationRepository? registration})
      : auth = auth ?? FakeAuthRepository(delay: Duration.zero) {
    this.registration = registration ?? FakeRegistrationRepository(auth: this.auth, delay: Duration.zero);
  }

  final FakeAuthRepository auth;
  late final FakeRegistrationRepository registration;
  final picker = FakeLicensePicker(PickedLicense(name: 'card.png', size: _png.length, read: () async => _png));

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(420, 900),
    AppPlatform platform = AppPlatform.mobile,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: await appOverrides(
        platform: platform,
        auth: auth,
        extra: [
          registrationRepositoryProvider.overrideWithValue(registration),
          licensePickerProvider.overrideWithValue(picker),
        ],
      ),
      child: const El3yadaApp(),
    ));
    await settle(tester);
  }
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), text);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await settle(tester);
}

Future<void> next(WidgetTester tester) => tapText(tester, 'Next');

Future<void> openPicker(WidgetTester tester, String label) async {
  final picker = find.widgetWithText(PickerField, label);
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await settle(tester);
}

Future<void> fillAccount(WidgetTester tester, {String email = 'sami@example.com'}) async {
  await enter(tester, 'Full name', 'Sami Abdallah');
  await enter(tester, 'Email', email);
  await enter(tester, 'Mobile number', '010 1234 5678');
  await enter(tester, 'Password', 'Doctor123');
  await enter(tester, 'Confirm password', 'Doctor123');
}

Future<void> fillProfessional(WidgetTester tester) async {
  await tapText(tester, 'Consultant');
  await openPicker(tester, 'Primary specialty');
  await tapText(tester, 'Cardiology');
  await enter(tester, 'Syndicate number', '45678');
  await tapText(tester, 'Syndicate card or license');
  await tapText(tester, 'Take a photo');
}

Future<void> fillBranch(WidgetTester tester) async {
  await enter(tester, 'Branch name', 'Maadi branch');
  await openPicker(tester, 'Governorate');
  await tapText(tester, 'Cairo');
  await enter(tester, 'City or area', 'Maadi');
  await enter(tester, 'Street address', '9 Street');
  await enter(tester, 'Number 1', '02 2358 1234');
}

Future<void> openRegistration(WidgetTester tester) async {
  await tapText(tester, 'Register as a doctor');
  expect(find.text('Step 1 of 4'), findsOneWidget);
}

void main() {
  testWidgets('A4: each step is checked before Next, Back keeps the data, and Submit opens A6', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await openRegistration(tester);

    // Step 1: nothing filled in.
    await next(tester);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(find.text('This field is required'), findsNWidgets(5));

    await fillAccount(tester);
    await enter(tester, 'Confirm password', 'Doctor124');
    await next(tester);
    expect(find.text("The passwords don't match."), findsOneWidget);
    await enter(tester, 'Confirm password', 'Doctor123');
    await next(tester);
    expect(find.text('Step 2 of 4'), findsOneWidget);

    // Step 2: nothing chosen.
    await next(tester);
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Choose your title, or type it.'), findsOneWidget);
    expect(find.text('Choose your specialty.'), findsOneWidget);
    expect(find.text('The syndicate number is required.'), findsOneWidget);
    expect(find.text('Add a photo of your syndicate card or license.'), findsOneWidget);

    // Back keeps what was typed.
    await tapText(tester, 'Back');
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Sami Abdallah'), findsOneWidget);
    expect(find.text('sami@example.com'), findsOneWidget);
    await next(tester);

    await fillProfessional(tester);
    expect(app.picker.lastSource, LicenseSource.camera);
    expect(find.text('card.png'), findsOneWidget);
    await next(tester);
    expect(find.text('Step 3 of 4'), findsOneWidget);

    // Step 3: a bad phone and price.
    await fillBranch(tester);
    await enter(tester, 'Number 1', '12');
    await enter(tester, 'Examination', '1.234');
    await next(tester);
    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.text('Enter a valid Egyptian number: mobile, landline or hotline.'), findsOneWidget);
    expect(find.text('Enter an amount from 0 to 100,000, with at most 2 decimals.'), findsOneWidget);
    await enter(tester, 'Number 1', '02 2358 1234');
    await enter(tester, 'Examination', '300');
    await next(tester);

    // Step 4: the review, then the Terms.
    expect(find.text('Step 4 of 4'), findsOneWidget);
    expect(find.text('Sami Abdallah'), findsOneWidget);
    expect(find.text('Cardiology'), findsOneWidget);
    expect(find.text('0223581234'), findsOneWidget);
    expect(find.text('EGP 300'), findsOneWidget);
    await tapText(tester, 'Send for review');
    expect(find.text('Accept the Terms and the Privacy Policy to continue.'), findsOneWidget);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    await tapText(tester, 'Send for review');

    // A6, with the data that was sent.
    expect(find.text('Your account is being reviewed'), findsOneWidget);
    expect(find.text('Maadi branch'), findsOneWidget);
    final sent = app.registration.lastData!;
    expect(sent.phone, '+201012345678');
    expect(sent.title, 'استشاري');
    expect(sent.specialtyId, 'sp-cardio');
    expect(sent.branch.governorate, 'القاهرة');
    expect(sent.branch.phones.single.number, '+20223581234');
    expect(sent.examinationPricePiasters, 30000);
    expect(sent.consultationPricePiasters, isNull);
    expect(sent.acceptTerms, isTrue);
    expect(sent.device?['deviceId'], 'test-device');
    expect(app.registration.lastLicense?.contentType, LicenseFile.png);
  });

  testWidgets('A4: an "Edit" on the review step opens that step', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await openRegistration(tester);
    await fillAccount(tester);
    await next(tester);
    await fillProfessional(tester);
    await next(tester);
    await fillBranch(tester);
    await next(tester);

    await tester.ensureVisible(find.text('Edit').at(1));
    await tester.tap(find.text('Edit').at(1));
    await settle(tester);
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Cardiology'), findsOneWidget);
  });

  testWidgets('A4: a server field error opens the step that has it', (tester) async {
    final registration = FailingRegistrationRepository(
      error: const ApiException(
        kind: ApiErrorKind.http,
        status: 400,
        code: ApiCodes.validationFailed,
        fieldCodes: {'licenseNumber': 'INVALID_LICENSE_NUMBER', 'branch.street': 'TOO_LONG'},
      ),
    );
    final app = _Harness(registration: registration);
    await app.pump(tester);
    await openRegistration(tester);
    await fillAccount(tester);
    await next(tester);
    await fillProfessional(tester);
    await next(tester);
    await fillBranch(tester);
    await next(tester);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tapText(tester, 'Send for review');

    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Check the highlighted fields.'), findsOneWidget);
    expect(find.text('Enter the syndicate number: 3 to 20 letters or digits.'), findsOneWidget);

    // Fixing it moves on; the branch error is still waiting on step 3.
    await enter(tester, 'Syndicate number', '45679');
    await next(tester);
    expect(find.text('Step 3 of 4'), findsOneWidget);
    await next(tester);
    expect(find.text('Step 3 of 4'), findsOneWidget);
    expect(find.text('This is too long.'), findsOneWidget);
  });

  testWidgets('A4: an email that is already registered is marked on step 1', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await openRegistration(tester);
    await fillAccount(tester, email: FakeRegistrationRepository.takenEmail);
    await next(tester);
    await fillProfessional(tester);
    await next(tester);
    await fillBranch(tester);
    await next(tester);
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tapText(tester, 'Send for review');

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('An account with this email already exists.'), findsOneWidget);
  });

  testWidgets('A4: a file of the wrong type is refused before upload', (tester) async {
    final app = _Harness();
    app.picker.file = PickedLicense(name: 'card.gif', size: 6, read: () async => Uint8List.fromList('GIF89a'.codeUnits));
    await app.pump(tester);
    await openRegistration(tester);
    await fillAccount(tester);
    await next(tester);
    await tapText(tester, 'Syndicate card or license');
    await tapText(tester, 'Choose a file (photo or PDF)');

    expect(app.picker.lastSource, LicenseSource.files);
    expect(find.text('Use a photo (JPEG, PNG or WebP) or a PDF.'), findsOneWidget);
  });

  testWidgets('A4 with reduced motion: steps crossfade, Back still keeps the data', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final app = _Harness();
    await app.pump(tester);
    await openRegistration(tester);
    await fillAccount(tester);
    await next(tester);
    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('Sami Abdallah'), findsNothing);
    await tapText(tester, 'Back');
    expect(find.text('Sami Abdallah'), findsOneWidget);
  });

  testWidgets('A4 on desktop: the license opens the file dialog, and the review has two columns', (tester) async {
    final app = _Harness();
    await app.pump(tester, size: const Size(1280, 900), platform: AppPlatform.desktop);
    await openRegistration(tester);
    await fillAccount(tester);
    await next(tester);
    await tapText(tester, 'Syndicate card or license');
    expect(app.picker.lastSource, LicenseSource.files);
    expect(find.text('Take a photo'), findsNothing);
    expect(find.text('card.png'), findsOneWidget);

    await tapText(tester, 'Consultant');
    await openPicker(tester, 'Primary specialty');
    expect(find.byType(Dialog), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), 'قلب');
    await tester.pump();
    expect(find.text('Dermatology'), findsNothing);
    await tapText(tester, 'Cardiology');
    await enter(tester, 'Syndicate number', '45678');
    await next(tester);
    await fillBranch(tester);
    await next(tester);

    final account = tester.getRect(find.text('Account').last);
    final branch = tester.getRect(find.text('First branch').last);
    expect(branch.left, greaterThan(account.right));
  });

  testWidgets('A7: the reason is shown, and "Edit and resubmit" fills the form and sends it back', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await signIn(tester, 'rejected@el3yada.dev');

    expect(find.text("Your registration wasn't approved"), findsOneWidget);
    expect(find.text('صورة الكارنيه غير واضحة، ارفع صورة أوضح.'), findsOneWidget);
    await tapText(tester, 'Edit and resubmit');

    expect(find.text('Edit registration'), findsOneWidget);
    expect(find.text('سامي عبد الله'), findsOneWidget);
    expect(find.text('01012345678'), findsOneWidget);
    expect(field('Password'), findsNothing);
    await next(tester);
    expect(find.text('Pediatrics'), findsOneWidget);
    expect(find.text('Current file'), findsOneWidget);
    await enter(tester, 'Syndicate number', '45680');
    await next(tester);
    expect(find.text('فرع المعادي'), findsOneWidget);
    await next(tester);
    expect(find.byType(Checkbox), findsNothing);
    await tapText(tester, 'Send again for review');

    expect(find.text('Your account is being reviewed'), findsOneWidget);
    final sent = app.registration.lastData!;
    expect(sent.licenseNumber, '45680');
    expect(sent.password, isNull);
    expect(sent.acceptTerms, isNull);
    expect(sent.titleEn, 'Consultant');
    expect(app.registration.lastLicense, isNull);
  });

  testWidgets('A6: Refresh keeps a pending doctor here, and moves an approved one home', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await signIn(tester, 'pending@el3yada.dev');

    expect(find.text('Your account is being reviewed'), findsOneWidget);
    expect(find.text('Verify your email'), findsOneWidget);
    expect(find.text('فرع المعادي'), findsOneWidget);
    expect(find.text('EGP 300'), findsOneWidget);

    await tapText(tester, 'Refresh');
    expect(find.text("Still under review. We'll notify you once it's approved."), findsOneWidget);

    app.auth.current = app.auth.current!.copyWith(doctorStatus: DoctorStatus.active);
    await tapText(tester, 'Refresh');
    // The doctor's home (D34 until the live board arrives in Phase 6).
    expect(find.text('Search patient'), findsOneWidget);
  });

  testWidgets('A5: Resend starts a visible 60-second cooldown, and a code verifies the email', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await signIn(tester, 'pending@el3yada.dev');
    await tapText(tester, 'Verify your email');

    expect(find.text('pending@el3yada.dev'), findsOneWidget);
    await tester.ensureVisible(find.text('Resend the email'));
    await tester.tap(find.text('Resend the email'));
    await tester.pump(Duration.zero); // the request (zero-delay fake)
    await tester.pump(); // the answer
    expect(find.text('Sent. Check your inbox and your spam folder.'), findsOneWidget);
    expect(find.text('Resend in 60 s'), findsOneWidget);
    final resend = find.ancestor(of: find.text('Resend in 60 s'), matching: find.byWidgetPredicate((w) => w is TextButton));
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend in 59 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 59));
    await tester.pumpAndSettle();
    expect(find.text('Resend the email'), findsOneWidget);

    await tester.enterText(field('Code from the email'), 'expired');
    await tapText(tester, 'Verify');
    expect(find.text('This code has expired. Ask for a new email.'), findsOneWidget);

    await tester.enterText(field('Code from the email'), 'abc123');
    await tapText(tester, 'Verify');
    expect(find.text('Email verified'), findsOneWidget);

    await tapText(tester, 'Continue');
    expect(find.text('Your account is being reviewed'), findsOneWidget);
    expect(find.text('Verify your email'), findsNothing);
  });

  testWidgets("A5: the server's cooldown (429 with Retry-After) disables Resend", (tester) async {
    final auth = CooldownAuthRepository();
    final app = _Harness(auth: auth);
    await app.pump(tester);
    await signIn(tester, 'pending@el3yada.dev');
    await tapText(tester, 'Verify your email');
    await tester.ensureVisible(find.text('Resend the email'));
    await tester.tap(find.text('Resend the email'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Wait a minute before sending another email.'), findsOneWidget);
    expect(find.text('Resend in 42 s'), findsOneWidget);
    await tester.tap(find.text('Resend in 42 s'));
    await tester.pump();
    expect(auth.resends, 1);
    await tester.pump(const Duration(seconds: 42));
    await tester.pumpAndSettle();
    expect(find.text('Resend the email'), findsOneWidget);
  });

  testWidgets('A5: "I\'ve verified" says when the email is not verified yet', (tester) async {
    final app = _Harness();
    await app.pump(tester);
    await signIn(tester, 'pending@el3yada.dev');
    await tapText(tester, 'Verify your email');
    await tapText(tester, "I've verified");
    expect(find.text('Not verified yet. Open the link in the email, then try again.'), findsOneWidget);

    app.auth.current = app.auth.current!.copyWith(emailVerified: true);
    await tapText(tester, "I've verified");
    expect(find.text('Email verified'), findsOneWidget);
  });
}
