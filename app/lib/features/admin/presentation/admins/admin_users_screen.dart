import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../core/widgets/success_check.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/admin_controllers.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';

/// AD14 (super admins only): every admin with role and status. Add an admin
/// (the temporary password is shown once), change a role, disable or
/// enable. You can't change your own role or disable yourself, and there is
/// always one active super admin left.
class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).value;
    if (session == null || !session.isSuperAdmin) {
      return _Restricted(message: l10n.adminAdminsRestricted);
    }
    final admins = ref.watch(adminUsersProvider);
    final me = session.userId;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kAdminWideLayout;
        final gutter = adminGutter(constraints.maxWidth);
        final list = admins.value;
        final superAdmins = list?.where((a) => a.isSuperAdmin && a.isActive).length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 16),
              child: AdminHeader(
                title: l10n.navAdmins,
                subtitle: list == null ? l10n.loading : l10n.adminAdminsCount(list.length, superAdmins),
                actions: [
                  FilledButton.icon(
                    onPressed: () => showCreateAdminDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(l10n.adminAddAdmin),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncStateSwitcher<List<AdminUser>>(
                value: admins,
                loading: (context) => _AdminsSkeleton(gutter: gutter),
                error: (context, error) => AdminErrorView(
                  error: error,
                  onRetry: () => ref.read(adminUsersProvider.notifier).reload(),
                ),
                data: (context, admins) => wide
                    ? _AdminsTable(admins: admins, me: me, gutter: gutter)
                    : _AdminsCards(admins: admins, me: me, gutter: gutter),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Restricted extends StatelessWidget {
  const _Restricted({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: StaggerGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StaggeredEntrance(
                  index: 0,
                  child: ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Icon(Icons.lock_outline, size: 36, color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                StaggeredEntrance(
                  index: 1,
                  child: Text(message, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The row actions: change role, disable or enable, each after a confirm.
Future<void> _changeRole(BuildContext context, WidgetRef ref, AdminUser admin) async {
  final l10n = AppLocalizations.of(context);
  final promote = !admin.isSuperAdmin;
  final confirmed = await confirmAction(
    context,
    title: promote ? l10n.adminMakeSuperTitle(admin.displayName) : l10n.adminMakeAdminTitle(admin.displayName),
    message: promote ? l10n.adminMakeSuperBody : l10n.adminMakeAdminBody,
    confirmLabel: promote ? l10n.adminMakeSuper : l10n.adminMakeAdmin,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(adminUsersProvider.notifier).setRole(admin, promote ? AdminRole.superAdmin : AdminRole.admin);
    if (context.mounted) showAdminSnack(context, l10n.adminRoleChanged(admin.displayName));
  } on ApiException catch (error) {
    if (context.mounted) _showActionError(context, error);
  }
}

Future<void> _changeStatus(BuildContext context, WidgetRef ref, AdminUser admin) async {
  final l10n = AppLocalizations.of(context);
  final disable = admin.isActive;
  final confirmed = await confirmAction(
    context,
    title: disable ? l10n.adminDisableTitle(admin.displayName) : l10n.adminEnableTitle(admin.displayName),
    message: disable ? l10n.adminDisableBody : l10n.adminEnableBody,
    confirmLabel: disable ? l10n.adminDisable : l10n.adminEnable,
    destructive: disable,
  );
  if (!confirmed || !context.mounted) return;
  try {
    await ref.read(adminUsersProvider.notifier).setActive(admin, active: !disable);
    if (context.mounted) {
      showAdminSnack(context, disable ? l10n.adminDisabledMessage(admin.displayName) : l10n.adminEnabledMessage(admin.displayName));
    }
  } on ApiException catch (error) {
    if (context.mounted) _showActionError(context, error);
  }
}

/// The AD14 guards get a dialog that says why; other errors a snack bar.
void _showActionError(BuildContext context, ApiException error) {
  final l10n = AppLocalizations.of(context);
  const guards = {'CANNOT_CHANGE_OWN_ROLE', 'CANNOT_DISABLE_SELF', 'LAST_SUPER_ADMIN'};
  if (!guards.contains(error.code)) {
    showAdminSnack(context, l10n.apiError(error), error: true);
    return;
  }
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.shield_outlined),
      title: Text(l10n.adminNotAllowedTitle),
      content: Text(l10n.apiError(error)),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.ok))],
    ),
  );
}

class _ActionsMenu extends ConsumerWidget {
  const _ActionsMenu({required this.admin, required this.isMe});

  final AdminUser admin;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (isMe) {
      // Your own role and status can't change here (the API refuses too).
      return IconButton(tooltip: l10n.adminThatsYou, onPressed: null, icon: const Icon(Icons.more_vert));
    }
    return PopupMenuButton<String>(
      tooltip: l10n.adminActionsFor(admin.displayName),
      onSelected: (action) => action == 'role' ? _changeRole(context, ref, admin) : _changeStatus(context, ref, admin),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'role',
          child: ListTile(
            leading: Icon(admin.isSuperAdmin ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined),
            title: Text(admin.isSuperAdmin ? l10n.adminMakeAdmin : l10n.adminMakeSuper),
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: ListTile(
            leading: Icon(admin.isActive ? Icons.block : Icons.check_circle_outline),
            title: Text(admin.isActive ? l10n.adminDisable : l10n.adminEnable),
          ),
        ),
      ],
    );
  }
}

List<Widget> _pills(AppLocalizations l10n, AdminUser admin) => [
      StatusPill(
        label: adminRoleLabel(l10n, admin.adminRole),
        tone: admin.isSuperAdmin ? PillTone.positive : PillTone.neutral,
        icon: admin.isSuperAdmin ? Icons.verified_user_outlined : null,
      ),
      StatusPill(
        label: admin.isActive ? l10n.adminStatusActive : l10n.adminStatusDisabled,
        tone: admin.isActive ? PillTone.positive : PillTone.danger,
      ),
      if (admin.mustChangePassword) StatusPill(label: l10n.adminPasswordNotSet, tone: PillTone.warning),
    ];

String _lastSeen(BuildContext context, AdminUser admin) {
  final l10n = AppLocalizations.of(context);
  final last = admin.lastLoginAt;
  return last == null ? l10n.adminNeverSignedIn : AppFormat.relative(context, last);
}

class _AdminsCards extends StatelessWidget {
  const _AdminsCards({required this.admins, required this.me, required this.gutter});

  final List<AdminUser> admins;
  final String me;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return StaggerGroup(
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16 + MediaQuery.paddingOf(context).bottom),
        itemCount: admins.length,
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final admin = admins[i];
          final isMe = admin.userId == me;
          return StaggeredEntrance(
            index: i,
            child: Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 4, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InitialAvatar(name: admin.displayName, muted: !admin.isActive),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMe ? l10n.adminYouSuffix(admin.displayName) : admin.displayName,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (admin.email != null)
                            LtrText(
                              admin.email!,
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: _pills(l10n, admin)),
                          const SizedBox(height: 8),
                          Text(
                            l10n.adminLastSignIn(_lastSeen(context, admin)),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    _ActionsMenu(admin: admin, isMe: isMe),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminsTable extends StatelessWidget {
  const _AdminsTable({required this.admins, required this.me, required this.gutter});

  final List<AdminUser> admins;
  final String me;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final header = theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
    Widget cell(String text) => Semantics(header: true, child: Text(text, style: header));
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: StaggerGroup(
          child: Column(
            children: [
              Container(
                color: scheme.surfaceContainer,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: cell(l10n.adminColumnName)),
                    Expanded(flex: 3, child: cell(l10n.adminColumnRole)),
                    Expanded(flex: 2, child: cell(l10n.adminColumnStatus)),
                    Expanded(flex: 2, child: cell(l10n.adminColumnLastSignIn)),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              for (final (i, admin) in admins.indexed) ...[
                if (i > 0) const Divider(height: 1),
                StaggeredEntrance(index: i, child: _AdminRow(admin: admin, isMe: admin.userId == me)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  const _AdminRow({required this.admin, required this.isMe});

  final AdminUser admin;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                InitialAvatar(name: admin.displayName, size: 40, muted: !admin.isActive),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMe ? l10n.adminYouSuffix(admin.displayName) : admin.displayName,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (admin.email != null)
                        LtrText(
                          admin.email!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: StatusPill(
                label: adminRoleLabel(l10n, admin.adminRole),
                tone: admin.isSuperAdmin ? PillTone.positive : PillTone.neutral,
                icon: admin.isSuperAdmin ? Icons.verified_user_outlined : null,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusPill(
                  label: admin.isActive ? l10n.adminStatusActive : l10n.adminStatusDisabled,
                  tone: admin.isActive ? PillTone.positive : PillTone.danger,
                ),
                if (admin.mustChangePassword) StatusPill(label: l10n.adminPasswordNotSet, tone: PillTone.warning),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(_lastSeen(context, admin), style: theme.textTheme.bodyMedium),
          ),
          _ActionsMenu(admin: admin, isMe: isMe),
        ],
      ),
    );
  }
}

class _AdminsSkeleton extends StatelessWidget {
  const _AdminsSkeleton({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          itemCount: 4,
          separatorBuilder: (context, _) => const SizedBox(height: 12),
          itemBuilder: (context, _) => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(radius: 22),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('----------------'), SizedBox(height: 6), Text('------------------------')],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Add admin: name, email, role. On success the dialog shows the 12-character
/// temporary password once, with Copy, and closes only with Done.
Future<void> showCreateAdminDialog(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CreateAdminDialog(),
    );

class _CreateAdminDialog extends ConsumerStatefulWidget {
  const _CreateAdminDialog();

  @override
  ConsumerState<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends ConsumerState<_CreateAdminDialog> {
  static final _fullName = RegExp(r'^[\p{L}\p{M}]+( [\p{L}\p{M}]+)+$', unicode: true);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  AdminRole _role = AdminRole.admin;
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _fieldErrors = const {};
  String? _error;
  CreatedAdmin? _created;
  bool _copied = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _fieldErrors = const {};
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _status = SubmitStatus.loading);
    try {
      final created = await ref.read(adminUsersProvider.notifier).create(
            email: _email.text.trim(),
            displayName: _name.text.trim().replaceAll(RegExp(r'\s+'), ' '),
            role: _role,
          );
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.success;
        _created = created;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _fieldErrors = {
          ...error.fieldCodes,
          if (error.code == 'EMAIL_ALREADY_REGISTERED') 'email': 'EMAIL_ALREADY_REGISTERED',
        };
        _error = _fieldErrors.isEmpty ? l10n.apiError(error) : null;
      });
      _formKey.currentState?.validate();
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _created!.temporaryPassword));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return PopScope(
      // Once the password shows, only Done closes the dialog.
      canPop: created == null && _status == SubmitStatus.idle,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AdminAnimatedSize(
              child: AnimatedSwitcher(
                duration: Motion.normal,
                reverseDuration: Motion.normalExit,
                switchInCurve: Motion.enterCurve,
                switchOutCurve: Motion.exitCurveReversed,
                child: created == null ? _form(context) : _password(context, created),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _status != SubmitStatus.idle;
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(l10n.adminAddAdmin, style: theme.textTheme.headlineSmall)),
          const SizedBox(height: 8),
          Text(l10n.adminAddAdminBody, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            enabled: !busy,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.adminFieldFullName, prefixIcon: const Icon(Icons.person_outline)),
            validator: (value) {
              final server = l10n.fieldError(_fieldErrors['displayName']);
              if (server != null) return server;
              final name = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
              if (name.isEmpty) return l10n.errorRequired;
              if (name.length > 60 || !_fullName.hasMatch(name)) return l10n.adminErrorInvalidName;
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: l10n.adminFieldEmail, prefixIcon: const Icon(Icons.alternate_email)),
            validator: (value) {
              final server = l10n.fieldError(_fieldErrors['email']);
              if (server != null) return server;
              final email = (value ?? '').trim();
              if (email.isEmpty) return l10n.errorRequired;
              if (!Validators.isEmail(email)) return l10n.errorInvalidEmail;
              return null;
            },
          ),
          const SizedBox(height: 20),
          Text(l10n.adminColumnRole, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<AdminRole>(
            segments: [
              ButtonSegment(value: AdminRole.admin, label: Text(l10n.adminRoleAdmin), icon: const Icon(Icons.person_outline)),
              ButtonSegment(
                value: AdminRole.superAdmin,
                label: Text(l10n.adminRoleSuperAdmin),
                icon: const Icon(Icons.verified_user_outlined),
              ),
            ],
            selected: {_role},
            onSelectionChanged: busy ? null : (selection) => setState(() => _role = selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            _role == AdminRole.superAdmin ? l10n.adminRoleSuperAdminBody : l10n.adminRoleAdminBody,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: scheme.error))),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(), child: Text(l10n.adminCancel)),
              const SizedBox(width: 8),
              SizedBox(width: 170, child: SubmitButton(label: l10n.adminAddAdmin, status: _status, onPressed: _submit)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _password(BuildContext context, CreatedAdmin created) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      key: const ValueKey('password'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: SuccessCheck(size: 72)),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            l10n.adminCreatedTitle(created.admin.displayName),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: scheme.onTertiaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.adminPasswordOnceWarning, style: TextStyle(color: scheme.onTertiaryContainer)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.adminTemporaryPassword, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary, width: 2),
          ),
          // One line, scaled down on narrow phones rather than broken in two.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SelectableText(
              created.temporaryPassword,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _copy,
          icon: AnimatedSwitcher(
            duration: Motion.fast,
            child: Icon(_copied ? Icons.check : Icons.copy, key: ValueKey(_copied)),
          ),
          label: Text(_copied ? l10n.adminCopied : l10n.adminCopyPassword),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.adminPasswordNextStep(created.admin.email ?? ''),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.done)),
      ],
    );
  }
}
