import '../../billing/domain/billing_models.dart';
import '../../sessions/domain/session_models.dart' show SessionType, parseDay;

export '../../billing/domain/billing_models.dart';
export '../../sessions/domain/session_models.dart'
    show SessionType, dayKey, monthKey, parseDay;

/// Models of the admin's billing and doctor screens (AD1, AD4–AD10). The
/// contract is backend/docs/api-phase-7.md. An admin sees fee snapshots and
/// payment screenshots, patient names masked, and never the clinic's revenue
/// (BR-REV1, AC-12).

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();
DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);
Map<String, dynamic> _map(Object? value) =>
    (value as Map).cast<String, dynamic>();
List<Map<String, dynamic>> _list(Object? value) => [
  for (final row in value! as List) _map(row),
];
String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
int _int(Object? value) => (value! as num).toInt();

String _displayName(String languageCode, String name, String? nameEn) =>
    languageCode == 'en' && nameEn != null ? nameEn : name;

/// A row of AD7: a payment waiting for review (or reviewed).
class PaymentQueueItem {
  const PaymentQueueItem({
    required this.paymentId,
    required this.invoiceId,
    required this.doctorId,
    required this.doctorName,
    this.doctorNameEn,
    required this.monthKey,
    required this.invoiceTotalPiasters,
    required this.amountPiasters,
    required this.mismatch,
    required this.submittedAt,
    required this.status,
  });

  factory PaymentQueueItem.fromJson(Map<String, dynamic> json) =>
      PaymentQueueItem(
        paymentId: json['paymentId'] as String,
        invoiceId: json['invoiceId'] as String,
        doctorId: json['doctorId'] as String,
        doctorName: json['doctorName'] as String,
        doctorNameEn: _text(json['doctorNameEn']),
        monthKey: json['monthKey'] as String,
        invoiceTotalPiasters: _int(json['invoiceTotalPiasters']),
        amountPiasters: _int(json['amountPiasters']),
        mismatch: json['mismatch'] as bool,
        submittedAt: _time(json['submittedAt']),
        status: PaymentStatus.fromWire(json['status']),
      );

  final String paymentId;
  final String invoiceId;
  final String doctorId;
  final String doctorName;
  final String? doctorNameEn;

  /// `2026-10`.
  final String monthKey;
  final int invoiceTotalPiasters;

  /// What the doctor entered.
  final int amountPiasters;

  /// The amount differs from the invoice total (BR-PAY3).
  final bool mismatch;
  final DateTime submittedAt;
  final PaymentStatus status;

  String doctor(String languageCode) =>
      _displayName(languageCode, doctorName, doctorNameEn);

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// The invoice summary on AD8.
class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.monthKey,
    required this.examCount,
    required this.consultationCount,
    required this.totalDuePiasters,
    required this.dueDate,
    required this.status,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) => InvoiceSummary(
    id: json['id'] as String,
    monthKey: json['monthKey'] as String,
    examCount: _int(json['examCount']),
    consultationCount: _int(json['consultationCount']),
    totalDuePiasters: _int(json['totalDuePiasters']),
    dueDate: parseDay(json['dueDate']),
    status: InvoiceStatus.fromWire(json['status']),
  );

  final String id;
  final String monthKey;
  final int examCount;
  final int consultationCount;
  final int totalDuePiasters;
  final DateTime dueDate;
  final InvoiceStatus status;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// AD8: the payment, the invoice it pays, and the earlier attempts.
class PaymentReview {
  const PaymentReview({
    required this.payment,
    required this.doctor,
    required this.invoice,
    required this.mismatch,
    required this.earlierAttempts,
  });

  factory PaymentReview.fromJson(Map<String, dynamic> json) => PaymentReview(
    payment: PaymentLine.fromJson(_map(json['payment'])),
    doctor: InvoiceDoctorRef.fromJson(_map(json['doctor'])),
    invoice: InvoiceSummary.fromJson(_map(json['invoice'])),
    mismatch: json['mismatch'] as bool,
    earlierAttempts: [
      for (final row in _list(json['earlierAttempts']))
        PaymentLine.fromJson(row),
    ],
  );

  final PaymentLine payment;
  final InvoiceDoctorRef doctor;
  final InvoiceSummary invoice;
  final bool mismatch;
  final List<PaymentLine> earlierAttempts;
}

