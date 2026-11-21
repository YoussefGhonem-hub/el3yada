import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../patient/presentation/patient_format.dart';
import '../domain/appointment_models.dart';

extension AppointmentFormat on BuildContext {
  String appointmentStatus(String status) => switch (status) {
        AppointmentStatus.pending => l10n.apStatusPending,
        AppointmentStatus.confirmed => l10n.apStatusConfirmed,
        AppointmentStatus.checkedIn => l10n.apStatusCheckedIn,
        AppointmentStatus.withDoctor => l10n.apStatusWithDoctor,
        AppointmentStatus.completed => l10n.apStatusCompleted,
        AppointmentStatus.cancelled => l10n.apStatusCancelled,
        AppointmentStatus.noShow => l10n.apStatusNoShow,
        AppointmentStatus.rejected => l10n.apStatusRejected,
        _ => status,
      };

  String boardStage(String stage) => switch (stage) {
        BoardStage.expected => l10n.stageExpected,
        BoardStage.waiting => l10n.stageWaiting,
        BoardStage.withDoctor => l10n.stageWithDoctor,
        BoardStage.done => l10n.stageDone,
        _ => l10n.stageMissed,
      };

  String visitTypeCode(String code) => code == 'consultation' ? l10n.visitTypeConsultation : l10n.visitTypeExamination;

  /// Timed: "18:15". Queue: the period, "Evening period from 18:00", with the number once checked in
  /// ("No. 7 · Evening period from 18:00"). Before check-in there is no number (BR-AP3).
  String appointmentWhen(Appointment a) {
    if (!a.isQueue) return clock(a.time);
    final period = queuePeriod(a.time);
    return a.queueNumber != null ? '${l10n.queueNumber(a.queueNumber!)} · $period' : period;
  }

  /// «الفترة الصباحية من 10:00» before 15:00, «الفترة المسائية من 18:00» after (as the API's texts).
  String queuePeriod(String start) {
    final hour = int.tryParse(start.split(':').first) ?? 0;
    return hour < 15 ? l10n.periodMorningFrom(clock(start)) : l10n.periodEveningFrom(clock(start));
  }

  /// The queue line under a booking (P1, P16): before check-in «سجّل حضورك في الاستقبال عند وصولك»;
  /// from check-in, the number, how many are ahead and the estimated wait (BR-AP16). Null otherwise.
  String? queueLine(Appointment a) {
    if (a.awaitsCheckIn) return l10n.queueCheckInOnArrival;
    if (a.inLine) {
      return [
        l10n.queueNumber(a.queueNumber!),
        if (a.ahead != null) l10n.queuePatientsAhead(a.ahead!),
        if (a.estimatedWaitMinutes != null && a.estimatedWaitMinutes! > 0) l10n.queueWaitAbout(a.estimatedWaitMinutes!),
      ].join(' · ');
    }
    if (a.isQueue && a.status == AppointmentStatus.withDoctor) return l10n.queueWithDoctorNow;
    return null;
  }

  /// The 6.12.6 messages for booking errors, then the general ones.
  String bookingError(Object error) => switch (ApiError.from(error).code) {
        'SLOT_TAKEN' => l10n.errSlotTaken,
        'PERIOD_FULL' => l10n.errPeriodFull,
        'OUTSIDE_HOURS' => l10n.errOutsideHours,
        'BRANCH_CLOSED' => l10n.errBranchClosed,
        'TOO_FAR_AHEAD' => l10n.errTooFarAhead,
        'TOO_SOON' => l10n.errTooSoon,
        'SAME_DAY_OFF' => l10n.errSameDayOff,
        'UPCOMING_LIMIT' => l10n.errUpcomingLimit,
        'SELF_BOOKING_BLOCKED' => l10n.errSelfBookingBlocked,
        'CONSULTATION_REQUIRES_EXAM' => l10n.errConsultationRequiresExam,
        'CANCEL_WINDOW_PASSED' => l10n.errCancelWindowPassed,
        'MAX_RESCHEDULES' => l10n.errMaxReschedules,
        'BOOKING_UNAVAILABLE' || 'DOCTOR_SUSPENDED' => l10n.errBookingUnavailable,
        'ALREADY_HANDLED' => l10n.errAlreadyHandled,
        'INVALID_TRANSITION' => l10n.errAlreadyHandled,
        'GUEST_NEEDS_ACCOUNT' => l10n.errGuestNeedsAccount,
        _ => l10n.apiErrorMessage(error),
      };

  Color statusColor(String status) {
    final scheme = Theme.of(this).colorScheme;
    return switch (status) {
      AppointmentStatus.pending => scheme.tertiary,
      AppointmentStatus.confirmed => scheme.primary,
      AppointmentStatus.checkedIn || AppointmentStatus.withDoctor => scheme.secondary,
      AppointmentStatus.completed => scheme.outline,
      _ => scheme.error,
    };
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(999)),
      child: Text(context.appointmentStatus(status), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
    );
  }
}
