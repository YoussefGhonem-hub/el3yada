import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/data/paged_controller.dart';
import '../../../../core/format/app_format.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../clinic/application/clinic_providers.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../domain/activity_models.dart';
import '../../domain/assistant_models.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'activity_text.dart';

/// D27: everything done in the clinic by the doctor and the assistants
/// (BR-AS10), newest first and grouped by Cairo day, loaded page by page.
/// Each row reads as a sentence with who and when under it; tapping opens
/// the related item. Filters: person, action, dates, and a patient picked
/// from a row.
class ActivityLogScreen extends ConsumerStatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  ConsumerState<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends ConsumerState<ActivityLogScreen> {
  int _generation = 0;

  ActivityLogController get _controller => ref.read(activityLogProvider.notifier);

  void _setFilter(ActivityFilter filter) {
    _controller.setFilter(filter);
    setState(() => _generation++);
  }

  Future<void> _pickDates(ActivityFilter filter) async {
    final now = AppFormat.cairo(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: today,
      initialDateRange: filter.from == null || filter.to == null ? null : DateTimeRange(start: filter.from!, end: filter.to!),
    );
    if (picked != null) _setFilter(filter.withDates(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(activityLogProvider);
    final filter = _controller.filter;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 12),
              child: AdminHeader(
                title: l10n.navActivityLog,
                subtitle: state.loading ? l10n.loading : l10n.activityCount(state.totalCount),
                actions: [
                  IconButton(
                    tooltip: l10n.adminRefresh,
                    onPressed: state.loading || state.refreshing ? null : () => _setFilter(filter),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            _FilterBar(
              filter: filter,
              people: _controller.people,
              actions: _controller.actions,
              gutter: gutter,
              onChanged: _setFilter,
              onPickDates: () => _pickDates(filter),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StateSwitcher(
                state: state.view,
                loading: (context) => _ActivitySkeleton(gutter: gutter),
                empty: (context) => EmptyState(
                  title: filter.isEmpty ? l10n.activityEmptyTitle : l10n.adminAuditNoMatchTitle,
                  message: filter.isEmpty ? l10n.activityEmptyBody : l10n.adminAuditNoMatchBody,
                  actionLabel: filter.isEmpty ? null : l10n.adminClearFilters,
                  onAction: filter.isEmpty ? null : () => _setFilter(const ActivityFilter()),
                ),
                error: (context) => AdminErrorView(error: state.error!, onRetry: _controller.reload),
                content: (context) => _list(context, state, gutter: gutter),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, PagedState<ActivityEntry> state, {required double gutter}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final clinic = ref.watch(clinicContextProvider).value;
    final names = ActivityNames(
      branches: {for (final b in clinic?.branches ?? const []) b.id: b.name(language)},
      people: {for (final p in _controller.people) p.userId: p.name},
    );

    // Rows with a day heading before the first row of each Cairo day.
    final rows = <Object>[];
    DateTime? day;
    for (final entry in state.items) {
      final cairo = AppFormat.cairo(entry.at);
      final thisDay = DateTime(cairo.year, cairo.month, cairo.day);
      if (thisDay != day) {
        rows.add(thisDay);
        day = thisDay;
      }
      rows.add(entry);
    }

    Widget footer() {
      if (state.moreError != null) return AdminErrorView(error: state.moreError!, onRetry: _controller.loadMore, compact: true);
      if (state.hasMore || state.loadingMore) return SkeletonLoading(loading: true, child: _ActivityRow.placeholder());
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          l10n.adminAuditEnd,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    var index = 0;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 500) _controller.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: StaggerGroup(
          key: ValueKey(_generation),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16 + MediaQuery.paddingOf(context).bottom),
            itemCount: rows.length + 1,
            itemBuilder: (context, i) {
              Widget frame(Widget child) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: SizedBox(width: double.infinity, child: child),
                    ),
                  );
              if (i == rows.length) return frame(footer());
              final row = rows[i];
              final Widget child;
              if (row is DateTime) {
                child = _DayHeading(day: row);
              } else {
                final entry = row as ActivityEntry;
                child = StaggeredEntrance(
                  index: index++,
                  child: _ActivityRow(
                    entry: entry,
                    names: names,
                    onFilterPatient: (patient) => _setFilter(_controller.filter.withPatient(patient.id, patient.name)),
                  ),
                );
              }
              return frame(child);
            },
          ),
        ),
      ),
    );
  }
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = AppFormat.cairo(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    final text = switch (difference) {
      0 => l10n.activityToday,
      1 => l10n.activityYesterday,
      _ => DateFormat.yMMMMEEEEd(Localizations.localeOf(context).languageCode).format(day),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 8, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry, required this.names, this.onFilterPatient});

  static Widget placeholder() => _ActivityRow(
        entry: ActivityEntry(
          id: -1,
          at: DateTime.now(),
          actor: const ActivityActor(name: '------------', role: 'doctor'),
          action: 'branchUpdated',
          targetType: 'branch',
        ),
        names: const ActivityNames(),
      );

