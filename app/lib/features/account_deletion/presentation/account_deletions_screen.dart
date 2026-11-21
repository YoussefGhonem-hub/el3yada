import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/desktop_surfaces.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';
import '../../auth/domain/user_role.dart';
import '../application/account_deletion_providers.dart';
import '../domain/account_deletion_models.dart';
import 'account_deletion_text.dart';

/// AD12 Account deletions (spec 6.17): every scheduled, waiting-for-payment,
/// restored and completed deletion, for every role, newest first. Filters:
/// role and status. "Cancel and restore" (with a reason) on the ones in
/// progress. Admins start a deletion from AD5 and AD11
/// ([AdminAccountDeletionCard]).
class AccountDeletionsScreen extends ConsumerWidget {
  const AccountDeletionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(accountDeletionFilterProvider);
    final page = ref.watch(accountDeletionsProvider);
    final gutter = adminGutter(MediaQuery.sizeOf(context).width);
    void setFilter(AccountDeletionFilter value) => ref.read(accountDeletionFilterProvider.notifier).set(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 12),
          child: AdminHeader(
            title: l10n.navAccountDeletions,
            subtitle: page.hasValue ? l10n.adminDeletionsCount(page.value!.totalCount) : l10n.adminDeletionsSubtitle,
            actions: [
              IconButton(
                tooltip: l10n.retryButton,
                onPressed: () => ref.invalidate(accountDeletionsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
          child: DesktopPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ChipRow(
                  label: l10n.adminDeletionsRoleFilter,
                  children: [
                    for (final role in [null, ...UserRole.values])
                      ChoiceChip(
                        label: Text(role == null ? l10n.adminDeletionsAll : l10n.deletionRoleLabel(role)),
                        selected: filter.role == role,
                        onSelected: (_) => setFilter(filter.withRole(role)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _ChipRow(
                  label: l10n.adminDeletionsStatusFilter,
                  children: [
                    for (final status in [null, ...DeletionStatus.values])
                      ChoiceChip(
                        label: Text(status == null ? l10n.adminDeletionsAll : l10n.deletionStatusLabel(status)),
                        selected: filter.status == status,
                        onSelected: (_) => setFilter(filter.withStatus(status)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: page.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AdminErrorView(error: error, onRetry: () => ref.invalidate(accountDeletionsProvider)),
            data: (data) => data.items.isEmpty
                ? EmptyState(title: l10n.adminDeletionsEmpty)
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                    itemCount: data.items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: AccountDeletionCard(item: data.items[index]),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (final (i, chip) in children.indexed) ...[if (i > 0) const SizedBox(width: 6), chip]]),
          ),
        ),
      ],
    );
  }
}

/// One deletion: who (name, role, contact), the status, the dates, the
/// reason, who started or restored it, what a doctor still owes, and
/// "Cancel and restore" while it is in progress.
class AccountDeletionCard extends ConsumerStatefulWidget {
  const AccountDeletionCard({super.key, required this.item, this.compact = false});

  final AccountDeletionItem item;

  /// Inside AD5 / AD11: no name line (the screen already shows the account).
  final bool compact;

  @override
  ConsumerState<AccountDeletionCard> createState() => _AccountDeletionCardState();
}

class _AccountDeletionCardState extends ConsumerState<AccountDeletionCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDeletionReasonDialog(
      context,
      title: l10n.adminDeletionCancelTitle,
      body: l10n.adminDeletionCancelBody,
      confirm: l10n.adminDeletionCancel,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.cancelAccountDeletion(widget.item, reason);
      if (mounted) showAdminSnack(context, l10n.adminDeletionCancelled);
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final contact = [?item.phone == null ? null : AppFormat.phone(item.phone!), ?item.email].join(' · ');
    final lines = <String>[
      l10n.adminDeletionRequestedOn(AppFormat.date(context, item.requestedAt)),
      switch (item.status) {
        DeletionStatus.completed => l10n.adminDeletionCompletedOn(AppFormat.date(context, item.completedAt ?? item.scheduledFor)),
        DeletionStatus.restored => l10n.adminDeletionRestoredOn(
            AppFormat.date(context, item.restoredAt ?? item.requestedAt), item.restoredByName ?? ''),
        _ => l10n.adminDeletionScheduledFor(AppFormat.date(context, item.scheduledFor)),
      },
      if (item.requestedByAdmin) l10n.adminDeletionByAdmin(item.requestedByName ?? ''),
      if (item.reason case final reason? when reason.isNotEmpty) l10n.reasonValue(reason),
      if (item.restoreReason case final reason? when reason.isNotEmpty) l10n.adminDeletionRestoreReason(reason),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!widget.compact)
                        Text(l10n.personName(item.displayName), style: theme.textTheme.titleMedium),
                      Text(
                        [l10n.deletionRoleLabel(item.role), if (contact.isNotEmpty && !widget.compact) contact].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _StatusPill(status: item.status),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines) Text(line, style: theme.textTheme.bodyMedium),
            if (item.status == DeletionStatus.waitingPayment || item.outstandingPiasters > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.adminDeletionOwed(AppFormat.egp(context, item.outstandingPiasters), item.unpaidInvoices),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
              ),
            ],
            if (item.status.open) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _cancel,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.adminDeletionCancel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final DeletionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      DeletionStatus.scheduled => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      DeletionStatus.waitingPayment => (scheme.errorContainer, scheme.onErrorContainer),
      DeletionStatus.restored => (scheme.primaryContainer, scheme.onPrimaryContainer),
      DeletionStatus.completed => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(l10n.deletionStatusLabel(status), style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// A reason the admin must type (it goes in the audit log). Null when cancelled.
Future<String?> showDeletionReasonDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool danger = false,
}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(title: title, body: body, confirm: confirm, danger: danger),
    );

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.body, required this.confirm, required this.danger});

  final String title;
  final String body;
  final String confirm;
  final bool danger;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ready = _text.text.trim().isNotEmpty;
    return AlertDialog(
      icon: widget.danger ? Icon(Icons.delete_forever_outlined, color: scheme.error) : null,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.body),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.adminDeletionReasonLabel),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: widget.danger ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: ready ? () => Navigator.pop(context, _text.text.trim()) : null,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

/// AD5 (doctors) and AD11 (patients, assistants): the account's deletion in
/// progress with "Cancel and restore", or "Delete account" to start one for a
/// support case (with a reason; the same grace period applies).
class AdminAccountDeletionCard extends ConsumerStatefulWidget {
  const AdminAccountDeletionCard({super.key, required this.userId, required this.name});

  final String userId;
  final String name;

  @override
  ConsumerState<AdminAccountDeletionCard> createState() => _AdminAccountDeletionCardState();
}

class _AdminAccountDeletionCardState extends ConsumerState<AdminAccountDeletionCard> {
  bool _busy = false;

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDeletionReasonDialog(
      context,
      title: l10n.adminDeleteAccountTitle(l10n.personName(widget.name)),
      body: l10n.adminDeleteAccountBody,
      confirm: l10n.adminDeleteAccountConfirm,
      danger: true,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.scheduleAccountDeletion(widget.userId, reason);
      if (mounted) showAdminSnack(context, l10n.adminDeletionStarted);
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final latest = ref.watch(userAccountDeletionProvider(widget.userId));
    final item = latest.value;
    if (item != null && item.status.open) return AccountDeletionCard(item: item, compact: true);
    if (item?.status == DeletionStatus.completed) return const SizedBox.shrink();
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        key: Key('adminDeleteAccount-${widget.userId}'),
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error)),
        onPressed: _busy || latest.isLoading ? null : _start,
        icon: const Icon(Icons.delete_forever_outlined),
        label: Text(l10n.adminDeleteAccount),
      ),
    );
  }
}
