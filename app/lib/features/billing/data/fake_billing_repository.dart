import 'dart:typed_data';

import '../../../core/network/api_exception.dart';
import '../domain/billing_models.dart';
import 'billing_repository.dart';

/// Offline invoices for the dev accounts and the tests: this month's running
/// total is on D3; here are four closed months, one of them overdue, so every
/// state of D18 and D19 can be seen. Submitting a payment moves the invoice to
/// «pending review» like the API.
class FakeBillingRepository implements BillingRepository {
  FakeBillingRepository({DateTime? today}) {
    final now = today ?? DateTime.now().toUtc();
    DateTime month(int back) => DateTime.utc(now.year, now.month - back);
    DateTime lastDay(DateTime first) =>
        DateTime.utc(first.year, first.month + 1, 0);

    InvoiceDetail make(
      int back,
      InvoiceStatus status, {
      int exams = 40,
      int consultations = 20,
      List<PaymentLine> payments = const [],
    }) {
      final first = month(back);
      final last = lastDay(first);
      final examAmount = exams * 3000;
      final consultationAmount = consultations * 1500;
      final invoice = InvoiceItem(
        id: 'inv-${first.year}-${first.month}',
        monthKey: '${first.year}-${first.month.toString().padLeft(2, '0')}',
        periodStart: first,
        periodEnd: last,
        examCount: exams,
        consultationCount: consultations,
        examAmountPiasters: examAmount,
        consultationAmountPiasters: consultationAmount,
        adjustmentsPiasters: 0,
        totalDuePiasters: examAmount + consultationAmount,
        dueDate: last.add(const Duration(days: 7)),
        status: status,
        canPay: status.payable,
        paidAt: status == InvoiceStatus.paid
            ? last.add(const Duration(days: 4))
            : null,
      );
      return InvoiceDetail(
        invoice: invoice,
        branches: [
          InvoiceBranchLine(
            branchId: 'branch-1',
            nameAr: 'فرع المعادي',
            nameEn: 'Maadi branch',
            examCount: exams,
            consultationCount: consultations,
            amountPiasters: examAmount + consultationAmount,
          ),
        ],
        adjustments: const [],
        timeline: [
          InvoiceTimelineLine(
            status: status == InvoiceStatus.noCharge
                ? InvoiceStatus.noCharge
                : InvoiceStatus.unpaid,
            changedAt: last.add(const Duration(hours: 24, minutes: 5)),
            changedByRole: 'system',
          ),
          if (status == InvoiceStatus.paid)
            InvoiceTimelineLine(
              status: InvoiceStatus.paid,
              changedAt: last.add(const Duration(days: 4)),
              changedByRole: 'admin',
            ),
          if (status == InvoiceStatus.overdue)
            InvoiceTimelineLine(
              status: InvoiceStatus.overdue,
              changedAt: last.add(const Duration(days: 8)),
              changedByRole: 'system',
            ),
        ],
        payments: payments,
      );
    }

    _details = [
      make(1, InvoiceStatus.unpaid),
      make(
        2,
        InvoiceStatus.overdue,
        exams: 52,
        consultations: 31,
        payments: [
          PaymentLine(
            id: 'pay-old',
            amountPiasters: 10000,
            transferDate: month(2).add(const Duration(days: 35)),
            status: PaymentStatus.rejected,
            submittedAt: month(2).add(const Duration(days: 36)),
            reviewedAt: month(2).add(const Duration(days: 37)),
            rejectionReason: 'المبلغ غير مطابق',
            screenshots: 1,
          ),
        ],
      ),
      make(3, InvoiceStatus.paid, exams: 47, consultations: 18),
      make(4, InvoiceStatus.noCharge, exams: 0, consultations: 0),
    ];
  }

  late List<InvoiceDetail> _details;

  InvoiceList _list() {
    final items = [for (final detail in _details) detail.invoice];
    final payable = items.where((i) => i.canPay).toList()
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    final overdue = items.any((i) => i.status == InvoiceStatus.overdue);
    return InvoiceList(
      items: items,
      attention: payable.isEmpty ? null : payable.first,
      underReview: items
          .where((i) => i.status == InvoiceStatus.pendingReview)
          .firstOrNull,
      outstandingPiasters: items
          .where((i) => i.status.outstanding)
          .fold(0, (sum, i) => sum + i.totalDuePiasters),
      suspension: overdue
          ? SuspensionInfo(
              monthKey: payable.isEmpty ? null : payable.first.monthKey,
              billing: true,
            )
          : null,
    );
  }

  @override
  Future<InvoiceList> invoices() async => _list();

  @override
  Future<InvoiceDetail> invoice(String invoiceId) async => _details.firstWhere(
    (d) => d.invoice.id == invoiceId,
    orElse: () => throw const ApiException.local('NOT_FOUND'),
  );

  @override
  Future<PaymentInfo> paymentInfo() async => const PaymentInfo(
    instapayAddress: 'el3yada@instapay',
    instapayAccountName: 'El3yada Platform',
    instructionsAr: 'حوّل المبلغ بالضبط ثم ارفع صورة التحويل.',
    instructionsEn:
        'Transfer the exact amount, then upload a screenshot of the transfer.',
  );

  @override
  Future<PaymentSubmitted> submitPayment(
    String invoiceId,
    PaymentDraft draft,
  ) async {
    final index = _details.indexWhere((d) => d.invoice.id == invoiceId);
    if (index < 0) throw const ApiException.local('NOT_FOUND');
    final detail = _details[index];
    if (!detail.invoice.status.payable)
      throw const ApiException.local(BillingCodes.invoiceNotPayable);
    final payment = PaymentLine(
      id: 'pay-${detail.payments.length + 1}',
      amountPiasters: draft.amountPiasters,
      transferDate: draft.transferDate,
      reference: draft.reference,
      senderName: draft.senderName,
      note: draft.note,
      status: PaymentStatus.pendingReview,
      submittedAt: DateTime.now().toUtc(),
      screenshots: draft.screenshots.length,
    );
    final old = detail.invoice;
    final updated = InvoiceItem(
      id: old.id,
      monthKey: old.monthKey,
      periodStart: old.periodStart,
      periodEnd: old.periodEnd,
      examCount: old.examCount,
      consultationCount: old.consultationCount,
      examAmountPiasters: old.examAmountPiasters,
      consultationAmountPiasters: old.consultationAmountPiasters,
      adjustmentsPiasters: old.adjustmentsPiasters,
      totalDuePiasters: old.totalDuePiasters,
      dueDate: old.dueDate,
      status: InvoiceStatus.pendingReview,
      canPay: false,
    );
    _details[index] = InvoiceDetail(
      invoice: updated,
      branches: detail.branches,
      adjustments: detail.adjustments,
      timeline: [
        ...detail.timeline,
        InvoiceTimelineLine(
          status: InvoiceStatus.pendingReview,
          changedAt: DateTime.now().toUtc(),
          changedByRole: 'doctor',
        ),
      ],
      payments: [payment, ...detail.payments],
    );
    return PaymentSubmitted(
      paymentId: payment.id,
      invoiceId: invoiceId,
      invoiceStatus: InvoiceStatus.pendingReview,
    );
  }

  @override
  Future<Uint8List> screenshot(String paymentId, int number) async =>
      throw const ApiException.local('NOT_FOUND');
}
