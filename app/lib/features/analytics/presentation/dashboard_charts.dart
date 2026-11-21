import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart' show ClinicFormat;
import '../domain/analytics_models.dart';
import 'chart_parts.dart';

/// The charts C1–C12 of D1 (spec 6.14, BR-REV6). A chart whose data the caller
/// may not see isn't drawn; one without data says so. Colours follow the
/// theme and keep their meaning: examinations blue, consultations green, the
/// previous period dashed.
class DashboardCharts extends ConsumerWidget {
  const DashboardCharts({
    super.key,
    required this.dashboard,
    required this.width,
  });

  final Dashboard dashboard;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    final d = dashboard;
    final language = Localizations.localeOf(context).languageCode;
    final wide = width >= 900;

    final charts = <Widget>[
      if (d.revenueSeries != null)
        _RevenueChart(
          points: d.revenueSeries!,
          bucket: d.period.bucket,
          compare: d.period.compare,
        ),
      if (d.visitsSeries != null)
        _VisitsChart(points: d.visitsSeries!, bucket: d.period.bucket),
      if (d.patientsPerWeek != null)
        _PatientsPerWeekChart(data: d.patientsPerWeek!),
      if (d.months != null) _MonthsChart(months: d.months!),
      if (d.heatmap != null) _Heatmap(grid: d.heatmap!),
      if (d.newVsReturning != null)
        _NewReturningChart(points: d.newVsReturning!),
      if (d.typeSplit != null) _TypeSplitChart(split: d.typeSplit!),
      if (d.branches != null)
        _BranchesChart(branches: d.branches!, language: language),
      if (d.funnel != null) _FunnelChart(funnel: d.funnel!),
      if (d.sources != null) _SourcesChart(points: d.sources!),
      if (d.notSeen != null)
        _NotSeenChart(
          buckets: d.notSeen!,
          onTap: (bucket) =>
              context.go('${paths.patients}?lastVisit=${bucket.filter}'),
        ),
      if (d.waitingTimes != null && d.waitingTimes!.isNotEmpty)
        _WaitChart(points: d.waitingTimes!),
    ];
    if (charts.isEmpty) return const SizedBox.shrink();

    final items = [
      for (final (i, chart) in charts.indexed)
        StaggeredEntrance(index: i + 3, child: chart),
    ];
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: item),
        ],
      );
    }
    // Two columns on wide screens, each card as tall as its content.
    final left = <Widget>[for (var i = 0; i < items.length; i += 2) items[i]];
    final right = <Widget>[for (var i = 1; i < items.length; i += 2) items[i]];
    Widget column(List<Widget> cards) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final card in cards)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [column(left), const SizedBox(width: 12), column(right)],
    );
  }
}

String _bucketLabel(BuildContext context, DateTime date, String bucket) =>
    bucket == 'month'
    ? ClinicFormat.month(context, date)
    : ClinicFormat.dayShort(context, date);

String _monthShort(BuildContext context, String monthKey) {
  final parts = monthKey.split('-');
  return ClinicFormat.month(
    context,
    DateTime.utc(int.parse(parts[0]), int.parse(parts[1])),
  ).split(' ').first;
}

// ---- C1 ---------------------------------------------------------------------------------------

/// C1: revenue per day, week or month, split by visit type, with the previous period dashed.
class _RevenueChart extends StatelessWidget {
  const _RevenueChart({
    required this.points,
    required this.bucket,
    required this.compare,
  });

