import 'package:material_ui/material_ui.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../appointments/domain/appointment_models.dart';
import '../../domain/weekly_hours.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'branch_drafts.dart';
import 'branch_fields.dart';
import 'branch_text.dart';
import 'schedule_drafts.dart';

// D29's Special dates and Booking settings tabs (spec 6.12.2, BR-AP13). The
// Working hours tab is HoursEditor. All three save through
// `updateBranchSchedule`, with the conflicts sheet (BR-AP12).

/// «السبت 28 نوفمبر 2026».
String scheduleDayText(BuildContext context, DateTime day) => '${weekdayName(context, day.weekday)} ${dayText(context, day)}';

String _clock(DateTime t) => WeeklyHours.format(t.hour * 60 + t.minute);

/// When a closure runs: «السبت 28 نوفمبر – الاثنين 30 نوفمبر» for whole
/// days, «السبت 28 نوفمبر · 6:00 م – 8:00 م» for part of a day.
String closureText(BuildContext context, Closure closure) {
  final l10n = AppLocalizations.of(context);
  final from = closure.from;
  final to = closure.to;
  final wholeDays = from.hour == 0 && from.minute == 0 && to.hour == 0 && to.minute == 0;
  if (wholeDays) {
    final last = to.subtract(const Duration(days: 1));
    final sameDay = last.year == from.year && last.month == from.month && last.day == from.day;
    return sameDay ? scheduleDayText(context, from) : l10n.adminDateRange(scheduleDayText(context, from), scheduleDayText(context, last));
  }
  return '${scheduleDayText(context, from)}${l10n.regListSeparator}'
      '${l10n.adminDateRange(clockText(context, _clock(from)), clockText(context, _clock(to)))}';
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

// -----------------------------------------------------------------------------
// Special dates

/// Special hours for one date (they replace the weekday's hours; none means
/// closed), then closures and blocked time for this branch or every branch.
class SpecialDatesEditor extends StatelessWidget {
  const SpecialDatesEditor({
    super.key,
    required this.draft,
    required this.queueMode,
    required this.defaultCapacity,
    this.enabled = true,
    this.extra,
  });

  final DatesDraft draft;
  final bool queueMode;
  final int defaultCapacity;
  final bool enabled;

  /// Shown between the two cards (the public holidays the admin suggests).
  final Widget? extra;

  Future<void> _addDay(BuildContext context) async {
    final today = _today();
    final date = await showDatePicker(context: context, firstDate: today, lastDate: today.add(const Duration(days: 365)), initialDate: today);
    if (date == null || !context.mounted) return;
    final existing = draft.overrides.where((o) => o.date.year == date.year && o.date.month == date.month && o.date.day == date.day).firstOrNull;
    // A new date starts closed; switching that off gives it hours.
    await _editDay(context, existing ?? DateOverride(date: date));
  }

  Future<void> _editDay(BuildContext context, DateOverride day) async {
    final result = await showDialog<DateOverride>(
      context: context,
      builder: (context) => _SpecialDayDialog(day: day, queueMode: queueMode, defaultCapacity: defaultCapacity),
    );
    if (result != null) draft.setDay(result);
  }

  Future<void> _addClosure(BuildContext context) async {
    final result = await showDialog<Closure>(context: context, builder: (context) => const _ClosureDialog());
    if (result != null) draft.addClosure(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          icon: Icons.event_note_outlined,
          title: l10n.scheduleSpecialHoursTitle,
          subtitle: l10n.scheduleSpecialHoursBody,
          trailing: TextButton.icon(
            onPressed: enabled ? () => _addDay(context) : null,
            icon: const Icon(Icons.add),
            label: Text(l10n.scheduleAddSpecialDay),
          ),
          child: MotionSize(
            alignment: AlignmentDirectional.topStart,
            child: draft.overrides.isEmpty
                ? Text(l10n.scheduleNoSpecialDays, style: muted)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final day in draft.overrides)
                        _DateRow(
                          key: ValueKey('day-${dayText(context, day.date)}'),
                          icon: day.periods.isEmpty ? Icons.event_busy_outlined : Icons.edit_calendar_outlined,
                          title: scheduleDayText(context, day.date),
                          subtitle: day.periods.isEmpty
                              ? l10n.scheduleDayClosed
                              : [for (final p in day.periods) periodText(context, p.toBranchPeriod())].join(l10n.regListSeparator),
                          onTap: enabled ? () => _editDay(context, day) : null,
                          onRemove: enabled ? () => draft.removeDay(day) : null,
                        ),
                    ],
                  ),
          ),
        ),
        if (extra != null) ...[const SizedBox(height: 16), extra!],
        const SizedBox(height: 16),
        SectionCard(
          icon: Icons.beach_access_outlined,
          title: l10n.closures,
          subtitle: l10n.scheduleClosuresBody,
          trailing: TextButton.icon(
            onPressed: enabled ? () => _addClosure(context) : null,
            icon: const Icon(Icons.add),
            label: Text(l10n.addClosure),
          ),
          child: MotionSize(
            alignment: AlignmentDirectional.topStart,
            child: draft.closures.isEmpty
                ? Text(l10n.scheduleNoClosures, style: muted)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final closure in draft.closures)
                        _DateRow(
                          key: ObjectKey(closure),
                          icon: closure.allBranches ? Icons.beach_access_outlined : Icons.block_outlined,
                          title: closureText(context, closure),
                          subtitle: [closure.allBranches ? l10n.allBranches : l10n.thisBranch, ?closure.reason].join(l10n.regListSeparator),
                          onRemove: enabled ? () => draft.removeClosure(closure) : null,
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({super.key, required this.icon, required this.title, required this.subtitle, this.onTap, this.onRemove});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
            child: Row(
              children: [
                RowIcon(icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(tooltip: l10n.remove, onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hours of one date: periods like a weekday's, or closed all day.
class _SpecialDayDialog extends StatefulWidget {
  const _SpecialDayDialog({required this.day, required this.queueMode, required this.defaultCapacity});

  final DateOverride day;
  final bool queueMode;
  final int defaultCapacity;

  @override
  State<_SpecialDayDialog> createState() => _SpecialDayDialogState();
}

class _SpecialDayDialogState extends State<_SpecialDayDialog> {
  late final int _weekday = widget.day.date.weekday;
  late final _hours = HoursDraft([for (final p in widget.day.periods) p.copyWith(weekday: _weekday).toBranchPeriod()]);
  late bool _closed = widget.day.periods.isEmpty;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    // A new date starts with one period, like a weekday.
    if (_hours.periods.isEmpty) _hours.add(_weekday);
  }

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Map<int, List<String>> _errors(AppLocalizations l10n) {
    if (!_tried || _closed) return const {};
    final errors = <int, List<String>>{};
    for (final problem in WeeklyHours.check(_hours.build())) {
      if (problem.index < 0) continue;
      (errors[problem.index] ??= []).add(l10n.fieldError(problem.code) ?? l10n.adminErrorInvalidValue);
    }
    return errors;
  }

  void _save() {
    final periods = _hours.build();
    if (!_closed && (periods.isEmpty || WeeklyHours.check(periods).isNotEmpty)) {
      setState(() => _tried = true);
      if (periods.isEmpty) setState(() => _closed = true);
      return;
    }
    Navigator.pop(
      context,
      DateOverride(date: widget.day.date, periods: _closed ? const [] : [for (final p in periods) p.toWeekly().copyWith(weekday: 0)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.edit_calendar_outlined),
      title: Text(scheduleDayText(context, widget.day.date)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 320),
        child: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: _hours.edits,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.scheduleDayClosedToggle),
                  value: _closed,
                  onChanged: (on) => setState(() => _closed = on),
                ),
                MotionSize(
                  alignment: AlignmentDirectional.topStart,
                  child: _closed
                      ? const SizedBox(width: double.infinity)
                      : DayHoursEditor(
                          draft: _hours,
                          weekday: _weekday,
                          title: l10n.scheduleDayHours,
                          queueMode: widget.queueMode,
                          defaultCapacity: widget.defaultCapacity,
                          periodErrors: _errors(l10n),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

/// A closure: whole days (one or a range) or part of one day, for this
/// branch or every branch (a vacation), with an optional reason.
class _ClosureDialog extends StatefulWidget {
  const _ClosureDialog();

  @override
  State<_ClosureDialog> createState() => _ClosureDialogState();
}

class _ClosureDialogState extends State<_ClosureDialog> {
  final _reason = TextEditingController();
  bool _partOfDay = false;
  bool _allBranches = false;
  DateTimeRange? _days;
  DateTime? _date;
  TimeOfDay _from = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 20, minute: 0);
  bool _tried = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDays() async {
    final today = _today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _days,
    );
    if (picked != null) setState(() => _days = picked);
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(context: context, firstDate: today, lastDate: today.add(const Duration(days: 365)), initialDate: _date ?? today);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool from}) async {
    final picked = await showTimePicker(context: context, initialTime: from ? _from : _to);
    if (picked == null) return;
    setState(() => from ? _from = picked : _to = picked);
  }

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String? get _problem {
    final l10n = AppLocalizations.of(context);
    if (_partOfDay) {
      if (_date == null) return l10n.errorRequired;
      if (_minutes(_to) <= _minutes(_from)) return l10n.scheduleClosureEndBeforeStart;
      return null;
    }
    return _days == null ? l10n.errorRequired : null;
  }

  void _save() {
    if (_problem != null) {
      setState(() => _tried = true);
      return;
    }
    final reason = _reason.text.trim();
    final (from, to) = _partOfDay
        ? (
            DateTime(_date!.year, _date!.month, _date!.day, _from.hour, _from.minute),
            DateTime(_date!.year, _date!.month, _date!.day, _to.hour, _to.minute),
          )
        : (
            DateTime(_days!.start.year, _days!.start.month, _days!.start.day),
            DateTime(_days!.end.year, _days!.end.month, _days!.end.day).add(const Duration(days: 1)),
          );
    Navigator.pop(context, Closure(from: from, to: to, reason: reason.isEmpty ? null : reason, allBranches: _allBranches));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = _tried ? _problem : null;
    final days = _days;
    String clock(TimeOfDay t) => clockText(context, WeeklyHours.format(_minutes(t)));
    return AlertDialog(
      icon: const Icon(Icons.beach_access_outlined),
      title: Text(l10n.addClosure),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, icon: const Icon(Icons.date_range_outlined), label: Text(l10n.scheduleClosureWholeDays)),
                  ButtonSegment(value: true, icon: const Icon(Icons.schedule_outlined), label: Text(l10n.scheduleClosurePartDay)),
                ],
                selected: {_partOfDay},
                onSelectionChanged: (v) => setState(() => _partOfDay = v.single),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
                switchInCurve: Motion.enterCurve,
                switchOutCurve: Motion.exitCurve,
                child: _partOfDay
                    ? Column(
                        key: const ValueKey('part'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(_date == null ? l10n.schedulePickDate : scheduleDayText(context, _date!)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pickTime(from: true),
                                  child: Text('${l10n.branchPeriodFrom} ${clock(_from)}'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _pickTime(from: false),
                                  child: Text('${l10n.branchPeriodTo} ${clock(_to)}'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        key: const ValueKey('days'),
                        onPressed: _pickDays,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(days == null
                            ? l10n.schedulePickDates
                            : closureText(context, Closure(from: days.start, to: days.end.add(const Duration(days: 1))))),
                      ),
              ),
              if (problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(problem, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 16),
              Text(l10n.closureScope, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, icon: const Icon(Icons.store_mall_directory_outlined), label: Text(l10n.thisBranch)),
                  ButtonSegment(value: true, icon: const Icon(Icons.storefront_outlined), label: Text(l10n.allBranches)),
                ],
                selected: {_allBranches},
                onSelectionChanged: (v) => setState(() => _allBranches = v.single),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                maxLength: 300,
                decoration: InputDecoration(labelText: l10n.scheduleClosureReason, hintText: l10n.scheduleClosureReasonHint),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.addClosure)),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Booking settings

/// Every setting of spec 6.12.2, in four groups: the mode, booking from the
/// app, no-shows and reminders, and the clinic's own bookings.
class BookingSettingsEditor extends StatelessWidget {
  const BookingSettingsEditor({super.key, required this.draft, this.enabled = true});

  final BookingSettingsDraft draft;
  final bool enabled;

  static const _slotChoices = [5, 10, 15, 20, 30, 45, 60];
  static const _slotsPerVisit = [1, 2, 3, 4];
  static const _capacityChoices = [5, 10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 150, 200];
  static const _avgChoices = [5, 10, 15, 20, 30, 45, 60];
  static const _windowChoices = [7, 14, 30, 60, 90, 180];
  static const _noticeChoices = [0, 30, 60, 120, 240, 720, 1440];
  static const _cancelChoices = [0, 60, 120, 240, 720, 1440, 2880];
  static const _rescheduleChoices = [0, 1, 2, 3, 4, 5];
  static const _upcomingChoices = [1, 2, 3, 4, 5];
  static const _noShowCounts = [1, 2, 3, 4, 5, 10];
  static const _noShowDays = [30, 60, 90, 180, 365];

  /// The two reminders of spec 6.12.2 (BR-AP16): a day before, and two hours before on the day.
  static const reminderDayBefore = 1440;
  static const reminderSameDay = 120;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = draft.value;
    final queue = s.mode == 'queue';
    void set(BookingSettings next) => draft.set(next);

    String minutes(int m) => m == 0
        ? l10n.bookingNone
        : m % 1440 == 0
            ? l10n.bookingDays(m ~/ 1440)
            : m % 60 == 0
                ? l10n.bookingHours(m ~/ 60)
                : l10n.bookingMinutes(m);

    Widget choice(IconData icon, String title, int value, List<int> choices, String Function(int) label, ValueChanged<int> onChanged,
            {String? subtitle}) =>
        SettingsTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          trailing: DropdownButton<int>(
            value: value,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            items: [
              for (final c in {...choices, value}.toList()..sort()) DropdownMenuItem(value: c, child: Text(label(c))),
            ],
            onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
          ),
        );

    Widget toggle(IconData icon, String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) =>
        SettingsSwitchTile(icon: icon, title: title, subtitle: subtitle, value: value, onChanged: enabled ? onChanged : null);

    final reminders = s.reminderMinutes.toSet();
    void reminder(int at, bool on) =>
        set(s.copyWith(reminderMinutes: ([...reminders.where((m) => m != at), if (on) at]..sort((a, b) => b.compareTo(a)))));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l10n.bookingMode,
          children: [
            SettingsTile(
              icon: queue ? Icons.confirmation_number_outlined : Icons.schedule_outlined,
              title: queue ? l10n.modeQueue : l10n.modeTimed,
              subtitle: queue ? l10n.bookingModeQueueBody : l10n.bookingModeTimedBody,
              below: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'queue', icon: const Icon(Icons.confirmation_number_outlined), label: Text(l10n.modeQueue)),
                  ButtonSegment(value: 'timed', icon: const Icon(Icons.schedule_outlined), label: Text(l10n.modeTimed)),
                ],
                selected: {s.mode},
                onSelectionChanged: enabled ? (v) => set(s.copyWith(mode: v.single)) : null,
              ),
            ),
            if (queue) ...[
              choice(Icons.groups_outlined, l10n.defaultCapacity, s.defaultCapacity, _capacityChoices, (v) => '$v',
                  (v) => set(s.copyWith(defaultCapacity: v)), subtitle: l10n.bookingCapacityBody),
              choice(Icons.timer_outlined, l10n.avgVisitMinutes, s.avgVisitMinutes, _avgChoices, l10n.bookingMinutes,
                  (v) => set(s.copyWith(avgVisitMinutes: v)), subtitle: l10n.bookingAvgVisitBody),
            ] else ...[
              choice(Icons.timelapse_outlined, l10n.slotMinutes, s.slotMinutes, _slotChoices, l10n.bookingMinutes,
                  (v) => set(s.copyWith(slotMinutes: v))),
              choice(Icons.medical_services_outlined, l10n.bookingExamSlots, s.examSlots, _slotsPerVisit, (v) => '$v',
                  (v) => set(s.copyWith(examSlots: v))),
              choice(Icons.forum_outlined, l10n.bookingConsultationSlots, s.consultationSlots, _slotsPerVisit, (v) => '$v',
                  (v) => set(s.copyWith(consultationSlots: v))),
            ],
          ],
        ),
        MotionSize(
          alignment: AlignmentDirectional.topStart,
          child: s.mode == draft.saved.mode
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: InfoBanner(icon: Icons.event_repeat_outlined, tone: PillTone.warning, message: l10n.bookingModeChangeNote),
                ),
        ),
        const SizedBox(height: 20),
        SettingsGroup(
          title: l10n.bookingGroupApp,
          children: [
            toggle(Icons.phone_iphone_outlined, l10n.selfBooking, s.selfBooking, (v) => set(s.copyWith(selfBooking: v))),
            toggle(Icons.task_alt_outlined, l10n.autoConfirm, s.autoConfirm, (v) => set(s.copyWith(autoConfirm: v)),
                subtitle: s.autoConfirm ? null : l10n.bookingAutoConfirmOffBody),
            toggle(Icons.today_outlined, l10n.sameDayBooking, s.sameDay, (v) => set(s.copyWith(sameDay: v))),
            choice(Icons.date_range_outlined, l10n.windowDays, s.windowDays, _windowChoices, l10n.bookingDays,
                (v) => set(s.copyWith(windowDays: v))),
            choice(Icons.hourglass_top_outlined, l10n.minNoticeMinutes, s.minNoticeMinutes, _noticeChoices, minutes,
                (v) => set(s.copyWith(minNoticeMinutes: v))),
            choice(Icons.free_cancellation_outlined, l10n.freeCancelMinutes, s.freeCancelMinutes, _cancelChoices, minutes,
                (v) => set(s.copyWith(freeCancelMinutes: v))),
            choice(Icons.event_repeat_outlined, l10n.maxReschedules, s.maxReschedules, _rescheduleChoices, (v) => '$v',
                (v) => set(s.copyWith(maxReschedules: v))),
            choice(Icons.event_available_outlined, l10n.maxUpcoming, s.maxUpcomingPerPatient, _upcomingChoices, (v) => '$v',
                (v) => set(s.copyWith(maxUpcomingPerPatient: v))),
          ],
        ),
        const SizedBox(height: 20),
        SettingsGroup(
          title: l10n.bookingGroupNoShows,
          children: [
            choice(Icons.person_off_outlined, l10n.bookingNoShowCount, s.noShowLimitCount, _noShowCounts, (v) => '$v',
                (v) => set(s.copyWith(noShowLimitCount: v)), subtitle: l10n.bookingNoShowBody(s.noShowLimitCount, s.noShowLimitDays)),
            choice(Icons.calendar_month_outlined, l10n.bookingNoShowDays, s.noShowLimitDays, _noShowDays, l10n.bookingDays,
                (v) => set(s.copyWith(noShowLimitDays: v))),
            toggle(Icons.notifications_active_outlined, l10n.bookingReminderDayBefore, reminders.contains(reminderDayBefore),
                (on) => reminder(reminderDayBefore, on)),
            toggle(Icons.alarm_outlined, l10n.bookingReminderSameDay, reminders.contains(reminderSameDay),
                (on) => reminder(reminderSameDay, on)),
          ],
        ),
        const SizedBox(height: 20),
        SettingsGroup(
          title: l10n.bookingGroupClinic,
          children: [
            toggle(Icons.playlist_add_outlined, l10n.staffOverbooking, s.staffOverbooking, (v) => set(s.copyWith(staffOverbooking: v))),
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Public holidays (AD13 [C], BR-AP13)

/// The coming public holidays the admin lists, as suggestions: "Close this
/// day" adds a whole-day closure for this branch (saved with the tab, so the
/// conflicts sheet lists any bookings). A holiday closes nothing by itself.
class HolidaySuggestions extends StatelessWidget {
  const HolidaySuggestions({super.key, required this.holidays, required this.draft, this.enabled = true});

  final List<HolidayRef> holidays;
  final DatesDraft draft;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return SectionCard(
      icon: Icons.celebration_outlined,
      title: l10n.holidaysTitle,
      subtitle: l10n.holidaysBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final holiday in holidays)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  RowIcon(Icons.event_outlined, muted: draft.closesWholeDay(holiday.date)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(holiday.name(arabic: arabic), style: theme.textTheme.titleSmall),
                        Text(scheduleDayText(context, holiday.date),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
                    child: draft.closesWholeDay(holiday.date)
                        ? StatusPill(key: const ValueKey('closed'), label: l10n.holidayClosed, tone: PillTone.neutral)
                        : TextButton.icon(
                            key: const ValueKey('close'),
                            onPressed: enabled
                                ? () {
                                    final day = DateTime(holiday.date.year, holiday.date.month, holiday.date.day);
                                    draft.addClosure(Closure(from: day, to: day.add(const Duration(days: 1)), reason: holiday.nameAr));
                                  }
                                : null,
                            icon: const Icon(Icons.event_busy_outlined),
                            label: Text(l10n.holidayCloseDay),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
