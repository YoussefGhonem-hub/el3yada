import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/billing_providers.dart';
import '../domain/billing_models.dart';
import 'billing_widgets.dart';

/// D18 / AS10: the billing hub (`billingView`). What needs paying first, the
/// payment waiting for review, this month's running total (D3), and every
/// invoice. Open while suspended: paying is how the clinic comes back (BR-G5).
class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
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
        return LayoutBuilder(
          builder: (context, constraints) =>
              _Content(clinic: clinic, width: constraints.maxWidth),
        );
      },
    ),
  );
}

class _Content extends ConsumerWidget {
  const _Content({required this.clinic, required this.width});

  final ClinicContext clinic;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final gutter = clinicGutter(width);
    final invoices = ref.watch(invoiceListProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
          child: ClinicHeader(
            title: l10n.billTitle,
            subtitle: l10n.billSubtitle,
          ),
        ),
        Expanded(
          child: AsyncStateSwitcher<InvoiceList>(
            value: invoices,
            loading: (context) => SkeletonLoading(
              loading: true,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: gutter),
                children: [
                  _AttentionCard(
                    invoice: _placeholder,
                    canPay: false,
                    onOpen: () {},
                    onPay: () {},
                  ),
                  const SizedBox(height: 16),
                  GroupedRows(
                    children: [
                      for (var i = 0; i < 4; i++)
                        InvoiceRow(invoice: _placeholder),
                    ],
                  ),
                ],
              ),
            ),
            error: (context, error) => AdminErrorView(
              error: error,
              onRetry: () => ref.invalidate(invoiceListProvider),
            ),
            data: (context, list) => RefreshIndicator(
              onRefresh: () => ref.refresh(invoiceListProvider.future),
              child: ListView(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                children: [
                  if (width >= 960)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _Summary(
                            list: list,
                            clinic: clinic,
                            paths: paths,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 7,
                          child: _InvoiceList(list: list, paths: paths),
                        ),
                      ],
                    )
                  else ...[
                    _Summary(list: list, clinic: clinic, paths: paths),
                    const SizedBox(height: 16),
                    _InvoiceList(list: list, paths: paths),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static final _placeholder = InvoiceItem(
    id: 'x',
    monthKey: '2026-01',
    periodStart: DateTime.utc(2026),
    periodEnd: DateTime.utc(2026, 1, 31),
    examCount: 10,
    consultationCount: 5,
    examAmountPiasters: 30000,
    consultationAmountPiasters: 7500,
    adjustmentsPiasters: 0,
    totalDuePiasters: 37500,
    dueDate: DateTime.utc(2026, 2, 7),
    status: InvoiceStatus.unpaid,
    canPay: true,
  );
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.list,
    required this.clinic,
    required this.paths,
  });

  final InvoiceList list;
  final ClinicContext clinic;
  final ClinicPaths paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canPay = clinic.can(ClinicPermission.billingPay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (list.attention case final invoice?)
          StaggeredEntrance(
            index: 0,
            child: _AttentionCard(
              invoice: invoice,
              canPay: canPay,
              onOpen: () => context.go(paths.invoice(invoice.id)),
              onPay: () => context.go(paths.payInvoice(invoice.id)),
            ),
          ),
        if (list.underReview case final invoice?) ...[
          if (list.attention != null) const SizedBox(height: 12),
          StaggeredEntrance(
            index: 1,
            child: _UnderReviewCard(
              invoice: invoice,
              onOpen: () => context.go(paths.invoice(invoice.id)),
            ),
          ),
        ],
        if (list.attention == null && list.underReview == null)
          StaggeredEntrance(
            index: 0,
            child: SectionCard(
              title: l10n.billAllSettledTitle,
              icon: Icons.check_circle_outline,
              child: Text(l10n.billAllSettledBody),
            ),
          ),
        const SizedBox(height: 12),
        StaggeredEntrance(
          index: 2,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(l10n.billRunningMonth),
              subtitle: Text(l10n.billRunningMonthHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(paths.month()),
            ),
          ),
        ),
      ],
    );
  }
}

/// The invoice to pay first: its month, amount, due date with a countdown,
/// and Pay (when the caller may pay).
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.invoice,
    required this.canPay,
    required this.onOpen,
    required this.onPay,
  });

  final InvoiceItem invoice;
  final bool canPay;
  final VoidCallback onOpen;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final overdue = invoice.status == InvoiceStatus.overdue;
    final days = invoice.daysLeft(ClinicFormat.today());
    final background = overdue || invoice.status == InvoiceStatus.rejected
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = overdue || invoice.status == InvoiceStatus.rejected
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    return Pressable(
      onTap: onOpen,
      child: Card(
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.billInvoiceOfMonth(
                        invoiceMonthLabel(context, invoice),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                      ),
                    ),
                  ),
                  InvoiceStatusPill(invoice.status),
                ],
              ),
              const SizedBox(height: 12),
              LtrText(
                AppFormat.egp(context, invoice.totalDuePiasters),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.billDueOn(ClinicFormat.day(context, invoice.dueDate))} · ${dueCountdown(l10n, days)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
              if (canPay && invoice.canPay) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(l10n.billPay),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnderReviewCard extends StatelessWidget {
  const _UnderReviewCard({required this.invoice, required this.onOpen});

  final InvoiceItem invoice;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.hourglass_top),
        title: Text(
          l10n.billUnderReviewTitle(invoiceMonthLabel(context, invoice)),
        ),
        subtitle: Text(l10n.billUnderReviewBody),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.list, required this.paths});

  final InvoiceList list;
  final ClinicPaths paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (list.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: EmptyState(
          title: l10n.billEmptyTitle,
          message: l10n.billEmptyBody,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Semantics(
            header: true,
            child: Text(
              l10n.billInvoices,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        GroupedRows(
          children: [
            for (final (i, invoice) in list.items.indexed)
              StaggeredEntrance(
                index: i + 3,
                child: InvoiceRow(
                  invoice: invoice,
                  onTap: () => context.go(paths.invoice(invoice.id)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
