import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/application/clinic_providers.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/application/patients_providers.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../../sessions/application/sessions_providers.dart';
import '../../sessions/domain/session_models.dart';
import '../../sessions/presentation/widgets/session_widgets.dart';

/// The doctor's home (D34) and AS1 until the live board arrives.
///
/// Phase 6 replaces it with the live board (section 6.13) for the doctor and
/// for assistants with `appointmentsView`. Until then everyone gets AS1's
/// "without `appointmentsView`" home: quick actions by permission (Add
/// patient, New session, Search patient; Scan comes in Phase 3, Unread chats
/// in Phase 5), today's fee card (`billingView`), and today's sessions in the
/// current branch (BR-BR3; `sessionsCreate`).
class ClinicHomeScreen extends ConsumerWidget {
  const ClinicHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClinicGate(
        builder: (context, clinic) => LayoutBuilder(
          builder: (context, constraints) => _HomeContent(clinic: clinic, width: constraints.maxWidth),
        ),
      );
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent({required this.clinic, required this.width});

  final ClinicContext clinic;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final paths = ref.watch(clinicPathsProvider);
    final branch = ref.watch(currentBranchProvider);
    final gutter = clinicGutter(width);
    final wide = width >= 900;
    final suspended = clinic.isSuspended;
    final showSessions = clinic.can(ClinicPermission.sessionsCreate) && branch != null;
    final billing = clinic.can(ClinicPermission.billingView);
    final DayQuery query = (day: null, branchId: branch?.id, type: null, recordedBy: null);

    final actions = <_QuickAction>[
      if (clinic.can(ClinicPermission.patientsManage) && !suspended)
        _QuickAction(icon: Icons.person_add_alt_1_rounded, label: l10n.patientAdd, onTap: () => context.go(paths.addPatient)),
      if (clinic.can(ClinicPermission.sessionsCreate) && !suspended)
        _QuickAction(icon: Icons.add_rounded, label: l10n.sessionNew, primary: true, onTap: () => context.push(paths.homeNewSession)),
      _QuickAction(
        icon: Icons.person_search_rounded,
        label: l10n.homeSearchPatient,
        onTap: () {
          ref.read(registerSearchRequestProvider.notifier).request();
          context.go(paths.patients);
        },
      ),
    ];

    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

    final sessions = !showSessions
        ? null
        : AsyncStateSwitcher<DaySessions>(
            value: ref.watch(daySessionsProvider(query)),
            isEmpty: (data) => data.items.isEmpty,
            loading: (context) => SkeletonLoading(
              loading: true,
              child: GroupedRows(children: [for (var i = 0; i < 3; i++) DaySessionRow.placeholder(wide: wide)]),
            ),
            error: (context, error) => AdminErrorView(error: error, compact: true, onRetry: () => ref.invalidate(daySessionsProvider(query))),
            empty: (context) => Card(
              child: EmptyState(
                title: l10n.homeNoSessionsTitle,
                message: suspended ? null : l10n.homeNoSessionsBody,
                actionLabel: suspended ? null : l10n.sessionNew,
                onAction: suspended ? null : () => context.push(paths.homeNewSession),
              ),
            ),
            data: (context, data) => GroupedRows(
              children: [
                for (final (i, item) in data.items.indexed)
                  StaggeredEntrance(
                    index: i,
                    child: DaySessionRow(item: item, wide: wide, onTap: () => context.push(paths.homeSession(item.sessionId))),
                  ),
              ],
            ),
          );

    final fees = !billing
        ? null
        : AsyncStateSwitcher<FeeSummary>(
            value: ref.watch(feeSummaryProvider),
            loading: (context) => SkeletonLoading(loading: true, child: FeeCard(title: l10n.feesToday, totals: FeeTotals.zero)),
            error: (context, error) => AdminErrorView(error: error, compact: true, onRetry: () => ref.invalidate(feeSummaryProvider)),
            data: (context, data) => FeeCard(
              title: l10n.feesToday,
              totals: data.today,
              highlight: true,
              onTap: () => context.go(paths.today()),
            ),
          );

    final header = enter(ClinicHeader(
      title: l10n.homeToday,
      subtitle: [
        ClinicFormat.dayWithWeekday(context, ClinicFormat.today()),
        if (branch != null) branch.name(language),
      ].join(l10n.adminListSeparator),
    ));
    final quick = enter(_QuickActions(actions: actions));
    final sessionsTitle = Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
      child: Semantics(
        header: true,
        child: Text(
          branch == null ? l10n.homeTodaySessions : l10n.homeTodaySessionsIn(branch.name(language)),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );

    final List<Widget> children;
    if (wide && fees != null) {
      children = [
        header,
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [quick, if (sessions != null) ...[const SizedBox(height: 24), sessionsTitle, enter(sessions)]],
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(width: 360, child: enter(fees)),
          ],
        ),
      ];
    } else {
      children = [
        header,
        const SizedBox(height: 20),
        quick,
        if (fees != null) ...[const SizedBox(height: 20), enter(fees)],
        if (sessions != null) ...[const SizedBox(height: 24), sessionsTitle, enter(sessions)],
      ];
    }

    return RefreshIndicator(
      onRefresh: () async => refreshFees(ref),
      child: StaggerGroup(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24 + MediaQuery.paddingOf(context).bottom),
          children: children,
        ),
      ),
    );
  }
}

/// One quick action: an icon in a tinted tile over a bold label. New
/// session is a pine gradient with a soft glow.
class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.action, required this.theme, required this.scheme});

  final _QuickAction action;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final primary = action.primary;
    final dark = theme.brightness == Brightness.dark;
    final onTile = primary ? (dark ? scheme.onPrimary : Colors.white) : scheme.onSurface;
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: primary ? null : scheme.surfaceContainerLow,
        gradient: primary
            ? LinearGradient(
                begin: AlignmentDirectional.topStart.resolve(Directionality.of(context)),
                end: AlignmentDirectional.bottomEnd.resolve(Directionality.of(context)),
                colors: dark ? [scheme.primary, const Color(0xFF4FC7A6)] : const [Color(0xFF1B6B5D), Color(0xFF0B3D37)],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: primary ? scheme.primary.withValues(alpha: 0.30) : scheme.shadow.withValues(alpha: 0.05),
            blurRadius: primary ? 16 : 10,
            spreadRadius: primary ? -4 : 0,
            offset: Offset(0, primary ? 8 : 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary ? Colors.white.withValues(alpha: dark ? 0.22 : 0.16) : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(action.icon, size: 19, color: primary ? onTile : scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 10),
          Text(action.label, style: theme.textTheme.titleSmall?.copyWith(color: onTile)),
        ],
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
}

/// Big, thumb-sized tiles; New session is the pine one.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 280 ? 1 : actions.length.clamp(1, 3);
        final spacing = 10.0;
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: tileWidth,
                child: Pressable(
                  onTap: action.onTap,
                  semanticLabel: action.label,
                  borderRadius: BorderRadius.circular(18),
                  child: _QuickTile(action: action, theme: theme, scheme: scheme),
                ),
              ),
          ],
        );
      },
    );
  }
}
