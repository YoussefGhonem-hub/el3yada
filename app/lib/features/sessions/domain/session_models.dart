
export '../../../core/data/paged.dart';

/// Models for sessions and the platform-fee screens (D1–D3, D8, D9, AS1,
/// AS5). The contract is backend/docs/api-phase-2-patients.md; the API's
/// `Sessions/SessionViews.cs` is the source of truth.
///
/// Plain classes with hand-written `fromJson`, like the admin models. A
/// field the caller may not see arrives as `null` ("hidden", never "none"),
/// and the screens hide it (spec 7.6).

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();
DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);
Map<String, dynamic> _map(Object? value) => (value as Map).cast<String, dynamic>();
String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;
double? _double(Object? value) => value is num ? value.toDouble() : null;
int? _int(Object? value) => value is num ? value.toInt() : null;

/// A Cairo calendar day (`YYYY-MM-DD`), kept as UTC midnight so it never
/// moves with the device's time zone (AC-4).
DateTime parseDay(Object? value) {
  final parts = (value! as String).split('-');
  return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

DateTime? parseDayOrNull(Object? value) => value == null ? null : parseDay(value);

/// `YYYY-MM-DD` for the API.
String dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// `YYYY-MM` for the API.
String monthKey(DateTime month) => '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

/// The first day of a `YYYY-MM` month, as UTC midnight.
DateTime parseMonth(String value) {
  final parts = value.split('-');
  return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]));
}

/// BR-S1: كشف or استشارة.
enum SessionType {
  examination,
  consultation;

  static SessionType fromWire(Object? value) => value == 'consultation' ? consultation : examination;

  String get wire => name;
}

/// BR-S10 [S]: how the patient paid the clinic.
enum PaymentMethod {
  cash,
  card,
  instapay,
  wallet;

  static PaymentMethod? fromWire(Object? value) {
    for (final method in values) {
      if (method.name == value) return method;
    }
    return null;
  }

  String get wire => name;
}

/// `{ id, nameAr, nameEn }` of a session's branch.
class SessionBranch {
  const SessionBranch({required this.id, required this.nameAr, this.nameEn});

  factory SessionBranch.fromJson(Map<String, dynamic> json) =>
      SessionBranch(id: json['id'] as String, nameAr: json['nameAr'] as String, nameEn: _text(json['nameEn']));

  final String id;
  final String nameAr;
  final String? nameEn;

  String name(String languageCode) => languageCode == 'en' && nameEn != null ? nameEn! : nameAr;
}

/// Who saved a session (BR-AS6: the doctor sees "Recorded by" and the name).
class RecordedBy {
  const RecordedBy({required this.userId, required this.name, required this.isAssistant});

  factory RecordedBy.fromJson(Map<String, dynamic> json) => RecordedBy(
        userId: json['userId'] as String,
        name: json['name'] as String,
        isAssistant: json['role'] == 'assistant',
      );

  final String userId;
  final String name;
  final bool isAssistant;

  Map<String, Object?> toJson() => {'userId': userId, 'name': name, 'role': isAssistant ? 'assistant' : 'doctor'};
}

/// Vitals (spec 6.2). Every value is optional. Blood pressure goes in pairs.
class Vitals {
  const Vitals({this.bpSys, this.bpDia, this.pulse, this.tempC, this.weightKg, this.heightCm, this.glucose});

  factory Vitals.fromJson(Map<String, dynamic>? json) => json == null
      ? const Vitals()
      : Vitals(
          bpSys: _int(json['bpSys']),
          bpDia: _int(json['bpDia']),
          pulse: _int(json['pulse']),
          tempC: _double(json['tempC']),
          weightKg: _double(json['weightKg']),
          heightCm: _double(json['heightCm']),
          glucose: _int(json['glucose']),
        );

  final int? bpSys;
  final int? bpDia;
  final int? pulse;
  final double? tempC;
  final double? weightKg;
  final double? heightCm;

  /// mg/dL.
  final int? glucose;

