import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';
import '../domain/account_deletion_models.dart';
import 'account_deletion_repository.dart';

/// The offline accounts' deletions, kept by [FakeAuthRepository] so signing in
/// with an account in its grace period opens A16, as the API does. Keys are
/// the fake accounts' identifiers (`+201…#assistant` for the assistant on a
/// shared number).
class FakeDeletionStore {
  FakeDeletionStore() {
    // The offline account already in its grace period (the dev login lists it).
    for (final MapEntry(key: identifier, value: account) in FakeAuthRepository.accounts.entries) {
      final days = account.pendingDeletionInDays;
      if (days == null) continue;
      final now = DateTime.now().toUtc();
      pending[identifier] = PendingDeletion(
        requestId: 'del-$identifier',
        requestedAt: now.subtract(Duration(days: 30 - days)),
        scheduledFor: now.add(Duration(days: days)),
        reason: 'قفلت العيادة',
        unpaidInvoices: account.role == UserRole.doctor ? 1 : 0,
        outstandingPiasters: account.role == UserRole.doctor ? 4500 : 0,
        waitsForPayment: account.role == UserRole.doctor,
      );
    }
  }

  final Map<String, PendingDeletion> pending = {};

  /// The session for [identifier] with its deletion, if any.
  AuthSession apply(String identifier, AuthSession session) {
    final deletion = pending[identifier];
    return deletion == null
        ? session.copyWith(accountStatus: 'active', pendingDeletion: null)
        : session.copyWith(accountStatus: 'pendingDeletion', pendingDeletion: deletion);
  }
}

/// Offline deletions, consistent with the API: the password check (`wrong`
/// fails), the doctor's unpaid invoices (the suspended test doctor) and final
/// invoice, the last super admin, A16's restore, and AD12 with its actions.
class FakeAccountDeletionRepository implements AccountDeletionRepository {
  FakeAccountDeletionRepository(this._auth, {this.delay = const Duration(milliseconds: 300)});

  final FakeAuthRepository _auth;
  final Duration delay;

  static const graceDays = 30;

  /// The suspended test doctor owes October's invoice (BR-DEL7).
  static final _owed = UnpaidInvoice(
    id: 'inv-owed',
    monthKey: '2026-10',
    totalDuePiasters: 18000,
    status: 'overdue',
    dueDate: DateTime.utc(2026, 11, 7),
  );

  late final List<AccountDeletionItem> _items = _seed();

  FakeDeletionStore get _store => _auth.deletions;

  @override
  Future<AccountDeletionState> state() async {
    await Future<void>.delayed(delay);
    final session = _session();
    final key = _auth.keyOf(session);
    final pending = _store.pending[key];
    final now = DateTime.now().toUtc();
    final unpaid = session.role == UserRole.doctor && session.doctorStatus == DoctorStatus.suspended ? [_owed] : <UnpaidInvoice>[];
    final refusal = pending != null
        ? DeletionRefusal.alreadyScheduled
        : unpaid.isNotEmpty
            ? DeletionRefusal.unpaidInvoices
            : session.isSuperAdmin
                ? DeletionRefusal.lastSuperAdmin
                : null;
    return AccountDeletionState(
      role: session.role,
      graceDays: graceDays,
      scheduledForIfNow: now.add(const Duration(days: graceDays)),
      pending: pending,
      unpaidInvoices: pending != null && session.role == UserRole.doctor ? [_finalInvoice(now)] : unpaid,
      finalInvoice: session.role == UserRole.doctor && refusal == null ? _preview(now) : null,
      refusal: refusal,
    );
  }

