import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../patients/presentation/widgets/clinic_ui.dart';
import '../../domain/session_models.dart';

/// The queue-ticket outline (the design's signature shape): a rounded card
/// with a notch at each end of a perforation, [stubWidth] from the
/// reading-start edge (the right in Arabic).
class TicketShapeBorder extends ShapeBorder {
  const TicketShapeBorder({this.side = BorderSide.none, this.radius = 20, this.stubWidth = 96, this.notch = 9});

  final BorderSide side;
  final double radius;
  final double stubWidth;
  final double notch;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  double _stubX(Rect rect, TextDirection? direction) =>
      direction == TextDirection.rtl ? rect.right - stubWidth : rect.left + stubWidth;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final x = _stubX(rect, textDirection);
    return Path.combine(
      PathOperation.difference,
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
      Path()
        ..addOval(Rect.fromCircle(center: Offset(x, rect.top), radius: notch))
        ..addOval(Rect.fromCircle(center: Offset(x, rect.bottom), radius: notch)),
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final x = _stubX(rect, textDirection);
    // The perforation between the stub and the rest.
    final dash = Paint()
      ..color = side.style == BorderStyle.none ? const Color(0x00000000) : side.color.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    for (var y = rect.top + notch + 6; y < rect.bottom - notch - 6; y += 9) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), dash);
    }
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2), textDirection: textDirection),
      side.toPaint()..style = PaintingStyle.stroke,
    );
  }

  @override
  ShapeBorder scale(double t) =>
      TicketShapeBorder(side: side.scale(t), radius: radius * t, stubWidth: stubWidth * t, notch: notch * t);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is TicketShapeBorder
      ? TicketShapeBorder(
          side: BorderSide.lerp(a.side, side, t),
          radius: ui.lerpDouble(a.radius, radius, t)!,
          stubWidth: ui.lerpDouble(a.stubWidth, stubWidth, t)!,
          notch: ui.lerpDouble(a.notch, notch, t)!,
        )
      : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is TicketShapeBorder
      ? TicketShapeBorder(
          side: BorderSide.lerp(side, b.side, t),
          radius: ui.lerpDouble(radius, b.radius, t)!,
          stubWidth: ui.lerpDouble(stubWidth, b.stubWidth, t)!,
          notch: ui.lerpDouble(notch, b.notch, t)!,
        )
      : super.lerpTo(b, t);

  @override
  bool operator ==(Object other) =>
      other is TicketShapeBorder &&
      other.side == side &&
      other.radius == radius &&
      other.stubWidth == stubWidth &&
      other.notch == notch;

  @override
  int get hashCode => Object.hash(side, radius, stubWidth, notch);
}

/// One row of a day's sessions (D2, the homes): time, patient, type badge,
/// fee, who recorded it, and «بانتظار الطبيب» (BR-AS7).
class DaySessionRow extends StatelessWidget {
  const DaySessionRow({super.key, required this.item, required this.onTap, this.showRecorder = true, this.wide = false});

  final SessionListItem item;
  final VoidCallback? onTap;

  /// "Recorded by" (BR-AS6).
  final bool showRecorder;

  /// Desktop: one line of columns.
  final bool wide;

  static Widget placeholder({bool wide = false}) => DaySessionRow(
        item: SessionListItem(
          sessionId: '',
          at: DateTime.utc(2026, 1, 1, 8),
          day: DateTime.utc(2026),
          type: SessionType.examination,
          patientId: '',
          fileNumber: 12,
          patientName: '———————————',
          branch: const SessionBranch(id: '', nameAr: '————'),
          platformFeePiasters: 3000,
          recordedBy: const RecordedBy(userId: '', name: '————', isAssistant: false),
        ),
        onTap: null,
        wide: wide,
      );

