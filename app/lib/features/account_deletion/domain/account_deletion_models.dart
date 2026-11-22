import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';

/// Account deletion (spec 6.17; the contract is backend/docs/api-account-deletion.md).
/// Every role deletes from its settings; the account is disabled at once and
/// erased after the grace period; signing in meanwhile opens A16.

DateTime _time(Object? value) => DateTime.parse(value as String);

DateTime? _timeOrNull(Object? value) => value == null ? null : DateTime.parse(value as String);

DateTime _day(Object? value) {
  final parts = (value as String).split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

/// `DeletionRequests.Status`.
enum DeletionStatus {
  scheduled,
  waitingPayment,
  restored,
  completed;

  static DeletionStatus fromWire(Object? value) =>
      DeletionStatus.values.asNameMap()[value] ?? DeletionStatus.scheduled;

  /// Still in progress: it can be cancelled and the account restored.
  bool get open => this == scheduled || this == waitingPayment;
}

/// An invoice that refuses a doctor's deletion (`UNPAID_INVOICES`) or holds
/// its erasure back.
class UnpaidInvoice {
  const UnpaidInvoice({
    required this.id,
    required this.monthKey,
    required this.totalDuePiasters,
    required this.status,
    required this.dueDate,
  });

  factory UnpaidInvoice.fromJson(Map<String, dynamic> json) => UnpaidInvoice(
        id: json['id'] as String,
        monthKey: json['monthKey'] as String,
        totalDuePiasters: json['totalDuePiasters'] as int,
        status: json['status'] as String,
        dueDate: _day(json['dueDate']),
      );

  final String id;

  /// `2026-10`.
  final String monthKey;
  final int totalDuePiasters;
  final String status;
  final DateTime dueDate;

  /// The month as a date (the 1st), for formatting.
  DateTime get month {
    final parts = monthKey.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1]);
  }
}

/// One invoice a doctor's deletion would issue now (BR-DEL8).
class FinalInvoiceLine {
  const FinalInvoiceLine({
    required this.monthKey,
    required this.periodStart,
    required this.periodEnd,
    required this.amountPiasters,
    this.isFinal = true,
  });

  factory FinalInvoiceLine.fromJson(Map<String, dynamic> json) => FinalInvoiceLine(
        monthKey: json['monthKey'] as String,
        periodStart: _day(json['periodStart']),
        periodEnd: _day(json['periodEnd']),
        amountPiasters: json['amountPiasters'] as int,
        isFinal: json['isFinal'] as bool? ?? true,
      );

  final String monthKey;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int amountPiasters;

  /// The month closed early (PeriodEnd = today); false for a past month not
  /// invoiced yet.
  final bool isFinal;
}

/// What a doctor's deletion would bill: «هيتعمل فاتورة نهائية بمبلغ …».
class FinalInvoicePreview {
  const FinalInvoicePreview({required this.amountPiasters, this.invoices = const []});

  factory FinalInvoicePreview.fromJson(Map<String, dynamic> json) => FinalInvoicePreview(
        amountPiasters: json['amountPiasters'] as int,
        invoices: [
          for (final line in json['invoices'] as List? ?? const [])
            FinalInvoiceLine.fromJson((line as Map).cast<String, dynamic>()),
        ],
      );

  final int amountPiasters;
  final List<FinalInvoiceLine> invoices;
}

/// Why the deletion can't start now (`getAccountDeletion.refusal`).
enum DeletionRefusal {
  alreadyScheduled('ACCOUNT_DELETION_SCHEDULED'),
  unpaidInvoices('UNPAID_INVOICES'),
  lastSuperAdmin('LAST_SUPER_ADMIN');

  const DeletionRefusal(this.code);

  final String code;

  static DeletionRefusal? fromWire(Object? value) =>
      DeletionRefusal.values.where((r) => r.code == value).firstOrNull;
}

/// `GET /me/accountDeletion`: what deleting the account does now, or the
/// deletion in progress.
class AccountDeletionState {
  const AccountDeletionState({
    required this.role,
    required this.graceDays,
    required this.scheduledForIfNow,
    this.pending,
    this.unpaidInvoices = const [],
    this.finalInvoice,
    this.refusal,
  });

  factory AccountDeletionState.fromJson(Map<String, dynamic> json) => AccountDeletionState(
        role: UserRole.fromJson(json['role'] as String),
        graceDays: json['graceDays'] as int,
        scheduledForIfNow: _time(json['scheduledForIfNow']),
        pending: json['pending'] == null
            ? null
            : PendingDeletion.fromJson((json['pending'] as Map).cast<String, dynamic>()),
        unpaidInvoices: [
          for (final item in json['unpaidInvoices'] as List? ?? const [])
            UnpaidInvoice.fromJson((item as Map).cast<String, dynamic>()),
        ],
        finalInvoice: json['finalInvoice'] == null
            ? null
            : FinalInvoicePreview.fromJson((json['finalInvoice'] as Map).cast<String, dynamic>()),
        refusal: DeletionRefusal.fromWire(json['refusal']),
      );

  final UserRole role;
  final int graceDays;

  /// When the identity would be erased if the deletion started now.
  final DateTime scheduledForIfNow;
  final PendingDeletion? pending;
  final List<UnpaidInvoice> unpaidInvoices;
  final FinalInvoicePreview? finalInvoice;
  final DeletionRefusal? refusal;

  bool get canRequest => refusal == null;
}

/// `requestAccountDeletion`'s answer. Every session of the account is already
/// signed out, this one too.
class AccountDeletionStarted {
  const AccountDeletionStarted({
    required this.requestId,
    required this.scheduledFor,
    this.cancelledBookings = 0,
    this.finalInvoice,
  });

