import '../../patient/domain/patient_models.dart' show Json;

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

/// AD12 row. Patient name and phone only: no medical data.
class AdminDeletionRequest {
  const AdminDeletionRequest({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientPhone,
    this.reason,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedByName,
    this.reviewNote,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientPhone;
  final String? reason;

  /// pending, approved or rejected.
  final String status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedByName;
  final String? reviewNote;

  bool get isPending => status == 'pending';

  AdminDeletionRequest reviewed(String newStatus, String? note, DateTime at) => AdminDeletionRequest(
        id: id, patientId: patientId, patientName: patientName, patientPhone: patientPhone, reason: reason,
        status: newStatus, createdAt: createdAt, reviewedAt: at, reviewNote: note,
      );

  factory AdminDeletionRequest.fromJson(Json json) => AdminDeletionRequest(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        patientName: json['patientName'] as String,
        patientPhone: json['patientPhone'] as String,
        reason: json['reason'] as String?,
        status: json['status'] as String,
        createdAt: _date(json['createdAt'])!,
        reviewedAt: _date(json['reviewedAt']),
        reviewedByName: json['reviewedByName'] as String?,
        reviewNote: json['reviewNote'] as String?,
      );
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
  });

  final String userId;
  final String patientId;
  final String fullName;
  final String phone;

  /// Users.Status: active or disabled.
  final String loginStatus;

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
