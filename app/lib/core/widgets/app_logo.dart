import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// The el3yada mark: a ع (which is also a mirrored 3, as in "el3yada") with a
/// plus in its mouth. Drawn in code so it follows the theme in light and dark.
/// Decorative: screens show the app name next to it.
///
/// - [animate]: the signature drawing. The ع is written with a glowing pen
///   tip, the plus spins and pops in on a spring, then two rings spread
///   from the plus like a heartbeat. With reduced motion the static mark
///   shows.
/// - [beat]: while the mark stays on screen, the plus beats gently
///   ("lub-dub") every few seconds. Off with reduced motion.
/// - [beatOnHover]: the plus beats once when the mouse comes over the mark
///   (desktop), instead of on a loop. Off with reduced motion.
/// - [hero]: wraps the mark in a `Hero` with [heroTag]. Use it on one widget
///   per screen.
/// - [onDrawn]: called when the drawing has finished (at once when static),
///   for example to leave the splash.
/// - [letterColor], [plusColor]: for the mark on a pine surface; by default
///   the theme's primary and brand accent.
class AppLogoMark extends StatefulWidget {
  const AppLogoMark({
    super.key,
    this.size = 72,
    this.animate = false,
    this.beat = false,
    this.beatOnHover = false,
    this.hero = false,
    this.onDrawn,
    this.letterColor,
    this.plusColor,
  });

  /// Shared by the splash and login so the mark can fly between them.
  static const heroTag = 'el3yada-logo-mark';

  /// How long the signature drawing takes.
  static const drawDuration = Duration(milliseconds: 1150);

  final double size;
  final bool animate;
  final bool beat;
  final bool beatOnHover;
  final bool hero;
  final VoidCallback? onDrawn;
  final Color? letterColor;
  final Color? plusColor;

  @override
  State<AppLogoMark> createState() => _AppLogoMarkState();
}

class _AppLogoMarkState extends State<AppLogoMark> with TickerProviderStateMixin {
  AnimationController? _draw;
  AnimationController? _beat;
  bool _planned = false;

  /// One heartbeat on hover ([AppLogoMark.beatOnHover]): runs once through
  /// the first part of a period, the "lub" and the "dub".
  AnimationController? _hover;
  Animation<double>? _hoverBeat;
  static const _onePulse = 0.26;

  void _beatOnce() {
    final hover = _hover;
    if (hover == null || _beat != null || Motion.of(context).reduced) return;
    if ((_draw?.isAnimating ?? false) || hover.isAnimating) return;
    hover.forward(from: 0);
  }

  // Phases of the drawing, as parts of [AppLogoMark.drawDuration].
  static const _strokePart = Interval(0, 0.55, curve: Motion.standardCurve);
  static const _plusPart = Interval(0.42, 0.82, curve: Motion.springBouncy);
  static const _ringPart = Interval(0.58, 1, curve: Curves.easeOutCubic);

