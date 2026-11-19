import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../application/appointment_providers.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment_models.dart';
import 'appointment_format.dart';
import 'branch_picker.dart';

/// D29 Working hours, Special dates and Booking settings tabs; AS17 for assistants with
/// `scheduleManage`. Saving runs a dry run first: bookings that no longer fit are listed in the
/// conflicts sheet, each to keep or cancel (BR-AP12).
class ScheduleEditorScreen extends ConsumerWidget {
  const ScheduleEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(currentBranchProvider);
    if (branchId == null) return const Center(child: CircularProgressIndicator());
    final schedule = ref.watch(scheduleProvider(branchId));
    return AsyncValueView(
      value: schedule,
      onRetry: () => ref.invalidate(scheduleProvider(branchId)),
      data: (data) => _Editor(key: ValueKey(branchId), initial: data),
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.initial});

  final BranchScheduleData initial;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late BranchScheduleData _data = widget.initial;
  bool _saving = false;

  // The clinic week starts on Saturday (spec 8).
  static const _weekOrder = [6, 7, 1, 2, 3, 4, 5];

  void _setWeekly(List<WeeklyPeriod> weekly) => setState(() => _data = _data.copyWith(weekly: weekly));

  Future<void> _save() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(appointmentsRepositoryProvider);
    setState(() => _saving = true);
    try {
      final preview = await repository.saveSchedule(_data, dryRun: true);
      var decisions = <String, String>{};
      if (preview.conflicts.isNotEmpty) {
        if (!mounted) return;
        final chosen = await showModalBottomSheet<Map<String, String>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => _ConflictsSheet(conflicts: preview.conflicts),
        );
        if (chosen == null) return;
        decisions = chosen;
      }
      final result = await repository.saveSchedule(_data, dryRun: false, decisions: decisions);
      if (!result.applied) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.scheduleConflictsLeft)));
        return;
      }
      ref.invalidate(scheduleProvider(_data.branchId));
      ref.invalidate(availabilityProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.scheduleSaved)));
    } catch (error) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(context.bookingError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              const BranchPicker(),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: Text(l10n.save),
              ),
            ]),
          ),
          TabBar(tabs: [Tab(text: l10n.workingHours), Tab(text: l10n.specialDates), Tab(text: l10n.bookingSettings)]),
          Expanded(
            child: TabBarView(children: [
              _weeklyTab(context),
              _datesTab(context),
              _settingsTab(context),
            ]),
          ),
        ],
      ),
    );
  }

  // ---- Working hours ----------------------------------------------------------------------------

  Widget _weeklyTab(BuildContext context) {
    final l10n = context.l10n;
    final queue = _data.settings.mode == 'queue';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(l10n.copySaturdayToAll),
            onPressed: () {
              final saturday = _data.weekly.where((p) => p.weekday == 6).toList();
              _setWeekly([
                for (final d in _weekOrder)
                  for (final p in saturday) p.copyWith(weekday: d),
              ]);
            },
          ),
        ),
        for (final day in _weekOrder)
          ContentWidth(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Text(context.weekday(day), style: Theme.of(context).textTheme.titleSmall)),
                      IconButton(
                        tooltip: l10n.addPeriod,
                        icon: const Icon(Icons.add),
                        onPressed: () => _setWeekly([..._data.weekly, WeeklyPeriod(weekday: day, start: '17:00', end: '21:00')]),
                      ),
                    ]),
                    if (!_data.weekly.any((p) => p.weekday == day)) Text(l10n.closedDay, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    for (final p in _data.weekly.where((p) => p.weekday == day))
                      _PeriodRow(
                        period: p,
                        queue: queue,
                        onChanged: (changed) => _setWeekly([for (final x in _data.weekly) identical(x, p) ? changed : x]),
                        onRemove: () => _setWeekly([for (final x in _data.weekly) if (!identical(x, p)) x]),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---- Special dates and closures ---------------------------------------------------------------

  Widget _datesTab(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(child: Text(l10n.specialDates, style: theme.textTheme.titleSmall)),
                TextButton.icon(
                  icon: const Icon(Icons.event_busy),
                  label: Text(l10n.closeADay),
                  onPressed: () async {
                    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (date == null) return;
                    setState(() => _data = _data.copyWith(overrides: [..._data.overrides.where((o) => o.date != date), DateOverride(date: date)]));
                  },
                ),
              ]),
              for (final o in _data.overrides)
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(context.date(o.date)),
                  subtitle: Text(o.periods.isEmpty
                      ? l10n.closedDay
                      : o.periods.map((p) => l10n.timeRange(context.clock(p.start), context.clock(p.end))).join('، ')),
                  trailing: IconButton(
                    tooltip: l10n.remove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _data = _data.copyWith(overrides: [for (final x in _data.overrides) if (!identical(x, o)) x])),
                  ),
                ),
              const Divider(height: 32),
              Row(children: [
                Expanded(child: Text(l10n.closures, style: theme.textTheme.titleSmall)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addClosure),
                  onPressed: () async {
                    final range = await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (range == null || !context.mounted) return;
                    final allBranches = await showDialog<bool>(
                      context: context,
                      builder: (context) => SimpleDialog(title: Text(l10n.closureScope), children: [
                        SimpleDialogOption(onPressed: () => Navigator.pop(context, false), child: Text(l10n.thisBranch)),
                        SimpleDialogOption(onPressed: () => Navigator.pop(context, true), child: Text(l10n.allBranches)),
                      ]),
                    );
                    if (allBranches == null) return;
                    setState(() => _data = _data.copyWith(closures: [
                          ..._data.closures,
                          Closure(from: range.start, to: range.end.add(const Duration(days: 1)), allBranches: allBranches),
                        ]));
                  },
                ),
              ]),
              for (final c in _data.closures)
                ListTile(
                  leading: Icon(c.allBranches ? Icons.beach_access_outlined : Icons.block),
                  title: Text('${context.date(c.from)} – ${context.date(c.to.subtract(const Duration(minutes: 1)))}'),
                  subtitle: Text([c.allBranches ? l10n.allBranches : l10n.thisBranch, ?c.reason].join(' · ')),
                  trailing: IconButton(
                    tooltip: l10n.remove,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _data = _data.copyWith(closures: [for (final x in _data.closures) if (!identical(x, c)) x])),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Booking settings (6.12.2) ------------------------------------------------------------------

  Widget _settingsTab(BuildContext context) {
    final l10n = context.l10n;
    final s = _data.settings;
    void set(BookingSettings next) => setState(() => _data = _data.copyWith(settings: next));

    Widget number(String label, int value, List<int> choices, ValueChanged<int> onChanged) => ListTile(
          title: Text(label),
          trailing: DropdownButton<int>(
            value: choices.contains(value) ? value : null,
            hint: Text('$value'),
            items: [for (final c in choices) DropdownMenuItem(value: c, child: Text('$c'))],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: Text(l10n.bookingMode),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<String>(
                    segments: [ButtonSegment(value: 'queue', label: Text(l10n.modeQueue)), ButtonSegment(value: 'timed', label: Text(l10n.modeTimed))],
                    selected: {s.mode},
                    onSelectionChanged: (v) => set(s.copyWith(mode: v.single)),
                  ),
                ),
              ),
              if (s.mode == 'timed') number(l10n.slotMinutes, s.slotMinutes, const [5, 10, 15, 20, 30, 45, 60], (v) => set(s.copyWith(slotMinutes: v))),
              if (s.mode == 'queue') ...[
                number(l10n.defaultCapacity, s.defaultCapacity, const [5, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100], (v) => set(s.copyWith(defaultCapacity: v))),
                number(l10n.avgVisitMinutes, s.avgVisitMinutes, const [5, 10, 15, 20, 30], (v) => set(s.copyWith(avgVisitMinutes: v))),
              ],
              SwitchListTile(title: Text(l10n.selfBooking), value: s.selfBooking, onChanged: (v) => set(s.copyWith(selfBooking: v))),
              SwitchListTile(title: Text(l10n.autoConfirm), value: s.autoConfirm, onChanged: (v) => set(s.copyWith(autoConfirm: v))),
              SwitchListTile(title: Text(l10n.sameDayBooking), value: s.sameDay, onChanged: (v) => set(s.copyWith(sameDay: v))),
              SwitchListTile(title: Text(l10n.staffOverbooking), value: s.staffOverbooking, onChanged: (v) => set(s.copyWith(staffOverbooking: v))),
              number(l10n.windowDays, s.windowDays, const [7, 14, 30, 60, 90, 180], (v) => set(s.copyWith(windowDays: v))),
              number(l10n.minNoticeMinutes, s.minNoticeMinutes, const [0, 30, 60, 120, 240, 1440], (v) => set(s.copyWith(minNoticeMinutes: v))),
              number(l10n.freeCancelMinutes, s.freeCancelMinutes, const [0, 60, 120, 240, 720, 1440], (v) => set(s.copyWith(freeCancelMinutes: v))),
              number(l10n.maxReschedules, s.maxReschedules, const [0, 1, 2, 3, 4, 5], (v) => set(s.copyWith(maxReschedules: v))),
              number(l10n.maxUpcoming, s.maxUpcomingPerPatient, const [1, 2, 3, 4, 5], (v) => set(s.copyWith(maxUpcomingPerPatient: v))),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.queue, required this.onChanged, required this.onRemove});

  final WeeklyPeriod period;
  final bool queue;
  final ValueChanged<WeeklyPeriod> onChanged;
  final VoidCallback onRemove;

  Future<String?> _pick(BuildContext context, String current) async {
    final parts = current.split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
    return t == null ? null : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: () async {
            final v = await _pick(context, period.start);
            if (v != null) onChanged(period.copyWith(start: v));
          },
          child: Text(context.clock(period.start)),
        ),
        const Text('–'),
        OutlinedButton(
          onPressed: () async {
            final v = await _pick(context, period.end);
            if (v != null) onChanged(period.copyWith(end: v, endsNextDay: v.compareTo(period.start) <= 0));
          },
          child: Text(context.clock(period.end)),
        ),
        if (period.endsNextDay) Text(l10n.nextDayShort),
        if (queue)
          SizedBox(
            width: 90,
            child: TextFormField(
              initialValue: period.capacity?.toString() ?? '',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.capacity, isDense: true),
              onChanged: (v) => onChanged(WeeklyPeriod(weekday: period.weekday, start: period.start, end: period.end,
                  endsNextDay: period.endsNextDay, label: period.label, capacity: int.tryParse(v))),
            ),
          ),
        IconButton(tooltip: l10n.remove, icon: const Icon(Icons.delete_outline), onPressed: onRemove),
      ],
    );
  }
}

