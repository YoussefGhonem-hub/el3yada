import 'package:material_ui/material_ui.dart';

import '../theme/motion.dart';

/// Pressed feedback for custom tappable surfaces (cards, tiles, nav items):
/// the child scales to [pressedScale] within 100 ms of the finger landing and
/// springs back on release. With reduced motion it dims instead of scaling.
///
/// Material buttons and `InkWell` already give a ripple; use this for custom
/// surfaces. It is a button for screen readers, takes keyboard focus (Enter
/// or Space activates it) and shows a focus ring.
///
/// ```dart
/// Pressable(onTap: openPatient, child: PatientCard(patient))
/// ```
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.pressedScale = 0.97,
    this.semanticLabel,
    this.selected,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  /// Null disables the surface (no feedback, announced as disabled).
  final VoidCallback? onTap;
  final Widget child;

  /// About 0.97 for cards; small targets such as nav items can go lower.
  final double pressedScale;

  /// Replaces the child's own semantics when set.
  final String? semanticLabel;

  /// Announced as selected / not selected when set (tabs, menu items).
  final bool? selected;

  /// Shape of the keyboard focus ring.
  final BorderRadius borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final scheme = Theme.of(context).colorScheme;
    final pressed = _pressed && _enabled;

    // Press lands within 100 ms; release springs back.
    final duration = pressed ? Motion.press : Motion.fast;
    Widget content = motion.reduced
        ? AnimatedOpacity(
            opacity: pressed ? 0.7 : 1,
            duration: duration,
            curve: Motion.enterCurve,
            child: widget.child,
          )
        : AnimatedScale(
            scale: pressed ? widget.pressedScale : 1,
            duration: duration,
            curve: pressed ? Motion.enterCurve : Motion.spring,
            child: widget.child,
          );

    if (_focused) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(color: scheme.primary, width: 2),
        ),
        child: content,
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
            widget.onTap?.call();
            return null;
          }),
        },
        // The pointer listener shows the press at once, even inside a scroll
        // view where the tap is only recognised after a delay; a drag that
        // takes over the gesture cancels the tap and releases the press.
        child: Listener(
          onPointerDown: _enabled ? (_) => _setPressed(true) : null,
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapCancel: () => _setPressed(false),
            onTap: widget.onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}