  factory AccountDeletionStarted.fromJson(Map<String, dynamic> json) => AccountDeletionStarted(
        requestId: json['requestId'] as String,
        scheduledFor: _time(json['scheduledFor']),
        cancelledBookings: json['cancelledBookings'] as int? ?? 0,
        finalInvoice: json['finalInvoice'] == null
            ? null
            : FinalInvoicePreview.fromJson((json['finalInvoice'] as Map).cast<String, dynamic>()),
      );

  final String requestId;
  final DateTime scheduledFor;
  final int cancelledBookings;
  final FinalInvoicePreview? finalInvoice;
}

/// One row of AD12. After erasure [displayName] is the role's «… محذوف» and
/// [phone] and [email] are null.
class AccountDeletionItem {
  const AccountDeletionItem({
    required this.id,
    required this.userId,
    required this.role,
    required this.displayName,
    this.phone,
    this.email,
    required this.status,
    this.reason,
    required this.requestedAt,
    this.requestedByAdmin = false,
    this.requestedByName,
    required this.scheduledFor,
    this.restoredAt,
    this.restoredByName,
    this.restoreReason,
    this.completedAt,
    this.unpaidInvoices = 0,
    this.outstandingPiasters = 0,
  });

  factory AccountDeletionItem.fromJson(Map<String, dynamic> json) => AccountDeletionItem(
        id: json['id'] as String,
        userId: json['userId'] as String,
        role: UserRole.fromJson(json['role'] as String),
        displayName: json['displayName'] as String? ?? '',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        status: DeletionStatus.fromWire(json['status']),
        reason: json['reason'] as String?,
        requestedAt: _time(json['requestedAt']),
        requestedByAdmin: json['requestedByAdmin'] as bool? ?? false,
        requestedByName: json['requestedByName'] as String?,
        scheduledFor: _time(json['scheduledFor']),
        restoredAt: _timeOrNull(json['restoredAt']),
        restoredByName: json['restoredByName'] as String?,
        restoreReason: json['restoreReason'] as String?,
        completedAt: _timeOrNull(json['completedAt']),
        unpaidInvoices: json['unpaidInvoices'] as int? ?? 0,
        outstandingPiasters: json['outstandingPiasters'] as int? ?? 0,
      );

  final String id;
  final String userId;
  final UserRole role;
  final String displayName;
  final String? phone;
  final String? email;
  final DeletionStatus status;
  final String? reason;
  final DateTime requestedAt;
  final bool requestedByAdmin;
  final String? requestedByName;
  final DateTime scheduledFor;
  final DateTime? restoredAt;
  final String? restoredByName;
  final String? restoreReason;
  final DateTime? completedAt;
  final int unpaidInvoices;
  final int outstandingPiasters;

  AccountDeletionItem copyWith({
    DeletionStatus? status,
    DateTime? restoredAt,
    String? restoredByName,
    String? restoreReason,
  }) =>
      AccountDeletionItem(
        id: id,
        userId: userId,
        role: role,
        displayName: displayName,
        phone: phone,
        email: email,
        status: status ?? this.status,
        reason: reason,
        requestedAt: requestedAt,
        requestedByAdmin: requestedByAdmin,
        requestedByName: requestedByName,
        scheduledFor: scheduledFor,
        restoredAt: restoredAt ?? this.restoredAt,
        restoredByName: restoredByName ?? this.restoredByName,
        restoreReason: restoreReason ?? this.restoreReason,
        completedAt: completedAt,
        unpaidInvoices: unpaidInvoices,
        outstandingPiasters: outstandingPiasters,
      );
}

/// A page of AD12.
class AccountDeletionPage {
  const AccountDeletionPage({required this.items, this.page = 1, this.totalCount = 0, this.hasMore = false});

  factory AccountDeletionPage.fromJson(Map<String, dynamic> json) => AccountDeletionPage(
        items: [
          for (final item in json['items'] as List? ?? const [])
            AccountDeletionItem.fromJson((item as Map).cast<String, dynamic>()),
        ],
        page: json['page'] as int? ?? 1,
        totalCount: json['totalCount'] as int? ?? 0,
        hasMore: json['hasMore'] as bool? ?? false,
      );

  final List<AccountDeletionItem> items;
  final int page;
  final int totalCount;
  final bool hasMore;
}

/// AD12's filters. Null is "all".
class AccountDeletionFilter {
  const AccountDeletionFilter({this.role, this.status});

  final UserRole? role;
  final DeletionStatus? status;

  AccountDeletionFilter withRole(UserRole? value) => AccountDeletionFilter(role: value, status: status);

  AccountDeletionFilter withStatus(DeletionStatus? value) => AccountDeletionFilter(role: role, status: value);

  @override
  bool operator ==(Object other) => other is AccountDeletionFilter && other.role == role && other.status == status;

  @override
  int get hashCode => Object.hash(role, status);
}

/// The names an erased account is replaced with (the API's `Tombstones`). The
/// app shows its own label for each, in the user's language.
abstract final class DeletedNames {
  static const patient = 'مريض محذوف';
  static const doctor = 'طبيب محذوف';
  static const assistant = 'مساعد محذوف';
  static const admin = 'مسؤول محذوف';
  static const doctorEn = 'Deleted doctor';

  /// The role of an erased account's name, or null for a real name.
  static UserRole? roleOf(String? name) => switch (name?.trim()) {
        patient => UserRole.patient,
        doctor || doctorEn => UserRole.doctor,
        assistant => UserRole.assistant,
        admin => UserRole.admin,
        _ => null,
      };

  static bool isDeleted(String? name) => roleOf(name) != null;
}
