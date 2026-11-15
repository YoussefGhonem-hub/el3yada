import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/validation/validators.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';
import '../domain/doctor_registration.dart';
import '../domain/license_file.dart';
import '../domain/specialty.dart';

/// Error codes of the registration endpoints that screens react to.
abstract final class RegistrationCodes {
  static const emailAlreadyRegistered = 'EMAIL_ALREADY_REGISTERED';
  static const registrationNotEditable = 'REGISTRATION_NOT_EDITABLE';
  static const requestTooLarge = 'REQUEST_TOO_LARGE';
}

/// Doctor registration (A4–A7) and the specialty list. Contract:
/// backend/docs/api-phase-1.md, "Doctor registration (A4–A7)" and "Public".
/// Every method throws [ApiException].
abstract interface class RegistrationRepository {
  /// `GET /api/specialties`: the active specialties in the admin's order.
  Future<List<Specialty>> specialties();

  /// A4 Submit: creates the account with status `pendingApproval` and
  /// answers with its session (the app then opens A6).
  Future<AuthSession> register(RegistrationData data, LicenseFile license);

  /// A6 and A7: the signed-in doctor's registration.
  Future<DoctorRegistration> myRegistration();

  /// The license file the doctor uploaded, or null when it is missing.
  Future<LicenseFile?> myLicense();

  /// A7 "Edit and resubmit". [license] only when it is replaced.
  Future<DoctorRegistration> resubmit(RegistrationData data, LicenseFile? license);
}

class ApiRegistrationRepository implements RegistrationRepository {
  ApiRegistrationRepository(this._dio, this._plain);

  /// Signed in (A6, A7).
  final Dio _dio;

  /// Anonymous (the specialties, A4).
  final Dio _plain;

  @override
  Future<List<Specialty>> specialties() => _call(() async {
        final response = await _plain.get<List<dynamic>>('/specialties');
        return [
          for (final item in response.data ?? const [])
            Specialty.fromJson((item as Map).cast<String, dynamic>()),
        ];
      });

  @override
  Future<AuthSession> register(RegistrationData data, LicenseFile license) => _call(() async {
        final response = await _plain.post<Map<String, dynamic>>(
          '/doctors/completeDoctorRegistration',
          data: _form(data, license),
        );
        return AuthSession.fromJson(response.data ?? const {});
      });

  @override
  Future<DoctorRegistration> myRegistration() => _call(() async {
        final response = await _dio.get<Map<String, dynamic>>('/doctors/myRegistration');
        return DoctorRegistration.fromJson(response.data ?? const {});
      });

  @override
  Future<LicenseFile?> myLicense() async {
    try {
      final response = await _dio.get<List<int>>(
        '/doctors/myRegistration/license',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      final type = LicenseFile.detectType(bytes) ?? response.headers.value('content-type') ?? '';
      return LicenseFile(bytes: bytes, name: 'license', contentType: type);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw ApiException.fromDio(error);
    }
  }

  @override
  Future<DoctorRegistration> resubmit(RegistrationData data, LicenseFile? license) => _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/doctors/resubmitDoctorRegistration',
          data: _form(data, license),
        );
        return DoctorRegistration.fromJson(response.data ?? const {});
      });

  /// `multipart/form-data`: the JSON part `data` and the file part `license`.
  static FormData _form(RegistrationData data, LicenseFile? license) => FormData.fromMap({
        'data': jsonEncode(data.toJson()),
        if (license != null)
          'license': MultipartFile.fromBytes(
            license.bytes,
            filename: license.name,
            contentType: DioMediaType.parse(license.contentType),
          ),
      });

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// Offline registration for development and tests, used with
/// [FakeAuthRepository] when `USE_FAKE_AUTH` is true. It keeps the latest
/// registration in memory and updates the fake signed-in account, so A4 →
/// A6 → Refresh and A7 → resubmit → A6 work without a server.
///
/// `taken@el3yada.dev` answers 409 `EMAIL_ALREADY_REGISTERED`.
class FakeRegistrationRepository implements RegistrationRepository {
  FakeRegistrationRepository({this.auth, this.delay = const Duration(milliseconds: 400)});

  /// The fake sign-in whose account registration changes. Null in tests that
  /// only need the data.
  final FakeAuthRepository? auth;
  final Duration delay;

