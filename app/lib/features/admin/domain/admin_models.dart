import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

import '../../auth/domain/auth_session.dart' show TrialInfo;

export '../../../core/data/paged.dart';
export '../../auth/domain/auth_session.dart' show TrialInfo;

/// Models for the Phase 1 admin endpoints (AD2, AD3, AD13–AD15, AD18).
/// The contract is backend/docs/api-phase-1.md, section "Admin"; the
/// controllers in backend/src/El3yada.Api/Controllers are the source of truth.
///
/// Plain classes with hand-written `fromJson`, like `PublicSettings`: the
/// screens only read them.

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();
DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);
String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;
Map<String, dynamic> _map(Object? value) => (value as Map).cast<String, dynamic>();
TrialInfo? _trial(Object? value) => value == null ? null : TrialInfo.fromJson(_map(value));

/// `{ id, nameAr, nameEn }`.
class SpecialtyRef {
  const SpecialtyRef({required this.id, required this.nameAr, required this.nameEn});

  factory SpecialtyRef.fromJson(Map<String, dynamic> json) =>
      SpecialtyRef(id: json['id'] as String, nameAr: json['nameAr'] as String, nameEn: json['nameEn'] as String);

  final String id;
  final String nameAr;
  final String nameEn;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}

/// A row of AD2 (`GET /api/admin/doctorRegistrations`).
class RegistrationSummary {
  const RegistrationSummary({
    required this.doctorId,
    required this.fullName,
    required this.title,
    required this.specialty,
    required this.status,
    required this.submittedAt,
    required this.createdAt,
    this.governorate,
    this.city,
    this.emailVerified = true,
    this.trial,
  });

  factory RegistrationSummary.fromJson(Map<String, dynamic> json) => RegistrationSummary(
        doctorId: json['doctorId'] as String,
        fullName: json['fullName'] as String,
        title: json['title'] as String? ?? '',
        specialty: SpecialtyRef.fromJson(_map(json['specialty'])),
        governorate: _text(json['governorate']),
        city: _text(json['city']),
        status: json['status'] as String,
        submittedAt: _time(json['submittedAt']),
        createdAt: _time(json['createdAt']),
        emailVerified: json['emailVerified'] as bool? ?? true,
        trial: _trial(json['trial']),
      );

  final String doctorId;
  final String fullName;
  final String title;
  final SpecialtyRef specialty;
  final String? governorate;
  final String? city;
  final String status;

  /// The free trial of an approved doctor (spec 6.16); null when none.
  final TrialInfo? trial;

  /// The latest submission: the first one, or the last resubmission.
  final DateTime submittedAt;
  final DateTime createdAt;
  final bool emailVerified;
}

/// `Doctors.Status` values the admin screens show.
abstract final class DoctorStatuses {
  static const pendingApproval = 'pendingApproval';
  static const active = 'active';
  static const rejected = 'rejected';
  static const suspended = 'suspended';
  static const disabled = 'disabled';
}

class BranchPhone {
  const BranchPhone({required this.number, required this.label, this.isWhatsapp = false});

  factory BranchPhone.fromJson(Map<String, dynamic> json) => BranchPhone(
        number: json['number'] as String,
        label: json['label'] as String? ?? 'reception',
        isWhatsapp: json['isWhatsapp'] as bool? ?? false,
      );

  /// E.164, or a hotline as typed.
  final String number;

  /// `reception`, `mobile` or `landline`.
  final String label;
  final bool isWhatsapp;
}

/// The first branch, as submitted in A4 step 3.
class RegistrationBranch {
  const RegistrationBranch({
    required this.nameAr,
    required this.governorate,
    required this.city,
    required this.addressDetails,
    this.nameEn,
    this.area,
    this.landmark,
    this.mapUrl,
    this.email,
    this.phones = const [],
  });

  factory RegistrationBranch.fromJson(Map<String, dynamic> json) => RegistrationBranch(
        nameAr: json['nameAr'] as String,
        nameEn: _text(json['nameEn']),
        governorate: json['governorate'] as String,
        city: json['city'] as String,
        area: _text(json['area']),
        addressDetails: json['addressDetails'] as String? ?? '',
        landmark: _text(json['landmark']),
        mapUrl: _text(json['mapUrl']),
        email: _text(json['email']),
        phones: [for (final phone in json['phones'] as List? ?? const []) BranchPhone.fromJson(_map(phone))],
      );

