import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/navigation/app_back_button.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/success_check.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/role_shells.dart';
import '../application/catalog_providers.dart';
import '../data/catalog_files.dart';
import 'catalog_text.dart';

/// D0 "Preparing the catalog": shown at the first sign-in of a doctor, an
/// admin or a `prescriptionsDraft` assistant, and when a large new version
/// arrives (`CatalogSetupHost`); also from Settings. Progress, the size,
/// «يُفضّل استخدام Wi-Fi» and Retry. The app stays usable: leaving this
/// screen keeps the download going, and until it finishes the editors
/// suggest the doctor's own history and take free text.
class CatalogSetupScreen extends ConsumerWidget {
  const CatalogSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(catalogControllerProvider);
    final role = ref.watch(authControllerProvider.select((auth) => auth.value?.role));
    final home = role == null ? null : RoleShell.forRole(role).homePath;
    final version = state.target ?? state.installed;
    final working = state.busy;
    final finished = state.phase == CatalogPhase.ready && state.target == null;

    final status = switch (state.phase) {
      CatalogPhase.checking => l10n.catalogPhaseChecking,
      CatalogPhase.downloading => l10n.catalogPhaseDownloading('${((state.progress ?? 0) * 100).floor()}'),
      CatalogPhase.verifying => l10n.catalogPhaseVerifying,
      CatalogPhase.ready => l10n.catalogPhaseReady,
      CatalogPhase.notPublished => l10n.catalogPhaseNotPublished,
      CatalogPhase.failed => l10n.catalogFailureText(state.failure),
      CatalogPhase.idle || CatalogPhase.unavailable => l10n.catalogPhaseUnavailable,
    };

    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: AppBackButton(fallback: home),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: StaggerGroup(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          enter(_ProgressRing(state: state, finished: finished)),
                          const SizedBox(height: 28),
                          enter(
                            Semantics(
                              header: true,
                              child: Text(
                                l10n.catalogSetupTitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          enter(
                            Text(
                              l10n.catalogSetupBody,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          enter(
                            Semantics(
                              liveRegion: true,
                              child: AnimatedSwitcher(
                                duration: Motion.normal,
                                child: Text(
                                  status,
                                  key: ValueKey(state.phase),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: state.phase == CatalogPhase.failed ? scheme.error : scheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (state.phase == CatalogPhase.downloading || state.phase == CatalogPhase.verifying) ...[
                            const SizedBox(height: 16),
                            _Bar(state: state),
                          ],
                          const SizedBox(height: 20),
                          enter(
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (version != null)
                                  _Chip(
                                    icon: Icons.inventory_2_outlined,
                                    label: l10n.catalogVersionLine(
                                      '${version.version}',
                                      l10n.catalogSize(version.sizeBytes),
                                    ),
                                  ),
                                if (!finished) _Chip(icon: Icons.wifi, label: l10n.catalogSetupWifi),
                              ],
                            ),
                          ),
                          if (!finished && state.phase != CatalogPhase.notPublished) ...[
                            const SizedBox(height: 16),
                            enter(
                              Text(
                                l10n.catalogSetupMeanwhile,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          enter(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (state.phase == CatalogPhase.failed && state.failure != CatalogFailure.schema)
                                  FilledButton.icon(
                                    onPressed: () => ref.read(catalogControllerProvider.notifier).retry(),
                                    icon: const Icon(Icons.refresh),
                                    label: Text(l10n.retryButton),
                                  ),
                                if (finished)
                                  FilledButton(
                                    onPressed: () => AppBackButton.goBack(context, fallback: home),
                                    child: Text(l10n.done),
                                  )
                                else ...[
                                  const SizedBox(height: 8),
                                  if (working)
                                    FilledButton.tonal(
                                      onPressed: () => AppBackButton.goBack(context, fallback: home),
                                      child: Text(l10n.catalogContinue),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () => AppBackButton.goBack(context, fallback: home),
                                      child: Text(l10n.catalogContinue),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A large ring that fills with the download, around the catalog's icon; a
/// spinning ring while checking, the check mark when done.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.state, required this.finished});

  final CatalogState state;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const size = 132.0;
    if (finished) return const SuccessCheck(size: size);
    final failed = state.phase == CatalogPhase.failed;
    final indeterminate = state.phase == CatalogPhase.checking || state.phase == CatalogPhase.verifying;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size - 28,
            height: size - 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: failed ? scheme.errorContainer : scheme.primaryContainer,
            ),
            child: Icon(
              failed ? Icons.cloud_off_outlined : Icons.medication_liquid_outlined,
              size: 46,
              color: failed ? scheme.onErrorContainer : scheme.onPrimaryContainer,
            ),
          ),
          if (indeterminate)
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(strokeWidth: 6, color: scheme.primary, strokeCap: StrokeCap.round),
            )
          else if (state.phase == CatalogPhase.downloading)
            TweenAnimationBuilder<double>(
              tween: Tween(end: state.progress ?? 0),
              duration: Motion.normal,
              curve: Motion.standardCurve,
              builder: (context, value, _) => SizedBox.square(
                dimension: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.state});

  final CatalogState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final verifying = state.phase == CatalogPhase.verifying;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: state.progress ?? 0),
            duration: Motion.normal,
            builder: (context, value, _) => LinearProgressIndicator(
              value: verifying ? null : value,
              minHeight: 8,
              semanticsLabel: l10n.catalogSetupTitle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.catalogSetupProgress(l10n.catalogSize(state.received), l10n.catalogSize(state.total)),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: scheme.surfaceContainerHigh, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
