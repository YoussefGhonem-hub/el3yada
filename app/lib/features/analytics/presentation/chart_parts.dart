import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';

/// Colours every chart uses (BR-REV6): examinations blue and consultations
/// green everywhere, and the previous period as a dashed grey line. They come
/// from the theme, so light and dark both work.
class ChartColors {
  const ChartColors._(
    this.examination,
    this.consultation,
    this.neutral,
    this.grid,
    this.label,
    this.highlight,
    this.warning,
  );

  factory ChartColors.of(BuildContext context) {
    final colors = context.el3yadaColors;
    final scheme = Theme.of(context).colorScheme;
    return ChartColors._(
      colors.examination,
      colors.consultation,
      scheme.outline,
      scheme.outlineVariant,
      scheme.onSurfaceVariant,
      scheme.primary,
      scheme.error,
    );
  }

  final Color examination;
  final Color consultation;

  /// The previous period, last year, averages.
  final Color neutral;
  final Color grid;
  final Color label;

  /// The busiest months.
  final Color highlight;

  /// The quietest months, no-shows.
  final Color warning;
}

/// A chart in a card: title, optional subtitle and legend, the chart, and an
/// empty state when there is no data (BR-REV6). [semanticLabel] summarises the
/// chart for screen readers. [onTap] opens the detailed list.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.legend = const [],
    this.empty = false,
    this.semanticLabel,
    this.height = 220,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<LegendItem> legend;
  final bool empty;
  final String? semanticLabel;

  /// Fixed chart height; null lets text-based charts take what they need.
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: empty ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.titleSmall),
                    ),
                  ),
                  if (onTap != null && !empty)
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: empty ? (height ?? 90) : height,
                child: empty
                    ? Center(
                        child: Text(
                          l10n.anaNoData,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Semantics(
                        label: semanticLabel ?? title,
                        child: ExcludeSemantics(child: child),
                      ),
              ),
              if (legend.isNotEmpty && !empty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [for (final item in legend) item],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A colour key under a chart: a swatch and its label (never colour alone).
class LegendItem extends StatelessWidget {
  const LegendItem({
    super.key,
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      dashed
          ? SizedBox(
              width: 16,
              height: 10,
              child: CustomPaint(painter: _DashPainter(color)),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const SizedBox(width: 12, height: 12),
            ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 6) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + 3).clamp(0, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Axis titles with no top and right labels.
FlTitlesData titles({
  required BuildContext context,
  required String Function(double value) left,
  required String Function(int index) bottom,
  required int count,
  double leftSize = 44,
}) {
  final style = Theme.of(context).textTheme.labelSmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
  // At most 6 labels along the bottom, whatever the number of points.
  final step = (count / 6).ceil().clamp(1, 1 << 20);
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: leftSize,
        getTitlesWidget: (value, meta) =>
            value == meta.max || value == meta.min && value != 0
            ? const SizedBox.shrink()
            : SideTitleWidget(
                meta: meta,
                child: Text(left(value), style: style),
              ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 26,
        interval: 1,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (value != index.toDouble() ||
              index < 0 ||
              index >= count ||
              index % step != 0) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            child: Text(bottom(index), style: style),
          );
        },
      ),
    ),
  );
}

/// A short number: 1.2K, 3.4M (axis labels).
String compact(double value) {
  final abs = value.abs();
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(abs >= 10000000 ? 0 : 1)}M';
  }
  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}K';
  }
  return value.round().toString();
}

FlGridData gridData(Color color) => FlGridData(
  show: true,
  drawVerticalLine: false,
  getDrawingHorizontalLine: (value) => FlLine(color: color, strokeWidth: 1),
);

/// A heading over a group of charts on the dashboard.
class ChartSectionTitle extends StatelessWidget {
  const ChartSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// «اضغط للتفاصيل»-style hint is not needed: the card shows a chevron. This
/// wraps an error from the charts area.
class ChartsError extends StatelessWidget {
  const ChartsError({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) =>
      AdminErrorView(error: error, onRetry: onRetry);
}
