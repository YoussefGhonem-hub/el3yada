import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../../core/format/app_format.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../domain/billing_models.dart';

/// Shared pieces of the invoice screens of the clinic (D18–D20, AS10) and of
/// the admin (AD7–AD10).

/// «Unpaid», «Pending review», … for a status chip.
String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus status) =>
    switch (status) {
      InvoiceStatus.unpaid => l10n.billStatusUnpaid,
      InvoiceStatus.pendingReview => l10n.billStatusPendingReview,
      InvoiceStatus.paid => l10n.billStatusPaid,
      InvoiceStatus.rejected => l10n.billStatusRejected,
      InvoiceStatus.overdue => l10n.billStatusOverdue,
      InvoiceStatus.waived => l10n.billStatusWaived,
      InvoiceStatus.noCharge => l10n.billStatusNoCharge,
    };

PillTone invoiceStatusTone(InvoiceStatus status) => switch (status) {
  InvoiceStatus.paid => PillTone.positive,
  InvoiceStatus.unpaid => PillTone.warning,
  InvoiceStatus.pendingReview => PillTone.accent,
  InvoiceStatus.rejected || InvoiceStatus.overdue => PillTone.danger,
  InvoiceStatus.waived || InvoiceStatus.noCharge => PillTone.neutral,
};

IconData invoiceStatusIcon(InvoiceStatus status) => switch (status) {
  InvoiceStatus.paid => Icons.check_circle_outline,
  InvoiceStatus.unpaid => Icons.schedule,
  InvoiceStatus.pendingReview => Icons.hourglass_top,
  InvoiceStatus.rejected => Icons.cancel_outlined,
  InvoiceStatus.overdue => Icons.error_outline,
  InvoiceStatus.waived => Icons.volunteer_activism_outlined,
  InvoiceStatus.noCharge => Icons.remove_circle_outline,
};

/// An invoice's status as a pill with its icon (always text, never colour alone).
class InvoiceStatusPill extends StatelessWidget {
  const InvoiceStatusPill(this.status, {super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) => StatusPill(
    label: invoiceStatusLabel(AppLocalizations.of(context), status),
    tone: invoiceStatusTone(status),
    icon: invoiceStatusIcon(status),
  );
}

/// «أكتوبر 2026» / "October 2026" for an invoice's month.
String invoiceMonthLabel(BuildContext context, InvoiceItem invoice) =>
    ClinicFormat.month(context, invoice.month);

/// «اليوم», «غداً», «بعد 3 أيام», «متأخرة 5 أيام» for the days until [InvoiceItem.dueDate].
String dueCountdown(AppLocalizations l10n, int daysLeft) {
  if (daysLeft < 0) return l10n.billDueLate(-daysLeft);
  if (daysLeft == 0) return l10n.billDueToday;
  if (daysLeft == 1) return l10n.billDueTomorrow;
  return l10n.billDueInDays(daysLeft);
}

/// One line of an invoice list: month, amount, due date and status. Tappable.
class InvoiceRow extends StatelessWidget {
  const InvoiceRow({
    super.key,
    required this.invoice,
    this.onTap,
    this.leading,
    this.title,
  });

  final InvoiceItem invoice;
  final VoidCallback? onTap;

  /// Before the month (AD9 puts the doctor here).
  final Widget? leading;

  /// Replaces the month as the first line (AD9: the doctor's name).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final noCharge = invoice.status == InvoiceStatus.noCharge;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? invoiceMonthLabel(context, invoice),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (title != null) invoiceMonthLabel(context, invoice),
                      if (!noCharge)
                        l10n.billCounts(
                          invoice.examCount,
                          invoice.consultationCount,
                        ),
                      if (!noCharge && invoice.status.outstanding)
                        l10n.billDueOn(
                          ClinicFormat.dayAuto(context, invoice.dueDate),
                        ),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!noCharge)
                    LtrText(
                      AppFormat.egp(context, invoice.totalDuePiasters),
                      style: theme.textTheme.titleSmall,
                    ),
                  const SizedBox(height: 4),
                  InvoiceStatusPill(invoice.status),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The body of an invoice (D19, AD10): the totals, the branches, the
/// adjustments, the status timeline and the payments with their screenshots.
/// [loadScreenshot] fetches an image (the clinic's and the admin's endpoints differ).
class InvoiceDetailBody extends StatelessWidget {
  const InvoiceDetailBody({
    super.key,
    required this.detail,
    required this.loadScreenshot,
  });

  final InvoiceDetail detail;
  final Future<Uint8List> Function(String paymentId, int number) loadScreenshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final invoice = detail.invoice;
    final theme = Theme.of(context);

