import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../data/admin_billing_repository.dart';
import '../domain/admin_billing_models.dart';

/// AD1.
final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>(
  (ref) => ref.watch(adminBillingRepositoryProvider).dashboard(),
  retry: noRetry,
);

// ---- AD7, AD8 --------------------------------------------------------------------------------

/// AD7: the payments waiting for review, oldest first.
final paymentQueueProvider =
    NotifierProvider.autoDispose<
      PaymentQueueController,
      PagedState<PaymentQueueItem>
    >(PaymentQueueController.new);

class PaymentQueueController extends PagedController<PaymentQueueItem> {
  @override
  Future<Paged<PaymentQueueItem>> fetch(int page, int pageSize) => ref
      .read(adminBillingRepositoryProvider)
      .payments(
        status: PaymentStatus.pendingReview,
        page: page,
        pageSize: pageSize,
      );

  @override
  Object keyOf(PaymentQueueItem item) => item.paymentId;
}

/// AD8.
final paymentReviewProvider = FutureProvider.autoDispose
    .family<PaymentReview, String>(
      (ref, paymentId) =>
          ref.watch(adminBillingRepositoryProvider).payment(paymentId),
      retry: noRetry,
    );

/// The Payments tab of AD5: every payment of one doctor, newest first.
final doctorPaymentsProvider = FutureProvider.autoDispose
    .family<Paged<PaymentQueueItem>, String>(
      (ref, doctorId) => ref
          .watch(adminBillingRepositoryProvider)
          .payments(doctorId: doctorId, pageSize: 50),
      retry: noRetry,
    );

// ---- AD9, AD10 -------------------------------------------------------------------------------

class InvoiceFilterController extends Notifier<InvoiceFilter> {
  @override
  InvoiceFilter build() => const InvoiceFilter();

  void set(InvoiceFilter filter) => state = filter;
}

/// AD9's filter (month, status, doctor).
final invoiceFilterProvider =
    NotifierProvider.autoDispose<InvoiceFilterController, InvoiceFilter>(
      InvoiceFilterController.new,
    );

/// AD9: the invoices of the filter. The totals row covers the whole filtered set.
final adminInvoicesProvider =
    NotifierProvider.autoDispose<
      AdminInvoicesController,
      PagedState<AdminInvoiceItem>
    >(AdminInvoicesController.new);

class AdminInvoicesController extends PagedController<AdminInvoiceItem> {
  InvoiceTotals? _totals;

  /// The totals of the last page loaded (they cover the whole filtered set).
  InvoiceTotals? get totals => _totals;

  @override
  PagedState<AdminInvoiceItem> build() {
    ref.listen(invoiceFilterProvider, (previous, next) => reload());
    return super.build();
  }

  @override
  Future<Paged<AdminInvoiceItem>> fetch(int page, int pageSize) async {
    final result = await ref
        .read(adminBillingRepositoryProvider)
        .invoices(
          ref.read(invoiceFilterProvider),
          page: page,
          pageSize: pageSize,
        );
    _totals = result.totals;
    return result.page;
  }

  @override
  Object keyOf(AdminInvoiceItem item) => item.id;
}

/// The totals row of AD9 (read after the list loaded).
final invoiceTotalsProvider = Provider.autoDispose<InvoiceTotals?>((ref) {
  ref.watch(adminInvoicesProvider);
  return ref.read(adminInvoicesProvider.notifier).totals;
});

/// AD10.
final adminInvoiceProvider = FutureProvider.autoDispose
    .family<InvoiceDetail, String>(
      (ref, invoiceId) =>
          ref.watch(adminBillingRepositoryProvider).invoice(invoiceId),
      retry: noRetry,
    );

/// The Invoices tab of AD5.
final doctorInvoicesProvider = FutureProvider.autoDispose
    .family<AdminInvoicesPage, String>(
      (ref, doctorId) => ref
          .watch(adminBillingRepositoryProvider)
          .invoices(InvoiceFilter(doctorId: doctorId), pageSize: 50),
      retry: noRetry,
    );

// ---- AD4, AD5 --------------------------------------------------------------------------------

class DoctorFilterController extends Notifier<DoctorFilter> {
  @override
  DoctorFilter build() => const DoctorFilter();

  void set(DoctorFilter filter) => state = filter;
}

/// AD4's search, status filter and sort.
final doctorFilterProvider =
    NotifierProvider.autoDispose<DoctorFilterController, DoctorFilter>(
      DoctorFilterController.new,
    );

/// AD4: the doctors with the month's sessions and what they still owe.
final adminDoctorsProvider =
    NotifierProvider.autoDispose<
      AdminDoctorsController,
      PagedState<DoctorListItem>
    >(AdminDoctorsController.new);

class AdminDoctorsController extends PagedController<DoctorListItem> {
  @override
  PagedState<DoctorListItem> build() {
    ref.listen(doctorFilterProvider, (previous, next) => reload());
    return super.build();
  }

  @override
  Future<Paged<DoctorListItem>> fetch(int page, int pageSize) => ref
      .read(adminBillingRepositoryProvider)
      .doctors(ref.read(doctorFilterProvider), page: page, pageSize: pageSize);

  @override
  Object keyOf(DoctorListItem item) => item.doctorId;
}

final adminDoctorProfileProvider = FutureProvider.autoDispose
    .family<AdminDoctorProfile, String>(
      (ref, doctorId) =>
          ref.watch(adminBillingRepositoryProvider).doctorProfile(doctorId),
      retry: noRetry,
    );

final doctorActivityProvider = FutureProvider.autoDispose
    .family<DoctorActivity, String>(
      (ref, doctorId) =>
          ref.watch(adminBillingRepositoryProvider).doctorActivity(doctorId),
      retry: noRetry,
    );

final doctorAuditProvider = FutureProvider.autoDispose
    .family<DoctorAudit, String>(
      (ref, doctorId) =>
          ref.watch(adminBillingRepositoryProvider).doctorAudit(doctorId),
      retry: noRetry,
    );

final doctorBranchesProvider = FutureProvider.autoDispose
    .family<List<DoctorBranchRow>, String>(
      (ref, doctorId) =>
          ref.watch(adminBillingRepositoryProvider).doctorBranches(doctorId),
      retry: noRetry,
    );

final doctorAppointmentsProvider = FutureProvider.autoDispose
    .family<List<DoctorAppointmentsMonth>, String>(
      (ref, doctorId) => ref
          .watch(adminBillingRepositoryProvider)
          .doctorAppointments(doctorId),
      retry: noRetry,
    );

final doctorAssistantsProvider = FutureProvider.autoDispose
    .family<List<DoctorAssistantRow>, String>(
      (ref, doctorId) =>
          ref.watch(adminBillingRepositoryProvider).doctorAssistants(doctorId),
      retry: noRetry,
    );

final doctorNotesProvider = FutureProvider.autoDispose
    .family<List<DoctorNote>, String>(
      (ref, doctorId) =>
          ref.watch(adminBillingRepositoryProvider).doctorNotes(doctorId),
      retry: noRetry,
    );
