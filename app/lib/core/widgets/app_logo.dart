import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// The el3yada mark: a ع (which is also a mirrored 3, as in "el3yada") with a
/// plus in its mouth. Drawn in code so it follows the theme in light and dark.
/// Decorative: screens show the app name next to it.
///
/// - [animate]: the ع stroke draws itself ([Motion.slow]), then the plus pops
///   in ([Motion.normal]). With reduced motion the static mark shows.
/// - [hero]: wraps the mark in a `Hero` with [heroTag], so the splash (A1)
///   can hand it to the login header (A3). Use it on one widget per screen.
/// - [onDrawn]: called when the drawing has finished (at once when static),
///   for example to leave the splash.
class AppLogoMark extends StatefulWidget {
  const AppLogoMark({
    super.key,
    this.size = 72,
    this.animate = false,
    this.hero = false,
    this.onDrawn,
  });

  /// Shared by the splash and login so the mark can fly between them.
  static const heroTag = 'el3yada-logo-mark';

  final double size;
  final bool animate;
  final bool hero;
  final VoidCallback? onDrawn;

  @override
  State<AppLogoMark> createState() => _AppLogoMarkState();
}

class _AppLogoMarkState extends State<AppLogoMark> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _stroke;
  Animation<double>? _plus;
  bool _planned = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_planned) return;
    _planned = true;

    if (!widget.animate || Motion.of(context).reduced) {
      if (widget.onDrawn != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onDrawn?.call();
        });
      }
      return;
    }

    final total = Motion.slow + Motion.normal;
    final split = Motion.slow.inMicroseconds / total.inMicroseconds;
    final controller = AnimationController(vsync: this, duration: total)
      ..addStatusListener((status) {
        if (status.isCompleted) widget.onDrawn?.call();
      });
    _controller = controller;
    _stroke = controller.drive(CurveTween(curve: Interval(0, split, curve: Motion.standardCurve)));
    _plus = controller.drive(CurveTween(curve: Interval(split, 1, curve: Motion.springBouncy)));
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget mark = CustomPaint(
      size: Size.square(widget.size),
      painter: _LogoPainter(
        letter: Theme.of(context).colorScheme.primary,
        plus: context.el3yadaColors.brandAccent,
        stroke: _stroke,
        plusScale: _plus,
      ),
    );
    if (_controller != null) mark = RepaintBoundary(child: mark);
    if (widget.hero) mark = Hero(tag: AppLogoMark.heroTag, child: mark);
    return ExcludeSemantics(child: mark);
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.letter, required this.plus, this.stroke, this.plusScale})
      : super(repaint: stroke == null ? null : Listenable.merge([stroke, plusScale]));

  final Color letter;
  final Color plus;

  /// How much of the ع is drawn (0–1); null draws all of it.
  final Animation<double>? stroke;

  /// Size of the plus (0–1, may overshoot); null draws it full size.
  final Animation<double>? plusScale;

  // Designed on a 96 × 96 grid (the logo artboard).
  static final Path _ain = Path()
    ..moveTo(62, 24)
    ..cubicTo(54, 16, 34, 18, 34, 32)
    ..cubicTo(34, 42, 42, 46, 50, 46)
    ..cubicTo(36, 46, 28, 54, 28, 64)
    ..cubicTo(28, 78, 46, 84, 66, 76);
  static final PathMetric _ainMetric = _ain.computeMetrics().first;
  static const Offset _plusCenter = Offset(73, 48.5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96, size.height / 96);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final drawn = stroke?.value ?? 1;
    if (drawn > 0) {
      final ain = drawn >= 1 ? _ain : _ainMetric.extractPath(0, _ainMetric.length * drawn);
      canvas.drawPath(ain, paint..color = letter..strokeWidth = 11);
    }

    final scale = plusScale?.value ?? 1;
    if (scale <= 0) return;
    canvas
      ..translate(_plusCenter.dx, _plusCenter.dy)
      ..scale(scale);
    final cross = Path()
      ..moveTo(0, -9.5)
      ..lineTo(0, 9.5)
      ..moveTo(-9.5, 0)
      ..lineTo(9.5, 0);
    canvas.drawPath(cross, paint..color = plus..strokeWidth = 8);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.letter != letter ||
      oldDelegate.plus != plus ||
      oldDelegate.stroke != stroke ||
      oldDelegate.plusScale != plusScale;
}
