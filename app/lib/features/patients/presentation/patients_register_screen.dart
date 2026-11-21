import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/paged_controller.dart';
import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/container_transform.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../records/data/file_actions.dart';
import '../../sessions/domain/session_models.dart' show dayKey;
import '../application/patients_providers.dart';
import '../clinic_paths.dart';
import '../data/patients_repository.dart';
import '../domain/patient_models.dart';
import 'patient_profile_screen.dart';
import 'widgets/clinic_ui.dart';
import 'widgets/patient_text.dart';

/// Content at least this wide shows the register as a table, with the
/// selected patient's profile (D6) on the right (spec section 4).
const double _tableWidth = 900;

/// D4 / AS2: every patient of the doctor, with search, filters, sort and
/// paging. Phones and tablets show cards that grow into D6 (container
/// transform); wide screens a table, and master-detail once a row is picked.
class PatientsRegisterScreen extends ConsumerStatefulWidget {
  const PatientsRegisterScreen({super.key, this.initialLastVisit});

  /// A `lastVisit` filter to start with (the dashboard's «not seen» bars, C11 and AC-24).
  final LastVisitFilter? initialLastVisit;

  @override
  ConsumerState<PatientsRegisterScreen> createState() => _PatientsRegisterScreenState();
}

class _PatientsRegisterScreenState extends ConsumerState<PatientsRegisterScreen> {
  static const _searchDelay = Duration(milliseconds: 350);

  late final TextEditingController _search;
  final _searchFocus = FocusNode();
  Timer? _debounce;

  /// The patient open on the right (wide layout).
  String? _selected;

