import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../billing/presentation/billing_widgets.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/analytics_providers.dart';
import '../domain/analytics_models.dart';
import 'dashboard_charts.dart';

/// The analytics half of D1 / AS18 (spec 6.14): the filter bar, the KPI tiles,
/// the insights and the charts C1–C12 for the chosen period, branch and visit
/// type. Anything the caller may not see is hidden, not zero (BR-REV1).
class AnalyticsSection extends ConsumerWidget {
  const AnalyticsSection({
    super.key,
    required this.clinic,
    required this.width,
  });

  final ClinicContext clinic;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(analyticsFilterProvider);
    final dashboard = ref.watch(dashboardProvider);
    final paths = ref.watch(clinicPathsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterBar(
          clinic: clinic,
          filter: filter,
          onChanged: ref.read(analyticsFilterProvider.notifier).set,
        ),
        const SizedBox(height: 16),
        AsyncStateSwitcher<Dashboard>(
          value: dashboard,
          loading: (context) => SkeletonLoading(
            loading: true,
            child: _Tiles(
              tiles: _placeholderTiles,
              access: const DashboardAccess(
                revenue: true,
                patients: true,
                billing: true,
              ),
              compare: false,
              width: width,
            ),
          ),
          error: (context, error) => AdminErrorView(
            error: error,
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (context, data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.invoice case final invoice?) ...[
                StaggeredEntrance(
                  index: 0,
                  child: _InvoiceCard(card: invoice, paths: paths),
                ),
                const SizedBox(height: 16),
              ],
              StaggeredEntrance(
                index: 1,
                child: _Tiles(
                  tiles: data.tiles,
                  access: data.access,
                  compare: data.period.compare,
                  width: width,
                ),
              ),
              if (data.insights.isNotEmpty) ...[
                const SizedBox(height: 16),
                StaggeredEntrance(
                  index: 2,
                  child: _Insights(insights: data.insights, paths: paths),
                ),
              ],
              const SizedBox(height: 16),
              DashboardCharts(dashboard: data, width: width),
            ],
          ),
        ),
      ],
    );
  }

  static const _placeholderTiles = DashboardTiles(
    revenue: Tile(value: 1250000),
    netIncome: Tile(value: 1100000),
    platformFees: Tile(value: 150000),
    visits: Tile(value: 120),
    uniquePatients: Tile(value: 90),
    newPatients: Tile(value: 14),
    weeklyAveragePatients: Tile(value: 22),
    averageRevenuePerVisit: Tile(value: 20000),
    noShowRate: Tile(value: 12),
    appShare: Tile(value: 35),
  );
}

// ---- The filter bar ------------------------------------------------------------------------

String presetLabel(AppLocalizations l10n, PeriodPreset preset) =>
    switch (preset) {
      PeriodPreset.today => l10n.anaPresetToday,
      PeriodPreset.yesterday => l10n.anaPresetYesterday,
      PeriodPreset.thisWeek => l10n.anaPresetThisWeek,
      PeriodPreset.lastWeek => l10n.anaPresetLastWeek,
      PeriodPreset.thisMonth => l10n.anaPresetThisMonth,
      PeriodPreset.lastMonth => l10n.anaPresetLastMonth,
      PeriodPreset.last3Months => l10n.anaPresetLast3Months,
      PeriodPreset.last6Months => l10n.anaPresetLast6Months,
      PeriodPreset.thisYear => l10n.anaPresetThisYear,
      PeriodPreset.lastYear => l10n.anaPresetLastYear,
      PeriodPreset.custom => l10n.anaPresetCustom,
    };

