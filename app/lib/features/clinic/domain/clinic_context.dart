import '../../auth/domain/user_role.dart';
import 'clinic_permissions.dart';

/// `GET /api/clinic/me` (backend/docs/api-phase-2.md): who is working in the
/// clinic and what they may do. Read after sign-in, on resume and after a
/// `PERMISSION_DENIED`; the server checks every request whatever the app
/// shows, so this only decides what to show.
class ClinicContext {
  const ClinicContext({
    required this.role,
    required this.doctor,
    required this.assistant,
    required this.permissions,
    required this.branches,
    required this.defaultBranchId,
    required this.fees,
    required this.limits,
  });

  factory ClinicContext.fromJson(Map<String, dynamic> json) {
    final permissions = (json['permissions'] as Map).cast<String, dynamic>();
    return ClinicContext(
      role: json['role'] == 'assistant' ? UserRole.assistant : UserRole.doctor,
      doctor: ClinicDoctor.fromJson(_map(json['doctor'])),
      assistant: json['assistant'] == null ? null : ClinicAssistant.fromJson(_map(json['assistant'])),
      permissions: {for (final MapEntry(:key, :value) in permissions.entries) if (value == true) key},
      branches: [for (final row in json['branches'] as List) ClinicBranch.fromJson(_map(row))],
      defaultBranchId: json['defaultBranchId'] as String?,
      fees: ClinicFees.fromJson(_map(json['fees'])),
      limits: ClinicLimits.fromJson(_map(json['limits'])),
    );
  }

  final UserRole role;
  final ClinicDoctor doctor;

  /// Null for the doctor.
  final ClinicAssistant? assistant;

  /// The keys that are on (spec 6.10). Every key for the doctor.
  final Set<String> permissions;

  /// Every branch of the doctor, default first (see [ClinicBranch.assigned]).
  final List<ClinicBranch> branches;
  final String? defaultBranchId;
  final ClinicFees fees;
  final ClinicLimits limits;

  bool get isDoctor => role == UserRole.doctor;

  /// The doctor is suspended for an overdue invoice: show the banner, and
  /// hide or refuse what BR-G5 blocks.
  bool get isSuspended => doctor.status == 'suspended';

  /// Whether the caller may do what [permission] allows. Always true for the doctor.
  bool can(String permission) => isDoctor || permissions.contains(permission);

  /// The branches the caller works in and may pick as the current branch
  /// (BR-BR3, BR-AS13): assigned and not archived.
  List<ClinicBranch> get workBranches => [for (final b in branches) if (b.assigned && !b.archived) b];

  ClinicBranch? branch(String? id) {
    for (final b in branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// "Pay now" on the suspension banner (BR-G8).
  bool get canPay => can(ClinicPermission.billingPay);
}

class ClinicDoctor {
  const ClinicDoctor({
    required this.id,
    required this.fullName,
    required this.fullNameEn,
    required this.title,
    required this.titleEn,
    required this.specialtyId,
    required this.specialtyNameAr,
    required this.specialtyNameEn,
    required this.status,
  });

  factory ClinicDoctor.fromJson(Map<String, dynamic> json) => ClinicDoctor(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        fullNameEn: json['fullNameEn'] as String?,
        title: json['title'] as String,
        titleEn: json['titleEn'] as String?,
        specialtyId: json['specialtyId'] as String,
        specialtyNameAr: json['specialtyNameAr'] as String,
        specialtyNameEn: json['specialtyNameEn'] as String,
        status: json['status'] as String,
      );

  final String id;
  final String fullName;
  final String? fullNameEn;
  final String title;
  final String? titleEn;
  final String specialtyId;
  final String specialtyNameAr;
  final String specialtyNameEn;

  /// `active` or `suspended`.
  final String status;

  /// The name in [languageCode], falling back to Arabic.
  String name(String languageCode) => languageCode == 'en' && fullNameEn != null ? fullNameEn! : fullName;
}

class ClinicAssistant {
  const ClinicAssistant({
    required this.userId,
    required this.fullName,
    required this.preset,
    required this.allBranches,
    required this.branchIds,
  });

  factory ClinicAssistant.fromJson(Map<String, dynamic> json) => ClinicAssistant(
        userId: json['userId'] as String,
        fullName: json['fullName'] as String,
        preset: json['preset'] as String,
        allBranches: json['allBranches'] as bool,
        branchIds: [for (final id in json['branchIds'] as List) id as String],
      );

  final String userId;
  final String fullName;
  final String preset;
  final bool allBranches;
  final List<String> branchIds;
}

class ClinicBranch {
  const ClinicBranch({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.isDefault,
    required this.status,
    required this.governorate,
    required this.city,
    required this.assigned,
  });

  factory ClinicBranch.fromJson(Map<String, dynamic> json) => ClinicBranch(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String?,
        isDefault: json['isDefault'] as bool,
        status: json['status'] as String,
        governorate: json['governorate'] as String,
        city: json['city'] as String,
        assigned: json['assigned'] as bool,
      );

  final String id;
  final String nameAr;
  final String? nameEn;
  final bool isDefault;

  /// `active`, `temporarilyClosed` or `archived`.
  final String status;
  final String governorate;
  final String city;

  /// The caller works in this branch (always true for the doctor).
  final bool assigned;

  bool get archived => status == 'archived';

  String name(String languageCode) => languageCode == 'en' && nameEn != null && nameEn!.isNotEmpty ? nameEn! : nameAr;
}

/// Platform fees per session (BR-S5) and the consultation limit (BR-S3).
/// Not the clinic's visit prices (section 6.15).
class ClinicFees {
  const ClinicFees({
    required this.examinationFeePiasters,
    required this.consultationFeePiasters,
    required this.maxConsecutiveConsultations,
  });

  factory ClinicFees.fromJson(Map<String, dynamic> json) => ClinicFees(
        examinationFeePiasters: json['examinationFeePiasters'] as int,
        consultationFeePiasters: json['consultationFeePiasters'] as int,
        maxConsecutiveConsultations: json['maxConsecutiveConsultations'] as int,
      );

  final int examinationFeePiasters;
  final int consultationFeePiasters;
  final int maxConsecutiveConsultations;
}

class ClinicLimits {
  const ClinicLimits({required this.maxAssistants, required this.maxBranches, required this.maxUploadMb});

  factory ClinicLimits.fromJson(Map<String, dynamic> json) => ClinicLimits(
        maxAssistants: json['maxAssistants'] as int,
        maxBranches: json['maxBranches'] as int,
        maxUploadMb: json['maxUploadMb'] as int,
      );

  final int maxAssistants;
  final int maxBranches;
  final int maxUploadMb;
}

Map<String, dynamic> _map(Object? value) => (value as Map).cast<String, dynamic>();