  final String nameAr;
  final String? nameEn;
  final String governorate;
  final String city;
  final String? area;

  /// «العنوان بالتفصيل»: street, building, floor and apartment in one text.
  final String addressDetails;
  final String? landmark;

  /// «لينك جوجل ماب», or null.
  final String? mapUrl;
  final String? email;
  final List<BranchPhone> phones;
}

/// The registration view: everything the doctor submitted in A4.
class DoctorRegistration {
  const DoctorRegistration({
    required this.doctorId,
    required this.status,
    required this.submittedAt,
    required this.fullName,
    required this.title,
    required this.specialty,
    required this.licenseNumber,
    required this.licenseContentType,
    this.statusReason,
    this.approvedAt,
    this.email,
    this.emailVerified = true,
    this.phone,
    this.locale = 'ar',
    this.extraSpecialties = const [],
    this.fullNameEn,
    this.titleEn,
    this.degreesAr,
    this.degreesEn,
    this.examinationPricePiasters,
    this.consultationPricePiasters,
    this.branch,
    this.trial,
  });

  factory DoctorRegistration.fromJson(Map<String, dynamic> json) => DoctorRegistration(
        doctorId: json['doctorId'] as String,
        status: json['status'] as String,
        statusReason: _text(json['statusReason']),
        submittedAt: _time(json['submittedAt']),
        approvedAt: _timeOrNull(json['approvedAt']),
        fullName: json['fullName'] as String,
        email: _text(json['email']),
        emailVerified: json['emailVerified'] as bool? ?? true,
        phone: _text(json['phone']),
        locale: json['locale'] as String? ?? 'ar',
        title: json['title'] as String? ?? '',
        specialty: SpecialtyRef.fromJson(_map(json['specialty'])),
        extraSpecialties: [
          for (final specialty in json['extraSpecialties'] as List? ?? const []) SpecialtyRef.fromJson(_map(specialty)),
        ],
        licenseNumber: json['licenseNumber'] as String,
        licenseContentType: json['licenseContentType'] as String? ?? 'application/octet-stream',
        fullNameEn: _text(json['fullNameEn']),
        titleEn: _text(json['titleEn']),
        degreesAr: _text(json['degreesAr']),
        degreesEn: _text(json['degreesEn']),
        examinationPricePiasters: json['examinationPricePiasters'] as int?,
        consultationPricePiasters: json['consultationPricePiasters'] as int?,
        branch: json['branch'] == null ? null : RegistrationBranch.fromJson(_map(json['branch'])),
        trial: _trial(json['trial']),
      );

  final String doctorId;
  final String status;
  final String? statusReason;
  final DateTime submittedAt;
  final DateTime? approvedAt;
  final String fullName;
  final String? email;
  final bool emailVerified;
  final String? phone;
  final String locale;
  final String title;
  final SpecialtyRef specialty;
  final List<SpecialtyRef> extraSpecialties;
  final String licenseNumber;
  final String licenseContentType;
  final String? fullNameEn;
  final String? titleEn;
  final String? degreesAr;
  final String? degreesEn;
  final int? examinationPricePiasters;
  final int? consultationPricePiasters;
  final RegistrationBranch? branch;

  /// The free trial after approval (spec 6.16): running, ended, or null when
  /// the service is active (or the doctor isn't approved yet).
  final TrialInfo? trial;

  bool get isPending => status == DoctorStatuses.pendingApproval;

  /// Approved: the admin can activate the service or extend the trial.
  bool get isApproved => status == DoctorStatuses.active || status == DoctorStatuses.suspended;

  /// The same registration with another [trial].
  DoctorRegistration withTrial(TrialInfo? trial) => _copy(status: status, statusReason: statusReason, trial: trial);

  /// The same registration with a new [status] and its [statusReason]
  /// (null: none, so an approval clears an earlier rejection's reason).
  DoctorRegistration withStatus(String status, {String? statusReason}) =>
      _copy(status: status, statusReason: statusReason, trial: trial);

  DoctorRegistration _copy({required String status, required String? statusReason, required TrialInfo? trial}) =>
      DoctorRegistration(
        doctorId: doctorId,
        status: status,
        statusReason: statusReason,
        trial: trial,
        submittedAt: submittedAt,
        approvedAt: approvedAt,
        fullName: fullName,
        email: email,
        emailVerified: emailVerified,
        phone: phone,
        locale: locale,
        title: title,
        specialty: specialty,
        extraSpecialties: extraSpecialties,
        licenseNumber: licenseNumber,
        licenseContentType: licenseContentType,
        fullNameEn: fullNameEn,
        titleEn: titleEn,
        degreesAr: degreesAr,
        degreesEn: degreesEn,
        examinationPricePiasters: examinationPricePiasters,
        consultationPricePiasters: consultationPricePiasters,
        branch: branch,
      );
}

