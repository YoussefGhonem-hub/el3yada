import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../../sessions/application/sessions_providers.dart';
import '../../sessions/domain/session_models.dart';
import '../../sessions/presentation/widgets/session_widgets.dart';

/// D1 / AS18 for Phase 2: the platform-fee cards (`billingView`): today,
/// «2 كشف + 3 استشارة = 105 ج.م» (→ D2), and this month (→ D3). An
/// assistant without `billingView` doesn't see them at all (AS18: hidden,
/// not zero). The suspension banner is in the shell; the analytics
/// (section 6.14) come in Phase 7.
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
            onRefresh: () async => ref.invalidate(feeSummaryProvider),
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
                  StaggeredEntrance(index: 2, child: const _AnalyticsLater()),
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

/// A calm place for the charts and insights of Phase 7.
class _AnalyticsLater extends StatelessWidget {
  const _AnalyticsLater();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const ExcludeSemantics(child: EmptyIllustration(width: 104)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.homeAnalyticsLaterTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    l10n.homeAnalyticsLaterBody,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
