import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// The A4 progress header: "Step 2 of 4", the step's name, and a bar of
/// [labels].length segments that fill up to the current step. The fill
/// slides along the reading direction (it starts on the right in Arabic);
/// with reduced motion it changes at once. Wide screens also name every
/// step under its segment.
///
/// Screen readers hear "Step 2 of 4: Professional details" whenever the
/// step changes.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.labels});

  /// 0-based.
  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = Motion.of(context).reduced;
    final count = labels.length;

    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.regStepSemantics(step + 1, count, labels[step]),
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 480;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.regStepOf(step + 1, count),
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: Motion.normal,
                  reverseDuration: Motion.normalExit,
                  switchInCurve: Motion.enterCurve,
                  switchOutCurve: Motion.exitCurveReversed,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [...previous, ?current],
                  ),
                  child: Text(
                    labels[step],
                    key: ValueKey(step),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: step + 1.0),
                  duration: reduced ? Duration.zero : Motion.slow,
                  curve: Motion.standardCurve,
                  builder: (context, filled, _) => Row(
                    children: [
                      for (var i = 0; i < count; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(
                          child: _Segment(
                            fill: (filled - i).clamp(0.0, 1.0),
                            label: wide ? labels[i] : null,
                            current: i == step,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.fill, required this.current, this.label});

  final double fill;
  final bool current;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHighest),
            // Transform only (spec 12): the fill scales from the start edge.
            Transform.scale(
              scaleX: fill,
              alignment: AlignmentDirectional.centerStart.resolve(Directionality.of(context)),
              child: ColoredBox(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
    if (label == null) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        const SizedBox(height: 6),
        Text(
          label!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: current || fill >= 1 ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: current ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
