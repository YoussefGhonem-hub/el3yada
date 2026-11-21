import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../patient/domain/patient_models.dart';
import '../domain/appointment_models.dart';

/// What a booking request needs (`createAppointment`).
class BookingRequest {
  const BookingRequest({
    required this.branchId,
    this.patientId,
    this.guestName,
    this.guestPhone,
    required this.visitType,
    required this.date,
    required this.time,
    this.reason,
    this.staffNotes,
    this.overbook = false,
    this.confirmWarnings = false,
  });

  final String branchId;
  final String? patientId;
  final String? guestName;
  final String? guestPhone;
  final String visitType;
  final DateTime date;
  final String time;
  final String? reason;
  final String? staffNotes;
  final bool overbook;
  final bool confirmWarnings;

  BookingRequest withWarnings({bool? overbook, bool? confirmWarnings}) => BookingRequest(
        branchId: branchId, patientId: patientId, guestName: guestName, guestPhone: guestPhone, visitType: visitType,
        date: date, time: time, reason: reason, staffNotes: staffNotes,
        overbook: overbook ?? this.overbook, confirmWarnings: confirmWarnings ?? this.confirmWarnings,
      );

  Json toJson() => {
        'branchId': branchId,
        'patientId': patientId,
        'guest': guestName == null ? null : {'name': guestName, 'phone': guestPhone},
        'visitType': visitType,
        'date': dayKey(date),
        'time': time,
        'reason': reason,
        'staffNotes': staffNotes,
        'overbook': overbook,
        'confirmWarnings': confirmWarnings,
      };
}

class SearchFilter {
  const SearchFilter({
    this.from,
    this.to,
    this.statuses = const [],
    this.q,
    this.guestsOnly = false,
    this.branchId,
    this.patientId,
    this.newestFirst = false,
  });

  final DateTime? from;
  final DateTime? to;
  final List<String> statuses;
  final String? q;
  final bool guestsOnly;
  final String? branchId;

  /// One patient's bookings (D6 Appointments tab).
  final String? patientId;

  /// Newest first (`sort=dateDesc`); oldest first otherwise.
  final bool newestFirst;

  Map<String, dynamic> toQuery() => {
        if (from != null) 'from': dayKey(from!),
        if (to != null) 'to': dayKey(to!),
        if (statuses.isNotEmpty) 'statuses': statuses,
        if (q != null && q!.isNotEmpty) 'q': q,
        if (guestsOnly) 'guestsOnly': true,
        if (branchId != null) 'branchIds': [branchId],
        'patientId': ?patientId,
        if (newestFirst) 'sort': 'dateDesc',
        'pageSize': 100,
      };

  @override
  bool operator ==(Object other) =>
      other is SearchFilter && other.from == from && other.to == to && other.q == q && other.guestsOnly == guestsOnly &&
      other.branchId == branchId && other.statuses.join(',') == statuses.join(',') && other.patientId == patientId &&
      other.newestFirst == newestFirst;

  @override
  int get hashCode => Object.hash(from, to, q, guestsOnly, branchId, statuses.join(','), patientId, newestFirst);
}

/// Bookings for both sides: `/api/patient/...` (P15–P17) and `/api/staff/...` (D29–D34, AS13–AS17).
abstract interface class AppointmentsRepository {
  // Patient
  Future<BookingOptions> bookingOptions(String doctorId);
  Future<List<Appointment>> myAppointments(String tab);
  Future<Appointment> myAppointment(String id);

  // Both (the implementation picks the side)
  Future<Availability> availability({required String branchId, required String visitType, required DateTime from, DateTime? to, required bool staff});
  Future<Appointment> book(BookingRequest request, {required bool staff});
  Future<Appointment> reschedule(String id, {required String branchId, required DateTime date, required String time, bool overbook, required bool staff});
  Future<Appointment> cancel(String id, {String? reason, required bool staff});