/// A row of AD9.
class AdminInvoiceItem {
  const AdminInvoiceItem({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    this.doctorNameEn,
    required this.monthKey,
    required this.examCount,
    required this.consultationCount,
    required this.totalDuePiasters,
    required this.dueDate,
    required this.status,
  });

  factory AdminInvoiceItem.fromJson(Map<String, dynamic> json) =>
      AdminInvoiceItem(
        id: json['id'] as String,
        doctorId: json['doctorId'] as String,
        doctorName: json['doctorName'] as String,
        doctorNameEn: _text(json['doctorNameEn']),
        monthKey: json['monthKey'] as String,
        examCount: _int(json['examCount']),
        consultationCount: _int(json['consultationCount']),
        totalDuePiasters: _int(json['totalDuePiasters']),
        dueDate: parseDay(json['dueDate']),
        status: InvoiceStatus.fromWire(json['status']),
      );

  final String id;
  final String doctorId;
  final String doctorName;
  final String? doctorNameEn;
  final String monthKey;
  final int examCount;
  final int consultationCount;
  final int totalDuePiasters;
  final DateTime dueDate;
  final InvoiceStatus status;

  String doctor(String languageCode) =>
      _displayName(languageCode, doctorName, doctorNameEn);

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class InvoiceTotals {
  const InvoiceTotals({
    required this.count,
    required this.examCount,
    required this.consultationCount,
    required this.totalDuePiasters,
  });

  factory InvoiceTotals.fromJson(Map<String, dynamic> json) => InvoiceTotals(
    count: _int(json['count']),
    examCount: _int(json['examCount']),
    consultationCount: _int(json['consultationCount']),
    totalDuePiasters: _int(json['totalDuePiasters']),
  );

  final int count;
  final int examCount;
  final int consultationCount;
  final int totalDuePiasters;
}

/// AD9: a page of invoices with the totals of the whole filtered set.
class AdminInvoicesPage {
  const AdminInvoicesPage({required this.page, required this.totals});

  factory AdminInvoicesPage.fromJson(Map<String, dynamic> json) =>
      AdminInvoicesPage(
        page: Paged.fromJson(_map(json['page']), AdminInvoiceItem.fromJson),
        totals: InvoiceTotals.fromJson(_map(json['totals'])),
      );

  final Paged<AdminInvoiceItem> page;
  final InvoiceTotals totals;
}

/// The filter of AD9 (month, status, doctor).
class InvoiceFilter {
  const InvoiceFilter({this.month, this.status, this.doctorId});

  /// `yyyy-MM`.
  final String? month;
  final InvoiceStatus? status;
  final String? doctorId;

  InvoiceFilter copyWith({
    Object? month = _keep,
    Object? status = _keep,
    Object? doctorId = _keep,
  }) => InvoiceFilter(
    month: identical(month, _keep) ? this.month : month as String?,
    status: identical(status, _keep) ? this.status : status as InvoiceStatus?,
    doctorId: identical(doctorId, _keep) ? this.doctorId : doctorId as String?,
  );

  static const _keep = Object();

  Map<String, Object> toQuery() => {
    'month': ?month,
    if (status != null) 'status': status!.wire,
    'doctorId': ?doctorId,
  };

  @override
  bool operator ==(Object other) =>
      other is InvoiceFilter &&
      other.month == month &&
      other.status == status &&
      other.doctorId == doctorId;

  @override
  int get hashCode => Object.hash(month, status, doctorId);
}

/// What `reviewPayment` and the invoice actions answer: the invoice's new state.
typedef AdminInvoiceState = InvoiceState;

// ---- AD1 -------------------------------------------------------------------------------------

class DoctorCounts {
  const DoctorCounts({
    required this.active,
    required this.pendingApproval,
    required this.suspended,
    required this.disabled,
    required this.rejected,
    required this.inTrial,
  });

  factory DoctorCounts.fromJson(Map<String, dynamic> json) => DoctorCounts(
    active: _int(json['active']),
    pendingApproval: _int(json['pendingApproval']),
    suspended: _int(json['suspended']),
    disabled: _int(json['disabled']),
    rejected: _int(json['rejected']),
    inTrial: _int(json['inTrial']),
  );

  final int active;
  final int pendingApproval;
  final int suspended;
  final int disabled;
  final int rejected;
  final int inTrial;
}

class TypeCounts {
  const TypeCounts({required this.examinations, required this.consultations});

