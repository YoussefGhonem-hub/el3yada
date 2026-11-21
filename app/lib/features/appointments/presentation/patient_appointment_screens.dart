import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/platform/contact_launcher.dart';
import '../../../core/theme/app_theme.dart' show Breakpoints;
import '../../../core/widgets/navigation/app_bottom_bar.dart' show AppBottomBar;
import '../../patient/application/patient_providers.dart';
import '../../patient/domain/patient_models.dart';
import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../application/appointment_providers.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment_models.dart';
import 'appointment_format.dart';
import 'place_picker.dart';
import 'walk_in_dialog.dart' show VisitTypePicker;

// ---- P16 My appointments -------------------------------------------------------------------------

class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // The shell's floating bar extends the body: lift the button above it.
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).width < Breakpoints.tablet ? AppBottomBar.barHeight : 0),
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/patient/appointments/book'),
            icon: const Icon(Icons.add),
            label: Text(l10n.book),
          ),
        ),
        body: Column(
          children: [
            TabBar(tabs: [Tab(text: l10n.tabUpcoming), Tab(text: l10n.tabPast), Tab(text: l10n.tabCancelled)]),
            const Expanded(child: TabBarView(children: [_MyList(tab: 'upcoming'), _MyList(tab: 'past'), _MyList(tab: 'cancelled')])),
          ],
        ),
      ),
    );
  }
}

class _MyList extends ConsumerWidget {
  const _MyList({required this.tab});

  final String tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myAppointmentsProvider(tab));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myAppointmentsProvider(tab).future),
      child: AsyncValueView(
        value: list,
        onRetry: () => ref.invalidate(myAppointmentsProvider(tab)),
        data: (items) => items.isEmpty
            ? ListView(children: [EmptyState(icon: Icons.event_note_outlined, message: context.l10n.noAppointments)])
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                itemCount: items.length,
                itemBuilder: (context, i) => ContentWidth(child: AppointmentRow(appointment: items[i], onTap: () => context.push('/patient/appointments/${items[i].id}'))),
              ),
      ),
    );
  }
}

class AppointmentRow extends StatelessWidget {
  const AppointmentRow({super.key, required this.appointment, required this.onTap, this.staff = false});

  final Appointment appointment;
  final VoidCallback onTap;
  final bool staff;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text(a.queueNumber != null ? '${a.queueNumber}' : a.time)),
      title: Text(staff ? a.displayName : context.doctorName(a.doctor)),
      subtitle: Text('${context.date(a.date)} · ${context.appointmentWhen(a)} · ${context.branchName(a.branch)} · ${context.visitTypeCode(a.visitType)}'),
      trailing: StatusChip(status: a.status),
    );
  }
}

// ---- P17 Appointment details ---------------------------------------------------------------------

