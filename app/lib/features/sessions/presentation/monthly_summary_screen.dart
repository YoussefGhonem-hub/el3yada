import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/sessions_providers.dart';
import '../domain/session_models.dart';
import 'widgets/session_widgets.dart';

/// D3: a month's platform fees (`billingView`): the month picker (this month
/// and past months), All or one branch, the totals, the totals per branch
/// (BR-BR7), and a per-day table; tap a day for its sessions (D2). The
/// month's invoice (D19) comes in Phase 7.
class MonthlySummaryScreen extends ConsumerStatefulWidget {
  const MonthlySummaryScreen({super.key, this.month});

  /// Null: this month (Cairo).
  final DateTime? month;

  @override
  ConsumerState<MonthlySummaryScreen> createState() => _MonthlySummaryScreenState();
}

class _MonthlySummaryScreenState extends ConsumerState<MonthlySummaryScreen> {
  late DateTime _month = widget.month ?? _thisMonth;
  String? _branchId;

  DateTime get _thisMonth {
    final today = ClinicFormat.today();
    return DateTime.utc(today.year, today.month);
  }

  bool get _isThisMonth => _month == _thisMonth;

  MonthQuery get _query => (month: _isThisMonth ? null : _month, branchId: _branchId);

  void _shift(int months) => setState(() => _month = DateTime.utc(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.billingView)) {
            return AdminErrorView(error: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.permissionDenied));
          }
          return LayoutBuilder(builder: (context, constraints) => _content(context, clinic, paths, constraints.maxWidth));
        },
      ),
    );
  }

  Widget _content(BuildContext context, ClinicContext clinic, ClinicPaths paths, double width) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final gutter = clinicGutter(width);
    final wide = width >= 960;
    final month = ref.watch(monthFeesProvider(_query));

    final controls = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(tooltip: l10n.feesPreviousMonth, onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: Text(
                ClinicFormat.month(context, _month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: l10n.feesNextMonth,
              onPressed: _isThisMonth ? null : () => _shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (clinic.branches.length > 1) ...[
          ChoiceChip(
            label: Text(l10n.patientFilterAllBranches),
            selected: _branchId == null,
            onSelected: (_) => setState(() => _branchId = null),
          ),
          for (final branch in clinic.branches)
            ChoiceChip(
              label: Text(branch.name(language)),
              selected: _branchId == branch.id,
              onSelected: (_) => setState(() => _branchId = branch.id),
            ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
          child: ClinicHeader(title: l10n.feesMonthTitle, subtitle: l10n.feesMonthSubtitle, backFallback: paths.dashboard),
        ),
        Padding(padding: EdgeInsets.symmetric(horizontal: gutter), child: ClinicChips(child: controls)),
        const SizedBox(height: 12),
        Expanded(
          child: AsyncStateSwitcher<MonthFees>(
            value: month,
            loading: (context) => SkeletonLoading(
              loading: true,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: gutter),
                children: [
                  FeeCard(title: l10n.feesMonthTotals, totals: const FeeTotals(examinationCount: 10, consultationCount: 8)),
                  const SizedBox(height: 16),
                  GroupedRows(children: [for (var i = 0; i < 6; i++) _DayRow.placeholder()]),
                ],
              ),
            ),
            error: (context, error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(monthFeesProvider(_query))),
            data: (context, data) {
              final totals = FeeCard(title: l10n.feesMonthTotals, totals: data.totals, highlight: true);
              final branches = _branchId == null && data.branches.length > 1 ? _BranchTotals(branches: data.branches) : null;
              final days = _DaysTable(
                days: data.days.reversed.toList(),
                onDay: (day) => context.push(paths.today(day: dayKey(day))),
              );
              final children = wide
                  ? [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 380,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                StaggeredEntrance(index: 0, child: totals),
                                if (branches != null) ...[const SizedBox(height: 16), StaggeredEntrance(index: 1, child: branches)],
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(child: StaggeredEntrance(index: 2, child: days)),
                        ],
                      ),
                    ]
                  : [
                      StaggeredEntrance(index: 0, child: totals),
                      if (branches != null) ...[const SizedBox(height: 16), StaggeredEntrance(index: 1, child: branches)],
                      const SizedBox(height: 16),
                      StaggeredEntrance(index: 2, child: days),
                    ];
              return StaggerGroup(
                key: ValueKey('$_month$_branchId'),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                  children: children,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// BR-BR7: what each branch adds up to.
class _BranchTotals extends StatelessWidget {
  const _BranchTotals({required this.branches});

  final List<BranchFees> branches;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return SectionCard(
      title: l10n.feesPerBranch,
      icon: Icons.store_mall_directory_outlined,
      child: Column(
        children: [
          for (final (i, branch) in branches.indexed) ...[
            if (i > 0) const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.name(language), style: theme.textTheme.titleSmall),
                      Text(
                        l10n.patientVisitsSplit(branch.totals.examinationCount, branch.totals.consultationCount),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(AppFormat.egp(context, branch.totals.totalPiasters), style: theme.textTheme.titleMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The per-day table: date, examinations, consultations, amount. Days
/// without sessions stay, quieter.
class _DaysTable extends StatelessWidget {
  const _DaysTable({required this.days, required this.onDay});

  final List<DayFees> days;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final header = theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant);
    if (days.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(l10n.feesMonthNoDays, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    return GroupedRows(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(l10n.feesColumnDay, style: header)),
              Expanded(flex: 2, child: Text(l10n.feesColumnExaminations, style: header, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text(l10n.feesColumnConsultations, style: header, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text(l10n.feesColumnAmount, style: header, textAlign: TextAlign.end)),
              const SizedBox(width: 24),
            ],
          ),
        ),
        for (final day in days) _DayRow(day: day, onTap: day.totals.sessionCount == 0 ? null : () => onDay(day.day)),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onTap});

  static Widget placeholder() => _DayRow(day: DayFees(day: DateTime.utc(2026), totals: const FeeTotals(examinationCount: 1)), onTap: null);

  final DayFees day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = day.totals.sessionCount == 0;
    final style = empty ? theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant) : theme.textTheme.bodyLarge;
    // Phones: "15 نوفمبر"; wider: with the weekday.
    final label = MediaQuery.sizeOf(context).width < 600
        ? ClinicFormat.dayShort(context, day.day)
        : ClinicFormat.dayWithWeekday(context, day.day);
    return Semantics(
      button: onTap != null,
      label: '$label, ${feeEquation(context, day.totals)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text(label, style: style)),
              Expanded(flex: 2, child: Text('${day.totals.examinationCount}', style: style, textAlign: TextAlign.center)),
              Expanded(flex: 2, child: Text('${day.totals.consultationCount}', style: style, textAlign: TextAlign.center)),
              Expanded(
                flex: 2,
                child: Text(
                  AppFormat.egp(context, day.totals.totalPiasters),
                  style: empty ? style : theme.textTheme.titleSmall,
                  textAlign: TextAlign.end,
                ),
              ),
              SizedBox(
                width: 24,
                child: onTap == null ? null : ExcludeSemantics(child: Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