  factory TypeCounts.fromJson(Map<String, dynamic> json) => TypeCounts(
    examinations: _int(json['examinations']),
    consultations: _int(json['consultations']),
  );

  final int examinations;
  final int consultations;

  int get total => examinations + consultations;
}

class InvoicedCollected {
  const InvoicedCollected({
    required this.monthKey,
    required this.invoicedPiasters,
    required this.collectedPiasters,
  });

  factory InvoicedCollected.fromJson(Map<String, dynamic> json) =>
      InvoicedCollected(
        monthKey: json['monthKey'] as String,
        invoicedPiasters: _int(json['invoicedPiasters']),
        collectedPiasters: _int(json['collectedPiasters']),
      );

  final String monthKey;
  final int invoicedPiasters;
  final int collectedPiasters;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class SessionsPerDay {
  const SessionsPerDay({
    required this.day,
    required this.examinations,
    required this.consultations,
  });

  factory SessionsPerDay.fromJson(Map<String, dynamic> json) => SessionsPerDay(
    day: parseDay(json['day']),
    examinations: _int(json['examinations']),
    consultations: _int(json['consultations']),
  );

  final DateTime day;
  final int examinations;
  final int consultations;
}

class LatestSignup {
  const LatestSignup({
    required this.doctorId,
    required this.fullName,
    this.fullNameEn,
    required this.specialtyAr,
    required this.specialtyEn,
    required this.status,
    required this.createdAt,
  });

  factory LatestSignup.fromJson(Map<String, dynamic> json) => LatestSignup(
    doctorId: json['doctorId'] as String,
    fullName: json['fullName'] as String,
    fullNameEn: _text(json['fullNameEn']),
    specialtyAr: json['specialtyAr'] as String,
    specialtyEn: json['specialtyEn'] as String,
    status: json['status'] as String,
    createdAt: _time(json['createdAt']),
  );

  final String doctorId;
  final String fullName;
  final String? fullNameEn;
  final String specialtyAr;
  final String specialtyEn;
  final String status;
  final DateTime createdAt;