class MyAppointmentDetailScreen extends ConsumerWidget {
  const MyAppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cancelBooking),
        content: TextField(controller: reason, maxLength: 200, decoration: InputDecoration(labelText: l10n.deletionReasonLabel)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.back)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.cancelBooking)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(appointmentsRepositoryProvider).cancel(appointmentId, reason: reason.text.trim().isEmpty ? null : reason.text.trim(), staff: false);
      ref.invalidate(myAppointmentProvider(appointmentId));
      ref.invalidate(myAppointmentsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.bookingCancelled)));
    } catch (error) {
      if (context.mounted) messenger.showSnackBar(SnackBar(content: Text(context.bookingError(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appointment = ref.watch(myAppointmentProvider(appointmentId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appointmentDetails)),
      body: AsyncValueView(
        value: appointment,
        onRetry: () => ref.invalidate(myAppointmentProvider(appointmentId)),
        data: (a) {
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [Expanded(child: Text(context.doctorName(a.doctor), style: theme.textTheme.titleLarge)), StatusChip(status: a.status)]),
                    const SizedBox(height: 8),
                    Text('${context.date(a.date)} · ${context.appointmentWhen(a)}', style: theme.textTheme.titleMedium),
                    Text(context.visitTypeCode(a.visitType)),
                    if (a.isQueue && a.nowServing != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: theme.colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l10n.nowServingYourNumber(a.nowServing!, a.queueNumber ?? 0),
                              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                        ),
                      ),
                    ],
                    if (a.estimatedTime != null) Text(l10n.estimatedTime(context.clock(a.estimatedTime!))),
                    if (a.status == AppointmentStatus.pending) Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(l10n.waitingForClinic, style: TextStyle(color: theme.colorScheme.tertiary)),
                    ),
                    const SizedBox(height: 16),
                    SectionCard(
                      title: context.branchName(a.branch),
                      icon: Icons.place_outlined,
                      child: Wrap(spacing: 8, children: [
                        for (final p in a.branchPhones.take(2))
                          TextButton.icon(onPressed: () => ContactLauncher.call(p.number), icon: const Icon(Icons.call_outlined),
                              label: Text(context.localPhone(p.number), textDirection: TextDirection.ltr)),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (a.isUpcoming && a.canChange)
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        FilledButton.tonalIcon(
                          onPressed: () => context.push('/patient/appointments/book?reschedule=${a.id}&doctor=${a.doctor.id}'),
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: Text(l10n.reschedule),
                        ),
                        OutlinedButton.icon(onPressed: () => _cancel(context, ref), icon: const Icon(Icons.event_busy), label: Text(l10n.cancelBooking)),
                      ])
                    else if (a.isUpcoming)
                      // BR-AP5: past the free-cancel limit, the buttons become "Call the clinic".
                      FilledButton.icon(
                        onPressed: a.branchPhones.isEmpty ? null : () => ContactLauncher.call(a.branchPhones.first.number),
                        icon: const Icon(Icons.call),
                        label: Text(l10n.callClinic),
                      ),
                    if (a.status == AppointmentStatus.completed && a.sessionId != null)
                      TextButton(onPressed: () => context.push('/patient/visits/${a.sessionId}'), child: Text(l10n.openVisit)),
                    if (a.history.isNotEmpty) ...[
                      const Divider(height: 32),
                      Text(l10n.history, style: theme.textTheme.titleSmall),
                      for (final h in a.history)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history, size: 18),
                          title: Text(_historyLabel(context, h)),
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
}

String _historyLabel(BuildContext context, AppointmentHistoryItem h) {
  final l10n = context.l10n;
  final who = switch (h.byRole) { 'patient' => l10n.byYou, 'system' => l10n.bySystem, _ => l10n.byClinic };
  final what = switch (h.action) {
    'created' => l10n.historyCreated,
    'rescheduled' => l10n.historyRescheduled,
    'cancelled' || 'cancelledRestOfDay' => l10n.apStatusCancelled,
    'confirmed' => l10n.apStatusConfirmed,
    'rejected' => l10n.apStatusRejected,
    'checkedIn' || 'walkIn' => l10n.apStatusCheckedIn,
    'noShow' => l10n.apStatusNoShow,
    'expired' => l10n.historyExpired,
    'completed' => l10n.apStatusCompleted,
    _ => h.action,
  };
  return '$what — $who';
}

// ---- P15 Book (and reschedule) --------------------------------------------------------------------

class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({super.key, this.rescheduleId, this.doctorId});

  final String? rescheduleId;
  final String? doctorId;

  @override
  ConsumerState<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  String? _doctorId;
  String? _branchId;
  String? _visitType;
  PlaceChoice? _place;
  final _reason = TextEditingController();
  bool _saving = false;
  Appointment? _result;

  bool get _reschedule => widget.rescheduleId != null;

  @override
  void initState() {
    super.initState();
    _doctorId = widget.doctorId;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit(BookingOptions options) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(appointmentsRepositoryProvider);
    try {
      final result = _reschedule
          ? await repository.reschedule(widget.rescheduleId!, branchId: _branchId!, date: _place!.date, time: _place!.time, staff: false)
          : await repository.book(BookingRequest(
              branchId: _branchId!, visitType: options.isNewPatient ? 'examination' : _visitType!, date: _place!.date, time: _place!.time,
              reason: _reason.text.trim().isEmpty ? null : _reason.text.trim()), staff: false);
      ref.invalidate(myAppointmentsProvider);
      if (_reschedule) ref.invalidate(myAppointmentProvider(widget.rescheduleId!));
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      final api = ApiError.from(error);
      messenger.showSnackBar(SnackBar(content: Text(context.bookingError(error))));
      if (api.code == 'SLOT_TAKEN' || api.code == 'PERIOD_FULL') {
        // The place went while choosing: show fresh availability (case 1).
        ref.invalidate(availabilityProvider);
        setState(() => _place = null);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final result = _result;
    if (result != null) return _Result(appointment: result, reschedule: _reschedule);

    final doctors = ref.watch(myDoctorsProvider).value ?? const <MyDoctor>[];
    if (_doctorId == null && doctors.length == 1) _doctorId = doctors.single.doctor.id;

    return Scaffold(
      appBar: AppBar(title: Text(_reschedule ? l10n.reschedule : l10n.bookAppointment)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (doctors.length > 1 && !_reschedule) ...[
                  _StepTitle(number: 1, text: l10n.chooseDoctor),
                  Wrap(spacing: 8, children: [
                    for (final d in doctors)
                      ChoiceChip(
                        label: Text(context.doctorName(d.doctor)),
                        selected: _doctorId == d.doctor.id,
                        onSelected: (_) => setState(() {
                          _doctorId = d.doctor.id;
                          _branchId = null;
                          _place = null;
                        }),
                      ),
                  ]),
                  const SizedBox(height: 16),
                ],
                if (_doctorId != null) _Options(
                  doctorId: _doctorId!,
                  builder: (options) => _steps(context, options),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _steps(BuildContext context, BookingOptions options) {
    final l10n = context.l10n;
    if (!options.canBook) {
      // BR-AP17 / BR-AP8: show the branch phones instead.
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(context.bookingError(options.unavailableReason ?? 'BOOKING_UNAVAILABLE')),
        for (final b in options.branches)
          for (final p in b.phones)
            ListTile(leading: const Icon(Icons.call), title: Text(b.displayName(arabic: context.isArabic)),
                subtitle: Text(context.localPhone(p.number), textDirection: TextDirection.ltr), onTap: () => ContactLauncher.call(p.number)),
      ]);
    }
    if (!_reschedule && options.upcomingAppointmentId != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l10n.errUpcomingLimit),
        TextButton(onPressed: () => context.push('/patient/appointments/${options.upcomingAppointmentId}'), child: Text(l10n.openBooking)),
      ]);
    }

    final branch = options.branches.where((b) => b.id == _branchId).firstOrNull;
    final visitType = options.isNewPatient ? 'examination' : _visitType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle(number: 2, text: l10n.chooseBranch),
        for (final b in options.branches)
          Card(
            color: b.id == _branchId ? Theme.of(context).colorScheme.primaryContainer : null,
            child: ListTile(
              enabled: b.canBook,
              title: Text(b.displayName(arabic: context.isArabic)),
              subtitle: Text(b.canBook
                  ? [?b.area, '${l10n.visitTypeExamination}: ${context.price(b.prices.examinationPiasters)}'].join(' · ')
                  : (b.closedMessage ?? l10n.errBookingUnavailable)),
              onTap: () => setState(() {
                _branchId = b.id;
                _place = null;
              }),
            ),
          ),
        if (branch != null && !_reschedule) ...[
          const SizedBox(height: 16),
          _StepTitle(number: 3, text: l10n.visitType),
          VisitTypePicker(
            isNew: options.isNewPatient,
            consultationAllowed: options.consultationAllowed,
            value: _visitType,
            examPrice: branch.prices.examinationPiasters,
            consultationPrice: branch.prices.consultationPiasters,
            consultationCount: options.consultationsSinceExam,
            maxConsultations: options.maxConsecutiveConsultations,
            onChanged: (v) => setState(() {
              _visitType = v;
              _place = null;
            }),
          ),
        ],
        if (branch != null && (visitType != null || _reschedule)) ...[
          const SizedBox(height: 16),
          _StepTitle(number: 4, text: l10n.chooseDateAndTime),
          PlacePicker(branchId: branch.id, visitType: visitType ?? 'examination', staff: false, value: _place,
              onChanged: (p) => setState(() => _place = p)),
        ],
        if (_place != null) ...[
          const SizedBox(height: 16),
          if (!_reschedule)
            TextField(controller: _reason, maxLength: 200, decoration: InputDecoration(labelText: l10n.bookingReasonOptional)),
          Text(l10n.cancelPolicy((branch!.freeCancelMinutes / 60).round()), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : () => _submit(options),
            child: _saving ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.confirmBookingButton),
          ),
        ],
      ],
    );
  }
}

class _Options extends ConsumerWidget {
  const _Options({required this.doctorId, required this.builder});

  final String doctorId;
  final Widget Function(BookingOptions options) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(bookingOptionsProvider(doctorId));
    return AsyncValueView(value: options, onRetry: () => ref.invalidate(bookingOptionsProvider(doctorId)), data: builder);
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          CircleAvatar(radius: 12, child: Text('$number', style: Theme.of(context).textTheme.labelSmall)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
        ]),
      );
}

class _Result extends StatelessWidget {
  const _Result({required this.appointment, required this.reschedule});

  final Appointment appointment;
  final bool reschedule;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pending = appointment.status == AppointmentStatus.pending;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(pending ? Icons.hourglass_top : Icons.check_circle_outline, size: 64, color: pending ? theme.colorScheme.tertiary : theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(pending ? l10n.waitingForClinic : (reschedule ? l10n.bookingMoved : l10n.bookingConfirmed),
                style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${context.date(appointment.date)} · ${context.appointmentWhen(appointment)}', style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton(onPressed: () => context.pushReplacement('/patient/appointments/${appointment.id}'), child: Text(l10n.openBooking)),
          ]),
        ),
      ),
    );
  }
}
