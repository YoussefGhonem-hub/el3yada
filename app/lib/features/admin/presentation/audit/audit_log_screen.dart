import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/format/app_format.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../admin_routes.dart';
import '../../application/admin_controllers.dart';
import '../../../../core/data/paged_controller.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';
import 'audit_text.dart';

/// AD15: who did what and when, newest first, loaded page by page as you
/// scroll. Filters: action, who (role, or one person picked from a row),
/// target (type, or one record picked from a row) and dates (Cairo days).
/// A row opens to show its details. Desktop shows a table.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final _expanded = <int>{};
  int _generation = 0;

  AuditLogController get _controller => ref.read(auditLogControllerProvider.notifier);

  void _setFilter(AuditFilter filter) {
    _controller.setFilter(filter);
    setState(() {
      _expanded.clear();
      _generation++;
    });
  }

  Future<void> _pickDates(AuditFilter filter) async {
    final now = AppFormat.cairo(DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final from = filter.from == null ? null : AppFormat.cairo(filter.from!);
    final to = filter.to == null ? null : AppFormat.cairo(filter.to!.subtract(const Duration(hours: 1)));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: today,
      initialDateRange: from == null || to == null
          ? null
          : DateTimeRange(start: DateTime(from.year, from.month, from.day), end: DateTime(to.year, to.month, to.day)),
    );
    if (picked == null) return;
    final end = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
    _setFilter(filter.withDates(AppFormat.cairoDayStartUtc(picked.start), AppFormat.cairoDayStartUtc(end)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(auditLogControllerProvider);
    final filter = _controller.filter;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kAdminWideLayout;
        final gutter = adminGutter(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 12),
              child: AdminHeader(
                title: l10n.navAuditLog,
                subtitle: state.loading ? l10n.loading : l10n.adminAuditCount(state.totalCount),
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
              gutter: gutter,
              onChanged: _setFilter,
              onPickDates: () => _pickDates(filter),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StateSwitcher(
                state: state.view,
                loading: (context) => _AuditSkeleton(gutter: gutter, wide: wide),
                empty: (context) => EmptyState(
                  title: filter.isEmpty ? l10n.adminAuditEmptyTitle : l10n.adminAuditNoMatchTitle,
                  message: filter.isEmpty ? null : l10n.adminAuditNoMatchBody,
                  actionLabel: filter.isEmpty ? null : l10n.adminClearFilters,
                  onAction: filter.isEmpty ? null : () => _setFilter(const AuditFilter()),
                ),
                error: (context) => AdminErrorView(error: state.error!, onRetry: _controller.reload),
                content: (context) => _list(context, state, wide: wide, gutter: gutter),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, PagedState<AuditEntry> state, {required bool wide, required double gutter}) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = state.items;
    final bottom = 16 + MediaQuery.paddingOf(context).bottom;

    Widget footer() {
      if (state.moreError != null) {
        return AdminErrorView(error: state.moreError!, onRetry: _controller.loadMore, compact: true);
      }
      if (state.hasMore || state.loadingMore) {
        return SkeletonLoading(loading: true, child: _AuditRow.placeholder(wide: wide));
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          l10n.adminAuditEnd,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    Widget row(int i) {
      final entry = items[i];
      return StaggeredEntrance(
        index: i,
        child: _AuditRow(
          entry: entry,
          wide: wide,
          expanded: _expanded.contains(entry.id),
          onToggle: () => setState(() => _expanded.contains(entry.id) ? _expanded.remove(entry.id) : _expanded.add(entry.id)),
          onFilter: _setFilter,
          filter: _controller.filter,
        ),
      );
    }

    final list = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 500) _controller.loadMore();
        return false;
      },
      child: StaggerGroup(
        key: ValueKey(_generation),
        child: wide
            ? ListView.builder(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
                itemCount: items.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) return const _TableHeader();
                  if (i == items.length + 1) return footer();
                  return row(i - 1);
                },
              )
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
                itemCount: items.length + 1,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => i == items.length ? footer() : row(i),
              ),
      ),
    );
    return RefreshIndicator(onRefresh: _controller.refresh, child: list);
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.gutter, required this.onChanged, required this.onPickDates});

  final AuditFilter filter;
  final double gutter;
  final ValueChanged<AuditFilter> onChanged;
  final VoidCallback onPickDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    String? dates;
    if (filter.from != null && filter.to != null) {
      final format = DateFormat.MMMd(locale);
      final from = format.format(AppFormat.cairo(filter.from!));
      final to = format.format(AppFormat.cairo(filter.to!.subtract(const Duration(hours: 1))));
      dates = from == to ? from : l10n.adminDateRange(from, to);
    }
    final chips = <Widget>[
      _FilterMenu(
        icon: Icons.bolt_outlined,
        label: filter.action == null ? l10n.adminFilterAction : l10n.auditActionName(filter.action!),
        active: filter.action != null,
        allLabel: l10n.adminFilterAllActions,
        options: {for (final action in AuditActions.all) action: l10n.auditActionName(action)},
        onSelected: (value) => onChanged(filter.withAction(value)),
      ),
      _FilterMenu(
        icon: Icons.person_search_outlined,
        label: filter.actorRole == null ? l10n.adminFilterWho : l10n.auditActorRole(filter.actorRole!),
        active: filter.actorRole != null,
        allLabel: l10n.adminFilterEveryone,
        options: {for (final role in AuditActions.actorRoles) role: l10n.auditActorRole(role)},
        onSelected: (value) => onChanged(filter.withActorRole(value)),
      ),
      if (filter.targetId == null)
        _FilterMenu(
          icon: Icons.track_changes_outlined,
          label: filter.targetType == null ? l10n.adminFilterTarget : l10n.auditTargetType(filter.targetType!),
          active: filter.targetType != null,
          allLabel: l10n.adminFilterAllTargets,
          options: {for (final type in AuditActions.targetTypes) type: l10n.auditTargetType(type)},
          onSelected: (value) => onChanged(filter.withTargetType(value)),
        ),
      _DatesButton(
        label: dates ?? l10n.adminFilterDates,
        active: dates != null,
        onPressed: onPickDates,
        onClear: dates == null ? null : () => onChanged(filter.withDates(null, null)),
      ),
      if (filter.actorUserId != null)
        InputChip(
          avatar: const Icon(Icons.person_outline, size: 18),
          label: Text(l10n.adminFilterBy(filter.actorName ?? '')),
          selected: true,
          showCheckmark: false,
          onDeleted: () => onChanged(filter.withActor(null, null)),
          deleteButtonTooltipMessage: l10n.adminClearFilter,
        ),
      if (filter.targetId != null)
        InputChip(
          avatar: const Icon(Icons.track_changes_outlined, size: 18),
          label: Text(filter.targetLabel ?? filter.targetId!),
          selected: true,
          showCheckmark: false,
          onDeleted: () => onChanged(filter.withTarget(null, null, null)),
          deleteButtonTooltipMessage: l10n.adminClearFilter,
        ),
      if (!filter.isEmpty)
        TextButton(onPressed: () => onChanged(const AuditFilter()), child: Text(l10n.adminClearFilters)),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        children: [
          for (final chip in chips) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: chip),
        ],
      ),
    );
  }
}

