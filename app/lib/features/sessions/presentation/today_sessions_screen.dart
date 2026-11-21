import 'package:material_ui/material_ui.dart';
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
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/sessions_providers.dart';
import '../domain/session_models.dart';
import 'widgets/session_widgets.dart';

/// D2: one Cairo day's sessions (today by default, or the day tapped in D3),
/// newest first, for the whole clinic or one branch. Rows show the time,
/// patient, type badge, fee, who recorded it and «بانتظار الطبيب» (BR-AS7);
/// filters by type and by who recorded; totals in the footer. Assistants see
/// their branches only (BR-AS13). Tap a row for D9.
class TodaySessionsScreen extends ConsumerStatefulWidget {
  const TodaySessionsScreen({super.key, this.day});

  /// Null: today (Cairo).
  final DateTime? day;

  @override
  ConsumerState<TodaySessionsScreen> createState() => _TodaySessionsScreenState();
}

class _TodaySessionsScreenState extends ConsumerState<TodaySessionsScreen> {
  late DateTime _day = widget.day ?? ClinicFormat.today();
  SessionType? _type;
  String? _recordedBy;
  String? _branchId;

  DateTime get _today => ClinicFormat.today();
  bool get _isToday => _day == _today;

  DayQuery get _query => (day: _isToday ? null : _day, branchId: _branchId, type: _type, recordedBy: _recordedBy);

  /// The same day without the type and recorder filters, for the recorder choices.
  DayQuery get _unfiltered => (day: _isToday ? null : _day, branchId: _branchId, type: null, recordedBy: null);