  String name(String languageCode) =>
      _displayName(languageCode, fullName, fullNameEn);
  String specialty(String languageCode) =>
      languageCode == 'en' ? specialtyEn : specialtyAr;
}

/// AD1.
class AdminDashboard {
  const AdminDashboard({
    required this.doctors,
    required this.totalPatients,
    required this.sessionsToday,
    required this.sessionsThisMonth,
    required this.bookingsToday,
    this.noShowRateLast30Days,
    required this.expectedFeesThisMonthPiasters,
    required this.lastMonth,
    required this.outstandingPiasters,
    required this.overdueDoctors,
    required this.paymentsToReview,
    required this.signupsToReview,
    required this.sessionsPerDay,
    required this.invoicedVsCollected,
    required this.latestPayments,
    required this.latestSignups,
    required this.invoicesDueSoon,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => AdminDashboard(
    doctors: DoctorCounts.fromJson(_map(json['doctors'])),
    totalPatients: _int(json['totalPatients']),
    sessionsToday: TypeCounts.fromJson(_map(json['sessionsToday'])),
    sessionsThisMonth: TypeCounts.fromJson(_map(json['sessionsThisMonth'])),
    bookingsToday: _int(json['bookingsToday']),
    noShowRateLast30Days: (json['noShowRateLast30Days'] as num?)?.toDouble(),
    expectedFeesThisMonthPiasters: _int(json['expectedFeesThisMonthPiasters']),
    lastMonth: InvoicedCollected.fromJson(_map(json['lastMonth'])),
    outstandingPiasters: _int(json['outstandingPiasters']),
    overdueDoctors: _int(json['overdueDoctors']),
    paymentsToReview: _int(json['paymentsToReview']),
    signupsToReview: _int(json['signupsToReview']),
    sessionsPerDay: [
      for (final row in _list(json['sessionsPerDay']))
        SessionsPerDay.fromJson(row),
    ],
    invoicedVsCollected: [
      for (final row in _list(json['invoicedVsCollected']))
        InvoicedCollected.fromJson(row),
    ],
    latestPayments: [
      for (final row in _list(json['latestPayments']))
        PaymentQueueItem.fromJson(row),
    ],
    latestSignups: [
      for (final row in _list(json['latestSignups']))
        LatestSignup.fromJson(row),
    ],
    invoicesDueSoon: [
      for (final row in _list(json['invoicesDueSoon']))
        AdminInvoiceItem.fromJson(row),
    ],
  );

  final DoctorCounts doctors;
  final int totalPatients;
  final TypeCounts sessionsToday;
  final TypeCounts sessionsThisMonth;
  final int bookingsToday;

  /// 0–1, null without data.
  final double? noShowRateLast30Days;
  final int expectedFeesThisMonthPiasters;
  final InvoicedCollected lastMonth;
  final int outstandingPiasters;
  final int overdueDoctors;
  final int paymentsToReview;
  final int signupsToReview;
  final List<SessionsPerDay> sessionsPerDay;
  final List<InvoicedCollected> invoicedVsCollected;
  final List<PaymentQueueItem> latestPayments;
  final List<LatestSignup> latestSignups;
  final List<AdminInvoiceItem> invoicesDueSoon;
}

// ---- AD4, AD5 --------------------------------------------------------------------------------

/// A row of AD4.
class DoctorListItem {
  const DoctorListItem({
    required this.doctorId,
    required this.fullName,
    this.fullNameEn,
    this.email,
    this.phone,
    this.clinicName,
    this.clinicNameEn,
    this.governorate,
    required this.specialtyAr,
    required this.specialtyEn,
    required this.status,
    this.trialEndsAt,
    required this.createdAt,
    required this.sessionsThisMonth,
    required this.outstandingPiasters,
  });

  factory DoctorListItem.fromJson(Map<String, dynamic> json) => DoctorListItem(
    doctorId: json['doctorId'] as String,
    fullName: json['fullName'] as String,
    fullNameEn: _text(json['fullNameEn']),
    email: _text(json['email']),
    phone: _text(json['phone']),
    clinicName: _text(json['clinicName']),
    clinicNameEn: _text(json['clinicNameEn']),
    governorate: _text(json['governorate']),
    specialtyAr: json['specialtyAr'] as String,
    specialtyEn: json['specialtyEn'] as String,
    status: json['status'] as String,
    trialEndsAt: _timeOrNull(json['trialEndsAt']),
    createdAt: _time(json['createdAt']),
    sessionsThisMonth: _int(json['sessionsThisMonth']),
    outstandingPiasters: _int(json['outstandingPiasters']),
  );

  final String doctorId;
  final String fullName;
  final String? fullNameEn;
  final String? email;
  final String? phone;
  final String? clinicName;
  final String? clinicNameEn;
  final String? governorate;
  final String specialtyAr;
  final String specialtyEn;

  /// Doctors.Status: `active`, `pendingApproval`, `suspended`, `disabled`, `rejected`.
  final String status;
  final DateTime? trialEndsAt;
  final DateTime createdAt;
  final int sessionsThisMonth;
  final int outstandingPiasters;

  String name(String languageCode) =>
      _displayName(languageCode, fullName, fullNameEn);
  String? clinic(String languageCode) =>
      languageCode == 'en' && clinicNameEn != null ? clinicNameEn : clinicName;
  String specialty(String languageCode) =>
      languageCode == 'en' ? specialtyEn : specialtyAr;
}

/// The AD4 filter and sort.
class DoctorFilter {
  const DoctorFilter({
    this.search = '',
    this.status,
    this.sort = DoctorSort.name,
  });

  final String search;
  final String? status;
  final DoctorSort sort;

  DoctorFilter copyWith({
    String? search,
    Object? status = _keep,
    DoctorSort? sort,
  }) => DoctorFilter(
    search: search ?? this.search,
    status: identical(status, _keep) ? this.status : status as String?,
    sort: sort ?? this.sort,
  );

  static const _keep = Object();

  Map<String, Object> toQuery() => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    'status': ?status,
    'sort': sort.name,
  };

  @override
  bool operator ==(Object other) =>
      other is DoctorFilter &&
      other.search == search &&
      other.status == status &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(search, status, sort);
}

enum DoctorSort { name, newest, sessions, outstanding }

/// AD5 Profile tab.
class AdminDoctorProfile {
  const AdminDoctorProfile({
    required this.doctorId,
    required this.fullName,
    this.fullNameEn,
    required this.title,
    this.titleEn,
    required this.licenseNumber,
    required this.specialtyId,
    required this.specialtyAr,
    required this.specialtyEn,
    this.email,
    this.phone,
    required this.emailVerified,
    required this.status,
    this.statusReason,
    this.statusChangedAt,
    this.trialEndsAt,
    required this.createdAt,
  });

