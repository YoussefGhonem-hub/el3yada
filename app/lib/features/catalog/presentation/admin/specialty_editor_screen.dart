import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/save_bar.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../admin/admin_routes.dart';
import '../../../admin/presentation/widgets/admin_widgets.dart';
import '../../application/admin_catalog_providers.dart';
import '../../application/catalog_providers.dart';
import '../../application/search_debouncer.dart';
import '../../data/catalog_reader.dart';
import '../../data/local_catalog_search.dart';
import '../../domain/catalog_models.dart';
import '../../domain/catalog_search.dart';
import '../catalog_text.dart';
import '../widgets/catalog_hits_view.dart';

/// AD19 editor: one specialty's profile (BR-CAT2, BR-CAT3):
///
/// * medicine groups, a checklist with the product count of each group
///   (counted in the catalog on this device);
/// * preferred routes [S];
/// * recommended lab tests (search the local catalog and add);
/// * radiology body regions, modalities and recommended procedures;
/// * "Include General" (on by default) and "Copy from another specialty";
/// * a preview of what a doctor of this specialty sees first for a sample
///   search (the editors' search, with this profile and General).
class SpecialtyEditorScreen extends ConsumerStatefulWidget {
  const SpecialtyEditorScreen({super.key, required this.specialtyId});

  final String specialtyId;

  @override
  ConsumerState<SpecialtyEditorScreen> createState() => _SpecialtyEditorScreenState();
}

class _SpecialtyEditorScreenState extends ConsumerState<SpecialtyEditorScreen> {
  SpecialtyProfile? _saved;
  SpecialtyProfile? _draft;
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;
  int _failures = 0;