  bool get isEmpty =>
      bpSys == null && bpDia == null && pulse == null && tempC == null && weightKg == null && heightCm == null && glucose == null;

  Map<String, Object?> toJson() => {
        'bpSys': ?bpSys,
        'bpDia': ?bpDia,
        'pulse': ?pulse,
        'tempC': ?tempC,
        'weightKg': ?weightKg,
        'heightCm': ?heightCm,
        'glucose': ?glucose,
      };
}

/// The clinical block of a session (`clinicalView`). Any field can be null.
class SessionClinical {
  const SessionClinical({
    this.chiefComplaint,
    this.findings,
    this.vitals = const Vitals(),
    this.diagnosis,
    this.patientNotes,
    this.followUpDate,
  });

  factory SessionClinical.fromJson(Map<String, dynamic> json) => SessionClinical(
        chiefComplaint: _text(json['chiefComplaint']),
        findings: _text(json['findings']),
        vitals: Vitals.fromJson(json['vitals'] == null ? null : _map(json['vitals'])),
        diagnosis: _text(json['diagnosis']),
        patientNotes: _text(json['patientNotes']),
        followUpDate: parseDayOrNull(json['followUpDate']),
      );

  final String? chiefComplaint;
  final String? findings;
  final Vitals vitals;
  final String? diagnosis;
  final String? patientNotes;
  final DateTime? followUpDate;

  bool get isEmpty =>
      chiefComplaint == null &&
      findings == null &&
      vitals.isEmpty &&
      diagnosis == null &&
      patientNotes == null &&
      followUpDate == null;
}

/// Why BR-S7 refuses a delete.
enum DeleteBlock {
  notLatest,
  notSameDay;

  static DeleteBlock? fromWire(Object? value) => switch (value) {
        'notLatest' => notLatest,
        'notSameDay' => notSameDay,
        _ => null,
      };
}

/// What D9 may offer now (the session view's `can`).
class SessionActions {
  const SessionActions({
    this.editClinical = false,
    this.editAmount = false,
    this.delete = false,
    this.deleteBlockedReason,
    this.privateNote = false,
  });

  factory SessionActions.fromJson(Map<String, dynamic> json) => SessionActions(
        editClinical: json['editClinical'] as bool? ?? false,
        editAmount: json['editAmount'] as bool? ?? false,
        delete: json['delete'] as bool? ?? false,
        deleteBlockedReason: DeleteBlock.fromWire(json['deleteBlockedReason']),
        privateNote: json['privateNote'] as bool? ?? false,
      );

  final bool editClinical;
  final bool editAmount;
  final bool delete;
  final DeleteBlock? deleteBlockedReason;
  final bool privateNote;
}

/// D9 (`GET /api/sessions/{sessionId}`), also the answer of every session write.
class SessionView {
  const SessionView({
    required this.sessionId,
    required this.patientId,
    required this.fileNumber,
    required this.patientName,
    required this.type,
    required this.at,
    required this.day,
    required this.branch,
    required this.platformFeePiasters,
    required this.recordedBy,
    required this.can,
    required this.updatedAt,
    this.amountChargedPiasters,
    this.listPricePiasters,
    this.paymentMethod,
    this.awaitingDoctor = false,
    this.clinical,
    this.hasPrivateNote,
  });

  factory SessionView.fromJson(Map<String, dynamic> json) => SessionView(
        sessionId: json['sessionId'] as String,
        patientId: json['patientId'] as String,
        fileNumber: json['fileNumber'] as int,
        patientName: json['patientName'] as String,
        type: SessionType.fromWire(json['type']),
        at: _time(json['at']),
        day: parseDay(json['day']),
        branch: SessionBranch.fromJson(_map(json['branch'])),
        platformFeePiasters: json['platformFeePiasters'] as int,
        amountChargedPiasters: _int(json['amountChargedPiasters']),
        listPricePiasters: _int(json['listPricePiasters']),
        paymentMethod: PaymentMethod.fromWire(json['paymentMethod']),
        recordedBy: RecordedBy.fromJson(_map(json['recordedBy'])),
        awaitingDoctor: json['awaitingDoctor'] as bool? ?? false,
        clinical: json['clinical'] == null ? null : SessionClinical.fromJson(_map(json['clinical'])),
        hasPrivateNote: json['hasPrivateNote'] as bool?,
        can: SessionActions.fromJson(_map(json['can'])),
        updatedAt: _timeOrNull(json['updatedAt']) ?? _time(json['at']),
      );