enum ReviewDecision { approve, reject }

/// An earlier review of the same registration (AD3 history).
class RegistrationReview {
  const RegistrationReview({required this.decision, required this.at, this.reason, this.reviewedByName});

  factory RegistrationReview.fromJson(Map<String, dynamic> json) => RegistrationReview(
        decision: json['decision'] == 'approve' ? ReviewDecision.approve : ReviewDecision.reject,
        reason: _text(json['reason']),
        reviewedByName: _text(json['reviewedByName']),
        at: _time(json['at']),
      );

  final ReviewDecision decision;
  final String? reason;
  final String? reviewedByName;
  final DateTime at;
}

/// `GET /api/admin/doctorRegistrations/{doctorId}`.
class RegistrationDetail {
  const RegistrationDetail({required this.registration, this.reviews = const []});

  factory RegistrationDetail.fromJson(Map<String, dynamic> json) => RegistrationDetail(
        registration: DoctorRegistration.fromJson(_map(json['registration'])),
        reviews: [for (final review in json['reviews'] as List? ?? const []) RegistrationReview.fromJson(_map(review))],
      );

  final DoctorRegistration registration;

  /// Newest first. A rejection here means the doctor resubmitted.
  final List<RegistrationReview> reviews;
}

/// `setDoctorStatus`'s answer (BR-G4; AD5 comes in Phase 7).
class DoctorStatusView {
  const DoctorStatusView({
    required this.doctorId,
    required this.fullName,
    required this.status,
    this.statusReason,
    this.statusChangedAt,
  });

  factory DoctorStatusView.fromJson(Map<String, dynamic> json) => DoctorStatusView(
        doctorId: json['doctorId'] as String,
        fullName: json['fullName'] as String,
        status: json['status'] as String,
        statusReason: _text(json['statusReason']),
        statusChangedAt: _timeOrNull(json['statusChangedAt']),
      );

  final String doctorId;
  final String fullName;

  /// [DoctorStatuses.active] or [DoctorStatuses.suspended].
  final String status;

  /// The suspension reason; null once active.
  final String? statusReason;
  final DateTime? statusChangedAt;

  bool get isSuspended => status == DoctorStatuses.suspended;
}

/// `activateDoctorService` and `extendDoctorTrial`'s answer
/// (backend/docs/api-free-trial.md).
class DoctorTrialView {
  const DoctorTrialView({required this.doctorId, required this.fullName, required this.status, this.trial});

  factory DoctorTrialView.fromJson(Map<String, dynamic> json) => DoctorTrialView(
        doctorId: json['doctorId'] as String,
        fullName: json['fullName'] as String,
        status: json['status'] as String,
        trial: _trial(json['trial']),
      );

  final String doctorId;
  final String fullName;
  final String status;

  /// Null once the service is active.
  final TrialInfo? trial;
}

/// AD2's trial filter: `running` or `ended` (`status=all`).
enum TrialFilter { running, ended }

/// AD2's other filters: the primary specialty, the first branch's
/// governorate (its Arabic name, as stored) and the sign-up dates: [from]
/// inclusive and [to] exclusive, both the UTC start of a Cairo day.
@immutable
class DoctorListFilter {
  const DoctorListFilter({this.specialty, this.governorate, this.from, this.to});

  final SpecialtyRef? specialty;
  final String? governorate;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty => specialty == null && governorate == null && from == null && to == null;

  DoctorListFilter withSpecialty(SpecialtyRef? value) => DoctorListFilter(specialty: value, governorate: governorate, from: from, to: to);

  DoctorListFilter withGovernorate(String? value) => DoctorListFilter(specialty: specialty, governorate: value, from: from, to: to);

  DoctorListFilter withDates(DateTime? from, DateTime? to) =>
      DoctorListFilter(specialty: specialty, governorate: governorate, from: from, to: to);

  @override
  bool operator ==(Object other) =>
      other is DoctorListFilter &&
      other.specialty?.id == specialty?.id &&
      other.governorate == governorate &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(specialty?.id, governorate, from, to);
}