/// BR-AP12: every affected booking is kept as an exception or cancelled (patients are told).
/// Moving one is a reschedule from the booking itself, before saving.
class _ConflictsSheet extends StatefulWidget {
  const _ConflictsSheet({required this.conflicts});

  final List<ScheduleConflict> conflicts;

  @override
  State<_ConflictsSheet> createState() => _ConflictsSheetState();
}

class _ConflictsSheetState extends State<_ConflictsSheet> {
  late final Map<String, String> _decisions = {for (final c in widget.conflicts) c.appointmentId: 'keep'};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.affectedBookings(widget.conflicts.length), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              TextButton(onPressed: () => setState(() => _decisions.updateAll((_, _) => 'keep')), child: Text(l10n.keepAll)),
              TextButton(onPressed: () => setState(() => _decisions.updateAll((_, _) => 'cancel')), child: Text(l10n.cancelAll)),
            ]),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in widget.conflicts)
                    ListTile(
                      title: Text(c.displayName),
                      subtitle: Text('${context.date(c.date)} · ${context.clock(c.time)}${c.queueNumber != null ? ' · ${l10n.queueNumber(c.queueNumber!)}' : ''}'),
                      trailing: SegmentedButton<String>(
                        segments: [ButtonSegment(value: 'keep', label: Text(l10n.keep)), ButtonSegment(value: 'cancel', label: Text(l10n.cancel))],
                        selected: {_decisions[c.appointmentId]!},
                        onSelectionChanged: (v) => setState(() => _decisions[c.appointmentId] = v.single),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: () => Navigator.pop(context, _decisions), child: Text(l10n.applyChanges)),
          ],
        ),
      ),
    );
  }
}
