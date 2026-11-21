import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/billing_providers.dart';
import '../data/billing_repository.dart';
import '../domain/billing_models.dart';
import 'billing_widgets.dart';

/// D19: one invoice: the period, the counts and amounts, the totals per branch,
/// adjustments, the status timeline, the submitted payments with their
/// screenshots and a rejection's reason. **Pay** appears while the invoice is
/// unpaid, rejected or overdue, for those who may pay (`billingPay`).
class InvoiceDetailsScreen extends ConsumerWidget {
  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.billingView)) {
            return const AdminErrorView(
              error: ApiException(
                kind: ApiErrorKind.http,
                status: 403,
                code: ApiCodes.permissionDenied,
              ),
            );
          }
          final l10n = AppLocalizations.of(context);
          final detail = ref.watch(invoiceDetailProvider(invoiceId));
          return LayoutBuilder(
            builder: (context, constraints) {
              final gutter = clinicGutter(constraints.maxWidth);
              final wide = constraints.maxWidth >= 840;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
                    child: ClinicHeader(
                      title: detail.value == null
                          ? l10n.billInvoiceTitle
                          : l10n.billInvoiceOfMonth(
                              invoiceMonthLabel(context, detail.value!.invoice),
                            ),
                      subtitle: l10n.billInvoiceSubtitle,
                      backFallback: paths.billing,
                    ),
                  ),
                  Expanded(
                    child: AsyncStateSwitcher<InvoiceDetail>(
                      value: detail,
                      loading: (context) => const SkeletonLoading(
                        loading: true,
                        child: _Skeleton(),
                      ),
                      error: (context, error) => AdminErrorView(
                        error: error,
                        onRetry: () =>
                            ref.invalidate(invoiceDetailProvider(invoiceId)),
                      ),
                      data: (context, data) {
                        final canPay =
                            data.invoice.canPay &&
                            clinic.can(ClinicPermission.billingPay);
                        return Stack(
                          children: [
                            ListView(
                              padding: EdgeInsets.fromLTRB(
                                wide ? gutter + 120 : gutter,
                                0,
                                wide ? gutter + 120 : gutter,
                                canPay ? 104 : 32,
                              ),
                              children: [
                                if (data.lastRejectionReason != null &&
                                    data.invoice.status ==
                                        InvoiceStatus.rejected)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _RejectedNotice(
                                      reason: data.lastRejectionReason!,
                                    ),
                                  ),
                                InvoiceDetailBody(
                                  detail: data,
                                  loadScreenshot: (paymentId, number) => ref
                                      .read(billingRepositoryProvider)
                                      .screenshot(paymentId, number),
                                ),
                              ],
                            ),
                            if (canPay)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _PayBar(
                                  onPay: () =>
                                      context.go(paths.payInvoice(invoiceId)),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _RejectedNotice extends StatelessWidget {
  const _RejectedNotice({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cancel_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.billRejectedTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.billRejectedBody(reason),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayBar extends StatelessWidget {
  const _PayBar({required this.onPay});

  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.billPay),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    children: [
      for (var i = 0; i < 3; i++)
        const Card(
          child: SizedBox(
            height: 140,
            child: Center(child: Text('██████████')),
          ),
        ),
    ],
  );
}