/// The license file, streamed through the API (never a public URL).
class LicenseFile {
  const LicenseFile({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';
}

/// `superAdmin` manages admins (AD14); `admin` does everything else.
enum AdminRole {
  superAdmin,
  admin;

  static AdminRole fromJson(String? value) => value == 'superAdmin' ? superAdmin : admin;
}

/// A row of AD14.
class AdminUser {
  const AdminUser({
    required this.userId,
    required this.displayName,
    required this.adminRole,
    required this.status,
    required this.createdAt,
    this.email,
    this.mustChangePassword = false,
    this.lastLoginAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String,
        email: _text(json['email']),
        adminRole: AdminRole.fromJson(json['adminRole'] as String?),
        status: json['status'] as String,
        mustChangePassword: json['mustChangePassword'] as bool? ?? false,
        createdAt: _time(json['createdAt']),
        lastLoginAt: _timeOrNull(json['lastLoginAt']),
      );

  final String userId;
  final String displayName;
  final String? email;
  final AdminRole adminRole;

  /// `active` or `disabled`.
  final String status;

  /// Hasn't set their own password yet (the temporary one still works).
  final bool mustChangePassword;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  bool get isActive => status == 'active';
  bool get isSuperAdmin => adminRole == AdminRole.superAdmin;

  AdminUser copyWith({String? displayName, AdminRole? adminRole, String? status}) => AdminUser(
        userId: userId,
        displayName: displayName ?? this.displayName,
        email: email,
        adminRole: adminRole ?? this.adminRole,
        status: status ?? this.status,
        mustChangePassword: mustChangePassword,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
      );
}

/// `POST /api/admin/createAdmin`: the temporary password is shown once.
class CreatedAdmin {
  const CreatedAdmin({required this.admin, required this.temporaryPassword});

  factory CreatedAdmin.fromJson(Map<String, dynamic> json) => CreatedAdmin(
        admin: AdminUser.fromJson(_map(json['admin'])),
        temporaryPassword: json['temporaryPassword'] as String,
      );

  final AdminUser admin;
  final String temporaryPassword;
}

/// `GET /api/admin/profile` (AD18).
class AdminProfile {
  const AdminProfile({required this.admin, this.locale = 'ar', this.themeMode = 'system'});

  factory AdminProfile.fromJson(Map<String, dynamic> json) => AdminProfile(
        admin: AdminUser.fromJson(_map(json['admin'])),
        locale: json['locale'] as String? ?? 'ar',
        themeMode: json['themeMode'] as String? ?? 'system',
      );

  final AdminUser admin;
  final String locale;
  final String themeMode;
}

/// A row of AD15 (`GET /api/admin/auditLogs`), newest first.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actorRole,
    required this.action,
    required this.targetType,
    this.actorUserId,
    this.actorName,
    this.targetId,
    this.doctorId,
    this.details,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) => AuditEntry(
        id: json['id'] as int,
        at: _time(json['at']),
        actorUserId: _text(json['actorUserId']),
        actorRole: json['actorRole'] as String? ?? 'system',
        actorName: _text(json['actorName']),
        action: json['action'] as String,
        targetType: json['targetType'] as String? ?? '',
        targetId: _text(json['targetId']),
        doctorId: _text(json['doctorId']),
        details: json['details'] is Map ? _map(json['details']) : null,
      );

  final int id;
  final DateTime at;
  final String? actorUserId;

  /// `system`, `admin`, `doctor`, `assistant` or `patient`.
  final String actorRole;
  final String? actorName;
  final String action;

  /// `user`, `doctor` or `settings`.
  final String targetType;
  final String? targetId;
  final String? doctorId;
  final Map<String, dynamic>? details;
}

/// The actions written in Phase 1 (AD15 filters by these).
abstract final class AuditActions {
  static const all = [
    'doctorRegistrationSubmitted',
    'doctorRegistrationResubmitted',
    'doctorRegistrationApproved',
    'doctorRegistrationRejected',
    'doctorLicenseViewed',
    'doctorServiceActivated',
    'doctorTrialExtended',
    'doctorCreated',
    'broadcastSent',
    'adminSeeded',
    'adminCreated',
    'adminRoleChanged',
    'adminDisabled',
    'adminEnabled',
    'adminProfileUpdated',
    'settingsUpdated',
    'passwordSet',
    'passwordChanged',
    'passwordResetRequested',
    'passwordReset',
    'accountLockedOut',
    'refreshTokenReuseDetected',
    'emailVerified',
  ];

