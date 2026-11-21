import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/admin_billing_models.dart';
import 'fake_admin_billing_repository.dart';

/// The admin's payments, invoices, doctors and dashboard (backend/docs/api-phase-7.md,
/// "Admin"). Every method throws [ApiException].
abstract interface class AdminBillingRepository {
  /// AD1.
  Future<AdminDashboard> dashboard();

  /// AD7 (the queue, oldest first) and the Payments tab of AD5 ([doctorId], [status] null = every status).
  Future<Paged<PaymentQueueItem>> payments({
    PaymentStatus? status,
    String? doctorId,
    int page = 1,
    int pageSize = 25,
  });

  /// AD8.
  Future<PaymentReview> payment(String paymentId);

  /// AD8's viewer: one image, by number from 1.
  Future<Uint8List> screenshot(String paymentId, int number);

  /// AD8 Approve. 409 `PAYMENT_ALREADY_REVIEWED`.
  Future<InvoiceState> approvePayment(String paymentId);

  /// AD8 Reject: [reason] is a preset or free text (3–500 characters).
  Future<InvoiceState> rejectPayment(String paymentId, String reason);

  /// AD9.
  Future<AdminInvoicesPage> invoices(
    InvoiceFilter filter, {
    int page = 1,
    int pageSize = 25,
  });

  /// AD10.
  Future<InvoiceDetail> invoice(String invoiceId);

  /// AD10 actions (BR-PAY4). Each needs a reason (3–500 characters).
  Future<InvoiceState> adjustInvoice(
    String invoiceId, {
    required int amountPiasters,
    required String reason,
  });
  Future<InvoiceState> waiveInvoice(String invoiceId, {required String reason});
  Future<InvoiceState> markInvoicePaid(
    String invoiceId, {
    required PaidMethod method,
    required String note,
  });
  Future<InvoiceState> extendInvoiceDueDate(
    String invoiceId, {
    required DateTime newDueDate,
    required String reason,
  });

  /// AD4.
  Future<Paged<DoctorListItem>> doctors(
    DoctorFilter filter, {
    int page = 1,
    int pageSize = 25,
  });

  /// AD5 tabs.
  Future<AdminDoctorProfile> doctorProfile(String doctorId);
  Future<DoctorActivity> doctorActivity(
    String doctorId, {
    String? month,
    int page = 1,
  });
  Future<DoctorAudit> doctorAudit(String doctorId);
  Future<List<DoctorBranchRow>> doctorBranches(String doctorId);
  Future<List<DoctorAppointmentsMonth>> doctorAppointments(String doctorId);
  Future<List<DoctorAssistantRow>> doctorAssistants(String doctorId);
  Future<List<DoctorNote>> doctorNotes(String doctorId);
  Future<void> addDoctorNote(String doctorId, String text);

  /// AD5 "Send password reset email".
  Future<void> sendPasswordReset(String doctorId);

  /// AD5 Suspend / Reactivate / Disable (`setDoctorStatus`): [status] is `suspended`, `active` or `disabled`.
  Future<void> setDoctorStatus(
    String doctorId, {
    required String status,
    required String reason,
  });
}

class ApiAdminBillingRepository implements AdminBillingRepository {
  ApiAdminBillingRepository(this._dio);

  final Dio _dio;

  @override
  Future<AdminDashboard> dashboard() => _call(
    () async => AdminDashboard.fromJson(await _get('/admin/dashboard')),
  );

  @override
  Future<Paged<PaymentQueueItem>> payments({
    PaymentStatus? status,
    String? doctorId,
    int page = 1,
    int pageSize = 25,
  }) => _call(
    () async => Paged.fromJson(
      await _get('/admin/payments', {
        'status': status?.wire ?? 'all',
        'doctorId': ?doctorId,
        'page': page,
        'pageSize': pageSize,
      }),
      PaymentQueueItem.fromJson,
    ),
  );

  @override
  Future<PaymentReview> payment(String paymentId) => _call(
    () async =>
        PaymentReview.fromJson(await _get('/admin/payments/$paymentId')),
  );

