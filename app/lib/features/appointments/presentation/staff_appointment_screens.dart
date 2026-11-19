import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/platform/contact_launcher.dart';
import '../../../core/validation/validators.dart';
import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../application/appointment_providers.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment_models.dart';
import 'appointment_format.dart';
import 'branch_picker.dart';
import 'patient_appointment_screens.dart' show AppointmentRow;
import 'place_picker.dart';
import 'walk_in_dialog.dart';

// ---- D30 / AS13 calendar -------------------------------------------------------------------------

/// Day view with the bookings of the current branch, and the free places of each period.
class AppointmentsCalendarScreen extends ConsumerStatefulWidget {
  const AppointmentsCalendarScreen({super.key, required this.basePath});

  final String basePath;

  @override
  ConsumerState<AppointmentsCalendarScreen> createState() => _AppointmentsCalendarScreenState();
}

class _AppointmentsCalendarScreenState extends ConsumerState<AppointmentsCalendarScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final branchId = ref.watch(currentBranchProvider);
    final result = branchId == null ? null : ref.watch(searchProvider(SearchFilter(from: _day, to: _day, branchId: branchId)));
    final availability = branchId == null
        ? null
        : ref.watch(availabilityProvider(AvailabilityKey(branchId: branchId, visitType: 'examination', from: _day, staff: true)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const BranchPicker(),
            IconButton(tooltip: l10n.previousDay, onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left)),
            TextButton(
              onPressed: () async {
                final picked = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (picked != null) setState(() => _day = picked);
              },
              child: Text(context.date(_day)),
            ),
            IconButton(tooltip: l10n.nextDay, onPressed: () => setState(() => _day = _day.add(const Duration(days: 1))), icon: const Icon(Icons.chevron_right)),
            FilledButton.icon(onPressed: () => context.push('${widget.basePath}/appointments/book'), icon: const Icon(Icons.add), label: Text(l10n.book)),
            OutlinedButton.icon(onPressed: () => context.push('${widget.basePath}/appointments/search'), icon: const Icon(Icons.search), label: Text(l10n.searchBookings)),
          ]),
        ),
        if (availability?.value case final a?)
          for (final d in a.days.take(1))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if (d.reason != null) Chip(label: Text(context.bookingError(d.reason!))),
                for (final p in d.periods)
                  Chip(label: Text('${[?p.label, context.clock(p.start)].join(' ')}: ${l10n.placesLeft(p.remaining)}')),
              ]),
            ),
        Expanded(
          child: result == null
              ? const SizedBox.shrink()
              : AsyncValueView(
                  value: result,
                  onRetry: () => ref.invalidate(searchProvider),
                  data: (r) => r.items.isEmpty
                      ? EmptyState(icon: Icons.event_available, message: l10n.noAppointments)
                      : ListView(children: [
                          for (final a in r.items)
                            ContentWidth(
                              maxWidth: 900,
                              child: AppointmentRow(appointment: a, staff: true, onTap: () => context.push('${widget.basePath}/appointments/${a.id}')),
                            ),
                        ]),
                ),
        ),
      ],
    );
  }
}

// ---- D31 details ---------------------------------------------------------------------------------

class StaffAppointmentDetailScreen extends ConsumerWidget {
  const StaffAppointmentDetailScreen({super.key, required this.appointmentId, required this.basePath});

  final String appointmentId;
  final String basePath;

