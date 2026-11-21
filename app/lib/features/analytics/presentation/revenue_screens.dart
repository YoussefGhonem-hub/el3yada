import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../sessions/domain/session_models.dart' show PaymentMethod;
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/analytics_providers.dart';
import '../domain/analytics_models.dart';

/// Wraps a D35 screen: only with `revenueView`, otherwise «not allowed».
class _RevenueGate extends StatelessWidget {
  const _RevenueGate({required this.builder});

  final Widget Function(
    BuildContext context,
    ClinicContext clinic,
    ClinicPaths paths,
    double width,
  )
  builder;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ClinicGate(
      builder: (context, clinic) {
        if (!clinic.can(ClinicPermission.revenueView)) {
          return const AdminErrorView(
            error: ApiException(
              kind: ApiErrorKind.http,
              status: 403,
              code: ApiCodes.permissionDenied,
            ),
          );
        }
        return Consumer(
          builder: (context, ref, _) {
            final paths = ref.watch(clinicPathsProvider);
            return LayoutBuilder(
              builder: (context, constraints) =>
                  builder(context, clinic, paths, constraints.maxWidth),
            );
          },
        );
      },
    ),
  );
}

String _money(BuildContext context, int piasters) =>
    AppFormat.egp(context, piasters);

// ---- D35: the year by month, branch, visit type, payment method ----------------------------

