import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/patient_models.dart';
import 'fake_patient_repository.dart';

/// Filters shared by the visits, prescriptions and files lists.
class PatientListFilter {
  const PatientListFilter({this.doctorId, this.branchId, this.kind, this.from, this.to});

  final String? doctorId;
  final String? branchId;

  /// Prescriptions: `medication` or `investigations`. Files: a [RecordCategory] name.
  final String? kind;
  final DateTime? from;
  final DateTime? to;

  Map<String, dynamic> toQuery(int page, int pageSize) => {
        'page': page,
        'pageSize': pageSize,
        if (doctorId != null) 'doctorId': doctorId,
        if (branchId != null) 'branchId': branchId,
        if (kind != null) 'kind': kind,
        if (from != null) 'from': _day(from!),
        if (to != null) 'to': _day(to!),
      };

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is PatientListFilter &&
      other.doctorId == doctorId &&
      other.branchId == branchId &&
      other.kind == kind &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(doctorId, branchId, kind, from, to);
}

/// The patient app's API (spec 9.1, `/api/patient`). Read-only except the "New" badges,
/// preferences and the deletion request.
abstract interface class PatientRepository {
  static const pageSize = 25;

  Future<PatientHome> home({String? doctorId});
  Future<List<MyDoctor>> myDoctors();
  Future<DoctorInfo> doctor(String doctorId);

  Future<Paged<VisitListItem>> visits(PatientListFilter filter, {int page = 1});

  /// The branches the patient has visits in, most visited first (P4 branch filter).
  Future<List<VisitBranchOption>> visitBranches({String? doctorId});
  Future<VisitDetail> visit(String id);

  Future<Paged<PrescriptionListItem>> prescriptions(PatientListFilter filter, {int page = 1});
  Future<PrescriptionDetail> prescription(String id);
  Future<Uint8List> prescriptionPdf(String id);

  Future<Paged<RecordListItem>> records(PatientListFilter filter, {int page = 1});

  /// The P8 tab counts for [filter]'s doctor and date range (its kind is ignored).
  Future<RecordCounts> recordCounts(PatientListFilter filter);
  Future<RecordDetail> record(String id);
  Future<Uint8List> attachment(String recordId, String attachmentId, {bool thumbnail = false});

  Future<MedicalProfile> medicalProfile();

  /// Clears "New" badges. Unknown ids are ignored by the API.
  Future<void> markSeen({List<String> visits, List<String> prescriptions, List<String> files});

  Future<PatientAccount> account();
  Future<void> updateNotificationPrefs(NotificationPrefs prefs);

  /// Saves the language and appearance on the account (used for pushes, spec 10.1).
  Future<void> updateAppearance({String? locale, String? themeMode});
  Future<void> acceptTerms();
  Future<DeletionRequest> requestAccountDeletion(String? reason);
}

class ApiPatientRepository implements PatientRepository {
  ApiPatientRepository(this._dio);

  final Dio _dio;

