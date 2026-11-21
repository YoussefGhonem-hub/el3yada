import 'dart:typed_data';

import '../../sessions/domain/session_models.dart'
    show parseDay, parseDayOrNull;

export '../../../core/data/paged.dart';
export '../../sessions/domain/session_models.dart'
    show dayKey, monthKey, parseDay, parseMonth;

/// Models of the clinic billing screens (D18–D20, AS10) and of the invoice and
/// payment screens shared with the admin (AD7–AD10). The contract is
/// backend/docs/api-phase-7.md; the API's `Billing/BillingViews.cs` is the
/// source of truth. Money is in piasters.

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();
DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);
Map<String, dynamic> _map(Object? value) =>
    (value as Map).cast<String, dynamic>();
String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Invoices.Status (spec 6.7).
enum InvoiceStatus {
  unpaid,
  pendingReview,
  paid,
  rejected,
  overdue,
  waived,
  noCharge;

  static InvoiceStatus fromWire(Object? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return unpaid;
  }

  String get wire => name;

  /// The doctor can pay it (BR-PAY1).
  bool get payable => this == unpaid || this == rejected || this == overdue;

  /// Money the doctor still owes.
  bool get outstanding =>
      this == unpaid ||
      this == pendingReview ||
      this == rejected ||
      this == overdue;
}

/// Payments.Status.
enum PaymentStatus {
  pendingReview,
  approved,
  rejected;

  static PaymentStatus fromWire(Object? value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return pendingReview;
  }

  String get wire => name;
}

/// How an admin recorded a manual payment (BR-PAY4).
enum PaidMethod {
  instapay,
  cash,
  bankTransfer,
  other;

  static PaidMethod? fromWire(Object? value) {
    for (final method in values) {
      if (method.name == value) return method;
    }
    return null;
  }

  String get wire => name;
}

/// One invoice in a list (D18, AD9 rows share the amounts).
class InvoiceItem {
  const InvoiceItem({
    required this.id,
    required this.monthKey,
    required this.periodStart,
    required this.periodEnd,
    required this.examCount,
    required this.consultationCount,
    required this.examAmountPiasters,
    required this.consultationAmountPiasters,
    required this.adjustmentsPiasters,
    required this.totalDuePiasters,
    required this.dueDate,
    required this.status,
    required this.canPay,
    this.paidAt,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
    id: json['id'] as String,
    monthKey: json['monthKey'] as String,
    periodStart: parseDay(json['periodStart']),
    periodEnd: parseDay(json['periodEnd']),
    examCount: json['examCount'] as int,
    consultationCount: json['consultationCount'] as int,
    examAmountPiasters: json['examAmountPiasters'] as int,
    consultationAmountPiasters: json['consultationAmountPiasters'] as int,
    adjustmentsPiasters: json['adjustmentsPiasters'] as int,
    totalDuePiasters: json['totalDuePiasters'] as int,
    dueDate: parseDay(json['dueDate']),
    status: InvoiceStatus.fromWire(json['status']),
    canPay:
        json['canPay'] as bool? ??
        InvoiceStatus.fromWire(json['status']).payable,
    paidAt: _timeOrNull(json['paidAt']),
  );

  final String id;

  /// `2026-10`.
  final String monthKey;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int examCount;
  final int consultationCount;
  final int examAmountPiasters;
  final int consultationAmountPiasters;
  final int adjustmentsPiasters;
  final int totalDuePiasters;

  /// The last day to pay, until 23:59 Cairo.
  final DateTime dueDate;
  final InvoiceStatus status;
  final bool canPay;
  final DateTime? paidAt;

  /// The month as a date (the 1st), for formatting.
  DateTime get month => DateTime.utc(periodStart.year, periodStart.month);

  /// Whole days left to pay on [today] (negative once it passed).
  int daysLeft(DateTime today) => dueDate.difference(today).inDays;
}

/// The suspension the banner and the Pay button speak of (BR-G5).
class SuspensionInfo {
  const SuspensionInfo({this.monthKey, required this.billing});

  factory SuspensionInfo.fromJson(Map<String, dynamic> json) => SuspensionInfo(
    monthKey: _text(json['monthKey']),
    billing: json['billing'] as bool? ?? false,
  );

  /// The unpaid month, when the cause is billing.
  final String? monthKey;
  final bool billing;
}

/// D18 and the invoice card of D1.
class InvoiceList {
  const InvoiceList({
    required this.items,
    this.attention,
    this.underReview,
    required this.outstandingPiasters,
    this.suspension,
  });