  Future<void> _act(BuildContext context, WidgetRef ref, String action, {bool askReason = false}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    String? reason;
    if (askReason) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.reasonLabel),
          content: TextField(controller: controller, maxLength: 200),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.confirm)),
          ],
        ),
      );
      if (ok != true) return;
      reason = controller.text.trim().isEmpty ? null : controller.text.trim();
    }
    try {
      final repository = ref.read(appointmentsRepositoryProvider);
      if (action == 'cancel') {
        await repository.cancel(appointmentId, reason: reason, staff: true);
      } else {
        await repository.act(appointmentId, action, reason: reason);
      }
      ref.invalidate(staffAppointmentProvider(appointmentId));
      ref.invalidate(searchProvider);
      final branch = ref.read(currentBranchProvider);
      if (branch != null) ref.invalidate(boardProvider(branch));
    } catch (error) {
      if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(context.bookingError(error))));
      ref.invalidate(staffAppointmentProvider(appointmentId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appointment = ref.watch(staffAppointmentProvider(appointmentId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appointmentDetails)),
      body: AsyncValueView(
        value: appointment,
        onRetry: () => ref.invalidate(staffAppointmentProvider(appointmentId)),
        data: (a) {
          final theme = Theme.of(context);
          final actions = <(String, String, bool)>[
            if (a.status == AppointmentStatus.pending) ...[('confirm', l10n.confirmBooking, false), ('reject', l10n.reject, true)],
            if (a.isUpcoming) ...[('check-in', l10n.checkIn, false), ('cancel', l10n.cancelBooking, true)],
            if (a.status == AppointmentStatus.confirmed) ('no-show', l10n.markNoShow, false),
            if (a.status == AppointmentStatus.checkedIn) ...[('call-in', l10n.callIn, false), ('left-without-seen', l10n.leftWithoutSeen, true)],
            if (a.status == AppointmentStatus.withDoctor) ('send-back', l10n.sendBack, false),
            if (a.status == AppointmentStatus.noShow) ('undo-no-show', l10n.undoNoShow, false),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ContentWidth(
                maxWidth: 900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Text(a.displayName, style: theme.textTheme.titleLarge)),
                      StatusChip(status: a.status),
                    ]),
                    if (a.isGuest) Text(l10n.guest, style: TextStyle(color: theme.colorScheme.tertiary)),
                    if (a.phone != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(onPressed: () => ContactLauncher.call(a.phone!), icon: const Icon(Icons.call_outlined),
                            label: Text(context.localPhone(a.phone!), textDirection: TextDirection.ltr)),
                      ),
                    LabeledValue(label: l10n.whenLabel, value: '${context.date(a.date)} · ${context.appointmentWhen(a)}'),
                    LabeledValue(label: l10n.branchesTitle, value: context.branchName(a.branch)),
                    LabeledValue(label: l10n.visitType, value: context.visitTypeCode(a.visitType)),
                    LabeledValue(label: l10n.bookedBy, value: [a.bookedByName ?? '', _source(context, a.source)].where((s) => s.isNotEmpty).join(' · ')),
                    if (a.reason != null) LabeledValue(label: l10n.bookingReason, value: a.reason!),
                    if (a.staffNotes != null) LabeledValue(label: l10n.staffNotes, value: a.staffNotes!),
                    if (a.overbooked) Text(l10n.overbooked, style: TextStyle(color: theme.colorScheme.tertiary)),
                    if (a.flaggedNoSession) Text(l10n.checkedInNoSession, style: TextStyle(color: theme.colorScheme.error)),
                    if (a.cancelReason != null) LabeledValue(label: l10n.reasonLabel, value: a.cancelReason!),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (action, label, reason) in actions)
                        FilledButton.tonal(onPressed: () => _act(context, ref, action, askReason: reason), child: Text(label)),
                      if (a.isUpcoming)
                        OutlinedButton(
                          onPressed: () => context.push('$basePath/appointments/book?reschedule=${a.id}'),
                          child: Text(l10n.reschedule),
                        ),
                    ]),
                    if (a.history.isNotEmpty) ...[
                      const Divider(height: 32),
                      Text(l10n.history, style: theme.textTheme.titleSmall),
                      for (final h in a.history)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('${h.action} · ${h.byName ?? h.byRole}'),
                          subtitle: Text([context.dateTime(h.at), ?h.reason].join(' · ')),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _source(BuildContext context, String s) => switch (s) {
        'patientApp' => context.l10n.sourceApp,
        'walkIn' => context.l10n.walkIn,
        _ => context.l10n.sourceStaff,
      };
}