  // Staff
  Future<List<StaffBranch>> branches();
  Future<Appointment> appointment(String id);
  Future<SearchResult> search(SearchFilter filter);
  Future<List<PatientLookup>> lookupPatients(String query);
  Future<BoardSnapshot> board(String branchId, {DateTime? date});
  Future<BoardPatientSummary> boardSummary(String appointmentId);

  /// `action`: check-in, call-in, send-back, no-show, undo-no-show, left-without-seen, confirm, reject, priority.
  Future<Appointment> act(String id, String action, {String? reason});
  Future<Appointment> walkIn({required String branchId, String? patientId, String? guestName, String? guestPhone, required String visitType});
  Future<int> cancelRestOfDay(String branchId, {String? reason});
  Future<int> sendDelay(String branchId, int minutes);
  Future<BranchScheduleData> schedule(String branchId);

  /// Returns the affected bookings. With [dryRun] nothing changes.
  Future<({bool applied, List<ScheduleConflict> conflicts})> saveSchedule(BranchScheduleData data, {required bool dryRun, Map<String, String> decisions});
}

class ApiAppointmentsRepository implements AppointmentsRepository {
  ApiAppointmentsRepository(this._dio);

  final Dio _dio;

  Future<T> _wrap<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiError.from(error);
    }
  }

  Future<Json> _get(String path, [Map<String, dynamic>? q]) async => (await _dio.get<Json>(path, queryParameters: q)).data!;
  Future<Json> _post(String path, [Object? body]) async => (await _dio.post<Json>(path, data: body ?? const {})).data!;

  String _side(bool staff) => staff ? '/api/staff' : '/api/patient';

  @override
  Future<BookingOptions> bookingOptions(String doctorId) =>
      _wrap(() async => BookingOptions.fromJson(await _get('/api/patient/doctors/$doctorId/booking-options')));

  @override
  Future<List<Appointment>> myAppointments(String tab) => _wrap(() async {
        final r = await _dio.get<List<dynamic>>('/api/patient/appointments', queryParameters: {'tab': tab});
        return [for (final a in r.data!) Appointment.fromJson(a as Json)];
      });

  @override
  Future<Appointment> myAppointment(String id) => _wrap(() async => Appointment.fromJson(await _get('/api/patient/appointments/$id')));

  @override
  Future<Availability> availability({required String branchId, required String visitType, required DateTime from, DateTime? to, required bool staff}) =>
      _wrap(() async => Availability.fromJson(await _get('${_side(staff)}/availability', {
            'branchId': branchId, 'visitType': visitType, 'from': dayKey(from), if (to != null) 'to': dayKey(to),
          })));

  @override
  Future<Appointment> book(BookingRequest request, {required bool staff}) =>
      _wrap(() async => Appointment.fromJson(await _post('${_side(staff)}/appointments', request.toJson())));

  @override
  Future<Appointment> reschedule(String id, {required String branchId, required DateTime date, required String time, bool overbook = false, required bool staff}) =>
      _wrap(() async => Appointment.fromJson(await _post('${_side(staff)}/appointments/$id/reschedule',
          {'branchId': branchId, 'date': dayKey(date), 'time': time, 'overbook': overbook})));

  @override
  Future<Appointment> cancel(String id, {String? reason, required bool staff}) =>
      _wrap(() async => Appointment.fromJson(await _post('${_side(staff)}/appointments/$id/cancel', {'reason': reason})));

  @override
  Future<List<StaffBranch>> branches() => _wrap(() async {
        final r = await _dio.get<List<dynamic>>('/api/staff/branches');
        return [for (final b in r.data!) StaffBranch.fromJson(b as Json)];
      });

  @override
  Future<Appointment> appointment(String id) => _wrap(() async => Appointment.fromJson(await _get('/api/staff/appointments/$id')));

  @override
  Future<SearchResult> search(SearchFilter filter) => _wrap(() async => SearchResult.fromJson(await _get('/api/staff/appointments', filter.toQuery())));

  @override
  Future<List<PatientLookup>> lookupPatients(String query) => _wrap(() async {
        final r = await _dio.get<List<dynamic>>('/api/staff/patients/lookup', queryParameters: {'q': query});
        return [for (final p in r.data!) PatientLookup.fromJson(p as Json)];
      });

  @override
  Future<BoardSnapshot> board(String branchId, {DateTime? date}) =>
      _wrap(() async => BoardSnapshot.fromJson(await _get('/api/staff/board', {'branchId': branchId, if (date != null) 'date': dayKey(date)})));

  @override
  Future<BoardPatientSummary> boardSummary(String appointmentId) =>
      _wrap(() async => BoardPatientSummary.fromJson(await _get('/api/staff/board/$appointmentId/summary')));

  @override
  Future<Appointment> act(String id, String action, {String? reason}) =>
      _wrap(() async => Appointment.fromJson(await _post('/api/staff/appointments/$id/$action', {'reason': reason})));

  @override
  Future<Appointment> walkIn({required String branchId, String? patientId, String? guestName, String? guestPhone, required String visitType}) =>
      _wrap(() async => Appointment.fromJson(await _post('/api/staff/board/walk-in', {
            'branchId': branchId, 'patientId': patientId, 'visitType': visitType,
            'guest': guestName == null ? null : {'name': guestName, 'phone': guestPhone},
          })));

  @override
  Future<int> cancelRestOfDay(String branchId, {String? reason}) =>
      _wrap(() async => (await _post('/api/staff/board/cancel-rest-of-day', {'branchId': branchId, 'reason': reason}))['cancelled'] as int);

  @override
  Future<int> sendDelay(String branchId, int minutes) =>
      _wrap(() async => (await _post('/api/staff/board/delay', {'branchId': branchId, 'minutes': minutes}))['notified'] as int);

  @override
  Future<BranchScheduleData> schedule(String branchId) =>
      _wrap(() async => BranchScheduleData.fromJson(await _get('/api/staff/branches/$branchId/schedule')));

  @override
  Future<({bool applied, List<ScheduleConflict> conflicts})> saveSchedule(BranchScheduleData data,
          {required bool dryRun, Map<String, String> decisions = const {}}) =>
      _wrap(() async {
        try {
          final r = (await _dio.put<Json>('/api/staff/branches/${data.branchId}/schedule', data: {
            'weekly': [for (final p in data.weekly) p.toJson()],
            'dateOverrides': [for (final o in data.overrides) o.toJson()],
            'closures': [for (final c in data.closures) c.toJson()],
            'settings': data.settings.toJson(),
            'dryRun': dryRun,
            'decisions': [for (final e in decisions.entries) {'appointmentId': e.key, 'action': e.value}],
          }))
              .data!;
          return (applied: r['applied'] as bool, conflicts: [for (final c in r['conflicts'] as List) ScheduleConflict.fromJson(c as Json)]);
        } on DioException catch (error) {
          final data = error.response?.data;
          if (data is Map && data['code'] == 'SCHEDULE_CONFLICTS') {
            final list = (data['details'] as Map)['conflicts'] as List;
            return (applied: false, conflicts: [for (final c in list) ScheduleConflict.fromJson(Map<String, dynamic>.from(c as Map))]);
          }
          rethrow;
        }
      });
}