  final String sessionId;
  final String patientId;
  final int fileNumber;
  final String patientName;

  /// Locked after saving (BR-S6), like [at].
  final SessionType type;

  /// The server time of the save (BR-S9), UTC.
  final DateTime at;

  /// [at]'s Cairo date.
  final DateTime day;
  final SessionBranch branch;

  /// The fee snapshot (BR-S5): what the platform bills the doctor.
  final int platformFeePiasters;

  /// What the patient paid (BR-S10); null when hidden (`revenueView`, or not the recorder).
  final int? amountChargedPiasters;
  final int? listPricePiasters;
  final PaymentMethod? paymentMethod;
  final RecordedBy recordedBy;

  /// «بانتظار الطبيب» (BR-AS7).
  final bool awaitingDoctor;

  /// Null without `clinicalView`.
  final SessionClinical? clinical;

  /// The doctor only; null for everyone else.
  final bool? hasPrivateNote;
  final SessionActions can;
  final DateTime updatedAt;
}

/// A row of the D6 Sessions tab and of D2 (`day`).
class SessionListItem {
  const SessionListItem({
    required this.sessionId,
    required this.at,
    required this.day,
    required this.type,
    required this.patientId,
    required this.fileNumber,
    required this.patientName,
    required this.branch,
    required this.platformFeePiasters,
    required this.recordedBy,
    this.amountChargedPiasters,
    this.paymentMethod,
    this.awaitingDoctor = false,
    this.chiefComplaint,
    this.diagnosis,
  });

  factory SessionListItem.fromJson(Map<String, dynamic> json) => SessionListItem(
        sessionId: json['sessionId'] as String,
        at: _time(json['at']),
        day: parseDay(json['day']),
        type: SessionType.fromWire(json['type']),
        patientId: json['patientId'] as String,
        fileNumber: json['fileNumber'] as int,
        patientName: json['patientName'] as String,
        branch: SessionBranch.fromJson(_map(json['branch'])),
        platformFeePiasters: json['platformFeePiasters'] as int,
        amountChargedPiasters: _int(json['amountChargedPiasters']),
        paymentMethod: PaymentMethod.fromWire(json['paymentMethod']),
        recordedBy: RecordedBy.fromJson(_map(json['recordedBy'])),
        awaitingDoctor: json['awaitingDoctor'] as bool? ?? false,
        chiefComplaint: _text(json['chiefComplaint']),
        diagnosis: _text(json['diagnosis']),
      );

  final String sessionId;
  final DateTime at;
  final DateTime day;
  final SessionType type;
  final String patientId;
  final int fileNumber;
  final String patientName;
  final SessionBranch branch;
  final int platformFeePiasters;

  /// `revenueView` or the recorder only; null otherwise.
  final int? amountChargedPiasters;
  final PaymentMethod? paymentMethod;
  final RecordedBy recordedBy;
  final bool awaitingDoctor;

  /// `clinicalView` only.
  final String? chiefComplaint;
  final String? diagnosis;
}

/// One type card of D8: allowed now, its platform fee, its visit price.
class TypeOption {
  const TypeOption({required this.allowed, required this.platformFeePiasters, this.visitPricePiasters, this.priceSource});

  factory TypeOption.fromJson(Map<String, dynamic> json) => TypeOption(
        allowed: json['allowed'] as bool,
        platformFeePiasters: json['platformFeePiasters'] as int,
        visitPricePiasters: _int(json['visitPricePiasters']),
        priceSource: json['priceSource'] as String?,
      );

