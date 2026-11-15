import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/motion.dart';

/// Where a submit action is.
enum SubmitStatus { idle, loading, success }

/// A filled button whose label morphs into a progress indicator while the
/// action runs, then into a check (spec A3 "Sign in morphs into a progress
/// indicator, then into a check"). The parent owns [status].
///
/// ```dart
/// SubmitButton(
///   label: l10n.signInButton,
///   status: _status, // idle → loading → success, or back to idle on error
///   onPressed: _submit,
/// )
/// ```
///
/// - The button keeps its size: only the content changes, by fade and scale.
/// - Actions that finish within [Motion.loaderDelay] (300 ms) never show the
///   indicator; the label goes straight to the check.
/// - While loading or done it ignores taps but keeps its colour.
/// - Screen readers hear the label, then "Loading…", then "Done".
class SubmitButton extends StatefulWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.status = SubmitStatus.idle,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final SubmitStatus status;

  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

enum _Face { label, progress, check }

class _SubmitButtonState extends State<SubmitButton> with SingleTickerProviderStateMixin {
  late final AnimationController _loaderDelay;

  @override
  void initState() {
    super.initState();
    _loaderDelay = AnimationController(vsync: this, duration: Motion.loaderDelay)
      ..addStatusListener((status) {
        if (status.isCompleted) setState(() {});
      });
    if (widget.status == SubmitStatus.loading) _loaderDelay.forward();
  }

  @override
  void didUpdateWidget(SubmitButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == oldWidget.status) return;
    if (widget.status == SubmitStatus.loading) {
      _loaderDelay.forward(from: 0);
    } else {
      _loaderDelay.reset();
    }
  }

  @override
  void dispose() {
    _loaderDelay.dispose();
    super.dispose();
  }

  _Face get _face => switch (widget.status) {
        SubmitStatus.idle => _Face.label,
        SubmitStatus.loading => _loaderDelay.isCompleted ? _Face.progress : _Face.label,
        SubmitStatus.success => _Face.check,
      };

  void _handlePressed() {
    if (widget.status == SubmitStatus.idle) widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    final busy = widget.status != SubmitStatus.idle;
    final face = _face;

    return AbsorbPointer(
      absorbing: busy,
      child: FilledButton(
        onPressed: widget.onPressed == null ? null : _handlePressed,
        child: Semantics(
          label: switch (widget.status) {
            SubmitStatus.idle => widget.label,
            SubmitStatus.loading => l10n.loading,
            SubmitStatus.success => l10n.done,
          },
          liveRegion: busy,
          excludeSemantics: true,
          child: SizedBox(
            height: 26,
            child: AnimatedSwitcher(
              duration: Motion.normal,
              reverseDuration: Motion.normalExit,
              switchInCurve: Motion.enterCurve,
              switchOutCurve: Motion.exitCurveReversed,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: reduced
                    ? child
                    : ScaleTransition(scale: animation.drive(Tween(begin: 0.6, end: 1)), child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey(face),
                child: Center(
                  child: switch (face) {
                    _Face.label => Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    _Face.progress => const _Progress(),
                    _Face.check => _Check(bounce: !reduced),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: SizedBox.square(
          dimension: 22,
          // The button's foreground colour (on primary).
          child: CircularProgressIndicator(strokeWidth: 2.5, color: IconTheme.of(context).color),
        ),
      );
}

class _Check extends StatelessWidget {
  const _Check({required this.bounce});

  final bool bounce;

  @override
  Widget build(BuildContext context) {
    const icon = Icon(Icons.check_rounded, size: 26);
    if (!bounce) return icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: Motion.slow,
      curve: Motion.springBouncy,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: icon,
    );
  }
}
