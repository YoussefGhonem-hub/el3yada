import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/admin_models.dart';
import 'fake_admin_repository.dart';

/// The Phase 1 admin endpoints (backend/docs/api-phase-1.md, "Admin").
/// Every method throws [ApiException].
abstract interface class AdminRepository {
  /// AD2, the doctors: every doctor (`status=all`), or with [trial] those
  /// whose free trial is running or has ended. New doctors are active at
  /// once (backend/docs/api-free-trial.md); only legacy sign-ups are still
  /// pending or rejected. [sort] is `newest` or `oldest`.
  Future<Paged<RegistrationSummary>> doctorRegistrations({
    String? search,
    String sort = 'newest',
    TrialFilter? trial,
    int page = 1,
    int pageSize = 25,
  });

  /// AD3: the registration and its earlier reviews.
  Future<RegistrationDetail> doctorRegistration(String doctorId);

  /// AD3 license viewer. The API writes a `doctorLicenseViewed` audit row.
  Future<LicenseFile> doctorLicense(String doctorId);

  /// `reviewDoctorRegistration`, for legacy sign-ups still pending. [reason]
  /// (3–500 characters) is required to reject. Approving starts the trial.
  Future<DoctorRegistration> reviewDoctorRegistration({
    required String doctorId,
    required ReviewDecision decision,
    String? reason,
  });

  /// BR-G4: suspends an active doctor ([suspended] true) or reactivates a
  /// suspended one, with a [reason] (3–500 characters). Any admin. A doctor
  /// who is pending, rejected or disabled answers 409
  /// `DOCTOR_STATUS_NOT_CHANGEABLE`. The AD5 screen comes in Phase 7.
  Future<DoctorStatusView> setDoctorStatus(String doctorId, {required bool suspended, required String reason});

  /// BR-T5: ends the free trial and turns the service on (per-session fees
  /// from now on). 409 `DOCTOR_STATUS_NOT_CHANGEABLE` unless the doctor is
  /// active or suspended.
  Future<DoctorTrialView> activateDoctorService(String doctorId);

  /// BR-T5: [days] (1–90) more, from the later of the trial's end and now.
  /// 409 `SERVICE_ALREADY_ACTIVE` when there is no trial.
  Future<DoctorTrialView> extendDoctorTrial(String doctorId, {required int days});

  /// AD14 (super admin only).
  Future<List<AdminUser>> admins();

  Future<CreatedAdmin> createAdmin({required String email, required String displayName, required AdminRole role});

  Future<AdminUser> setAdminRole(String userId, AdminRole role);

  /// [active] false disables the admin and signs them out everywhere.
  Future<AdminUser> setAdminStatus(String userId, {required bool active});

  /// AD18.
  Future<AdminProfile> profile();

  Future<AdminProfile> updateAdminProfile(String displayName);

  /// AD15, newest first.
  Future<Paged<AuditEntry>> auditLogs(AuditFilter filter, {int page = 1, int pageSize = 25});

  /// AD13.
  Future<PlatformSettings> settings();

  /// Sends only [changes] (field name → wire value; null clears an optional
  /// text). Nothing is saved when one field fails.
  Future<PlatformSettings> updateSettings(Map<String, Object?> changes);

  /// One field's history ([field]), or every field's; newest first.
  Future<Paged<SettingsHistoryEntry>> settingsHistory({String? field, int page = 1, int pageSize = 25});

  /// One history entry with the full values.
  Future<SettingsHistoryEntry> settingsHistoryEntry(String id);
}

/// Real API, or the offline sample data when `USE_FAKE_AUTH` is on (dev
/// builds and tests), like `authRepositoryProvider`.
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  if (Env.useFakeAuth) {
    return FakeAdminRepository(currentAdmin: () {
      final session = ref.read(authControllerProvider).value;
      return session == null ? null : (session.userId, session.displayName, session.email, session.isSuperAdmin);
    });
  }
  return ApiAdminRepository(ref.watch(dioProvider));
});