// ---- D32 / AS14 book -----------------------------------------------------------------------------

class StaffBookScreen extends ConsumerStatefulWidget {
  const StaffBookScreen({super.key, required this.basePath, this.rescheduleId});

  final String basePath;
  final String? rescheduleId;

  @override
  ConsumerState<StaffBookScreen> createState() => _StaffBookScreenState();
}

class _StaffBookScreenState extends ConsumerState<StaffBookScreen> {
  bool _guest = false;
  PatientLookup? _patient;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  String? _visitType;
  PlaceChoice? _place;
  bool _saving = false;

  bool get _reschedule => widget.rescheduleId != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit(String branchId) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(appointmentsRepositoryProvider);
    String? phone;
    if (_guest && !_reschedule) {
      phone = Validators.normalizeEgyptianMobile(_phone.text);
      if (_name.text.trim().split(' ').where((w) => w.isNotEmpty).length < 2 || phone == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.guestNameAndPhone)));
        return;
      }
    }
    var request = BookingRequest(
      branchId: branchId,
      patientId: _guest ? null : _patient?.patientId,
      guestName: _guest ? _name.text.trim() : null,
      guestPhone: phone,
      visitType: _isNew ? 'examination' : (_visitType ?? 'examination'),
      date: _place!.date,
      time: _place!.time,
      staffNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    setState(() => _saving = true);
    try {
      while (true) {
        try {
          final result = _reschedule
              ? await repository.reschedule(widget.rescheduleId!, branchId: branchId, date: _place!.date, time: _place!.time,
                  overbook: request.overbook, staff: true)
              : await repository.book(request, staff: true);
          ref.invalidate(searchProvider);
          ref.invalidate(boardProvider(branchId));
          if (mounted) context.pushReplacement('${widget.basePath}/appointments/${result.id}');
          return;
        } catch (error) {
          final code = ApiError.from(error).code;
          // Staff may go past the limits after a warning (BR-AP7, BR-AP21, case 2).
          if (!mounted || (code != 'OVERBOOKING_WARNING' && code != 'UPCOMING_LIMIT')) rethrow;
          final go = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(code == 'OVERBOOKING_WARNING' ? l10n.overbookTitle : l10n.errUpcomingLimit),
              content: Text(code == 'OVERBOOKING_WARNING' ? l10n.overbookBody : l10n.upcomingWarningBody),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.bookAnyway)),
              ],
            ),
          );
          if (go != true) return;
          request = request.withWarnings(overbook: code == 'OVERBOOKING_WARNING' ? true : null, confirmWarnings: code == 'UPCOMING_LIMIT' ? true : null);
        }
      }
    } catch (error) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(context.bookingError(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _isNew => _guest || (_patient?.isNew ?? false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final branchId = ref.watch(currentBranchProvider);
    final ready = _reschedule || _guest || _patient != null;
    final visitType = _isNew ? 'examination' : _visitType;

    return Scaffold(
      appBar: AppBar(title: Text(_reschedule ? l10n.reschedule : l10n.bookAppointment)),
      body: branchId == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(alignment: AlignmentDirectional.centerStart, child: BranchPicker()),
                      if (!_reschedule) ...[
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: [ButtonSegment(value: false, label: Text(l10n.existingPatient)), ButtonSegment(value: true, label: Text(l10n.quickGuest))],
                          selected: {_guest},
                          onSelectionChanged: (v) => setState(() {
                            _guest = v.single;
                            _patient = null;
                            _visitType = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        if (_guest) ...[
                          TextField(controller: _name, decoration: InputDecoration(labelText: l10n.fullName)),
                          const SizedBox(height: 8),
                          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.mobileNumber)),
                        ] else if (_patient == null)
                          PatientPickerField(onPicked: (p) => setState(() => _patient = p))
                        else
                          Card(
                            child: ListTile(
                              title: Text(_patient!.name),
                              subtitle: Text([
                                l10n.fileNumber(_patient!.fileNumber),
                                if (_patient!.upcomingAppointmentId != null) l10n.hasUpcoming,
                              ].join(' · ')),
                              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _patient = null)),
                            ),
                          ),
                        if (ready) ...[
                          const SizedBox(height: 12),
                          VisitTypePicker(
                            isNew: _isNew,
                            consultationAllowed: _patient?.consultationAllowed ?? false,
                            value: _visitType,
                            consultationCount: _patient?.consultationsSinceExam,
                            maxConsultations: 2,
                            onChanged: (v) => setState(() => _visitType = v),
                          ),
                        ],
                      ],
                      if (ready && (visitType != null || _reschedule)) ...[
                        const SizedBox(height: 16),
                        PlacePicker(branchId: branchId, visitType: visitType ?? 'examination', staff: true, value: _place,
                            onChanged: (p) => setState(() => _place = p)),
                      ],
                      if (_place != null) ...[
                        if (!_reschedule) ...[
                          const SizedBox(height: 12),
                          TextField(controller: _notes, maxLength: 500, decoration: InputDecoration(labelText: l10n.staffNotes)),
                        ],
                        if (_place!.full) Text(l10n.overbookBody, style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving ? null : () => _submit(branchId),
                          child: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.confirmBookingButton),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ---- D33 / AS15 search ---------------------------------------------------------------------------

class AppointmentsSearchScreen extends ConsumerStatefulWidget {
  const AppointmentsSearchScreen({super.key, required this.basePath});

  final String basePath;

  @override
  ConsumerState<AppointmentsSearchScreen> createState() => _AppointmentsSearchScreenState();
}

class _AppointmentsSearchScreenState extends ConsumerState<AppointmentsSearchScreen> {
  final _q = TextEditingController();
  SearchFilter _filter = SearchFilter(from: DateUtils.dateOnly(DateTime.now()), to: DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7)));

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _update({DateTime? from, DateTime? to, List<String>? statuses, bool? guestsOnly, String? q}) => setState(() => _filter = SearchFilter(
        from: from ?? _filter.from, to: to ?? _filter.to, statuses: statuses ?? _filter.statuses,
        guestsOnly: guestsOnly ?? _filter.guestsOnly, q: q ?? _filter.q,
      ));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = ref.watch(searchProvider(_filter));
    final today = DateUtils.dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchBookings)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: l10n.searchPatient),
              onSubmitted: (v) => _update(q: v.trim()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              for (final (label, from, to) in [
                (l10n.today, today, today),
                (l10n.tomorrow, today.add(const Duration(days: 1)), today.add(const Duration(days: 1))),
                (l10n.next7Days, today, today.add(const Duration(days: 7))),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(label: Text(label), selected: _filter.from == from && _filter.to == to, onSelected: (_) => _update(from: from, to: to)),
                ),
              FilterChip(label: Text(l10n.guestsOnly), selected: _filter.guestsOnly, onSelected: (v) => _update(guestsOnly: v)),
            ]),
          ),
          if (result.value case final r?)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                for (final status in AppointmentStatus.all.where((s) => (r.statusCounts[s] ?? 0) > 0))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      label: Text('${context.appointmentStatus(status)} (${r.statusCounts[status]})'),
                      selected: _filter.statuses.contains(status),
                      onSelected: (on) => _update(statuses: on ? [..._filter.statuses, status] : _filter.statuses.where((s) => s != status).toList()),
                    ),
                  ),
              ]),
            ),
          Expanded(
            child: AsyncValueView(
              value: result,
              onRetry: () => ref.invalidate(searchProvider(_filter)),
              data: (r) => r.items.isEmpty
                  ? EmptyState(icon: Icons.search_off, message: l10n.noAppointments)
                  : ListView(children: [
                      for (final a in r.items)
                        ContentWidth(maxWidth: 900, child: AppointmentRow(appointment: a, staff: true, onTap: () => context.push('${widget.basePath}/appointments/${a.id}'))),
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}
