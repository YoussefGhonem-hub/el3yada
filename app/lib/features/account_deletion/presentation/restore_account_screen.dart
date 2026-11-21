import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/status_layout.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/support_contact.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';
import '../../billing/application/billing_providers.dart';
import '../../billing/domain/billing_models.dart';
import '../../billing/presentation/billing_widgets.dart';
import '../application/account_deletion_providers.dart';

/// A16: the account is in its deletion grace period (spec 6.17, BR-DEL3).
/// Signing in with the right password lands here and nowhere else: the
/// erasure date, Restore account and Sign out. Cancelled bookings stay
/// cancelled. A doctor also sees the invoices that hold the erasure back,
/// with Pay (D19 and D20 open under this screen).
///
/// Restore makes the account active again; the router then leaves A16.
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key});

  @override
  ConsumerState<RestoreAccountScreen> createState() => _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  SubmitStatus _status = SubmitStatus.idle;

  Future<void> _restore() async {
    if (_status != SubmitStatus.idle) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _status = SubmitStatus.loading);
    try {
      await ref.restoreAccount();
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeletionRestoreDone)));
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiError(error))));
      // Restored elsewhere (an admin, another device): the session says so.
      if (error.code == 'ACCOUNT_NOT_PENDING_DELETION') {
        await ref.read(authControllerProvider.notifier).reloadAccount();
      }
    } finally {
      if (mounted) setState(() => _status = SubmitStatus.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).value;
    final pending = session?.pendingDeletion;
    if (session == null || pending == null) return const Scaffold(body: SizedBox.shrink());
    final date = AppFormat.date(context, pending.scheduledFor);
    return StatusLayout(
      icon: Icons.hourglass_top_outlined,
      tone: StatusTone.error,
      title: l10n.accountDeletionRestoreTitle,
      message: pending.waitingPayment ? l10n.accountDeletionWaitingPaymentBody : l10n.accountDeletionRestoreBody(date),
      details: [
        _Facts(pending: pending),
        if (session.role == UserRole.doctor) const _InvoicesToPay(),
        if (pending.requestedByAdmin) const SupportContact(),
      ],
      actions: [
        SubmitButton(label: l10n.accountDeletionRestoreButton, status: _status, onPressed: _restore),
        TextButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.logout),
        ),
      ],
    );
  }
}

/// What the restore keeps and doesn't: the reason, and that cancelled bookings
/// stay cancelled.
class _Facts extends StatelessWidget {
  const _Facts({required this.pending});

  final PendingDeletion pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reason = pending.reason;
    final lines = [
      if (reason != null && reason.isNotEmpty)
        pending.requestedByAdmin ? l10n.accountDeletionRestoreByAdmin(reason) : l10n.reasonValue(reason),
      l10n.accountDeletionRestoreBookings,
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, line) in lines.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(i == lines.length - 1 ? Icons.event_busy_outlined : Icons.notes_outlined,
                      size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A doctor's invoices still to pay (BR-DEL9): the erasure waits for them.
/// Each opens D19 under A16, and Pay opens D20.
class _InvoicesToPay extends ConsumerWidget {
  const _InvoicesToPay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final invoices = ref.watch(invoiceListProvider);
    final due = invoices.value?.items
            .where((i) => i.canPay || i.status == InvoiceStatus.pendingReview)
            .toList() ??
        const <InvoiceItem>[];
    if (invoices.isLoading && !invoices.hasValue) return const Center(child: CircularProgressIndicator());
    if (invoices.hasError) {
      return Text(l10n.apiError(invoices.error!), textAlign: TextAlign.center);
    }
    if (due.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('restoreInvoices'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l10n.accountDeletionInvoicesTitle, style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.accountDeletionInvoicesBody,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (final invoice in due) ...[
            const Divider(height: 1),
            InvoiceRow(
              invoice: invoice,
              onTap: () => context.push('${AppRoutes.restoreAccount}/invoices/${invoice.id}'),
            ),
            if (invoice.canPay)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonalIcon(
                    onPressed: () => context.push('${AppRoutes.restoreAccount}/invoices/${invoice.id}/pay'),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text(l10n.billPay),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
