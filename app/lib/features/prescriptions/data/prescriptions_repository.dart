import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/prescription_models.dart';
import 'fake_prescriptions.dart';

/// Prescriptions and requests, item history, templates and the D22 print
/// settings (backend/docs/api-phase-3-prescriptions.md). Every method throws
/// [ApiException].
abstract interface class PrescriptionsRepository {
  /// BR-RX1: a draft on one of the doctor's sessions, pre-filled from it.
  /// [copyFromId] is "Issue new copy" (D15).
  Future<Prescription> createDraft({required String sessionId, required PrescriptionKind kind, String? copyFromId});

  /// Everything replaced; items in display order. 409 `PRESCRIPTION_NOT_EDITABLE`.
  Future<Prescription> updateDraft(String prescriptionId, PrescriptionKind kind, PrescriptionDraftInput input);

  /// Discards a draft or a `readyForReview` document.
  Future<void> deleteDraft(String prescriptionId);

  /// AS7 «إرسال للطبيب للمراجعة». 409 `PRESCRIPTION_EMPTY`.
  Future<Prescription> submitForReview(String prescriptionId);

  /// D15 "Send to patient" (doctor only), with the PDF the app built.
  Future<Prescription> send(String prescriptionId, Uint8List pdf);

  /// Doctor only; 409 `PRESCRIPTION_NOT_SENT`.
  Future<Prescription> cancel(String prescriptionId, String reason);

  Future<Prescription> prescription(String prescriptionId);

  /// D9 and Print all: the session's documents, oldest first.
  Future<List<Prescription>> sessionPrescriptions(String sessionId);

  /// D6 Prescriptions tab, newest first.
  Future<Paged<Prescription>> patientPrescriptions(String patientId, {PrescriptionKind? kind, int page = 1, int pageSize = 25});

  /// The stored PDF (sent and cancelled documents): what Reprint prints.
  Future<Uint8List> pdf(String prescriptionId);

  /// "Used before" (BR-CAT4 group 1).
  Future<List<ItemHistoryEntry>> itemHistory();

  /// D23 [S].
  Future<void> deleteHistoryItem(String itemId);

  Future<List<PrescriptionTemplate>> templates({PrescriptionKind? kind});

  Future<PrescriptionTemplate> createTemplate({
    required String name,
    required PrescriptionKind kind,
    required PrescriptionDraftInput items,
    String? advice,
  });

  Future<PrescriptionTemplate> updateTemplate(PrescriptionTemplate template, {required String name});

  Future<void> deleteTemplate(String templateId);

  /// D22.
  Future<RxSettings> rxSettings();

  Future<RxSettings> updateRxSettings(RxSettings settings);

  /// JPEG, PNG or WebP ≤ 2 MB; stored as a PNG ≤ 1000 px.
  Future<RxSettings> uploadRxImage(RxImageKind kind, Uint8List bytes, String fileName);

  /// The PNG, or null when there is none.
  Future<Uint8List?> rxImage(RxImageKind kind);

  Future<RxSettings> deleteRxImage(RxImageKind kind);
}

class ApiPrescriptionsRepository implements PrescriptionsRepository {
  ApiPrescriptionsRepository(this._dio);

  final Dio _dio;

  @override
  Future<Prescription> createDraft({required String sessionId, required PrescriptionKind kind, String? copyFromId}) =>
      _call(() async => Prescription.fromJson(await _post('/prescriptions/createPrescriptionDraft', {
            'sessionId': sessionId,
            'kind': kind.wire,
            'copyFromId': copyFromId,
          })));

  @override
  Future<Prescription> updateDraft(String prescriptionId, PrescriptionKind kind, PrescriptionDraftInput input) =>
      _call(() async => Prescription.fromJson(
          await _post('/prescriptions/updatePrescriptionDraft', {'prescriptionId': prescriptionId, ...input.toJson(kind)})));

  @override
  Future<void> deleteDraft(String prescriptionId) =>
      _call(() => _post('/prescriptions/deletePrescriptionDraft', {'prescriptionId': prescriptionId}));

  @override
  Future<Prescription> submitForReview(String prescriptionId) => _call(() async =>
      Prescription.fromJson(await _post('/prescriptions/submitDraftForReview', {'prescriptionId': prescriptionId})));

  @override
  Future<Prescription> send(String prescriptionId, Uint8List pdf) => _call(() async {
        final form = FormData.fromMap({
          'data': jsonEncode({'prescriptionId': prescriptionId}),
          'pdf': MultipartFile.fromBytes(pdf, filename: 'prescription.pdf', contentType: DioMediaType('application', 'pdf')),
        });
        final response = await _dio.post<Map<String, dynamic>>('/prescriptions/sendPrescription', data: form);
        return Prescription.fromJson(response.data ?? const {});
      });