  factory InvoiceList.fromJson(Map<String, dynamic> json) => InvoiceList(
    items: [
      for (final row in json['items'] as List) InvoiceItem.fromJson(_map(row)),
    ],
    attention: json['attention'] == null
        ? null
        : InvoiceItem.fromJson(_map(json['attention'])),
    underReview: json['underReview'] == null
        ? null
        : InvoiceItem.fromJson(_map(json['underReview'])),
    outstandingPiasters: json['outstandingPiasters'] as int,
    suspension: json['suspension'] == null
        ? null
        : SuspensionInfo.fromJson(_map(json['suspension'])),
  );

  final List<InvoiceItem> items;

  /// The invoice to pay first (unpaid, rejected or overdue).
  final InvoiceItem? attention;

  /// The invoice whose payment is waiting for the admin.
  final InvoiceItem? underReview;
  final int outstandingPiasters;
  final SuspensionInfo? suspension;
}

class InvoiceBranchLine {
  const InvoiceBranchLine({
    required this.branchId,
    required this.nameAr,
    this.nameEn,
    required this.examCount,
    required this.consultationCount,
    required this.amountPiasters,
  });

  factory InvoiceBranchLine.fromJson(Map<String, dynamic> json) =>
      InvoiceBranchLine(
        branchId: json['branchId'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: _text(json['nameEn']),
        examCount: json['examCount'] as int,
        consultationCount: json['consultationCount'] as int,
        amountPiasters: json['amountPiasters'] as int,
      );

  final String branchId;
  final String nameAr;
  final String? nameEn;
  final int examCount;
  final int consultationCount;
  final int amountPiasters;

  String name(String languageCode) =>
      languageCode == 'en' && nameEn != null ? nameEn! : nameAr;
}

class InvoiceAdjustment {
  const InvoiceAdjustment({
    required this.id,
    required this.amountPiasters,
    required this.reason,
    required this.createdAt,
  });

  factory InvoiceAdjustment.fromJson(Map<String, dynamic> json) =>
      InvoiceAdjustment(
        id: json['id'] as String,
        amountPiasters: json['amountPiasters'] as int,
        reason: json['reason'] as String,
        createdAt: _time(json['createdAt']),
      );

  final String id;

  /// Signed: a discount is negative.
  final int amountPiasters;
  final String reason;
  final DateTime createdAt;
}

/// One step of the status timeline (D19, AD10).
class InvoiceTimelineLine {
  const InvoiceTimelineLine({
    required this.status,
    this.note,
    required this.changedAt,
    this.changedByRole,
  });

  factory InvoiceTimelineLine.fromJson(Map<String, dynamic> json) =>
      InvoiceTimelineLine(
        status: InvoiceStatus.fromWire(json['status']),
        note: _text(json['note']),
        changedAt: _time(json['changedAt']),
        changedByRole: _text(json['changedByRole']),
      );

  final InvoiceStatus status;
  final String? note;
  final DateTime changedAt;

  /// `system`, `doctor`, `assistant` or `admin`.
  final String? changedByRole;
}

/// A payment the doctor submitted (D19, AD8).
class PaymentLine {
  const PaymentLine({
    required this.id,
    required this.amountPiasters,
    required this.transferDate,
    this.reference,
    this.senderName,
    this.note,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    required this.screenshots,
  });

  factory PaymentLine.fromJson(Map<String, dynamic> json) => PaymentLine(
    id: json['id'] as String,
    amountPiasters: json['amountPiasters'] as int,
    transferDate: parseDay(json['transferDate']),
    reference: _text(json['reference']),
    senderName: _text(json['senderName']),
    note: _text(json['note']),
    status: PaymentStatus.fromWire(json['status']),
    submittedAt: _time(json['submittedAt']),
    reviewedAt: _timeOrNull(json['reviewedAt']),
    rejectionReason: _text(json['rejectionReason']),
    screenshots: json['screenshots'] as int,
  );

  final String id;
  final int amountPiasters;
  final DateTime transferDate;
  final String? reference;
  final String? senderName;
  final String? note;
  final PaymentStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  /// How many images there are; fetch them by number, from 1.
  final int screenshots;
}

/// The doctor an invoice belongs to (admin screens only).
class InvoiceDoctorRef {
  const InvoiceDoctorRef({
    required this.id,
    required this.name,
    this.nameEn,
    required this.status,
  });

  factory InvoiceDoctorRef.fromJson(Map<String, dynamic> json) =>
      InvoiceDoctorRef(
        id: json['id'] as String,
        name: json['name'] as String,
        nameEn: _text(json['nameEn']),
        status: json['status'] as String,
      );

  final String id;
  final String name;
  final String? nameEn;

  /// Doctors.Status.
  final String status;