  final bool allowed;

  /// For the BR-S6 confirmation.
  final int platformFeePiasters;

  /// The default amount charged (BR-S10, BR-PR3); null when no price is set.
  final int? visitPricePiasters;

  /// `branch` or `doctor`.
  final String? priceSource;
}

/// Why the Consultation card is closed (BR-S2, BR-S3).
enum ConsultationBlock {
  firstVisit,
  limitReached;

  static ConsultationBlock? fromWire(Object? value) => switch (value) {
        'firstVisit' => firstVisit,
        'limitReached' => limitReached,
        _ => null,
      };
}

/// The patient's latest session with this doctor (`lastSession`, `lastVisit`).
class LastVisit {
  const LastVisit({
    required this.sessionId,
    required this.at,
    required this.day,
    required this.daysAgo,
    required this.type,
    required this.branchId,
    required this.branchNameAr,
    this.branchNameEn,
  });

  factory LastVisit.fromJson(Map<String, dynamic> json) => LastVisit(
        sessionId: json['sessionId'] as String,
        at: _time(json['at']),
        day: parseDay(json['day']),
        daysAgo: json['daysAgo'] as int,
        type: SessionType.fromWire(json['type']),
        branchId: json['branchId'] as String,
        branchNameAr: json['branchNameAr'] as String,
        branchNameEn: _text(json['branchNameEn']),
      );

  final String sessionId;
  final DateTime at;
  final DateTime day;

  /// Cairo days since (0 = today), for "x days ago".
  final int daysAgo;
  final SessionType type;
  final String branchId;
  final String branchNameAr;
  final String? branchNameEn;

  String branchName(String languageCode) => languageCode == 'en' && branchNameEn != null ? branchNameEn! : branchNameAr;
}

/// D8 step 1 (`GET /api/sessions/newSessionInfo`).
class NewSessionInfo {
  const NewSessionInfo({
    required this.patientId,
    required this.branchId,
    required this.isFirstVisit,
    required this.consultationsSinceExam,
    required this.maxConsecutiveConsultations,
    required this.consultationAllowed,
    required this.examination,
    required this.consultation,
    this.lastSession,
    this.consultationBlockedReason,
  });

  factory NewSessionInfo.fromJson(Map<String, dynamic> json) => NewSessionInfo(
        patientId: json['patientId'] as String,
        branchId: json['branchId'] as String,
        isFirstVisit: json['isFirstVisit'] as bool,
        lastSession: json['lastSession'] == null ? null : LastVisit.fromJson(_map(json['lastSession'])),
        consultationsSinceExam: json['consultationsSinceExam'] as int,
        maxConsecutiveConsultations: json['maxConsecutiveConsultations'] as int,
        consultationAllowed: json['consultationAllowed'] as bool,
        consultationBlockedReason: ConsultationBlock.fromWire(json['consultationBlockedReason']),
        examination: TypeOption.fromJson(_map(json['examination'])),
        consultation: TypeOption.fromJson(_map(json['consultation'])),
      );

  final String patientId;
  final String branchId;
  final bool isFirstVisit;
  final LastVisit? lastSession;
  final int consultationsSinceExam;
  final int maxConsecutiveConsultations;
  final bool consultationAllowed;
  final ConsultationBlock? consultationBlockedReason;
  final TypeOption examination;
  final TypeOption consultation;

  TypeOption option(SessionType type) => type == SessionType.examination ? examination : consultation;
}

/// The doctor's private note on a session (doctor only).
class PrivateNote {
  const PrivateNote({required this.sessionId, this.text, this.updatedAt});

  factory PrivateNote.fromJson(Map<String, dynamic> json) => PrivateNote(
        sessionId: json['sessionId'] as String,
        text: _text(json['text']),
        updatedAt: _timeOrNull(json['updatedAt']),
      );

  final String sessionId;
  final String? text;
  final DateTime? updatedAt;
}