  /// The heartbeat: one beat per [_beatPeriod], the "lub" then the "dub".
  static const _beatPeriod = Duration(milliseconds: 2600);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_planned) return;
    _planned = true;
    final reduced = Motion.of(context).reduced;

    if (widget.beat && Motion.of(context).loops) {
      _beat = AnimationController(vsync: this, duration: _beatPeriod);
    } else if (widget.beatOnHover) {
      final hover = _hover = AnimationController(vsync: this, duration: _beatPeriod * _onePulse);
      _hoverBeat = hover.drive(Tween(begin: 0, end: _onePulse));
    }

    if (!widget.animate || reduced) {
      _beat?.repeat();
      if (widget.onDrawn != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onDrawn?.call();
        });
      }
      return;
    }

    _draw = AnimationController(vsync: this, duration: AppLogoMark.drawDuration)
      ..addStatusListener((status) {
        if (!status.isCompleted) return;
        widget.onDrawn?.call();
        _beat?.repeat();
      })
      ..forward();
  }

  @override
  void dispose() {
    _draw?.dispose();
    _beat?.dispose();
    _hover?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget mark = CustomPaint(
      size: Size.square(widget.size),
      painter: _LogoPainter(
        letter: widget.letterColor ?? Theme.of(context).colorScheme.primary,
        plus: widget.plusColor ?? context.el3yadaColors.brandAccent,
        draw: _draw,
        beat: _beat ?? _hoverBeat,
      ),
    );
    if (_draw != null || _beat != null || _hover != null) mark = RepaintBoundary(child: mark);
    if (_hover != null) mark = MouseRegion(onEnter: (_) => _beatOnce(), child: mark);
    if (widget.hero) mark = Hero(tag: AppLogoMark.heroTag, child: mark);
    return ExcludeSemantics(child: mark);
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.letter, required this.plus, this.draw, this.beat})
      : super(repaint: Listenable.merge([?draw, ?beat]));

  final Color letter;
  final Color plus;

  /// The signature drawing (0–1); null draws the finished mark.
  final Animation<double>? draw;

  /// The heartbeat loop (0–1 per beat); null for none.
  final Animation<double>? beat;

  // Designed on a 96 × 96 grid (the logo artboard).
  static final Path _ain = Path()
    ..moveTo(62, 24)
    ..cubicTo(54, 16, 34, 18, 34, 32)
    ..cubicTo(34, 42, 42, 46, 50, 46)
    ..cubicTo(36, 46, 28, 54, 28, 64)
    ..cubicTo(28, 78, 46, 84, 66, 76);
  static final PathMetric _ainMetric = _ain.computeMetrics().first;
  static const Offset _plusCenter = Offset(73, 48.5);

  /// The heartbeat's scale at [t] (0–1 of one period): a strong beat, a
  /// softer one right after, then rest.
  static double _beatScale(double t) {
    double pulse(double at, double width, double height) {
      final x = (t - at) / width;
      return x <= 0 || x >= 1 ? 0 : math.sin(x * math.pi) * height;
    }

    return 1 + pulse(0.0, 0.11, 0.2) + pulse(0.13, 0.11, 0.11);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 96, size.height / 96);
    final t = draw?.value ?? 1;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. The ع, written with a glowing pen tip.
    final drawn = _AppLogoMarkState._strokePart.transform(t);
    if (drawn > 0) {
      final length = _ainMetric.length * drawn;
      final ain = drawn >= 1 ? _ain : _ainMetric.extractPath(0, length);
      canvas.drawPath(ain, paint..color = letter..strokeWidth = 11);
      if (drawn < 1) {
        final tip = _ainMetric.getTangentForOffset(length)?.position;
        if (tip != null) {
          final fade = 1 - drawn * drawn;
          canvas.drawCircle(
            tip,
            9,
            Paint()
              ..color = plus.withValues(alpha: 0.55 * fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          canvas.drawCircle(tip, 3.2, Paint()..color = plus.withValues(alpha: fade));
        }
      }
    }

    // 2. Rings spreading from the plus, once, after it lands.
    if (draw != null && t < 1) {
      final rings = _AppLogoMarkState._ringPart.transform(t);
      if (rings > 0) {
        for (final (delay, maxRadius) in [(0.0, 34.0), (0.25, 46.0)]) {
          final p = ((rings - delay) / (1 - delay)).clamp(0.0, 1.0);
          if (p <= 0 || p >= 1) continue;
          canvas.drawCircle(
            _plusCenter,
            10 + (maxRadius - 10) * p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5 * (1 - p) + 0.5
              ..color = plus.withValues(alpha: 0.55 * (1 - p)),
          );
        }
      }
    }

    // 3. The plus: spins a quarter turn and pops in, then beats.
    final pop = draw == null ? 1.0 : _AppLogoMarkState._plusPart.transform(t);
    if (pop <= 0) return;
    final scale = pop * (beat == null ? 1 : _beatScale(beat!.value));
    canvas
      ..save()
      ..translate(_plusCenter.dx, _plusCenter.dy)
      ..rotate((1 - pop.clamp(0.0, 1.0)) * -math.pi / 2)
      ..scale(scale);
    final cross = Path()
      ..moveTo(0, -9.5)
      ..lineTo(0, 9.5)
      ..moveTo(-9.5, 0)
      ..lineTo(9.5, 0);
    canvas
      ..drawPath(cross, paint..color = plus..strokeWidth = 8)
      ..restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.letter != letter ||
      oldDelegate.plus != plus ||
      oldDelegate.draw != draw ||
      oldDelegate.beat != beat;
}