  String displayName(String languageCode) =>
      languageCode == 'en' && nameEn != null ? nameEn! : name;
}

/// D19 (doctor) and AD10 (admin).
class InvoiceDetail {
  const InvoiceDetail({
    required this.invoice,
    this.paidMethod,
    required this.branches,
    required this.adjustments,
    required this.timeline,
    required this.payments,
    this.doctor,
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) => InvoiceDetail(
    invoice: InvoiceItem.fromJson(json),
    paidMethod: PaidMethod.fromWire(json['paidMethod']),
    branches: [
      for (final row in json['branches'] as List)
        InvoiceBranchLine.fromJson(_map(row)),
    ],
    adjustments: [
      for (final row in json['adjustments'] as List)
        InvoiceAdjustment.fromJson(_map(row)),
    ],
    timeline: [
      for (final row in json['timeline'] as List)
        InvoiceTimelineLine.fromJson(_map(row)),
    ],
    payments: [
      for (final row in json['payments'] as List)
        PaymentLine.fromJson(_map(row)),
    ],
    doctor: json['doctor'] == null
        ? null
        : InvoiceDoctorRef.fromJson(_map(json['doctor'])),
  );

  final InvoiceItem invoice;
  final PaidMethod? paidMethod;
  final List<InvoiceBranchLine> branches;
  final List<InvoiceAdjustment> adjustments;
  final List<InvoiceTimelineLine> timeline;

  /// Newest first.
  final List<PaymentLine> payments;
  final InvoiceDoctorRef? doctor;

  /// The latest rejected payment's reason, shown on D19 above Pay.
  String? get lastRejectionReason {
    for (final payment in payments) {
      if (payment.status == PaymentStatus.rejected) {
        return payment.rejectionReason;
      }
    }
    return null;
  }
}

/// D20's InstaPay box.
class PaymentInfo {
  const PaymentInfo({
    this.instapayAddress,
    this.instapayAccountName,
    this.instructionsAr,
    this.instructionsEn,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
    instapayAddress: _text(json['instapayAddress']),
    instapayAccountName: _text(json['instapayAccountName']),
    instructionsAr: _text(json['instructionsAr']),
    instructionsEn: _text(json['instructionsEn']),
  );

  final String? instapayAddress;
  final String? instapayAccountName;
  final String? instructionsAr;
  final String? instructionsEn;

  String? instructions(String languageCode) =>
      (languageCode == 'en' ? instructionsEn : instructionsAr) ??
      instructionsAr ??
      instructionsEn;
}

/// A screenshot chosen on the device, ready to upload (D20).
class ScreenshotFile {
  const ScreenshotFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// What D20 sends (`submitPayment`, BR-PAY2).
class PaymentDraft {
  const PaymentDraft({
    required this.amountPiasters,
    required this.transferDate,
    this.reference,
    this.senderName,
    this.note,
    required this.screenshots,
  });

  final int amountPiasters;
  final DateTime transferDate;
  final String? reference;
  final String? senderName;
  final String? note;

  /// 1 to 3 images of 10 MB or less.
  final List<ScreenshotFile> screenshots;
}

/// The answer of `submitPayment`.
class PaymentSubmitted {
  const PaymentSubmitted({
    required this.paymentId,
    required this.invoiceId,
    required this.invoiceStatus,
  });

  factory PaymentSubmitted.fromJson(Map<String, dynamic> json) =>
      PaymentSubmitted(
        paymentId: json['paymentId'] as String,
        invoiceId: json['invoiceId'] as String,
        invoiceStatus: InvoiceStatus.fromWire(json['invoiceStatus']),
      );

  final String paymentId;
  final String invoiceId;
  final InvoiceStatus invoiceStatus;
}

/// The state an admin's invoice action leaves the invoice in.
class InvoiceState {
  const InvoiceState({
    required this.invoiceId,
    required this.status,
    required this.totalDuePiasters,
    required this.dueDate,
  });

  factory InvoiceState.fromJson(Map<String, dynamic> json) => InvoiceState(
    invoiceId: json['invoiceId'] as String,
    status: InvoiceStatus.fromWire(json['status']),
    totalDuePiasters: json['totalDuePiasters'] as int,
    dueDate: parseDayOrNull(json['dueDate']) ?? DateTime.utc(1970),
  );

  final String invoiceId;
  final InvoiceStatus status;
  final int totalDuePiasters;
  final DateTime dueDate;
}

/// The API's invoice and payment error codes (backend/docs/api-phase-7.md).
abstract final class BillingCodes {
  static const invoiceNotPayable = 'INVOICE_NOT_PAYABLE';
  static const invoiceStatusInvalid = 'INVOICE_STATUS_INVALID';
  static const paymentAlreadyReviewed = 'PAYMENT_ALREADY_REVIEWED';
  static const adjustmentInvalid = 'ADJUSTMENT_INVALID';
  static const dueDateInvalid = 'DUE_DATE_INVALID';
  static const tooManyScreenshots = 'TOO_MANY_SCREENSHOTS';
}