  void _update(SpecialtyProfile profile) => setState(() => _draft = profile);

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      final saved = await ref.read(adminCatalogRepositoryProvider).updateProfile(_draft!);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _draft = saved;
        _status = SubmitStatus.success;
      });
      ref.invalidate(adminSpecialtiesProvider);
      ref.invalidate(specialtyProfileProvider);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _status = SubmitStatus.idle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _error = l10n.apiError(error);
        _failures++;
      });
    }
  }

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final specialties = await ref.read(adminSpecialtiesProvider.future);
    if (!mounted) return;
    final from = await showDialog<SpecialtySummary>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.specialtyCopyTitle),
        children: [
          for (final specialty in specialties)
            if (specialty.specialtyId != widget.specialtyId)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, specialty),
                child: Text(specialty.name(language)),
              ),
        ],
      ),
    );
    if (from == null || !mounted) return;
    final confirmed = await confirmAction(
      context,
      title: l10n.specialtyCopyConfirmTitle(from.name(language)),
      message: l10n.specialtyCopyConfirmBody,
      confirmLabel: l10n.specialtyCopy,
    );
    if (!confirmed || !mounted) return;
    try {
      final copied = await ref
          .read(adminCatalogRepositoryProvider)
          .copyProfile(widget.specialtyId, fromSpecialtyId: from.specialtyId);
      if (!mounted) return;
      setState(() {
        _saved = copied;
        _draft = copied;
      });
      ref.invalidate(adminSpecialtiesProvider);
      showAdminSnack(context, l10n.specialtyCopied(from.name(language)));
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(specialtyProfileProvider(widget.specialtyId));
    final choices = ref.watch(catalogChoicesProvider).value;
    final catalogReady = ref.watch(catalogControllerProvider.select((s) => s.ready));
    final specialties = ref.watch(adminSpecialtiesProvider).value;
    final generalId = specialties?.where((s) => s.isGeneral).firstOrNull?.specialtyId;
    final general = generalId == null || generalId == widget.specialtyId
        ? null
        : ref.watch(specialtyProfileProvider(generalId)).value;
    if (_saved == null && profile.hasValue) {
      _saved = profile.value;
      _draft = profile.value;
    }
    return AsyncStateSwitcher<SpecialtyProfile>(
      value: _saved == null ? profile : AsyncData(_saved!),
      loading: (context) => const _EditorSkeleton(),
      error: (context, error) => Column(
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: AdminBackButton(fallback: AdminRoutes.specialties),
            ),
          ),
          Expanded(
            child: AdminErrorView(
              error: error,
              onRetry: () => ref.invalidate(specialtyProfileProvider(widget.specialtyId)),
            ),
          ),
        ],
      ),
      data: (context, _) => _editor(
        context,
        l10n,
        choices: choices,
        catalogReady: catalogReady,
        summary: specialties?.where((s) => s.specialtyId == widget.specialtyId).firstOrNull,
        general: general,
      ),
    );
  }

  Widget _editor(
    BuildContext context,
    AppLocalizations l10n, {
    required CatalogChoices? choices,
    required bool catalogReady,
    required SpecialtySummary? summary,
    required SpecialtyProfile? general,
  }) {
    final saved = _saved!;
    final draft = _draft!;
    final language = Localizations.localeOf(context).languageCode;
    final dirty = draft.changesFrom(saved);
    final preview = CatalogProfile.ofSpecialty(draft, general: draft.isGeneral ? draft : general);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = adminGutter(width);
        final twoColumns = width >= 1100;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final showBar = dirty > 0 || _status != SubmitStatus.idle;
        var index = 0;
        Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
        const gap = SizedBox(height: 16);

        final editor = [
          if (!catalogReady) ...[
            enter(_Banner(icon: Icons.cloud_download_outlined, message: l10n.specialtyCatalogNotReady)),
            gap,
          ],
          enter(_GeneralCard(draft: draft, onChanged: _update)),
          gap,
          enter(_GroupsCard(draft: draft, choices: choices, onChanged: _update)),
          gap,
          enter(_RoutesCard(draft: draft, choices: choices, onChanged: _update)),
          gap,
          enter(
            _CodesCard(
              lab: true,
              codes: draft.labCodes,
              onChanged: (codes) => _update(draft.copyWith(labCodes: codes)),
            ),
          ),
          gap,
          enter(_RadiologyCard(draft: draft, choices: choices, onChanged: _update)),
        ];
        final previewCard = enter(_PreviewCard(profile: preview));

        return Column(
          children: [
            Expanded(
              child: StaggerGroup(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 24 + (showBar ? 0 : bottomInset)),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          enter(
                            AdminHeader(
                              leading: const AdminBackButton(fallback: AdminRoutes.specialties),
                              title: saved.name(language),
                              subtitle: [
                                if (summary != null && !saved.isGeneral) l10n.specialtyDoctorCount(summary.doctorCount),
                                if (saved.isGeneral) l10n.specialtyGeneralBody,
                                if (saved.updatedAt != null)
                                  l10n.specialtyUpdated(AppFormat.relative(context, saved.updatedAt!)),
                              ].join(' · '),
                              actions: [
                                OutlinedButton.icon(
                                  onPressed: _status == SubmitStatus.idle ? _copy : null,
                                  icon: const Icon(Icons.content_copy_outlined),
                                  label: Text(l10n.specialtyCopyTitle),
                                ),
                              ],
                            ),
                          ),
                          gap,
                          if (twoColumns)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: Column(children: editor)),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: previewCard),
                              ],
                            )
                          else ...[
                            ...editor,
                            gap,
                            previewCard,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SaveBar(
              visible: showBar,
              dirty: dirty,
              status: _status,
              error: _error,
              failures: _failures,
              gutter: gutter,
              bottomInset: bottomInset,
              onDiscard: () => setState(() {
                _draft = _saved;
                _error = null;
              }),
              onSave: _save,
            ),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: scheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneralCard extends StatelessWidget {
  const _GeneralCard({required this.draft, required this.onChanged});

  final SpecialtyProfile draft;
  final ValueChanged<SpecialtyProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (draft.isGeneral) {
      return _Banner(icon: Icons.public, message: l10n.specialtyGeneralExplained);
    }
    return Card(
      child: SwitchListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(20, 6, 12, 6),
        secondary: const Icon(Icons.public),
        value: draft.includeGeneral,
        onChanged: (value) => onChanged(draft.copyWith(includeGeneral: value)),
        title: Text(l10n.specialtyIncludeGeneral),
        subtitle: Text(l10n.specialtyIncludeGeneralHint),
      ),
    );
  }
}

