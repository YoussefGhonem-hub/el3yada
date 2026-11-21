import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/platform/contact_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../application/appointment_providers.dart';
import '../domain/appointment_models.dart';
import 'appointment_format.dart';
import 'branch_picker.dart';
import 'walk_in_dialog.dart';

/// D34 / AS1 / AS16: today's patients at the current branch by stage. Every action is an API
/// call (BR-LB1); changes from other devices arrive live (BR-LB2). Done is reached only by
/// saving a session (BR-LB3): Finish opens the session form, which is Phase 2 (D8).
class LiveBoardScreen extends ConsumerWidget {
  const LiveBoardScreen({super.key, required this.basePath});

  /// `/doctor` or `/assistant`.
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(currentBranchProvider);
    if (branchId == null) {
      final branches = ref.watch(staffBranchesProvider);
      return AsyncValueView(
        value: branches,
        onRetry: () => ref.invalidate(staffBranchesProvider),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.store_mall_directory_outlined, message: context.l10n.noBranches)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return _Board(branchId: branchId, basePath: basePath);
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.branchId, required this.basePath});

  final String branchId;
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final board = ref.watch(boardProvider(branchId));
    final width = MediaQuery.sizeOf(context).width;

    return AsyncValueView(
      value: board,
      onRetry: () => ref.invalidate(boardProvider(branchId)),
      data: (state) {
        final snapshot = state.snapshot;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.offline)
              Container(
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Text(l10n.boardOffline, textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
              ),
            _TopBar(branchId: branchId, basePath: basePath, snapshot: snapshot, offline: state.offline),
            _Counters(snapshot: snapshot),
            Expanded(
              child: width >= Breakpoints.tablet
                  ? _Columns(branchId: branchId, basePath: basePath, snapshot: snapshot, offline: state.offline)
                  : _Tabs(branchId: branchId, basePath: basePath, snapshot: snapshot, offline: state.offline),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.branchId, required this.basePath, required this.snapshot, required this.offline});

  final String branchId;
  final String basePath;
  final BoardSnapshot snapshot;
  final bool offline;

  Future<void> _menu(BuildContext context, WidgetRef ref, String action) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(boardProvider(branchId).notifier);
    try {
      if (action == 'delay') {
        final minutes = await showDialog<int>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.doctorDelayed),
            children: [
              for (final m in [15, 30, 45, 60])
                SimpleDialogOption(onPressed: () => Navigator.pop(context, m), child: Text(l10n.minutesCount(m))),
            ],
          ),
        );
        if (minutes == null) return;
        final n = await controller.sendDelay(minutes);
        messenger.showSnackBar(SnackBar(content: Text(l10n.patientsNotified(n))));
      } else if (action == 'cancelRest') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.cancelRestOfDay),
            content: Text(l10n.cancelRestOfDayBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.confirm)),
            ],
          ),
        );
        if (ok != true) return;
        final n = await controller.cancelRestOfDay(null);
        messenger.showSnackBar(SnackBar(content: Text(l10n.bookingsCancelled(n))));
      }
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(context.mounted ? context.bookingError(error) : '$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const BranchPicker(),
          FilledButton.icon(
            onPressed: offline ? null : () => context.push('$basePath/appointments/book'),
            icon: const Icon(Icons.add),
            label: Text(l10n.book),
          ),
          OutlinedButton.icon(
            onPressed: offline ? null : () => showDialog<void>(context: context, builder: (_) => WalkInDialog(branchId: branchId)),
            icon: const Icon(Icons.directions_walk),
            label: Text(l10n.walkIn),
          ),
          PopupMenuButton<String>(
            enabled: !offline,
            tooltip: l10n.more,
            onSelected: (v) => _menu(context, ref, v),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'delay', child: Text(l10n.doctorDelayed)),
              PopupMenuItem(value: 'cancelRest', child: Text(l10n.cancelRestOfDay)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({required this.snapshot});

  final BoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final booked = snapshot.entries.where((e) => e.stage != BoardStage.missed).length;
    final arrived = snapshot.entries.where((e) => e.stage == BoardStage.waiting || e.stage == BoardStage.withDoctor || e.stage == BoardStage.done).length;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (snapshot.mode == 'queue')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsetsDirectional.only(end: 12),
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Text(l10n.nowServing, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                  Text('${snapshot.nowServing ?? '–'}',
                      style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          Expanded(
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                Text(l10n.countBooked(booked)),
                Text(l10n.countArrived(arrived)),
                for (final stage in [BoardStage.waiting, BoardStage.withDoctor, BoardStage.done, BoardStage.missed])
                  Text('${context.boardStage(stage)}: ${snapshot.stage(stage).length}'),
                if (snapshot.delayMinutes != null) Text(l10n.delayedBy(snapshot.delayMinutes!), style: TextStyle(color: theme.colorScheme.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Columns extends StatelessWidget {
  const _Columns({required this.branchId, required this.basePath, required this.snapshot, required this.offline});

  final String branchId;
  final String basePath;
  final BoardSnapshot snapshot;
  final bool offline;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth / 5).clamp(220.0, 320.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final stage in BoardStage.all)
                  SizedBox(
                    width: columnWidth,
                    height: constraints.maxHeight,
                    child: _StageList(branchId: branchId, basePath: basePath, stage: stage, entries: snapshot.stage(stage), offline: offline, showHeader: true),
                  ),
              ],
            ),
          );
        },
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.branchId, required this.basePath, required this.snapshot, required this.offline});

  final String branchId;
  final String basePath;
  final BoardSnapshot snapshot;
  final bool offline;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: BoardStage.all.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final s in BoardStage.all) Tab(text: '${context.boardStage(s)} (${snapshot.stage(s).length})')],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final s in BoardStage.all)
                    _StageList(branchId: branchId, basePath: basePath, stage: s, entries: snapshot.stage(s), offline: offline, showHeader: false),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StageList extends StatelessWidget {
  const _StageList({required this.branchId, required this.basePath, required this.stage, required this.entries, required this.offline, required this.showHeader});

  final String branchId;
  final String basePath;
  final String stage;
  final List<BoardEntry> entries;
  final bool offline;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${context.boardStage(stage)} (${entries.length})', style: theme.textTheme.titleSmall),
          ),
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text(context.l10n.boardEmptyStage, style: TextStyle(color: theme.colorScheme.outline)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: entries.length,
                  itemBuilder: (context, i) => BoardCard(branchId: branchId, basePath: basePath, entry: entries[i], offline: offline),
                ),
        ),
      ],
    );
  }
}

