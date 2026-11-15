import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The el3yada mark: a ع (which is also a mirrored 3, as in "el3yada") with a
/// plus in its mouth. Drawn in code so it follows the theme in light and dark.
/// Decorative: screens show the app name next to it.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(
          letter: Theme.of(context).colorScheme.primary,
          plus: context.el3yadaColors.brandAccent,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.letter, required this.plus});

  final Color letter;
  final Color plus;

  @override
  void paint(Canvas canvas, Size size) {
    // Designed on a 96 × 96 grid (the logo artboard).
    canvas.scale(size.width / 96, size.height / 96);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ain = Path()
      ..moveTo(62, 24)
      ..cubicTo(54, 16, 34, 18, 34, 32)
      ..cubicTo(34, 42, 42, 46, 50, 46)
      ..cubicTo(36, 46, 28, 54, 28, 64)
      ..cubicTo(28, 78, 46, 84, 66, 76);
    canvas.drawPath(ain, stroke..color = letter..strokeWidth = 11);

    final cross = Path()
      ..moveTo(73, 39)
      ..lineTo(73, 58)
      ..moveTo(63.5, 48.5)
      ..lineTo(82.5, 48.5);
    canvas.drawPath(cross, stroke..color = plus..strokeWidth = 8);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.letter != letter || oldDelegate.plus != plus;
}
