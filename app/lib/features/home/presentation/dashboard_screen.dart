import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../analytics/application/analytics_providers.dart';
import '../../analytics/presentation/dashboard_analytics.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../../sessions/application/sessions_providers.dart';
import '../../sessions/domain/session_models.dart';
import '../../sessions/presentation/widgets/session_widgets.dart';

/// D1 / AS18: the platform-fee cards (`billingView`): today,
/// «2 كشف + 3 استشارة = 105 ج.م» (→ D2), and this month (→ D3); then the
/// analytics of section 6.14 (filter bar, KPI tiles, insights, charts C1–C12).
/// An assistant doesn't see what her permissions don't cover (AS18: hidden,
/// not zero). The suspension banner is in the shell; the invoice card is
/// part of the analytics.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    return ClinicGate(
      builder: (context, clinic) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final gutter = clinicGutter(width);
          final billing = clinic.can(ClinicPermission.billingView);
          final summary = billing ? ref.watch(feeSummaryProvider) : null;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feeSummaryProvider);
              ref.invalidate(dashboardProvider);
            },
            child: StaggerGroup(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: ClinicHeader(title: l10n.navDashboard, subtitle: ClinicFormat.dayWithWeekday(context, ClinicFormat.today())),
                  ),
                  const SizedBox(height: 20),
                  if (summary != null) ...[
                    StaggeredEntrance(
                      index: 1,
                      child: AsyncStateSwitcher<FeeSummary>(
                        value: summary,
                        loading: (context) => SkeletonLoading(
                          loading: true,
                          child: _FeeCards(today: FeeTotals.zero, month: FeeTotals.zero, width: width, onToday: null, onMonth: null),
                        ),
                        error: (context, error) => AdminErrorView(error: error, compact: true, onRetry: () => ref.invalidate(feeSummaryProvider)),
                        data: (context, data) => _FeeCards(
                          today: data.today,
                          month: data.thisMonth,
                          width: width,
                          onToday: () => context.push(paths.today()),
                          onMonth: () => context.push(paths.month()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (clinic.can(ClinicPermission.appointmentsView) || billing || clinic.can(ClinicPermission.revenueView))
                    AnalyticsSection(clinic: clinic, width: width - gutter * 2),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeeCards extends StatelessWidget {
  const _FeeCards({required this.today, required this.month, required this.width, required this.onToday, required this.onMonth});

  final FeeTotals today;
  final FeeTotals month;
  final double width;
  final VoidCallback? onToday;
  final VoidCallback? onMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todayCard = FeeCard(title: l10n.feesToday, totals: today, highlight: true, onTap: onToday);
    final monthCard = FeeCard(title: l10n.feesThisMonth, totals: month, onTap: onMonth);
    if (width < 720) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [todayCard, const SizedBox(height: 16), monthCard]);
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: todayCard), const SizedBox(width: 16), Expanded(child: monthCard)],
      ),
    );
  }
}

