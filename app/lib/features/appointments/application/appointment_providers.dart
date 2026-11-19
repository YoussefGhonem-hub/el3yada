import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/settings/app_settings.dart';
import '../data/appointments_repository.dart';
import '../domain/appointment_models.dart';

// ---- Staff: branches and the current branch (BR-BR3) ------------------------------------------

final staffBranchesProvider = FutureProvider.autoDispose<List<StaffBranch>>(
  (ref) => ref.watch(appointmentsRepositoryProvider).branches(),
);

/// The branch new bookings, walk-ins and today's board use. Remembered on the device.
final currentBranchProvider = NotifierProvider<CurrentBranchController, String?>(CurrentBranchController.new);

class CurrentBranchController extends Notifier<String?> {
  static const _key = 'staff.currentBranch';

  @override
  String? build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    // Fall back to the default branch once the list arrives.
    ref.listen(staffBranchesProvider, (previous, next) {
      final branches = next.value;
      if (branches == null || branches.isEmpty) return;
      if (state == null || !branches.any((b) => b.id == state)) {
        select((branches.where((b) => b.isDefault).firstOrNull ?? branches.first).id);
      }
    }, fireImmediately: true);
    return saved;
  }

  void select(String id) {
    state = id;
    ref.read(sharedPreferencesProvider).setString(_key, id);
  }
}

// ---- Live board (D34, AS1, AS16) --------------------------------------------------------------

class BoardState {
  const BoardState({required this.snapshot, this.offline = false});

  final BoardSnapshot snapshot;

  /// BR-LB5: the last refresh failed; the data may be out of date and actions are off.
  final bool offline;
}

/// The board for one branch, today. Refreshes on every `boardChanged` event for the branch
/// (BR-LB2) and every 15 seconds while the live connection is down (spec 9.6 fallback).
final boardProvider = AsyncNotifierProvider.autoDispose.family<BoardController, BoardState, String>(BoardController.new);

class BoardController extends AsyncNotifier<BoardState> {
  BoardController(this.branchId);

  final String branchId;
  Timer? _poll;

  AppointmentsRepository get _repository => ref.read(appointmentsRepositoryProvider);

  @override
  Future<BoardState> build() async {
    final realtime = ref.watch(realtimeServiceProvider);
    unawaited(realtime.joinBoard(branchId));
    final sub = realtime.events.listen((event) {
      if (event.name == RealtimeEvents.boardChanged && event.data['branchId'] == branchId) refresh();
    });
    void schedulePoll() {
      _poll?.cancel();
      if (realtime.status.value != RealtimeStatus.connected) {
        _poll = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
      }
    }

    realtime.status.addListener(schedulePoll);
    schedulePoll();
    ref.onDispose(() {
      sub.cancel();
      _poll?.cancel();
      realtime.status.removeListener(schedulePoll);
      unawaited(realtime.leaveBoard(branchId));
    });
    return BoardState(snapshot: await ref.watch(appointmentsRepositoryProvider).board(branchId));
  }

  Future<void> refresh() async {
    try {
      final snapshot = await _repository.board(branchId);
      state = AsyncData(BoardState(snapshot: snapshot));
    } catch (error) {
      final current = state.value;
      if (current != null && ApiError.from(error).isNetwork) {
        state = AsyncData(BoardState(snapshot: current.snapshot, offline: true));
      }
    }
  }

  /// Runs a card action, then refreshes. If someone acted first (BR-LB4) the board refreshes
  /// and the error is rethrown so the screen can say who did it.
  Future<void> act(String appointmentId, String action, {String? reason}) async {
    try {
      await _repository.act(appointmentId, action, reason: reason);
    } finally {
      await refresh();
    }
  }

  Future<void> walkIn({String? patientId, String? guestName, String? guestPhone, required String visitType}) async {
    await _repository.walkIn(branchId: branchId, patientId: patientId, guestName: guestName, guestPhone: guestPhone, visitType: visitType);
    await refresh();
  }

  Future<int> cancelRestOfDay(String? reason) async {
    final n = await _repository.cancelRestOfDay(branchId, reason: reason);
    await refresh();
    return n;
  }

  Future<int> sendDelay(int minutes) => _repository.sendDelay(branchId, minutes);
}

final boardSummaryProvider = FutureProvider.autoDispose.family<BoardPatientSummary, String>(
  (ref, id) => ref.watch(appointmentsRepositoryProvider).boardSummary(id),
);

// ---- Staff reads -------------------------------------------------------------------------------

final staffAppointmentProvider = FutureProvider.autoDispose.family<Appointment, String>(
  (ref, id) => ref.watch(appointmentsRepositoryProvider).appointment(id),
);

final searchProvider = FutureProvider.autoDispose.family<SearchResult, SearchFilter>(
  (ref, filter) => ref.watch(appointmentsRepositoryProvider).search(filter),
);

class AvailabilityKey {
  const AvailabilityKey({required this.branchId, required this.visitType, required this.from, this.to, required this.staff});

  final String branchId;
  final String visitType;
  final DateTime from;
  final DateTime? to;
  final bool staff;

  @override
  bool operator ==(Object other) =>
      other is AvailabilityKey && other.branchId == branchId && other.visitType == visitType && other.from == from && other.to == to && other.staff == staff;

  @override
  int get hashCode => Object.hash(branchId, visitType, from, to, staff);
}

/// Availability is computed on the server only (BR-AP1).
final availabilityProvider = FutureProvider.autoDispose.family<Availability, AvailabilityKey>(
  (ref, k) => ref.watch(appointmentsRepositoryProvider).availability(branchId: k.branchId, visitType: k.visitType, from: k.from, to: k.to, staff: k.staff),
);

final scheduleProvider = FutureProvider.autoDispose.family<BranchScheduleData, String>(
  (ref, branchId) => ref.watch(appointmentsRepositoryProvider).schedule(branchId),
);

// ---- Patient reads -----------------------------------------------------------------------------

final myAppointmentsProvider = FutureProvider.autoDispose.family<List<Appointment>, String>((ref, tab) {
  // Booking changes from the clinic (confirm, reschedule, cancel) arrive as notifications.
  final sub = ref.watch(realtimeServiceProvider).events.where((e) => e.name == RealtimeEvents.notification).listen((e) {
    if ((e.data['type'] as String? ?? '').startsWith('booking')) ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);
  return ref.watch(appointmentsRepositoryProvider).myAppointments(tab);
});

final myAppointmentProvider = FutureProvider.autoDispose.family<Appointment, String>(
  (ref, id) => ref.watch(appointmentsRepositoryProvider).myAppointment(id),
);

final bookingOptionsProvider = FutureProvider.autoDispose.family<BookingOptions, String>(
  (ref, doctorId) => ref.watch(appointmentsRepositoryProvider).bookingOptions(doctorId),
);

/// Staff D32 step 1: existing patients by name, phone or file number.
final patientLookupProvider = FutureProvider.autoDispose.family<List<PatientLookup>, String>(
  (ref, q) => ref.watch(appointmentsRepositoryProvider).lookupPatients(q),
);