  @override
  Future<Uint8List> screenshot(String paymentId, int number) => _call(() async {
    final response = await _dio.get<List<int>>(
      '/admin/payments/$paymentId/screenshots/$number',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  });

  @override
  Future<InvoiceState> approvePayment(String paymentId) => _call(
    () async => InvoiceState.fromJson(
      await _post('/admin/reviewPayment', {
        'paymentId': paymentId,
        'action': 'approve',
      }),
    ),
  );

  @override
  Future<InvoiceState> rejectPayment(String paymentId, String reason) => _call(
    () async => InvoiceState.fromJson(
      await _post('/admin/reviewPayment', {
        'paymentId': paymentId,
        'action': 'reject',
        'reason': reason,
      }),
    ),
  );

  @override
  Future<AdminInvoicesPage> invoices(
    InvoiceFilter filter, {
    int page = 1,
    int pageSize = 25,
  }) => _call(
    () async => AdminInvoicesPage.fromJson(
      await _get('/admin/invoices', {
        ...filter.toQuery(),
        'page': page,
        'pageSize': pageSize,
      }),
    ),
  );

  @override
  Future<InvoiceDetail> invoice(String invoiceId) => _call(
    () async =>
        InvoiceDetail.fromJson(await _get('/admin/invoices/$invoiceId')),
  );

  @override
  Future<InvoiceState> adjustInvoice(
    String invoiceId, {
    required int amountPiasters,
    required String reason,
  }) => _call(
    () async => InvoiceState.fromJson(
      await _post('/admin/adjustInvoice', {
        'invoiceId': invoiceId,
        'amountPiasters': amountPiasters,
        'reason': reason,
      }),
    ),
  );

  @override
  Future<InvoiceState> waiveInvoice(
    String invoiceId, {
    required String reason,
  }) => _call(
    () async => InvoiceState.fromJson(
      await _post('/admin/waiveInvoice', {
        'invoiceId': invoiceId,
        'reason': reason,
      }),
    ),
  );

  @override
  Future<InvoiceState> markInvoicePaid(
    String invoiceId, {
    required PaidMethod method,
    required String note,
  }) => _call(
    () async => InvoiceState.fromJson(
      await _post('/admin/markInvoicePaid', {
        'invoiceId': invoiceId,
        'method': method.wire,
        'note': note,
      }),
    ),
  );

  @override
  Future<InvoiceState> extendInvoiceDueDate(
    String invoiceId, {
    required DateTime newDueDate,
    required String reason,
  }) => _call(
    () async => InvoiceState.fromJson(
      await _post('/admin/extendInvoiceDueDate', {
        'invoiceId': invoiceId,
        'newDueDate': dayKey(newDueDate),
        'reason': reason,
      }),
    ),
  );

  @override
  Future<Paged<DoctorListItem>> doctors(
    DoctorFilter filter, {
    int page = 1,
    int pageSize = 25,
  }) => _call(
    () async => Paged.fromJson(
      await _get('/admin/doctors', {
        ...filter.toQuery(),
        'page': page,
        'pageSize': pageSize,
      }),
      DoctorListItem.fromJson,
    ),
  );

  @override
  Future<AdminDoctorProfile> doctorProfile(String doctorId) => _call(
    () async =>
        AdminDoctorProfile.fromJson(await _get('/admin/doctors/$doctorId')),
  );

  @override
  Future<DoctorActivity> doctorActivity(
    String doctorId, {
    String? month,
    int page = 1,
  }) => _call(
    () async => DoctorActivity.fromJson(
      await _get('/admin/doctors/$doctorId/activity', {
        'month': ?month,
        'page': page,
        'pageSize': 25,
      }),
    ),
  );

  @override
  Future<DoctorAudit> doctorAudit(String doctorId) => _call(
    () async => DoctorAudit.fromJson(
      await _get('/admin/doctors/$doctorId/audit', {'pageSize': 50}),
    ),
  );

  @override
  Future<List<DoctorBranchRow>> doctorBranches(String doctorId) => _call(
    () async => [
      for (final row in await _getList('/admin/doctors/$doctorId/branches'))
        DoctorBranchRow.fromJson(row),
    ],
  );

  @override
  Future<List<DoctorAppointmentsMonth>> doctorAppointments(String doctorId) =>
      _call(
        () async => [
          for (final row in await _getList(
            '/admin/doctors/$doctorId/appointments',
          ))
            DoctorAppointmentsMonth.fromJson(row),
        ],
      );

  @override
  Future<List<DoctorAssistantRow>> doctorAssistants(String doctorId) => _call(
    () async => [
      for (final row in await _getList('/admin/doctors/$doctorId/assistants'))
        DoctorAssistantRow.fromJson(row),
    ],
  );

  @override
  Future<List<DoctorNote>> doctorNotes(String doctorId) => _call(
    () async => [
      for (final row in await _getList('/admin/doctors/$doctorId/notes'))
        DoctorNote.fromJson(row),
    ],
  );

  @override
  Future<void> addDoctorNote(String doctorId, String text) => _call(
    () => _post('/admin/doctors/addDoctorNote', {
      'doctorId': doctorId,
      'text': text,
    }),
  );

  @override
  Future<void> sendPasswordReset(String doctorId) => _call(
    () => _post('/admin/doctors/sendPasswordReset', {'doctorId': doctorId}),
  );

  @override
  Future<void> setDoctorStatus(
    String doctorId, {
    required String status,
    required String reason,
  }) => _call(
    () => _post('/admin/setDoctorStatus', {
      'doctorId': doctorId,
      'status': status,
      'reason': reason,
    }),
  );

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, dynamic>? query,
  ]) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return response.data ?? const {};
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response = await _dio.get<List<dynamic>>(path);
    return [
      for (final row in response.data ?? const [])
        (row as Map).cast<String, dynamic>(),
    ];
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
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

/// The real API, or the offline data when `USE_FAKE_AUTH` is on.
final adminBillingRepositoryProvider = Provider<AdminBillingRepository>((ref) {
  if (Env.useFakeAuth) return FakeAdminBillingRepository();
  return ApiAdminBillingRepository(ref.watch(dioProvider));
});