  static const actorRoles = ['admin', 'doctor', 'assistant', 'patient', 'system'];
  static const targetTypes = ['doctor', 'user', 'settings', 'broadcast'];
}

/// AD15 filters. Every one is optional. [from] and [to] are UTC; [to] is
/// exclusive. [actorName] and [targetLabel] are only for the filter chips.
class AuditFilter {
  const AuditFilter({
    this.action,
    this.actorRole,
    this.actorUserId,
    this.actorName,
    this.targetType,
    this.targetId,
    this.targetLabel,
    this.from,
    this.to,
  });

  final String? action;
  final String? actorRole;
  final String? actorUserId;
  final String? actorName;
  final String? targetType;
  final String? targetId;
  final String? targetLabel;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      action == null && actorRole == null && actorUserId == null && targetType == null && targetId == null && from == null;

  Map<String, dynamic> toQuery() => {
        'action': ?action,
        'actorRole': ?actorRole,
        'actorUserId': ?actorUserId,
        'targetType': ?targetType,
        'targetId': ?targetId,
        'from': ?from?.toUtc().toIso8601String(),
        'to': ?to?.toUtc().toIso8601String(),
      };

  AuditFilter withAction(String? value) => _copy(action: () => value);

  AuditFilter withActorRole(String? value) => _copy(actorRole: () => value);

  /// One person's actions; null clears it.
  AuditFilter withActor(String? userId, String? name) => _copy(actor: () => (userId, name));

  /// A kind of target; clears a single target picked with [withTarget].
  AuditFilter withTargetType(String? type) => _copy(target: () => (type, null, null));

  /// One record (a doctor, an admin); null clears it.
  AuditFilter withTarget(String? type, String? id, String? label) => _copy(target: () => (type, id, label));

  AuditFilter withDates(DateTime? from, DateTime? to) => _copy(dates: () => (from, to));

  AuditFilter _copy({
    String? Function()? action,
    String? Function()? actorRole,
    (String?, String?) Function()? actor,
    (String?, String?, String?) Function()? target,
    (DateTime?, DateTime?) Function()? dates,
  }) {
    final (actorId, actorLabel) = actor == null ? (actorUserId, actorName) : actor();
    final (type, id, label) = target == null ? (targetType, targetId, targetLabel) : target();
    final (start, end) = dates == null ? (from, to) : dates();
    return AuditFilter(
      action: action == null ? this.action : action(),
      actorRole: actorRole == null ? this.actorRole : actorRole(),
      actorUserId: actorId,
      actorName: actorLabel,
      targetType: type,
      targetId: id,
      targetLabel: label,
      from: start,
      to: end,
    );
  }
}

/// `GET /api/admin/settingsHistory`: one changed field, newest first.
class SettingsHistoryEntry {
  const SettingsHistoryEntry({
    required this.id,
    required this.field,
    required this.changedByName,
    required this.changedAt,
    this.before,
    this.after,
    this.truncated = false,
  });

  factory SettingsHistoryEntry.fromJson(Map<String, dynamic> json) => SettingsHistoryEntry(
        id: json['id'] as String,
        field: json['field'] as String,
        before: json['before'] as String?,
        after: json['after'] as String?,
        truncated: json['truncated'] as bool? ?? false,
        changedByName: json['changedByName'] as String? ?? '',
        changedAt: _time(json['changedAt']),
      );

  final String id;
  final String field;

  /// As stored: invariant text, `true`/`false`, piasters for fees; null when empty.
  final String? before;
  final String? after;

  /// The list cuts values longer than 300 characters; fetch the entry for the full text.
  final bool truncated;
  final String changedByName;
  final DateTime changedAt;
}

/// `GET /api/admin/settings`: every field by its `updateSettings` name.
class PlatformSettings {
  const PlatformSettings({required this.values, this.updatedAt, this.updatedByName});

  factory PlatformSettings.fromJson(Map<String, dynamic> json) {
    final values = Map<String, Object?>.of(json)
      ..remove('updatedAt')
      ..remove('updatedBy');
    final updatedBy = json['updatedBy'];
    return PlatformSettings(
      values: values,
      updatedAt: _timeOrNull(json['updatedAt']),
      updatedByName: updatedBy is Map ? updatedBy['displayName'] as String? : null,
    );
  }

  final Map<String, Object?> values;
  final DateTime? updatedAt;
  final String? updatedByName;

  Object? operator [](String field) => values[field];
}