    Widget amountRow(String label, int piasters, {bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: bold
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium,
                ),
              ),
              LtrText(
                AppFormat.egp(context, piasters),
                style: bold
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l10n.billInvoiceTotals,
          icon: Icons.receipt_long_outlined,
          trailing: InvoiceStatusPill(invoice.status),
          child: Column(
            children: [
              amountRow(
                l10n.billExaminationsLine(invoice.examCount),
                invoice.examAmountPiasters,
              ),
              amountRow(
                l10n.billConsultationsLine(invoice.consultationCount),
                invoice.consultationAmountPiasters,
              ),
              for (final adjustment in detail.adjustments) ...[
                amountRow(
                  l10n.billAdjustmentLine(adjustment.reason),
                  adjustment.amountPiasters,
                ),
              ],
              const Divider(height: 20),
              amountRow(
                l10n.billTotalDue,
                invoice.totalDuePiasters,
                bold: true,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.billPeriodLine(
                        ClinicFormat.month(context, invoice.month),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (invoice.status.outstanding)
                    Text(
                      l10n.billDueOn(
                        ClinicFormat.day(context, invoice.dueDate),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (invoice.status == InvoiceStatus.paid &&
                  invoice.paidAt != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.billPaidOn(
                      AppFormat.date(context, invoice.paidAt!),
                      detail.paidMethod == null
                          ? ''
                          : paidMethodLabel(l10n, detail.paidMethod!),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (detail.branches.length > 1) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.billByBranch,
            icon: Icons.store_mall_directory_outlined,
            child: Column(
              children: [
                for (final branch in detail.branches)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                branch.name(language),
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                l10n.billCounts(
                                  branch.examCount,
                                  branch.consultationCount,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        LtrText(
                          AppFormat.egp(context, branch.amountPiasters),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (detail.payments.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.billPayments,
            icon: Icons.payments_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, payment) in detail.payments.indexed) ...[
                  if (i > 0) const Divider(height: 24),
                  PaymentCard(payment: payment, loadScreenshot: loadScreenshot),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.billTimeline,
          icon: Icons.timeline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final step in detail.timeline) _TimelineStep(step: step),
            ],
          ),
        ),
      ],
    );
  }
}

String paidMethodLabel(AppLocalizations l10n, PaidMethod method) =>
    switch (method) {
      PaidMethod.instapay => l10n.billMethodInstapay,
      PaidMethod.cash => l10n.billMethodCash,
      PaidMethod.bankTransfer => l10n.billMethodBank,
      PaidMethod.other => l10n.billMethodOther,
    };

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.step});

  final InvoiceTimelineLine step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            invoiceStatusIcon(step.status),
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoiceStatusLabel(l10n, step.status),
                  style: theme.textTheme.bodyMedium,
                ),
                if (step.note != null)
                  Text(
                    step.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  AppFormat.dateTime(context, step.changedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A payment attempt: the amount, the transfer, the status, the rejection
/// reason and the screenshots (tap one to see it large).
class PaymentCard extends StatelessWidget {
  const PaymentCard({
    super.key,
    required this.payment,
    required this.loadScreenshot,
  });

  final PaymentLine payment;
  final Future<Uint8List> Function(String paymentId, int number) loadScreenshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, tone) = switch (payment.status) {
      PaymentStatus.pendingReview => (l10n.billPaymentPending, PillTone.accent),
      PaymentStatus.approved => (l10n.billPaymentApproved, PillTone.positive),
      PaymentStatus.rejected => (l10n.billPaymentRejected, PillTone.danger),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: LtrText(
                AppFormat.egp(context, payment.amountPiasters),
                style: theme.textTheme.titleSmall,
              ),
            ),
            StatusPill(label: label, tone: tone),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          [
            l10n.billTransferOn(
              ClinicFormat.day(context, payment.transferDate),
            ),
            if (payment.senderName != null) payment.senderName!,
            if (payment.reference != null)
              l10n.billReference(payment.reference!),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (payment.note != null)
          Text(payment.note!, style: theme.textTheme.bodySmall),
        if (payment.rejectionReason != null) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.billRejectionReason(payment.rejectionReason!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (payment.screenshots > 0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 1; n <= payment.screenshots; n++)
                OutlinedButton.icon(
                  onPressed: () => showScreenshot(
                    context,
                    () => loadScreenshot(payment.id, n),
                  ),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(l10n.billScreenshotN(n)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Opens a payment screenshot in a dialog: pinch to zoom, loaded on demand.
Future<void> showScreenshot(
  BuildContext context,
  Future<Uint8List> Function() load,
) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
      child: FutureBuilder<Uint8List>(
        future: load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: AdminErrorView(error: snapshot.error!),
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return InteractiveViewer(
            maxScale: 5,
            child: Image.memory(snapshot.data!, fit: BoxFit.contain),
          );
        },
      ),
    ),
  ),
);