/// Counts and fee sums (spec 6.5). «2 كشف + 3 استشارة = 105 ج.م».
class FeeTotals {
  const FeeTotals({
    this.examinationCount = 0,
    this.consultationCount = 0,
    this.examinationFeePiasters = 0,
    this.consultationFeePiasters = 0,
    this.totalPiasters = 0,
  });

  factory FeeTotals.fromJson(Map<String, dynamic> json) => FeeTotals(
        examinationCount: json['examinationCount'] as int,
        consultationCount: json['consultationCount'] as int,
        examinationFeePiasters: json['examinationFeePiasters'] as int,
        consultationFeePiasters: json['consultationFeePiasters'] as int,
        totalPiasters: json['totalPiasters'] as int,
      );

  static const zero = FeeTotals();

  final int examinationCount;
  final int consultationCount;
  final int examinationFeePiasters;
  final int consultationFeePiasters;
  final int totalPiasters;

  int get sessionCount => examinationCount + consultationCount;

  FeeTotals add(SessionType type, int feePiasters) => type == SessionType.examination
      ? FeeTotals(
          examinationCount: examinationCount + 1,
          consultationCount: consultationCount,
          examinationFeePiasters: examinationFeePiasters + feePiasters,
          consultationFeePiasters: consultationFeePiasters,
          totalPiasters: totalPiasters + feePiasters,
        )
      : FeeTotals(
          examinationCount: examinationCount,
          consultationCount: consultationCount + 1,
          examinationFeePiasters: examinationFeePiasters,
          consultationFeePiasters: consultationFeePiasters + feePiasters,
          totalPiasters: totalPiasters + feePiasters,
        );

  Map<String, Object?> toJson() => {
        'examinationCount': examinationCount,
        'consultationCount': consultationCount,
        'examinationFeePiasters': examinationFeePiasters,
        'consultationFeePiasters': consultationFeePiasters,
        'totalPiasters': totalPiasters,
      };
}

/// D2 and AS1 (`GET /api/sessions/day`): one Cairo day, newest first.
class DaySessions {
  const DaySessions({required this.day, required this.items, required this.totals, this.amountChargedTotalPiasters});

  factory DaySessions.fromJson(Map<String, dynamic> json) => DaySessions(
        day: parseDay(json['day']),
        items: [for (final row in json['items'] as List) SessionListItem.fromJson(_map(row))],
        totals: FeeTotals.fromJson(_map(json['totals'])),
        amountChargedTotalPiasters: _int(json['amountChargedTotalPiasters']),
      );

  final DateTime day;
  final List<SessionListItem> items;

  /// For exactly [items].
  final FeeTotals totals;

  /// `revenueView` only.
  final int? amountChargedTotalPiasters;
}

/// D1 fee cards (`GET /api/sessions/feeSummary`).
class FeeSummary {
  const FeeSummary({required this.day, required this.month, required this.today, required this.thisMonth});

  factory FeeSummary.fromJson(Map<String, dynamic> json) => FeeSummary(
        day: parseDay(json['day']),
        month: parseMonth(json['month'] as String),
        today: FeeTotals.fromJson(_map(json['today'])),
        thisMonth: FeeTotals.fromJson(_map(json['thisMonth'])),
      );

  final DateTime day;
  final DateTime month;
  final FeeTotals today;
  final FeeTotals thisMonth;
}

/// One branch's totals in D3 (BR-BR7).
class BranchFees {
  const BranchFees({required this.branchId, required this.nameAr, required this.totals, this.nameEn});

  factory BranchFees.fromJson(Map<String, dynamic> json) => BranchFees(
        branchId: json['branchId'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: _text(json['nameEn']),
        totals: FeeTotals.fromJson(_map(json['totals'])),
      );

  final String branchId;
  final String nameAr;
  final String? nameEn;
  final FeeTotals totals;

  String name(String languageCode) => languageCode == 'en' && nameEn != null ? nameEn! : nameAr;
}

class DayFees {
  const DayFees({required this.day, required this.totals});