/// A small in-memory clinic for dev builds and widget tests: one doctor, one queue branch with a
/// morning and an evening period (capacity 5), a few bookings today.
class FakeAppointmentsRepository implements AppointmentsRepository {
  FakeAppointmentsRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    final today = DateTime(_now.year, _now.month, _now.day);
    _list = [
      _make('ap-1', 'محمد إبراهيم', 'pat-1', today, '17:00', 1, AppointmentStatus.confirmed),
      _make('ap-2', 'خالد يوسف', 'pat-2', today, '17:00', 2, AppointmentStatus.checkedIn),
      _make('ap-3', 'زائر جديد', null, today, '17:00', 3, AppointmentStatus.pending, guest: true),
    ];
  }

  final DateTime _now;
  late List<Appointment> _list;
  int _next = 10;

  static const _doctor = DoctorRef(id: 'doc-a', fullName: 'د. أحمد سامي', fullNameEn: 'Dr. Ahmed Samy', title: 'استشاري', titleEn: 'Consultant');
  static const _branch = BranchRef(id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch');
  static const _phones = [BranchPhone(number: '+201011111111', label: 'reception', isWhatsapp: true)];

  Appointment _make(String id, String name, String? patientId, DateTime date, String time, int? number, String status,
          {bool guest = false, String source = 'staff', bool canChange = true}) =>
      Appointment(
        id: id, doctor: _doctor, branch: _branch, patientId: patientId, displayName: name, phone: '+201000000002', isGuest: guest,
        visitType: 'examination', mode: 'queue', date: date, time: time,
        startUtc: DateTime(date.year, date.month, date.day, int.parse(time.substring(0, 2))).toUtc(),
        queueNumber: number, status: status, source: source, canChange: canChange, branchPhones: _phones,
        checkedInAt: status == AppointmentStatus.checkedIn ? _now : null,
      );

  Appointment _set(String id, Appointment Function(Appointment a) change) {
    final index = _list.indexWhere((a) => a.id == id);
    if (index < 0) throw const ApiError(ApiError.notFound, status: 404);
    _list[index] = change(_list[index]);
    return _list[index];
  }

  Appointment _withStatus(Appointment a, String status) => Appointment(
        id: a.id, doctor: a.doctor, branch: a.branch, patientId: a.patientId, displayName: a.displayName, phone: a.phone, isGuest: a.isGuest,
        visitType: a.visitType, mode: a.mode, date: a.date, time: a.time, startUtc: a.startUtc, queueNumber: a.queueNumber, status: status,
        source: a.source, canChange: status == AppointmentStatus.pending || status == AppointmentStatus.confirmed, branchPhones: a.branchPhones,
        checkedInAt: status == AppointmentStatus.checkedIn ? (a.checkedInAt ?? _now) : a.checkedInAt, reason: a.reason,
      );

  @override
  Future<BookingOptions> bookingOptions(String doctorId) async => BookingOptions(
        doctor: doctorId == 'doc-b'
            ? const DoctorRef(id: 'doc-b', fullName: 'د. منى حسن', fullNameEn: 'Dr. Mona Hassan', title: 'أخصائي', titleEn: 'Specialist')
            : _doctor,
        canBook: true, isNewPatient: false, consultationAllowed: true, consultationsSinceExam: 0, maxConsecutiveConsultations: 2,
        branches: const [
          BookingBranch(id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch', area: 'المعادي', status: 'active', mode: 'queue',
              selfBooking: true, freeCancelMinutes: 120, windowDays: 30,
              prices: VisitPrices(examinationPiasters: 35000, consultationPiasters: 15000), phones: _phones),
        ],
      );

  @override
  Future<List<Appointment>> myAppointments(String tab) async => switch (tab) {
        'cancelled' => _list.where((a) => a.status == AppointmentStatus.cancelled || a.status == AppointmentStatus.rejected).toList(),
        'past' => _list.where((a) => a.status == AppointmentStatus.completed || a.status == AppointmentStatus.noShow).toList(),
        _ => _list.where((a) => a.patientId == 'pat-1' && (a.isUpcoming || a.status == AppointmentStatus.checkedIn)).toList(),
      };

  @override
  Future<Appointment> myAppointment(String id) async => _list.firstWhere((a) => a.id == id, orElse: () => throw const ApiError(ApiError.notFound, status: 404));

  @override
  Future<Availability> availability({required String branchId, required String visitType, required DateTime from, DateTime? to, required bool staff}) async {
    final days = <DayAvailability>[];
    for (var d = from; !d.isAfter(to ?? from); d = d.add(const Duration(days: 1))) {
      int booked(String start) => _list.where((a) => a.date == DateTime(d.year, d.month, d.day) && a.time == start && a.status != AppointmentStatus.cancelled).length;
      final friday = d.weekday == DateTime.friday;
      days.add(DayAvailability(
        date: d,
        closed: friday,
        reason: friday ? 'OUTSIDE_HOURS' : null,
        periods: friday
            ? const []
            : [
                for (final (start, end, label) in [('10:00', '14:00', 'صباحي'), ('17:00', '22:00', 'مسائي')])
                  PeriodSlot(start: start, end: end, label: label, capacity: 5, booked: booked(start), remaining: 5 - booked(start),
                      estimatedTime: start, unavailable: booked(start) >= 5 ? 'PERIOD_FULL' : null),
              ],
      ));
    }
    return Availability(branchId: branchId, mode: 'queue', days: days);
  }

  @override
  Future<Appointment> book(BookingRequest r, {required bool staff}) async {
    if (!staff && _list.any((a) => a.patientId == 'pat-1' && a.isUpcoming && a.date.isAfter(_now))) {
      throw const ApiError('UPCOMING_LIMIT', status: 409);
    }
    final number = _list.where((a) => a.date == r.date && a.time == r.time).length + 1;
    final a = _make('ap-${_next++}', r.guestName ?? 'محمد إبراهيم', r.guestName == null ? (r.patientId ?? 'pat-1') : null, r.date, r.time, number,
        AppointmentStatus.confirmed, guest: r.guestName != null, source: staff ? 'staff' : 'patientApp');
    _list.add(a);
    return a;
  }

  @override
  Future<Appointment> reschedule(String id, {required String branchId, required DateTime date, required String time, bool overbook = false, required bool staff}) async =>
      _set(id, (a) => _make(a.id, a.displayName, a.patientId, date, time, a.queueNumber, a.status, guest: a.isGuest));

  @override
  Future<Appointment> cancel(String id, {String? reason, required bool staff}) async => _set(id, (a) => _withStatus(a, AppointmentStatus.cancelled));

  @override
  Future<List<StaffBranch>> branches() async =>
      const [StaffBranch(id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch', isDefault: true, status: 'active', mode: 'queue')];

  @override
  Future<Appointment> appointment(String id) => myAppointment(id);

  @override
  Future<SearchResult> search(SearchFilter filter) async {
    final items = _list.where((a) =>
        (filter.statuses.isEmpty || filter.statuses.contains(a.status)) &&
        (filter.q == null || filter.q!.isEmpty || a.displayName.contains(filter.q!)) &&
        (filter.patientId == null || a.patientId == filter.patientId) &&
        (!filter.guestsOnly || a.isGuest)).toList()
      ..sort((a, b) => filter.newestFirst ? b.startUtc.compareTo(a.startUtc) : a.startUtc.compareTo(b.startUtc));
    final counts = <String, int>{};
    for (final a in _list) {
      counts[a.status] = (counts[a.status] ?? 0) + 1;
    }
    return SearchResult(items: items, totalCount: items.length, statusCounts: counts);
  }

  @override
  Future<List<PatientLookup>> lookupPatients(String query) async => [
        const PatientLookup(patientId: 'pat-1', name: 'محمد إبراهيم', phone: '+201000000002', fileNumber: 1, sessionCount: 1,
            consultationAllowed: true, consultationsSinceExam: 0),
      ].where((p) => query.isEmpty || p.name.contains(query) || p.phone.contains(query)).toList();

  static String _stage(String status) => switch (status) {
        AppointmentStatus.pending || AppointmentStatus.confirmed => BoardStage.expected,
        AppointmentStatus.checkedIn => BoardStage.waiting,
        AppointmentStatus.withDoctor => BoardStage.withDoctor,
        AppointmentStatus.completed => BoardStage.done,
        _ => BoardStage.missed,
      };

  @override
  Future<BoardSnapshot> board(String branchId, {DateTime? date}) async {
    final day = date ?? DateTime(_now.year, _now.month, _now.day);
    final entries = [
      for (final a in _list.where((a) => a.date == day))
        BoardEntry(
          appointmentId: a.id, queueNumber: a.queueNumber, timeLocal: a.time, stage: _stage(a.status), displayName: a.displayName,
          visitType: a.visitType, source: a.source, isNewPatient: a.isGuest, guest: a.isGuest, pending: a.status == AppointmentStatus.pending,
          walkIn: a.source == 'walkIn', checkedInAt: a.checkedInAt, status: a.status, patientId: a.patientId, createdAt: _now,
        ),
    ];
    final serving = _list.where((a) => a.status == AppointmentStatus.withDoctor).map((a) => a.queueNumber).firstOrNull;
    return BoardSnapshot(branchId: branchId, date: day, mode: 'queue', nowServing: serving, entries: entries, updatedAt: _now,
        nextNumbers: [for (final e in entries.where((e) => e.stage == BoardStage.waiting)) e.queueNumber!]);
  }

  @override
  Future<BoardPatientSummary> boardSummary(String appointmentId) async {
    final a = await myAppointment(appointmentId);
    return BoardPatientSummary(displayName: a.displayName, isGuest: a.isGuest, phone: a.phone, age: 41, fileNumber: a.isGuest ? null : 1,
        examCount: 1, allergies: a.isGuest ? null : const ['البنسلين'], consultationAllowed: !a.isGuest);
  }

  @override
  Future<Appointment> act(String id, String action, {String? reason}) async {
    final a = await myAppointment(id);
    final next = switch (action) {
      'check-in' when a.isUpcoming => AppointmentStatus.checkedIn,
      'call-in' when a.status == AppointmentStatus.checkedIn => AppointmentStatus.withDoctor,
      'send-back' when a.status == AppointmentStatus.withDoctor => AppointmentStatus.checkedIn,
      'no-show' when a.status == AppointmentStatus.confirmed => AppointmentStatus.noShow,
      'undo-no-show' when a.status == AppointmentStatus.noShow => AppointmentStatus.checkedIn,
      'left-without-seen' => AppointmentStatus.cancelled,
      'confirm' when a.status == AppointmentStatus.pending => AppointmentStatus.confirmed,
      'reject' when a.status == AppointmentStatus.pending => AppointmentStatus.rejected,
      'priority' => a.status,
      _ => throw const ApiError('ALREADY_HANDLED', status: 409),
    };
    return _set(id, (a) => _withStatus(a, next));
  }

  @override
  Future<Appointment> walkIn({required String branchId, String? patientId, String? guestName, String? guestPhone, required String visitType}) async {
    final today = DateTime(_now.year, _now.month, _now.day);
    final number = _list.where((a) => a.date == today).length + 1;
    final a = _make('ap-${_next++}', guestName ?? 'محمد إبراهيم', guestName == null ? patientId : null, today, '17:00', number,
        AppointmentStatus.checkedIn, guest: guestName != null, source: 'walkIn');
    _list.add(a);
    return a;
  }

  @override
  Future<int> cancelRestOfDay(String branchId, {String? reason}) async {
    var n = 0;
    for (final a in [..._list]) {
      if (a.isUpcoming) {
        _set(a.id, (x) => _withStatus(x, AppointmentStatus.cancelled));
        n++;
      }
    }
    return n;
  }

  @override
  Future<int> sendDelay(String branchId, int minutes) async => _list.where((a) => a.isUpcoming).length;

  BranchScheduleData _schedule = const BranchScheduleData(branchId: 'br-a1', weekly: [
    WeeklyPeriod(weekday: 6, start: '10:00', end: '14:00', label: 'صباحي'),
    WeeklyPeriod(weekday: 6, start: '17:00', end: '22:00', label: 'مسائي', capacity: 30),
    WeeklyPeriod(weekday: 1, start: '17:00', end: '22:00', label: 'مسائي'),
  ]);

  @override
  Future<BranchScheduleData> schedule(String branchId) async => _schedule;

  @override
  Future<({bool applied, List<ScheduleConflict> conflicts})> saveSchedule(BranchScheduleData data,
      {required bool dryRun, Map<String, String> decisions = const {}}) async {
    if (!dryRun) _schedule = data;
    return (applied: !dryRun, conflicts: const <ScheduleConflict>[]);
  }
}

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  if (Env.useFakeAuth) return FakeAppointmentsRepository();
  return ApiAppointmentsRepository(ref.watch(dioProvider));
});
