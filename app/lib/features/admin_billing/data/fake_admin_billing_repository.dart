import 'dart:typed_data';

import '../../../core/network/api_exception.dart';
import '../domain/admin_billing_models.dart';
import 'admin_billing_repository.dart';

/// Offline admin data for the dev account and the tests: three doctors, an
/// invoice each, two payments waiting for review (one with a wrong amount).
/// Approving, rejecting and the invoice actions change the lists like the API.
class FakeAdminBillingRepository implements AdminBillingRepository {
  FakeAdminBillingRepository({DateTime? today})
    : _today = today ?? _cairoToday() {
    DateTime month(int back) => DateTime.utc(_today.year, _today.month - back);
    String key(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

    _doctors = [
      _doc('d1', 'د. أحمد علي', 'Dr Ahmed Ali', 'active', 120, 0),
      _doc('d2', 'د. منى حسن', 'Dr Mona Hassan', 'suspended', 64, 78000),
      _doc('d3', 'د. كريم سمير', 'Dr Karim Samir', 'active', 31, 45000),
    ];

    InvoiceItem inv(
      String id,
      int back,
      InvoiceStatus status,
      int exams,
      int consultations,
    ) {
      final first = month(back);
      final last = DateTime.utc(first.year, first.month + 1, 0);
      final examAmount = exams * 3000;
      final consultationAmount = consultations * 1500;
      return InvoiceItem(
        id: id,
        monthKey: key(first),
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
      );
    }

    final items = <(InvoiceItem, String)>[
      (inv('i1', 1, InvoiceStatus.pendingReview, 40, 20), 'd1'),
      (inv('i2', 2, InvoiceStatus.overdue, 52, 31), 'd2'),
      (inv('i3', 1, InvoiceStatus.pendingReview, 22, 10), 'd3'),
      (inv('i4', 2, InvoiceStatus.paid, 47, 18), 'd1'),
    ];
    for (final (item, doctorId) in items) {
      _invoices[item.id] = InvoiceDetail(
        invoice: item,
        branches: const [],
        adjustments: const [],
        timeline: [
          InvoiceTimelineLine(
            status: InvoiceStatus.unpaid,
            changedAt: item.periodEnd.add(const Duration(days: 1)),
            changedByRole: 'system',
          ),
        ],
        payments: const [],
        doctor: InvoiceDoctorRef(
          id: doctorId,
          name: _doctors.firstWhere((d) => d.doctorId == doctorId).fullName,
          nameEn: _doctors.firstWhere((d) => d.doctorId == doctorId).fullNameEn,
          status: _doctors.firstWhere((d) => d.doctorId == doctorId).status,
        ),
      );
    }
    _payments = [
      _payment('p1', 'i1', 'd1', _invoices['i1']!.invoice.totalDuePiasters, 1),
      _payment('p2', 'i3', 'd3', 30000, 2),
    ];
  }

  static DateTime _cairoToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 2));
    return DateTime.utc(now.year, now.month, now.day);
  }

  final DateTime _today;
  late List<DoctorListItem> _doctors;
  final Map<String, InvoiceDetail> _invoices = {};
  late List<({PaymentQueueItem item, PaymentLine line})> _payments;
  final List<DoctorNote> _notes = [];

  DoctorListItem _doc(
    String id,
    String name,
    String nameEn,
    String status,
    int sessions,
    int outstanding,
  ) => DoctorListItem(
    doctorId: id,
    fullName: name,
    fullNameEn: nameEn,
    email: '$id@el3yada.dev',
    phone: '+20101234567${id.length}',
    clinicName: 'عيادة $name',
    clinicNameEn: '$nameEn clinic',
    governorate: 'القاهرة',
    specialtyAr: 'باطنة',
    specialtyEn: 'Internal medicine',
    status: status,
    createdAt: DateTime.utc(_today.year, _today.month - 6),
    sessionsThisMonth: sessions,
    outstandingPiasters: outstanding,
  );

  ({PaymentQueueItem item, PaymentLine line}) _payment(
    String id,
    String invoiceId,
    String doctorId,
    int amount,
    int days,
  ) {
    final invoice = _invoices[invoiceId]!.invoice;
    final doctor = _doctors.firstWhere((d) => d.doctorId == doctorId);
    final submitted = DateTime.now().toUtc().subtract(Duration(days: days));
    return (
      item: PaymentQueueItem(
        paymentId: id,
        invoiceId: invoiceId,
        doctorId: doctorId,
        doctorName: doctor.fullName,
        doctorNameEn: doctor.fullNameEn,
        monthKey: invoice.monthKey,
        invoiceTotalPiasters: invoice.totalDuePiasters,
        amountPiasters: amount,
        mismatch: amount != invoice.totalDuePiasters,
        submittedAt: submitted,
        status: PaymentStatus.pendingReview,
      ),
      line: PaymentLine(
        id: id,
        amountPiasters: amount,
        transferDate: _today.subtract(Duration(days: days)),
        reference: 'IP-$id',
        status: PaymentStatus.pendingReview,
        submittedAt: submitted,
        screenshots: 1,
      ),
    );
  }

  InvoiceState _state(InvoiceItem invoice) => InvoiceState(
    invoiceId: invoice.id,
    status: invoice.status,
    totalDuePiasters: invoice.totalDuePiasters,
    dueDate: invoice.dueDate,
  );

  void _setInvoice(
    String id,
    InvoiceStatus status, {
    int? total,
    DateTime? dueDate,
    String? note,
    int? adjustment,
    String? reason,
  }) {
    final detail = _invoices[id]!;
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
      adjustmentsPiasters: old.adjustmentsPiasters + (adjustment ?? 0),
      totalDuePiasters: total ?? old.totalDuePiasters,
      dueDate: dueDate ?? old.dueDate,
      status: status,
      canPay: status.payable,
      paidAt: status == InvoiceStatus.paid
          ? DateTime.now().toUtc()
          : old.paidAt,
    );
    _invoices[id] = InvoiceDetail(
      invoice: updated,
      paidMethod: detail.paidMethod,
      branches: detail.branches,
      adjustments: [
        ...detail.adjustments,
        if (adjustment != null)
          InvoiceAdjustment(
            id: 'a${detail.adjustments.length + 1}',
            amountPiasters: adjustment,
            reason: reason ?? '',
            createdAt: DateTime.now().toUtc(),
          ),
      ],
      timeline: [
        ...detail.timeline,
        InvoiceTimelineLine(
          status: status,
          note: note,
          changedAt: DateTime.now().toUtc(),
          changedByRole: 'admin',
        ),
      ],
      payments: detail.payments,
      doctor: detail.doctor,
    );
  }

  @override
  Future<AdminDashboard> dashboard() async {
    final pending = _payments
        .where((p) => p.item.status == PaymentStatus.pendingReview)
        .toList();
    final months = [
      for (var i = 11; i >= 0; i--) DateTime.utc(_today.year, _today.month - i),
    ];
    return AdminDashboard(
      doctors: DoctorCounts(
        active: 2,
        pendingApproval: 0,
        suspended: 1,
        disabled: 0,
        rejected: 0,
        inTrial: 1,
      ),
      totalPatients: 412,
      sessionsToday: const TypeCounts(examinations: 14, consultations: 6),
      sessionsThisMonth: const TypeCounts(examinations: 212, consultations: 96),
      bookingsToday: 31,
      noShowRateLast30Days: 0.11,
      expectedFeesThisMonthPiasters: 780000,
      lastMonth: InvoicedCollected(
        monthKey:
            '${_today.year}-${(_today.month - 1).toString().padLeft(2, '0')}',
        invoicedPiasters: 1950000,
        collectedPiasters: 1200000,
      ),
      outstandingPiasters: 1030000,
      overdueDoctors: 1,
      paymentsToReview: pending.length,
      signupsToReview: 0,
      sessionsPerDay: [
        for (var i = 29; i >= 0; i--)
          SessionsPerDay(
            day: _today.subtract(Duration(days: i)),
            examinations: 8 + (i % 5),
            consultations: 3 + (i % 3),
          ),
      ],
      invoicedVsCollected: [
        for (final (i, m) in months.indexed)
          InvoicedCollected(
            monthKey: '${m.year}-${m.month.toString().padLeft(2, '0')}',
            invoicedPiasters: 1200000 + i * 60000,
            collectedPiasters: i == 11 ? 0 : 1100000 + i * 55000,
          ),
      ],
      latestPayments: [for (final p in pending) p.item],
      latestSignups: [
        LatestSignup(
          doctorId: 'd3',
          fullName: 'د. كريم سمير',
          fullNameEn: 'Dr Karim Samir',
          specialtyAr: 'جلدية',
          specialtyEn: 'Dermatology',
          status: 'active',
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
        ),
      ],
      invoicesDueSoon: [
        for (final detail in _invoices.values)
          if (detail.invoice.status == InvoiceStatus.unpaid)
            AdminInvoiceItem(
              id: detail.invoice.id,
              doctorId: detail.doctor!.id,
              doctorName: detail.doctor!.name,
              doctorNameEn: detail.doctor!.nameEn,
              monthKey: detail.invoice.monthKey,
              examCount: detail.invoice.examCount,
              consultationCount: detail.invoice.consultationCount,
              totalDuePiasters: detail.invoice.totalDuePiasters,
              dueDate: detail.invoice.dueDate,
              status: detail.invoice.status,
            ),
      ],
    );
  }

  @override
  Future<Paged<PaymentQueueItem>> payments({
    PaymentStatus? status,
    String? doctorId,
    int page = 1,
    int pageSize = 25,
  }) async {
    final rows =
        _payments
            .map((p) => p.item)
            .where(
              (p) =>
                  (status == null || p.status == status) &&
                  (doctorId == null || p.doctorId == doctorId),
            )
            .toList()
          ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    return Paged.single(rows);
  }

  @override
  Future<PaymentReview> payment(String paymentId) async {
    final index = _payments.indexWhere((p) => p.item.paymentId == paymentId);
    if (index < 0) throw const ApiException.local('NOT_FOUND');
    final p = _payments[index];
    final invoice = _invoices[p.item.invoiceId]!.invoice;
    final doctor = _doctors.firstWhere((d) => d.doctorId == p.item.doctorId);
    return PaymentReview(
      payment: p.line,
      doctor: InvoiceDoctorRef(
        id: doctor.doctorId,
        name: doctor.fullName,
        nameEn: doctor.fullNameEn,
        status: doctor.status,
      ),
      invoice: InvoiceSummary(
        id: invoice.id,
        monthKey: invoice.monthKey,
        examCount: invoice.examCount,
        consultationCount: invoice.consultationCount,
        totalDuePiasters: invoice.totalDuePiasters,
        dueDate: invoice.dueDate,
        status: invoice.status,
      ),
      mismatch: p.item.mismatch,
      earlierAttempts: const [],
    );
  }

  @override
  Future<Uint8List> screenshot(String paymentId, int number) async =>
      throw const ApiException.local('NOT_FOUND');

  Future<InvoiceState> _review(
    String paymentId,
    PaymentStatus outcome,
    String? reason,
  ) async {
    final index = _payments.indexWhere((p) => p.item.paymentId == paymentId);
    if (index < 0) throw const ApiException.local('NOT_FOUND');
    final p = _payments[index];
    if (p.item.status != PaymentStatus.pendingReview)
      throw const ApiException.local(BillingCodes.paymentAlreadyReviewed);
    _payments[index] = (
      item: PaymentQueueItem(
        paymentId: p.item.paymentId,
        invoiceId: p.item.invoiceId,
        doctorId: p.item.doctorId,
        doctorName: p.item.doctorName,
        doctorNameEn: p.item.doctorNameEn,
        monthKey: p.item.monthKey,
        invoiceTotalPiasters: p.item.invoiceTotalPiasters,
        amountPiasters: p.item.amountPiasters,
        mismatch: p.item.mismatch,
        submittedAt: p.item.submittedAt,
        status: outcome,
      ),
      line: PaymentLine(
        id: p.line.id,
        amountPiasters: p.line.amountPiasters,
        transferDate: p.line.transferDate,
        reference: p.line.reference,
        status: outcome,
        submittedAt: p.line.submittedAt,
        reviewedAt: DateTime.now().toUtc(),
        rejectionReason: reason,
        screenshots: p.line.screenshots,
      ),
    );
    _setInvoice(
      p.item.invoiceId,
      outcome == PaymentStatus.approved
          ? InvoiceStatus.paid
          : InvoiceStatus.rejected,
      note: reason,
    );
    return _state(_invoices[p.item.invoiceId]!.invoice);
  }

  @override
  Future<InvoiceState> approvePayment(String paymentId) =>
      _review(paymentId, PaymentStatus.approved, null);

  @override
  Future<InvoiceState> rejectPayment(String paymentId, String reason) =>
      _review(paymentId, PaymentStatus.rejected, reason);

  @override
  Future<AdminInvoicesPage> invoices(
    InvoiceFilter filter, {
    int page = 1,
    int pageSize = 25,
  }) async {
    final rows = [
      for (final detail in _invoices.values)
        if ((filter.status == null || detail.invoice.status == filter.status) &&
            (filter.month == null || detail.invoice.monthKey == filter.month) &&
            (filter.doctorId == null || detail.doctor!.id == filter.doctorId))
          AdminInvoiceItem(
            id: detail.invoice.id,
            doctorId: detail.doctor!.id,
            doctorName: detail.doctor!.name,
            doctorNameEn: detail.doctor!.nameEn,
            monthKey: detail.invoice.monthKey,
            examCount: detail.invoice.examCount,
            consultationCount: detail.invoice.consultationCount,
            totalDuePiasters: detail.invoice.totalDuePiasters,
            dueDate: detail.invoice.dueDate,
            status: detail.invoice.status,
          ),
    ]..sort((a, b) => b.monthKey.compareTo(a.monthKey));
    return AdminInvoicesPage(
      page: Paged.single(rows),
      totals: InvoiceTotals(
        count: rows.length,
        examCount: rows.fold(0, (sum, r) => sum + r.examCount),
        consultationCount: rows.fold(0, (sum, r) => sum + r.consultationCount),
        totalDuePiasters: rows.fold(0, (sum, r) => sum + r.totalDuePiasters),
      ),
    );
  }

  @override
  Future<InvoiceDetail> invoice(String invoiceId) async {
    final detail = _invoices[invoiceId];
    if (detail == null) throw const ApiException.local('NOT_FOUND');
    final payments = [
      for (final p in _payments)
        if (p.item.invoiceId == invoiceId) p.line,
    ];
    return InvoiceDetail(
      invoice: detail.invoice,
      paidMethod: detail.paidMethod,
      branches: detail.branches,
      adjustments: detail.adjustments,
      timeline: detail.timeline,
      payments: payments,
      doctor: detail.doctor,
    );
  }

  void _guard(String invoiceId) {
    final status = _invoices[invoiceId]?.invoice.status;
    if (status == null) throw const ApiException.local('NOT_FOUND');
    if (!(status == InvoiceStatus.unpaid ||
        status == InvoiceStatus.overdue ||
        status == InvoiceStatus.rejected)) {
      throw const ApiException.local(BillingCodes.invoiceStatusInvalid);
    }
  }

  @override
  Future<InvoiceState> adjustInvoice(
    String invoiceId, {
    required int amountPiasters,
    required String reason,
  }) async {
    _guard(invoiceId);
    final invoice = _invoices[invoiceId]!.invoice;
    final total = invoice.totalDuePiasters + amountPiasters;
    if (total <= 0)
      throw const ApiException.local(BillingCodes.adjustmentInvalid);
    _setInvoice(
      invoiceId,
      invoice.status,
      total: total,
      adjustment: amountPiasters,
      reason: reason,
      note: reason,
    );
    return _state(_invoices[invoiceId]!.invoice);
  }

  @override
  Future<InvoiceState> waiveInvoice(
    String invoiceId, {
    required String reason,
  }) async {
    _guard(invoiceId);
    _setInvoice(invoiceId, InvoiceStatus.waived, note: reason);
    return _state(_invoices[invoiceId]!.invoice);
  }

  @override
  Future<InvoiceState> markInvoicePaid(
    String invoiceId, {
    required PaidMethod method,
    required String note,
  }) async {
    _guard(invoiceId);
    _setInvoice(invoiceId, InvoiceStatus.paid, note: '${method.wire}: $note');
    return _state(_invoices[invoiceId]!.invoice);
  }

  @override
  Future<InvoiceState> extendInvoiceDueDate(
    String invoiceId, {
    required DateTime newDueDate,
    required String reason,
  }) async {
    _guard(invoiceId);
    final invoice = _invoices[invoiceId]!.invoice;
    if (!newDueDate.isAfter(invoice.dueDate))
      throw const ApiException.local(BillingCodes.dueDateInvalid);
    _setInvoice(
      invoiceId,
      invoice.status == InvoiceStatus.overdue && !newDueDate.isBefore(_today)
          ? InvoiceStatus.unpaid
          : invoice.status,
      dueDate: newDueDate,
      note: reason,
    );
    return _state(_invoices[invoiceId]!.invoice);
  }

  @override
  Future<Paged<DoctorListItem>> doctors(
    DoctorFilter filter, {
    int page = 1,
    int pageSize = 25,
  }) async {
    final text = filter.search.trim().toLowerCase();
    final rows = _doctors
        .where(
          (d) =>
              (filter.status == null || d.status == filter.status) &&
              (text.isEmpty ||
                  d.fullName.toLowerCase().contains(text) ||
                  (d.fullNameEn ?? '').toLowerCase().contains(text)),
        )
        .toList();
    rows.sort(switch (filter.sort) {
      DoctorSort.name => (a, b) => a.fullName.compareTo(b.fullName),
      DoctorSort.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
      DoctorSort.sessions => (a, b) => b.sessionsThisMonth.compareTo(
        a.sessionsThisMonth,
      ),
      DoctorSort.outstanding => (a, b) => b.outstandingPiasters.compareTo(
        a.outstandingPiasters,
      ),
    });
    return Paged.single(rows);
  }

  DoctorListItem _find(String id) => _doctors.firstWhere(
    (d) => d.doctorId == id,
    orElse: () => throw const ApiException.local('NOT_FOUND'),
  );

  @override
  Future<AdminDoctorProfile> doctorProfile(String doctorId) async {
    final d = _find(doctorId);
    return AdminDoctorProfile(
      doctorId: d.doctorId,
      fullName: d.fullName,
      fullNameEn: d.fullNameEn,
      title: 'استشاري',
      titleEn: 'Consultant',
      licenseNumber: '12345',
      specialtyId: 'sp-1',
      specialtyAr: d.specialtyAr,
      specialtyEn: d.specialtyEn,
      email: d.email,
      phone: d.phone,
      emailVerified: true,
      status: d.status,
      statusReason: d.status == 'suspended'
          ? 'billing:${_invoices['i2']!.invoice.monthKey}'
          : null,
      createdAt: d.createdAt,
    );
  }

  @override
  Future<DoctorActivity> doctorActivity(
    String doctorId, {
    String? month,
    int page = 1,
  }) async {
    final key =
        month ?? '${_today.year}-${_today.month.toString().padLeft(2, '0')}';
    return DoctorActivity(
      months: [
        for (var i = 0; i < 6; i++)
          DoctorMonthActivity(
            monthKey:
                '${_today.year}-${(_today.month - i).clamp(1, 12).toString().padLeft(2, '0')}',
            examinations: 40 - i * 3,
            consultations: 20 - i,
            platformFeesPiasters: (40 - i * 3) * 3000 + (20 - i) * 1500,
          ),
      ],
      month: key,
      sessions: Paged.single([
        for (var i = 0; i < 6; i++)
          DoctorSessionRow(
            id: 's$i',
            day: _today.subtract(Duration(days: i)),
            at: DateTime.now().toUtc().subtract(Duration(days: i, hours: 2)),
            type: i.isEven ? SessionType.examination : SessionType.consultation,
            feePiasters: i.isEven ? 3000 : 1500,
            patientMasked: 'أ*** م***',
            deleted: false,
          ),
      ]),
    );
  }

  @override
  Future<DoctorAudit> doctorAudit(String doctorId) async => DoctorAudit(
    deletedSessions: Paged.single([
      DeletedSessionRow(
        id: 'x1',
        day: _today.subtract(const Duration(days: 9)),
        type: SessionType.examination,
        deletedAt: DateTime.now().toUtc().subtract(const Duration(days: 9)),
        reason: 'خطأ في الإدخال',
        patientMasked: 'م*** ح***',
      ),
    ]),
    statusChanges: Paged.single([
      DoctorAuditRow(
        at: DateTime.now().toUtc().subtract(const Duration(days: 12)),
        action: 'doctorSuspended',
        actorRole: 'system',
      ),
    ]),
  );

  @override
  Future<List<DoctorBranchRow>> doctorBranches(String doctorId) async => const [
    DoctorBranchRow(
      id: 'b1',
      nameAr: 'فرع المعادي',
      nameEn: 'Maadi branch',
      area: 'المعادي',
      city: 'القاهرة',
      status: 'active',
      isDefault: true,
      phones: ['+201012345678'],
    ),
  ];

  @override
  Future<List<DoctorAppointmentsMonth>> doctorAppointments(
    String doctorId,
  ) async => [
    DoctorAppointmentsMonth(
      monthKey: '${_today.year}-${_today.month.toString().padLeft(2, '0')}',
      bookings: 96,
      noShows: 11,
      cancellations: 8,
      checkedInNoSession: 2,
      noShowRate: 0.12,
    ),
  ];

  @override
  Future<List<DoctorAssistantRow>> doctorAssistants(String doctorId) async => [
    DoctorAssistantRow(
      userId: 'a1',
      fullName: 'منى (الاستقبال)',
      phone: '+201000000001',
      preset: 'reception',
      status: 'active',
      lastActiveAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
    ),
  ];

  @override
  Future<List<DoctorNote>> doctorNotes(String doctorId) async =>
      List.of(_notes.reversed);

  @override
  Future<void> addDoctorNote(String doctorId, String text) async => _notes.add(
    DoctorNote(
      id: 'n${_notes.length + 1}',
      text: text,
      authorName: 'Admin',
      createdAt: DateTime.now().toUtc(),
    ),
  );

  @override
  Future<void> sendPasswordReset(String doctorId) async {}

  @override
  Future<void> setDoctorStatus(
    String doctorId, {
    required String status,
    required String reason,
  }) async {
    final index = _doctors.indexWhere((d) => d.doctorId == doctorId);
    if (index < 0) throw const ApiException.local('NOT_FOUND');
    final d = _doctors[index];
    _doctors[index] = DoctorListItem(
      doctorId: d.doctorId,
      fullName: d.fullName,
      fullNameEn: d.fullNameEn,
      email: d.email,
      phone: d.phone,
      clinicName: d.clinicName,
      clinicNameEn: d.clinicNameEn,
      governorate: d.governorate,
      specialtyAr: d.specialtyAr,
      specialtyEn: d.specialtyEn,
      status: status,
      trialEndsAt: d.trialEndsAt,
      createdAt: d.createdAt,
      sessionsThisMonth: d.sessionsThisMonth,
      outstandingPiasters: d.outstandingPiasters,
    );
  }
}
