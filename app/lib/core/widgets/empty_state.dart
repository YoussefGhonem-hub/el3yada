import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'staggered_entrance.dart';

/// An empty list or screen: a small illustration, a title, a message and the
/// action that fills it (spec: never plain text alone). Write the message as
/// an invitation to act, for example "No bookings yet" + "Book a visit".
///
/// ```dart
/// EmptyState(
///   title: l10n.noBookingsTitle,
///   message: l10n.noBookingsBody,
///   actionLabel: l10n.bookVisit,
///   onAction: () => context.go('/patient/book'),
/// )
/// ```
///
/// The parts enter one after another; with reduced motion they fade in.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.illustration = const EmptyIllustration(),
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Defaults to the queue ticket. Must be decorative.
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <Widget>[
      ExcludeSemantics(child: illustration),
      const SizedBox(height: 20),
      Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
      if (message != null) ...[
        const SizedBox(height: 8),
        Text(
          message!,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
      if (actionLabel != null && onAction != null) ...[
        const SizedBox(height: 20),
        FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ];

    var index = 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final part in parts)
                part is SizedBox ? part : StaggeredEntrance(index: index++, child: part),
            ],
          ),
        ),
      ),
    );
  }
}

/// The default empty-state picture: a queue ticket on a mint disc, drawn in
/// code from theme colours so it follows light and dark mode and mirrors in
/// Arabic (the stub is on the reading-start side).
class EmptyIllustration extends StatelessWidget {
  const EmptyIllustration({super.key, this.width = 160});

  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size(width, width * 0.75),
      painter: _TicketPainter(
        backdrop: scheme.primaryContainer,
        ticket: scheme.surfaceContainerLow,
        outline: scheme.primary,
        line: scheme.outlineVariant,
        perforation: scheme.outline,
        accent: context.el3yadaColors.brandAccent,
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
    );
  }
}

class _TicketPainter extends CustomPainter {
  _TicketPainter({
    required this.backdrop,
    required this.ticket,
    required this.outline,
    required this.line,
    required this.perforation,
    required this.accent,
    required this.rtl,
  });

  final Color backdrop;
  final Color ticket;
  final Color outline;
  final Color line;
  final Color perforation;
  final Color accent;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 160 × 120 artboard, reading-start on the left.
    canvas.scale(size.width / 160, size.height / 120);
    if (rtl) {
      canvas
        ..translate(160, 0)
        ..scale(-1, 1);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint();

    canvas.drawCircle(const Offset(80, 62), 50, fill..color = backdrop);

    // Sparkles.
    _plus(canvas, const Offset(140, 26), 4, stroke..color = accent..strokeWidth = 2.5);
    canvas.drawCircle(const Offset(24, 96), 3, fill..color = accent);

    canvas
      ..save()
      ..translate(80, 64)
      ..rotate(-0.1)
      ..translate(-52, -32);

    // Ticket with a notch at each end of the perforation.
    const stubWidth = 36.0;
    final body = Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromLTRBR(0, 0, 104, 64, const Radius.circular(10))),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(stubWidth, 0), radius: 7))
        ..addOval(Rect.fromCircle(center: const Offset(stubWidth, 64), radius: 7)),
    );
    canvas
      ..drawPath(body, fill..color = ticket)
      ..drawPath(body, stroke..color = outline..strokeWidth = 2);

    // Perforation.
    stroke
      ..color = perforation
      ..strokeWidth = 2;
    for (var y = 12.0; y < 54; y += 8) {
      canvas.drawLine(Offset(stubWidth, y), Offset(stubWidth, y + 4), stroke);
    }

    // The stub carries the logo's plus; the main part carries text lines.
    _plus(canvas, const Offset(18, 32), 8, stroke..color = accent..strokeWidth = 5);
    canvas
      ..drawRRect(RRect.fromLTRBR(48, 16, 90, 25, const Radius.circular(4.5)), fill..color = outline)
      ..drawRRect(RRect.fromLTRBR(48, 32, 80, 38, const Radius.circular(3)), fill..color = line)
      ..drawRRect(RRect.fromLTRBR(48, 44, 86, 50, const Radius.circular(3)), fill)
      ..restore();
  }

  void _plus(Canvas canvas, Offset center, double arm, Paint paint) {
    canvas
      ..drawLine(center.translate(-arm, 0), center.translate(arm, 0), paint)
      ..drawLine(center.translate(0, -arm), center.translate(0, arm), paint);
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.backdrop != backdrop ||
      old.ticket != ticket ||
      old.outline != outline ||
      old.line != line ||
      old.perforation != perforation ||
      old.accent != accent ||
      old.rtl != rtl;
}