/// Talks to the ASP.NET Core API.
class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._dio);

  final Dio _dio;

  @override
  Future<Paged<RegistrationSummary>> doctorRegistrations({
    String? search,
    String sort = 'newest',
    TrialFilter? trial,
    int page = 1,
    int pageSize = 25,
  }) =>
      _call(() async => Paged.fromJson(
            await _get('/admin/doctorRegistrations', {
              'status': 'all',
              'trial': ?trial?.name,
              if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
              'sort': sort,
              'page': page,
              'pageSize': pageSize,
            }),
            RegistrationSummary.fromJson,
          ));

  @override
  Future<RegistrationDetail> doctorRegistration(String doctorId) =>
      _call(() async => RegistrationDetail.fromJson(await _get('/admin/doctorRegistrations/$doctorId')));

  @override
  Future<LicenseFile> doctorLicense(String doctorId) => _call(() async {
        final response = await _dio.get<List<int>>(
          '/admin/doctorRegistrations/$doctorId/license',
          options: Options(responseType: ResponseType.bytes),
        );
        return LicenseFile(
          bytes: Uint8List.fromList(response.data ?? const []),
          contentType: response.headers.value(Headers.contentTypeHeader)?.split(';').first.trim() ??
              'application/octet-stream',
        );
      });

  @override
  Future<DoctorRegistration> reviewDoctorRegistration({
    required String doctorId,
    required ReviewDecision decision,
    String? reason,
  }) =>
      _call(() async => DoctorRegistration.fromJson(await _post('/admin/reviewDoctorRegistration', {
            'doctorId': doctorId,
            'decision': decision.name,
            'reason': ?reason,
          })));

  @override
  Future<DoctorStatusView> setDoctorStatus(String doctorId, {required bool suspended, required String reason}) =>
      _call(() async => DoctorStatusView.fromJson(await _post('/admin/setDoctorStatus', {
            'doctorId': doctorId,
            'status': suspended ? DoctorStatuses.suspended : DoctorStatuses.active,
            'reason': reason,
          })));

  @override
  Future<DoctorTrialView> activateDoctorService(String doctorId) => _call(() async =>
      DoctorTrialView.fromJson(await _post('/admin/activateDoctorService', {'doctorId': doctorId})));

  @override
  Future<DoctorTrialView> extendDoctorTrial(String doctorId, {required int days}) => _call(() async =>
      DoctorTrialView.fromJson(await _post('/admin/extendDoctorTrial', {'doctorId': doctorId, 'days': days})));

  @override
  Future<List<AdminUser>> admins() => _call(() async {
        final response = await _dio.get<List<dynamic>>('/admin/admins');
        return [for (final row in response.data ?? const []) AdminUser.fromJson((row as Map).cast<String, dynamic>())];
      });

  @override
  Future<CreatedAdmin> createAdmin({required String email, required String displayName, required AdminRole role}) =>
      _call(() async => CreatedAdmin.fromJson(await _post('/admin/createAdmin', {
            'email': email,
            'displayName': displayName,
            'adminRole': role.name,
          })));

  @override
  Future<AdminUser> setAdminRole(String userId, AdminRole role) => _call(
      () async => AdminUser.fromJson(await _post('/admin/setAdminRole', {'userId': userId, 'adminRole': role.name})));

  @override
  Future<AdminUser> setAdminStatus(String userId, {required bool active}) => _call(() async => AdminUser.fromJson(
      await _post('/admin/setAdminStatus', {'userId': userId, 'status': active ? 'active' : 'disabled'})));

  @override
  Future<AdminProfile> profile() => _call(() async => AdminProfile.fromJson(await _get('/admin/profile')));

  @override
  Future<AdminProfile> updateAdminProfile(String displayName) => _call(
      () async => AdminProfile.fromJson(await _post('/admin/updateAdminProfile', {'displayName': displayName})));

  @override
  Future<Paged<AuditEntry>> auditLogs(AuditFilter filter, {int page = 1, int pageSize = 25}) =>
      _call(() async => Paged.fromJson(
            await _get('/admin/auditLogs', {...filter.toQuery(), 'page': page, 'pageSize': pageSize}),
            AuditEntry.fromJson,
          ));

  @override
  Future<PlatformSettings> settings() => _call(() async => PlatformSettings.fromJson(await _get('/admin/settings')));

  @override
  Future<PlatformSettings> updateSettings(Map<String, Object?> changes) =>
      _call(() async => PlatformSettings.fromJson(await _post('/admin/updateSettings', changes)));

  @override
  Future<Paged<SettingsHistoryEntry>> settingsHistory({String? field, int page = 1, int pageSize = 25}) =>
      _call(() async => Paged.fromJson(
            await _get('/admin/settingsHistory', {'field': ?field, 'page': page, 'pageSize': pageSize}),
            SettingsHistoryEntry.fromJson,
          ));

  @override
  Future<SettingsHistoryEntry> settingsHistoryEntry(String id) =>
      _call(() async => SettingsHistoryEntry.fromJson(await _get('/admin/settingsHistory/$id')));

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
      // A file download gets its problem+json error as bytes: read it as JSON.
      final response = error.response;
      if (response != null && response.data is List<int>) {
        try {
          response.data = jsonDecode(utf8.decode(response.data as List<int>));
        } on FormatException {
          // Not JSON: the status alone tells what happened.
        }
      }
      throw ApiException.fromDio(error);
    }
  }
}
