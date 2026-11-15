import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/patient_models.dart';
import 'fake_clinic_records.dart';

/// Patients, the medical profile and the register
/// (backend/docs/api-phase-2-patients.md). Every method throws [ApiException].
abstract interface class PatientsRepository {
  /// D5 pre-check. [phone] in any accepted mobile form.
  Future<PhoneLookup> lookupPhone(String phone);

  /// D5, AS3: a new account (BR-P4) or a link to an existing one (BR-P3).
  /// 409 `PATIENT_ALREADY_LINKED` when it is already this doctor's patient.
  Future<CreatedPatient> createPatient(PatientDraft draft);

  /// D6 header and file summary.
  Future<PatientView> patient(String patientId);

  /// D7 identity, except the phone. Send the whole form.
  Future<PatientView> updatePatient(String patientId, PatientDraft draft);

  /// D7 phone change. 409 `PATIENT_PHONE_TAKEN`.
  Future<PatientView> updatePatientPhone(String patientId, String phone);

  /// BR-P5: the new temporary password, shown once.
  Future<String> resetPatientPassword(String patientId);

  /// BR-P7 [S].
  Future<PatientView> setArchived(String patientId, {required bool archived});

  /// `clinicalView`.
  Future<MedicalProfile> medicalProfile(String patientId);

  /// `clinicalEditProfile`. Replaces the whole profile.
  Future<MedicalProfile> updateMedicalProfile(String patientId, MedicalProfileDraft draft);

  /// D4, AS2.
  Future<Paged<PatientRegisterRow>> register(RegisterQuery query, {int page = 1, int pageSize = 25});
}

class ApiPatientsRepository implements PatientsRepository {
  ApiPatientsRepository(this._dio);

  final Dio _dio;

  @override
  Future<PhoneLookup> lookupPhone(String phone) =>
      _call(() async => PhoneLookup.fromJson(await _get('/patients/lookupPhone', {'phone': phone})));

  @override
  Future<CreatedPatient> createPatient(PatientDraft draft) =>
      _call(() async => CreatedPatient.fromJson(await _post('/patients/createPatient', draft.toJson())));

  @override
  Future<PatientView> patient(String patientId) =>
      _call(() async => PatientView.fromJson(await _get('/patients/$patientId')));

  @override
  Future<PatientView> updatePatient(String patientId, PatientDraft draft) => _call(() async => PatientView.fromJson(
      await _post('/patients/updatePatient', {'patientId': patientId, ...draft.toJson()..remove('phone')})));

  @override
  Future<PatientView> updatePatientPhone(String patientId, String phone) => _call(() async =>
      PatientView.fromJson(await _post('/patients/updatePatientPhone', {'patientId': patientId, 'phone': phone})));

  @override
  Future<String> resetPatientPassword(String patientId) => _call(() async =>
      (await _post('/patients/resetPatientPassword', {'patientId': patientId}))['temporaryPassword'] as String);

  @override
  Future<PatientView> setArchived(String patientId, {required bool archived}) => _call(() async =>
      PatientView.fromJson(await _post('/patients/setArchived', {'patientId': patientId, 'archived': archived})));

  @override
  Future<MedicalProfile> medicalProfile(String patientId) =>
      _call(() async => MedicalProfile.fromJson(await _get('/patients/$patientId/medicalProfile')));

  @override
  Future<MedicalProfile> updateMedicalProfile(String patientId, MedicalProfileDraft draft) =>
      _call(() async => MedicalProfile.fromJson(await _post('/patients/updateMedicalProfile', draft.toJson(patientId))));

  @override
  Future<Paged<PatientRegisterRow>> register(RegisterQuery query, {int page = 1, int pageSize = 25}) =>
      _call(() async => Paged.fromJson(
            await _get('/patients/register', {...query.toQuery(), 'page': page, 'pageSize': pageSize}),
            PatientRegisterRow.fromJson,
          ));

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final response = await _dio.post<Map<String, dynamic>>(path, data: body);
    return response.data ?? const {};
  }

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// The real API, or the offline records when `USE_FAKE_AUTH` is on (dev
/// builds and tests), like `adminRepositoryProvider`.
final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  if (Env.useFakeAuth) return ref.watch(fakeClinicRecordsProvider);
  return ApiPatientsRepository(ref.watch(dioProvider));
});
