import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';

/// Holds the tab navigators of a role's shell (one per `StatefulShellBranch`)
/// and switches between them with a fade-through (spec section 12: "Switching
/// tabs uses fade-through"). Every visited tab stays alive, so its scroll
/// position and inner screens survive a tab switch. With reduced motion the
/// tabs crossfade.
///
/// Used as the router's `navigatorContainerBuilder`.
class FadeThroughBranches extends StatefulWidget {
  const FadeThroughBranches({super.key, required this.currentIndex, required this.children});

  final int currentIndex;
  final List<Widget> children;

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, value: 1)
    ..addStatusListener((status) {
      // The tab that left is hidden once the switch has finished.
      if (status.isCompleted && _previous != null) setState(() => _previous = null);
    });

  /// The tab that is fading out, while a switch runs.
  int? _previous;

  @override
  void didUpdateWidget(FadeThroughBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex == widget.currentIndex) return;
    _previous = oldWidget.currentIndex;
    _controller
      ..duration = Motion.of(context).reduced ? Motion.fast : Motion.normal
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context).reduced;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          _slot(i, widget.children[i], reduced),
      ],
    );
  }

  Widget _slot(int index, Widget child, bool reduced) {
    final active = index == widget.currentIndex;
    final leaving = index == _previous;
    final Animation<double> enter = active ? _controller : kAlwaysCompleteAnimation;
    final Animation<double> exit = leaving ? _controller : kAlwaysDismissedAnimation;

    return Offstage(
      offstage: !active && !leaving,
      child: TickerMode(
        enabled: active,
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: reduced
                ? FadeTransition(
                    opacity: leaving ? ReverseAnimation(exit) : enter,
                    child: child,
                  )
                : FadeThroughTransition(
                    animation: enter,
                    secondaryAnimation: exit,
                    fillColor: Colors.transparent,
                    child: child,
                  ),
          ),
        ),
      ),
    );
  }
}
