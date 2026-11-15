import 'dart:convert';
import 'dart:typed_data';

import 'package:el3yada/core/validation/egyptian_phone.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/doctor_registration/application/registration_form.dart';
import 'package:el3yada/features/doctor_registration/data/license_picker.dart';
import 'package:el3yada/features/doctor_registration/data/registration_repository.dart';
import 'package:el3yada/features/doctor_registration/domain/doctor_registration.dart';
import 'package:el3yada/features/doctor_registration/domain/license_file.dart';
import 'package:el3yada/features/doctor_registration/domain/reference_lists.dart';
import 'package:el3yada/features/doctor_registration/domain/registration_rules.dart';
import 'package:el3yada/features/doctor_registration/domain/specialty.dart';
import 'package:flutter_test/flutter_test.dart';

final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0]);
final pdfBytes = Uint8List.fromList('%PDF-1.7\n'.codeUnits);

/// A form with every step filled in validly.
RegistrationForm filledForm({bool resubmit = false}) {
  final form = RegistrationForm(resubmit: resubmit);
  form.fullName.text = '  سامي   عبد الله ';
  form.email.text = 'Sami@Example.com ';
  form.phone.text = '010 1234 5678';
  form.password.text = 'Doctor123';
  form.confirmPassword.text = 'Doctor123';
  form.selectTitle(DoctorTitles.all[1]);
  form.setSpecialty(FakeRegistrationRepository.specialtyList[7]);
  form.addExtraSpecialty(FakeRegistrationRepository.specialtyList[0]);
  form.licenseNumber.text = '٤٥ ٦٧٨';
  form.setLicense(LicenseFile(bytes: pngBytes, name: 'card.png', contentType: LicenseFile.png));
  form.branchName.text = 'فرع المعادي';
  form.setGovernorate('القاهرة');
  form.city.text = 'المعادي';
  form.street.text = 'شارع 9';
  form.phones.first.number.text = '02 2358 1234';
  form.examinationPrice.text = '300';
  form.consultationPrice.text = '150.5';
  form.setAcceptTerms(true);
  return form;
}

