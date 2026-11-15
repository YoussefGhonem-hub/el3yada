import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/motion.dart';

/// The success moment (booking confirmed P15, prescription sent D15, payment
/// submitted D20): a disc pops in and a check draws itself, once, in 1.1 s.
///
/// The Lottie file is hand-made for el3yada (see `assets/lottie/SOURCES.txt`)
/// and its colours are replaced with theme colours here. With reduced motion
/// the finished check fades in. Screen readers hear "Done".
///
/// ```dart
/// SuccessCheck(onCompleted: () => context.go('/patient/appointments'))
/// ```
class SuccessCheck extends StatefulWidget {
  const SuccessCheck({super.key, this.size = 96, this.onCompleted});

  static const asset = 'assets/lottie/success_check.json';

  final double size;

  /// Called once the check has finished drawing.
  final VoidCallback? onCompleted;

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // One provider for the widget's lifetime: a new one would reload the file
  // (and restart the animation) on every rebuild.
  final _lottie = AssetLottie(SuccessCheck.asset);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status.isCompleted) widget.onCompleted?.call();
      });
  }

  void _onLoaded(LottieComposition composition) {
    if (_started || !mounted) return;
    _started = true;
    _controller.duration = composition.duration;
    if (Motion.of(context).reduced) {
      _controller.value = 1; // the status listener reports completion
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.of(context).reduced;
    Widget check = LottieBuilder(
      lottie: _lottie,
      controller: _controller,
      width: widget.size,
      height: widget.size,
      onLoaded: _onLoaded,
      addRepaintBoundary: true,
      delegates: LottieDelegates(
        values: [
          ValueDelegate.color(const ['disc', '**'], value: scheme.primary),
          ValueDelegate.strokeColor(const ['ring', '**'], value: scheme.primary),
          ValueDelegate.strokeColor(const ['check', '**'], value: scheme.onPrimary),
        ],
      ),
    );
    if (reduced) {
      check = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.fast,
        curve: Motion.enterCurve,
        builder: (context, opacity, child) => Opacity(opacity: opacity, child: child),
        child: check,
      );
    }
    return Semantics(
      label: AppLocalizations.of(context).done,
      liveRegion: true,
      child: ExcludeSemantics(child: SizedBox.square(dimension: widget.size, child: check)),
    );
  }
}