  factory AdminDoctorProfile.fromJson(Map<String, dynamic> json) =>
      AdminDoctorProfile(
        doctorId: json['doctorId'] as String,
        fullName: json['fullName'] as String,
        fullNameEn: _text(json['fullNameEn']),
        title: json['title'] as String,
        titleEn: _text(json['titleEn']),
        licenseNumber: json['licenseNumber'] as String,
        specialtyId: json['specialtyId'] as String,
        specialtyAr: json['specialtyAr'] as String,
        specialtyEn: json['specialtyEn'] as String,
        email: _text(json['email']),
        phone: _text(json['phone']),
        emailVerified: json['emailVerified'] as bool,
        status: json['status'] as String,
        statusReason: _text(json['statusReason']),
        statusChangedAt: _timeOrNull(json['statusChangedAt']),
        trialEndsAt: _timeOrNull(json['trialEndsAt']),
        createdAt: _time(json['createdAt']),
      );

  final String doctorId;
  final String fullName;
  final String? fullNameEn;
  final String title;
  final String? titleEn;
  final String licenseNumber;
  final String specialtyId;
  final String specialtyAr;
  final String specialtyEn;
  final String? email;
  final String? phone;
  final bool emailVerified;
  final String status;
  final String? statusReason;
  final DateTime? statusChangedAt;
  final DateTime? trialEndsAt;
  final DateTime createdAt;

  String name(String languageCode) =>
      _displayName(languageCode, fullName, fullNameEn);
  String specialty(String languageCode) =>
      languageCode == 'en' ? specialtyEn : specialtyAr;
}

class DoctorMonthActivity {
  const DoctorMonthActivity({
    required this.monthKey,
    required this.examinations,
    required this.consultations,
    required this.platformFeesPiasters,
  });

  factory DoctorMonthActivity.fromJson(Map<String, dynamic> json) =>
      DoctorMonthActivity(
        monthKey: json['monthKey'] as String,
        examinations: _int(json['examinations']),
        consultations: _int(json['consultations']),
        platformFeesPiasters: _int(json['platformFeesPiasters']),
      );

  final String monthKey;
  final int examinations;
  final int consultations;
  final int platformFeesPiasters;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

/// A session as the admin sees it: time, type, fee and a masked name (AD5).
class DoctorSessionRow {
  const DoctorSessionRow({
    required this.id,
    required this.day,
    required this.at,
    required this.type,
    required this.feePiasters,
    required this.patientMasked,
    required this.deleted,
  });

  factory DoctorSessionRow.fromJson(Map<String, dynamic> json) =>
      DoctorSessionRow(
        id: json['id'] as String,
        day: parseDay(json['day']),
        at: _time(json['at']),
        type: SessionType.fromWire(json['type']),
        feePiasters: _int(json['feePiasters']),
        patientMasked: json['patientMasked'] as String,
        deleted: json['deleted'] as bool,
      );

  final String id;
  final DateTime day;
  final DateTime at;
  final SessionType type;
  final int feePiasters;
  final String patientMasked;
  final bool deleted;
}

class DoctorActivity {
  const DoctorActivity({
    required this.months,
    required this.month,
    required this.sessions,
  });

  factory DoctorActivity.fromJson(Map<String, dynamic> json) => DoctorActivity(
    months: [
      for (final row in _list(json['months']))
        DoctorMonthActivity.fromJson(row),
    ],
    month: json['month'] as String,
    sessions: Paged.fromJson(_map(json['sessions']), DoctorSessionRow.fromJson),
  );

  final List<DoctorMonthActivity> months;
  final String month;
  final Paged<DoctorSessionRow> sessions;
}

class DeletedSessionRow {
  const DeletedSessionRow({
    required this.id,
    required this.day,
    required this.type,
    this.deletedAt,
    this.reason,
    required this.patientMasked,
  });

  factory DeletedSessionRow.fromJson(Map<String, dynamic> json) =>
      DeletedSessionRow(
        id: json['id'] as String,
        day: parseDay(json['day']),
        type: SessionType.fromWire(json['type']),
        deletedAt: _timeOrNull(json['deletedAt']),
        reason: _text(json['reason']),
        patientMasked: json['patientMasked'] as String,
      );

