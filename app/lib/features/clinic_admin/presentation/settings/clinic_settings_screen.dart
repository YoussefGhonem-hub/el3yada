import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/platform/device_identity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/preference_pickers.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/support_contact.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/change_password_form.dart';
import '../../../clinic/application/clinic_providers.dart';
import '../../../clinic/domain/clinic_context.dart';
import '../../../clinic/domain/clinic_permissions.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../clinic_admin_routes.dart';
import '../../domain/account_models.dart';
import '../assistants/assistant_text.dart';
import '../branches/branch_text.dart';
import '../widgets/clinic_admin_widgets.dart';

/// D24 (doctor) and AS12 (assistant) settings. Both have the identity
/// ticket, language and appearance, notification preferences, change
/// password, support, about and log out. The doctor's ticket opens the
/// profile (D22) and Visit prices opens D37; an assistant sees their
/// permissions and branches read-only, and Visit prices (AS19) only with
/// `pricesManage`.
class ClinicSettingsScreen extends ConsumerWidget {
  const ClinicSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clinic = ref.watch(clinicContextProvider).value;
    final doctor = ref.watch(authControllerProvider.select((auth) => auth.value?.role)) == UserRole.doctor;
    return ClinicPage(
      builder: (context, width) {
        final wide = width >= kAdminWideLayout;
        const gap = SizedBox(height: 24);
        final header = AdminHeader(
          title: l10n.navSettings,
          subtitle: doctor ? l10n.settingsSubtitleDoctor : l10n.settingsSubtitleAssistant,
        );
        final identity = _IdentityTicket(clinic: clinic, doctor: doctor);
        final clinicGroup = _ClinicGroup(clinic: clinic, doctor: doctor);
        final preferences = _PreferencesGroup(narrow: width < 400);
        final notifications = _NotificationsGroup(doctor: doctor);
        const account = _AccountGroup();
        const about = _AboutGroup();
        final permissions = !doctor && clinic != null ? _MyPermissionsGroup(clinic: clinic) : null;
        final branches = !doctor && clinic != null ? _MyBranchesGroup(clinic: clinic) : null;

        // An assistant's branches and permissions are for reading, so they
        // come after the settings they change.
        if (!wide) {
          return [
            header,
            const SizedBox(height: 16),
            identity,
            if (clinicGroup.visible) ...[gap, clinicGroup],
            gap,
            preferences,
            gap,
            notifications,
            gap,
            account,
            if (branches != null) ...[gap, branches],
            if (permissions != null) ...[gap, permissions],
            gap,
            about,
          ];
        }
        return [
          header,
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    if (clinicGroup.visible) ...[gap, clinicGroup],
                    if (branches != null) ...[gap, branches],
                    if (permissions != null) ...[gap, permissions],
                    if (doctor) ...[gap, account],
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [preferences, gap, notifications, if (!doctor) ...[gap, account], gap, about],
                ),
              ),
            ],
          ),
        ];
      },
    );
  }
}

/// The pine ticket at the top: who you are in this clinic. The doctor's
/// stub opens the profile (D22).
class _IdentityTicket extends StatelessWidget {
  const _IdentityTicket({required this.clinic, required this.doctor});

  final ClinicContext? clinic;
  final bool doctor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.el3yadaColors;
    final language = Localizations.localeOf(context).languageCode;
    final clinic = this.clinic;
    final onPine = scheme.onPrimary;
    final muted = onPine.withValues(alpha: 0.78);

    final String name;
    final String detail;
    if (clinic == null) {
      name = '';
      detail = '';
    } else if (doctor) {
      final d = clinic.doctor;
      name = l10n.adminDoctorName(d.name(language));
      final title = language == 'en' && d.titleEn != null ? d.titleEn! : d.title;
      detail = [title, language == 'en' ? d.specialtyNameEn : d.specialtyNameAr].where((s) => s.isNotEmpty).join(' · ');
    } else {
      name = clinic.assistant?.fullName ?? '';
      detail = l10n.clinicOfDoctor(clinic.doctor.name(language));
    }

