import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../patients/clinic_paths.dart';
import '../application/account_deletion_providers.dart';
import '../domain/account_deletion_models.dart';
import 'account_deletion_text.dart';

/// «حذف الحساب» for every role (P14, D24, AS12, AD18; spec 6.17): what will
/// happen for this role, a doctor's unpaid invoices (refused) or final
/// invoice (shown first), an optional reason and the current password. On
/// phones a sheet, on wider windows a dialog. After the deletion starts, the
/// date is shown and the session ends on this device too.
Future<void> showDeleteAccountFlow(BuildContext context) async {
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
  final started = wide
      ? await showDialog<AccountDeletionStarted>(
          context: context,
          useRootNavigator: true,
          builder: (context) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
              child: const DeleteAccountPanel(),
            ),
          ),
        )
      : await showModalBottomSheet<AccountDeletionStarted>(
          context: context,
          useRootNavigator: true,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (context) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: const DeleteAccountPanel(),
          ),
        );
  if (started == null || !context.mounted) return;
  await showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => _DeletionStartedDialog(started: started),
  );
}

/// The body of the flow: loads `getAccountDeletion`, then explains, refuses or
/// asks for the password. Pops with the [AccountDeletionStarted] once it began.
class DeleteAccountPanel extends ConsumerStatefulWidget {
  const DeleteAccountPanel({super.key});

  @override
  ConsumerState<DeleteAccountPanel> createState() => _DeleteAccountPanelState();
}

class _DeleteAccountPanelState extends ConsumerState<DeleteAccountPanel> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _reason = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _passwordError;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _passwordError = null;
      _error = null;
    });
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final reason = _reason.text.trim();
      final started = await ref.requestAccountDeletion(
        currentPassword: _password.text,
        reason: reason.isEmpty ? null : reason,
      );
      if (mounted) Navigator.of(context).pop(started);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _passwordError = l10n.fieldError(error.fieldCodes['currentPassword']);
        _error = _passwordError == null ? l10n.apiError(error) : null;
      });
      // The refusal may have changed meanwhile (an invoice became overdue): show it.
      if (error.code == ApiCodes.unpaidInvoices || error.code == ApiCodes.lastSuperAdmin) {
        ref.invalidate(accountDeletionStateProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(accountDeletionStateProvider);
    return state.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.apiError(error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: () => ref.invalidate(accountDeletionStateProvider), child: Text(l10n.retryButton)),
          ],
        ),
      ),
      data: (data) => _body(context, data),
    );
  }

  Widget _body(BuildContext context, AccountDeletionState data) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final refusal = data.refusal;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: scheme.errorContainer, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.delete_forever_outlined, color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.accountDeletionSheetTitle, style: theme.textTheme.titleLarge),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // A doctor's final invoice comes first (BR-DEL8).
            if (refusal == null && data.finalInvoice != null) ...[
              _Notice(
                icon: Icons.receipt_long_outlined,
                text: l10n.accountDeletionFinalInvoice(AppFormat.egp(context, data.finalInvoice!.amountPiasters)),
              ),
              const SizedBox(height: 16),
            ],
            Text(l10n.accountDeletionWhatHappens, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final line in [
              l10n.accountDeletionStepGrace(data.graceDays, AppFormat.date(context, data.scheduledForIfNow)),
              ...l10n.deletionEffects(data.role),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 6, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (refusal != null)
              _Refusal(state: data)
            else ...[
              TextField(
                controller: _reason,
                maxLength: 500,
                maxLines: 2,
                decoration: InputDecoration(labelText: l10n.deletionReasonLabel),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _busy ? null : _submit(),
                validator: (value) => value == null || value.isEmpty ? l10n.errorRequired : null,
                decoration: InputDecoration(
                  labelText: l10n.adminCurrentPassword,
                  helperText: l10n.accountDeletionPasswordHelper,
                  errorText: _passwordError,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('confirmAccountDeletion'),
                style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.onError))
                    : const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.accountDeletionConfirm),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the deletion can't start: a doctor's unpaid invoices (with D18), the
/// last super admin, or a deletion already in progress.
class _Refusal extends StatelessWidget {
  const _Refusal({required this.state});

  final AccountDeletionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return switch (state.refusal!) {
      DeletionRefusal.unpaidInvoices => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Notice(icon: Icons.receipt_long_outlined, text: l10n.accountDeletionUnpaidTitle, body: l10n.accountDeletionUnpaidBody),
            const SizedBox(height: 8),
            for (final invoice in state.unpaidInvoices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(_month(context, invoice.month)),
                trailing: LtrText(AppFormat.egp(context, invoice.totalDuePiasters), style: theme.textTheme.titleSmall),
              ),
            const SizedBox(height: 8),
            if (state.role == UserRole.doctor)
              FilledButton.tonalIcon(
                onPressed: () {
                  // Read first: the sheet's context is gone once it closes.
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.go(ClinicPaths.doctor.billing);
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(l10n.accountDeletionOpenInvoices),
              ),
          ],
        ),
      DeletionRefusal.lastSuperAdmin => _Notice(icon: Icons.admin_panel_settings_outlined, text: l10n.adminErrorLastSuperAdmin),
      DeletionRefusal.alreadyScheduled => _Notice(icon: Icons.hourglass_top_outlined, text: l10n.errorAccountDeletionScheduled),
    };
  }

  static String _month(BuildContext context, DateTime month) =>
      MaterialLocalizations.of(context).formatMonthYear(month);
}

/// A tinted box in the error colours: the final invoice, a refusal.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.body});

  final IconData icon;
  final String text;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onErrorContainer, fontWeight: FontWeight.w600)),
                    if (body != null) ...[
                      const SizedBox(height: 4),
                      Text(body!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer)),
                    ],
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

/// «حسابك اتقفل»: the erasure date and how to come back, then the session ends.
class _DeletionStartedDialog extends ConsumerWidget {
  const _DeletionStartedDialog({required this.started});

  final AccountDeletionStarted started;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.hourglass_top_outlined, color: scheme.error),
      title: Text(l10n.accountDeletionDoneTitle),
      content: Text(l10n.accountDeletionDoneBody(AppFormat.date(context, started.scheduledFor))),
      actions: [
        FilledButton(
          onPressed: () {
            // Read first: the dialog's ref is gone once it closes.
            final auth = ref.read(authControllerProvider.notifier);
            Navigator.of(context).pop();
            auth.logout();
          },
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
