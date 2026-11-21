import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';
import '../../analytics/presentation/chart_parts.dart';
import '../../patients/presentation/widgets/clinic_ui.dart'
    show ClinicFormat, GroupedRows;
import '../application/admin_billing_providers.dart';
import '../domain/admin_billing_models.dart';

/// AD1: the platform at a glance (spec 7.5): doctors by status, patients,
/// today's and this month's sessions, bookings, the no-show rate, the fees
/// expected and invoiced against collected, what is outstanding, how many
/// doctors are overdue, and what waits for the admin. Two charts and three
/// action lists. Counts and platform fees only: never a clinic's revenue.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dashboard = ref.watch(adminDashboardProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = adminGutter(width);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
              child: AdminHeader(
                title: l10n.abDashboardTitle,
                subtitle: l10n.abDashboardSubtitle,
              ),
            ),
            Expanded(
              child: AsyncStateSwitcher<AdminDashboard>(
                value: dashboard,
                loading: (context) => SkeletonLoading(
                  loading: true,
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [SizedBox(height: 360)],
                  ),
                ),
                error: (context, error) => AdminErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(adminDashboardProvider),
                ),
                data: (context, data) => RefreshIndicator(
                  onRefresh: () => ref.refresh(adminDashboardProvider.future),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                    children: [
                      StaggeredEntrance(
                        index: 0,
                        child: _Tiles(data: data, width: width - gutter * 2),
                      ),
                      const SizedBox(height: 16),
                      StaggeredEntrance(
                        index: 1,
                        child: _Charts(data: data, wide: width >= 900),
                      ),
                      const SizedBox(height: 16),
                      StaggeredEntrance(
                        index: 2,
                        child: _Lists(data: data, wide: width >= 900),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.value,
    required this.icon,
    this.caption,
    this.tone,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? caption;
  final PillTone? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = tone == PillTone.danger;
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$title: $value${caption == null ? '' : ', $caption'}',
      child: ExcludeSemantics(
        child: Card(
          color: danger ? scheme.errorContainer : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: danger
                            ? scheme.onErrorContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: danger
                                ? scheme.onErrorContainer
                                : scheme.onSurfaceVariant,
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
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: danger ? scheme.onErrorContainer : null,
                      ),
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      caption!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: danger
                            ? scheme.onErrorContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.data, required this.width});

  final AdminDashboard data;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String money(int piasters) => AppFormat.egp(context, piasters);
    final d = data.doctors;
    final tiles = <Widget>[
      _Tile(
        title: l10n.abTileDoctors,
        value: '${d.active + d.suspended + d.pendingApproval}',
        icon: Icons.medical_services_outlined,
        caption: l10n.abTileDoctorsCaption(
          d.active,
          d.pendingApproval,
          d.suspended,
        ),
        onTap: () => context.go('/admin/doctors'),
      ),
      _Tile(
        title: l10n.abTilePatients,
        value: '${data.totalPatients}',
        icon: Icons.groups_outlined,
      ),
      _Tile(
        title: l10n.abTileSessionsToday,
        value: '${data.sessionsToday.total}',
        icon: Icons.today_outlined,
        caption: l10n.billCounts(
          data.sessionsToday.examinations,
          data.sessionsToday.consultations,
        ),
      ),
      _Tile(
        title: l10n.abTileSessionsMonth,
        value: '${data.sessionsThisMonth.total}',
        icon: Icons.calendar_month_outlined,
        caption: l10n.billCounts(
          data.sessionsThisMonth.examinations,
          data.sessionsThisMonth.consultations,
        ),
      ),
      _Tile(
        title: l10n.abTileBookingsToday,
        value: '${data.bookingsToday}',
        icon: Icons.event_available_outlined,
      ),
      _Tile(
        title: l10n.abTileNoShow,
        value: data.noShowRateLast30Days == null
            ? '–'
            : l10n.anaPercent(
                (data.noShowRateLast30Days! * 100).round().toString(),
              ),
        icon: Icons.event_busy_outlined,
        caption: l10n.abLast30Days,
      ),
      _Tile(
        title: l10n.abTileExpectedFees,
        value: money(data.expectedFeesThisMonthPiasters),
        icon: Icons.trending_up,
        caption: l10n.abLiveThisMonth,
      ),
      _Tile(
        title: l10n.abTileLastMonth,
        value: money(data.lastMonth.collectedPiasters),
        icon: Icons.account_balance_wallet_outlined,
        caption: l10n.abCollectedOfInvoiced(
          money(data.lastMonth.invoicedPiasters),
        ),
        onTap: () => context.go('/admin/invoices'),
      ),
      _Tile(
        title: l10n.abTileOutstanding,
        value: money(data.outstandingPiasters),
        icon: Icons.pending_actions_outlined,
        tone: data.outstandingPiasters > 0 ? PillTone.warning : null,
        onTap: () => context.go('/admin/invoices'),
      ),
      _Tile(
        title: l10n.abTileOverdue,
        value: '${data.overdueDoctors}',
        icon: Icons.error_outline,
        tone: data.overdueDoctors > 0 ? PillTone.danger : null,
        onTap: () => context.go('/admin/doctors'),
      ),
      _Tile(
        title: l10n.abTilePaymentsToReview,
        value: '${data.paymentsToReview}',
        icon: Icons.payments_outlined,
        tone: data.paymentsToReview > 0 ? PillTone.danger : null,
        onTap: () => context.go('/admin/payments'),
      ),
      _Tile(
        title: l10n.abTileSignups,
        value: '${data.signupsToReview}',
        icon: Icons.how_to_reg_outlined,
        onTap: () => context.go('/admin/signups'),
      ),
    ];
    final columns = width >= 1100 ? 4 : (width >= 720 ? 3 : 2);
    const gap = 12.0;
    final tileWidth =
        ((width - gap * (columns - 1)) / columns).floorToDouble() - 1;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
      ],
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({required this.data, required this.wide});

  final AdminDashboard data;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = ChartColors.of(context);
    final days = data.sessionsPerDay;
    final maxDay = days.fold<int>(
      0,
      (a, d) => d.examinations + d.consultations > a
          ? d.examinations + d.consultations
          : a,
    );
    final months = data.invoicedVsCollected;
    final maxMonth = months.fold<int>(
      0,
      (a, m) => [
        a,
        m.invoicedPiasters,
        m.collectedPiasters,
      ].reduce((x, y) => x > y ? x : y),
    );

    final sessions = ChartCard(
      title: l10n.abChartSessions,
      empty: maxDay == 0,
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
      child: BarChart(
        BarChartData(
          maxY: maxDay == 0 ? 1 : maxDay * 1.15,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v),
            bottom: (i) => ClinicFormat.dayShort(context, days[i].day),
            count: days.length,
            leftSize: 32,
          ),
          barGroups: [
            for (final (i, d) in days.indexed)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (d.examinations + d.consultations).toDouble(),
                    width: 6,
                    borderRadius: BorderRadius.circular(2),
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        d.examinations.toDouble(),
                        colors.examination,
                      ),
                      BarChartRodStackItem(
                        d.examinations.toDouble(),
                        (d.examinations + d.consultations).toDouble(),
                        colors.consultation,
                      ),
                    ],
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${ClinicFormat.dayShort(context, days[group.x].day)}\n${l10n.sessionTypeExamination}: ${days[group.x].examinations}\n${l10n.sessionTypeConsultation}: ${days[group.x].consultations}',
                Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final invoiced = ChartCard(
      title: l10n.abChartInvoiced,
      empty: maxMonth == 0,
      legend: [
        LegendItem(color: colors.examination, label: l10n.abInvoiced),
        LegendItem(color: colors.highlight, label: l10n.abCollected),
      ],
      child: BarChart(
        BarChartData(
          maxY: maxMonth == 0 ? 1 : maxMonth * 1.15,
          gridData: gridData(colors.grid),
          borderData: FlBorderData(show: false),
          titlesData: titles(
            context: context,
            left: (v) => compact(v / 100),
            bottom: (i) =>
                ClinicFormat.month(context, months[i].month).split(' ').first,
            count: months.length,
          ),
          barGroups: [
            for (final (i, m) in months.indexed)
              BarChartGroupData(
                x: i,
                barsSpace: 2,
                barRods: [
                  BarChartRodData(
                    toY: m.invoicedPiasters.toDouble(),
                    width: 8,
                    color: colors.examination,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  BarChartRodData(
                    toY: m.collectedPiasters.toDouble(),
                    width: 8,
                    color: colors.highlight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${ClinicFormat.month(context, months[group.x].month)}\n${l10n.abInvoiced}: ${AppFormat.egp(context, months[group.x].invoicedPiasters)}\n${l10n.abCollected}: ${AppFormat.egp(context, months[group.x].collectedPiasters)}',
                Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [sessions, const SizedBox(height: 12), invoiced],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: sessions),
        const SizedBox(width: 12),
        Expanded(child: invoiced),
      ],
    );
  }
}

/// The three action lists: payments to review, the latest sign-ups, invoices due in 3 days.
class _Lists extends StatelessWidget {
  const _Lists({required this.data, required this.wide});

  final AdminDashboard data;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);

    Widget section(
      String title,
      IconData icon,
      List<Widget> rows,
      String empty, {
      VoidCallback? onAll,
    }) => SectionCard(
      title: title,
      icon: icon,
      trailing: onAll == null
          ? null
          : TextButton(onPressed: onAll, child: Text(l10n.abSeeAll)),
      child: rows.isEmpty
          ? Text(
              empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : GroupedRows(children: rows),
    );

    final payments = section(
      l10n.abListPayments,
      Icons.payments_outlined,
      [
        for (final p in data.latestPayments)
          ListTile(
            title: Text(p.doctor(language)),
            subtitle: Text(
              '${l10n.abInvoiceOf(ClinicFormat.month(context, p.month))} · ${AppFormat.relative(context, p.submittedAt)}',
            ),
            trailing: p.mismatch
                ? StatusPill(
                    label: l10n.abAmountMismatch,
                    tone: PillTone.danger,
                  )
                : LtrText(AppFormat.egp(context, p.amountPiasters)),
            onTap: () => context.go('/admin/payments/${p.paymentId}'),
          ),
      ],
      l10n.abListPaymentsEmpty,
      onAll: () => context.go('/admin/payments'),
    );
    final signups = section(
      l10n.abListSignups,
      Icons.person_add_alt_outlined,
      [
        for (final s in data.latestSignups)
          ListTile(
            leading: InitialAvatar(name: s.name(language)),
            title: Text(s.name(language)),
            subtitle: Text(
              '${s.specialty(language)} · ${AppFormat.relative(context, s.createdAt)}',
            ),
            onTap: () => context.go('/admin/doctors/${s.doctorId}'),
          ),
      ],
      l10n.abListSignupsEmpty,
      onAll: () => context.go('/admin/doctors'),
    );
    final due = section(
      l10n.abListDueSoon,
      Icons.event_outlined,
      [
        for (final i in data.invoicesDueSoon)
          ListTile(
            title: Text(i.doctor(language)),
            subtitle: Text(
              '${l10n.abInvoiceOf(ClinicFormat.month(context, i.month))} · ${l10n.billDueOn(ClinicFormat.day(context, i.dueDate))}',
            ),
            trailing: LtrText(AppFormat.egp(context, i.totalDuePiasters)),
            onTap: () => context.go('/admin/invoices/${i.id}'),
          ),
      ],
      l10n.abListDueSoonEmpty,
      onAll: () => context.go('/admin/invoices'),
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          payments,
          const SizedBox(height: 12),
          signups,
          const SizedBox(height: 12),
          due,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: payments),
        const SizedBox(width: 12),
        Expanded(child: signups),
        const SizedBox(width: 12),
        Expanded(child: due),
      ],
    );
  }
}
