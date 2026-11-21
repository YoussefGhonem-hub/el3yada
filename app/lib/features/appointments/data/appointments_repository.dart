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
  const SearchFilter({this.from, this.to, this.statuses = const [], this.q, this.guestsOnly = false, this.branchId, this.checkedInNoSession = false});

  final DateTime? from;
  final DateTime? to;
  final List<String> statuses;
  final String? q;
  final bool guestsOnly;
  final String? branchId;

  /// BR-AP11: checked in on an earlier day, but no session was recorded.
  final bool checkedInNoSession;

  Map<String, dynamic> toQuery() => {
        if (from != null) 'from': dayKey(from!),
        if (to != null) 'to': dayKey(to!),
        if (statuses.isNotEmpty) 'statuses': statuses,
        if (q != null && q!.isNotEmpty) 'q': q,
        if (guestsOnly) 'guestsOnly': true,
        if (branchId != null) 'branchIds': [branchId],
        if (checkedInNoSession) 'checkedInNoSession': true,
        'pageSize': 100,
      };

  @override
  bool operator ==(Object other) =>
      other is SearchFilter && other.from == from && other.to == to && other.q == q && other.guestsOnly == guestsOnly &&
      other.branchId == branchId && other.statuses.join(',') == statuses.join(',') && other.checkedInNoSession == checkedInNoSession;

  @override
  int get hashCode => Object.hash(from, to, q, guestsOnly, branchId, statuses.join(','), checkedInNoSession);
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
/// morning and an evening period (capacity 5), a few bookings today. It follows the API's queue rules
/// (BR-AP3): a booking has no number; check-in, walk-ins and undoing a no-show take the period's next
/// number; numbers are never reused; priority keeps the number and goes first.
class FakeAppointmentsRepository implements AppointmentsRepository {
  FakeAppointmentsRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    final today = DateTime(_now.year, _now.month, _now.day);
    _list = [
      _make('ap-1', 'محمد إبراهيم', 'pat-1', today, '17:00', null, AppointmentStatus.confirmed),
      _make('ap-2', 'خالد يوسف', 'pat-2', today, '17:00', 1, AppointmentStatus.checkedIn),
      _make('ap-3', 'زائر جديد', null, today, '17:00', null, AppointmentStatus.pending, guest: true),
      // Yesterday: checked in, but no session was recorded (BR-AP11).
      _make('ap-0', 'سعاد كامل', 'pat-3', today.subtract(const Duration(days: 1)), '17:00', 4, AppointmentStatus.checkedIn, flagged: true),
    ];
    _bookedAt.addAll({
      'ap-0': _now.subtract(const Duration(days: 3)),
      'ap-2': _now.subtract(const Duration(hours: 6)),
      'ap-1': _now.subtract(const Duration(hours: 5)),
      'ap-3': _now.subtract(const Duration(hours: 2)),
    });
    _order['ap-2'] = 1;
  }

  final DateTime _now;
  late List<Appointment> _list;
  int _next = 10;

  /// When each booking was made: Expected is ordered by it in queue mode.
  final _bookedAt = <String, DateTime>{};

  /// The board order, as the API's `BoardOrder`: the number from check-in; a priority move goes before the rest.
  final _order = <String, int>{};
  final _calledAt = <String, DateTime>{};

  /// "Now serving" per period (`yyyy-MM-dd HH:mm`), and the last number called in today.
  final _serving = <String, int>{};
  int? _lastServing;

  static const avgVisitMinutes = 10;

  static const _doctor = DoctorRef(id: 'doc-a', fullName: 'د. أحمد سامي', fullNameEn: 'Dr. Ahmed Samy', title: 'استشاري', titleEn: 'Consultant');
  static const _branch = BranchRef(id: 'br-a1', nameAr: 'فرع المعادي', nameEn: 'Maadi branch');
  static const _phones = [BranchPhone(number: '+201011111111', label: 'reception', isWhatsapp: true)];

  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  static String _period(Appointment a) => '${dayKey(a.date)} ${a.time}';

  Appointment _make(String id, String name, String? patientId, DateTime date, String time, int? number, String status,
          {bool guest = false, String source = 'staff', bool flagged = false}) =>
      Appointment(
        id: id, doctor: _doctor, branch: _branch, patientId: patientId, displayName: name, phone: '+201000000002', isGuest: guest,
        visitType: 'examination', mode: 'queue', date: date, time: time,
        startUtc: DateTime(date.year, date.month, date.day, int.parse(time.substring(0, 2))).toUtc(),
        queueNumber: number, status: status, source: source,
        canChange: status == AppointmentStatus.pending || status == AppointmentStatus.confirmed, branchPhones: _phones,
        checkedInAt: status == AppointmentStatus.checkedIn ? _now : null, flaggedNoSession: flagged,
      );

  Appointment _set(String id, Appointment Function(Appointment a) change) {
    final index = _list.indexWhere((a) => a.id == id);
    if (index < 0) throw const ApiError(ApiError.notFound, status: 404);
    _list[index] = change(_list[index]);
    return _list[index];
  }

  Appointment _withStatus(Appointment a, String status) => a.copyWith(
        status: status,
        canChange: status == AppointmentStatus.pending || status == AppointmentStatus.confirmed,
        checkedInAt: () => status == AppointmentStatus.checkedIn ? (a.checkedInAt ?? DateTime.now()) : a.checkedInAt,
      );

  /// One more than the highest number the period ever gave (numbers are never reused).
  int _nextNumber(Appointment a) =>
      1 + _list.where((x) => _period(x) == _period(a) && x.queueNumber != null).fold<int>(0, (m, x) => x.queueNumber! > m ? x.queueNumber! : m);

  /// Checked in, numbered, in the order they go in: priority first, then by number.
  List<Appointment> _line(Appointment a) => _list.where((x) => _period(x) == _period(a) && x.inLine).toList()
    ..sort((x, y) => (_order[x.id] ?? 0).compareTo(_order[y.id] ?? 0));

  /// Arrival (BR-AP3): today only; the next number, unless already moved up.
  Appointment _arrive(Appointment a) {
    if (a.date != _today) throw const ApiError('INVALID_TRANSITION', status: 409);
    final number = _nextNumber(a);
    if (!a.isPriority) _order[a.id] = number;
    return a.copyWith(status: AppointmentStatus.checkedIn, canChange: false, queueNumber: () => number, checkedInAt: () => DateTime.now());
  }

  /// Like the API's `Appointment` on the day: "now serving" and, while checked in, who is ahead and the wait.
  Appointment _decorate(Appointment a) {
    if (!a.isQueue || a.date != _today) return a;
    final serving = _serving[_period(a)];
    if (!a.inLine) return a.copyWith(nowServing: () => serving);
    final ahead = _line(a).takeWhile((x) => x.id != a.id).length;
    final at = DateTime.now().add(Duration(minutes: ahead * avgVisitMinutes));
    return a.copyWith(
      nowServing: () => serving,
      ahead: () => ahead,
      estimatedWaitMinutes: () => ahead * avgVisitMinutes,
      estimatedTime: () => '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
    );
  }

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
  Future<List<Appointment>> myAppointments(String tab) async => [
        for (final a in switch (tab) {
          'cancelled' => _list.where((a) => a.status == AppointmentStatus.cancelled || a.status == AppointmentStatus.rejected),
          'past' => _list.where((a) => a.status == AppointmentStatus.completed || a.status == AppointmentStatus.noShow),
          _ => _list.where((a) => a.patientId == 'pat-1'
              && (a.isUpcoming || a.status == AppointmentStatus.checkedIn || a.status == AppointmentStatus.withDoctor)),
        })
          _decorate(a),
      ];

  Appointment _find(String id) => _list.firstWhere((a) => a.id == id, orElse: () => throw const ApiError(ApiError.notFound, status: 404));

  @override
  Future<Appointment> myAppointment(String id) async => _decorate(_find(id));

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
                      unavailable: booked(start) >= 5 ? 'PERIOD_FULL' : null),
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
    // A place on the period's list: no number until check-in (BR-AP3).
    final a = _make('ap-${_next++}', r.guestName ?? 'محمد إبراهيم', r.guestName == null ? (r.patientId ?? 'pat-1') : null, r.date, r.time, null,
        AppointmentStatus.confirmed, guest: r.guestName != null, source: staff ? 'staff' : 'patientApp');
    _list.add(a);
    _bookedAt[a.id] = DateTime.now();
    return a;
  }

  @override
  Future<Appointment> reschedule(String id, {required String branchId, required DateTime date, required String time, bool overbook = false, required bool staff}) async {
    final current = _find(id);
    if (!current.isUpcoming) throw const ApiError('INVALID_TRANSITION', status: 409);
    return _set(id, (a) => a.copyWith(
          date: date, time: time, queueNumber: () => null, rescheduleCount: a.rescheduleCount + 1,
          startUtc: DateTime(date.year, date.month, date.day, int.parse(time.substring(0, 2))).toUtc(),
        ));
  }

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
        (!filter.guestsOnly || a.isGuest) &&
        (!filter.checkedInNoSession || a.flaggedNoSession)).toList();
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

  /// The API's board order (6.13): Expected by booking time; Waiting priority first, then by number (the order of
  /// arrival); With the doctor by when they went in.
  int _compare(Appointment x, Appointment y) {
    final stages = BoardStage.all;
    final byStage = stages.indexOf(_stage(x.status)).compareTo(stages.indexOf(_stage(y.status)));
    if (byStage != 0) return byStage;
    return switch (_stage(x.status)) {
      BoardStage.expected => _bookedAt[x.id]!.compareTo(_bookedAt[y.id]!),
      BoardStage.waiting => [
          (x.isPriority ? 0 : 1).compareTo(y.isPriority ? 0 : 1),
          x.time.compareTo(y.time),
          (_order[x.id] ?? 0).compareTo(_order[y.id] ?? 0),
        ].firstWhere((c) => c != 0, orElse: () => 0),
      BoardStage.withDoctor => (_calledAt[x.id] ?? _now).compareTo(_calledAt[y.id] ?? _now),
      _ => (_order[x.id] ?? 0).compareTo(_order[y.id] ?? 0),
    };
  }

  @override
  Future<BoardSnapshot> board(String branchId, {DateTime? date}) async {
    final day = date ?? _today;
    final today = _list.where((a) => a.date == day).toList()..sort(_compare);
    final entries = [
      for (final a in today)
        BoardEntry(
          appointmentId: a.id, queueNumber: a.queueNumber, timeLocal: a.time, stage: _stage(a.status), displayName: a.displayName,
          visitType: a.visitType, source: a.source, isNewPatient: a.isGuest, guest: a.isGuest, pending: a.status == AppointmentStatus.pending,
          priority: a.isPriority, walkIn: a.source == 'walkIn', checkedInAt: a.checkedInAt, status: a.status, patientId: a.patientId,
          createdAt: _bookedAt[a.id] ?? _now,
        ),
    ];
    final serving = _lastServing;
    return BoardSnapshot(branchId: branchId, date: day, mode: 'queue', nowServing: serving, entries: entries, updatedAt: DateTime.now(),
        nextNumbers: [for (final e in entries.where((e) => e.stage == BoardStage.waiting && e.queueNumber != null).take(5)) e.queueNumber!]);
  }

  @override
  Future<BoardPatientSummary> boardSummary(String appointmentId) async {
    final a = await myAppointment(appointmentId);
    return BoardPatientSummary(displayName: a.displayName, isGuest: a.isGuest, phone: a.phone, age: 41, fileNumber: a.isGuest ? null : 1,
        examCount: 1, allergies: a.isGuest ? null : const ['البنسلين'], consultationAllowed: !a.isGuest);
  }

  @override
  Future<Appointment> act(String id, String action, {String? reason}) async {
    final a = _find(id);
    final changed = switch (action) {
      'check-in' when a.isUpcoming => _arrive(a),
      'undo-no-show' when a.status == AppointmentStatus.noShow => _arrive(a),
      'call-in' when a.status == AppointmentStatus.checkedIn => () {
          _calledAt[a.id] = DateTime.now();
          if (a.queueNumber != null) _lastServing = _serving[_period(a)] = a.queueNumber!;
          return _withStatus(a, AppointmentStatus.withDoctor);
        }(),
      'send-back' when a.status == AppointmentStatus.withDoctor => _withStatus(a, AppointmentStatus.checkedIn),
      'no-show' when a.status == AppointmentStatus.confirmed => _withStatus(a, AppointmentStatus.noShow),
      'left-without-seen' when a.status == AppointmentStatus.checkedIn || a.status == AppointmentStatus.withDoctor =>
        _withStatus(a, AppointmentStatus.cancelled),
      'confirm' when a.status == AppointmentStatus.pending => _withStatus(a, AppointmentStatus.confirmed),
      'reject' when a.status == AppointmentStatus.pending => _withStatus(a, AppointmentStatus.rejected),
      // BR-AP3: keeps the number, goes before the rest.
      'priority' when a.status == AppointmentStatus.checkedIn || a.status == AppointmentStatus.confirmed => () {
          _order[a.id] = _order.values.fold<int>(0, (m, v) => v < m ? v : m) - 1;
          return a.copyWith(isPriority: true);
        }(),
      _ => throw const ApiError('ALREADY_HANDLED', status: 409),
    };
    return _decorate(_set(id, (_) => changed));
  }

  @override
  Future<Appointment> walkIn({required String branchId, String? patientId, String? guestName, String? guestPhone, required String visitType}) async {
    // Checked in at once: the period's next number, in the same line as the booked patients (case 4).
    final draft = _make('ap-${_next++}', guestName ?? 'محمد إبراهيم', guestName == null ? patientId : null, _today, '17:00', null,
        AppointmentStatus.confirmed, guest: guestName != null, source: 'walkIn');
    final a = _arrive(draft);
    _list.add(a);
    _bookedAt[a.id] = DateTime.now();
    return _decorate(a);
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