  void _setDay(DateTime day) => setState(() {
        _day = day;
        _recordedBy = null;
      });

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.utc(_today.year - 3),
      lastDate: _today,
    );
    if (picked != null) _setDay(DateTime.utc(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.sessionsCreate) && !clinic.can(ClinicPermission.billingView)) {
            return AdminErrorView(error: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.permissionDenied));
          }
          return LayoutBuilder(
            builder: (context, constraints) => _content(context, clinic, paths, constraints.maxWidth),
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, ClinicContext clinic, ClinicPaths paths, double width) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final gutter = clinicGutter(width);
    final wide = width >= 900;
    final day = ref.watch(daySessionsProvider(_query));
    final all = ref.watch(daySessionsProvider(_unfiltered)).value;
    final canNew = clinic.can(ClinicPermission.sessionsCreate) && !clinic.isSuspended && _isToday;
    final branches = clinic.isDoctor ? clinic.branches : clinic.workBranches;

    // Who recorded sessions this day: the doctor and the assistants (BR-AS6).
    final recorders = <String, RecordedBy>{for (final item in all?.items ?? const <SessionListItem>[]) item.recordedBy.userId: item.recordedBy};
    String recorderName(String id) => recorders[id]!.isAssistant ? recorders[id]!.name : l10n.sessionRecordedByDoctor;

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<SessionType?>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: null, label: Text(l10n.patientFilterAny)),
            ButtonSegment(value: SessionType.examination, label: Text(l10n.sessionTypeExamination)),
            ButtonSegment(value: SessionType.consultation, label: Text(l10n.sessionTypeConsultation)),
          ],
          selected: {_type},
          onSelectionChanged: (value) => setState(() => _type = value.first),
        ),
        if (recorders.length > 1 || _recordedBy != null)
          _ChoiceMenu<String?>(
            icon: Icons.person_outline,
            label: _recordedBy == null ? l10n.sessionRecordedByAll : l10n.sessionRecordedBy(recorderName(_recordedBy!)),
            selected: _recordedBy != null,
            values: [null, ...recorders.keys],
            current: _recordedBy,
            itemLabel: (id) => id == null ? l10n.sessionRecordedByAll : recorderName(id),
            onSelected: (id) => setState(() => _recordedBy = id),
          ),
        if (branches.length > 1)
          _ChoiceMenu<String?>(
            icon: Icons.store_mall_directory_outlined,
            label: _branchId == null ? l10n.patientFilterAllBranches : clinic.branch(_branchId)!.name(language),
            selected: _branchId != null,
            values: [null, for (final b in branches) b.id],
            current: _branchId,
            itemLabel: (id) => id == null ? l10n.patientFilterAllBranches : clinic.branch(id)!.name(language),
            onSelected: (id) => setState(() {
              _branchId = id;
              _recordedBy = null;
            }),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
          child: ClinicHeader(
            title: _isToday ? l10n.sessionTodayTitle : l10n.sessionDayTitle,
            subtitle: ClinicFormat.dayWithWeekday(context, _day),
            backFallback: paths.dashboard,
            actions: [
              if (canNew && wide)
                FilledButton.icon(
                  onPressed: () => context.push(paths.dashboardNewSession),
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(l10n.sessionNew),
                )
              else if (canNew)
                IconButton.filledTonal(
                  tooltip: l10n.sessionNew,
                  onPressed: () => context.push(paths.dashboardNewSession),
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: _DayPicker(
            day: _day,
            today: _today,
            onDay: _setDay,
            onPick: _pickDay,
          ),
        ),
        const SizedBox(height: 8),
        Padding(padding: EdgeInsets.symmetric(horizontal: gutter), child: ClinicChips(child: filters)),
        const SizedBox(height: 12),
        Expanded(
          child: AsyncStateSwitcher<DaySessions>(
            value: day,
            isEmpty: (data) => data.items.isEmpty,
            loading: (context) => SkeletonLoading(
              loading: true,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: gutter),
                children: [GroupedRows(children: [for (var i = 0; i < 5; i++) DaySessionRow.placeholder(wide: wide)])],
              ),
            ),
            error: (context, error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(daySessionsProvider(_query))),
            empty: (context) => EmptyState(
              title: _type != null || _recordedBy != null ? l10n.sessionDayNoMatch : l10n.sessionDayEmptyTitle,
              message: canNew ? l10n.sessionDayEmptyBody : null,
              actionLabel: canNew ? l10n.sessionNew : null,
              onAction: canNew ? () => context.push(paths.dashboardNewSession) : null,
            ),
            data: (context, data) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(daySessionsProvider),
              child: StaggerGroup(
                key: ValueKey('$_day$_type$_recordedBy$_branchId'),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                  children: [
                    GroupedRows(
                      children: [
                        for (final (i, item) in data.items.indexed)
                          StaggeredEntrance(
                            index: i,
                            child: DaySessionRow(
                              item: item,
                              wide: wide,
                              onTap: () => context.push(paths.dashboardSession(item.sessionId)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (day.value != null && day.value!.items.isNotEmpty) _TotalsFooter(data: day.value!, gutter: gutter),
      ],
    );
  }
}

/// Previous day, the date (tap to pick), next day (not after today).
class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.day, required this.today, required this.onDay, required this.onPick});

  final DateTime day;
  final DateTime today;
  final ValueChanged<DateTime> onDay;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isToday = day == today;
    // Chevrons follow the reading direction: "previous" points back.
    return Row(
      children: [
        IconButton(
          tooltip: l10n.sessionPreviousDay,
          onPressed: () => onDay(day.subtract(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_left),
        ),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(isToday ? l10n.sessionToday : ClinicFormat.day(context, day)),
        ),
        IconButton(
          tooltip: l10n.sessionNextDay,
          onPressed: isToday ? null : () => onDay(day.add(const Duration(days: 1))),
          icon: const Icon(Icons.chevron_right),
        ),
        if (!isToday)
          TextButton(onPressed: () => onDay(today), child: Text(l10n.sessionBackToToday)),
      ],
    );
  }
}

/// «2 كشف + 3 استشارة = 105 ج.م» for exactly the rows listed, and the amount
/// charged with `revenueView`.
class _TotalsFooter extends StatelessWidget {
  const _TotalsFooter({required this.data, required this.gutter});

  final DaySessions data;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final charged = data.amountChargedTotalPiasters;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + MediaQuery.paddingOf(context).bottom),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.feesPlatformFees, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(feeEquation(context, data.totals), style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              if (charged != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.feesCollected, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(AppFormat.egp(context, charged), style: theme.textTheme.titleMedium),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceMenu<T> extends StatelessWidget {
  const _ChoiceMenu({
    required this.icon,
    required this.label,
    required this.selected,
    required this.values,
    required this.current,
    required this.itemLabel,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final List<T> values;
  final T current;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => MenuAnchor(
        menuChildren: [
          for (final value in values)
            MenuItemButton(
              leadingIcon: Icon(value == current ? Icons.check : null, size: 20),
              onPressed: () => onSelected(value),
              child: Text(itemLabel(value)),
            ),
        ],
        builder: (context, controller, _) => FilterChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => controller.isOpen ? controller.close() : controller.open(),
        ),
      );
}