    final top = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.navIndicator, shape: BoxShape.circle),
              child: Text(
                InitialAvatar.initialOf(name.replaceFirst(RegExp(r'^(د\.|Dr\.)\s*'), '')),
                style: theme.textTheme.titleLarge?.copyWith(color: colors.onNavIndicator, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleLarge?.copyWith(color: onPine, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                if (!doctor && clinic?.assistant != null) ...[
                  const SizedBox(height: 8),
                  PresetPill(preset: clinic!.assistant!.preset),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final Widget stub;
    if (doctor) {
      stub = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 12, 14),
        child: Row(
          children: [
            Icon(Icons.badge_outlined, size: 20, color: colors.navIndicator),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.profileTitle, style: theme.textTheme.titleSmall?.copyWith(color: onPine)),
                  Text(l10n.settingsProfileHint, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ],
              ),
            ),
            Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right, color: onPine),
          ],
        ),
      );
    } else {
      final permissions = clinic?.permissions.length ?? 0;
      final branches = clinic?.workBranches.length ?? 0;
      stub = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 16),
        child: Wrap(
          spacing: 20,
          runSpacing: 6,
          children: [
            _StubFact(icon: Icons.verified_user_outlined, text: l10n.settingsPermissionCount(permissions)),
            _StubFact(icon: Icons.store_mall_directory_outlined, text: l10n.settingsBranchCount(branches)),
          ],
        ),
      );
    }

    return SkeletonLoading(
      loading: clinic == null,
      child: TicketCard(
        pine: true,
        onTap: doctor && clinic != null ? () => context.go(ClinicAdminRoutes.doctorProfile) : null,
        semanticLabel: doctor ? '$name, $detail. ${l10n.profileTitle}' : null,
        stub: stub,
        child: top,
      ),
    );
  }
}

class _StubFact extends StatelessWidget {
  const _StubFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final onPine = Theme.of(context).colorScheme.onPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 18, color: context.el3yadaColors.navIndicator)),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: onPine)),
      ],
    );
  }
}

/// Visit prices: the doctor's always, an assistant's with `pricesManage`.
class _ClinicGroup extends StatelessWidget {
  const _ClinicGroup({required this.clinic, required this.doctor});

  final ClinicContext? clinic;
  final bool doctor;

  bool get visible => doctor || (clinic?.can(ClinicPermission.pricesManage) ?? false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsGroup(
      title: l10n.settingsClinicGroup,
      children: [
        SettingsTile(
          icon: Icons.sell_outlined,
          title: l10n.pricesTitle,
          subtitle: l10n.settingsPricesHint,
          onTap: () => context.go(ClinicAdminRoutes.pricesFor(doctor: doctor)),
        ),
      ],
    );
  }
}

/// AS12: what the doctor allowed, read-only, in checklist order.
class _MyPermissionsGroup extends StatelessWidget {
  const _MyPermissionsGroup({required this.clinic});

  final ClinicContext clinic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keys = [for (final key in ClinicPermission.all) if (clinic.permissions.contains(key)) key];
    return SettingsGroup(
      title: l10n.settingsMyPermissions,
      footer: l10n.settingsMyPermissionsFooter,
      children: [
        if (keys.isEmpty) SettingsTile(icon: Icons.block, title: l10n.settingsNoPermissions),
        for (final key in keys)
          SettingsTile(
            icon: permissionGroupIcon(permissionGroups.firstWhere((g) => g.$2.contains(key)).$1),
            title: l10n.permissionName(key),
            subtitle: l10n.permissionHelp(key),
          ),
      ],
    );
  }
}

/// AS12: the branches the assistant works in (BR-AS13).
class _MyBranchesGroup extends StatelessWidget {
  const _MyBranchesGroup({required this.clinic});

  final ClinicContext clinic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final all = clinic.assistant?.allBranches ?? false;
    return SettingsGroup(
      title: l10n.settingsMyBranches,
      footer: all ? l10n.settingsAllBranchesFooter : null,
      children: [
        for (final branch in clinic.workBranches)
          SettingsTile(
            icon: Icons.store_mall_directory_outlined,
            title: branch.name(language),
            subtitle: [branch.city, branch.governorate].where((s) => s.isNotEmpty).join(l10n.adminListSeparator),
            trailing: branch.isDefault
                ? const DefaultBranchPill()
                : branch.status == 'temporarilyClosed'
                    ? BranchStatusPill(status: branch.status)
                    : null,
          ),
      ],
    );
  }
}