/// A chip per value; the selected ones that the catalog doesn't have are
/// still shown, so they can be removed.
class _ChipChecklist extends StatelessWidget {
  const _ChipChecklist({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelOf,
    this.limit,
  });

  final List<CatalogValueCount> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String Function(CatalogValueCount option)? labelOf;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final known = {for (final option in options) option.value};
    final shown = [
      for (final value in selected)
        if (!known.contains(value)) CatalogValueCount(value, 0),
      ...(limit == null ? options : _withSelected(options, selected, limit!)),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in shown)
          FilterChip(
            label: Text(
              option.count > 0
                  ? '${labelOf?.call(option) ?? option.label(language)} · ${option.count}'
                  : labelOf?.call(option) ?? option.label(language),
            ),
            selected: selected.contains(option.value),
            onSelected: (on) => onChanged(
              on
                  ? [...selected, option.value]
                  : [
                      for (final value in selected)
                        if (value != option.value) value,
                    ],
            ),
          ),
      ],
    );
  }

  /// The first [limit] options, plus the selected ones further down.
  static List<CatalogValueCount> _withSelected(List<CatalogValueCount> options, List<String> selected, int limit) => [
    for (final (i, option) in options.indexed)
      if (i < limit || selected.contains(option.value)) option,
  ];
}

class _GroupsCard extends StatefulWidget {
  const _GroupsCard({required this.draft, required this.choices, required this.onChanged});

  final SpecialtyProfile draft;
  final CatalogChoices? choices;
  final ValueChanged<SpecialtyProfile> onChanged;

  @override
  State<_GroupsCard> createState() => _GroupsCardState();
}

class _GroupsCardState extends State<_GroupsCard> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final query = _filter.trim().toLowerCase();
    final groups = [
      for (final group in widget.choices?.groups ?? const <CatalogValueCount>[])
        if (query.isEmpty ||
            [group.value, group.nameEn, group.nameAr].any((text) => (text ?? '').toLowerCase().contains(query)))
          group,
    ];
    return SectionCard(
      icon: Icons.medication_outlined,
      title: l10n.specialtyGroupsTitle,
      subtitle: l10n.specialtySelectedCount(widget.draft.drugGroups.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.specialtyGroupsHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (widget.choices != null) ...[
            TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.filter_list),
                hintText: l10n.specialtyGroupsFilter,
              ),
              onChanged: (text) => setState(() => _filter = text),
            ),
            const SizedBox(height: 12),
          ],
          _ChipChecklist(
            options: groups,
            selected: widget.draft.drugGroups,
            labelOf: (option) => option.label(language),
            onChanged: (values) => widget.onChanged(widget.draft.copyWith(drugGroups: values)),
          ),
        ],
      ),
    );
  }
}

class _RoutesCard extends StatelessWidget {
  const _RoutesCard({required this.draft, required this.choices, required this.onChanged});

  final SpecialtyProfile draft;
  final CatalogChoices? choices;
  final ValueChanged<SpecialtyProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      icon: Icons.alt_route,
      title: l10n.specialtyRoutesTitle,
      subtitle: l10n.specialtyRoutesHint,
      child: _ChipChecklist(
        options: choices?.routes ?? const [],
        selected: draft.routes,
        labelOf: (option) => l10n.catalogRouteName(option.value),
        onChanged: (values) => onChanged(draft.copyWith(routes: values)),
      ),
    );
  }
}