  @override
  Future<AccountDeletionStarted> request({required String currentPassword, String? reason}) async {
    await Future<void>.delayed(delay);
    final current = await state();
    if (currentPassword == 'wrong' || currentPassword.isEmpty) {
      throw const ApiException(
        kind: ApiErrorKind.http,
        status: 400,
        code: ApiCodes.validationFailed,
        fieldCodes: {'currentPassword': 'CURRENT_PASSWORD_INCORRECT'},
      );
    }
    if (current.refusal case final refusal?) {
      throw ApiException(
        kind: ApiErrorKind.http,
        status: 409,
        code: refusal.code,
        details: {
          'code': refusal.code,
          if (refusal == DeletionRefusal.unpaidInvoices)
            'details': {
              'invoices': [
                for (final i in current.unpaidInvoices)
                  {'id': i.id, 'monthKey': i.monthKey, 'totalDuePiasters': i.totalDuePiasters, 'status': i.status},
              ],
            },
        },
      );
    }
    final session = _session();
    final now = DateTime.now().toUtc();
    final doctor = session.role == UserRole.doctor;
    final deletion = PendingDeletion(
      requestId: 'del-${now.microsecondsSinceEpoch}',
      requestedAt: now,
      scheduledFor: now.add(const Duration(days: graceDays)),
      reason: reason,
      unpaidInvoices: doctor ? 1 : 0,
      outstandingPiasters: doctor ? 4500 : 0,
      waitsForPayment: doctor,
    );
    _store.pending[_auth.keyOf(session)] = deletion;
    _items.insert(
      0,
      AccountDeletionItem(
        id: deletion.requestId,
        userId: session.userId,
        role: session.role,
        displayName: session.displayName,
        phone: session.phone,
        email: session.email,
        status: DeletionStatus.scheduled,
        reason: reason,
        requestedAt: now,
        requestedByName: session.displayName,
        scheduledFor: deletion.scheduledFor,
        unpaidInvoices: deletion.unpaidInvoices,
        outstandingPiasters: deletion.outstandingPiasters,
      ),
    );
    return AccountDeletionStarted(
      requestId: deletion.requestId,
      scheduledFor: deletion.scheduledFor,
      cancelledBookings: session.role == UserRole.patient ? 1 : (doctor ? 3 : 0),
      finalInvoice: doctor ? _preview(now) : null,
    );
  }

