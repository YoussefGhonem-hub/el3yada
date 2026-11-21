import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/billing_models.dart';
import 'fake_billing_repository.dart';

/// The clinic's invoices and payments (backend/docs/api-phase-7.md, "Clinic
/// billing"). Every method throws [ApiException].
abstract interface class BillingRepository {
  /// D18, D1's invoice card.
  Future<InvoiceList> invoices();

  /// D19.
  Future<InvoiceDetail> invoice(String invoiceId);

  /// D20's InstaPay box.
  Future<PaymentInfo> paymentInfo();

  /// D20 (`billingPay`). 409 `INVOICE_NOT_PAYABLE` when the status changed meanwhile.
  Future<PaymentSubmitted> submitPayment(String invoiceId, PaymentDraft draft);

  /// One screenshot of one payment, by number from 1 (D19).
  Future<Uint8List> screenshot(String paymentId, int number);
}

class ApiBillingRepository implements BillingRepository {
  ApiBillingRepository(this._dio);

  final Dio _dio;

  @override
  Future<InvoiceList> invoices() =>
      _call(() async => InvoiceList.fromJson(await _get('/billing/invoices')));

  @override
  Future<InvoiceDetail> invoice(String invoiceId) => _call(
    () async =>
        InvoiceDetail.fromJson(await _get('/billing/invoices/$invoiceId')),
  );

  @override
  Future<PaymentInfo> paymentInfo() => _call(
    () async => PaymentInfo.fromJson(await _get('/billing/paymentInfo')),
  );

  @override
  Future<PaymentSubmitted> submitPayment(
    String invoiceId,
    PaymentDraft draft,
  ) => _call(() async {
    final form = FormData.fromMap({
      'amountPiasters': draft.amountPiasters,
      'transferDate': dayKey(draft.transferDate),
      'reference': ?draft.reference,
      'senderName': ?draft.senderName,
      'note': ?draft.note,
    });
    for (final file in draft.screenshots) {
      form.files.add(
        MapEntry(
          'screenshots',
          MultipartFile.fromBytes(file.bytes, filename: file.name),
        ),
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/billing/invoices/$invoiceId/submitPayment',
      data: form,
    );
    return PaymentSubmitted.fromJson(response.data ?? const {});
  });

  @override
  Future<Uint8List> screenshot(String paymentId, int number) => _call(() async {
    final response = await _dio.get<List<int>>(
      '/billing/payments/$paymentId/screenshots/$number',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  });

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

  Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// The real API, or the offline invoices when `USE_FAKE_AUTH` is on.
final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  if (Env.useFakeAuth) return FakeBillingRepository();
  return ApiBillingRepository(ref.watch(dioProvider));
});
