import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
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
            flex: 3,
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
          Expanded(
            flex: 2,
            child: Text(item.branch.name(language), style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (showRecorder)
            Expanded(flex: 2, child: Text(recorder, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 150,
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
          Text(
            AppFormat.egp(context, totals.totalPiasters),
            style: theme.textTheme.displaySmall?.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(equation, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
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

    final card = Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ],
      );
}