/// A chip that opens a menu: "All" first, then [options] (value → label).
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
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

/// The date range filter: opens the date picker; a set range has a clear button.
class _DatesButton extends StatelessWidget {
  const _DatesButton({required this.label, required this.active, required this.onPressed, this.onClear});

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
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: _ChipFace(icon: Icons.date_range_outlined, label: label, active: active),
          ),
        ),
        if (onClear != null)
          IconButton(
            tooltip: l10n.adminClearFilter,
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
      ],
    );
  }
}

/// How the filter buttons look: a pill, filled when its filter is set.
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

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget cell(String text) => Semantics(header: true, child: Text(text, style: style));
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 176, child: cell(l10n.adminColumnWhen)),
          Expanded(flex: 3, child: cell(l10n.adminColumnWho)),
          Expanded(flex: 5, child: cell(l10n.adminColumnWhat)),
          Expanded(flex: 2, child: cell(l10n.adminColumnTarget)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

IconData _actionIcon(String action) => switch (action) {
      'doctorRegistrationSubmitted' || 'doctorRegistrationResubmitted' => Icons.assignment_outlined,
      'doctorRegistrationApproved' => Icons.how_to_reg_outlined,
      'doctorRegistrationRejected' => Icons.person_off_outlined,
      'doctorLicenseViewed' => Icons.badge_outlined,
      'adminSeeded' || 'adminCreated' || 'adminRoleChanged' || 'adminProfileUpdated' => Icons.admin_panel_settings_outlined,
      'adminDisabled' => Icons.block,
      'adminEnabled' => Icons.check_circle_outline,
      'settingsUpdated' => Icons.tune,
      'accountLockedOut' || 'refreshTokenReuseDetected' => Icons.lock_outline,
      'emailVerified' => Icons.mark_email_read_outlined,
      _ => Icons.key_outlined,
    };

class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.entry,
    required this.wide,
    required this.expanded,
    required this.onToggle,
    required this.onFilter,
    required this.filter,
  });

  static Widget placeholder({required bool wide}) => _AuditRow(
        entry: AuditEntry(
          id: -1,
          at: DateTime.now(),
          actorRole: 'admin',
          actorName: '------------',
          action: 'settingsUpdated',
          targetType: 'settings',
        ),
        wide: wide,
        expanded: false,
        onToggle: () {},
        onFilter: (_) {},
        filter: const AuditFilter(),
      );

  final AuditEntry entry;
  final bool wide;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<AuditFilter> onFilter;
  final AuditFilter filter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sentence = l10n.auditSentence(entry);
    final actor = l10n.auditActor(entry);
    final role = l10n.auditActorRole(entry.actorRole);
    final system = entry.actorRole == 'system';
    final when = AppFormat.dateTime(context, entry.at);
    final relative = AppFormat.relative(context, entry.at);
    final chevron = AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
      child: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
    );
    final details = AdminAnimatedSize(
      child: expanded ? _AuditDetails(entry: entry, onFilter: onFilter, filter: filter) : const SizedBox(width: double.infinity),
    );

    final Widget summary;
    if (wide) {
      summary = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 176,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(when, style: theme.textTheme.bodyMedium),
                  Text(relative, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  if (system)
                    ExcludeSemantics(
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: scheme.surfaceContainerHigh,
                        child: Icon(Icons.settings_suggest_outlined, size: 18, color: scheme.onSurfaceVariant),
                      ),
                    )
                  else
                    InitialAvatar(name: actor, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(actor, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                        if (!system)
                          Text(role, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Icon(_actionIcon(entry.action), size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(sentence, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(l10n.auditTargetType(entry.targetType), style: theme.textTheme.bodyMedium)),
            SizedBox(width: 40, child: chevron),
          ],
        ),
      );
    } else {
      summary = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(_actionIcon(entry.action), size: 20, color: scheme.onPrimaryContainer),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sentence, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    system ? actor : '$actor · $role',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(relative, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            chevron,
          ],
        ),
      );
    }

    final tappable = Semantics(
      button: true,
      expanded: expanded,
      label: '$sentence${l10n.adminListSeparator}$actor${l10n.adminListSeparator}$when',
      excludeSemantics: true,
      child: InkWell(onTap: onToggle, child: summary),
    );
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tappable, details]);
    if (wide) {
      return Material(
        color: expanded ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
          child: content,
        ),
      );
    }
    return Card(clipBehavior: Clip.antiAlias, child: content);
  }
}

