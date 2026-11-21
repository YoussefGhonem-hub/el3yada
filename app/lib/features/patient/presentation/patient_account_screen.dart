import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/settings/app_settings.dart';
import '../../auth/application/auth_controller.dart';
import '../application/patient_providers.dart';
import '../data/patient_repository.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'widgets/patient_widgets.dart';

/// P14 Account and settings: name and phone (read-only), language, appearance, notification
/// toggles, the account deletion request (required by the App Store and Google Play), Logout.
/// Change password (A9), Terms (A12) and support contact come with Phase 1's public settings.
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
              _DeletionTile(account: account),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(l10n.logout),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

/// "Request account deletion": confirmation with an optional reason → admin queue (AD12).
class _DeletionTile extends ConsumerWidget {
  const _DeletionTile({required this.account});

  final PatientAccount account;

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(context: context, builder: (context) => const _DeletionDialog());
    if (reason == null) return;
    try {
      await ref.read(patientAccountProvider.notifier).requestDeletion(reason);
      messenger.showSnackBar(SnackBar(content: Text(l10n.deletionRequestSent)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final request = account.deletionRequest;

    if (account.hasPendingDeletion) {
      return ListTile(
        leading: Icon(Icons.hourglass_top_outlined, color: scheme.error),
        title: Text(l10n.deletionPendingTitle),
        subtitle: Text(l10n.deletionPendingBody(context.date(request!.createdAt))),
      );
    }
    return ListTile(
      leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
      title: Text(l10n.requestAccountDeletion, style: TextStyle(color: scheme.error)),
      subtitle: request?.status == DeletionRequestStatus.rejected
          ? Text(l10n.deletionRejected(request!.reviewNote ?? ''))
          : null,
      onTap: () => _request(context, ref),
    );
  }
}

class _DeletionDialog extends StatefulWidget {
  const _DeletionDialog();

  @override
  State<_DeletionDialog> createState() => _DeletionDialogState();
}

class _DeletionDialogState extends State<_DeletionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.delete_forever_outlined, color: scheme.error),
      title: Text(l10n.requestAccountDeletion),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.deletionConfirmBody),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.deletionReasonLabel),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.pop(context, _reason.text),
          child: Text(l10n.deletionConfirmButton),
        ),
      ],
    );
  }
}
