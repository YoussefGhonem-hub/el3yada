import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// The brand surface behind the splash, login and language screens: a deep
/// pine gradient with soft mint and teal lights that drift slowly, and a few
/// faint plus signs floating up. It loops calmly (one cycle every
/// [period]); with reduced motion (or [Motion.ambientLoops] off) it stands
/// still.
///
/// Text on it uses white or [AppColors.mint] (both pass 4.5:1 on pine).
class BrandBackdrop extends StatefulWidget {
  const BrandBackdrop({super.key, this.child});

  final Widget? child;

  static const period = Duration(seconds: 18);

  /// The gradient's colours, top to bottom, for light and dark.
  static List<Color> colorsFor(Brightness brightness) => brightness == Brightness.dark
      ? const [Color(0xFF0F3A35), Color(0xFF0B2622), Color(0xFF061412)]
      : const [Color(0xFF15604F), AppColors.pine, Color(0xFF0A3732)];

  @override
  State<BrandBackdrop> createState() => _BrandBackdropState();
}

class _BrandBackdropState extends State<BrandBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: BrandBackdrop.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.of(context).loops) {
      _loop.stop();
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return CustomPaint(
      painter: _BackdropPainter(
        loop: _loop,
        colors: BrandBackdrop.colorsFor(brightness),
        dark: brightness == Brightness.dark,
      ),
      isComplex: true,
      willChange: true,
      child: widget.child,
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.loop, required this.colors, required this.dark}) : super(repaint: loop);

  final Animation<double> loop;
  final List<Color> colors;
  final bool dark;

  /// Plus signs: (x 0–1, start y 0–1, size, speed in screens per loop, alpha).
  static const _pluses = [
    (0.12, 0.18, 10.0, 1.0, 0.16),
    (0.82, 0.10, 14.0, 0.7, 0.12),
    (0.66, 0.52, 8.0, 1.3, 0.14),
    (0.28, 0.70, 12.0, 0.8, 0.10),
    (0.90, 0.78, 9.0, 1.1, 0.14),
    (0.46, 0.34, 6.0, 1.5, 0.12),
    (0.06, 0.92, 11.0, 0.9, 0.10),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );

    final a = loop.value * 2 * math.pi;
    final longest = size.longestSide;
    void light(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Three lights on slow, different orbits.
    light(
      Offset(size.width * (0.85 + 0.08 * math.sin(a)), size.height * (0.12 + 0.05 * math.cos(a))),
      longest * 0.42,
      AppColors.mint.withValues(alpha: dark ? 0.16 : 0.26),
    );
    light(
      Offset(size.width * (0.10 + 0.10 * math.cos(a + 1)), size.height * (0.62 + 0.06 * math.sin(a * 2))),
      longest * 0.5,
      const Color(0xFF2BB594).withValues(alpha: dark ? 0.14 : 0.22),
    );
    light(
      Offset(size.width * (0.55 + 0.12 * math.sin(a + 2)), size.height * (0.38 + 0.08 * math.cos(a + 0.5))),
      longest * 0.3,
      Colors.white.withValues(alpha: dark ? 0.03 : 0.06),
    );

    // Faint plus signs floating up and wrapping round.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (x, y, s, speed, alpha) in _pluses) {
      final travel = (y - loop.value * speed) % 1.0;
      final center = Offset(
        size.width * x + math.sin(a * speed + x * 10) * 8,
        -20 + (size.height + 40) * travel,
      );
      stroke
        ..strokeWidth = s / 4
        ..color = Colors.white.withValues(alpha: alpha);
      canvas
        ..drawLine(center.translate(-s / 2, 0), center.translate(s / 2, 0), stroke)
        ..drawLine(center.translate(0, -s / 2), center.translate(0, s / 2), stroke);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => oldDelegate.dark != dark || oldDelegate.loop != loop;
}

/// A frosted glass disc with a soft mint glow behind the logo.
class BrandMedallion extends StatelessWidget {
  const BrandMedallion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 132,
        height: 132,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.04)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(color: AppColors.mint.withValues(alpha: 0.22), blurRadius: 48, spreadRadius: 4),
          ],
        ),
        child: child,
      );
}

/// White icons and text for controls that sit on the pine brand backdrop.
class OnBrand extends StatelessWidget {
  const OnBrand({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        iconTheme: const IconThemeData(color: Colors.white),
        popupMenuTheme: theme.popupMenuTheme.copyWith(iconColor: Colors.white),
        iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Colors.white)),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            textStyle: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      child: child,
    );
  }
}
