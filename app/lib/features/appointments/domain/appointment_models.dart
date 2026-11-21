// Models of bookings, availability, the live board and the schedule (spec 6.12, 6.13).
// They mirror backend Features/Appointments/AppointmentDtos.cs and BoardSnapshot.

import '../../patient/domain/patient_models.dart' show Json, DoctorRef, BranchRef, BranchPhone, VisitPrices;

DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);
String _hhmm(Object? v) => (v as String).substring(0, 5);

/// `yyyy-MM-dd` for API dates.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

abstract final class AppointmentStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const checkedIn = 'checkedIn';
  static const withDoctor = 'withDoctor';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const noShow = 'noShow';
  static const rejected = 'rejected';

  static const all = [pending, confirmed, checkedIn, withDoctor, completed, cancelled, noShow, rejected];
}

class AppointmentHistoryItem {
  const AppointmentHistoryItem({required this.at, required this.byRole, this.byName, required this.action, this.reason});

  final DateTime at;
  final String byRole;
  final String? byName;
  final String action;
  final String? reason;

  factory AppointmentHistoryItem.fromJson(Json j) => AppointmentHistoryItem(
        at: DateTime.parse(j['at'] as String),
        byRole: j['byRole'] as String,
        byName: j['byName'] as String?,
        action: j['action'] as String,
        reason: j['reason'] as String?,
      );
}

class Appointment {
  const Appointment({
    required this.id,
    required this.doctor,
    required this.branch,
    this.patientId,
    required this.displayName,
    this.phone,
    required this.isGuest,
    required this.visitType,
    required this.mode,
    required this.date,
    required this.time,
    required this.startUtc,
    this.queueNumber,
    required this.status,
    required this.source,
    this.bookedByName,
    this.reason,
    this.staffNotes,
    this.overbooked = false,
    this.rescheduleCount = 0,
    this.checkedInAt,
    this.sessionId,
    this.cancelReason,
    this.cancelledByRole,
    this.isPriority = false,
    this.flaggedNoSession = false,
    this.canChange = false,
    this.nowServing,
    this.estimatedTime,
    this.history = const [],
    this.branchPhones = const [],
    this.ahead,
    this.estimatedWaitMinutes,
  });

  final String id;
  final DoctorRef doctor;
  final BranchRef branch;
  final String? patientId;
  final String displayName;
  final String? phone;
  final bool isGuest;
  final String visitType;

  /// `queue` or `timed`.
  final String mode;
  final DateTime date;

  /// Queue: the period start; timed: the slot start (`HH:mm`, Cairo time).
  final String time;
  final DateTime startUtc;

  /// Queue mode: given at check-in, in order of arrival (BR-AP3). Null before.
  final int? queueNumber;
  final String status;

  /// `patientApp`, `staff` or `walkIn`.
  final String source;
  final String? bookedByName;
  final String? reason;
  final String? staffNotes;
  final bool overbooked;
  final int rescheduleCount;
  final DateTime? checkedInAt;
  final String? sessionId;
  final String? cancelReason;
  final String? cancelledByRole;
  final bool isPriority;
  final bool flaggedNoSession;

  /// The patient can still cancel or reschedule (BR-AP5).
  final bool canChange;

  /// Queue mode on the day: the number with the doctor in this period (BR-AP15).
  final int? nowServing;

  /// Queue mode, checked in: about when the patient goes in (`HH:mm`).
  final String? estimatedTime;
  final List<AppointmentHistoryItem> history;
  final List<BranchPhone> branchPhones;

  /// Queue mode, checked in: patients who go in first (BR-AP16).
  final int? ahead;

  /// Queue mode, checked in: [ahead] × the branch's average visit time.
  final int? estimatedWaitMinutes;

  bool get isQueue => mode == 'queue';
  bool get isUpcoming => status == AppointmentStatus.pending || status == AppointmentStatus.confirmed;

  /// Queue mode, not arrived yet: a place on the period's list, no number. The turn is given at check-in.
  bool get awaitsCheckIn => isQueue && isUpcoming;

  /// Queue mode, checked in and waiting: has a number, patients ahead and an estimated wait.
  bool get inLine => isQueue && status == AppointmentStatus.checkedIn && queueNumber != null;