/// Period, branch, visit type and compare (BR-REV2, BR-REV3, BR-REV4).
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.clinic,
    required this.filter,
    required this.onChanged,
  });

  final ClinicContext clinic;
  final AnalyticsFilter filter;
  final ValueChanged<AnalyticsFilter> onChanged;

  Future<void> _pickRange(BuildContext context) async {
    final today = ClinicFormat.today();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(today.year - 3),
      lastDate: today,
      initialDateRange: filter.from != null && filter.to != null
          ? DateTimeRange(start: filter.from!, end: filter.to!)
          : null,
    );
    if (range == null) return;
    onChanged(
      filter.copyWith(
        preset: PeriodPreset.custom,
        from: DateTime.utc(
          range.start.year,
          range.start.month,
          range.start.day,
        ),
        to: DateTime.utc(range.end.year, range.end.month, range.end.day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final branches = clinic.branches
        .where((b) => b.assigned && b.status != 'archived')
        .toList();
    final presetLabelText =
        filter.preset == PeriodPreset.custom &&
            filter.from != null &&
            filter.to != null
        ? '${ClinicFormat.dayAuto(context, filter.from!)} – ${ClinicFormat.dayAuto(context, filter.to!)}'
        : presetLabel(l10n, filter.preset);
    return ClinicChips(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PopupMenuButton<PeriodPreset>(
            tooltip: l10n.anaPeriod,
            initialValue: filter.preset,
            onSelected: (preset) {
              if (preset == PeriodPreset.custom) {
                _pickRange(context);
              } else {
                onChanged(filter.copyWith(preset: preset));
              }
            },
            itemBuilder: (context) => [
              for (final preset in PeriodPreset.values)
                PopupMenuItem(
                  value: preset,
                  child: Text(presetLabel(l10n, preset)),
                ),
            ],
            child: Chip(
              avatar: const Icon(Icons.date_range_outlined, size: 18),
              label: Text(presetLabelText),
              deleteIcon: const Icon(Icons.arrow_drop_down),
              onDeleted: null,
            ),
          ),
          if (branches.length > 1) ...[
            ChoiceChip(
              label: Text(l10n.patientFilterAllBranches),
              selected: filter.branchId == null,
              onSelected: (_) => onChanged(filter.copyWith(branchId: null)),
            ),
            for (final branch in branches)
              ChoiceChip(
                label: Text(branch.name(language)),
                selected: filter.branchId == branch.id,
                onSelected: (_) =>
                    onChanged(filter.copyWith(branchId: branch.id)),
              ),
          ],
          ChoiceChip(
            label: Text(l10n.anaAllTypes),
            selected: filter.type == null,
            onSelected: (_) => onChanged(filter.copyWith(type: null)),
          ),
          ChoiceChip(
            label: Text(l10n.sessionTypeExamination),
            selected: filter.type == SessionType.examination,
            onSelected: (_) =>
                onChanged(filter.copyWith(type: SessionType.examination)),
          ),
          ChoiceChip(
            label: Text(l10n.sessionTypeConsultation),
            selected: filter.type == SessionType.consultation,
            onSelected: (_) =>
                onChanged(filter.copyWith(type: SessionType.consultation)),
          ),
          FilterChip(
            label: Text(l10n.anaCompare),
            selected: filter.compare,
            onSelected: (value) => onChanged(filter.copyWith(compare: value)),
          ),
        ],
      ),
    );
  }
}

// ---- KPI tiles -----------------------------------------------------------------------------

/// How a tile's value is written.
enum TileFormat { money, count, percent, minutes, decimal }

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.tiles,
    required this.access,
    required this.compare,
    required this.width,
  });

  final DashboardTiles tiles;
  final DashboardAccess access;
  final bool compare;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <Widget>[
      if (tiles.revenue != null)
        KpiTile(
          title: l10n.anaTileRevenue,
          tile: tiles.revenue!,
          format: TileFormat.money,
          compare: compare,
          icon: Icons.payments_outlined,
        ),
      if (tiles.netIncome != null)
        KpiTile(
          title: l10n.anaTileNet,
          tile: tiles.netIncome!,
          format: TileFormat.money,
          compare: compare,
          icon: Icons.savings_outlined,
        ),
      if (tiles.platformFees != null)
        KpiTile(
          title: l10n.anaTileFees,
          tile: tiles.platformFees!,
          format: TileFormat.money,
          compare: compare,
          icon: Icons.receipt_long_outlined,
          invertChange: true,
        ),
      if (tiles.visits != null)
        KpiTile(
          title: l10n.anaTileVisits,
          tile: tiles.visits!,
          format: TileFormat.count,
          compare: compare,
          icon: Icons.medical_services_outlined,
          caption: tiles.examinations == null || tiles.consultations == null
              ? null
              : l10n.anaTileVisitsSplit(
                  tiles.examinations!.value.round(),
                  tiles.consultations!.value.round(),
                ),
        ),
      if (tiles.uniquePatients != null)
        KpiTile(
          title: l10n.anaTilePatients,
          tile: tiles.uniquePatients!,
          format: TileFormat.count,
          compare: compare,
          icon: Icons.groups_outlined,
        ),
      if (tiles.newPatients != null)
        KpiTile(
          title: l10n.anaTileNewPatients,
          tile: tiles.newPatients!,
          format: TileFormat.count,
          compare: compare,
          icon: Icons.person_add_alt_outlined,
        ),
      if (tiles.weeklyAveragePatients != null)
        KpiTile(
          title: l10n.anaTileWeeklyAverage,
          tile: tiles.weeklyAveragePatients!,
          format: TileFormat.decimal,
          compare: compare,
          icon: Icons.date_range_outlined,
        ),
      if (tiles.averageRevenuePerVisit != null)
        KpiTile(
          title: l10n.anaTileAveragePerVisit,
          tile: tiles.averageRevenuePerVisit!,
          format: TileFormat.money,
          compare: compare,
          icon: Icons.calculate_outlined,
        ),
      if (tiles.noShowRate != null)
        KpiTile(
          title: l10n.anaTileNoShow,
          tile: tiles.noShowRate!,
          format: TileFormat.percent,
          compare: compare,
          icon: Icons.event_busy_outlined,
          invertChange: true,
        ),
      if (tiles.appShare != null)
        KpiTile(
          title: l10n.anaTileAppShare,
          tile: tiles.appShare!,
          format: TileFormat.percent,
          compare: compare,
          icon: Icons.phone_android_outlined,
        ),
      if (tiles.averageWaitMinutes != null)
        KpiTile(
          title: l10n.anaTileWait,
          tile: tiles.averageWaitMinutes!,
          format: TileFormat.minutes,
          compare: compare,
          icon: Icons.hourglass_bottom_outlined,
          invertChange: true,
        ),
    ];
    final columns = width >= 1100 ? 4 : (width >= 720 ? 3 : 2);
    const gap = 12.0;
    final tileWidth = (width - gap * (columns - 1)) / columns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final item in items)
          SizedBox(width: tileWidth.floorToDouble() - 1, child: item),
      ],
    );
  }
}

