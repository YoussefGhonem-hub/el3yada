import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Skeleton placeholders shaped like the content (spec: lists and cards never
/// show a centred spinner). Build the real widget with placeholder data and
/// wrap it: `skeletonizer` paints every text, icon and box as a bone.
///
/// ```dart
/// SkeletonLoading(
///   loading: patients.isLoading,
///   child: PatientList(patients.value ?? PatientList.placeholder),
/// )
/// ```
///
/// The highlight sweep is the only continuous animation here; it sits in a
/// `RepaintBoundary` and becomes a still placeholder with reduced motion.
/// Screen readers hear "Loading…" instead of the placeholder text.
class SkeletonLoading extends StatelessWidget {
  const SkeletonLoading({super.key, required this.loading, required this.child});

  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final reduced = Motion.of(context).reduced;
    final PaintingEffect effect = reduced
        ? SolidColorEffect(color: colors.skeleton)
        : ShimmerEffect(baseColor: colors.skeleton, highlightColor: colors.skeletonHighlight);

    return Semantics(
      label: loading ? AppLocalizations.of(context).loading : null,
      liveRegion: loading,
      child: ExcludeSemantics(
        excluding: loading,
        child: RepaintBoundary(
          child: Skeletonizer(
            enabled: loading,
            effect: effect,
            enableSwitchAnimation: true,
            switchAnimationConfig: const SwitchAnimationConfig(
              duration: Motion.normal,
              reverseDuration: Motion.normalExit,
              switchInCurve: Motion.enterCurve,
              switchOutCurve: Motion.exitCurveReversed,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