  Appointment copyWith({
    String? patientId,
    String? displayName,
    bool? isGuest,
    DateTime? date,
    String? time,
    DateTime? startUtc,
    int? Function()? queueNumber,
    String? status,
    bool? canChange,
    DateTime? Function()? checkedInAt,
    bool? isPriority,
    int? Function()? nowServing,
    String? Function()? estimatedTime,
    int? Function()? ahead,
    int? Function()? estimatedWaitMinutes,
    int? rescheduleCount,
  }) =>
      Appointment(
        id: id, doctor: doctor, branch: branch, patientId: patientId ?? this.patientId, displayName: displayName ?? this.displayName,
        phone: phone, isGuest: isGuest ?? this.isGuest, visitType: visitType, mode: mode, date: date ?? this.date, time: time ?? this.time,
        startUtc: startUtc ?? this.startUtc, queueNumber: queueNumber != null ? queueNumber() : this.queueNumber,
        status: status ?? this.status, source: source, bookedByName: bookedByName, reason: reason, staffNotes: staffNotes,
        overbooked: overbooked, rescheduleCount: rescheduleCount ?? this.rescheduleCount,
        checkedInAt: checkedInAt != null ? checkedInAt() : this.checkedInAt, sessionId: sessionId, cancelReason: cancelReason,
        cancelledByRole: cancelledByRole, isPriority: isPriority ?? this.isPriority, flaggedNoSession: flaggedNoSession,
        canChange: canChange ?? this.canChange, nowServing: nowServing != null ? nowServing() : this.nowServing,
        estimatedTime: estimatedTime != null ? estimatedTime() : this.estimatedTime, history: history, branchPhones: branchPhones,
        ahead: ahead != null ? ahead() : this.ahead,
        estimatedWaitMinutes: estimatedWaitMinutes != null ? estimatedWaitMinutes() : this.estimatedWaitMinutes,
      );

  factory Appointment.fromJson(Json j) => Appointment(
        id: j['id'] as String,
        doctor: DoctorRef.fromJson(j['doctor'] as Json),
        branch: BranchRef.fromJson(j['branch'] as Json),
        patientId: j['patientId'] as String?,
        displayName: j['displayName'] as String? ?? '',
        phone: j['phone'] as String?,
        isGuest: j['isGuest'] as bool? ?? false,
        visitType: j['visitType'] as String,
        mode: j['mode'] as String,
        date: DateTime.parse(j['date'] as String),
        time: _hhmm(j['time']),
        startUtc: DateTime.parse(j['startUtc'] as String),
        queueNumber: j['queueNumber'] as int?,
        status: j['status'] as String,
        source: j['source'] as String,
        bookedByName: j['bookedByName'] as String?,
        reason: j['reason'] as String?,
        staffNotes: j['staffNotes'] as String?,
        overbooked: j['overbooked'] as bool? ?? false,
        rescheduleCount: j['rescheduleCount'] as int? ?? 0,
        checkedInAt: _dt(j['checkedInAt']),
        sessionId: j['sessionId'] as String?,
        cancelReason: j['cancelReason'] as String?,
        cancelledByRole: j['cancelledByRole'] as String?,
        isPriority: j['isPriority'] as bool? ?? false,
        flaggedNoSession: j['flaggedNoSession'] as bool? ?? false,
        canChange: j['canChange'] as bool? ?? false,
        nowServing: j['nowServing'] as int?,
        estimatedTime: j['estimatedTime'] == null ? null : _hhmm(j['estimatedTime']),
        history: [for (final h in (j['history'] as List? ?? const [])) AppointmentHistoryItem.fromJson(h as Json)],
        branchPhones: [for (final p in (j['branchPhones'] as List? ?? const [])) BranchPhone.fromJson(p as Json)],
        ahead: j['ahead'] as int?,
        estimatedWaitMinutes: j['estimatedWaitMinutes'] as int?,
      );
}

// ---- Availability -------------------------------------------------------------------------------

class PeriodSlot {
  const PeriodSlot({
    required this.start,
    required this.end,
    this.label,
    required this.capacity,
    required this.booked,
    required this.remaining,
    this.unavailable,
  });

  final String start;
  final String end;
  final String? label;
  final int capacity;
  final int booked;
  final int remaining;

  /// Null when bookable; otherwise a 6.12.6 code.
  final String? unavailable;

  bool get available => unavailable == null && remaining > 0;

