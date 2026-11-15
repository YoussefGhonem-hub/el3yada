import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../clinic_admin_routes.dart';
import '../../domain/branch_models.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'branch_text.dart';

/// D28: the doctor's branches as tickets: name, area, status, today's open
/// periods, upcoming bookings and the Default badge. "Add branch" shows
/// the count ("2 of 5") and is disabled at the limit, with the reason.
class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final branches = ref.watch(branchesProvider);
    final list = branches.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        final canAdd = list?.canAdd ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 8),
              child: AdminHeader(
                title: l10n.navBranches,
                subtitle: l10n.branchesSubtitle,
                actions: [
                  FilledButton.icon(
                    onPressed: canAdd ? () => context.go(ClinicAdminRoutes.newBranch) : null,
                    icon: const Icon(Icons.add_business_outlined),
                    label: Text(l10n.branchAdd),
                  ),
                ],
              ),
            ),
            if (list != null)
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CapacityMeter(count: list.count, limit: list.limit, label: l10n.branchCountOf(list.count, list.limit)),
                    if (!list.canAdd)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InfoBanner(icon: Icons.block, tone: PillTone.warning, message: l10n.branchErrorLimitReached),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: AsyncStateSwitcher<BranchList>(
                value: branches,
                isEmpty: (list) => list.items.isEmpty,
                loading: (context) => _BranchesSkeleton(gutter: gutter),
                empty: (context) => EmptyState(
                  title: l10n.branchesEmptyTitle,
                  actionLabel: l10n.branchAdd,
                  onAction: () => context.go(ClinicAdminRoutes.newBranch),
                ),
                error: (context, error) => AdminErrorView(error: error, onRetry: () => ref.read(branchesProvider.notifier).reload()),
                data: (context, list) => RefreshIndicator(
                  onRefresh: () => ref.read(branchesProvider.notifier).refresh(),
                  child: StaggerGroup(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                      child: ResponsiveGrid(
                        columns: 3,
                        minColumnWidth: 320,
                        children: [
                          for (final (i, branch) in list.items.indexed)
                            StaggeredEntrance(
                              index: i,
                              child: BranchTicket(
                                branch: branch,
                                onTap: () => context.go(ClinicAdminRoutes.branch(branch.id)),
                              ),
                            ),
                        ],
                      ),
                    ),
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

/// One D28 card: the branch above the tear line, today's hours and the
/// upcoming bookings below it.
class BranchTicket extends StatelessWidget {
  const BranchTicket({super.key, required this.branch, this.onTap});

  static Widget placeholder() => const BranchTicket(
        branch: BranchCard(
          id: '',
          nameAr: '--------------',
          governorate: '--------',
          city: '----------',
          status: BranchStatuses.active,
          isDefault: false,
          assigned: true,
          todayPeriods: [BranchPeriod(weekday: 1, startLocal: '10:00', endLocal: '14:00')],
        ),
      );

  final BranchCard branch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final name = branch.name(language);
    final place = [branch.area, branch.city, branch.governorate].whereType<String>().where((s) => s.isNotEmpty).join(l10n.regListSeparator);
    final muted = branch.archived;
    final closed = branch.status == BranchStatuses.temporarilyClosed;

    final top = Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(color: muted ? scheme.onSurfaceVariant : null),
                ),
              ),
              if (branch.isDefault) ...[const SizedBox(width: 8), const DefaultBranchPill()],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ExcludeSemantics(child: Icon(Icons.place_outlined, size: 16, color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(place, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))),
            ],
          ),
          const SizedBox(height: 10),
          BranchStatusPill(status: branch.status),
          if (closed && branch.closedMessage != null) ...[
            const SizedBox(height: 8),
            Text(branch.closedMessage!, style: theme.textTheme.bodySmall),
            if (branch.reopenDate != null)
              Text(
                l10n.branchReopensOn(dayText(context, branch.reopenDate!)),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ],
      ),
    );

    final periods = branch.todayPeriods;
    final stub = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(Icons.schedule_outlined, size: 18, color: scheme.primary)),
              const SizedBox(width: 8),
              Expanded(
                child: periods.isEmpty || branch.archived
                    ? Text(
                        branch.archived ? l10n.branchArchivedHint : l10n.branchClosedToday,
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final period in periods)
                            _PeriodChip(text: periodText(context, period), label: period.label),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ExcludeSemantics(child: Icon(Icons.event_available_outlined, size: 18, color: scheme.primary)),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.branchUpcomingBookings(branch.upcomingBookings), style: theme.textTheme.bodyMedium)),
              ExcludeSemantics(
                child: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
                    color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );

    return TicketCard(
      onTap: onTap,
      semanticLabel: [
        name,
        if (branch.isDefault) l10n.branchDefault,
        l10n.branchStatusName(branch.status),
        place,
        l10n.branchUpcomingBookings(branch.upcomingBookings),
      ].join(l10n.adminListSeparator),
      stub: stub,
      child: top,
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.text, this.label});

  final String text;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final name = switch (label) {
      'صباحي' => l10n.branchPeriodMorning,
      'مسائي' => l10n.branchPeriodEvening,
      final other => other,
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          name == null ? text : '$name  $text',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _BranchesSkeleton extends StatelessWidget {
  const _BranchesSkeleton({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: ResponsiveGrid(columns: 3, minColumnWidth: 320, children: [for (var i = 0; i < 3; i++) BranchTicket.placeholder()]),
        ),
      );
}
