import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/preference_pickers.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../account_deletion/presentation/delete_account_flow.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/presentation/change_password_form.dart';
import '../../admin_routes.dart';
import '../../application/admin_controllers.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';

/// AD18: the signed-in admin's name and email (the name can change),
/// language and appearance (saved on the device and the account), change
/// password, and log out.
class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(adminProfileProvider);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final gutter = adminGutter(width);
          final twoColumns = width >= kAdminWideLayout;
          return AsyncStateSwitcher<AdminProfile>(
            value: profile,
            loading: (context) => const _ProfileSkeleton(),
            error: (context, error) => Column(
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(padding: EdgeInsets.all(8), child: AdminBackButton(fallback: AdminRoutes.settings)),
                ),
                Expanded(
                  child: AdminErrorView(error: error, onRetry: () => ref.read(adminProfileProvider.notifier).reload()),
                ),
              ],
            ),
            data: (context, profile) {
              var index = 0;
              Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
              const gap = SizedBox(height: 16);
              final identity = _IdentityCard(admin: profile.admin);
              const preferences = _PreferencesCard();
              const password = _PasswordCard();
              const logout = _LogoutCard();
              const deletion = _DeleteAccountCard();
              return StaggerGroup(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          enter(AdminHeader(
                            leading: const AdminBackButton(fallback: AdminRoutes.settings),
                            title: l10n.adminMyProfile,
                            subtitle: l10n.adminProfileSubtitle,
                          )),
                          gap,
                          if (twoColumns)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [enter(identity), gap, enter(preferences), gap, enter(logout)],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: Column(children: [enter(password), gap, enter(deletion)])),
                              ],
                            )
                          else ...[
                            enter(identity),
                            gap,
                            enter(preferences),
                            gap,
                            enter(password),
                            gap,
                            enter(logout),
                            gap,
                            enter(deletion),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.admin});

  final AdminUser admin;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  static final _fullName = RegExp(r'^[\p{L}\p{M}]+( [\p{L}\p{M}]+)+$', unicode: true);

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.admin.displayName);
  bool _editing = false;
  SubmitStatus _status = SubmitStatus.idle;
  String? _serverError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _status = SubmitStatus.loading);
    try {
      await ref.read(adminProfileProvider.notifier).rename(_name.text.trim().replaceAll(RegExp(r'\s+'), ' '));
      // The menu shows the session's name: fetch the account again.
      ref.read(authControllerProvider.notifier).reloadAccount().ignore();
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _editing = false;
      });
      showAdminSnack(context, l10n.adminNameSaved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _serverError = l10n.fieldError(error.fieldCodes['displayName']) ?? l10n.apiError(error);
      });
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final admin = widget.admin;
    final busy = _status != SubmitStatus.idle;
    return SectionCard(
      icon: Icons.person_outline,
      title: l10n.adminProfileAccount,
      trailing: _editing
          ? null
          : TextButton.icon(
              onPressed: () => setState(() {
                _name.text = admin.displayName;
                _editing = true;
              }),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l10n.adminEditName),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialAvatar(name: admin.displayName, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.displayName, style: theme.textTheme.titleLarge),
                    if (admin.email != null)
                      LtrText(admin.email!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    StatusPill(
                      label: adminRoleLabel(l10n, admin.adminRole),
                      tone: admin.isSuperAdmin ? PillTone.positive : PillTone.neutral,
                      icon: admin.isSuperAdmin ? Icons.verified_user_outlined : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          AdminAnimatedSize(
            child: !_editing
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: InfoRow(label: l10n.adminMemberSince, value: AppFormat.date(context, admin.createdAt)),
                  )
                : Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _name,
                            enabled: !busy,
                            autofocus: true,
                            decoration: InputDecoration(labelText: l10n.adminFieldFullName),
                            onFieldSubmitted: (_) => _save(),
                            validator: (value) {
                              if (_serverError != null) return _serverError;
                              final name = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
                              if (name.isEmpty) return l10n.errorRequired;
                              if (name.length > 60 || !_fullName.hasMatch(name)) return l10n.adminErrorInvalidName;
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: busy ? null : () => setState(() => _editing = false),
                                child: Text(l10n.adminCancel),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(width: 140, child: SubmitButton(label: l10n.adminSave, status: _status, onPressed: _save)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SectionCard(
      icon: Icons.tune,
      title: l10n.adminPreferences,
      subtitle: l10n.adminPreferencesBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.adminLanguage, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          const LanguagePicker(),
          const SizedBox(height: 20),
          Text(l10n.appearance, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          const AppearancePicker(),
        ],
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  const _PasswordCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      icon: Icons.lock_outline,
      title: l10n.adminChangePassword,
      subtitle: l10n.adminChangePasswordBody,
      child: const ChangePasswordForm(),
    );
  }
}

class _LogoutCard extends ConsumerWidget {
  const _LogoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.logout,
      title: l10n.logout,
      subtitle: l10n.adminLogoutBody,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error, width: 2)),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.logout),
        ),
      ),
    );
  }
}

/// AD18 «حذف الحساب» (spec 6.17). The last active super admin is refused, as
/// in AD14.
class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      icon: Icons.delete_forever_outlined,
      title: l10n.accountDeletionTile,
      subtitle: l10n.accountDeletionTileBody,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: const Key('deleteAccountTile'),
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error, width: 2)),
          onPressed: () => showDeleteAccountFlow(context),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l10n.accountDeletionTile),
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Text('-------------'),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(children: [
                  CircleAvatar(radius: 32),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('------------------', maxLines: 1, overflow: TextOverflow.clip),
                      SizedBox(height: 8),
                      Text('----------------------', maxLines: 1, overflow: TextOverflow.clip),
                    ]),
                  ),
                ]),
              ),
            ),
          ],
        ),
      );
}