/// D35: the year month by month with the totals, the best and worst months,
/// and the tabs By month, By branch, By visit type and By payment method.
/// Tap a month for its days, a day for its sessions.
class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _RevenueGate(
    builder: (context, clinic, paths, width) {
      final l10n = AppLocalizations.of(context);
      final gutter = clinicGutter(width);
      final filter = ref.watch(revenueFilterProvider);
      final report = ref.watch(revenueReportProvider);
      return DefaultTabController(
        length: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
              child: ClinicHeader(
                title: l10n.revTitle,
                subtitle: l10n.revSubtitle,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: RevenueFilterBar(
                clinic: clinic,
                filter: filter,
                onChanged: ref.read(revenueFilterProvider.notifier).set,
              ),
            ),
            const SizedBox(height: 8),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: l10n.revTabMonth),
                Tab(text: l10n.revTabBranch),
                Tab(text: l10n.revTabType),
                Tab(text: l10n.revTabPayment),
              ],
            ),
            Expanded(
              child: AsyncStateSwitcher<RevenueReport>(
                value: report,
                loading: (context) => const SkeletonLoading(
                  loading: true,
                  child: SizedBox(height: 360),
                ),
                error: (context, error) => AdminErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(revenueReportProvider),
                ),
                data: (context, data) => TabBarView(
                  children: [
                    _ByMonth(
                      report: data,
                      clinic: clinic,
                      paths: paths,
                      width: width,
                    ),
                    _ByBranch(report: data, gutter: gutter),
                    _ByType(report: data, gutter: gutter),
                    _ByPayment(report: data, gutter: gutter),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Year, branch and visit type (D35's filters).
class RevenueFilterBar extends StatelessWidget {
  const RevenueFilterBar({
    super.key,
    required this.clinic,
    required this.filter,
    required this.onChanged,
  });

  final ClinicContext clinic;
  final RevenueFilter filter;
  final ValueChanged<RevenueFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final branches = clinic.branches
        .where((b) => b.assigned && b.status != 'archived')
        .toList();
    final thisYear = ClinicFormat.today().year;
    return ClinicChips(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final year in [thisYear, thisYear - 1, thisYear - 2])
            ChoiceChip(
              label: Text('$year'),
              selected: filter.year == year,
              onSelected: (_) => onChanged(filter.copyWith(year: year)),
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
        ],
      ),
    );
  }
}

class _ByMonth extends StatelessWidget {
  const _ByMonth({
    required this.report,
    required this.clinic,
    required this.paths,
    required this.width,
  });

  final RevenueReport report;
  final ClinicContext clinic;
  final ClinicPaths paths;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gutter = clinicGutter(width);
    if (report.months.every((m) => m.row.visits == 0)) {
      return EmptyState(title: l10n.revEmptyTitle, message: l10n.revEmptyBody);
    }
    final months = report.months.reversed.toList();
    if (width >= 900) {
      return ListView(
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                columns: [
                  DataColumn(label: Text(l10n.revColMonth)),
                  DataColumn(
                    label: Text(l10n.revColExaminations),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(l10n.revColConsultations),
                    numeric: true,
                  ),
                  DataColumn(label: Text(l10n.revColRevenue), numeric: true),
                  DataColumn(label: Text(l10n.revColFees), numeric: true),
                  DataColumn(label: Text(l10n.revColNet), numeric: true),
                  DataColumn(label: Text(l10n.revColPatients), numeric: true),
                  DataColumn(
                    label: Text(l10n.revColNewPatients),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(l10n.revColFreeDiscounted),
                    numeric: true,
                  ),
                  DataColumn(label: Text(l10n.revColChange), numeric: true),
                  DataColumn(label: Text(l10n.revColInvoice)),
                ],
                rows: [
                  for (final month in months)
                    DataRow(
                      color: month.monthKey == report.bestMonth
                          ? WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                            )
                          : month.monthKey == report.worstMonth
                          ? WidgetStatePropertyAll(
                              Theme.of(context).colorScheme.errorContainer
                                  .withValues(alpha: 0.4),
                            )
                          : null,
                      onSelectChanged: (_) =>
                          context.go(paths.revenueMonth(month.monthKey)),
                      cells: [
                        DataCell(
                          Text(
                            ClinicFormat.month(context, month.month) +
                                (month.monthKey == report.bestMonth
                                    ? ' ★'
                                    : ''),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${month.row.examinations} · ${_money(context, month.row.examinationRevenue)}',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${month.row.consultations} · ${_money(context, month.row.consultationRevenue)}',
                          ),
                        ),
                        DataCell(Text(_money(context, month.row.revenue))),
                        DataCell(Text(_money(context, month.row.platformFees))),
                        DataCell(Text(_money(context, month.row.net))),
                        DataCell(Text('${month.row.uniquePatients}')),
                        DataCell(Text('${month.row.newPatients}')),
                        DataCell(
                          Text(
                            '${month.row.freeVisits} / ${month.row.discountedVisits}',
                          ),
                        ),
                        DataCell(_Change(month.changePct)),
                        DataCell(
                          month.invoiceId == null
                              ? const Text('–')
                              : TextButton(
                                  onPressed: () => context.go(
                                    paths.invoice(month.invoiceId!),
                                  ),
                                  child: Text(l10n.revOpenInvoice),
                                ),
                        ),
                      ],
                    ),
                  DataRow(
                    color: WidgetStatePropertyAll(
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                    ),
                    cells: [
                      DataCell(
                        Text(
                          l10n.revTotals,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${report.totals.examinations} · ${_money(context, report.totals.examinationRevenue)}',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${report.totals.consultations} · ${_money(context, report.totals.consultationRevenue)}',
                        ),
                      ),
                      DataCell(
                        Text(
                          _money(context, report.totals.revenue),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        Text(_money(context, report.totals.platformFees)),
                      ),
                      DataCell(
                        Text(
                          _money(context, report.totals.net),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text('${report.totals.uniquePatients}')),
                      DataCell(Text('${report.totals.newPatients}')),
                      DataCell(
                        Text(
                          '${report.totals.freeVisits} / ${report.totals.discountedVisits}',
                        ),
                      ),
                      const DataCell(SizedBox.shrink()),
                      const DataCell(SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 32),
      children: [
        StaggeredEntrance(
          index: 0,
          child: _TotalsCard(title: l10n.revTotals, row: report.totals),
        ),
        const SizedBox(height: 12),
        for (final (i, month) in months.indexed)
          StaggeredEntrance(
            index: i + 1,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MonthCard(
                month: month,
                best: month.monthKey == report.bestMonth,
                worst: month.monthKey == report.worstMonth,
                paths: paths,
              ),
            ),
          ),
      ],
    );
  }
}

class _Change extends StatelessWidget {
  const _Change(this.changePct);

  final double? changePct;

  @override
  Widget build(BuildContext context) {
    if (changePct == null) return const Text('–');
    final scheme = Theme.of(context).colorScheme;
    final value = changePct!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          value >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
          size: 14,
          color: value >= 0 ? scheme.primary : scheme.error,
        ),
        LtrText('${value.abs().toStringAsFixed(value.abs() >= 10 ? 0 : 1)}%'),
      ],
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.title, required this.row});

  final String title;
  final RevenueRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget cell(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: LtrText(value, style: theme.textTheme.titleMedium),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                cell(l10n.revColRevenue, _money(context, row.revenue)),
                cell(l10n.revColFees, _money(context, row.platformFees)),
                cell(l10n.revColNet, _money(context, row.net)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                cell(l10n.revColVisits, '${row.visits}'),
                cell(l10n.revColPatients, '${row.uniquePatients}'),
                cell(l10n.revColNewPatients, '${row.newPatients}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.best,
    required this.worst,
    required this.paths,
  });

  final RevenueMonthRow month;
  final bool best;
  final bool worst;
  final ClinicPaths paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final row = month.row;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(paths.revenueMonth(month.monthKey)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ClinicFormat.month(context, month.month),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (best)
                    StatusPill(
                      label: l10n.revBestMonth,
                      tone: PillTone.positive,
                      icon: Icons.star_outline,
                    ),
                  if (worst)
                    StatusPill(
                      label: l10n.revWorstMonth,
                      tone: PillTone.warning,
                    ),
                  const SizedBox(width: 8),
                  _Change(month.changePct),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Mini(
                      label: l10n.revColRevenue,
                      value: _money(context, row.revenue),
                    ),
                  ),
                  Expanded(
                    child: _Mini(
                      label: l10n.revColNet,
                      value: _money(context, row.net),
                    ),
                  ),
                  Expanded(
                    child: _Mini(
                      label: l10n.revColVisits,
                      value: '${row.visits}',
                    ),
                  ),
                ],
              ),
              if (month.invoiceId != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () =>
                        context.go(paths.invoice(month.invoiceId!)),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(l10n.revOpenInvoice),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: LtrText(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _ByBranch extends StatelessWidget {
  const _ByBranch({required this.report, required this.gutter});

  final RevenueReport report;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    if (report.byBranch.isEmpty)
      return EmptyState(title: l10n.revEmptyTitle, message: l10n.revEmptyBody);
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 32),
      children: [
        for (final branch in report.byBranch)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TotalsCard(title: branch.name(language), row: branch.row),
          ),
      ],
    );
  }
}