  Future<T> _get<T>(String path, T Function(Object? data) parse, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<Object?>(path, queryParameters: query);
      return parse(response.data);
    } on DioException catch (error) {
      throw ApiError.from(error);
    }
  }

  Future<Uint8List> _bytes(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (error) {
      throw ApiError.from(error);
    }
  }

  Future<Object?> _send(String method, String path, Object? body) async {
    try {
      final response = await _dio.request<Object?>(path, data: body, options: Options(method: method));
      return response.data;
    } on DioException catch (error) {
      throw ApiError.from(error);
    }
  }

  @override
  Future<PatientHome> home({String? doctorId}) => _get(
        '/api/patient/home',
        (d) => PatientHome.fromJson(d as Json),
        query: {'doctorId': ?doctorId},
      );

  @override
  Future<List<MyDoctor>> myDoctors() => _get(
        '/api/patient/doctors',
        (d) => [for (final item in d as List<dynamic>) MyDoctor.fromJson(item as Json)],
      );

  @override
  Future<DoctorInfo> doctor(String doctorId) =>
      _get('/api/patient/doctors/$doctorId', (d) => DoctorInfo.fromJson(d as Json));

  @override
  Future<Paged<VisitListItem>> visits(PatientListFilter filter, {int page = 1}) => _get(
        '/api/patient/visits',
        (d) => Paged.fromJson(d as Json, VisitListItem.fromJson),
        query: filter.toQuery(page, PatientRepository.pageSize),
      );

  @override
  Future<List<VisitBranchOption>> visitBranches({String? doctorId}) => _get(
        '/api/patient/visits/branches',
        (d) => [for (final item in d as List<dynamic>) VisitBranchOption.fromJson(item as Json)],
        query: {'doctorId': ?doctorId},
      );

  @override
  Future<VisitDetail> visit(String id) => _get('/api/patient/visits/$id', (d) => VisitDetail.fromJson(d as Json));

  @override
  Future<Paged<PrescriptionListItem>> prescriptions(PatientListFilter filter, {int page = 1}) => _get(
        '/api/patient/prescriptions',
        (d) => Paged.fromJson(d as Json, PrescriptionListItem.fromJson),
        query: filter.toQuery(page, PatientRepository.pageSize),
      );

  @override
  Future<PrescriptionDetail> prescription(String id) =>
      _get('/api/patient/prescriptions/$id', (d) => PrescriptionDetail.fromJson(d as Json));

  @override
  Future<Uint8List> prescriptionPdf(String id) => _bytes('/api/patient/prescriptions/$id/pdf');

  @override
  Future<Paged<RecordListItem>> records(PatientListFilter filter, {int page = 1}) => _get(
        '/api/patient/records',
        (d) => Paged.fromJson(d as Json, RecordListItem.fromJson),
        query: filter.toQuery(page, PatientRepository.pageSize),
      );

  @override
  Future<RecordCounts> recordCounts(PatientListFilter filter) => _get(
        '/api/patient/records/counts',
        (d) => RecordCounts.fromJson(d as Json),
        query: {
          'doctorId': ?filter.doctorId,
          if (filter.from != null) 'from': PatientListFilter._day(filter.from!),
          if (filter.to != null) 'to': PatientListFilter._day(filter.to!),
        },
      );

  @override
  Future<RecordDetail> record(String id) => _get('/api/patient/records/$id', (d) => RecordDetail.fromJson(d as Json));

  @override
  Future<Uint8List> attachment(String recordId, String attachmentId, {bool thumbnail = false}) => _bytes(
        '/api/patient/records/$recordId/attachments/$attachmentId',
        query: {if (thumbnail) 'thumbnail': true},
      );

  @override
  Future<MedicalProfile> medicalProfile() =>
      _get('/api/patient/medical-profile', (d) => MedicalProfile.fromJson(d as Json));

  @override
  Future<void> markSeen({List<String> visits = const [], List<String> prescriptions = const [], List<String> files = const []}) async {
    if (visits.isEmpty && prescriptions.isEmpty && files.isEmpty) return;
    await _send('POST', '/api/patient/seen', {'visits': visits, 'prescriptions': prescriptions, 'files': files});
  }

  @override
  Future<PatientAccount> account() => _get('/api/patient/account', (d) => PatientAccount.fromJson(d as Json));

  @override
  Future<void> updateNotificationPrefs(NotificationPrefs prefs) => _send('PATCH', '/api/me/preferences', {
        'notifyChat': prefs.chat,
        'notifyReminders': prefs.reminders,
        'notifyShowPreview': prefs.showPreview,
      });

  @override
  Future<void> updateAppearance({String? locale, String? themeMode}) => _send('PATCH', '/api/me/preferences', {
        'locale': ?locale,
        'themeMode': ?themeMode,
      });

  @override
  Future<void> acceptTerms() => _send('POST', '/api/me/accept-terms', null);

  @override
  Future<DeletionRequest> requestAccountDeletion(String? reason) async =>
      DeletionRequest.fromJson(await _send('POST', '/api/patient/deletion-request', {'reason': reason}) as Json);
}

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  // Dev builds with the offline test accounts get offline data too: their tokens aren't real.
  if (Env.useFakeAuth) return FakePatientRepository();
  return ApiPatientRepository(ref.watch(dioProvider));
});
