import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// Fades a list or grid item in while it rises [Motion.entranceDistance] dp,
/// [Motion.staggerStep] after the item before it. Only the first
/// [Motion.staggerCount] items animate; later ones simply appear.
/// With reduced motion every item does a short plain fade, all at once.
///
/// Put the list inside a [StaggerGroup] so items that scroll into view later
/// don't replay the entrance, and a tap or swipe finishes it at once:
///
/// ```dart
/// StaggerGroup(
///   child: ListView.builder(
///     itemCount: patients.length,
///     itemBuilder: (context, i) => StaggeredEntrance(index: i, child: PatientTile(patients[i])),
///   ),
/// )
/// ```
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child});

  /// Position in the list; sets the delay.
  final int index;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _progress;
  double _distance = 0;
  bool _planned = false;
  _StaggerGroupState? _group;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_planned) return;
    _planned = true;

    final motion = Motion.of(context);
    _group = context.findAncestorStateOfType<_StaggerGroupState>();
    final play = (_group?.isOpen ?? true) && motion.staggers(widget.index);
    if (!play) return;

    final delay = motion.staggerDelay(widget.index);
    final length = motion.entrance(item: true);
    final total = delay + length;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    _distance = motion.entranceOffset;
    _progress = controller.drive(
      CurveTween(
        curve: Interval(
          delay.inMicroseconds / total.inMicroseconds,
          1,
          curve: Motion.enterCurve,
        ),
      ),
    );
    _group?._skip.addListener(_finish);
    controller.forward();
  }

  void _finish() => _controller?.value = 1;

  @override
  void dispose() {
    _group?._skip.removeListener(_finish);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null) return widget.child;
    return FadeTransition(
      opacity: progress,
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _distance * (1 - progress.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// The start of a staggered list (see [StaggeredEntrance]). Items built after
/// the entrance window ([Motion.staggerWindow]) appear without animating, and
/// any tap or swipe inside the group finishes running entrances at once.
/// Give it a new key to play the entrance again, for example after a refresh.
class StaggerGroup extends StatefulWidget {
  const StaggerGroup({super.key, required this.child});

  final Widget child;

  @override
  State<StaggerGroup> createState() => _StaggerGroupState();
}

class _StaggerGroupState extends State<StaggerGroup> with SingleTickerProviderStateMixin {
  late final AnimationController _window;
  final _skip = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _window = AnimationController(vsync: this, duration: Motion.staggerWindow)..forward();
  }

  bool get isOpen => !_skip.value && !_window.isCompleted;

  @override
  void dispose() {
    _window.dispose();
    _skip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _skip.value = true,
        child: widget.child,
      );
}