class _RadiologyCard extends StatefulWidget {
  const _RadiologyCard({required this.draft, required this.choices, required this.onChanged});

  final SpecialtyProfile draft;
  final CatalogChoices? choices;
  final ValueChanged<SpecialtyProfile> onChanged;

  @override
  State<_RadiologyCard> createState() => _RadiologyCardState();
}

class _RadiologyCardState extends State<_RadiologyCard> {
  bool _allRegions = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = widget.draft;
    final regions = widget.choices?.regions ?? const <CatalogValueCount>[];
    const shortList = 24;
    return SectionCard(
      icon: Icons.settings_overscan_outlined,
      title: l10n.specialtyRadiologyTitle,
      subtitle: l10n.specialtyRadiologyHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.specialtyRegions, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _ChipChecklist(
            options: regions,
            selected: draft.radiologyRegions,
            limit: _allRegions ? null : shortList,
            onChanged: (values) => widget.onChanged(draft.copyWith(radiologyRegions: values)),
          ),
          if (regions.length > shortList)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _allRegions = !_allRegions),
                child: Text(_allRegions ? l10n.specialtyShowFewer : l10n.specialtyShowAll(regions.length)),
              ),
            ),
          const SizedBox(height: 16),
          Text(l10n.specialtyModalities, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _ChipChecklist(
            options: widget.choices?.modalities ?? const [],
            selected: draft.radiologyModalities,
            onChanged: (values) => widget.onChanged(draft.copyWith(radiologyModalities: values)),
          ),
          const SizedBox(height: 20),
          _CodesBody(
            lab: false,
            codes: draft.radiologyCodes,
            onChanged: (codes) => widget.onChanged(draft.copyWith(radiologyCodes: codes)),
          ),
        ],
      ),
    );
  }
}

class _CodesCard extends StatelessWidget {
  const _CodesCard({required this.lab, required this.codes, required this.onChanged});

  final bool lab;
  final List<String> codes;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      icon: Icons.biotech_outlined,
      title: l10n.specialtyLabsTitle,
      subtitle: l10n.specialtySelectedCount(codes.length),
      child: _CodesBody(lab: lab, codes: codes, onChanged: onChanged),
    );
  }
}

/// Recommended lab tests or radiology procedures: the chosen ones, named
/// from the local catalog, and a search of the local catalog to add more.
class _CodesBody extends ConsumerStatefulWidget {
  const _CodesBody({required this.lab, required this.codes, required this.onChanged});

  final bool lab;
  final List<String> codes;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<_CodesBody> createState() => _CodesBodyState();
}

class _CodesBodyState extends ConsumerState<_CodesBody> {
  final _debouncer = SearchDebouncer();
  final _query = TextEditingController();
  List<TestHit> _results = const [];
  Map<String, TestHit> _names = const {};
  String _namesFor = '';

  @override
  void dispose() {
    _debouncer.dispose();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadNames(CatalogReader? reader) async {
    final key = widget.codes.join(',');
    if (reader == null || key == _namesFor) return;
    _namesFor = key;
    final hits = widget.lab ? await reader.labs(widget.codes) : await reader.radiology(widget.codes);
    if (!mounted || key != _namesFor) return;
    setState(() => _names = {for (final hit in hits) hit.code!: hit});
  }

  Future<void> _search(String text) async {
    final search = LocalCatalogSearch(
      history: const NoHistorySearch(),
      database: () => ref.read(catalogControllerProvider.notifier).database,
    );
    final hits = await _debouncer.run(() => search.tests(text, category: widget.lab ? 'lab' : 'radiology', limit: 8));
    if (hits == null || !mounted) return;
    setState(() => _results = [...hits.mySpecialty, ...hits.others].where((hit) => hit.code != null).toList());
  }

  Widget _chosen(String code) {
    final remove = _RemoveButton(onPressed: () => widget.onChanged([...widget.codes]..remove(code)));
    final hit = _names[code];
    if (hit != null) return CatalogTestTile(hit: hit, dense: true, trailing: remove);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(code, textDirection: TextDirection.ltr),
      trailing: remove,
    );
  }