  /// Changes with the results, so the list entrance plays again.
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  RegisterQuery get _query => ref.read(registerQueryProvider);

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(registerQueryProvider).search);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialLastVisit case final filter?) {
        ref.read(registerQueryProvider.notifier).set(_query.copyWith(lastVisit: () => filter));
      }
      if (ref.read(registerSearchRequestProvider)) _focusSearch();
    });
  }

  void _focusSearch() {
    if (!ref.read(registerSearchRequestProvider.notifier).take()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _setQuery(RegisterQuery query) {
    ref.read(registerQueryProvider.notifier).set(query);
    setState(() => _generation++);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      if (!mounted || value.trim() == _query.search) return;
      _setQuery(_query.copyWith(search: value.trim()));
    });
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    if (_query.search.isNotEmpty) _setQuery(_query.copyWith(search: ''));
  }

  void _clearAll() {
    _search.clear();
    _setQuery(const RegisterQuery().copyWith(sort: _query.sort, descending: () => _query.descending));
  }

  void _sortBy(RegisterSort sort) {
    final query = _query;
    if (query.sort == sort) {
      _setQuery(query.copyWith(descending: () => !query.isDescending));
    } else {
      _setQuery(query.copyWith(sort: sort, descending: () => null));
    }
  }

  Future<void> _refresh() => ref.read(registerControllerProvider.notifier).refresh();

  bool _exporting = false;

  /// D4 [S] "Export CSV" (doctor only): the rows the filters and sort select, in the app's language.
  /// A save dialog on desktop, the share sheet on phones.
  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(patientsRepositoryProvider).exportRegister(_query, language: language);
      final saved = await ref.read(fileActionsProvider).save(
            bytes,
            fileName: 'patients-${dayKey(DateTime.now())}.csv',
            mimeType: 'text/csv',
          );
      if (saved && mounted) showAdminSnack(context, l10n.patientExportDone);
    } on ApiException catch (error) {
      if (!mounted) return;
      showAdminSnack(context, error.code == 'EXPORT_TOO_LARGE' ? l10n.patientExportTooLarge : l10n.apiError(error), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registerSearchRequestProvider, (_, pending) {
      if (pending) _focusSearch();
    });
    return ClinicGate(
      builder: (context, clinic) => LayoutBuilder(
        builder: (context, constraints) {
          final state = ref.watch(registerControllerProvider);
          final wide = constraints.maxWidth >= _tableWidth;
          if (!wide) return _pane(context, clinic, state, mode: _Mode.cards, width: constraints.maxWidth);
          final selected = _selected;
          final listWidth = (constraints.maxWidth * 0.36).clamp(340.0, 420.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: selected == null ? constraints.maxWidth : listWidth,
                child: _pane(
                  context,
                  clinic,
                  state,
                  mode: selected == null ? _Mode.table : _Mode.compact,
                  width: selected == null ? constraints.maxWidth : listWidth,
                ),
              ),
              if (selected != null) ...[
                const VerticalDivider(width: 1),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.normal,
                    reverseDuration: Motion.normalExit,
                    switchInCurve: Motion.enterCurve,
                    switchOutCurve: Motion.exitCurveReversed,
                    child: PatientProfileView(
                      key: ValueKey(selected),
                      patientId: selected,
                      onClose: () => setState(() => _selected = null),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _pane(BuildContext context, ClinicContext clinic, PagedState<PatientRegisterRow> state,
      {required _Mode mode, required double width}) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final query = ref.watch(registerQueryProvider);
    final gutter = mode == _Mode.compact ? 16.0 : clinicGutter(width);
    final canAdd = clinic.can(ClinicPermission.patientsManage) && !clinic.isSuspended;
    final compact = mode == _Mode.compact;
    final add = !canAdd
        ? null
        : compact
            ? IconButton.filledTonal(
                tooltip: l10n.patientAdd,
                onPressed: () => context.push(paths.addPatient),
                icon: const Icon(Icons.person_add_alt_1_outlined),
              )
            : FilledButton.icon(
                onPressed: () => context.push(paths.addPatient),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(l10n.patientAdd),
              );
    // The whole list with phone numbers: the doctor's alone (the API refuses assistants).
    final exportIcon = _exporting
        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.file_download_outlined);
    final export = !clinic.isDoctor
        ? null
        : compact || width < 600
            ? IconButton(tooltip: l10n.patientExportCsv, onPressed: _exporting ? null : _export, icon: exportIcon)
            : OutlinedButton.icon(onPressed: _exporting ? null : _export, icon: exportIcon, label: Text(l10n.patientExportCsv));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 12),
          child: ClinicHeader(
            title: l10n.navPatients,
            subtitle: state.loading ? l10n.loading : l10n.patientRegisterCount(state.totalCount),
            actions: [?export, ?add],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  focusNode: _searchFocus,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.patientSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _search,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: l10n.adminClearSearch,
                              icon: const Icon(Icons.close),
                              onPressed: _clearSearch,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _SortMenu(clinic: clinic, query: query, onSort: _sortBy),
              if (mode != _Mode.cards)
                IconButton(
                  tooltip: l10n.adminRefresh,
                  onPressed: state.refreshing ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _FilterBar(
          clinic: clinic,
          query: query,
          gutter: gutter,
          onChanged: _setQuery,
          onClear: _clearAll,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StateSwitcher(
            state: state.view,
            loading: (context) => _RegisterSkeleton(mode: mode, gutter: gutter, clinic: clinic, width: width),
            error: (context) => AdminErrorView(
              error: state.error!,
              onRetry: () => ref.read(registerControllerProvider.notifier).reload(),
            ),
            empty: (context) => RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: query.isFiltered
                        ? EmptyState(
                            title: l10n.patientNoMatchTitle,
                            message: l10n.patientNoMatchBody,
                            actionLabel: l10n.patientFilterClear,
                            onAction: _clearAll,
                          )
                        : EmptyState(
                            title: l10n.patientEmptyTitle,
                            message: canAdd ? l10n.patientEmptyBody : null,
                            actionLabel: canAdd ? l10n.patientAdd : null,
                            onAction: canAdd ? () => context.push(paths.addPatient) : null,
                          ),
                  ),
                ),
              ),
            ),
            content: (context) => _results(context, clinic, state, mode: mode, gutter: gutter, width: width),
          ),
        ),
      ],
    );
  }

  Widget _results(BuildContext context, ClinicContext clinic, PagedState<PatientRegisterRow> state,
      {required _Mode mode, required double gutter, required double width}) {
    final controller = ref.read(registerControllerProvider.notifier);
    final items = state.items;
    final footer = state.loadingMore || state.moreError != null || state.hasMore;
    final bottom = 16 + MediaQuery.paddingOf(context).bottom;
    final columns = mode == _Mode.table ? _columns(context, clinic, width - 2 * gutter) : const <_Column>[];

    Widget footerRow() => state.moreError != null
        ? AdminErrorView(error: state.moreError!, onRetry: controller.loadMore, compact: true)
        : SkeletonLoading(
            loading: true,
            child: switch (mode) {
              _Mode.cards => _PatientCard.placeholder(clinic),
              _Mode.compact => _CompactRow.placeholder(),
              _Mode.table => _TableRow.placeholder(columns),
            },
          );

    Widget item(int i) {
      final row = items[i];
      switch (mode) {
        case _Mode.cards:
          return ContainerTransform<void>(
            tappable: false,
            closedBuilder: (context, open) => _PatientCard(row: row, clinic: clinic, onTap: open),
            openBuilder: (context, close) => PatientProfilePage(patientId: row.patientId),
          );
        case _Mode.compact:
          return _CompactRow(
            row: row,
            selected: row.patientId == _selected,
            onTap: () => setState(() => _selected = row.patientId),
          );
        case _Mode.table:
          return _TableRow(row: row, columns: columns, onTap: () => setState(() => _selected = row.patientId));
      }
    }

    final list = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 400) controller.loadMore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: StaggerGroup(
          key: ValueKey(_generation),
          child: switch (mode) {
            _Mode.cards => _CardList(
                count: items.length,
                columns: width >= 640 ? 2 : 1,
                gutter: gutter,
                bottom: bottom,
                item: (i) => StaggeredEntrance(index: i, child: item(i)),
                footer: footer ? footerRow() : null,
              ),
            _ => ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(mode == _Mode.table ? 0 : gutter, 0, mode == _Mode.table ? 0 : gutter, bottom),
                itemCount: items.length + (footer ? 1 : 0),
                separatorBuilder: (context, _) =>
                    mode == _Mode.table ? const Divider(height: 1) : const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    i == items.length ? footerRow() : StaggeredEntrance(index: i, child: item(i)),
              ),
          },
        ),
      ),
    );

    if (mode != _Mode.table) return list;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TableHeader(columns: columns, query: ref.watch(registerQueryProvider), onSort: _sortBy),
            const Divider(height: 1),
            Expanded(child: list),
          ],
        ),
      ),
    );
  }
}

