import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../patient/domain/patient_models.dart' show Paged;
import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../data/admin_support_repository.dart';
import '../domain/admin_support_models.dart';

// ---- AD12 Account deletion requests -----------------------------------------------------------

final deletionStatusFilterProvider =
    NotifierProvider<_StatusFilter, String>(_StatusFilter.new);

class _StatusFilter extends Notifier<String> {
  @override
  String build() => 'pending';

  void set(String value) => state = value;
}

final deletionRequestsProvider = FutureProvider.autoDispose<Paged<AdminDeletionRequest>>((ref) {
  final status = ref.watch(deletionStatusFilterProvider);
  return ref.watch(adminSupportRepositoryProvider).deletionRequests(status: status);
});

/// AD12: patient requests (oldest first while pending). Approve disables login; reject needs a reason.
class DeletionRequestsScreen extends ConsumerWidget {
  const DeletionRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(deletionStatusFilterProvider);
    final requests = ref.watch(deletionRequestsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'pending', label: Text(l10n.statusPending)),
              ButtonSegment(value: 'approved', label: Text(l10n.statusApproved)),
              ButtonSegment(value: 'rejected', label: Text(l10n.statusRejected)),
            ],
            selected: {status},
            onSelectionChanged: (v) => ref.read(deletionStatusFilterProvider.notifier).set(v.single),
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: requests,
            onRetry: () => ref.invalidate(deletionRequestsProvider),
            data: (page) => page.items.isEmpty
                ? EmptyState(icon: Icons.inbox_outlined, message: l10n.noDeletionRequests)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: page.items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => ContentWidth(maxWidth: 900, child: _DeletionCard(request: page.items[index])),
                  ),
          ),
        ),
      ],
    );
  }
}

class _DeletionCard extends ConsumerStatefulWidget {
  const _DeletionCard({required this.request});

  final AdminDeletionRequest request;

  @override
  ConsumerState<_DeletionCard> createState() => _DeletionCardState();
}

class _DeletionCardState extends ConsumerState<_DeletionCard> {
  bool _busy = false;

  Future<void> _review({required bool approve}) async {
    final l10n = context.l10n;
    final note = await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(
        title: approve ? l10n.approveDeletionTitle : l10n.rejectDeletionTitle,
        body: approve ? l10n.approveDeletionBody : null,
        reasonRequired: !approve,
        confirm: approve ? l10n.approve : l10n.reject,
      ),
    );
    if (note == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(adminSupportRepositoryProvider)
          .reviewDeletionRequest(widget.request.id, approve: approve, note: note.isEmpty ? null : note);
      ref.invalidate(deletionRequestsProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final r = widget.request;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.patientName, style: theme.textTheme.titleMedium),
            Text('${context.localPhone(r.patientPhone)} · ${context.dateTime(r.createdAt)}'),
            if (r.reason != null) ...[const SizedBox(height: 8), Text(l10n.reasonValue(r.reason!))],
            if (!r.isPending && r.reviewedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                [context.dateTime(r.reviewedAt!), ?r.reviewedByName, ?r.reviewNote].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (r.isPending) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton(onPressed: _busy ? null : () => _review(approve: true), child: Text(l10n.approve)),
                  OutlinedButton(onPressed: _busy ? null : () => _review(approve: false), child: Text(l10n.reject)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Returns the (possibly empty) reason, or null when cancelled.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, this.body, required this.reasonRequired, required this.confirm});

  final String title;
  final String? body;
  final bool reasonRequired;
  final String confirm;

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
    final l10n = context.l10n;
    final canConfirm = !widget.reasonRequired || _text.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.body != null) ...[Text(widget.body!), const SizedBox(height: 16)],
          TextField(
            controller: _text,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: widget.reasonRequired ? l10n.reasonRequiredLabel : l10n.deletionReasonLabel),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: canConfirm ? () => Navigator.pop(context, _text.text.trim()) : null, child: Text(widget.confirm)),
      ],
    );
  }
}

// ---- AD11 Accounts support --------------------------------------------------------------------

/// AD11: search patient and assistant accounts by phone only; disable or enable login.
class AccountsSupportScreen extends ConsumerStatefulWidget {
  const AccountsSupportScreen({super.key});

  @override
  ConsumerState<AccountsSupportScreen> createState() => _AccountsSupportScreenState();
}

class _AccountsSupportScreenState extends ConsumerState<AccountsSupportScreen> {
  final _phone = TextEditingController();
  String? _error;
  AsyncValue<AccountSearchResult>? _result;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final phone = Validators.normalizeEgyptianMobile(_phone.text);
    if (phone == null) {
      setState(() => _error = context.l10n.errorInvalidPhone);
      return;
    }
    setState(() {
      _error = null;
      _result = const AsyncLoading();
    });
    final result = await AsyncValue.guard(() => ref.read(adminSupportRepositoryProvider).searchAccounts(phone));
    if (mounted) setState(() => _result = result);
  }

  Future<void> _toggle(String userId, {required bool active}) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(adminSupportRepositoryProvider).setLoginStatus(userId, active: active);
      await _search();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContentWidth(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  labelText: l10n.mobileNumber,
                  hintText: '01XXXXXXXXX',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(tooltip: l10n.search, icon: const Icon(Icons.arrow_forward), onPressed: _search),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.accountsSupportHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              if (result != null)
                AsyncValueView(
                  value: result,
                  onRetry: _search,
                  data: (data) => data.isEmpty
                      ? EmptyState(icon: Icons.person_search_outlined, message: l10n.noAccountsFound)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final p in data.patients)
                              _AccountCard(
                                title: p.fullName,
                                role: l10n.rolePatient,
                                active: p.loginStatus == 'active',
                                lines: [
                                  if (p.patientStatus == 'deleted') l10n.accountDeleted,
                                  l10n.linkedDoctors(p.doctors.map((d) => d.fullName).join('، ')),
                                  l10n.createdOn(context.date(p.createdAt)),
                                ],
                                canEnable: p.patientStatus != 'deleted',
                                onToggle: (active) => _toggle(p.userId, active: active),
                              ),
                            for (final a in data.assistants)
                              _AccountCard(
                                title: a.fullName,
                                role: l10n.roleAssistant,
                                active: a.loginStatus == 'active',
                                lines: [
                                  l10n.assistantOf(a.doctorName),
                                  if (a.lastActiveAt != null) l10n.lastActive(context.dateTime(a.lastActiveAt!)),
                                ],
                                canEnable: a.assistantStatus != 'removed',
                                onToggle: (active) => _toggle(a.userId, active: active),
                              ),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.title,
    required this.role,
    required this.active,
    required this.lines,
    required this.canEnable,
    required this.onToggle,
  });

  final String title;
  final String role;
  final bool active;
  final List<String> lines;
  final bool canEnable;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title · $role', style: theme.textTheme.titleMedium),
                  for (final line in lines) Text(line),
                  Text(active ? l10n.loginEnabled : l10n.loginDisabled,
                      style: TextStyle(color: active ? theme.colorScheme.primary : theme.colorScheme.error)),
                ],
              ),
            ),
            Switch(
              value: active,
              onChanged: active || canEnable ? onToggle : null,
            ),
          ],
        ),
      ),
    );
  }
}
