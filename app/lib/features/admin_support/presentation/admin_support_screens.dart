import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/validation/validators.dart';
import '../../account_deletion/application/account_deletion_providers.dart';
import '../../account_deletion/presentation/account_deletion_text.dart';
import '../../account_deletion/presentation/account_deletions_screen.dart';
import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../data/admin_support_repository.dart';
import '../domain/admin_support_models.dart';

// ---- AD11 Accounts support --------------------------------------------------------------------

/// AD11: search patient and assistant accounts by phone only; disable or enable login, and start or cancel an
/// account's deletion (spec 6.17; AD12 lists them all).
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
      ref.invalidate(userAccountDeletionProvider(userId));
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
                                title: l10n.personName(p.fullName),
                                role: l10n.rolePatient,
                                active: p.loginStatus == 'active',
                                lines: [
                                  if (p.patientStatus == 'deleted') l10n.errorAccountDeleted,
                                  if (p.deletion != null) l10n.adminAccountPendingDeletion(context.date(p.deletion!.scheduledFor)),
                                  l10n.linkedDoctors(p.doctors.map((d) => l10n.personName(d.fullName)).join('، ')),
                                  l10n.createdOn(context.date(p.createdAt)),
                                ],
                                canEnable: p.patientStatus != 'deleted',
                                locked: p.loginStatus == 'pendingDeletion' || p.loginStatus == 'deleted',
                                onToggle: (active) => _toggle(p.userId, active: active),
                                footer: p.patientStatus == 'deleted'
                                    ? null
                                    : AdminAccountDeletionCard(userId: p.userId, name: p.fullName),
                              ),
                            for (final a in data.assistants)
                              _AccountCard(
                                title: l10n.personName(a.fullName),
                                role: l10n.roleAssistant,
                                active: a.loginStatus == 'active',
                                lines: [
                                  l10n.assistantOf(l10n.personName(a.doctorName)),
                                  if (a.deletion != null) l10n.adminAccountPendingDeletion(context.date(a.deletion!.scheduledFor)),
                                  if (a.lastActiveAt != null) l10n.lastActive(context.dateTime(a.lastActiveAt!)),
                                ],
                                canEnable: a.assistantStatus != 'removed',
                                locked: a.loginStatus == 'pendingDeletion' || a.loginStatus == 'deleted',
                                onToggle: (active) => _toggle(a.userId, active: active),
                                footer: a.loginStatus == 'deleted'
                                    ? null
                                    : AdminAccountDeletionCard(userId: a.userId, name: a.fullName),
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
    this.footer,
    this.locked = false,
  });

  final String title;
  final String role;
  final bool active;
  final List<String> lines;
  final bool canEnable;
  final ValueChanged<bool> onToggle;

  /// Under the row: the account's deletion, or "Delete account".
  final Widget? footer;

  /// Being deleted or erased: "Cancel and restore" (spec 6.17) turns it back
  /// on, not the switch.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                  onChanged: !locked && (active || canEnable) ? onToggle : null,
                ),
              ],
            ),
            if (footer != null) ...[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}
