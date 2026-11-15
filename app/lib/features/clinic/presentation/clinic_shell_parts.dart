import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/motion.dart';
import '../../../l10n/gen/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final motion = Motion.of(context);
    return AnimatedSize(
      duration: motion.reduced ? Duration.zero : Motion.normal,
      curve: Motion.enterCurve,
      alignment: AlignmentDirectional.topStart,
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
                          l10n.clinicSuspendedBanner,
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
