import 'package:material_ui/material_ui.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/motion.dart';
import 'shake_on_error.dart';
import 'submit_button.dart';

/// "3 changes not saved · Discard · Save" at the bottom of a form (AD13,
/// D22, D26, D29): it slides up while there are changes and sits above the
/// phone's floating bar ([bottomInset]). It shakes once when [failures]
/// grows, and shows [error] above the buttons.
class SaveBar extends StatelessWidget {
  const SaveBar({
    super.key,
    required this.visible,
    required this.dirty,
    required this.status,
    required this.onDiscard,
    required this.onSave,
    this.error,
    this.failures = 0,
    this.gutter = 16,
    this.bottomInset = 0,
    this.saveLabel,
    this.label,
    this.discardLabel,
  });

  final bool visible;

  /// How many changes are waiting.
  final int dirty;
  final SubmitStatus status;
  final String? error;
  final int failures;
  final double gutter;
  final double bottomInset;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  /// Defaults to Save.
  final String? saveLabel;

  /// Replaces "3 changes not saved" (a form that adds something new).
  final String? label;

  /// Defaults to Discard.
  final String? discardLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = Motion.of(context).reduced;
    final bar = Material(
      color: scheme.surfaceContainerLow,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.3),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + bottomInset),
          child: ShakeOnError(
            trigger: failures == 0 ? null : failures,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          status == SubmitStatus.success ? l10n.adminAllSaved : (label ?? l10n.adminUnsavedChanges(dirty)),
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: status == SubmitStatus.idle ? onDiscard : null,
                      child: Text(discardLabel ?? l10n.adminDiscard),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      child: SubmitButton(label: saveLabel ?? l10n.adminSave, status: status, onPressed: onSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return AnimatedSwitcher(
      duration: Motion.normal,
      reverseDuration: Motion.normalExit,
      switchInCurve: Motion.enterCurve,
      switchOutCurve: Motion.exitCurveReversed,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: reduced
            ? FadeTransition(opacity: animation, child: child)
            : SlideTransition(
                position: animation.drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero)),
                child: FadeTransition(opacity: animation, child: child),
              ),
      ),
      child: visible ? KeyedSubtree(key: const ValueKey('bar'), child: bar) : const SizedBox(width: double.infinity),
    );
  }
}