/// One KPI tile: the value, its change against the previous period (↑ / ↓ and
/// %, BR-REV4) and a caption. [invertChange]: lower is better (fees, no-shows).
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.title,
    required this.tile,
    required this.format,
    required this.compare,
    required this.icon,
    this.caption,
    this.invertChange = false,
  });

  final String title;
  final Tile tile;
  final TileFormat format;
  final bool compare;
  final IconData icon;
  final String? caption;
  final bool invertChange;

  String _value(BuildContext context, double value) {
    final l10n = AppLocalizations.of(context);
    return switch (format) {
      TileFormat.money => AppFormat.egp(context, value.round()),
      TileFormat.count => value.round().toString(),
      TileFormat.percent => l10n.anaPercent(_one(value)),
      TileFormat.minutes => l10n.anaMinutes(_one(value)),
      TileFormat.decimal => _one(value),
    };
  }

  static String _one(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final change = compare ? tile.changePct : null;
    final better = change == null
        ? null
        : (invertChange ? change <= 0 : change >= 0);
    return Semantics(
      container: true,
      label:
          '$title: ${_value(context, tile.value)}${change == null ? '' : ', ${l10n.anaChangeSemantics(_one(change.abs()), change >= 0 ? l10n.anaUp : l10n.anaDown)}'}',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: LtrText(
                    _value(context, tile.value),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                if (change != null)
                  _ChangeChip(change: change, better: better!)
                else if (compare && tile.previous != null)
                  Text(
                    l10n.anaNoChange,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (change != null && caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      caption!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
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

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.change, required this.better});

  final double change;
  final bool better;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = change == 0
        ? scheme.onSurfaceVariant
        : (better ? scheme.primary : scheme.error);
    final up = change > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          change == 0
              ? Icons.remove
              : (up ? Icons.arrow_upward : Icons.arrow_downward),
          size: 14,
          color: color,
        ),
        const SizedBox(width: 2),
        LtrText(
          '${KpiTile._one(change.abs())}%',
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ---- Invoice card and insights ------------------------------------------------------------

/// D1's invoice card: the invoice to pay (or the one under review) with a countdown and Pay (needs `billingView`).
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.card, required this.paths});

  final InvoiceCard card;
  final ClinicPaths paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final urgent =
        card.status.name == 'overdue' ||
        card.status.name == 'rejected' ||
        card.daysLeft <= 2;
    return Card(
      color: urgent ? scheme.errorContainer : scheme.tertiaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(paths.invoice(card.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: urgent
                    ? scheme.onErrorContainer
                    : scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.anaInvoiceCardTitle(
                        ClinicFormat.month(context, card.month),
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: urgent
                            ? scheme.onErrorContainer
                            : scheme.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppFormat.egp(context, card.totalDuePiasters)} · ${l10n.billDueOn(ClinicFormat.day(context, card.dueDate))} · ${dueCountdown(l10n, card.daysLeft)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: urgent
                            ? scheme.onErrorContainer
                            : scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              InvoiceStatusPill(card.status),
            ],
          ),
        ),
      ),
    );
  }
}

/// The automatic sentences (spec 6.14 "Insights"); each opens its detail.
class _Insights extends StatelessWidget {
  const _Insights({required this.insights, required this.paths});

  final List<Insight> insights;
  final ClinicPaths paths;

  void _open(BuildContext context, Insight insight) {
    switch (insight.screen) {
      case 'revenue':
        context.go(paths.revenue);
      case 'patients':
        context.go(
          insight.filter == null
              ? paths.patients
              : '${paths.patients}?lastVisit=${insight.filter}',
        );
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    return SectionCard(
      title: l10n.anaInsights,
      icon: Icons.lightbulb_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final insight in insights)
            InkWell(
              onTap: insight.screen == 'dashboard'
                  ? null
                  : () => _open(context, insight),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        insight.text(language),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (insight.screen != 'dashboard')
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