  void _add(TestHit hit) {
    if (widget.codes.contains(hit.code)) return;
    widget.onChanged([...widget.codes, hit.code!]);
    _query.clear();
    setState(() => _results = const []);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reader = ref.watch(catalogReaderProvider);
    _loadNames(reader);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.lab) ...[
          Text(l10n.specialtyProcedures, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
        ],
        if (widget.codes.isEmpty)
          Text(
            widget.lab ? l10n.specialtyNoLabs : l10n.specialtyNoProcedures,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        for (final code in widget.codes) _chosen(code),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          enabled: reader != null,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.add),
            hintText: widget.lab ? l10n.specialtyAddLab : l10n.specialtyAddProcedure,
          ),
          onChanged: _search,
        ),
        for (final hit in _results)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _add(hit),
            child: CatalogTestTile(
              hit: hit,
              dense: true,
              trailing: Icon(
                widget.codes.contains(hit.code) ? Icons.check : Icons.add_circle_outline,
                color: scheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).specialtyRemove,
    onPressed: onPressed,
    icon: const Icon(Icons.close),
  );
}

/// What a doctor of this specialty sees first for a sample search: the
/// editors' search over the local catalog with this profile and General.
class _PreviewCard extends ConsumerStatefulWidget {
  const _PreviewCard({required this.profile});

  final CatalogProfile profile;

  @override
  ConsumerState<_PreviewCard> createState() => _PreviewCardState();
}

class _PreviewCardState extends ConsumerState<_PreviewCard> {
  final _debouncer = SearchDebouncer();
  final _query = TextEditingController();
  bool _tests = false;
  CatalogHits<Object>? _hits;

  @override
  void dispose() {
    _debouncer.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_PreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.profile, widget.profile) && _query.text.isNotEmpty) _run();
  }

  Future<void> _run() async {
    final search = LocalCatalogSearch(
      history: const NoHistorySearch(),
      database: () => ref.read(catalogControllerProvider.notifier).database,
      profile: () => widget.profile,
      customItems: () => ref.read(customItemsProvider).values,
    );
    final text = _query.text;
    final hits = await _debouncer.run<CatalogHits<Object>>(
      () async => _tests ? await search.tests(text, limit: 8) : await search.drugs(text, limit: 8),
    );
    if (hits == null || !mounted) return;
    setState(() => _hits = hits);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hits = _hits;
    return SectionCard(
      icon: Icons.manage_search,
      title: l10n.specialtyPreviewTitle,
      subtitle: l10n.specialtyPreviewHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.catalogTypeDrugs),
                icon: const Icon(Icons.medication_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.specialtyPreviewTests),
                icon: const Icon(Icons.biotech_outlined),
              ),
            ],
            selected: {_tests},
            onSelectionChanged: (value) {
              setState(() => _tests = value.first);
              _run();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _tests ? l10n.specialtyPreviewTestsSample : l10n.specialtyPreviewDrugsSample,
            ),
            onChanged: (_) => _run(),
          ),
          if (hits != null) ...[
            if (hits.isEmpty && LocalCatalogSearch.searchesCatalog(_query.text))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.specialtyPreviewNothing, style: theme.textTheme.bodyMedium),
              )
            else if (!hits.catalogReady)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(l10n.specialtyCatalogNotReady, style: theme.textTheme.bodySmall),
              ),
            CatalogHitsView<Object>(hits: hits, dense: true),
          ],
        ],
      ),
    );
  }
}

class _EditorSkeleton extends StatelessWidget {
  const _EditorSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonLoading(
    loading: true,
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        Text('----------------------'),
        SizedBox(height: 16),
        Card(child: SizedBox(height: 120)),
        SizedBox(height: 16),
        Card(child: SizedBox(height: 200)),
      ],
    ),
  );
}