  final ActivityEntry entry;
  final ActivityNames names;
  final ValueChanged<ActivityPatient>? onFilterPatient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sentence = l10n.activitySentence(entry, names);
    final detail = l10n.activityDetail(context, entry);
    final actor = entry.actor.isSystem ? l10n.adminSystem : (entry.actor.name ?? l10n.adminUnknownUser);
    final who = entry.actor.isSystem ? actor : '$actor (${l10n.activityRole(entry.actor.role)})';
    final when = AppFormat.dateTime(context, entry.at);
    final path = activityTargetPath(entry);
    final patient = entry.patient;
    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RowIcon(activityIcon(entry.action), muted: entry.actor.isSystem),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sentence, style: theme.textTheme.titleSmall),
                if (detail != null && detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(detail, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 4),
                Text(
                  l10n.activityWhoWhen(who, AppFormat.relative(context, entry.at)),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (patient != null) ...[
                  const SizedBox(height: 8),
                  ActionChip(
                    avatar: const Icon(Icons.person_outline, size: 18),
                    label: Text(patient.name == null
                        ? l10n.activityPatientUnlinked
                        : patient.fileNumber == null
                            ? patient.name!
                            : l10n.activityPatientFile(patient.name!, patient.fileNumber!)),
                    tooltip: l10n.activityOnlyThisPatient,
                    onPressed: onFilterPatient == null ? null : () => onFilterPatient!(patient),
                  ),
                ],
              ],
            ),
          ),
          if (path != null)
            ExcludeSemantics(
              child: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
                  color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
    final card = Card(child: content);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: path == null
          ? MergeSemantics(child: Semantics(label: '$sentence. $who. $when', excludeSemantics: patient == null, child: card))
          : Pressable(
              onTap: () => context.go(path),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              semanticLabel: '$sentence. $who. $when',
              child: card,
            ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.people,
    required this.actions,
    required this.gutter,
    required this.onChanged,
    required this.onPickDates,
  });

  final ActivityFilter filter;
  final List<ActivityPerson> people;
  final List<String> actions;
  final double gutter;
  final ValueChanged<ActivityFilter> onChanged;
  final VoidCallback onPickDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    String? dates;
    if (filter.from != null && filter.to != null) {
      final format = DateFormat.MMMd(locale);
      final from = format.format(filter.from!);
      final to = format.format(filter.to!);
      dates = from == to ? from : l10n.adminDateRange(from, to);
    }
    String personLabel(ActivityPerson p) =>
        p.status == AssistantStatuses.removed ? l10n.activityRemovedPerson(p.name) : '${p.name} (${l10n.activityRole(p.role)})';
    final chips = <Widget>[
      _MenuChip(
        icon: Icons.person_search_outlined,
        label: filter.actorName ?? l10n.adminFilterWho,
        active: filter.actorUserId != null,
        allLabel: l10n.adminFilterEveryone,
        options: {for (final p in people) p.userId: personLabel(p)},
        onSelected: (id) => onChanged(filter.withActor(id, id == null ? null : people.firstWhere((p) => p.userId == id).name)),
      ),
      _MenuChip(
        icon: Icons.bolt_outlined,
        label: filter.action == null ? l10n.adminFilterAction : l10n.activityActionName(filter.action!),
        active: filter.action != null,
        allLabel: l10n.adminFilterAllActions,
        options: {for (final a in actions) a: l10n.activityActionName(a)},
        onSelected: (action) => onChanged(filter.withAction(action)),
      ),
      _ChipButton(
        icon: Icons.date_range_outlined,
        label: dates ?? l10n.adminFilterDates,
        active: dates != null,
        onPressed: onPickDates,
        onClear: dates == null ? null : () => onChanged(filter.withDates(null, null)),
      ),
      if (filter.patientId != null)
        InputChip(
          avatar: const Icon(Icons.person_outline, size: 18),
          label: Text(filter.patientName ?? l10n.activityPatientUnlinked),
          selected: true,
          showCheckmark: false,
          onDeleted: () => onChanged(filter.withPatient(null, null)),
          deleteButtonTooltipMessage: l10n.adminClearFilter,
        ),
      if (!filter.isEmpty) TextButton(onPressed: () => onChanged(const ActivityFilter()), child: Text(l10n.adminClearFilters)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(children: [for (final chip in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: chip)]),
    );
  }
}

/// A filter that opens a menu: "All" first, then [options] (value → label).
class _MenuChip extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.allLabel,
    required this.options,
    required this.onSelected,
  });

  static const _all = '';

  final IconData icon;
  final String label;
  final bool active;
  final String allLabel;
  final Map<String, String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: label,
        onSelected: (value) => onSelected(value == _all ? null : value),
        itemBuilder: (context) => [
          PopupMenuItem(value: _all, child: Text(allLabel)),
          const PopupMenuDivider(),
          for (final MapEntry(:key, :value) in options.entries) PopupMenuItem(value: key, child: Text(value)),
        ],
        child: _ChipFace(icon: icon, label: label, active: active),
      );
}

class _ChipButton extends StatelessWidget {
  const _ChipButton({required this.icon, required this.label, required this.active, required this.onPressed, this.onClear});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(customBorder: const StadiumBorder(), onTap: onPressed, child: _ChipFace(icon: icon, label: label, active: active)),
        ),
        if (onClear != null) IconButton(tooltip: l10n.adminClearFilter, onPressed: onClear, icon: const Icon(Icons.close, size: 18)),
      ],
    );
  }
}

class _ChipFace extends StatelessWidget {
  const _ChipFace({required this.icon, required this.label, required this.active});

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = active ? scheme.onSecondaryContainer : scheme.onSurface;
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 6, 6),
      decoration: ShapeDecoration(
        color: active ? scheme.secondaryContainer : scheme.surfaceContainerLow,
        shape: StadiumBorder(side: BorderSide(color: active ? scheme.secondaryContainer : scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground)),
          Icon(Icons.arrow_drop_down, color: foreground),
        ],
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          children: [for (var i = 0; i < 6; i++) _ActivityRow.placeholder()],
        ),
      );
}
