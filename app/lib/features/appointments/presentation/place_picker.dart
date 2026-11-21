import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../application/appointment_providers.dart';
import '../domain/appointment_models.dart';
import 'appointment_format.dart';

/// The chosen place: a date and a period start (queue) or slot start (timed).
class PlaceChoice {
  const PlaceChoice(this.date, this.time, {this.full = false});

  final DateTime date;
  final String time;

  /// Staff picked a full period or a taken slot: the booking will need the overbooking warning.
  final bool full;

  @override
  bool operator ==(Object other) => other is PlaceChoice && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(date, time);
}

/// Date strip (closed and full days greyed out) and the periods or slots of the chosen day.
/// Availability comes from the server only (BR-AP1).
class PlacePicker extends ConsumerStatefulWidget {
  const PlacePicker({super.key, required this.branchId, required this.visitType, required this.staff, required this.value, required this.onChanged, this.days = 14});

  final String branchId;
  final String visitType;
  final bool staff;
  final PlaceChoice? value;
  final ValueChanged<PlaceChoice> onChanged;
  final int days;

  @override
  ConsumerState<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends ConsumerState<PlacePicker> {
  late final DateTime _from = () {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }();
  DateTime? _day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = AvailabilityKey(
      branchId: widget.branchId, visitType: widget.visitType, from: _from, to: _from.add(Duration(days: widget.days - 1)), staff: widget.staff,
    );
    final availability = ref.watch(availabilityProvider(key));

    return AsyncValueView(
      value: availability,
      onRetry: () => ref.invalidate(availabilityProvider(key)),
      data: (a) {
        final selected = _day ?? a.days.where((d) => !d.closed).firstOrNull?.date;
        final day = a.days.where((d) => d.date == selected).firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final d in a.days)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(context.weekday(d.date.weekday)),
                          Text('${d.date.day}/${d.date.month}'),
                        ]),
                        selected: d.date == selected,
                        onSelected: d.closed && !widget.staff ? null : (_) => setState(() => _day = d.date),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (day == null)
              EmptyState(icon: Icons.event_busy, message: l10n.noOpenDays)
            else if (day.reason != null)
              EmptyState(icon: Icons.event_busy, message: context.bookingError(day.reason!))
            else if (a.mode == 'queue') ...[
              // P15: a place on the period's list; the turn is given at the clinic, in order of arrival (BR-AP3).
              if (!widget.staff)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(Icons.groups_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.queueByArrival, style: Theme.of(context).textTheme.bodyMedium)),
                  ]),
                ),
              for (final p in day.periods)
                _PeriodTile(
                  period: p,
                  selected: widget.value == PlaceChoice(day.date, p.start),
                  staff: widget.staff,
                  onTap: () => widget.onChanged(PlaceChoice(day.date, p.start, full: !p.available)),
                ),
            ]
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in day.slots.where((s) => s.available || (widget.staff && s.unavailable == 'SLOT_TAKEN')))
                    ChoiceChip(
                      label: Text(context.clock(s.start)),
                      selected: widget.value == PlaceChoice(day.date, s.start),
                      avatar: s.available ? null : const Icon(Icons.warning_amber, size: 16),
                      onSelected: (_) => widget.onChanged(PlaceChoice(day.date, s.start, full: !s.available)),
                    ),
                  if (!day.slots.any((s) => s.available)) Text(l10n.errPeriodFull),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({required this.period, required this.selected, required this.staff, required this.onTap});

  final PeriodSlot period;
  final bool selected;
  final bool staff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Staff can pick a full period (overbooking after a warning); patients can't.
    final enabled = period.available || (staff && period.unavailable == 'PERIOD_FULL');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        title: Text([?period.label, l10n.timeRange(context.clock(period.start), context.clock(period.end))].join(' · ')),
        // No number and no estimate before arrival: the order is the order of arrival (BR-AP3).
        subtitle: Text(period.unavailable != null ? context.bookingError(period.unavailable!) : l10n.placesLeft(period.remaining)),
      ),
    );
  }
}