class _ByType extends StatelessWidget {
  const _ByType({required this.report, required this.gutter});

  final RevenueReport report;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (report.byType.isEmpty)
      return EmptyState(title: l10n.revEmptyTitle, message: l10n.revEmptyBody);
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 32),
      children: [
        for (final entry in report.byType)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TotalsCard(
              title: sessionTypeLabel(l10n, entry.type),
              row: entry.row,
            ),
          ),
      ],
    );
  }
}

class _ByPayment extends StatelessWidget {
  const _ByPayment({required this.report, required this.gutter});

  final RevenueReport report;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (report.byPaymentMethod.isEmpty)
      return EmptyState(title: l10n.revEmptyTitle, message: l10n.revEmptyBody);
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 32),
      children: [
        for (final entry in report.byPaymentMethod)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TotalsCard(
              title: _methodLabel(l10n, entry.method),
              row: entry.row,
            ),
          ),
      ],
    );
  }

  String _methodLabel(AppLocalizations l10n, String? method) {
    final parsed = PaymentMethod.fromWire(method);
    return parsed == null
        ? l10n.revMethodUnspecified
        : paymentMethodLabel(l10n, parsed);
  }
}

// ---- Drill-down: the days of a month, the sessions of a day --------------------------------

/// D35: a month's days with the same columns. Tap a day for its sessions.
class RevenueMonthScreen extends ConsumerWidget {
  const RevenueMonthScreen({super.key, required this.month});