void main() {
  group('RegistrationRules (spec section 11)', () {
    test('full name: two words of letters, 2–60 characters', () {
      expect(RegistrationRules.isFullName('سامي عبد الله'), isTrue);
      expect(RegistrationRules.isFullName('Sami  Abdallah'), isTrue);
      expect(RegistrationRules.isFullName('سامي'), isFalse);
      expect(RegistrationRules.isFullName('Sami 2nd'), isFalse);
      expect(RegistrationRules.isFullName('${'a' * 40} ${'b' * 30}'), isFalse);
    });

    test('syndicate number: 3–20 letters, digits, - or /, Arabic digits and spaces normalized', () {
      expect(RegistrationRules.normalizeLicenseNumber('٤٥ ٦٧٨'), '45678');
      expect(RegistrationRules.normalizeLicenseNumber('AB-12/3'), 'AB-12/3');
      expect(RegistrationRules.normalizeLicenseNumber('12'), isNull);
      expect(RegistrationRules.normalizeLicenseNumber('12#4'), isNull);
    });

    test('visit prices: EGP with up to 2 decimals → piasters, 0–100,000', () {
      expect(RegistrationRules.parsePrice(''), isNull);
      expect(RegistrationRules.parsePrice('300'), 30000);
      expect(RegistrationRules.parsePrice('150.5'), 15050);
      expect(RegistrationRules.parsePrice('٣٠٠٫٢٥'), 30025);
      expect(RegistrationRules.parsePrice('100000'), 10000000);
      expect(() => RegistrationRules.parsePrice('100000.01'), throwsFormatException);
      expect(() => RegistrationRules.parsePrice('1.234'), throwsFormatException);
      expect(() => RegistrationRules.parsePrice('abc'), throwsFormatException);
      expect(RegistrationRules.formatPriceInput(30000), '300');
      expect(RegistrationRules.formatPriceInput(15050), '150.50');
    });
  });

  test('EgyptianPhone accepts mobiles, landlines and hotlines like the API', () {
    expect(EgyptianPhone.normalize('010 1234 5678'), '+201012345678');
    expect(EgyptianPhone.normalize('02 2358 1234'), '+20223581234');
    expect(EgyptianPhone.normalize('+20 3 4851234'), '+2034851234');
    expect(EgyptianPhone.normalize('19123'), '19123');
    expect(EgyptianPhone.normalize('١٩١٢٣'), '19123');
    expect(EgyptianPhone.normalize('0123'), isNull);
    expect(EgyptianPhone.display('+20223581234'), '0223581234');
  });

  test('LicenseFile reads the type from the first bytes, as the API does', () {
    expect(LicenseFile.detectType(pngBytes), LicenseFile.png);
    expect(LicenseFile.detectType(pdfBytes), LicenseFile.pdf);
    expect(LicenseFile.detectType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), LicenseFile.jpeg);
    expect(LicenseFile.detectType(Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits)), LicenseFile.webp);
    expect(LicenseFile.detectType(Uint8List.fromList('GIF89a'.codeUnits)), isNull);
  });

  group('loadLicense', () {
    test('refuses a file over 10 MB before reading it', () async {
      var read = false;
      final picked = PickedLicense(name: 'big.pdf', size: LicenseFile.maxBytes + 1, read: () async {
        read = true;
        return pdfBytes;
      });
      await expectLater(loadLicense(picked), throwsA(isA<LicenseFileException>().having((e) => e.code, 'code', 'FILE_TOO_LARGE')));
      expect(read, isFalse);
    });

    test('refuses a type the API does not take', () async {
      final picked = PickedLicense(name: 'a.gif', size: 6, read: () async => Uint8List.fromList('GIF89a'.codeUnits));
      await expectLater(
        loadLicense(picked),
        throwsA(isA<LicenseFileException>().having((e) => e.code, 'code', 'FILE_TYPE_NOT_ALLOWED')),
      );
    });

    test('accepts a PDF', () async {
      final file = await loadLicense(PickedLicense(name: 'card.pdf', size: pdfBytes.length, read: () async => pdfBytes));
      expect(file.contentType, LicenseFile.pdf);
      expect(file.isPdf, isTrue);
    });
  });

  test('RegField maps API field paths to the step that shows them', () {
    expect(RegField.stepOf('email'), 0);
    expect(RegField.stepOf('licenseNumber'), 1);
    expect(RegField.stepOf('license'), 1);
    expect(RegField.stepOf('extraSpecialtyIds'), 1);
    expect(RegField.stepOf('branch.phones[2].number'), 2);
    expect(RegField.stepOf('consultationPricePiasters'), 2);
    expect(RegField.stepOf('acceptTerms'), 3);
    expect(RegField.stepOf('device.deviceId'), 3);
    expect(RegField.isUnplaced('device.deviceId'), isTrue);
    expect(RegField.isUnplaced('acceptTerms'), isFalse);
  });

  group('RegistrationForm', () {
    test('an empty form fails every step with the right codes', () {
      final form = RegistrationForm();
      expect(form.validateStep(0), {
        'fullName': 'REQUIRED',
        'email': 'REQUIRED',
        'phone': 'REQUIRED',
        'password': 'REQUIRED',
        'confirmPassword': 'REQUIRED',
      });
      expect(form.validateStep(1), {
        'title': 'REQUIRED',
        'specialtyId': 'REQUIRED',
        'licenseNumber': 'REQUIRED',
        'license': 'REQUIRED',
      });
      expect(form.validateStep(2), {
        'branch.nameAr': 'REQUIRED',
        'branch.governorate': 'REQUIRED',
        'branch.city': 'REQUIRED',
        'branch.street': 'REQUIRED',
        'branch.phones[0].number': 'REQUIRED',
      });
      expect(form.validateStep(3), {'acceptTerms': 'TERMS_NOT_ACCEPTED'});
    });

    test('a resubmission needs no password, Terms or new license', () {
      final form = RegistrationForm(resubmit: true)..keptLicenseType = LicenseFile.jpeg;
      expect(form.validateStep(0).keys, isNot(contains('password')));
      expect(form.validateStep(1).keys, isNot(contains('license')));
      expect(form.validateStep(3), isEmpty);
    });

    test('invalid values get their own codes', () {
      final form = filledForm();
      form.fullName.text = 'Sami';
      form.email.text = 'sami@';
      form.phone.text = '0123';
      form.confirmPassword.text = 'other123';
      form.phones.first.number.text = '12';
      form.examinationPrice.text = '1.234';
      expect(form.validateStep(0), {
        'fullName': 'INVALID_NAME',
        'email': 'INVALID_EMAIL',
        'phone': 'INVALID_MOBILE',
        'confirmPassword': 'PASSWORDS_DONT_MATCH',
      });
      expect(form.validateStep(2), {
        'branch.phones[0].number': 'INVALID_PHONE',
        'examinationPricePiasters': 'INVALID_AMOUNT',
      });
    });

    test('typing in a field clears its error and the first step with an error is found', () {
      final form = filledForm();
      form.setErrors({'branch.street': 'TOO_LONG', 'email': 'EMAIL_ALREADY_REGISTERED'});
      expect(form.firstStepWithError(), 0);
      form.email.text = 'other@example.com';
      expect(form.errorOf('email'), isNull);
      expect(form.firstStepWithError(), 2);
    });

    test('builds the API body: normalized, piasters, nulls left out', () {
      final form = filledForm();
      expect(form.validateAll(), isEmpty);
      final json = jsonDecode(jsonEncode(form.toData(locale: 'ar', device: {'deviceId': 'd1'}).toJson()));
      expect(json, {
        'fullName': 'سامي عبد الله',
        'email': 'sami@example.com',
        'phone': '+201012345678',
        'password': 'Doctor123',
        'locale': 'ar',
        'title': 'استشاري',
        'titleEn': 'Consultant',
        'specialtyId': 'sp-cardio',
        'extraSpecialtyIds': ['sp-internal'],
        'licenseNumber': '45678',
        'examinationPricePiasters': 30000,
        'consultationPricePiasters': 15050,
        'branch': {
          'nameAr': 'فرع المعادي',
          'governorate': 'القاهرة',
          'city': 'المعادي',
          'street': 'شارع 9',
          'phones': [
            {'number': '+20223581234', 'label': 'reception', 'isWhatsapp': false},
          ],
        },
        'acceptTerms': true,
        'device': {'deviceId': 'd1'},
      });
    });

    test('choosing the primary specialty drops it from the extras', () {
      final form = filledForm();
      form.setSpecialty(FakeRegistrationRepository.specialtyList[0]);
      expect(form.extraSpecialties, isEmpty);
    });

    test('A7 pre-fill keeps the fields the form does not show, and leaves out password and Terms', () {
      const view = DoctorRegistration(
        status: DoctorStatus.rejected,
        fullName: 'سامي عبد الله',
        email: 'sami@example.com',
        phone: '+201012345678',
        title: 'جراح أطفال',
        titleEn: 'Pediatric Surgeon',
        fullNameEn: 'Sami Abdallah',
        specialty: Specialty(id: 'sp-pediatrics', nameAr: 'أطفال', nameEn: 'Pediatrics'),
        licenseNumber: '45678',
        licenseContentType: LicenseFile.pdf,
        examinationPricePiasters: 25050,
        branch: RegistrationBranch(
          nameAr: 'فرع المعادي',
          nameEn: 'Maadi',
          governorate: 'Cairo',
          city: 'المعادي',
          area: 'دجلة',
          street: 'شارع 9',
          lat: 29.96,
          lng: 31.25,
          phones: [BranchPhone(number: '+20223581234', label: 'landline', isWhatsapp: true)],
        ),
      );
      final form = RegistrationForm(resubmit: true)..prefill(view);
      expect(form.otherTitle, isTrue);
      expect(form.titleText.text, 'جراح أطفال');
      expect(form.governorate, 'القاهرة');
      expect(form.phone.text, '01012345678');
      expect(form.phones.single.number.text, '0223581234');
      expect(form.examinationPrice.text, '250.50');
      expect(form.keptLicenseType, LicenseFile.pdf);
      expect(form.validateAll(), isEmpty);

      final json = form.toData(locale: 'en').toJson();
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('acceptTerms'), isFalse);
      expect(json['titleEn'], 'Pediatric Surgeon');
      expect(json['fullNameEn'], 'Sami Abdallah');
      final branch = (json['branch'] as Map).cast<String, dynamic>();
      expect(branch['nameEn'], 'Maadi');
      expect(branch['area'], 'دجلة');
      expect(branch['lat'], 29.96);
      expect(branch.containsKey('id'), isFalse);
    });
  });

  group('FakeRegistrationRepository', () {
    test('registers, then answers myRegistration and the license for the new account', () async {
      final auth = FakeAuthRepository(delay: Duration.zero);
      final repository = FakeRegistrationRepository(auth: auth, delay: Duration.zero);
      final form = filledForm();
      final session = await repository.register(form.toData(locale: 'ar'), form.license!);

      expect(session.doctorStatus, DoctorStatus.pendingApproval);
      expect(auth.current, session);
      final view = await repository.myRegistration();
      expect(view.specialty.nameEn, 'Cardiology');
      expect(view.branch?.phones.single.number, '+20223581234');
      expect((await repository.myLicense())?.contentType, LicenseFile.png);
    });

    test('taken@el3yada.dev is already registered', () async {
      final repository = FakeRegistrationRepository(delay: Duration.zero);
      final form = filledForm()..email.text = FakeRegistrationRepository.takenEmail;
      await expectLater(
        repository.register(form.toData(locale: 'ar'), form.license!),
        throwsA(isA<Object>().having((e) => '$e', 'error', contains('EMAIL_ALREADY_REGISTERED'))),
      );
    });

    test('a rejected doctor resubmits and becomes pending again', () async {
      final auth = FakeAuthRepository(delay: Duration.zero);
      await auth.login(identifier: 'rejected@el3yada.dev', password: 'dev');
      final repository = FakeRegistrationRepository(auth: auth, delay: Duration.zero);
      final before = await repository.myRegistration();
      expect(before.status, DoctorStatus.rejected);

      final form = RegistrationForm(resubmit: true)..prefill(before);
      final after = await repository.resubmit(form.toData(locale: 'ar'), null);
      expect(after.status, DoctorStatus.pendingApproval);
      expect(auth.current?.doctorStatus, DoctorStatus.pendingApproval);
      expect(auth.current?.doctorStatusReason, isNull);
    });
  });
}