/// One patient on the board. The main action matches the stage (6.13).
class BoardCard extends ConsumerWidget {
  const BoardCard({super.key, required this.branchId, required this.basePath, required this.entry, required this.offline});

  final String branchId;
  final String basePath;
  final BoardEntry entry;
  final bool offline;

  static (String, String)? mainAction(BuildContext context, BoardEntry e) => switch (e.stage) {
        BoardStage.expected => e.pending ? ('confirm', context.l10n.confirmBooking) : ('check-in', context.l10n.checkIn),
        BoardStage.waiting => ('call-in', context.l10n.callIn),
        BoardStage.missed when e.status == 'noShow' => ('undo-no-show', context.l10n.undoNoShow),
        _ => null,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.el3yadaColors;
    final action = mainAction(context, entry);
    final waitedMinutes = entry.checkedInAt == null || entry.stage != BoardStage.waiting ? null : DateTime.now().difference(entry.checkedInAt!).inMinutes;
    final waitColor = waitedMinutes == null ? null : waitedMinutes >= 40 ? theme.colorScheme.error : waitedMinutes >= 20 ? theme.colorScheme.tertiary : theme.colorScheme.outline;
    final isNew = DateTime.now().difference(entry.createdAt).inMinutes < 1 && entry.stage == BoardStage.expected;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showPatientPanel(context, branchId: branchId, basePath: basePath, entry: entry, offline: offline),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(entry.queueNumber != null ? '${entry.queueNumber}' : entry.timeLocal ?? '',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.displayName, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (isNew) const NewBadge(),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.visitType == 'consultation' ? colors.consultation : colors.examination,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(context.visitTypeCode(entry.visitType), style: theme.textTheme.labelSmall?.copyWith(
                        color: entry.visitType == 'consultation' ? colors.onConsultation : colors.onExamination)),
                  ),
                  Icon(switch (entry.source) { 'patientApp' => Icons.phone_iphone, 'walkIn' => Icons.directions_walk, _ => Icons.support_agent },
                      size: 16, color: theme.colorScheme.outline),
                  if (entry.isNewPatient) Text(l10n.newPatient, style: theme.textTheme.labelSmall)
                  else if (entry.lastVisitDate != null)
                    Text(l10n.lastVisitOn(context.date(entry.lastVisitDate!), context.visitTypeCode(entry.lastVisitType ?? 'examination')),
                        style: theme.textTheme.labelSmall),
                  if (entry.priority) _Flag(icon: Icons.priority_high, label: l10n.priority),
                  if (entry.late) _Flag(icon: Icons.schedule, label: l10n.late),
                  if (entry.consultationNotAllowed) _Flag(icon: Icons.warning_amber, label: l10n.consultationNotAllowed),
                  if (entry.guest) _Flag(icon: Icons.person_add_alt, label: l10n.guest),
                  if (entry.pending) _Flag(icon: Icons.hourglass_top, label: l10n.apStatusPending),
                  if (entry.hasNotes) Icon(Icons.sticky_note_2_outlined, size: 16, semanticLabel: l10n.notes),
                  if (waitedMinutes != null) Text(l10n.waitedMinutes(waitedMinutes), style: theme.textTheme.labelSmall?.copyWith(color: waitColor)),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonal(
                    onPressed: offline ? null : () => runBoardAction(context, ref, branchId, entry.appointmentId, action.$1),
                    child: Text(action.$2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 2),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ),
    ]);
  }
}

