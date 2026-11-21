import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../app/routes.dart';
import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../admin/presentation/widgets/admin_widgets.dart';
import '../../../doctor_registration/presentation/registration_text.dart' show ltrIsolate;
import '../../application/admin_catalog_providers.dart';
import '../../application/catalog_providers.dart';
import '../../data/catalog_reader.dart';
import '../../domain/catalog_models.dart';
import '../catalog_text.dart';
import 'custom_item_dialog.dart';
import 'publish_catalog_dialog.dart';

/// AD20 Catalogs: the current version and publishing a new one, the
/// versions list, the admin's custom items (BR-CAT9) and the doctors'
/// reports [S] (BR-CAT8).
class CatalogsScreen extends ConsumerStatefulWidget {
  const CatalogsScreen({super.key, this.initialTab = 0});

  /// 0 versions, 1 custom items, 2 reports.
  final int initialTab;

  @override
  ConsumerState<CatalogsScreen> createState() => _CatalogsScreenState();
}

class _CatalogsScreenState extends ConsumerState<CatalogsScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final openReports = ref.watch(catalogReportsProvider('open')).value?.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 8),
              child: AdminHeader(
                title: l10n.navCatalogs,
                subtitle: l10n.adminCatalogSubtitle,
                actions: [
                  FilledButton.icon(
                    onPressed: () => showPublishCatalogDialog(context),
                    icon: const Icon(Icons.publish_outlined),
                    label: Text(l10n.adminCatalogPublish),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter - 8),
              child: TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: l10n.adminCatalogTabVersions),
                  Tab(text: l10n.adminCatalogTabCustom),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.adminCatalogTabReports),
                        if (openReports != null && openReports > 0) ...[
                          const SizedBox(width: 6),
                          Badge.count(count: openReports),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _VersionsTab(gutter: gutter),
                  _CustomItemsTab(gutter: gutter),
                  _ReportsTab(gutter: gutter),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _count(int value) => NumberFormat('#,##0', 'en').format(value);

// -----------------------------------------------------------------------------
// Versions

class _VersionsTab extends ConsumerWidget {
  const _VersionsTab({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final versions = ref.watch(catalogVersionsProvider);
    return AsyncStateSwitcher<List<CatalogVersionEntry>>(
      value: versions,
      loading: (context) => _ListSkeleton(gutter: gutter),
      error: (context, error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(catalogVersionsProvider)),
      data: (context, versions) {
        final current = versions.where((v) => v.current).firstOrNull;
        var index = 0;
        Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(catalogVersionsProvider.future),
          child: StaggerGroup(
            child: ListView(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                enter(current == null ? const _NothingPublished() : _CurrentVersionCard(entry: current)),
                const SizedBox(height: 12),
                enter(const _ThisDeviceCard()),
                if (versions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  enter(
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                      child: Semantics(
                        header: true,
                        child: Text(l10n.adminCatalogAllVersions, style: theme.textTheme.titleMedium),
                      ),
                    ),
                  ),
                  enter(
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final (i, entry) in versions.indexed) ...[
                            if (i > 0) const Divider(height: 1),
                            _VersionRow(entry: entry),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurrentVersionCard extends StatelessWidget {
  const _CurrentVersionCard({required this.entry});

  final CatalogVersionEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = entry.version;
    final stats = [
      (Icons.medication_outlined, l10n.catalogTypeDrugs, v.counts.drugs),
      (Icons.biotech_outlined, l10n.catalogTypeLabs, v.counts.labs),
      (Icons.settings_overscan_outlined, l10n.catalogTypeRadiologyPlural, v.counts.radiology),
    ];
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(18)),
                  child: Text(
                    'v${v.version}',
                    style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.adminCatalogCurrent,
                        style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.catalogVersionTitle('${v.version}'),
                        style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (v.publishedAt != null)
                            l10n.adminCatalogPublishedOn(AppFormat.date(context, v.publishedAt!)),
                          l10n.catalogSize(v.sizeBytes),
                          ?entry.publishedByName,
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (icon, label, value) in stats)
                  Container(
                    constraints: const BoxConstraints(minWidth: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 20, color: scheme.primary),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _count(value),
                              textDirection: TextDirection.ltr,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(label, style: theme.textTheme.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              [
                if (v.drugSourceDate != null) l10n.adminCatalogDrugSource(ltrIsolate(v.drugSourceDate!)),
                if (v.loincRelease != null) l10n.adminCatalogLoincRelease(ltrIsolate(v.loincRelease!)),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _NothingPublished extends StatelessWidget {
  const _NothingPublished();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InfoCard(
      icon: Icons.inventory_2_outlined,
      title: l10n.catalogNotPublished,
      body: l10n.adminCatalogNothingPublishedBody,
      action: FilledButton.icon(
        onPressed: () => showPublishCatalogDialog(context),
        icon: const Icon(Icons.publish_outlined),
        label: Text(l10n.adminCatalogPublish),
      ),
    );
  }
}

/// The catalog on the admin's own device (AD19 reads it), with D0.
class _ThisDeviceCard extends ConsumerWidget {
  const _ThisDeviceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(catalogControllerProvider);
    return InfoCard(
      icon: Icons.devices_outlined,
      title: l10n.adminCatalogThisDevice,
      body: catalogStatus(l10n, state),
      action: TextButton(
        onPressed: () => context.push(AppRoutes.catalogSetup),
        child: Text(l10n.adminCatalogOpenSetup),
      ),
    );
  }
}

/// A plain card: icon, title, a line, and an action at the end.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: scheme.secondaryContainer, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(icon, size: 20, color: scheme.onSecondaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      Text(body, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.entry});

  final CatalogVersionEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = entry.version;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              'v${v.version}',
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminCatalogCounts(_count(v.counts.drugs), _count(v.counts.labs), _count(v.counts.radiology)),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  [
                    if (v.publishedAt != null) AppFormat.date(context, v.publishedAt!),
                    l10n.catalogSize(v.sizeBytes),
                    ?entry.publishedByName,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (entry.current) StatusPill(label: l10n.adminCatalogCurrentPill, tone: PillTone.positive),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
    loading: true,
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
      itemCount: 4,
      separatorBuilder: (context, _) => const SizedBox(height: 12),
      itemBuilder: (context, _) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('----------------'), SizedBox(height: 6), Text('------------------------------')],
          ),
        ),
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Custom items (BR-CAT9)

class _CustomItemsTab extends ConsumerStatefulWidget {
  const _CustomItemsTab({required this.gutter});

  final double gutter;

  @override
  ConsumerState<_CustomItemsTab> createState() => _CustomItemsTabState();
}

class _CustomItemsTabState extends ConsumerState<_CustomItemsTab> {
  CatalogItemType? _type;
  bool _showDisabled = false;
  String _search = '';
  Timer? _debounce;

  CustomItemFilter get _filter => (type: _type, showDisabled: _showDisabled, search: _search);

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _edit([CustomCatalogItem? item]) async {
    final saved = await showCustomItemDialog(context, item: item, type: _type);
    if (saved == null || !mounted) return;
    ref.invalidate(adminCustomItemsProvider);
    // This device's search has it too, without waiting for the minute.
    ref.read(customItemsProvider.notifier).sync().ignore();
  }

  Future<void> _toggle(CustomCatalogItem item) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(adminCatalogRepositoryProvider)
          .updateCustomItem(item.customItemId, CustomItemDraft.of(item).copyWith(active: !item.active));
      if (!mounted) return;
      showAdminSnack(
        context,
        item.active ? l10n.adminCatalogItemDisabled(item.nameEn) : l10n.adminCatalogItemEnabled(item.nameEn),
      );
      ref.invalidate(adminCustomItemsProvider);
      ref.read(customItemsProvider.notifier).sync().ignore();
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final gutter = widget.gutter;
    final items = ref.watch(adminCustomItemsProvider(_filter));
    final language = Localizations.localeOf(context).languageCode;
    final groups = {
      for (final group in ref.watch(catalogChoicesProvider).value?.groups ?? const <CatalogValueCount>[])
        group.value: group.label(language),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One row of filters that scrolls sideways on phones.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final type in <CatalogItemType?>[null, ...CatalogItemType.values]) ...[
                      ChoiceChip(
                        label: Text(type == null ? l10n.adminCatalogAllTypes : l10n.catalogTypeName(type)),
                        avatar: type == null ? null : Icon(catalogTypeIcon(type), size: 18),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilterChip(
                      label: Text(l10n.adminCatalogShowDisabled),
                      selected: _showDisabled,
                      onSelected: (value) => setState(() => _showDisabled = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n.adminCatalogSearchItems,
                        ),
                        onChanged: (text) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 300), () {
                            if (mounted) setState(() => _search = text.trim());
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _edit,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.adminCatalogAddItem),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncStateSwitcher<List<CustomCatalogItem>>(
            value: items,
            loading: (context) => _ListSkeleton(gutter: gutter),
            error: (context, error) =>
                AdminErrorView(error: error, onRetry: () => ref.invalidate(adminCustomItemsProvider)),
            isEmpty: (items) => items.isEmpty,
            empty: (context) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.adminCatalogNoItems, textAlign: TextAlign.center),
              ),
            ),
            data: (context, items) => StaggerGroup(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                itemCount: items.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => StaggeredEntrance(
                  index: i,
                  child: _CustomItemCard(
                    item: items[i],
                    groupName: groups[items[i].drugGroupId],
                    onEdit: () => _edit(items[i]),
                    onToggle: () => _toggle(items[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomItemCard extends StatelessWidget {
  const _CustomItemCard({required this.item, required this.onEdit, required this.onToggle, this.groupName});

  final CustomCatalogItem item;

  /// The group's name from the catalog on this device.
  final String? groupName;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = item.type == CatalogItemType.drug
        ? [
            ?item.activeIngredient,
            ?(groupName ?? item.drugGroupId),
            if (item.route case final route?) l10n.catalogRouteName(route),
          ]
        : [?item.loincCode];
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 4, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: item.active ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    catalogTypeIcon(item.type),
                    size: 20,
                    color: item.active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nameEn, textDirection: TextDirection.ltr, style: theme.textTheme.titleSmall),
                    if (item.nameAr != null) Text(item.nameAr!, style: theme.textTheme.bodyMedium),
                    if (details.isNotEmpty)
                      Text(
                        details.join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(label: l10n.catalogTypeName(item.type), icon: catalogTypeIcon(item.type)),
                        StatusPill(
                          label: item.active ? l10n.adminStatusActive : l10n.adminStatusDisabled,
                          tone: item.active ? PillTone.positive : PillTone.danger,
                        ),
                        for (final alias in item.aliases) StatusPill(label: alias),
                      ],
                    ),
                    if (item.updatedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.adminCatalogUpdated(AppFormat.relative(context, item.updatedAt!)),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: l10n.adminCatalogItemActions(item.nameEn),
                onSelected: (action) => action == 'edit' ? onEdit() : onToggle(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(leading: const Icon(Icons.edit_outlined), title: Text(l10n.adminCatalogEdit)),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(item.active ? Icons.block : Icons.check_circle_outline),
                      title: Text(item.active ? l10n.adminDisable : l10n.adminEnable),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Doctor reports [S]

class _ReportsTab extends ConsumerStatefulWidget {
  const _ReportsTab({required this.gutter});

  final double gutter;

  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  String _status = 'open';
  final _handling = <String>{};

  Future<void> _handle(CatalogReport report) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _handling.add(report.reportId));
    try {
      await ref.read(adminCatalogRepositoryProvider).handleReport(report.reportId);
      if (!mounted) return;
      showAdminSnack(context, l10n.adminCatalogReportHandled);
      ref.invalidate(catalogReportsProvider);
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    } finally {
      if (mounted) setState(() => _handling.remove(report.reportId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gutter = widget.gutter;
    final reports = ref.watch(catalogReportsProvider(_status));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'open', label: Text(l10n.adminCatalogReportsOpen)),
                ButtonSegment(value: 'done', label: Text(l10n.adminCatalogReportsDone)),
                ButtonSegment(value: 'all', label: Text(l10n.adminCatalogAllTypes)),
              ],
              selected: {_status},
              onSelectionChanged: (value) => setState(() => _status = value.first),
            ),
          ),
        ),
        Expanded(
          child: AsyncStateSwitcher<List<CatalogReport>>(
            value: reports,
            loading: (context) => _ListSkeleton(gutter: gutter),
            error: (context, error) =>
                AdminErrorView(error: error, onRetry: () => ref.invalidate(catalogReportsProvider)),
            isEmpty: (reports) => reports.isEmpty,
            empty: (context) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.adminCatalogNoReports, textAlign: TextAlign.center),
              ),
            ),
            data: (context, reports) => StaggerGroup(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                itemCount: reports.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final report = reports[i];
                  return StaggeredEntrance(
                    index: i,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                StatusPill(
                                  label: l10n.catalogReportTypeName(report.type),
                                  tone: report.type == CatalogReportType.wrong ? PillTone.warning : PillTone.neutral,
                                ),
                                if (report.done)
                                  StatusPill(label: l10n.adminCatalogReportsDone, tone: PillTone.positive),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(report.text, style: theme.textTheme.bodyLarge),
                            if (report.itemRef != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                report.itemRef!,
                                textDirection: TextDirection.ltr,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${report.doctorName} · ${AppFormat.relative(context, report.createdAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ),
                                if (!report.done)
                                  FilledButton.tonalIcon(
                                    onPressed: _handling.contains(report.reportId) ? null : () => _handle(report),
                                    icon: const Icon(Icons.check),
                                    label: Text(l10n.adminCatalogMarkDone),
                                  )
                                else if (report.handledAt != null)
                                  Text(
                                    l10n.adminCatalogHandledOn(AppFormat.date(context, report.handledAt!)),
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
