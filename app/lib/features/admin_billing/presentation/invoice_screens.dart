import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';
import '../../billing/presentation/billing_widgets.dart';
import '../../patients/presentation/widgets/clinic_ui.dart'
    show ClinicChips, ClinicFormat;
import '../application/admin_billing_providers.dart';
import '../data/admin_billing_repository.dart';
import '../domain/admin_billing_models.dart';
import 'admin_billing_widgets.dart';
import 'paged_list.dart';

/// AD9: the invoices, filtered by month and status (and doctor), with a totals
/// row for the whole filtered set. Tap one for AD10.
class AdminInvoicesScreen extends ConsumerWidget {
  const AdminInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final filter = ref.watch(invoiceFilterProvider);
    final state = ref.watch(adminInvoicesProvider);
    final controller = ref.read(adminInvoicesProvider.notifier);
    final totals = ref.watch(invoiceTotalsProvider);
    void set(InvoiceFilter next) =>
        ref.read(invoiceFilterProvider.notifier).set(next);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        final months = lastMonthKeys(ClinicFormat.today());
        final filters = ClinicChips(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PopupMenuButton<String?>(
                tooltip: l10n.abFilterMonth,
                onSelected: (value) =>
                    set(filter.copyWith(month: value == '' ? null : value)),
                itemBuilder: (context) => [
                  PopupMenuItem(value: '', child: Text(l10n.abAllMonths)),
                  for (final key in months)
                    PopupMenuItem(
                      value: key,
                      child: Text(ClinicFormat.month(context, parseMonth(key))),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(
                    filter.month == null
                        ? l10n.abAllMonths
                        : ClinicFormat.month(
                            context,
                            parseMonth(filter.month!),
                          ),
                  ),
                ),
              ),
              ChoiceChip(
                label: Text(l10n.abAllStatuses),
                selected: filter.status == null,
                onSelected: (_) => set(filter.copyWith(status: null)),
              ),
              for (final status in filterableStatuses)
                ChoiceChip(
                  label: Text(invoiceStatusLabel(l10n, status)),
                  selected: filter.status == status,
                  onSelected: (_) => set(filter.copyWith(status: status)),
                ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
              child: AdminHeader(
                title: l10n.abInvoicesTitle,
                subtitle: l10n.abInvoicesSubtitle,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
              child: filters,
            ),
            Expanded(
              child: PagedGroupedList<AdminInvoiceItem>(
                state: state,
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                onLoadMore: controller.loadMore,
                onRefresh: controller.refresh,
                onRetry: controller.reload,
                empty: (context) => EmptyState(
                  title: l10n.abInvoicesEmptyTitle,
                  message: l10n.abInvoicesEmptyBody,
                ),
                skeletonRow: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Text('████████████  ████'),
                ),
                header: totals == null || state.loading
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TotalsRow(totals: totals),
                      ),
                itemBuilder: (context, item) =>
                    _InvoiceListRow(item: item, language: language),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.totals});

  final InvoiceTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget cell(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: LtrText(value, style: theme.textTheme.titleMedium),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      child: Card(
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              cell(l10n.abTotalsInvoices, '${totals.count}'),
              cell(l10n.abTotalsExaminations, '${totals.examCount}'),
              cell(l10n.abTotalsConsultations, '${totals.consultationCount}'),
              cell(
                l10n.abTotalsAmount,
                AppFormat.egp(context, totals.totalDuePiasters),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceListRow extends StatelessWidget {
  const _InvoiceListRow({required this.item, required this.language});

  final AdminInvoiceItem item;
  final String language;

  @override
  Widget build(BuildContext context) {
    final invoice = InvoiceItem(
      id: item.id,
      monthKey: item.monthKey,
      periodStart: item.month,
      periodEnd: DateTime.utc(item.month.year, item.month.month + 1, 0),
      examCount: item.examCount,
      consultationCount: item.consultationCount,
      examAmountPiasters: 0,
      consultationAmountPiasters: 0,
      adjustmentsPiasters: 0,
      totalDuePiasters: item.totalDuePiasters,
      dueDate: item.dueDate,
      status: item.status,
      canPay: item.status.payable,
    );
    return InvoiceRow(
      invoice: invoice,
      title: item.doctor(language),
      leading: InitialAvatar(name: item.doctor(language)),
      onTap: () => context.go('/admin/invoices/${item.id}'),
    );
  }
}

// ---- AD10 ------------------------------------------------------------------------------------

/// AD10: an invoice's breakdown, adjustments, payments and status history, with
/// the admin's actions (BR-PAY4): mark paid, waive, adjust the amount, extend
/// the due date. Each needs a reason.
class AdminInvoiceScreen extends ConsumerStatefulWidget {
  const AdminInvoiceScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<AdminInvoiceScreen> createState() => _AdminInvoiceScreenState();
}

class _AdminInvoiceScreenState extends ConsumerState<AdminInvoiceScreen> {
  bool _busy = false;

  AdminBillingRepository get _repo => ref.read(adminBillingRepositoryProvider);

  Future<void> _run(Future<Object?> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(adminInvoiceProvider(widget.invoiceId));
      ref.invalidate(adminInvoicesProvider);
      ref.invalidate(adminDashboardProvider);
      showAdminSnack(context, done);
    } catch (error) {
      if (!mounted) return;
      showActionError(context, error);
      ref.invalidate(adminInvoiceProvider(widget.invoiceId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markPaid() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<(PaidMethod, String)>(
      context: context,
      builder: (context) => const _MarkPaidDialog(),
    );
    if (choice == null || !mounted) return;
    await _run(
      () => _repo.markInvoicePaid(
        widget.invoiceId,
        method: choice.$1,
        note: choice.$2,
      ),
      l10n.abMarkedPaidSnack,
    );
  }

  Future<void> _waive() async {
    final l10n = AppLocalizations.of(context);
    final reason = await askReason(
      context,
      title: l10n.abWaiveTitle,
      message: l10n.abWaiveBody,
      confirmLabel: l10n.abWaive,
      destructive: true,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _repo.waiveInvoice(widget.invoiceId, reason: reason),
      l10n.abWaivedSnack,
    );
  }

  Future<void> _adjust() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<(int, String)>(
      context: context,
      builder: (context) => const _AdjustDialog(),
    );
    if (choice == null || !mounted) return;
    await _run(
      () => _repo.adjustInvoice(
        widget.invoiceId,
        amountPiasters: choice.$1,
        reason: choice.$2,
      ),
      l10n.abAdjustedSnack,
    );
  }

  Future<void> _extend(InvoiceItem invoice) async {
    final l10n = AppLocalizations.of(context);
    final today = ClinicFormat.today();
    final date = await showDatePicker(
      context: context,
      initialDate: invoice.dueDate.add(const Duration(days: 7)),
      firstDate: invoice.dueDate.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: l10n.abExtendTitle,
    );
    if (date == null || !mounted) return;
    final reason = await askReason(
      context,
      title: l10n.abExtendTitle,
      confirmLabel: l10n.abExtend,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _repo.extendInvoiceDueDate(
        widget.invoiceId,
        newDueDate: DateTime.utc(date.year, date.month, date.day),
        reason: reason,
      ),
      l10n.abExtendedSnack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final detail = ref.watch(adminInvoiceProvider(widget.invoiceId));
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        final wide = constraints.maxWidth >= kAdminWideLayout;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
              child: AdminHeader(
                title: detail.value == null
                    ? l10n.abInvoiceTitle
                    : l10n.abInvoiceOf(
                        invoiceMonthLabel(context, detail.value!.invoice),
                      ),
                subtitle: detail.value?.doctor?.displayName(language),
                leading: const AdminBackButton(fallback: '/admin/invoices'),
              ),
            ),
            Expanded(
              child: AsyncStateSwitcher<InvoiceDetail>(
                value: detail,
                loading: (context) => const SkeletonLoading(
                  loading: true,
                  child: SizedBox(height: 360),
                ),
                error: (context, error) => AdminErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(adminInvoiceProvider(widget.invoiceId)),
                ),
                data: (context, data) {
                  final actionable =
                      data.invoice.status == InvoiceStatus.unpaid ||
                      data.invoice.status == InvoiceStatus.overdue ||
                      data.invoice.status == InvoiceStatus.rejected;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? gutter + 100 : gutter,
                      0,
                      wide ? gutter + 100 : gutter,
                      32,
                    ),
                    children: [
                      if (actionable) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _busy ? null : _markPaid,
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(l10n.abMarkPaid),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _waive,
                              icon: const Icon(
                                Icons.volunteer_activism_outlined,
                              ),
                              label: Text(l10n.abWaive),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _adjust,
                              icon: const Icon(Icons.tune),
                              label: Text(l10n.abAdjust),
                            ),
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _extend(data.invoice),
                              icon: const Icon(Icons.event_repeat_outlined),
                              label: Text(l10n.abExtend),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ] else if (data.invoice.status ==
                          InvoiceStatus.pendingReview)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.hourglass_top),
                              title: Text(l10n.abPendingHint),
                              trailing: TextButton(
                                onPressed: () => context.go('/admin/payments'),
                                child: Text(l10n.abOpenQueue),
                              ),
                            ),
                          ),
                        ),
                      InvoiceDetailBody(
                        detail: data,
                        loadScreenshot: (paymentId, number) =>
                            _repo.screenshot(paymentId, number),
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
  }
}

/// «Mark paid»: the method and a note (BR-PAY4).
class _MarkPaidDialog extends StatefulWidget {
  const _MarkPaidDialog();

  @override
  State<_MarkPaidDialog> createState() => _MarkPaidDialogState();
}

class _MarkPaidDialogState extends State<_MarkPaidDialog> {
  PaidMethod _method = PaidMethod.cash;
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.abMarkPaidTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.abMarkPaidBody),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in PaidMethod.values)
                    ChoiceChip(
                      label: Text(paidMethodLabel(l10n, method)),
                      selected: _method == method,
                      onSelected: (_) => setState(() => _method = method),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                decoration: InputDecoration(
                  labelText: l10n.abNoteLabel,
                  errorText: _error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          onPressed: () {
            final text = _note.text.trim();
            if (text.length < 3) {
              setState(() => _error = l10n.abReasonRequired);
              return;
            }
            Navigator.pop(context, (_method, text));
          },
          child: Text(l10n.abMarkPaid),
        ),
      ],
    );
  }
}

/// «Adjust the amount»: a signed amount (a discount is negative) and a reason.
class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog();

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  bool _discount = true;
  String? _amountError;
  String? _reasonError;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.abAdjustTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.abAdjustBody),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.abAdjustDiscount),
                    icon: const Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.abAdjustCharge),
                    icon: const Icon(Icons.add),
                  ),
                ],
                selected: {_discount},
                onSelectionChanged: (value) =>
                    setState(() => _discount = value.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.abAdjustAmount,
                  suffixText: l10n.billEgpUnit,
                  errorText: _amountError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 2,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                decoration: InputDecoration(
                  labelText: l10n.abReasonLabel,
                  errorText: _reasonError,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          onPressed: () {
            final amount = AppFormat.parseEgp(_amount.text);
            final reason = _reason.text.trim();
            setState(() {
              _amountError = amount == null || amount < 1
                  ? l10n.billErrorAmount
                  : null;
              _reasonError = reason.length < 3 ? l10n.abReasonRequired : null;
            });
            if (_amountError != null || _reasonError != null) return;
            Navigator.pop(context, (_discount ? -amount! : amount!, reason));
          },
          child: Text(l10n.abAdjust),
        ),
      ],
    );
  }
}
