import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/support_contact.dart';
import '../../account_deletion/presentation/delete_account_flow.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/change_password_form.dart';
import '../application/patient_providers.dart';
import '../data/patient_repository.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'widgets/patient_widgets.dart';

/// P14 Account and settings: name and phone (read-only), language, appearance, notification
/// toggles and the "show message text" switch, change password, «حذف الحساب» (spec 6.17,
/// required by the App Store and Google Play), Logout, then Terms and Privacy (A12) and the
/// support contact from the public settings.
class PatientAccountScreen extends ConsumerWidget {
  const PatientAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(patientAccountProvider);
    return AsyncValueView(
      value: account,
      onRetry: () => ref.invalidate(patientAccountProvider),
      data: (data) => _AccountBody(account: data),
    );
  }
}

class _AccountBody extends ConsumerWidget {
  const _AccountBody({required this.account});

  final PatientAccount account;

  Future<void> _savePrefs(BuildContext context, WidgetRef ref, NotificationPrefs prefs) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(patientAccountProvider.notifier).setNotificationPrefs(prefs);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiErrorMessage(error))));
    }
  }

  /// The device keeps the choice at once; the account copy (used for pushes) is best effort.
  void _syncAppearance(WidgetRef ref, {String? locale, String? themeMode}) {
    ref.read(patientRepositoryProvider).updateAppearance(locale: locale, themeMode: themeMode).ignore();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final settingsController = ref.read(appSettingsProvider.notifier);
    final prefs = account.notifications;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(account.personal.fullName, style: theme.textTheme.titleMedium),
                subtitle: Text(context.localPhone(account.personal.phone), textDirection: TextDirection.ltr,
                    textAlign: context.isArabic ? TextAlign.right : TextAlign.left),
              ),
              const Divider(),
              _Header(l10n.settingsGeneral),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                trailing: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ar', label: Text('العربية')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {settings.locale.languageCode},
                  onSelectionChanged: (value) {
                    settingsController.setLocale(Locale(value.single));
                    _syncAppearance(ref, locale: value.single);
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(l10n.appearance),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(l10n.themeSystem)),
                      ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
                      ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (value) {
                      settingsController.setThemeMode(value.single);
                      _syncAppearance(ref, themeMode: value.single.name);
                    },
                  ),
                ),
              ),
              const Divider(),
              _Header(l10n.notificationsTitle),
              SwitchListTile(
                secondary: const Icon(Icons.chat_bubble_outline),
                title: Text(l10n.notifyChat),
                value: prefs.chat,
                onChanged: (value) => _savePrefs(context, ref, prefs.copyWith(chat: value)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.alarm_outlined),
                title: Text(l10n.notifyReminders),
                value: prefs.reminders,
                onChanged: (value) => _savePrefs(context, ref, prefs.copyWith(reminders: value)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.visibility_outlined),
                title: Text(l10n.notifyShowPreview),
                subtitle: Text(l10n.notifyShowPreviewHint),
                value: prefs.showPreview,
                onChanged: (value) => _savePrefs(context, ref, prefs.copyWith(showPreview: value)),
              ),
              const Divider(),
              _Header(l10n.accountTitle),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: Text(l10n.adminChangePassword),
                subtitle: Text(l10n.adminChangePasswordBody),
                onTap: () => _showChangePassword(context),
              ),
              const _DeletionTile(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(l10n.logout),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              const Divider(),
              _Header(l10n.settingsAbout),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.termsTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.terms),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.privacyTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.privacy),
              ),
              // The admin's WhatsApp, phone and email (AD13); nothing when none is set.
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SupportContact(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Change password (A9's rules) in a sheet that rises with the keyboard. The API signs the other
/// devices out; the sheet closes after the check has shown.
Future<void> _showChangePassword(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      // Over the whole app, like the D24 dialog: the shell under it may rebuild when the session changes.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final l10n = context.l10n;
        final theme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ContentWidth(
              maxWidth: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text(l10n.adminChangePassword, style: theme.textTheme.headlineSmall)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.adminChangePasswordBody,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  ChangePasswordForm(onChanged: () => Navigator.of(context).pop()),
                ],
              ),
            ),
          ),
        );
      },
    );

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

/// «حذف الحساب» (spec 6.17; the App Store and Google Play require it): the
/// shared flow, which explains, asks for the password and signs out.
class _DeletionTile extends StatelessWidget {
  const _DeletionTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
      title: Text(l10n.accountDeletionTile, style: TextStyle(color: scheme.error)),
      subtitle: Text(l10n.accountDeletionTileBody),
      onTap: () => showDeleteAccountFlow(context),
    );
  }
}