class _PreferencesGroup extends StatelessWidget {
  const _PreferencesGroup({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsGroup(
      title: l10n.adminPreferences,
      footer: l10n.adminPreferencesBody,
      children: [
        SettingsTile(icon: Icons.translate, title: l10n.adminLanguage, below: const Align(alignment: AlignmentDirectional.centerStart, child: LanguagePicker())),
        SettingsTile(
          icon: Icons.palette_outlined,
          title: l10n.appearance,
          below: Align(alignment: AlignmentDirectional.centerStart, child: AppearancePicker(showIcons: !narrow)),
        ),
      ],
    );
  }
}

/// Saved on the account at once (`updateNotificationPrefs`); a failed save
/// puts the switch back and says why.
class _NotificationsGroup extends ConsumerWidget {
  const _NotificationsGroup({required this.doctor});

  final bool doctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(notificationPrefsProvider);
    final controller = ref.read(notificationPrefsProvider.notifier);

    Future<void> set({bool? chat, bool? reminders, bool? showPreview, bool? bookings}) async {
      try {
        await controller.set(chat: chat, reminders: reminders, showPreview: showPreview, bookings: bookings);
      } catch (error) {
        if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
      }
    }

    List<Widget> rows(NotificationPrefs p, {bool enabled = true}) => [
          SettingsSwitchTile(
            icon: Icons.chat_bubble_outline,
            title: l10n.settingsNotifyChat,
            subtitle: l10n.settingsNotifyChatHint,
            value: p.chat,
            onChanged: enabled ? (v) => set(chat: v) : null,
          ),
          SettingsSwitchTile(
            icon: Icons.alarm_outlined,
            title: l10n.settingsNotifyReminders,
            subtitle: l10n.settingsNotifyRemindersHint,
            value: p.reminders,
            onChanged: enabled ? (v) => set(reminders: v) : null,
          ),
          if (doctor)
            SettingsSwitchTile(
              icon: Icons.event_available_outlined,
              title: l10n.settingsNotifyBookings,
              subtitle: l10n.settingsNotifyBookingsHint,
              value: p.bookings,
              onChanged: enabled ? (v) => set(bookings: v) : null,
            ),
          SettingsSwitchTile(
            icon: Icons.visibility_outlined,
            title: l10n.settingsShowPreview,
            subtitle: l10n.settingsShowPreviewHint,
            value: p.showPreview,
            onChanged: enabled ? (v) => set(showPreview: v) : null,
          ),
        ];

    return SettingsGroup(
      title: l10n.settingsNotifications,
      children: [
        AsyncStateSwitcher<NotificationPrefs>(
          value: prefs,
          loading: (context) => SkeletonLoading(
            loading: true,
            child: Column(children: rows(const NotificationPrefs(), enabled: false)),
          ),
          error: (context, error) => SettingsTile(
            icon: Icons.cloud_off_outlined,
            title: l10n.apiError(error),
            trailing: TextButton(onPressed: controller.reload, child: Text(l10n.retryButton)),
          ),
          data: (context, value) => Column(
            children: [
              for (final (i, row) in rows(value).indexed) ...[if (i > 0) const Divider(height: 1, indent: 68), row],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountGroup extends ConsumerWidget {
  const _AccountGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsGroup(
      title: l10n.settingsAccount,
      children: [
        SettingsTile(
          icon: Icons.lock_outline,
          title: l10n.adminChangePassword,
          subtitle: l10n.adminChangePasswordBody,
          onTap: () => showChangePasswordDialog(context),
        ),
        SettingsTile(
          icon: Icons.logout,
          title: l10n.logout,
          subtitle: l10n.adminLogoutBody,
          destructive: true,
          onTap: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}

/// Support (the admin's WhatsApp, phone and email), Terms, Privacy and the version.
class _AboutGroup extends ConsumerWidget {
  const _AboutGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final version = ref.watch(deviceIdentityProvider).value?.appVersion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SupportContact(),
        const SizedBox(height: 16),
        SettingsGroup(
          title: l10n.settingsAbout,
          children: [
            SettingsTile(icon: Icons.description_outlined, title: l10n.termsTitle, onTap: () => context.push(AppRoutes.terms)),
            SettingsTile(icon: Icons.privacy_tip_outlined, title: l10n.privacyTitle, onTap: () => context.push(AppRoutes.privacy)),
            SettingsTile(
              icon: Icons.info_outline,
              title: l10n.appTitle,
              subtitle: l10n.appTagline,
              trailing: version == null ? null : StatusPill(label: l10n.appVersionLabel(version)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Change password in a dialog (D24, AS12): the same form as AD18.
Future<void> showChangePasswordDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(header: true, child: Text(l10n.adminChangePassword, style: theme.textTheme.headlineSmall)),
                      ),
                      IconButton(
                        tooltip: l10n.adminClose,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
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