  factory PeriodSlot.fromJson(Json j) => PeriodSlot(
        start: _hhmm(j['start']),
        end: _hhmm(j['end']),
        label: j['label'] as String?,
        capacity: j['capacity'] as int,
        booked: j['booked'] as int,
        remaining: j['remaining'] as int,
        unavailable: j['unavailable'] as String?,
      );
}

class TimeSlot {
  const TimeSlot({required this.start, required this.end, required this.available, this.unavailable});

  final String start;
  final String end;
  final bool available;
  final String? unavailable;

  factory TimeSlot.fromJson(Json j) => TimeSlot(
        start: _hhmm(j['start']),
        end: _hhmm(j['end']),
        available: j['available'] as bool,
        unavailable: j['unavailable'] as String?,
      );
}

class DayAvailability {
  const DayAvailability({required this.date, required this.closed, this.reason, this.periods = const [], this.slots = const []});

  final DateTime date;
  final bool closed;
  final String? reason;
  final List<PeriodSlot> periods;
  final List<TimeSlot> slots;

  factory DayAvailability.fromJson(Json j) => DayAvailability(
        date: DateTime.parse(j['date'] as String),
        closed: j['closed'] as bool,
        reason: j['reason'] as String?,
        periods: [for (final p in j['periods'] as List) PeriodSlot.fromJson(p as Json)],
        slots: [for (final s in j['slots'] as List) TimeSlot.fromJson(s as Json)],
      );
}

class Availability {
  const Availability({required this.branchId, required this.mode, required this.days});

  final String branchId;
  final String mode;
  final List<DayAvailability> days;

  factory Availability.fromJson(Json j) => Availability(
        branchId: j['branchId'] as String,
        mode: j['mode'] as String,
        days: [for (final d in j['days'] as List) DayAvailability.fromJson(d as Json)],
      );
}

// ---- P15 booking options ------------------------------------------------------------------------

class BookingBranch {
  const BookingBranch({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.area,
    required this.status,
    this.closedMessage,
    required this.mode,
    required this.selfBooking,
    required this.freeCancelMinutes,
    required this.windowDays,
    required this.prices,
    this.phones = const [],
  });

  final String id;
  final String nameAr;
  final String? nameEn;
  final String? area;
  final String status;
  final String? closedMessage;
  final String mode;
  final bool selfBooking;
  final int freeCancelMinutes;
  final int windowDays;
  final VisitPrices prices;
  final List<BranchPhone> phones;

  String displayName({required bool arabic}) => !arabic && nameEn != null ? nameEn! : nameAr;
  bool get canBook => status == 'active' && selfBooking;

  factory BookingBranch.fromJson(Json j) => BookingBranch(
        id: j['id'] as String,
        nameAr: j['nameAr'] as String,
        nameEn: j['nameEn'] as String?,
        area: j['area'] as String?,
        status: j['status'] as String,
        closedMessage: j['closedMessage'] as String?,
        mode: j['mode'] as String,
        selfBooking: j['selfBooking'] as bool,
        freeCancelMinutes: j['freeCancelMinutes'] as int,
        windowDays: j['windowDays'] as int,
        prices: VisitPrices.fromJson(j['prices'] as Json),
        phones: [for (final p in (j['phones'] as List? ?? const [])) BranchPhone.fromJson(p as Json)],
      );
}

class BookingOptions {
  const BookingOptions({
    required this.doctor,
    required this.canBook,
    this.unavailableReason,
    required this.isNewPatient,
    required this.consultationAllowed,
    required this.consultationsSinceExam,
    required this.maxConsecutiveConsultations,
    this.upcomingAppointmentId,
    this.branches = const [],
  });

  final DoctorRef doctor;
  final bool canBook;
  final String? unavailableReason;
  final bool isNewPatient;
  final bool consultationAllowed;
  final int consultationsSinceExam;
  final int maxConsecutiveConsultations;
  final String? upcomingAppointmentId;
  final List<BookingBranch> branches;