/// Runs a board action. When someone acted first, says who (BR-LB4).
Future<void> runBoardAction(BuildContext context, WidgetRef ref, String branchId, String appointmentId, String action, {String? reason}) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = context.bookingError;
  final l10n = context.l10n;
  try {
    await ref.read(boardProvider(branchId).notifier).act(appointmentId, action, reason: reason);
  } catch (error) {
    final api = ApiError.from(error);
    messenger.showSnackBar(SnackBar(content: Text(api.code == 'ALREADY_HANDLED' ? l10n.errAlreadyHandled : message(error))));
  }
}

/// The patient side panel (6.13): a bottom sheet on phones, a side sheet on wide screens.
Future<void> showPatientPanel(BuildContext context, {required String branchId, required String basePath, required BoardEntry entry, required bool offline}) {
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
  final panel = _PatientPanel(branchId: branchId, basePath: basePath, entry: entry, offline: offline);
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Material(
          elevation: 8,
          child: SizedBox(width: 400, height: double.infinity, child: SafeArea(child: panel)),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (context) => FractionallySizedBox(heightFactor: 0.85, child: panel));
}

class _PatientPanel extends ConsumerWidget {
  const _PatientPanel({required this.branchId, required this.basePath, required this.entry, required this.offline});

  final String branchId;
  final String basePath;
  final BoardEntry entry;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.el3yadaColors;
    final summary = ref.watch(boardSummaryProvider(entry.appointmentId));

    Future<void> act(String action, {String? reason}) async {
      Navigator.of(context).pop();
      await runBoardAction(context, ref, branchId, entry.appointmentId, action, reason: reason);
    }

    final actions = <(String, String)>[
      if (entry.stage == BoardStage.expected) ...[
        if (entry.pending) ('confirm', l10n.confirmBooking),
        ('check-in', l10n.checkIn),
        ('no-show', l10n.markNoShow),
      ],
      if (entry.stage == BoardStage.waiting) ...[('call-in', l10n.callIn), ('left-without-seen', l10n.leftWithoutSeen)],
      if (entry.stage == BoardStage.withDoctor) ...[('send-back', l10n.sendBack), ('left-without-seen', l10n.leftWithoutSeen)],
      if (entry.status == 'noShow') ('undo-no-show', l10n.undoNoShow),
    ];

    return AsyncValueView(
      value: summary,
      onRetry: () => ref.invalidate(boardSummaryProvider(entry.appointmentId)),
      data: (s) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.displayName, style: theme.textTheme.titleLarge),
          Text([
            if (s.fileNumber != null) l10n.fileNumber(s.fileNumber!),
            if (s.age != null) l10n.ageYears(s.age!),
            if (s.isGuest) l10n.guest,
          ].join(' · ')),
          if (s.phone != null)
            Wrap(spacing: 8, children: [
              TextButton.icon(onPressed: () => ContactLauncher.call(s.phone!), icon: const Icon(Icons.call_outlined),
                  label: Text(context.localPhone(s.phone!), textDirection: TextDirection.ltr)),
              TextButton.icon(onPressed: () => ContactLauncher.whatsApp(s.phone!), icon: const Icon(Icons.chat_outlined), label: Text(l10n.whatsApp)),
            ]),
          if (s.allergies != null && s.allergies!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colors.allergy, borderRadius: BorderRadius.circular(12)),
              child: Text('${l10n.allergies}: ${s.allergies!.join('، ')}', style: TextStyle(color: colors.onAllergy)),
            ),
          LabeledValue(label: l10n.visitsCount, value: '${s.examCount} ${l10n.visitTypeExamination} · ${s.consultationCount} ${l10n.visitTypeConsultation}'),
          if (s.lastVisitAt != null) LabeledValue(label: l10n.lastVisit, value: context.date(s.lastVisitAt!)),
          if (s.lastDiagnosis != null) LabeledValue(label: l10n.diagnosis, value: s.lastDiagnosis!),
          if (s.chronicDiseases != null && s.chronicDiseases!.isNotEmpty) LabeledValue(label: l10n.chronicDiseases, value: s.chronicDiseases!.join('، ')),
          if (s.recentAmountsPiasters != null && s.recentAmountsPiasters!.isNotEmpty)
            LabeledValue(label: l10n.recentAmounts, value: s.recentAmountsPiasters!.map(context.price).join(' · ')),
          LabeledValue(label: l10n.upcomingAndNoShows, value: '${s.upcomingBookings} · ${s.noShows}'),
          if (s.reason != null) LabeledValue(label: l10n.bookingReason, value: s.reason!),
          if (s.staffNotes != null) LabeledValue(label: l10n.staffNotes, value: s.staffNotes!),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (action, label) in actions)
                FilledButton.tonal(onPressed: offline ? null : () => act(action), child: Text(label)),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('$basePath/appointments/${entry.appointmentId}');
                },
                child: Text(l10n.openBooking),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
