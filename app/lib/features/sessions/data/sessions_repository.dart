import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/session_models.dart';
import '../../patients/data/fake_clinic_records.dart';

/// Sessions and the platform-fee totals (backend/docs/api-phase-2-patients.md,
/// "Sessions" and "Fees"). Every method throws [ApiException].
abstract interface class SessionsRepository {
  /// D6 Sessions tab, newest first.
  Future<Paged<SessionListItem>> patientSessions(String patientId, {int page = 1, int pageSize = 25});

  /// D8 step 1: the type cards, the BR-S4 message and the BR-S6 fee.
  Future<NewSessionInfo> newSessionInfo({required String patientId, required String branchId});

  /// D8 save, after the BR-S6 confirmation. 409 `CONSULTATION_REQUIRES_EXAM`
  /// when the rule refuses (someone else may have saved first, AC-2).
  Future<SessionView> createSession(NewSessionDraft draft);

  /// D9.
  Future<SessionView> session(String sessionId);

  /// Doctor only.
  Future<PrivateNote> privateNote(String sessionId);

  /// Doctor only. Empty text removes the note.
  Future<PrivateNote> setPrivateNote(String sessionId, String? text);

  /// Doctor only. Clears «بانتظار الطبيب» when a field is filled (BR-AS7).
  Future<SessionView> updateClinical(String sessionId, ClinicalDraft draft);

  /// BR-S10: on the session's day, by the doctor or whoever recorded it.
  Future<SessionView> updateAmountCharged(String sessionId, {required int amountChargedPiasters, PaymentMethod? paymentMethod});

  /// BR-S7. 409 `SESSION_NOT_DELETABLE` with a `reason`.
  Future<void> deleteSession(String sessionId, String reason);

  /// D2, AS1: one Cairo day (today when [day] is null).
  Future<DaySessions> day({DateTime? day, String? branchId, SessionType? type, String? recordedBy});

  /// D1 fee cards.
  Future<FeeSummary> feeSummary();

  /// D3 (this month when [month] is null).
  Future<MonthFees> month({DateTime? month, String? branchId});
}

class ApiSessionsRepository implements SessionsRepository {
  ApiSessionsRepository(this._dio);

  final Dio _dio;

  @override
  Future<Paged<SessionListItem>> patientSessions(String patientId, {int page = 1, int pageSize = 25}) =>
      _call(() async => Paged.fromJson(
            await _get('/patients/$patientId/sessions', {'page': page, 'pageSize': pageSize}),
            SessionListItem.fromJson,
          ));

  @override
  Future<NewSessionInfo> newSessionInfo({required String patientId, required String branchId}) => _call(() async =>
      NewSessionInfo.fromJson(await _get('/sessions/newSessionInfo', {'patientId': patientId, 'branchId': branchId})));

  @override
  Future<SessionView> createSession(NewSessionDraft draft) =>
      _call(() async => SessionView.fromJson(await _post('/sessions/createSession', draft.toJson())));

  @override
  Future<SessionView> session(String sessionId) => _call(() async => SessionView.fromJson(await _get('/sessions/$sessionId')));

  @override
  Future<PrivateNote> privateNote(String sessionId) =>
      _call(() async => PrivateNote.fromJson(await _get('/sessions/$sessionId/privateNote')));

  @override
  Future<PrivateNote> setPrivateNote(String sessionId, String? text) => _call(() async =>
      PrivateNote.fromJson(await _post('/sessions/setPrivateNote', {'sessionId': sessionId, 'text': text})));

  @override
  Future<SessionView> updateClinical(String sessionId, ClinicalDraft draft) =>
      _call(() async => SessionView.fromJson(await _post('/sessions/updateClinical', draft.toJson(sessionId))));

  @override
  Future<SessionView> updateAmountCharged(String sessionId, {required int amountChargedPiasters, PaymentMethod? paymentMethod}) =>
      _call(() async => SessionView.fromJson(await _post('/sessions/updateAmountCharged', {
            'sessionId': sessionId,
            'amountChargedPiasters': amountChargedPiasters,
            'paymentMethod': paymentMethod?.wire,
          })));

  @override
  Future<void> deleteSession(String sessionId, String reason) =>
      _call(() => _post('/sessions/deleteSession', {'sessionId': sessionId, 'reason': reason}));

  @override
  Future<DaySessions> day({DateTime? day, String? branchId, SessionType? type, String? recordedBy}) =>
      _call(() async => DaySessions.fromJson(await _get('/sessions/day', {
            if (day != null) 'day': dayKey(day),
            'branchId': ?branchId,
            'type': ?type?.wire,
            'recordedBy': ?recordedBy,
          })));

  @override
  Future<FeeSummary> feeSummary() => _call(() async => FeeSummary.fromJson(await _get('/sessions/feeSummary')));

  @override
  Future<MonthFees> month({DateTime? month, String? branchId}) => _call(() async => MonthFees.fromJson(
      await _get('/sessions/month', {if (month != null) 'month': monthKey(month), 'branchId': ?branchId})));

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

/// The real API, or the offline records when `USE_FAKE_AUTH` is on.
final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  if (Env.useFakeAuth) return ref.watch(fakeClinicRecordsProvider);
  return ApiSessionsRepository(ref.watch(dioProvider));
});