  @override
  Future<Prescription> cancel(String prescriptionId, String reason) => _call(() async => Prescription.fromJson(
      await _post('/prescriptions/cancelPrescription', {'prescriptionId': prescriptionId, 'reason': reason.trim()})));

  @override
  Future<Prescription> prescription(String prescriptionId) =>
      _call(() async => Prescription.fromJson(await _get('/prescriptions/$prescriptionId')));

  @override
  Future<List<Prescription>> sessionPrescriptions(String sessionId) => _call(() async {
        final response = await _dio.get<List<dynamic>>('/sessions/$sessionId/prescriptions');
        return [for (final row in response.data ?? const []) Prescription.fromJson((row as Map).cast<String, dynamic>())];
      });

  @override
  Future<Paged<Prescription>> patientPrescriptions(String patientId, {PrescriptionKind? kind, int page = 1, int pageSize = 25}) =>
      _call(() async => Paged.fromJson(
            await _get('/patients/$patientId/prescriptions', {'kind': ?kind?.wire, 'page': page, 'pageSize': pageSize}),
            Prescription.fromJson,
          ));

  @override
  Future<Uint8List> pdf(String prescriptionId) => _bytes('/prescriptions/$prescriptionId/pdf');

  @override
  Future<List<ItemHistoryEntry>> itemHistory() => _call(() async {
        final response = await _dio.get<List<dynamic>>('/prescriptions/itemHistory');
        return [for (final row in response.data ?? const []) ItemHistoryEntry.fromJson((row as Map).cast<String, dynamic>())];
      });

  @override
  Future<void> deleteHistoryItem(String itemId) => _call(() => _post('/prescriptions/deleteHistoryItem', {'itemId': itemId}));

  @override
  Future<List<PrescriptionTemplate>> templates({PrescriptionKind? kind}) => _call(() async {
        final response = await _dio.get<List<dynamic>>('/prescriptionTemplates', queryParameters: {'kind': ?kind?.wire});
        return [for (final row in response.data ?? const []) PrescriptionTemplate.fromJson((row as Map).cast<String, dynamic>())];
      });

  @override
  Future<PrescriptionTemplate> createTemplate({
    required String name,
    required PrescriptionKind kind,
    required PrescriptionDraftInput items,
    String? advice,
  }) =>
      _call(() async => PrescriptionTemplate.fromJson(await _post('/prescriptionTemplates/createTemplate', {
            'name': name.trim(),
            'kind': kind.wire,
            'items': items.toJson(kind)['items'],
            'advice': advice,
          })));

  @override
  Future<PrescriptionTemplate> updateTemplate(PrescriptionTemplate template, {required String name}) =>
      _call(() async => PrescriptionTemplate.fromJson(await _post('/prescriptionTemplates/updateTemplate', {
            'templateId': template.templateId,
            'name': name.trim(),
            'items': template.itemsJson(),
            'advice': template.advice,
          })));

  @override
  Future<void> deleteTemplate(String templateId) =>
      _call(() => _post('/prescriptionTemplates/deleteTemplate', {'templateId': templateId}));

  @override
  Future<RxSettings> rxSettings() => _call(() async => RxSettings.fromJson(await _get('/doctor/rxSettings')));

  @override
  Future<RxSettings> updateRxSettings(RxSettings settings) =>
      _call(() async => RxSettings.fromJson(await _post('/doctor/updateRxSettings', settings.toJson())));

  @override
  Future<RxSettings> uploadRxImage(RxImageKind kind, Uint8List bytes, String fileName) => _call(() async {
        final form = FormData.fromMap({
          'kind': kind.wire,
          'file': MultipartFile.fromBytes(bytes, filename: fileName),
        });
        final response = await _dio.post<Map<String, dynamic>>('/doctor/uploadRxImage', data: form);
        return RxSettings.fromJson(response.data ?? const {});
      });

  @override
  Future<Uint8List?> rxImage(RxImageKind kind) async {
    try {
      return await _bytes('/doctor/rxImage/${kind.wire}');
    } on ApiException catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<RxSettings> deleteRxImage(RxImageKind kind) =>
      _call(() async => RxSettings.fromJson(await _post('/doctor/deleteRxImage', {'kind': kind.wire})));

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object?> body) async {
    final response = await _dio.post<Object?>(path, data: body);
    final data = response.data;
    return data is Map ? data.cast<String, dynamic>() : const {};
  }

  Future<Uint8List> _bytes(String path) => _call(() async {
        final response = await _dio.get<List<int>>(path, options: Options(responseType: ResponseType.bytes));
        return Uint8List.fromList(response.data ?? const []);
      });

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// The real API, or the offline prescriptions when `USE_FAKE_AUTH` is on.
final prescriptionsRepositoryProvider = Provider<PrescriptionsRepository>((ref) {
  if (Env.useFakeAuth) return ref.watch(fakePrescriptionsProvider);
  return ApiPrescriptionsRepository(ref.watch(dioProvider));
});