  final List<RevenuePoint> points;
  final String bucket;
  final bool compare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final empty = points.every((p) => p.total == 0);
    final maxY = [
      for (final p in points) ...[
        p.total.toDouble(),
        (p.previousTotalPiasters ?? 0).toDouble(),
      ],
    ].fold<double>(0, (a, b) => a > b ? a : b);
    final top = maxY == 0 ? 1.0 : maxY * 1.15;
    List<FlSpot> spots(double Function(RevenuePoint) value) => [
      for (final (i, p) in points.indexed) FlSpot(i.toDouble(), value(p)),
    ];
    return ChartCard(
      title: l10n.anaC1Title,
      subtitle: l10n.anaC1Subtitle,
      empty: empty,
      legend: [
        LegendItem(
          color: colors.examination,
          label: l10n.sessionTypeExamination,
        ),
        LegendItem(
          color: colors.consultation,
          label: l10n.sessionTypeConsultation,
        ),
        if (compare)
          LegendItem(
            color: colors.neutral,
            label: l10n.anaPreviousPeriod,
            dashed: true,
          ),
      ],
      semanticLabel: l10n.anaC1Summary(
        AppFormat.egp(context, points.fold(0, (sum, p) => sum + p.total)),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: top,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v / 100),
            bottom: (i) => _bucketLabel(context, points[i].date, bucket),
            count: points.length,
          ),
          lineBarsData: [
            // The total first (consultation green below the line), then the examinations over it.
            LineChartBarData(
              spots: spots((p) => p.total.toDouble()),
              isCurved: false,
              color: colors.consultation,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colors.consultation.withValues(alpha: 0.28),
              ),
            ),
            LineChartBarData(
              spots: spots((p) => p.examinationPiasters.toDouble()),
              isCurved: false,
              color: colors.examination,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colors.examination.withValues(alpha: 0.4),
              ),
            ),
            if (compare)
              LineChartBarData(
                spots: [
                  for (final (i, p) in points.indexed)
                    if (p.previousTotalPiasters != null)
                      FlSpot(i.toDouble(), p.previousTotalPiasters!.toDouble()),
                ],
                color: colors.neutral,
                barWidth: 2,
                dashArray: const [6, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) {
                final p = points[touched.first.x.round()];
                final text =
                    '${_bucketLabel(context, p.date, bucket)}\n'
                    '${l10n.sessionTypeExamination}: ${AppFormat.egp(context, p.examinationPiasters)}\n'
                    '${l10n.sessionTypeConsultation}: ${AppFormat.egp(context, p.consultationPiasters)}'
                    '${p.previousTotalPiasters == null ? '' : '\n${l10n.anaPreviousPeriod}: ${AppFormat.egp(context, p.previousTotalPiasters!)}'}';
                return [
                  for (var i = 0; i < touched.length; i++)
                    i == 0
                        ? LineTooltipItem(
                            text,
                            Theme.of(context).textTheme.bodySmall!.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
                            ),
                          )
                        : null,
                ];
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---- C2 ---------------------------------------------------------------------------------------

/// C2: visits per bucket, examinations and consultations stacked.
class _VisitsChart extends StatelessWidget {
  const _VisitsChart({required this.points, required this.bucket});

  final List<VisitsPoint> points;
  final String bucket;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final maxY = points.fold<int>(0, (a, p) => p.total > a ? p.total : a);
    return ChartCard(
      title: l10n.anaC2Title,
      empty: maxY == 0,
      legend: [
        LegendItem(
          color: colors.examination,
          label: l10n.sessionTypeExamination,
        ),
        LegendItem(
          color: colors.consultation,
          label: l10n.sessionTypeConsultation,
        ),
      ],
      semanticLabel: l10n.anaC2Summary(
        points.fold(0, (sum, p) => sum + p.total),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v),
            bottom: (i) => _bucketLabel(context, points[i].date, bucket),
            count: points.length,
            leftSize: 32,
          ),
          barGroups: [
            for (final (i, p) in points.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: p.total.toDouble(),
                    width: points.length > 20 ? 5 : 12,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        p.examinations.toDouble(),
                        colors.examination,
                      ),
                      BarChartRodStackItem(
                        p.examinations.toDouble(),
                        p.total.toDouble(),
                        colors.consultation,
                      ),
                    ],
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final p = points[group.x];
                return BarTooltipItem(
                  '${_bucketLabel(context, p.date, bucket)}\n${l10n.sessionTypeExamination}: ${p.examinations}\n${l10n.sessionTypeConsultation}: ${p.consultations}',
                  Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---- C3 ---------------------------------------------------------------------------------------

/// C3: unique patients each week, with the weekly average as a line.
class _PatientsPerWeekChart extends StatelessWidget {
  const _PatientsPerWeekChart({required this.data});

  final WeeklyPatients data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final weeks = data.weeks;
    final maxY = weeks.fold<int>(0, (a, w) => w.patients > a ? w.patients : a);
    return ChartCard(
      title: l10n.anaC3Title,
      empty: maxY == 0,
      legend: [
        LegendItem(color: colors.highlight, label: l10n.anaPatientsPerWeek),
        LegendItem(
          color: colors.neutral,
          label: l10n.anaWeeklyAverageLine(data.average.toStringAsFixed(1)),
          dashed: true,
        ),
      ],
      semanticLabel: l10n.anaC3Summary(data.average.toStringAsFixed(1)),
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.2,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v),
            bottom: (i) => ClinicFormat.dayShort(context, weeks[i].weekStart),
            count: weeks.length,
            leftSize: 32,
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: data.average,
                color: colors.neutral,
                strokeWidth: 2,
                dashArray: const [6, 4],
              ),
            ],
          ),
          barGroups: [
            for (final (i, w) in weeks.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: w.patients.toDouble(),
                    color: colors.highlight,
                    width: weeks.length > 20 ? 6 : 14,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${l10n.anaWeekOf(ClinicFormat.dayShort(context, weeks[group.x].weekStart))}\n${l10n.anaPatientsCount(weeks[group.x].patients)}',
                Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- C4 ---------------------------------------------------------------------------------------

/// C4: visits per month for the last 12 months; the 3 busiest and 3 quietest are highlighted, last year beside them.
class _MonthsChart extends StatelessWidget {
  const _MonthsChart({required this.months});

  final List<MonthPoint> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final maxY = months.fold<int>(
      0,
      (a, m) => [a, m.visits, m.lastYearVisits].reduce((x, y) => x > y ? x : y),
    );
    final hasLastYear = months.any((m) => m.lastYearVisits > 0);
    return ChartCard(
      title: l10n.anaC4Title,
      subtitle: l10n.anaC4Subtitle,
      empty: maxY == 0,
      legend: [
        LegendItem(color: colors.highlight, label: l10n.anaBusiest),
        LegendItem(color: colors.warning, label: l10n.anaQuietest),
        LegendItem(color: colors.examination, label: l10n.anaThisYear),
        if (hasLastYear)
          LegendItem(color: colors.neutral, label: l10n.anaLastYear),
      ],
      semanticLabel: l10n.anaC4Summary,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.2,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v),
            bottom: (i) => _monthShort(context, months[i].monthKey),
            count: months.length,
            leftSize: 32,
          ),
          barGroups: [
            for (final (i, m) in months.indexed)
              BarChartGroupData(
                x: i,
                barsSpace: 2,
                barRods: [
                  BarChartRodData(
                    toY: m.visits.toDouble(),
                    width: hasLastYear ? 9 : 14,
                    color: m.busiest
                        ? colors.highlight
                        : (m.quietest ? colors.warning : colors.examination),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  if (hasLastYear)
                    BarChartRodData(
                      toY: m.lastYearVisits.toDouble(),
                      width: 5,
                      color: colors.neutral.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final m = months[group.x];
                return BarTooltipItem(
                  '${ClinicFormat.month(context, m.month)}\n${l10n.anaVisitsCount(m.visits)}${hasLastYear ? '\n${l10n.anaLastYear}: ${m.lastYearVisits}' : ''}',
                  Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---- C5 ---------------------------------------------------------------------------------------

/// C5: visits by weekday (Saturday first) and hour: a heatmap of squares.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.grid});

  final List<List<int>> grid;

  static final _hours = [for (var h = 7; h <= 22; h++) h];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = ChartColors.of(context);
    final days = [
      l10n.anaSat,
      l10n.anaSun,
      l10n.anaMon,
      l10n.anaTue,
      l10n.anaWed,
      l10n.anaThu,
      l10n.anaFri,
    ];
    final peak = grid.fold<int>(
      0,
      (a, row) => row.fold(a, (b, cell) => cell > b ? cell : b),
    );
    return ChartCard(
      title: l10n.anaC5Title,
      subtitle: l10n.anaC5Subtitle,
      empty: peak == 0,
      height: 7 * 28.0 + 48,
      semanticLabel: l10n.anaC5Summary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const labelWidth = 44.0;
          final cell = ((constraints.maxWidth - labelWidth) / _hours.length)
              .floorToDouble();
          return Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: labelWidth),
                  for (final hour in _hours)
                    SizedBox(
                      width: cell,
                      child: hour.isEven
                          ? Text(
                              '$hour',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.label,
                                fontSize: 9,
                              ),
                            )
                          : null,
                    ),
                ],
              ),
              for (var d = 0; d < 7; d++)
                Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      height: 28,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(days[d], style: theme.textTheme.labelSmall),
                      ),
                    ),
                    for (final hour in _hours)
                      Tooltip(
                        message: l10n.anaHeatCell(days[d], hour, grid[d][hour]),
                        child: Container(
                          width: cell - 2,
                          height: 24,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              colors.grid.withValues(alpha: 0.35),
                              colors.highlight,
                              peak == 0 ? 0 : grid[d][hour] / peak,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---- C6 ---------------------------------------------------------------------------------------

class _NewReturningChart extends StatelessWidget {
  const _NewReturningChart({required this.points});

  final List<NewReturningPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final maxY = points.fold<int>(
      0,
      (a, p) =>
          p.newPatients + p.returning > a ? p.newPatients + p.returning : a,
    );
    return ChartCard(
      title: l10n.anaC6Title,
      empty: maxY == 0,
      legend: [
        LegendItem(color: colors.highlight, label: l10n.anaNewPatients),
        LegendItem(color: colors.neutral, label: l10n.anaReturningPatients),
      ],
      semanticLabel: l10n.anaC6Summary,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v),
            bottom: (i) => _monthShort(context, points[i].monthKey),
            count: points.length,
            leftSize: 32,
          ),
          barGroups: [
            for (final (i, p) in points.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (p.newPatients + p.returning).toDouble(),
                    width: 16,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        p.returning.toDouble(),
                        colors.neutral.withValues(alpha: 0.7),
                      ),
                      BarChartRodStackItem(
                        p.returning.toDouble(),
                        (p.newPatients + p.returning).toDouble(),
                        colors.highlight,
                      ),
                    ],
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${l10n.anaNewPatients}: ${points[group.x].newPatients}\n${l10n.anaReturningPatients}: ${points[group.x].returning}',
                Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- C7 ---------------------------------------------------------------------------------------

/// C7: the share of examinations and consultations, by count and by revenue, as 100% bars.
class _TypeSplitChart extends StatelessWidget {
  const _TypeSplitChart({required this.split});

  final TypeSplit split;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final total = split.examinations + split.consultations;
    Widget bar(
      String label,
      int exam,
      int consultation,
      String Function(int) format,
    ) {
      final sum = exam + consultation;
      final share = sum == 0 ? 0.0 : exam / sum;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 28,
              child: Row(
                children: [
                  Expanded(
                    flex: (share * 1000).round(),
                    child: ColoredBox(color: colors.examination),
                  ),
                  Expanded(
                    flex: 1000 - (share * 1000).round(),
                    child: ColoredBox(color: colors.consultation),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(
                '${l10n.sessionTypeExamination}: ${format(exam)} (${(share * 100).round()}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '${l10n.sessionTypeConsultation}: ${format(consultation)} (${sum == 0 ? 0 : 100 - (share * 100).round()}%)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      );
    }

    return ChartCard(
      title: l10n.anaC7Title,
      empty: total == 0,
      height: null,
      semanticLabel: l10n.anaC7Summary(split.examinations, split.consultations),
      child: Column(
        children: [
          bar(
            l10n.anaByCount,
            split.examinations,
            split.consultations,
            (v) => '$v',
          ),
          if (split.examinationRevenue != null &&
              split.consultationRevenue != null) ...[
            const SizedBox(height: 16),
            bar(
              l10n.anaByRevenue,
              split.examinationRevenue!,
              split.consultationRevenue!,
              (v) => AppFormat.egp(context, v),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- C8 ---------------------------------------------------------------------------------------

/// C8: revenue and visits per branch (two or more branches).
class _BranchesChart extends StatelessWidget {
  const _BranchesChart({required this.branches, required this.language});

  final List<BranchPoint> branches;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final theme = Theme.of(context);
    final maxVisits = branches.fold<int>(
      0,
      (a, b) => b.visits > a ? b.visits : a,
    );
    return ChartCard(
      title: l10n.anaC8Title,
      empty: maxVisits == 0,
      height: null,
      semanticLabel: l10n.anaC8Summary,
      child: Column(
        children: [
          for (final branch in branches)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          branch.name(language),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          branch.revenuePiasters == null
                              ? l10n.anaVisitsCount(branch.visits)
                              : '${l10n.anaVisitsCount(branch.visits)} · ${AppFormat.egp(context, branch.revenuePiasters!)}',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: maxVisits == 0 ? 0 : branch.visits / maxVisits,
                      minHeight: 12,
                      color: colors.highlight,
                      backgroundColor: colors.grid.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---- C9 ---------------------------------------------------------------------------------------

/// C9: the bookings funnel (booked → arrived → seen) and the weekly no-shows and cancellations.
class _FunnelChart extends StatelessWidget {
  const _FunnelChart({required this.funnel});

  final Funnel funnel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final theme = Theme.of(context);
    final stages = [
      (l10n.anaFunnelBooked, funnel.booked),
      (l10n.anaFunnelArrived, funnel.arrived),
      (l10n.anaFunnelSeen, funnel.seen),
    ];
    final weeks = funnel.weeks;
    final maxWeek = weeks.fold<int>(
      0,
      (a, w) => [a, w.noShows, w.cancellations].reduce((x, y) => x > y ? x : y),
    );
    return ChartCard(
      title: l10n.anaC9Title,
      empty: funnel.booked == 0 && weeks.isEmpty,
      height: 120 + (weeks.isEmpty ? 0 : 150),
      legend: [
        if (weeks.isNotEmpty) ...[
          LegendItem(color: colors.warning, label: l10n.anaNoShows),
          LegendItem(color: colors.neutral, label: l10n.anaCancellations),
        ],
      ],
      semanticLabel: l10n.anaC9Summary(
        funnel.booked,
        funnel.arrived,
        funnel.seen,
      ),
      child: Column(
        children: [
          for (final (i, stage) in stages.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(stage.$1, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: funnel.booked == 0
                            ? 0
                            : stage.$2 / funnel.booked,
                        minHeight: 16,
                        color: Color.lerp(
                          colors.highlight,
                          colors.consultation,
                          i / 2,
                        ),
                        backgroundColor: colors.grid.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${stage.$2}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          if (weeks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxWeek == 0 ? 1 : maxWeek * 1.3,
                  gridData: gridData(colors.grid),
                  borderData: FlBorderData(show: false),
                  titlesData: titles(
                    context: context,
                    left: (v) => compact(v),
                    bottom: (i) =>
                        ClinicFormat.dayShort(context, weeks[i].weekStart),
                    count: weeks.length,
                    leftSize: 28,
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (final (i, w) in weeks.indexed)
                          FlSpot(i.toDouble(), w.noShows.toDouble()),
                      ],
                      color: colors.warning,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: [
                        for (final (i, w) in weeks.indexed)
                          FlSpot(i.toDouble(), w.cancellations.toDouble()),
                      ],
                      color: colors.neutral,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touched) => [
                        for (final spot in touched)
                          LineTooltipItem(
                            '${spot.barIndex == 0 ? l10n.anaNoShows : l10n.anaCancellations}: ${spot.y.round()}',
                            theme.textTheme.bodySmall!.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- C10 --------------------------------------------------------------------------------------

class _SourcesChart extends StatelessWidget {
  const _SourcesChart({required this.points});

  final List<SourcePoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final maxY = points.fold<int>(
      0,
      (a, p) => p.app + p.staff + p.walkIn > a ? p.app + p.staff + p.walkIn : a,
    );
    return ChartCard(
      title: l10n.anaC10Title,
      empty: maxY == 0,
      legend: [
        LegendItem(color: colors.highlight, label: l10n.anaSourceApp),
        LegendItem(color: colors.examination, label: l10n.anaSourceStaff),
        LegendItem(color: colors.neutral, label: l10n.anaSourceWalkIn),
      ],
      semanticLabel: l10n.anaC10Summary,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v),
            bottom: (i) => _monthShort(context, points[i].monthKey),
            count: points.length,
            leftSize: 32,
          ),
          barGroups: [
            for (final (i, p) in points.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (p.app + p.staff + p.walkIn).toDouble(),
                    width: 16,
                    borderRadius: BorderRadius.circular(3),
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        p.app.toDouble(),
                        colors.highlight,
                      ),
                      BarChartRodStackItem(
                        p.app.toDouble(),
                        (p.app + p.staff).toDouble(),
                        colors.examination,
                      ),
                      BarChartRodStackItem(
                        (p.app + p.staff).toDouble(),
                        (p.app + p.staff + p.walkIn).toDouble(),
                        colors.neutral,
                      ),
                    ],
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final p = points[group.x];
                return BarTooltipItem(
                  '${l10n.anaSourceApp}: ${p.app}\n${l10n.anaSourceStaff}: ${p.staff}\n${l10n.anaSourceWalkIn}: ${p.walkIn}',
                  Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---- C11 --------------------------------------------------------------------------------------

/// C11: patients not seen for 3, 6 or 12+ months. Tap a bar to open the register (D4) with that filter.
class _NotSeenChart extends StatelessWidget {
  const _NotSeenChart({required this.buckets, required this.onTap});

  final List<NotSeenBucket> buckets;
  final ValueChanged<NotSeenBucket> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final theme = Theme.of(context);
    final maxY = buckets.fold<int>(
      0,
      (a, b) => b.patients > a ? b.patients : a,
    );
    return ChartCard(
      title: l10n.anaC11Title,
      subtitle: l10n.anaC11Subtitle,
      empty: maxY == 0,
      height: buckets.length * 52.0,
      semanticLabel: l10n.anaC11Summary,
      child: Column(
        children: [
          for (final bucket in buckets)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onTap(bucket),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          bucket.months == 12
                              ? l10n.anaNotSeen12
                              : l10n.anaNotSeenMonths(bucket.months),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: maxY == 0 ? 0 : bucket.patients / maxY,
                            minHeight: 18,
                            color: colors.warning,
                            backgroundColor: colors.grid.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${bucket.patients}',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: colors.label),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- C12 --------------------------------------------------------------------------------------

class _WaitChart extends StatelessWidget {
  const _WaitChart({required this.points});

  final List<WaitPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final maxY = points.fold<double>(
      0,
      (a, p) => p.minutes > a ? p.minutes : a,
    );
    return ChartCard(
      title: l10n.anaC12Title,
      empty: maxY == 0,
      semanticLabel: l10n.anaC12Summary,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.25,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v),
            bottom: (i) => ClinicFormat.dayShort(context, points[i].date),
            count: points.length,
            leftSize: 32,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (final (i, p) in points.indexed)
                  FlSpot(i.toDouble(), p.minutes),
              ],
              isCurved: true,
              color: colors.highlight,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colors.highlight.withValues(alpha: 0.15),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touched) => [
                for (final spot in touched)
                  LineTooltipItem(
                    '${ClinicFormat.dayShort(context, points[spot.x.round()].date)}: ${l10n.anaMinutes(spot.y.toStringAsFixed(1))}',
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