class _AuditDetails extends StatelessWidget {
  const _AuditDetails({required this.entry, required this.onFilter, required this.filter});

  final AuditEntry entry;
  final ValueChanged<AuditFilter> onFilter;
  final AuditFilter filter;

  String _json() => const JsonEncoder.withIndent('  ').convert({
        'id': entry.id,
        'at': entry.at.toIso8601String(),
        'actorUserId': entry.actorUserId,
        'actorRole': entry.actorRole,
        'actorName': entry.actorName,
        'action': entry.action,
        'targetType': entry.targetType,
        'targetId': entry.targetId,
        'doctorId': entry.doctorId,
        'details': entry.details,
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final details = entry.details ?? const {};
    final actor = l10n.auditActor(entry);
    final targetLabel = '${l10n.auditTargetType(entry.targetType)} · ${entry.targetId ?? ''}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          ResponsiveGrid(
            columns: 3,
            minColumnWidth: 200,
            children: [
              for (final MapEntry(:key, :value) in details.entries)
                InfoRow(label: l10n.auditDetailLabel(key), value: l10n.auditDetailValue(key, value)),
              InfoRow(label: l10n.adminColumnTarget, value: entry.targetId == null ? null : targetLabel),
              InfoRow(label: l10n.adminColumnWhen, value: AppFormat.dateTime(context, entry.at)),
              InfoRow(label: l10n.adminEntryNumber, value: '#${entry.id}', ltr: true),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (entry.actorUserId != null && filter.actorUserId != entry.actorUserId)
                TextButton.icon(
                  onPressed: () => onFilter(filter.withActor(entry.actorUserId, actor)),
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: Text(l10n.adminOnlyThisPerson),
                ),
              if (entry.targetId != null && filter.targetId != entry.targetId)
                TextButton.icon(
                  onPressed: () => onFilter(filter.withTarget(entry.targetType, entry.targetId, targetLabel)),
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: Text(l10n.adminOnlyThisRecord),
                ),
              if (entry.targetType == 'doctor' && entry.targetId != null)
                TextButton.icon(
                  onPressed: () => context.go(AdminRoutes.signup(entry.targetId!)),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.adminOpenRegistration),
                ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _json()));
                  if (context.mounted) showAdminSnack(context, l10n.adminCopiedDetails);
                },
                icon: const Icon(Icons.copy_outlined),
                label: Text(l10n.adminCopyDetails),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditSkeleton extends StatelessWidget {
  const _AuditSkeleton({required this.gutter, required this.wide});

  final double gutter;
  final bool wide;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          itemCount: 8,
          separatorBuilder: (context, _) => SizedBox(height: wide ? 0 : 10),
          itemBuilder: (context, _) => _AuditRow.placeholder(wide: wide),
        ),
      );
}