  @override
  Future<Map<String, dynamic>> restore() async {
    await Future<void>.delayed(delay);
    final session = _session();
    if (_store.pending.remove(_auth.keyOf(session)) == null) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: 'ACCOUNT_NOT_PENDING_DELETION');
    }
    _auth.current = session.copyWith(accountStatus: 'active', pendingDeletion: null);
    return _auth.me();
  }

  @override
  Future<AccountDeletionPage> list({
    AccountDeletionFilter filter = const AccountDeletionFilter(),
    String? userId,
    int page = 1,
  }) async {
    await Future<void>.delayed(delay);
    final items = _items
        .where((i) => filter.role == null || i.role == filter.role)
        .where((i) => filter.status == null || i.status == filter.status)
        .where((i) => userId == null || i.userId == userId)
        .toList();
    return AccountDeletionPage(items: items, totalCount: items.length);
  }

  @override
  Future<AccountDeletionItem> schedule({required String userId, required String reason}) async {
    await Future<void>.delayed(delay);
    if (_items.any((i) => i.userId == userId && i.status.open)) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: 'ACCOUNT_DELETION_SCHEDULED');
    }
    final now = DateTime.now().toUtc();
    // AD11's offline accounts are u-pat… and u-as…; AD5's doctors are anything else.
    final role = userId.startsWith('u-pat')
        ? UserRole.patient
        : userId.startsWith('u-as')
            ? UserRole.assistant
            : UserRole.doctor;
    final item = AccountDeletionItem(
      id: 'del-${now.microsecondsSinceEpoch}',
      userId: userId,
      role: role,
      displayName: switch (role) {
        UserRole.patient => 'محمد إبراهيم',
        UserRole.assistant => 'سارة علي',
        _ => 'د. أحمد سامي',
      },
      status: DeletionStatus.scheduled,
      reason: reason,
      requestedAt: now,
      requestedByAdmin: true,
      requestedByName: _auth.current?.displayName ?? 'Admin',
      scheduledFor: now.add(const Duration(days: graceDays)),
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<AccountDeletionItem> cancel(String requestId, {required String reason}) async {
    await Future<void>.delayed(delay);
    final index = _items.indexWhere((i) => i.id == requestId);
    if (index < 0) throw const ApiException(kind: ApiErrorKind.http, status: 404, code: ApiCodes.notFound);
    if (!_items[index].status.open) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: 'ACCOUNT_NOT_PENDING_DELETION');
    }
    final restored = _items[index].copyWith(
      status: DeletionStatus.restored,
      restoredAt: DateTime.now().toUtc(),
      restoredByName: _auth.current?.displayName ?? 'Admin',
      restoreReason: reason,
    );
    _items[index] = restored;
    _store.pending.removeWhere((_, deletion) => deletion.requestId == requestId);
    return restored;
  }

  AuthSession _session() =>
      _auth.current ?? (throw const ApiException(kind: ApiErrorKind.http, status: 401, code: 'UNAUTHENTICATED'));

  static FinalInvoicePreview _preview(DateTime now) {
    final cairo = now.add(const Duration(hours: 2));
    return FinalInvoicePreview(amountPiasters: 4500, invoices: [
      FinalInvoiceLine(
        monthKey: '${cairo.year}-${cairo.month.toString().padLeft(2, '0')}',
        periodStart: DateTime.utc(cairo.year, cairo.month),
        periodEnd: DateTime.utc(cairo.year, cairo.month, cairo.day),
        amountPiasters: 4500,
      ),
    ]);
  }

  static UnpaidInvoice _finalInvoice(DateTime now) {
    final line = _preview(now).invoices.single;
    return UnpaidInvoice(
      id: 'inv-final',
      monthKey: line.monthKey,
      totalDuePiasters: line.amountPiasters,
      status: 'unpaid',
      dueDate: line.periodEnd.add(const Duration(days: 7)),
    );
  }

  List<AccountDeletionItem> _seed() {
    final now = DateTime.now().toUtc();
    return [
      AccountDeletionItem(
        id: 'del-seed-1', userId: 'dev-doctor-deleting', role: UserRole.doctor, displayName: 'د. هشام فؤاد',
        email: 'deleting@el3yada.dev', status: DeletionStatus.waitingPayment, reason: 'قفلت العيادة',
        requestedAt: now.subtract(const Duration(days: 34)), requestedByName: 'د. هشام فؤاد',
        scheduledFor: now.subtract(const Duration(days: 4)), unpaidInvoices: 1, outstandingPiasters: 4500,
      ),
      AccountDeletionItem(
        id: 'del-seed-2', userId: 'u-pat-2', role: UserRole.patient, displayName: 'خالد يوسف', phone: '+201000000013',
        status: DeletionStatus.scheduled, reason: 'مش محتاج التطبيق', requestedAt: now.subtract(const Duration(days: 3)),
        requestedByName: 'خالد يوسف', scheduledFor: now.add(const Duration(days: 27)),
      ),
      AccountDeletionItem(
        id: 'del-seed-3', userId: 'u-as-2', role: UserRole.assistant, displayName: 'ريم صلاح', phone: '+201000000014',
        status: DeletionStatus.restored, requestedAt: now.subtract(const Duration(days: 12)), requestedByName: 'ريم صلاح',
        scheduledFor: now.add(const Duration(days: 18)), restoredAt: now.subtract(const Duration(days: 10)),
        restoredByName: 'ريم صلاح',
      ),
      AccountDeletionItem(
        id: 'del-seed-4', userId: 'u-pat-3', role: UserRole.patient, displayName: DeletedNames.patient,
        status: DeletionStatus.completed, reason: 'طلب بالتليفون', requestedAt: now.subtract(const Duration(days: 45)),
        requestedByAdmin: true, requestedByName: 'Admin', scheduledFor: now.subtract(const Duration(days: 15)),
        completedAt: now.subtract(const Duration(days: 15)),
      ),
    ];
  }
}