enum _Mode { cards, table, compact }

// -----------------------------------------------------------------------------
// Filters and sort

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.clinic,
    required this.query,
    required this.gutter,
    required this.onChanged,
    required this.onClear,
  });

  final ClinicContext clinic;
  final RegisterQuery query;
  final double gutter;
  final ValueChanged<RegisterQuery> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final branchName = query.branchId == null ? null : clinic.branch(query.branchId)?.name(language);
    final visits = _VisitsRange.of(query);
    final chips = <Widget>[
      _MenuChip<LastVisitFilter?>(
        label: query.lastVisit == null ? l10n.patientFilterLastVisit : lastVisitFilterLabel(l10n, query.lastVisit!),
        selected: query.lastVisit != null,
        values: [null, ...LastVisitFilter.values],
        current: query.lastVisit,
        itemLabel: (value) => value == null ? l10n.patientFilterAny : lastVisitFilterLabel(l10n, value),
        onSelected: (value) => onChanged(query.copyWith(lastVisit: () => value)),
      ),
      if (clinic.branches.length > 1)
        _MenuChip<String?>(
          label: branchName ?? l10n.patientFilterBranch,
          selected: query.branchId != null,
          values: [null, for (final b in clinic.branches) b.id],
          current: query.branchId,
          itemLabel: (id) => id == null ? l10n.patientFilterAllBranches : clinic.branch(id)!.name(language),
          onSelected: (id) => onChanged(query.copyWith(branchId: () => id)),
        ),
      _MenuChip<_VisitsRange>(
        label: visits == _VisitsRange.any ? l10n.patientFilterVisits : visits.label(l10n),
        selected: visits != _VisitsRange.any,
        values: _VisitsRange.values,
        current: visits,
        itemLabel: (value) => value == _VisitsRange.any ? l10n.patientFilterAny : value.label(l10n),
        onSelected: (value) => onChanged(query.copyWith(minVisits: () => value.min, maxVisits: () => value.max)),
      ),
      FilterChip(
        label: Text(l10n.patientFilterNewThisMonth),
        selected: query.newThisMonth,
        onSelected: (on) => onChanged(query.copyWith(newThisMonth: on)),
      ),
      if (clinic.can(ClinicPermission.clinicalView))
        FilterChip(
          label: Text(l10n.patientFilterChronic),
          selected: query.hasChronicDisease,
          onSelected: (on) => onChanged(query.copyWith(hasChronicDisease: on)),
        ),
      FilterChip(
        label: Text(l10n.patientFilterUpcoming),
        selected: query.hasUpcomingBooking,
        onSelected: (on) => onChanged(query.copyWith(hasUpcomingBooking: on)),
      ),
      FilterChip(
        label: Text(l10n.patientFilterNoShows),
        selected: query.hasNoShows,
        onSelected: (on) => onChanged(query.copyWith(hasNoShows: on)),
      ),
      FilterChip(
        label: Text(l10n.patientFilterArchived),
        selected: query.archived,
        onSelected: (on) => onChanged(query.copyWith(archived: on)),
      ),
      if (query.filterCount > 0)
        ActionChip(
          avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: Text(l10n.patientFilterClear),
          onPressed: onClear,
        ),
    ];
    return ClinicChips(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Row(children: [for (final (i, chip) in chips.indexed) ...[if (i > 0) const SizedBox(width: 8), chip]]),
      ),
    );
  }
}