  final String id;
  final DateTime day;
  final SessionType type;
  final DateTime? deletedAt;
  final String? reason;
  final String patientMasked;
}

class DoctorAuditRow {
  const DoctorAuditRow({
    required this.at,
    required this.action,
    required this.actorRole,
    this.details,
  });

  factory DoctorAuditRow.fromJson(Map<String, dynamic> json) => DoctorAuditRow(
    at: _time(json['at']),
    action: json['action'] as String,
    actorRole: json['actorRole'] as String,
    details: _text(json['details']),
  );

  final DateTime at;

  /// `doctorSuspended`, `doctorReactivated`, `doctorDisabled`, `doctorServiceActivated`, `doctorTrialExtended`, `invoiceOverdue`.
  final String action;
  final String actorRole;
  final String? details;
}

class DoctorAudit {
  const DoctorAudit({
    required this.deletedSessions,
    required this.statusChanges,
  });

  factory DoctorAudit.fromJson(Map<String, dynamic> json) => DoctorAudit(
    deletedSessions: Paged.fromJson(
      _map(json['deletedSessions']),
      DeletedSessionRow.fromJson,
    ),
    statusChanges: Paged.fromJson(
      _map(json['statusChanges']),
      DoctorAuditRow.fromJson,
    ),
  );

  final Paged<DeletedSessionRow> deletedSessions;
  final Paged<DoctorAuditRow> statusChanges;
}

class DoctorBranchRow {
  const DoctorBranchRow({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.area,
    required this.city,
    required this.status,
    required this.isDefault,
    required this.phones,
  });

  factory DoctorBranchRow.fromJson(Map<String, dynamic> json) =>
      DoctorBranchRow(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: _text(json['nameEn']),
        area: _text(json['area']),
        city: json['city'] as String,
        status: json['status'] as String,
        isDefault: json['isDefault'] as bool,
        phones: [for (final phone in json['phones'] as List) '$phone'],
      );

  final String id;
  final String nameAr;
  final String? nameEn;
  final String? area;
  final String city;
  final String status;
  final bool isDefault;
  final List<String> phones;

  String name(String languageCode) =>
      _displayName(languageCode, nameAr, nameEn);
}

class DoctorAppointmentsMonth {
  const DoctorAppointmentsMonth({
    required this.monthKey,
    required this.bookings,
    required this.noShows,
    required this.cancellations,
    required this.checkedInNoSession,
    required this.noShowRate,
  });

  factory DoctorAppointmentsMonth.fromJson(Map<String, dynamic> json) =>
      DoctorAppointmentsMonth(
        monthKey: json['monthKey'] as String,
        bookings: _int(json['bookings']),
        noShows: _int(json['noShows']),
        cancellations: _int(json['cancellations']),
        checkedInNoSession: _int(json['checkedInNoSession']),
        noShowRate: (json['noShowRate'] as num).toDouble(),
      );

  final String monthKey;
  final int bookings;
  final int noShows;
  final int cancellations;
  final int checkedInNoSession;

  /// 0–1.
  final double noShowRate;

  DateTime get month {
    final parts = monthKey.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
  }
}

class DoctorAssistantRow {
  const DoctorAssistantRow({
    required this.userId,
    required this.fullName,
    this.phone,
    required this.preset,
    required this.status,
    this.lastActiveAt,
  });

  factory DoctorAssistantRow.fromJson(Map<String, dynamic> json) =>
      DoctorAssistantRow(
        userId: json['userId'] as String,
        fullName: json['fullName'] as String,
        phone: _text(json['phone']),
        preset: json['preset'] as String,
        status: json['status'] as String,
        lastActiveAt: _timeOrNull(json['lastActiveAt']),
      );

  final String userId;
  final String fullName;
  final String? phone;
  final String preset;
  final String status;
  final DateTime? lastActiveAt;
}

class DoctorNote {
  const DoctorNote({
    required this.id,
    required this.text,
    required this.authorName,
    required this.createdAt,
  });

  factory DoctorNote.fromJson(Map<String, dynamic> json) => DoctorNote(
    id: json['id'] as String,
    text: json['text'] as String,
    authorName: json['authorName'] as String,
    createdAt: _time(json['createdAt']),
  );

  final String id;
  final String text;
  final String authorName;
  final DateTime createdAt;
}
