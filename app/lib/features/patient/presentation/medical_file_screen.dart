import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/motion_size.dart';
import '../application/patient_providers.dart';
import '../data/patient_repository.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'patient_routes.dart';
import 'widgets/patient_widgets.dart';

/// The patient's medical file (spec 7.1): tabs Visits (P4), Prescriptions (P6) and Files (P8).
/// The doctor selector filters all three; Visits also filter by branch and Files by document date,
/// on the server.
class MedicalFileScreen extends StatefulWidget {
  const MedicalFileScreen({super.key, this.initialTab = MedicalFileTab.visits});

  final MedicalFileTab initialTab;

  @override
  State<MedicalFileScreen> createState() => _MedicalFileScreenState();
}

class _MedicalFileScreenState extends State<MedicalFileScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: MedicalFileTab.values.length, vsync: this, initialIndex: widget.initialTab.index);

  @override
  void didUpdateWidget(MedicalFileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) _tabs.animateTo(widget.initialTab.index);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        const DoctorSelector(),
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.tabVisits),
            Tab(text: l10n.tabPrescriptions),
            Tab(text: l10n.tabFiles),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [VisitsTab(), PrescriptionsTab(), FilesTab()],
          ),
        ),
      ],
    );
  }
}

// ---- P4 Visits --------------------------------------------------------------------------------

class VisitsTab extends ConsumerWidget {
  const VisitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final doctorId = ref.watch(selectedDoctorProvider);
    final branches = ref.watch(visitBranchesProvider(doctorId)).value ?? const <VisitBranchOption>[];
    final picked = ref.watch(visitBranchFilterProvider);
    // A branch the selected doctor has no visits in doesn't filter (the doctor changed).
    final branchId = branches.any((b) => b.branch.id == picked) ? picked : null;
    final filter = PatientListFilter(doctorId: doctorId, branchId: branchId);
    final provider = visitsProvider(filter);
    final visits = ref.watch(provider);
    final seen = ref.watch(seenItemsProvider).visits;

    final list = RefreshIndicator(
      onRefresh: () {
        ref.invalidate(visitBranchesProvider);
        return ref.refresh(provider.future);
      },
      child: AsyncValueView(
        value: visits,
        onRetry: () => ref.invalidate(provider),
        data: (state) {
          if (state.items.isEmpty) {
            return ListView(children: [
              EmptyState(icon: Icons.event_note_outlined, message: branchId != null ? l10n.visitsNoneInBranch : l10n.noVisits),
            ]);
          }
          // Timeline grouped by month (P4).
          final rows = <Widget>[];
          String? month;
          for (final visit in state.items) {
            final label = context.monthYear(visit.day);
            if (label != month) {
              month = label;
              rows.add(_MonthHeader(label: label));
            }
            rows.add(_VisitRow(visit: visit, isNew: visit.isNew && !seen.contains(visit.id)));
          }
          rows.add(PagedFooter(state: state, onRetry: () => ref.read(provider.notifier).loadMore()));

          return LoadMoreListener(
            onEnd: () => ref.read(provider.notifier).loadMore(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [for (final row in rows) ContentWidth(child: row)],
            ),
          );
        },
      ),
    );

    return Column(
      children: [
        MotionSize(
          child: branches.length < 2
              ? const SizedBox(width: double.infinity)
              : _BranchFilter(options: branches, selected: branchId),
        ),
        Expanded(child: list),
      ],
    );
  }
}

/// P4: All branches, then each branch the patient has visits in. A branch name that two doctors
/// share gets the doctor's name too.
class _BranchFilter extends ConsumerWidget {
  const _BranchFilter({required this.options, required this.selected});

  final List<VisitBranchOption> options;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(visitBranchFilterProvider.notifier);
    final names = [for (final o in options) context.branchName(o.branch)];
    String label(int i) => names.where((n) => n == names[i]).length > 1
        ? '${names[i]} · ${context.doctorName(options[i].doctor)}'
        : names[i];

    return Semantics(
      container: true,
      label: context.l10n.visitsFilterBranch,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
        child: Row(
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
              label: Text(context.l10n.allBranches),
              selected: selected == null,
              onSelected: (_) => controller.select(null),
            ),
            for (final (i, option) in options.indexed) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(label(i)),
                selected: selected == option.branch.id,
                onSelected: (_) => controller.select(option.branch.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
        child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.isNew});