/// Presets for the visits filter (the API takes a min and a max).
enum _VisitsRange {
  any(null, null),
  one(1, 1),
  few(2, 4),
  many(5, null);

  const _VisitsRange(this.min, this.max);

  final int? min;
  final int? max;

  static _VisitsRange of(RegisterQuery query) =>
      values.firstWhere((r) => r.min == query.minVisits && r.max == query.maxVisits, orElse: () => any);

  String label(AppLocalizations l10n) => switch (this) {
        any => l10n.patientFilterAny,
        one => l10n.patientVisitsOne,
        few => l10n.patientVisitsFew,
        many => l10n.patientVisitsMany,
      };
}

/// A filter chip that opens a menu of choices.
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.label,
    required this.selected,
    required this.values,
    required this.current,
    required this.itemLabel,
    required this.onSelected,
  });

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
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(label), const SizedBox(width: 2), const Icon(Icons.arrow_drop_down, size: 18)],
          ),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => controller.isOpen ? controller.close() : controller.open(),
        ),
      );
}

/// The sorts the caller may use (`totalPaid` needs `revenueView`, `allergies` `clinicalView`).
List<RegisterSort> availableSorts(ClinicContext clinic) => [
      RegisterSort.lastVisit,
      RegisterSort.name,
      RegisterSort.fileNumber,
      RegisterSort.age,
      RegisterSort.firstVisit,
      RegisterSort.visits,
      RegisterSort.nextBooking,
      RegisterSort.noShows,
      RegisterSort.files,
      RegisterSort.linkedAt,
      if (clinic.can(ClinicPermission.revenueView)) RegisterSort.totalPaid,
      if (clinic.can(ClinicPermission.clinicalView)) RegisterSort.allergies,
      if (clinic.can(ClinicPermission.chat)) RegisterSort.unreadChat,
    ];

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.clinic, required this.query, required this.onSort});

  final ClinicContext clinic;
  final RegisterQuery query;
  final ValueChanged<RegisterSort> onSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MenuAnchor(
      menuChildren: [
        for (final sort in availableSorts(clinic))
          MenuItemButton(
            leadingIcon: Icon(sort == query.sort ? Icons.check : null, size: 20),
            trailingIcon: sort == query.sort
                ? Icon(query.isDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 18)
                : null,
            onPressed: () => onSort(sort),
            child: Text(registerSortLabel(l10n, sort)),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: '${l10n.adminSort}: ${registerSortLabel(l10n, query.sort)}',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.swap_vert),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Cards (phones, tablets)

/// Cards in one or two columns, with the paging footer.
class _CardList extends StatelessWidget {
  const _CardList({
    required this.count,
    required this.columns,
    required this.gutter,
    required this.bottom,
    required this.item,
    this.footer,
  });

  final int count;
  final int columns;
  final double gutter;
  final double bottom;
  final Widget Function(int index) item;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final rows = (count / columns).ceil();
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
      itemCount: rows + (footer == null ? 0 : 1),
      separatorBuilder: (context, _) => const SizedBox(height: 12),
      itemBuilder: (context, r) {
        if (r == rows) return footer!;
        if (columns == 1) return item(r);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(child: r * columns + c < count ? item(r * columns + c) : const SizedBox.shrink()),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.row, required this.clinic, required this.onTap});

  static Widget placeholder(ClinicContext clinic) => _PatientCard(row: _placeholderRow, clinic: clinic, onTap: null);

  final PatientRegisterRow row;
  final ClinicContext clinic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = row.visits.lastVisit;
    final paid = row.totalPaidPiasters;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      semanticLabel: patientRowSemantics(context, row),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InitialAvatar(name: row.fullName, size: 46, muted: row.archived),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                row.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (row.hasAllergies ?? false) ...[const SizedBox(width: 8), const AllergyFlag(compact: true)],
                            if ((row.unreadChatCount ?? 0) > 0) const SizedBox(width: 8),
                            UnreadChatBadge(count: row.unreadChatCount ?? 0),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            FileNumberPill(row.fileNumber),
                            Text(
                              patientAgeGender(l10n, row.ageYears, row.gender, estimated: row.dateOfBirthEstimated),
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            LtrText(
                              AppFormat.phone(row.phone),
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            if (row.archived) StatusPill(label: l10n.patientArchived),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: last == null
                            ? Text(l10n.patientNoVisits,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant))
                            : _LastVisitLine(last: last),
                      ),
                      if (paid != null) ...[
                        const SizedBox(width: 8),
                        Text(AppFormat.egp(context, paid), style: theme.textTheme.labelLarge),
                      ],
                    ],
                  ),
                ),
              ),
              if (row.visits.total > 0) ...[
                const SizedBox(height: 8),
                Text(
                  visitsSummary(l10n, row.visits),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (row.nextBooking != null || row.noShowCount > 0 || row.filesCount > 0) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (row.nextBooking case final next?)
                      MetaLine(
                        icon: Icons.event_available_outlined,
                        text: l10n.patientCardNextBooking(ClinicFormat.dayAuto(context, next.date)),
                        color: scheme.primary,
                      ),
                    if (row.noShowCount > 0)
                      MetaLine(icon: Icons.event_busy_outlined, text: l10n.patientCardNoShows(row.noShowCount), color: scheme.error),
                    if (row.filesCount > 0) MetaLine(icon: Icons.folder_outlined, text: l10n.patientCardFiles(row.filesCount)),
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

/// Type badge, date, branch and "x days ago" of a last visit.
class _LastVisitLine extends StatelessWidget {
  const _LastVisitLine({required this.last, this.dense = false});

  final LastVisit last;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TypeBadge(last.type),
        Text(ClinicFormat.dayShort(context, last.day), style: theme.textTheme.bodyMedium),
        if (!dense) Text(last.branchName(language), style: muted),
        Text(ClinicFormat.daysAgo(l10n, last.daysAgo), style: muted),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Compact rows (the list next to D6)

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.row, required this.selected, required this.onTap});

  static Widget placeholder() => _CompactRow(row: _placeholderRow, selected: false, onTap: null);

  final PatientRegisterRow row;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = row.visits.lastVisit;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: patientRowSemantics(context, row),
      child: AnimatedContainer(
        duration: Motion.fast,
        curve: Motion.enterCurve,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            InitialAvatar(name: row.fullName, size: 38, muted: row.archived),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(row.fullName,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                      ),
                      if (row.hasAllergies ?? false) ...[const SizedBox(width: 6), const AllergyFlag(compact: true)],
                      if ((row.unreadChatCount ?? 0) > 0) const SizedBox(width: 6),
                      UnreadChatBadge(count: row.unreadChatCount ?? 0),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      FileNumberPill(row.fileNumber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          last == null
                              ? l10n.patientNoVisits
                              : '${ClinicFormat.dayShort(context, last.day)}  ${ClinicFormat.daysAgo(l10n, last.daysAgo)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      if (last != null) TypeBadge(last.type),
                    ],
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

// -----------------------------------------------------------------------------
// Table (desktop)

class _Column {
  const _Column({required this.label, required this.cell, this.width, this.flex, this.sort, this.numeric = false});

  final String label;
  final double? width;
  final int? flex;
  final RegisterSort? sort;
  final bool numeric;
  final Widget Function(BuildContext context, PatientRegisterRow row) cell;
}

/// D4's columns that the caller may see and that fit [width]. Total paid
/// needs `revenueView` and the allergy flag `clinicalView` (spec 7.6).
List<_Column> _columns(BuildContext context, ClinicContext clinic, double width) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
  return [
    _Column(
      label: l10n.patientColumnFile,
      width: 64,
      sort: RegisterSort.fileNumber,
      numeric: true,
      cell: (context, row) => Text('${row.fileNumber}', style: theme.textTheme.titleSmall),
    ),
    // The name gets the most room: with the desktop type scale a full
    // four-part name needs it to stay on one line.
    _Column(
      label: l10n.patientColumnName,
      flex: 4,
      sort: RegisterSort.name,
      cell: (context, row) => Row(
        children: [
          // A narrow table keeps the room for the name.
          if (width >= 1000) ...[
            InitialAvatar(name: row.fullName, size: 32, muted: row.archived),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(row.fullName, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          ),
        ],
      ),
    ),
    _Column(
      label: l10n.patientColumnPhone,
      width: 128,
      cell: (context, row) => LtrText(AppFormat.phone(row.phone), style: theme.textTheme.bodyMedium),
    ),
    _Column(
      label: l10n.patientColumnAge,
      width: 96,
      sort: RegisterSort.age,
      cell: (context, row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(patientAge(l10n, row.ageYears, estimated: row.dateOfBirthEstimated), style: theme.textTheme.bodyMedium),
          Text(genderLabel(l10n, row.gender), style: muted),
        ],
      ),
    ),
    // The narrower the table, the fewer columns: the name and the last visit keep their room.
    if (width >= 1250)
      _Column(
        label: l10n.patientColumnFirstVisit,
        width: 104,
        sort: RegisterSort.firstVisit,
        cell: (context, row) => row.visits.firstVisitAt == null
            ? Text('—', style: muted)
            : Text(AppFormat.date(context, row.visits.firstVisitAt!), style: theme.textTheme.bodyMedium),
      ),
    _Column(
      label: l10n.patientColumnLastVisit,
      flex: 3,
      sort: RegisterSort.lastVisit,
      cell: (context, row) => row.visits.lastVisit == null
          ? Text(l10n.patientNoVisits, style: muted)
          : _LastVisitLine(last: row.visits.lastVisit!, dense: width < 1100),
    ),
    _Column(
      label: l10n.patientColumnVisits,
      width: 120,
      sort: RegisterSort.visits,
      cell: (context, row) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${row.visits.total}', style: theme.textTheme.titleSmall),
          if (row.visits.total > 0)
            Text(
              l10n.patientVisitsSplit(row.visits.examinations, row.visits.consultations),
              style: muted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    ),
    if (width >= 1000)
      _Column(
        label: l10n.patientColumnNextBooking,
        width: 112,
        sort: RegisterSort.nextBooking,
        cell: (context, row) => row.nextBooking == null
            ? Text('—', style: muted)
            : Text(ClinicFormat.dayAuto(context, row.nextBooking!.date), style: theme.textTheme.bodyMedium),
      ),
    if (width >= 1000)
      _Column(
        label: l10n.patientColumnNoShows,
        width: 80,
        sort: RegisterSort.noShows,
        numeric: true,
        cell: (context, row) => row.noShowCount == 0 ? Text('—', style: muted) : Text('${row.noShowCount}', style: theme.textTheme.bodyMedium),
      ),
    if (width >= 1300)
      _Column(
        label: l10n.patientSortFiles,
        width: 72,
        sort: RegisterSort.files,
        numeric: true,
        cell: (context, row) => row.filesCount == 0 ? Text('—', style: muted) : Text('${row.filesCount}', style: theme.textTheme.bodyMedium),
      ),
    if (clinic.can(ClinicPermission.revenueView))
      _Column(
        label: l10n.patientColumnPaid,
        width: 96,
        sort: RegisterSort.totalPaid,
        numeric: true,
        cell: (context, row) => Text(AppFormat.egp(context, row.totalPaidPiasters ?? 0), style: theme.textTheme.bodyMedium),
      ),
    if (clinic.can(ClinicPermission.clinicalView))
      _Column(
        label: l10n.patientAllergyFlag,
        width: 96,
        sort: RegisterSort.allergies,
        cell: (context, row) => (row.hasAllergies ?? false) ? const AllergyFlag(compact: true) : const SizedBox.shrink(),
      ),
    if (clinic.can(ClinicPermission.chat))
      _Column(
        label: l10n.patientColumnUnread,
        width: 72,
        sort: RegisterSort.unreadChat,
        cell: (context, row) => UnreadChatBadge(count: row.unreadChatCount ?? 0),
      ),
  ];
}

/// D4's unread chat badge: the caller's own unread messages from the patient, popping in when
/// the count changes. Nothing while there are none.
class UnreadChatBadge extends StatelessWidget {
  const UnreadChatBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final reduced = Motion.of(context).reduced;
    return AnimatedSwitcher(
      duration: reduced ? Duration.zero : Motion.normal,
      reverseDuration: reduced ? Duration.zero : Motion.normalExit,
      switchInCurve: Motion.spring,
      switchOutCurve: Motion.exitCurveReversed,
      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
      child: count == 0
          ? const SizedBox.shrink(key: ValueKey(0))
          : Semantics(
              key: ValueKey(count),
              label: l10n.patientUnreadSemantics(count),
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: ShapeDecoration(color: scheme.primary, shape: const StadiumBorder()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_rounded, size: 13, color: scheme.onPrimary),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

Widget _cellBox(_Column column, Widget child) {
  final aligned = Align(alignment: AlignmentDirectional.centerStart, child: child);
  return column.width != null
      ? SizedBox(width: column.width, child: aligned)
      : Expanded(flex: column.flex ?? 1, child: aligned);
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.query, required this.onSort});

  final List<_Column> columns;
  final RegisterQuery query;
  final ValueChanged<RegisterSort> onSort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            for (final column in columns)
              _cellBox(
                column,
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: column.sort == null
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(column.label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                        )
                      : TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              foregroundColor: query.sort == column.sort ? scheme.primary : scheme.onSurfaceVariant,
                              minimumSize: const Size(40, 48),
                            ),
                            onPressed: () => onSort(column.sort!),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    column.label,
                                    overflow: TextOverflow.ellipsis,
                                    semanticsLabel: '${column.label}, ${l10n.adminSort}',
                                  ),
                                ),
                                if (query.sort == column.sort)
                                  Icon(query.isDescending ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                              ],
                            ),
                          ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.row, required this.columns, required this.onTap});

  static Widget placeholder(List<_Column> columns) => _TableRow(row: _placeholderRow, columns: columns, onTap: null);

  final PatientRegisterRow row;
  final List<_Column> columns;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: patientRowSemantics(context, row),
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              children: [
                for (final column in columns)
                  _cellBox(column, Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: column.cell(context, row))),
              ],
            ),
          ),
        ),
      );
}