  factory DayFees.fromJson(Map<String, dynamic> json) =>
      DayFees(day: parseDay(json['day']), totals: FeeTotals.fromJson(_map(json['totals'])));

  final DateTime day;
  final FeeTotals totals;
}

/// D3 (`GET /api/sessions/month`).
class MonthFees {
  const MonthFees({required this.month, required this.totals, required this.branches, required this.days, this.branchId});

  factory MonthFees.fromJson(Map<String, dynamic> json) => MonthFees(
        month: parseMonth(json['month'] as String),
        branchId: json['branchId'] as String?,
        totals: FeeTotals.fromJson(_map(json['totals'])),
        branches: [for (final row in json['branches'] as List) BranchFees.fromJson(_map(row))],
        days: [for (final row in json['days'] as List) DayFees.fromJson(_map(row))],
      );

  final DateTime month;
  final String? branchId;
  final FeeTotals totals;
  final List<BranchFees> branches;

  /// One row per day, zeros included, oldest first.
  final List<DayFees> days;
}

/// `createSession`'s body. Assistants send only [type], [chiefComplaint],
/// [vitals], [amountChargedPiasters] and [paymentMethod] (BR-AS5).
class NewSessionDraft {
  const NewSessionDraft({
    required this.patientId,
    required this.branchId,
    required this.type,
    this.chiefComplaint,
    this.vitals = const Vitals(),
    this.findings,
    this.diagnosis,
    this.patientNotes,
    this.privateNote,
    this.followUpDate,
    this.amountChargedPiasters,
    this.paymentMethod,
    this.appointmentId,
  });

  final String patientId;
  final String branchId;
  final SessionType type;
  final String? chiefComplaint;
  final Vitals vitals;
  final String? findings;
  final String? diagnosis;
  final String? patientNotes;
  final String? privateNote;
  final DateTime? followUpDate;
  final int? amountChargedPiasters;
  final PaymentMethod? paymentMethod;

  /// The checked-in booking this session completes (BR-AP10), when opened from the live board.
  final String? appointmentId;

  Map<String, Object?> toJson() => {
        'patientId': patientId,
        'branchId': branchId,
        'type': type.wire,
        'appointmentId': ?appointmentId,
        'chiefComplaint': ?_blankToNull(chiefComplaint),
        if (!vitals.isEmpty) 'vitals': vitals.toJson(),
        'findings': ?_blankToNull(findings),
        'diagnosis': ?_blankToNull(diagnosis),
        'patientNotes': ?_blankToNull(patientNotes),
        'privateNote': ?_blankToNull(privateNote),
        if (followUpDate != null) 'followUpDate': dayKey(followUpDate!),
        'amountChargedPiasters': ?amountChargedPiasters,
        'paymentMethod': ?paymentMethod?.wire,
      };
}

/// `updateClinical`'s body: the whole clinical form (a field left out is cleared).
class ClinicalDraft {
  const ClinicalDraft({
    this.chiefComplaint,
    this.findings,
    this.vitals = const Vitals(),
    this.diagnosis,
    this.patientNotes,
    this.followUpDate,
  });

  final String? chiefComplaint;
  final String? findings;
  final Vitals vitals;
  final String? diagnosis;
  final String? patientNotes;
  final DateTime? followUpDate;

  bool get isEmpty =>
      _blankToNull(chiefComplaint) == null &&
      _blankToNull(findings) == null &&
      vitals.isEmpty &&
      _blankToNull(diagnosis) == null &&
      _blankToNull(patientNotes) == null &&
      followUpDate == null;

  Map<String, Object?> toJson(String sessionId) => {
        'sessionId': sessionId,
        'chiefComplaint': _blankToNull(chiefComplaint),
        'findings': _blankToNull(findings),
        'vitals': vitals.toJson(),
        'diagnosis': _blankToNull(diagnosis),
        'patientNotes': _blankToNull(patientNotes),
        'followUpDate': followUpDate == null ? null : dayKey(followUpDate!),
      };
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}
