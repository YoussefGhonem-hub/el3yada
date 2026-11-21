import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';

/// D18 and D1's invoice card (`billingView`).
final invoiceListProvider = FutureProvider.autoDispose<InvoiceList>(
  (ref) => ref.watch(billingRepositoryProvider).invoices(),
  retry: noRetry,
);

/// D19.
final invoiceDetailProvider = FutureProvider.autoDispose
    .family<InvoiceDetail, String>(
      (ref, invoiceId) =>
          ref.watch(billingRepositoryProvider).invoice(invoiceId),
      retry: noRetry,
    );

/// D20's InstaPay box.
final paymentInfoProvider = FutureProvider.autoDispose<PaymentInfo>(
  (ref) => ref.watch(billingRepositoryProvider).paymentInfo(),
  retry: noRetry,
);

/// Invoices load again after a payment was submitted.
void refreshBilling(WidgetRef ref) {
  ref.invalidate(invoiceListProvider);
  ref.invalidate(invoiceDetailProvider);
}

/// Same as [refreshBilling] for callers whose widget is already gone.
void refreshBillingIn(ProviderContainer container) {
  container.invalidate(invoiceListProvider);
  container.invalidate(invoiceDetailProvider);
}