// -----------------------------------------------------------------------------
// Skeleton

final _placeholderRow = PatientRegisterRow(
  patientId: '',
  fileNumber: 12,
  fullName: '—————————————',
  phone: '+201000000000',
  gender: Gender.female,
  ageYears: 30,
  linkedAt: DateTime.utc(2026),
  visits: PatientVisits(
    total: 3,
    examinations: 1,
    consultations: 2,
    lastVisit: LastVisit(
      sessionId: '',
      at: DateTime.utc(2026),
      day: DateTime.utc(2026),
      daysAgo: 3,
      type: SessionType.examination,
      branchId: '',
      branchNameAr: '——————',
    ),
  ),
);

class _RegisterSkeleton extends StatelessWidget {
  const _RegisterSkeleton({required this.mode, required this.gutter, required this.clinic, required this.width});

  final _Mode mode;
  final double gutter;
  final ClinicContext clinic;
  final double width;

  @override
  Widget build(BuildContext context) {
    final columns = mode == _Mode.table ? _columns(context, clinic, width - 2 * gutter) : const <_Column>[];
    final list = ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: mode == _Mode.table ? 0 : gutter),
      itemCount: 6,
      separatorBuilder: (context, _) => mode == _Mode.table ? const Divider(height: 1) : const SizedBox(height: 12),
      itemBuilder: (context, _) => switch (mode) {
        _Mode.cards => _PatientCard.placeholder(clinic),
        _Mode.compact => _CompactRow.placeholder(),
        _Mode.table => _TableRow.placeholder(columns),
      },
    );
    return SkeletonLoading(
      loading: true,
      child: mode == _Mode.table
          ? Padding(padding: EdgeInsets.symmetric(horizontal: gutter), child: Card(child: list))
          : list,
    );
  }
}