  static const takenEmail = 'taken@el3yada.dev';

  static const specialtyList = [
    Specialty(id: 'sp-internal', nameAr: 'باطنة', nameEn: 'Internal Medicine'),
    Specialty(id: 'sp-pediatrics', nameAr: 'أطفال وحديثي الولادة', nameEn: 'Pediatrics'),
    Specialty(id: 'sp-obgyn', nameAr: 'نساء وتوليد', nameEn: 'Obstetrics and Gynecology'),
    Specialty(id: 'sp-ortho', nameAr: 'عظام', nameEn: 'Orthopedics'),
    Specialty(id: 'sp-derma', nameAr: 'جلدية', nameEn: 'Dermatology'),
    Specialty(id: 'sp-ent', nameAr: 'أنف وأذن وحنجرة', nameEn: 'ENT'),
    Specialty(id: 'sp-ophtha', nameAr: 'رمد', nameEn: 'Ophthalmology'),
    Specialty(id: 'sp-cardio', nameAr: 'قلب وأوعية دموية', nameEn: 'Cardiology'),
    Specialty(id: 'sp-neuro', nameAr: 'مخ وأعصاب', nameEn: 'Neurology'),
    Specialty(id: 'sp-uro', nameAr: 'مسالك بولية', nameEn: 'Urology'),
    Specialty(id: 'sp-chest', nameAr: 'صدر', nameEn: 'Chest and Pulmonology'),
    Specialty(id: 'sp-gastro', nameAr: 'جهاز هضمي وكبد', nameEn: 'Gastroenterology and Hepatology'),
    Specialty(id: 'sp-endo', nameAr: 'غدد صماء وسكر', nameEn: 'Endocrinology and Diabetes'),
    Specialty(id: 'sp-nephro', nameAr: 'كلى', nameEn: 'Nephrology'),
    Specialty(id: 'sp-psych', nameAr: 'نفسية', nameEn: 'Psychiatry'),
    Specialty(id: 'sp-surgery', nameAr: 'جراحة عامة', nameEn: 'General Surgery'),
    Specialty(id: 'sp-dental', nameAr: 'أسنان', nameEn: 'Dentistry'),
    Specialty(id: 'sp-physio', nameAr: 'علاج طبيعي', nameEn: 'Physiotherapy'),
    Specialty(id: 'sp-gp', nameAr: 'ممارس عام', nameEn: 'General Practice'),
  ];

  /// Registrations by user ID. The offline accounts `pending@el3yada.dev` and
  /// `rejected@el3yada.dev` start with a sample one.
  final _registrations = <String, DoctorRegistration>{};
  final _licenses = <String, LicenseFile>{};

  /// The latest data sent to [register] or [resubmit] (for tests).
  RegistrationData? lastData;

  /// The latest license sent (null when a resubmission kept the old one).
  LicenseFile? lastLicense;

  @override
  Future<List<Specialty>> specialties() async {
    await Future<void>.delayed(delay);
    return specialtyList;
  }