  /// The columns need about this much room; below it the row stacks.
  static const double _columnsWidth = 840;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => _row(context, wide: wide && constraints.maxWidth >= _columnsWidth),
      );

  Widget _row(BuildContext context, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final recorder = item.recordedBy.isAssistant ? item.recordedBy.name : l10n.sessionRecordedByDoctor;
    final time = Text(ClinicFormat.time(context, item.at), style: theme.textTheme.titleSmall);
    final semantics = [
      ClinicFormat.time(context, item.at),
      item.patientName,
      l10n.patientFileNumber('${item.fileNumber}'),
      sessionTypeLabel(l10n, item.type),
      l10n.sessionPlatformFeeShort(AppFormat.egp(context, item.platformFeePiasters)),
      if (showRecorder) l10n.sessionRecordedBy(recorder),
      if (item.awaitingDoctor) l10n.sessionAwaitingDoctor,
    ].join(l10n.adminListSeparator);

    final Widget content;
    if (wide) {
      content = Row(
        children: [
          SizedBox(width: 88, child: time),
          Expanded(
            child: Row(
              children: [
                Flexible(child: Text(item.patientName, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Flexible(child: FileNumberPill(item.fileNumber)),
              ],
            ),
          ),
          SizedBox(width: 110, child: Align(alignment: AlignmentDirectional.centerStart, child: TypeBadge(item.type))),
          SizedBox(width: 96, child: Text(AppFormat.egp(context, item.platformFeePiasters), style: theme.textTheme.bodyMedium)),
          SizedBox(
            width: 128,
            child: Text(item.branch.name(language), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (showRecorder)
            SizedBox(width: 128, child: Text(recorder, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 140,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: item.awaitingDoctor ? const AwaitingDoctorBadge() : const SizedBox.shrink(),
            ),
          ),
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Padding(padding: const EdgeInsets.only(top: 2), child: time)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(item.patientName, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    TypeBadge(item.type),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.sessionPlatformFeeShort(AppFormat.egp(context, item.platformFeePiasters)), style: muted),
                    if (showRecorder) Text(l10n.sessionRecordedBy(recorder), style: muted),
                    if (item.awaitingDoctor) const AwaitingDoctorBadge(),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null) ExcludeSemantics(child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
        ],
      );
    }
    return Semantics(
      button: onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: content),
      ),
    );
  }
}

/// A platform-fee card (D1, D2's footer, the homes): the period, the
/// equation «2 كشف + 3 استشارة = 105 ج.م», and the two sums.
class FeeCard extends StatelessWidget {
  const FeeCard({
    super.key,
    required this.title,
    required this.totals,
    this.onTap,
    this.highlight = false,
    this.footer,
  });

  final String title;
  final FeeTotals totals;
  final VoidCallback? onTap;

  /// Pine surface (today's card); otherwise the white card.
  final bool highlight;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.el3yadaColors;
    final background = highlight ? colors.navBar : scheme.surfaceContainerLow;
    final dark = theme.brightness == Brightness.dark;
    final foreground = highlight ? (dark ? scheme.onSurface : scheme.onPrimary) : scheme.onSurface;
    final soft = highlight ? colors.onNavBar : scheme.onSurfaceVariant;
    final accent = highlight ? colors.navIndicator : scheme.primary;
    final equation = feeEquation(context, totals);

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(child: Icon(Icons.receipt_long_outlined, size: 20, color: accent)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: soft))),
              if (onTap != null) ExcludeSemantics(child: Icon(Icons.chevron_right, color: soft)),
            ],
          ),
          const SizedBox(height: 14),
          _CountUp(
            piasters: totals.totalPiasters,
            style: theme.textTheme.headlineLarge?.copyWith(color: foreground),
          ),
          const SizedBox(height: 6),
          Text(equation, style: theme.textTheme.bodyLarge?.copyWith(color: foreground)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Part(
                label: l10n.feesExaminationsFee(AppFormat.egp(context, totals.examinationFeePiasters)),
                dot: colors.examination,
                color: soft,
              ),
              _Part(
                label: l10n.feesConsultationsFee(AppFormat.egp(context, totals.consultationFeePiasters)),
                dot: colors.consultation,
                color: soft,
              ),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );

    final card = highlight
        ? _GlowCard(dark: dark, base: background, accent: accent, child: body)
        : Material(
            color: background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: body,
          );
    return Semantics(
      label: '$title, $equation',
      button: onTap != null,
      excludeSemantics: true,
      child: onTap == null ? card : Pressable(onTap: onTap, borderRadius: BorderRadius.circular(20), child: card),
    );
  }
}

/// The highlighted fee card's surface: a pine gradient with two soft mint
/// circles in the top end corner and a tinted shadow.
class _GlowCard extends StatelessWidget {
  const _GlowCard({required this.dark, required this.base, required this.accent, required this.child});

  final bool dark;
  final Color base;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(24));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: base.withValues(alpha: dark ? 0.5 : 0.35), blurRadius: 24, spreadRadius: -6, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart.resolve(Directionality.of(context)),
              end: AlignmentDirectional.bottomEnd.resolve(Directionality.of(context)),
              colors: [Color.lerp(base, accent, 0.18)!, base, Color.lerp(base, Colors.black, 0.18)!],
            ),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                end: -40,
                top: -50,
                child: _Circle(size: 160, color: accent.withValues(alpha: 0.12)),
              ),
              PositionedDirectional(
                end: 50,
                top: -70,
                child: _Circle(size: 120, color: accent.withValues(alpha: 0.08)),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      );
}

/// A money amount that counts up to its value when it appears, and from the
/// old value to the new one when it changes. Plain with reduced motion.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.piasters, this.style});

  final int piasters;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (Motion.of(context).reduced) return Text(AppFormat.egp(context, piasters), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: piasters.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => Text(
        AppFormat.egp(context, value.round()),
        style: style?.copyWith(fontFeatures: const [ui.FontFeature.tabularFigures()]),
      ),
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({required this.label, required this.dot, required this.color});

  final String label;
  final Color dot;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            child: const SizedBox.square(dimension: 10),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color))),
        ],
      );
}
