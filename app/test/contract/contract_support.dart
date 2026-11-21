import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/appointments/data/appointments_repository.dart';
import 'package:el3yada/features/admin/data/admin_repository.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/clinic_admin/data/clinic_admin_repository.dart';
import 'package:el3yada/features/doctor_registration/data/registration_repository.dart';
import 'package:el3yada/features/doctor_registration/domain/doctor_registration.dart';
import 'package:el3yada/features/doctor_registration/domain/license_file.dart';
import 'package:el3yada/features/patients/data/patients_repository.dart';
import 'package:el3yada/features/sessions/data/sessions_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helpers shared by the contract tests in this folder (`api_contract_test.dart`
/// runs them all in one isolate, in order).

final _random = Random();

/// A new Egyptian mobile number in the local form (`010XXXXXXXX`).
String contractMobile() =>
    '010${List.generate(8, (_) => _random.nextInt(10)).join()}';

/// `010 1234 5678` → `+201012345678`, as the API answers.
String contractE164(String local) => '+2${local.replaceAll(' ', '')}';

/// A suffix that makes this run's emails, names and license numbers unique.
String contractRunId() =>
    '${DateTime.now().millisecondsSinceEpoch}${_random.nextInt(1000)}';

/// The `device` object of sign-in calls.
Map<String, dynamic> contractDevice(String who, String run) => {
  'deviceId': 'contract-$who-$run',
  'platform': 'android',
  'appVersion': '1.0.0',
};

Dio contractClient(String? baseUrl) => Dio(
  BaseOptions(baseUrl: '$baseUrl/api', headers: {'Accept': 'application/json'}),
);

/// One signed-in person: their own client, token and repositories.
class ContractAccount {
  ContractAccount(String? baseUrl, this.plain) : dio = contractClient(baseUrl) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
    auth = ApiAuthRepository(dio, plain);
  }

  final Dio dio;

  /// Without a token: sign-in, refresh, registration.
  final Dio plain;
  String? token;
  late final ApiAuthRepository auth;
  late final admin = ApiAdminRepository(dio);
  late final clinic = ApiClinicRepository(dio);
  late final clinicAdmin = ApiClinicAdminRepository(dio);
  late final appointments = ApiAppointmentsRepository(dio);
  late final patients = ApiPatientsRepository(dio);
  late final sessions = ApiSessionsRepository(dio);
  late final registration = ApiRegistrationRepository(dio, plain);
}

/// What the Phase 2 clinic day leaves for the tests after it. Filled in as
/// its tests run; the later groups read it.
class ClinicDay {
  ClinicDay(this.baseUrl);

  final String? baseUrl;

  // Lazy: without the variables the tests skip, and a client needs a valid URL.
  late final plain = contractClient(baseUrl);
  late final admin = ContractAccount(baseUrl, plain);
  late final doctor = ContractAccount(baseUrl, plain);

  late final String run;
  late final String doctorEmail;
  late final String doctorPassword;
  late final String doctorId;

  /// The Cairo day of the API (`YYYY-MM-DD`).
  late final String today;

  /// The default branch, from the sign-up.
  late final String maadiId;

  /// The second branch: not the default.
  late final String dokkiId;

  /// منة حسن, the doctor's first patient (file 1), with her details (D7).
  late final String patientId;

  /// Her number now (the clinic day moves it once).
  late String patientPhone;
}

/// Signs in as the seeded admin: with [password] when an earlier run (or
/// the Phase 1 test) already set it, else with the temporary password and A9.
Future<AuthSession> signInAdmin(
  ContractAccount admin,
  String email,
  String temporaryPassword,
  String password,
  Map<String, dynamic> device,
) async {
  try {
    final result = await admin.auth.login(
      identifier: email,
      password: password,
      device: device,
    );
    return (result as SignedIn).session;
  } on ApiException catch (error) {
    if (error.code != ApiCodes.invalidCredentials) rethrow;
  }
  final first = await admin.auth.login(
    identifier: email,
    password: temporaryPassword,
    device: device,
  );
  admin.token = (first as SignedIn).session.accessToken;
  return admin.auth.setNewPassword(newPassword: password, device: device);
}

/// A doctor's sign-up (A4) with its first branch, «فرع المعادي». Every
/// contract test that signs a doctor up uses this one branch address.
RegistrationData doctorRegistration({
  required String fullName,
  String? fullNameEn,
  required String email,
  required String phone,
  required String password,
  required String licenseNumber,
  required String specialtyId,
  required Map<String, dynamic> device,
}) => RegistrationData(
  fullName: fullName,
  email: email,
  phone: phone,
  password: password,
  locale: 'ar',
  title: 'استشاري',
  specialtyId: specialtyId,
  licenseNumber: licenseNumber,
  fullNameEn: fullNameEn,
  examinationPricePiasters: 30000,
  consultationPricePiasters: 15000,
  branch: const RegistrationBranch(
    nameAr: 'فرع المعادي',
    governorate: 'القاهرة',
    city: 'المعادي',
    addressDetails: 'شارع 9',
    landmark: 'بجوار المترو',
    phones: [BranchPhone(number: '02 2358 1234', label: BranchPhone.landline)],
  ),
  acceptTerms: true,
  device: device,
);

/// The license part of a sign-up: a real 1×1 PNG.
LicenseFile contractLicense() => LicenseFile(
  bytes: base64Decode(_onePixelPng),
  name: 'license.png',
  contentType: LicenseFile.png,
);

/// Another doctor with a clinic of their own: signs up with
/// [doctorRegistration] and is active at once, in a free trial (no
/// approval: backend/docs/api-free-trial.md), then signs in. Returns their
/// session; [doctor] holds its token.
Future<AuthSession> signUpDoctor({
  required ContractAccount doctor,
  required String fullName,
  required String email,
  required String password,
  required Map<String, dynamic> device,
}) async {
  final specialties = await doctor.registration.specialties();
  final registered = await doctor.registration.register(
    doctorRegistration(
      fullName: fullName,
      email: email,
      phone: contractMobile(),
      password: password,
      licenseNumber: 'C${contractRunId().substring(4, 13)}',
      specialtyId: specialties.first.id,
      device: device,
    ),
    contractLicense(),
  );
  expect(registered.doctorStatus, DoctorStatus.active);
  expect(registered.trial?.ended, isFalse);
  final signedIn = await doctor.auth.login(
    identifier: email,
    password: password,
    device: device,
  );
  final session = (signedIn as SignedIn).session;
  expect(session.doctorStatus, DoctorStatus.active);
  expect(session.trial?.endsAt, registered.trial?.endsAt);
  doctor.token = session.accessToken;
  return session;
}

TypeMatcher<ApiException> apiError(int status, String code) =>
    isA<ApiException>()
        .having((e) => e.status, 'status', status)
        .having((e) => e.code, 'code', code);

/// A 1×1 PNG: a real image, for the license part.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
