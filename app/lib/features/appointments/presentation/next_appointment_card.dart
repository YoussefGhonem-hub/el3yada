import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../patient/presentation/patient_format.dart';
import '../../patient/presentation/widgets/patient_widgets.dart';
import '../application/appointment_providers.dart';
import '../domain/appointment_models.dart';
import 'appointment_format.dart';
import 'patient_appointment_screens.dart' show QueueStatusCard;

/// P1's next-appointment card: date, period or time, branch and status → P17, with **Book** → P15.
/// Queue mode: «سجّل حضورك في الاستقبال عند وصولك» until check-in; from check-in on the day, the number, how
/// many are ahead, the estimated wait and [S] "now serving" (BR-AP3, BR-AP16).
class NextAppointmentCard extends ConsumerWidget {
  const NextAppointmentCard({super.key, this.doctorId});

  /// The home's doctor selector; null for all doctors.
  final String? doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final upcoming = ref.watch(myAppointmentsProvider('upcoming'));
    // The rest of the home stays useful without it: nothing while loading or when it fails.
    final list = upcoming.value;
    if (list == null) return const SizedBox.shrink();
    final next = list.where((a) => doctorId == null || a.doctor.id == doctorId).firstOrNull;

    return SectionCard(
      title: l10n.homeNextAppointment,
      icon: Icons.event_outlined,
      trailing: TextButton(
        onPressed: () => context.push('/patient/appointments/book${doctorId == null ? '' : '?doctor=$doctorId'}'),
        child: Text(l10n.book),
      ),
      onTap: next == null ? null : () => context.push('/patient/appointments/${next.id}'),
      child: next == null
          ? Text(l10n.homeNoUpcomingAppointment, style: theme.textTheme.bodyMedium)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('${context.date(next.date)} · ${context.appointmentWhen(next)}', style: theme.textTheme.bodyLarge),
                  ),
                  StatusChip(status: next.status),
                ]),
                const SizedBox(height: 4),
                Text('${context.doctorName(next.doctor)} · ${context.branchName(next.branch)}', style: theme.textTheme.bodyMedium),
                if (next.isQueue && (next.awaitsCheckIn || next.inLine || next.status == AppointmentStatus.withDoctor)) ...[
                  const SizedBox(height: 12),
                  QueueStatusCard(appointment: next),
                ],
              ],
            ),
    );
  }
}