  /// `yyyy-MM`.
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _RevenueGate(
    builder: (context, clinic, paths, width) {
      final l10n = AppLocalizations.of(context);
      final gutter = clinicGutter(width);
      final data = ref.watch(revenueMonthProvider(month));
      final first = parseMonth(month);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
            child: ClinicHeader(
              title: ClinicFormat.month(context, first),
              subtitle: l10n.revMonthSubtitle,
              backFallback: paths.revenue,
            ),
          ),
          Expanded(
            child: AsyncStateSwitcher<RevenueMonth>(
              value: data,
              loading: (context) => const SkeletonLoading(
                loading: true,
                child: SizedBox(height: 360),
              ),
              error: (context, error) => AdminErrorView(
                error: error,
                onRetry: () => ref.invalidate(revenueMonthProvider(month)),
              ),
              data: (context, data) {
                final days = data.days
                    .where((d) => d.row.visits > 0)
                    .toList()
                    .reversed
                    .toList();
                return ListView(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                  children: [
                    _TotalsCard(title: l10n.revTotals, row: data.totals),
                    const SizedBox(height: 12),
                    if (days.isEmpty)
                      EmptyState(
                        title: l10n.revEmptyTitle,
                        message: l10n.revEmptyBody,
                      )
                    else
                      GroupedRows(
                        children: [
                          for (final entry in days)
                            InkWell(
                              onTap: () => context.go(
                                paths.revenueDay(dayKey(entry.day)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ClinicFormat.dayWithWeekday(
                                              context,
                                              entry.day,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleSmall,
                                          ),
                                          Text(
                                            l10n.billCounts(
                                              entry.row.examinations,
                                              entry.row.consultations,
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        LtrText(
                                          _money(context, entry.row.revenue),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        LtrText(
                                          l10n.revNetShort(
                                            _money(context, entry.row.net),
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

/// D35: a day's sessions: time, patient, branch, type, visit price, amount
/// charged, discount, payment method and who recorded it.
class RevenueDayScreen extends ConsumerWidget {
  const RevenueDayScreen({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _RevenueGate(
    builder: (context, clinic, paths, width) {
      final l10n = AppLocalizations.of(context);
      final language = Localizations.localeOf(context).languageCode;
      final gutter = clinicGutter(width);
      final data = ref.watch(revenueDayProvider(day));
      final theme = Theme.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
            child: ClinicHeader(
              title: ClinicFormat.dayWithWeekday(context, day),
              subtitle: l10n.revDaySubtitle,
              backFallback: paths.revenueMonth(
                '${day.year}-${day.month.toString().padLeft(2, '0')}',
              ),
            ),
          ),
          Expanded(
            child: AsyncStateSwitcher<RevenueDay>(
              value: data,
              loading: (context) => const SkeletonLoading(
                loading: true,
                child: SizedBox(height: 360),
              ),
              error: (context, error) => AdminErrorView(
                error: error,
                onRetry: () => ref.invalidate(revenueDayProvider(day)),
              ),
              isEmpty: (data) => data.sessions.isEmpty,
              empty: (context) => EmptyState(
                title: l10n.revEmptyTitle,
                message: l10n.revEmptyBody,
              ),
              data: (context, data) => ListView(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                children: [
                  _TotalsCard(title: l10n.revTotals, row: data.totals),
                  const SizedBox(height: 12),
                  GroupedRows(
                    children: [
                      for (final s in data.sessions)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.patientName,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  TypeBadge(s.type),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  ClinicFormat.time(context, s.at),
                                  s.branchName(language),
                                  l10n.revRecordedBy(s.recordedBy),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (s.listPricePiasters != null)
                                    Expanded(
                                      child: _Mini(
                                        label: l10n.revVisitPrice,
                                        value: _money(
                                          context,
                                          s.listPricePiasters!,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: _Mini(
                                      label: l10n.revAmountCharged,
                                      value: _money(
                                        context,
                                        s.amountChargedPiasters,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _Mini(
                                      label: l10n.revDiscount,
                                      value: _money(
                                        context,
                                        s.discountPiasters,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