  factory BookingOptions.fromJson(Json j) => BookingOptions(
        doctor: DoctorRef.fromJson(j['doctor'] as Json),
        canBook: j['canBook'] as bool,
        unavailableReason: j['unavailableReason'] as String?,
        isNewPatient: j['isNewPatient'] as bool,
        consultationAllowed: j['consultationAllowed'] as bool,
        consultationsSinceExam: j['consultationsSinceExam'] as int,
        maxConsecutiveConsultations: j['maxConsecutiveConsultations'] as int,
        upcomingAppointmentId: j['upcomingAppointmentId'] as String?,
        branches: [for (final b in j['branches'] as List) BookingBranch.fromJson(b as Json)],
      );
}

// ---- Live board ---------------------------------------------------------------------------------

abstract final class BoardStage {
  static const expected = 'expected';
  static const waiting = 'waiting';
  static const withDoctor = 'withDoctor';
  static const done = 'done';
  static const missed = 'missed';

  static const all = [expected, waiting, withDoctor, done, missed];
}

class BoardEntry {
  const BoardEntry({
    required this.appointmentId,
    this.queueNumber,
    this.timeLocal,
    required this.stage,
    required this.displayName,
    required this.visitType,
    required this.source,
    required this.isNewPatient,
    this.lastVisitDate,
    this.lastVisitType,
    this.priority = false,
    this.walkIn = false,
    this.late = false,
    this.guest = false,
    this.consultationNotAllowed = false,
    this.hasNotes = false,
    this.pending = false,
    this.checkedInAt,
    required this.status,
    this.patientId,
    required this.createdAt,
  });

  final String appointmentId;
  final int? queueNumber;
  final String? timeLocal;
  final String stage;
  final String displayName;
  final String visitType;
  final String source;
  final bool isNewPatient;
  final DateTime? lastVisitDate;
  final String? lastVisitType;
  final bool priority;
  final bool walkIn;
  final bool late;
  final bool guest;
  final bool consultationNotAllowed;
  final bool hasNotes;
  final bool pending;
  final DateTime? checkedInAt;
  final String status;
  final String? patientId;
  final DateTime createdAt;

