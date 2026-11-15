import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/admin_controllers.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';
import 'setting_labels.dart';

/// AD13 "Change history": one setting's ([field]) or every setting's
/// changes, newest first. A dialog on wide screens, a sheet on phones.
Future<void> showSettingHistory(BuildContext context, {String? field}) {
  final wide = MediaQuery.sizeOf(context).width >= kAdminWideLayout;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
          child: SettingHistoryList(field: field, shrinkWrap: true),
        ),
      ),
    );
  }
  final content = SettingHistoryList(field: field);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(heightFactor: 0.85, child: content),
  );
}

class SettingHistoryList extends ConsumerWidget {
  const SettingHistoryList({super.key, this.field, this.shrinkWrap = false});

  final String? field;

  /// In a dialog: as tall as the entries (up to the dialog's limit).
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final provider = settingsHistoryProvider(field ?? '');
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final list = Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(l10n.adminHistoryTitle, style: theme.textTheme.titleLarge),
                    ),
                    Text(
                      field == null ? l10n.adminHistoryAll : l10n.settingLabel(field!),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.adminClose,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(),
        Flexible(
          fit: shrinkWrap ? FlexFit.loose : FlexFit.tight,
          child: StateSwitcher(
            state: state.view,
            loading: (context) => SkeletonLoading(
              loading: true,
              child: ListView(
                shrinkWrap: shrinkWrap,
                physics: const NeverScrollableScrollPhysics(),
                children: [for (var i = 0; i < 3; i++) _HistoryTile.placeholder()],
              ),
            ),
            empty: (context) => EmptyState(title: l10n.adminHistoryEmptyTitle, message: l10n.adminHistoryEmptyBody),
            error: (context) => AdminErrorView(error: state.error!, onRetry: controller.reload),
            content: (context) => NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 300) controller.loadMore();
                return false;
              },
              child: StaggerGroup(
                child: ListView.separated(
                  shrinkWrap: shrinkWrap,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: state.items.length + (state.hasMore || state.moreError != null ? 1 : 0),
                  separatorBuilder: (context, _) => const Divider(indent: 24, endIndent: 24),
                  itemBuilder: (context, i) {
                    if (i == state.items.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: state.moreError != null
                            ? AdminErrorView(error: state.moreError!, onRetry: controller.loadMore, compact: true)
                            : SkeletonLoading(loading: true, child: _HistoryTile.placeholder()),
                      );
                    }
                    return StaggeredEntrance(
                      index: i,
                      child: _HistoryTile(entry: state.items[i], showField: field == null),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return shrinkWrap ? ConstrainedBox(constraints: const BoxConstraints(minHeight: 240), child: list) : list;
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.entry, this.showField = false});

  static Widget placeholder() => _HistoryTile(
        entry: SettingsHistoryEntry(
          id: '',
          field: 'examFeePiasters',
          before: '------',
          after: '------',
          changedByName: '------------',
          changedAt: DateTime.now(),
        ),
        showField: true,
      );

  final SettingsHistoryEntry entry;
  final bool showField;

  Future<void> _showFull(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final full = await ref.read(adminRepositoryProvider).settingsHistoryEntry(entry.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.settingLabel(full.field)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 480),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InfoRow(label: l10n.adminHistoryBefore, value: settingValueText(context, full.field, full.before)),
                  const SizedBox(height: 16),
                  InfoRow(label: l10n.adminHistoryAfter, value: settingValueText(context, full.field, full.after)),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminClose))],
        ),
      );
    } catch (error) {
      if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget value(String? raw, {required bool after}) => Text(
          settingValueText(context, entry.field, raw),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: after ? scheme.onSurface : scheme.onSurfaceVariant,
            decoration: after ? null : TextDecoration.lineThrough,
            decorationColor: scheme.onSurfaceVariant,
          ),
        );
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showField) Text(l10n.settingLabel(entry.field), style: theme.textTheme.titleSmall),
            Text(
              l10n.adminHistoryChangedBy(entry.changedByName, AppFormat.dateTime(context, entry.changedAt)),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: value(entry.before, after: false)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Semantics(
                    label: l10n.adminHistoryChangedTo,
                    // Mirrors itself in Arabic: it always points from before to after.
                    child: Icon(Icons.arrow_forward, size: 18, color: scheme.primary),
                  ),
                ),
                Flexible(child: value(entry.after, after: true)),
              ],
            ),
            if (entry.truncated)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(onPressed: () => _showFull(context, ref), child: Text(l10n.adminHistoryShowFull)),
              ),
          ],
        ),
      ),
    );
  }
}
