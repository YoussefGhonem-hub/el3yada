import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

/// The filter bar of D1: period, branch, visit type, compare (BR-REV2). It
/// lives in a provider so the page keeps it while you come back from a detail.
class AnalyticsFilterController extends Notifier<AnalyticsFilter> {
  @override
  AnalyticsFilter build() => const AnalyticsFilter();

  void set(AnalyticsFilter filter) => state = filter;
}

final analyticsFilterProvider =
    NotifierProvider<AnalyticsFilterController, AnalyticsFilter>(
      AnalyticsFilterController.new,
    );

/// D1 / AS18 for the current filter.
final dashboardProvider = FutureProvider.autoDispose<Dashboard>(
  (ref) => ref
      .watch(analyticsRepositoryProvider)
      .dashboard(ref.watch(analyticsFilterProvider)),
  retry: noRetry,
);

/// The D35 filter (year, branch, visit type).
class RevenueFilterController extends Notifier<RevenueFilter> {
  @override
  RevenueFilter build() => RevenueFilter(
    year: DateTime.now().toUtc().add(const Duration(hours: 2)).year,
  );

  void set(RevenueFilter filter) => state = filter;
}

final revenueFilterProvider =
    NotifierProvider<RevenueFilterController, RevenueFilter>(
      RevenueFilterController.new,
    );

/// D35 by month for the current filter.
final revenueReportProvider = FutureProvider.autoDispose<RevenueReport>(
  (ref) => ref
      .watch(analyticsRepositoryProvider)
      .revenue(ref.watch(revenueFilterProvider)),
  retry: noRetry,
);

/// D35: the days of a month under the current filter.
final revenueMonthProvider = FutureProvider.autoDispose
    .family<RevenueMonth, String>((ref, month) {
      final filter = ref.watch(revenueFilterProvider);
      return ref
          .watch(analyticsRepositoryProvider)
          .revenueMonth(month, branchId: filter.branchId, type: filter.type);
    }, retry: noRetry);

/// D35: the sessions of a day under the current filter.
final revenueDayProvider = FutureProvider.autoDispose
    .family<RevenueDay, DateTime>((ref, day) {
      final filter = ref.watch(revenueFilterProvider);
      return ref
          .watch(analyticsRepositoryProvider)
          .revenueDay(day, branchId: filter.branchId, type: filter.type);
    }, retry: noRetry);