  final VisitListItem visit;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => context.push(PatientRoutes.visit(visit.id)),
      title: Row(
        children: [
          VisitTypeBadge(type: visit.type),
          const SizedBox(width: 8),
          Expanded(child: Text(context.date(visit.at))),
          if (isNew) const NewBadge(),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${context.doctorName(visit.doctor)} · ${context.branchName(visit.branch)}'),
            if (visit.diagnosisSnippet != null)
              Text(visit.diagnosisSnippet!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

// ---- P6 Prescriptions -------------------------------------------------------------------------

class PrescriptionsTab extends StatelessWidget {
  const PrescriptionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [Tab(text: l10n.rxTabMedications), Tab(text: l10n.rxTabInvestigations)],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _PrescriptionList(kind: PrescriptionKind.medication),
                _PrescriptionList(kind: PrescriptionKind.investigations),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionList extends ConsumerWidget {
  const _PrescriptionList({required this.kind});

  final PrescriptionKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = PatientListFilter(doctorId: ref.watch(selectedDoctorProvider), kind: kind.name);
    final provider = prescriptionsProvider(filter);
    final list = ref.watch(provider);
    final seen = ref.watch(seenItemsProvider).prescriptions;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(provider.future),
      child: AsyncValueView(
        value: list,
        onRetry: () => ref.invalidate(provider),
        data: (state) {
          if (state.items.isEmpty) {
            return ListView(children: [EmptyState(icon: Icons.receipt_long_outlined, message: l10n.noPrescriptions)]);
          }
          return LoadMoreListener(
            onEnd: () => ref.read(provider.notifier).loadMore(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.items.length + 1,
              itemBuilder: (context, index) {
                if (index == state.items.length) {
                  return PagedFooter(state: state, onRetry: () => ref.read(provider.notifier).loadMore());
                }
                final rx = state.items[index];
                return ContentWidth(child: PrescriptionRow(rx: rx, isNew: rx.isNew && !seen.contains(rx.id)));
              },
            ),
          );
        },
      ),
    );
  }
}

/// One prescription row. Cancelled ones are struck through with a "Cancelled" label (P6).
class PrescriptionRow extends StatelessWidget {
  const PrescriptionRow({super.key, required this.rx, this.isNew = false});

  final PrescriptionListItem rx;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final strike = rx.isCancelled ? const TextStyle(decoration: TextDecoration.lineThrough) : null;
    return ListTile(
      onTap: () => context.push(PatientRoutes.prescription(rx.id)),
      leading: Icon(rx.kind == PrescriptionKind.medication ? Icons.medication_outlined : Icons.biotech_outlined),
      title: Row(
        children: [
          Expanded(child: Text(context.date(rx.sentAt ?? rx.cancelledAt ?? DateTime.now()), style: strike)),
          if (rx.isCancelled)
            Chip(
              label: Text(l10n.statusCancelled),
              visualDensity: VisualDensity.compact,
              labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer),
              backgroundColor: theme.colorScheme.errorContainer,
              side: BorderSide.none,
            )
          else if (isNew)
            const NewBadge(),
        ],
      ),
      subtitle: Text('${context.doctorName(rx.doctor)} · ${l10n.itemCount(rx.itemCount)}', style: strike),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

// ---- P8 Files ---------------------------------------------------------------------------------

/// The P8 list filter: the selected doctor and the document-date range, without a category.
PatientListFilter _filesFilter(WidgetRef ref, {String? kind}) {
  final range = ref.watch(fileDateRangeProvider);
  return PatientListFilter(doctorId: ref.watch(selectedDoctorProvider), kind: kind, from: range?.from, to: range?.to);
}

class FilesTab extends ConsumerWidget {
  const FilesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(recordCountsProvider(_filesFilter(ref))).value ?? const RecordCounts();

    return DefaultTabController(
      length: RecordCategory.values.length,
      child: Column(
        children: [
          const _DateRangeBar(),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final category in RecordCategory.values)
                Tab(text: '${context.recordCategory(category)} (${counts.of(category)})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [for (final category in RecordCategory.values) _RecordGrid(category: category)],
            ),
          ),
        ],
      ),
    );
  }
}

/// P8 "filter by date range": the document dates shown, with a clear button. The picker opens on
/// the current range and ends today. The tab counts follow the range.
class _DateRangeBar extends ConsumerWidget {
  const _DateRangeBar();

  Future<void> _pick(BuildContext context, WidgetRef ref, DayRange? current) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 30),
      lastDate: today,
      initialDateRange: current == null ? null : DateTimeRange(start: current.from, end: current.to),
      helpText: context.l10n.filesDateRange,
    );
    if (picked == null) return;
    ref.read(fileDateRangeProvider.notifier).set((from: DateUtils.dateOnly(picked.start), to: DateUtils.dateOnly(picked.end)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final range = ref.watch(fileDateRangeProvider);
    final label = range == null ? l10n.filesAnyDate : l10n.adminDateRange(context.date(range.from), context.date(range.to));
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: InputChip(
          avatar: const Icon(Icons.date_range_outlined, size: 18),
          label: Text(label),
          tooltip: l10n.filesDateRange,
          selected: range != null,
          showCheckmark: false,
          onPressed: () => _pick(context, ref, range),
          onDeleted: range == null ? null : () => ref.read(fileDateRangeProvider.notifier).set(null),
          deleteButtonTooltipMessage: l10n.filesClearDates,
        ),
      ),
    );
  }
}

class _RecordGrid extends ConsumerWidget {
  const _RecordGrid({required this.category});

  final RecordCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = _filesFilter(ref, kind: category.name);
    final provider = recordsProvider(filter);
    final records = ref.watch(provider);
    final seen = ref.watch(seenItemsProvider).files;
    final dated = filter.from != null;

    return RefreshIndicator(
      onRefresh: () {
        ref.invalidate(recordCountsProvider);
        return ref.refresh(provider.future);
      },
      child: AsyncValueView(
        value: records,
        onRetry: () => ref.invalidate(provider),
        data: (state) {
          if (state.items.isEmpty) {
            return ListView(children: [
              EmptyState(icon: Icons.folder_open_outlined, message: dated ? l10n.filesNoneInRange : l10n.noFiles),
            ]);
          }
          return LoadMoreListener(
            onEnd: () => ref.read(provider.notifier).loadMore(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 2 columns on phones, more on tablets.
                final columns = (constraints.maxWidth / 200).floor().clamp(2, 5);
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final record = state.items[index];
                          return _RecordTile(record: record, isNew: record.isNew && !seen.contains(record.id));
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: PagedFooter(state: state, onRetry: () => ref.read(provider.notifier).loadMore()),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.isNew});

  final RecordListItem record;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeLabel = context.otherType(record.otherType, record.otherTypeText);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(PatientRoutes.record(record.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, c) => FileThumb(recordId: record.id, cover: record.cover, size: c.maxWidth),
                  ),
                  if (isNew) const PositionedDirectional(top: 8, start: 8, child: NewBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  if (typeLabel != null)
                    Text(typeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
                  Text(
                    '${context.date(record.documentDate)} · ${context.doctorName(record.doctor)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
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