  factory BoardEntry.fromJson(Json j) {
    final f = j['flags'] as Json? ?? const {};
    return BoardEntry(
      appointmentId: j['appointmentId'] as String,
      queueNumber: j['queueNumber'] as int?,
      timeLocal: j['timeLocal'] as String?,
      stage: j['stage'] as String,
      displayName: j['displayName'] as String,
      visitType: j['visitType'] as String,
      source: j['source'] as String,
      isNewPatient: j['isNewPatient'] as bool? ?? false,
      lastVisitDate: j['lastVisitDate'] == null ? null : DateTime.parse(j['lastVisitDate'] as String),
      lastVisitType: j['lastVisitType'] as String?,
      priority: f['priority'] as bool? ?? false,
      walkIn: f['walkIn'] as bool? ?? false,
      late: f['late'] as bool? ?? false,
      guest: f['guest'] as bool? ?? false,
      consultationNotAllowed: f['consultationNotAllowed'] as bool? ?? false,
      hasNotes: f['hasNotes'] as bool? ?? false,
      pending: f['pending'] as bool? ?? false,
      checkedInAt: _dt(j['checkedInAt']),
      status: j['status'] as String,
      patientId: j['patientId'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
}

class BoardSnapshot {
  const BoardSnapshot({
    required this.branchId,
    required this.date,
    required this.mode,
    this.nowServing,
    this.delayMinutes,
    required this.entries,
    this.nextNumbers = const [],
    required this.updatedAt,
  });

  final String branchId;
  final DateTime date;
  final String mode;
  final int? nowServing;
  final int? delayMinutes;
  final List<BoardEntry> entries;
  final List<int> nextNumbers;
  final DateTime updatedAt;

  List<BoardEntry> stage(String stage) => entries.where((e) => e.stage == stage).toList();

  factory BoardSnapshot.fromJson(Json j) => BoardSnapshot(
        branchId: j['branchId'] as String,
        date: DateTime.parse(j['date'] as String),
        mode: j['mode'] as String,
        nowServing: j['nowServing'] as int?,
        delayMinutes: j['delayMinutes'] as int?,
        entries: [for (final e in j['entries'] as List) BoardEntry.fromJson(e as Json)],
        nextNumbers: [for (final n in (j['nextNumbers'] as List? ?? const [])) n as int],
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}

class BoardPatientSummary {
  const BoardPatientSummary({
    required this.displayName,
    required this.isGuest,
    this.phone,
    this.age,
    this.fileNumber,
    this.examCount = 0,
    this.consultationCount = 0,
    this.lastVisitAt,
    this.lastVisitType,
    this.upcomingBookings = 0,
    this.noShows = 0,
    this.reason,
    this.staffNotes,
    this.allergies,
    this.chronicDiseases,
    this.lastDiagnosis,
    this.recentAmountsPiasters,
    this.consultationAllowed = false,
    this.selfBookingBlocked = false,
  });

  final String displayName;
  final bool isGuest;
  final String? phone;
  final int? age;
  final int? fileNumber;
  final int examCount;
  final int consultationCount;
  final DateTime? lastVisitAt;
  final String? lastVisitType;
  final int upcomingBookings;
  final int noShows;
  final String? reason;
  final String? staffNotes;

  /// Null when the caller can't see clinical content.
  final List<String>? allergies;
  final List<String>? chronicDiseases;
  final String? lastDiagnosis;

  /// Null without revenue access.
  final List<int>? recentAmountsPiasters;
  final bool consultationAllowed;
  final bool selfBookingBlocked;

  static List<String>? _strings(Object? v) => v == null ? null : [for (final s in v as List) s as String];

  factory BoardPatientSummary.fromJson(Json j) => BoardPatientSummary(
        displayName: j['displayName'] as String,
        isGuest: j['isGuest'] as bool,
        phone: j['phone'] as String?,
        age: j['age'] as int?,
        fileNumber: j['fileNumber'] as int?,
        examCount: j['examCount'] as int? ?? 0,
        consultationCount: j['consultationCount'] as int? ?? 0,
        lastVisitAt: _dt(j['lastVisitAt']),
        lastVisitType: j['lastVisitType'] as String?,
        upcomingBookings: j['upcomingBookings'] as int? ?? 0,
        noShows: j['noShows'] as int? ?? 0,
        reason: j['reason'] as String?,
        staffNotes: j['staffNotes'] as String?,
        allergies: _strings(j['allergies']),
        chronicDiseases: _strings(j['chronicDiseases']),
        lastDiagnosis: j['lastDiagnosis'] as String?,
        recentAmountsPiasters: j['recentAmountsPiasters'] == null ? null : [for (final a in j['recentAmountsPiasters'] as List) a as int],
        consultationAllowed: j['consultationAllowed'] as bool? ?? false,
        selfBookingBlocked: j['selfBookingBlocked'] as bool? ?? false,
      );
}

// ---- Staff helpers ------------------------------------------------------------------------------

class StaffBranch {
  const StaffBranch({required this.id, required this.nameAr, this.nameEn, required this.isDefault, required this.status, required this.mode});

  final String id;
  final String nameAr;
  final String? nameEn;
  final bool isDefault;
  final String status;
  final String mode;

  String displayName({required bool arabic}) => !arabic && nameEn != null ? nameEn! : nameAr;

  factory StaffBranch.fromJson(Json j) => StaffBranch(
        id: j['id'] as String,
        nameAr: j['nameAr'] as String,
        nameEn: j['nameEn'] as String?,
        isDefault: j['isDefault'] as bool,
        status: j['status'] as String,
        mode: j['mode'] as String,
      );
}

class PatientLookup {
  const PatientLookup({
    required this.patientId,
    required this.name,
    required this.phone,
    required this.fileNumber,
    required this.sessionCount,
    required this.consultationAllowed,
    required this.consultationsSinceExam,
    this.lastVisitAt,
    this.upcomingAppointmentId,
  });

  final String patientId;
  final String name;
  final String phone;
  final int fileNumber;
  final int sessionCount;
  final bool consultationAllowed;
  final int consultationsSinceExam;
  final DateTime? lastVisitAt;
  final String? upcomingAppointmentId;

  bool get isNew => sessionCount == 0;

  factory PatientLookup.fromJson(Json j) => PatientLookup(
        patientId: j['patientId'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        fileNumber: j['fileNumber'] as int,
        sessionCount: j['sessionCount'] as int,
        consultationAllowed: j['consultationAllowed'] as bool,
        consultationsSinceExam: j['consultationsSinceExam'] as int,
        lastVisitAt: _dt(j['lastVisitAt']),
        upcomingAppointmentId: j['upcomingAppointmentId'] as String?,
      );
}

class SearchResult {
  const SearchResult({required this.items, required this.totalCount, required this.statusCounts});

  final List<Appointment> items;
  final int totalCount;
  final Map<String, int> statusCounts;

  factory SearchResult.fromJson(Json j) {
    final page = j['page'] as Json;
    return SearchResult(
      items: [for (final a in page['items'] as List) Appointment.fromJson(a as Json)],
      totalCount: page['totalCount'] as int,
      statusCounts: {for (final e in (j['statusCounts'] as Json).entries) e.key: e.value as int},
    );
  }
}

// ---- Schedule (D29, AS17) -----------------------------------------------------------------------

class WeeklyPeriod {
  const WeeklyPeriod({required this.weekday, required this.start, required this.end, this.endsNextDay = false, this.label, this.capacity});

  /// ISO: 1 = Monday … 7 = Sunday.
  final int weekday;
  final String start;
  final String end;
  final bool endsNextDay;
  final String? label;
  final int? capacity;

  WeeklyPeriod copyWith({int? weekday, String? start, String? end, bool? endsNextDay, String? label, int? capacity}) => WeeklyPeriod(
        weekday: weekday ?? this.weekday, start: start ?? this.start, end: end ?? this.end,
        endsNextDay: endsNextDay ?? this.endsNextDay, label: label ?? this.label, capacity: capacity ?? this.capacity,
      );

  Json toJson() => {'weekday': weekday, 'start': start, 'end': end, 'endsNextDay': endsNextDay, 'label': label, 'capacity': capacity};

  factory WeeklyPeriod.fromJson(Json j) => WeeklyPeriod(
        weekday: j['weekday'] as int,
        start: _hhmm(j['start']),
        end: _hhmm(j['end']),
        endsNextDay: j['endsNextDay'] as bool? ?? false,
        label: j['label'] as String?,
        capacity: j['capacity'] as int?,
      );
}

class DateOverride {
  const DateOverride({required this.date, this.periods = const []});

  final DateTime date;

  /// Empty = closed that day.
  final List<WeeklyPeriod> periods;

  Json toJson() => {
        'date': dayKey(date),
        'periods': [for (final p in periods) {'start': p.start, 'end': p.end, 'endsNextDay': p.endsNextDay, 'label': p.label, 'capacity': p.capacity}],
      };

  factory DateOverride.fromJson(Json j) => DateOverride(
        date: DateTime.parse(j['date'] as String),
        periods: [
          for (final p in j['periods'] as List)
            WeeklyPeriod(weekday: 0, start: _hhmm((p as Json)['start']), end: _hhmm(p['end']), endsNextDay: p['endsNextDay'] as bool? ?? false,
                label: p['label'] as String?, capacity: p['capacity'] as int?),
        ],
      );
}

class Closure {
  const Closure({this.id, required this.from, required this.to, this.reason, this.allBranches = false});

  final String? id;

  /// Cairo local times.
  final DateTime from;
  final DateTime to;
  final String? reason;
  final bool allBranches;

  static String _local(DateTime d) => '${dayKey(d)}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

  Json toJson() => {'id': id, 'fromLocal': _local(from), 'toLocal': _local(to), 'reason': reason, 'allBranches': allBranches};

  factory Closure.fromJson(Json j) => Closure(
        id: j['id'] as String?,
        from: DateTime.parse((j['fromLocal'] as String).replaceAll('Z', '')),
        to: DateTime.parse((j['toLocal'] as String).replaceAll('Z', '')),
        reason: j['reason'] as String?,
        allBranches: j['allBranches'] as bool? ?? false,
      );
}

class BookingSettings {
  const BookingSettings({
    this.mode = 'queue',
    this.slotMinutes = 15,
    this.examSlots = 1,
    this.consultationSlots = 1,
    this.defaultCapacity = 30,
    this.avgVisitMinutes = 10,
    this.selfBooking = true,
    this.autoConfirm = true,
    this.windowDays = 30,
    this.minNoticeMinutes = 60,
    this.sameDay = true,
    this.freeCancelMinutes = 120,
    this.maxReschedules = 2,
    this.maxUpcomingPerPatient = 1,
    this.noShowLimitCount = 3,
    this.noShowLimitDays = 90,
    this.reminderMinutes = const [1440, 120],
    this.staffOverbooking = true,
    this.waitingOrderByArrival = false,
  });

  final String mode;
  final int slotMinutes;
  final int examSlots;
  final int consultationSlots;
  final int defaultCapacity;
  final int avgVisitMinutes;
  final bool selfBooking;
  final bool autoConfirm;
  final int windowDays;
  final int minNoticeMinutes;
  final bool sameDay;
  final int freeCancelMinutes;
  final int maxReschedules;
  final int maxUpcomingPerPatient;
  final int noShowLimitCount;
  final int noShowLimitDays;
  final List<int> reminderMinutes;
  final bool staffOverbooking;
  final bool waitingOrderByArrival;

  Json toJson() => {
        'mode': mode, 'slotMinutes': slotMinutes, 'examSlots': examSlots, 'consultationSlots': consultationSlots,
        'defaultCapacity': defaultCapacity, 'avgVisitMinutes': avgVisitMinutes, 'selfBooking': selfBooking,
        'autoConfirm': autoConfirm, 'windowDays': windowDays, 'minNoticeMinutes': minNoticeMinutes, 'sameDay': sameDay,
        'freeCancelMinutes': freeCancelMinutes, 'maxReschedules': maxReschedules, 'maxUpcomingPerPatient': maxUpcomingPerPatient,
        'noShowLimitCount': noShowLimitCount, 'noShowLimitDays': noShowLimitDays, 'reminderMinutes': reminderMinutes,
        'staffOverbooking': staffOverbooking, 'waitingOrderByArrival': waitingOrderByArrival,
      };

  factory BookingSettings.fromJson(Json j) => BookingSettings(
        mode: j['mode'] as String,
        slotMinutes: j['slotMinutes'] as int,
        examSlots: j['examSlots'] as int,
        consultationSlots: j['consultationSlots'] as int,
        defaultCapacity: j['defaultCapacity'] as int,
        avgVisitMinutes: j['avgVisitMinutes'] as int,
        selfBooking: j['selfBooking'] as bool,
        autoConfirm: j['autoConfirm'] as bool,
        windowDays: j['windowDays'] as int,
        minNoticeMinutes: j['minNoticeMinutes'] as int,
        sameDay: j['sameDay'] as bool,
        freeCancelMinutes: j['freeCancelMinutes'] as int,
        maxReschedules: j['maxReschedules'] as int,
        maxUpcomingPerPatient: j['maxUpcomingPerPatient'] as int,
        noShowLimitCount: j['noShowLimitCount'] as int,
        noShowLimitDays: j['noShowLimitDays'] as int,
        reminderMinutes: [for (final m in j['reminderMinutes'] as List) m as int],
        staffOverbooking: j['staffOverbooking'] as bool,
        waitingOrderByArrival: j['waitingOrderByArrival'] as bool? ?? false,
      );

  BookingSettings copyWith({
    String? mode, int? slotMinutes, int? examSlots, int? consultationSlots, int? defaultCapacity, int? avgVisitMinutes,
    bool? selfBooking, bool? autoConfirm, int? windowDays, int? minNoticeMinutes, bool? sameDay, int? freeCancelMinutes,
    int? maxReschedules, int? maxUpcomingPerPatient, int? noShowLimitCount, int? noShowLimitDays, List<int>? reminderMinutes,
    bool? staffOverbooking,
  }) =>
      BookingSettings(
        mode: mode ?? this.mode, slotMinutes: slotMinutes ?? this.slotMinutes, examSlots: examSlots ?? this.examSlots,
        consultationSlots: consultationSlots ?? this.consultationSlots,
        defaultCapacity: defaultCapacity ?? this.defaultCapacity, avgVisitMinutes: avgVisitMinutes ?? this.avgVisitMinutes,
        selfBooking: selfBooking ?? this.selfBooking, autoConfirm: autoConfirm ?? this.autoConfirm, windowDays: windowDays ?? this.windowDays,
        minNoticeMinutes: minNoticeMinutes ?? this.minNoticeMinutes, sameDay: sameDay ?? this.sameDay,
        freeCancelMinutes: freeCancelMinutes ?? this.freeCancelMinutes, maxReschedules: maxReschedules ?? this.maxReschedules,
        maxUpcomingPerPatient: maxUpcomingPerPatient ?? this.maxUpcomingPerPatient,
        noShowLimitCount: noShowLimitCount ?? this.noShowLimitCount, noShowLimitDays: noShowLimitDays ?? this.noShowLimitDays,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes, staffOverbooking: staffOverbooking ?? this.staffOverbooking,
        waitingOrderByArrival: waitingOrderByArrival,
      );
}

class BranchScheduleData {
  const BranchScheduleData({required this.branchId, this.weekly = const [], this.overrides = const [], this.closures = const [], this.settings = const BookingSettings()});

  final String branchId;
  final List<WeeklyPeriod> weekly;
  final List<DateOverride> overrides;
  final List<Closure> closures;
  final BookingSettings settings;

  BranchScheduleData copyWith({List<WeeklyPeriod>? weekly, List<DateOverride>? overrides, List<Closure>? closures, BookingSettings? settings}) =>
      BranchScheduleData(branchId: branchId, weekly: weekly ?? this.weekly, overrides: overrides ?? this.overrides,
          closures: closures ?? this.closures, settings: settings ?? this.settings);

  factory BranchScheduleData.fromJson(Json j) => BranchScheduleData(
        branchId: j['branchId'] as String,
        weekly: [for (final p in j['weekly'] as List) WeeklyPeriod.fromJson(p as Json)],
        overrides: [for (final o in j['dateOverrides'] as List) DateOverride.fromJson(o as Json)],
        closures: [for (final c in j['closures'] as List) Closure.fromJson(c as Json)],
        settings: BookingSettings.fromJson(j['settings'] as Json),
      );
}

/// A place a booking can move to: a period start (queue) or a slot start (timed).
class MovePlace {
  const MovePlace({required this.branchId, required this.date, required this.time});

  final String branchId;
  final DateTime date;
  final String time;

  factory MovePlace.fromJson(Json j) =>
      MovePlace(branchId: j['branchId'] as String, date: DateTime.parse(j['date'] as String), time: _hhmm(j['time']));

  @override
  bool operator ==(Object other) => other is MovePlace && other.branchId == branchId && other.date == date && other.time == time;

  @override
  int get hashCode => Object.hash(branchId, date, time);
}

/// A booking the new schedule leaves without a place (BR-AP12). [suggestion] is the server's
/// nearest free place under the new schedule, or null.
class ScheduleConflict {
  const ScheduleConflict({
    required this.appointmentId,
    required this.displayName,
    required this.date,
    required this.time,
    this.queueNumber,
    this.status = AppointmentStatus.confirmed,
    this.branchId,
    this.visitType = 'examination',
    this.suggestion,
  });

  final String appointmentId;
  final String displayName;
  final DateTime date;
  final String time;
  final int? queueNumber;
  final String status;
  final String? branchId;
  final String visitType;
  final MovePlace? suggestion;

  factory ScheduleConflict.fromJson(Json j) => ScheduleConflict(
        appointmentId: j['appointmentId'] as String,
        displayName: j['displayName'] as String,
        date: DateTime.parse(j['date'] as String),
        time: _hhmm(j['time']),
        queueNumber: j['queueNumber'] as int?,
        status: j['status'] as String? ?? AppointmentStatus.confirmed,
        branchId: j['branchId'] as String?,
        visitType: j['visitType'] as String? ?? 'examination',
        suggestion: j['suggestion'] == null ? null : MovePlace.fromJson(Map<String, dynamic>.from(j['suggestion'] as Map)),
      );
}

/// What to do with one affected booking (BR-AP12): keep it as an exception, move it to [to], or
/// cancel it (the patient is told, with a rebook link).
class ConflictDecision {
  const ConflictDecision.keep() : action = keepAction, to = null;
  const ConflictDecision.cancel() : action = cancelAction, to = null;
  const ConflictDecision.move(MovePlace this.to) : action = moveAction;

  static const keepAction = 'keep';
  static const moveAction = 'move';
  static const cancelAction = 'cancel';

  final String action;
  final MovePlace? to;

  Json toJson(String appointmentId) => {
        'appointmentId': appointmentId,
        'action': action,
        if (to != null) ...{'branchId': to!.branchId, 'date': dayKey(to!.date), 'time': to!.time},
      };

  @override
  bool operator ==(Object other) => other is ConflictDecision && other.action == action && other.to == to;

  @override
  int get hashCode => Object.hash(action, to);
}