  @override
  Future<AuthSession> register(RegistrationData data, LicenseFile license) async {
    await Future<void>.delayed(delay);
    lastData = data;
    lastLicense = license;
    if (data.email.trim().toLowerCase() == takenEmail) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: RegistrationCodes.emailAlreadyRegistered);
    }
    final userId = 'dev-doctor-${data.email.hashCode.abs()}';
    final session = AuthSession(
      userId: userId,
      displayName: data.fullName,
      role: UserRole.doctor,
      doctorId: userId,
      doctorStatus: DoctorStatus.pendingApproval,
      email: data.email.trim().toLowerCase(),
      emailVerified: false,
      phone: Validators.normalizeEgyptianMobile(data.phone),
      locale: data.locale,
      accessToken: 'dev-access-token',
      refreshToken: 'dev-refresh-token',
    );
    _registrations[userId] = _view(userId, data, license.contentType, DoctorStatus.pendingApproval);
    _licenses[userId] = license;
    auth?.current = session;
    return session;
  }

  @override
  Future<DoctorRegistration> myRegistration() async {
    await Future<void>.delayed(delay);
    return _registrations[_userId] ??= _sample();
  }

  @override
  Future<LicenseFile?> myLicense() async {
    await Future<void>.delayed(delay);
    return _licenses[_userId];
  }

  @override
  Future<DoctorRegistration> resubmit(RegistrationData data, LicenseFile? license) async {
    await Future<void>.delayed(delay);
    lastData = data;
    lastLicense = license;
    final userId = _userId;
    final previous = _registrations[userId] ?? _sample();
    if (previous.status != DoctorStatus.rejected) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: RegistrationCodes.registrationNotEditable);
    }
    if (license != null) _licenses[userId] = license;
    final view = _view(
      userId,
      data,
      license?.contentType ?? previous.licenseContentType,
      DoctorStatus.pendingApproval,
    ).copyWith(emailVerified: previous.emailVerified && previous.email == data.email.trim().toLowerCase());
    _registrations[userId] = view;
    final current = auth?.current;
    if (current != null) {
      auth!.current = current.copyWith(
        displayName: data.fullName,
        doctorStatus: DoctorStatus.pendingApproval,
        doctorStatusReason: null,
        email: view.email,
        emailVerified: view.emailVerified,
      );
    }
    return view;
  }

  String get _userId => auth?.current?.userId ?? 'dev-doctor';

  /// A sample registration for the offline accounts, in the state of the
  /// signed-in account (pending or rejected).
  DoctorRegistration _sample() {
    final session = auth?.current;
    final rejected = session?.doctorStatus == DoctorStatus.rejected;
    return DoctorRegistration(
      doctorId: _userId,
      status: session?.doctorStatus ?? DoctorStatus.pendingApproval,
      statusReason: rejected ? session?.doctorStatusReason : null,
      submittedAt: DateTime.utc(2026, 11, 14, 9, 30),
      fullName: 'سامي عبد الله',
      email: session?.email ?? 'pending@el3yada.dev',
      emailVerified: session?.emailVerified ?? false,
      phone: '+201012345678',
      title: 'استشاري',
      titleEn: 'Consultant',
      specialty: specialtyList[1],
      extraSpecialties: [specialtyList[0]],
      licenseNumber: '45678',
      licenseContentType: LicenseFile.jpeg,
      examinationPricePiasters: 30000,
      consultationPricePiasters: 15000,
      branch: const RegistrationBranch(
        id: 'dev-branch',
        nameAr: 'فرع المعادي',
        governorate: 'القاهرة',
        city: 'المعادي',
        street: 'شارع 9',
        building: '12',
        floor: '3',
        apartment: '5',
        landmark: 'بجوار محطة المترو',
        phones: [
          BranchPhone(number: '+20223581234', label: BranchPhone.landline),
          BranchPhone(number: '+201012345678', label: BranchPhone.mobile, isWhatsapp: true),
        ],
      ),
    );
  }

  DoctorRegistration _view(String userId, RegistrationData data, String? licenseType, DoctorStatus status) {
    Specialty byId(String id) => specialtyList.firstWhere((s) => s.id == id, orElse: () => Specialty(id: id));
    return DoctorRegistration(
      doctorId: userId,
      status: status,
      submittedAt: DateTime.now().toUtc(),
      fullName: data.fullName,
      email: data.email.trim().toLowerCase(),
      phone: Validators.normalizeEgyptianMobile(data.phone) ?? data.phone,
      locale: data.locale,
      title: data.title,
      titleEn: data.titleEn,
      fullNameEn: data.fullNameEn,
      degreesAr: data.degreesAr,
      degreesEn: data.degreesEn,
      specialty: byId(data.specialtyId),
      extraSpecialties: [for (final id in data.extraSpecialtyIds) byId(id)],
      licenseNumber: data.licenseNumber,
      licenseContentType: licenseType,
      examinationPricePiasters: data.examinationPricePiasters,
      consultationPricePiasters: data.consultationPricePiasters,
      branch: data.branch.copyWith(id: 'dev-branch'),
    );
  }
}

/// The registration API, or the offline fake with the fake sign-in.
final registrationRepositoryProvider = Provider<RegistrationRepository>((ref) {
  if (Env.useFakeAuth) {
    final auth = ref.watch(authRepositoryProvider);
    return auth is FakeAuthRepository
        ? FakeRegistrationRepository(auth: auth, delay: auth.delay)
        : FakeRegistrationRepository();
  }
  return ApiRegistrationRepository(ref.watch(dioProvider), ref.watch(plainDioProvider));
});
