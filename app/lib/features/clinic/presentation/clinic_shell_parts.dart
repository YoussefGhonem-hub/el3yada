import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/motion_size.dart';
import '../../../app/routes.dart';
import '../../../core/widgets/support_contact.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../../patients/presentation/widgets/clinic_ui.dart' show ClinicFormat;
import '../../startup/startup.dart';
import '../application/clinic_providers.dart';
import '../domain/clinic_context.dart';

/// The current-branch picker in the top bar (BR-BR3, spec 7.1). Shown only
/// when the doctor or assistant works in more than one branch.
class BranchPicker extends ConsumerWidget {
  const BranchPicker({super.key, this.compact = false});

  /// Phones: the store icon and a short name.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinic = ref.watch(clinicContextProvider).value;
    final current = ref.watch(currentBranchProvider);
    final branches = clinic?.workBranches ?? const <ClinicBranch>[];
    if (clinic == null || current == null || branches.length < 2) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    return MenuAnchor(
      menuChildren: [
        for (final branch in branches)
          MenuItemButton(
            leadingIcon: Icon(branch.id == current.id ? Icons.check : null, size: 20),
            onPressed: () => ref.read(currentBranchProvider.notifier).select(branch.id),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branch.name(language)),
                if (branch.status == 'temporarilyClosed')
                  Text(l10n.clinicBranchTemporarilyClosed, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
      ],
      builder: (context, controller, _) => Tooltip(
        message: l10n.clinicCurrentBranch,
        child: TextButton.icon(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.store_mall_directory_outlined, size: 20),
          label: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 96 : 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
                    child: Text(
                      current.name(language),
                      key: ValueKey(current.id),
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: '${l10n.clinicCurrentBranch}: ${current.name(language)}',
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «عيادة د. …» for assistants (spec 7.6), otherwise null.
String? clinicTitle(AppLocalizations l10n, String languageCode, ClinicContext? clinic) {
  if (clinic == null || clinic.isDoctor) return null;
  return l10n.clinicOfDoctor(clinic.doctor.name(languageCode));
}

/// The permanent banner while the doctor is suspended (BR-G5, BR-G8), with
/// Pay now for the doctor and assistants with `billingPay`. It grows in and
/// out with the status.
class SuspensionBanner extends ConsumerWidget {
  const SuspensionBanner({super.key, required this.billingPath});

  /// Where Pay now goes (D18 / AS10).
  final String billingPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinic = ref.watch(clinicContextProvider).value;
    final show = clinic?.isSuspended ?? false;
    final month = clinic?.doctor.suspendedForMonth;
    final suspendedMonth = month == null ? null : DateTime.utc(int.parse(month.substring(0, 4)), int.parse(month.substring(5, 7)));
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MotionSize(
      curve: Motion.enterCurve,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.errorContainer,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      Icon(Icons.pause_circle_outline, color: scheme.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          suspendedMonth == null ? l10n.clinicSuspendedBanner : l10n.clinicSuspendedBannerMonth(ClinicFormat.month(context, suspendedMonth)),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                        ),
                      ),
                      if (clinic!.canPay) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () => context.go(billingPath),
                          child: Text(l10n.clinicPayNow),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The free-trial countdown (BR-T6): in the trial's last [showWithin] days,
/// a calm banner above every clinic screen, with Contact us when the admin
/// has set a support contact. It grows in and out like [SuspensionBanner].
/// The API decides the days left; the device's clock is never used.
class TrialBanner extends ConsumerWidget {
  const TrialBanner({super.key});

  static const showWithin = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trial = ref.watch(clinicContextProvider).value?.trial;
    final show = trial != null && !trial.ended && trial.daysLeft <= showWithin;
    final canContact = ref.watch(publicSettingsProvider)?.hasSupportContact ?? false;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MotionSize(
      curve: Motion.enterCurve,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.secondaryContainer,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_bottom_rounded, size: 20, color: scheme.onSecondaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.trialBanner(trial.daysLeft),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                      ),
                      if (canContact) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: scheme.onSecondaryContainer),
                          onPressed: () => showSupportContactSheet(context),
                          child: Text(l10n.trialContactUs),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The user who closed [EmailVerifyBanner] in this app run, so it stays
/// closed until the next start (or another account signs in).
final emailBannerDismissedProvider = NotifierProvider<EmailBannerDismissed, String?>(EmailBannerDismissed.new);

class EmailBannerDismissed extends Notifier<String?> {
  @override
  String? build() => null;

  void dismiss(String userId) => state = userId;
}

/// "Verify your email" for a doctor whose email isn't verified (A5 [S]): a
/// new doctor is active at once (spec 6.16), so A6 no longer leads there.
/// Calm, like [TrialBanner]: Verify pushes A5 over the shell (Back returns
/// home), and the close button hides it until the app starts again. It
/// goes away by itself once A5 has verified the email and reloaded the
/// account.
class EmailVerifyBanner extends ConsumerWidget {
  const EmailVerifyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final dismissed = ref.watch(emailBannerDismissedProvider);
    final show = session != null &&
        session.role == UserRole.doctor &&
        session.email != null &&
        !session.emailVerified &&
        dismissed != session.userId;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MotionSize(
      curve: Motion.enterCurve,
      child: !show
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.secondaryContainer,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
                  child: Row(
                    children: [
                      Icon(Icons.mark_email_unread_outlined, size: 20, color: scheme.onSecondaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.regVerifyCardTitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: scheme.onSecondaryContainer),
                        onPressed: () => context.push(AppRoutes.verifyEmail),
                        child: Text(l10n.regVerifyButton),
                      ),
                      IconButton(
                        tooltip: l10n.emailBannerDismiss,
                        color: scheme.onSecondaryContainer,
                        iconSize: 20,
                        onPressed: () => ref.read(emailBannerDismissedProvider.notifier).dismiss(session.userId),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// The support contacts (WhatsApp, call, email) in a bottom sheet, for the
/// trial banner's Contact us.
Future<void> showSupportContactSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SupportContact(),
        ),
      ),
    );

/// Shown above the content when the clinic couldn't load (offline at sign-in).
class ClinicLoadError extends ConsumerWidget {
  const ClinicLoadError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(clinicContextProvider);
    if (!state.hasError || state.value != null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.clinicLoadFailed)),
            TextButton(
              onPressed: () => ref.invalidate(clinicContextProvider),
              child: Text(l10n.retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
