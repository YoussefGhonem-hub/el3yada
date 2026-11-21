import '../../patient/domain/patient_models.dart' show Json;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

/// An account's deletion in progress (spec 6.17), in AD11's search results.
class SupportDeletion {
  const SupportDeletion({required this.id, required this.status, required this.scheduledFor});

  factory SupportDeletion.fromJson(Json json) => SupportDeletion(
        id: json['id'] as String,
        status: json['status'] as String,
        scheduledFor: _date(json['scheduledFor'])!,
      );

  final String id;

  /// scheduled or waitingPayment.
  final String status;
  final DateTime scheduledFor;

  static SupportDeletion? fromJsonOrNull(Object? json) => json == null ? null : SupportDeletion.fromJson(json as Json);
}

class LinkedDoctor {
  const LinkedDoctor({required this.doctorId, required this.fullName});

  final String doctorId;
  final String fullName;

  factory LinkedDoctor.fromJson(Json json) =>
      LinkedDoctor(doctorId: json['doctorId'] as String, fullName: json['fullName'] as String);
}

class SupportPatient {
  const SupportPatient({
    required this.userId,
    required this.patientId,
    required this.fullName,
    required this.phone,
    required this.loginStatus,
    required this.patientStatus,
    required this.createdAt,
    this.doctors = const [],
    this.deletion,
  });

  final String userId;
  final String patientId;
  final String fullName;
  final String phone;

  /// Users.Status: active, disabled, pendingDeletion or deleted.
  final String loginStatus;

  /// The deletion in progress, if any.
  final SupportDeletion? deletion;

  /// Patients.Status: active, disabled or deleted.
  final String patientStatus;
  final DateTime createdAt;
  final List<LinkedDoctor> doctors;

  factory SupportPatient.fromJson(Json json) => SupportPatient(
        userId: json['userId'] as String,
        patientId: json['patientId'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        loginStatus: json['loginStatus'] as String,
        patientStatus: json['patientStatus'] as String,
        createdAt: _date(json['createdAt'])!,
        doctors: [for (final d in json['doctors'] as List) LinkedDoctor.fromJson(d as Json)],
        deletion: SupportDeletion.fromJsonOrNull(json['deletion']),
      );
}

class SupportAssistant {
  const SupportAssistant({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.loginStatus,
    required this.assistantStatus,
    required this.doctorId,
    required this.doctorName,
    required this.preset,
    this.lastActiveAt,
    this.deletion,
  });

  final String userId;
  final String fullName;
  final String phone;
  final String loginStatus;

  /// active, disabled or removed.
  final String assistantStatus;
  final String doctorId;
  final String doctorName;
  final String preset;
  final DateTime? lastActiveAt;

  /// The deletion in progress, if any.
  final SupportDeletion? deletion;

  factory SupportAssistant.fromJson(Json json) => SupportAssistant(
        userId: json['userId'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        loginStatus: json['loginStatus'] as String,
        assistantStatus: json['assistantStatus'] as String,
        doctorId: json['doctorId'] as String,
        doctorName: json['doctorName'] as String,
        preset: json['preset'] as String,
        lastActiveAt: _date(json['lastActiveAt']),
        deletion: SupportDeletion.fromJsonOrNull(json['deletion']),
      );
}

class AccountSearchResult {
  const AccountSearchResult({required this.phone, this.patients = const [], this.assistants = const []});

  final String phone;
  final List<SupportPatient> patients;
  final List<SupportAssistant> assistants;

  bool get isEmpty => patients.isEmpty && assistants.isEmpty;

  factory AccountSearchResult.fromJson(Json json) => AccountSearchResult(
        phone: json['phone'] as String,
        patients: [for (final p in json['patients'] as List) SupportPatient.fromJson(p as Json)],
        assistants: [for (final a in json['assistants'] as List) SupportAssistant.fromJson(a as Json)],
      );
}
