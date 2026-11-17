// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => _AuthSession(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String? ?? '',
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  adminRole: json['adminRole'] as String?,
  doctorId: json['doctorId'] as String?,
  doctorStatus: $enumDecodeNullable(
    _$DoctorStatusEnumMap,
    json['doctorStatus'],
    unknownValue: JsonKey.nullForUndefinedEnumValue,
  ),
  doctorStatusReason: json['doctorStatusReason'] as String?,
  mustChangePassword: json['mustChangePassword'] as bool? ?? false,
  mustAcceptTerms: json['mustAcceptTerms'] as bool? ?? false,
  email: json['email'] as String?,
  emailVerified: json['emailVerified'] as bool? ?? true,
  phone: json['phone'] as String?,
  locale: json['locale'] as String? ?? 'ar',
  themeMode: json['themeMode'] as String? ?? 'system',
  trial: json['trial'] == null
      ? null
      : TrialInfo.fromJson(json['trial'] as Map<String, dynamic>),
  accessToken: json['accessToken'] as String,
  accessTokenExpiresAt: json['accessTokenExpiresAt'] == null
      ? null
      : DateTime.parse(json['accessTokenExpiresAt'] as String),
  refreshToken: json['refreshToken'] as String,
  refreshTokenExpiresAt: json['refreshTokenExpiresAt'] == null
      ? null
      : DateTime.parse(json['refreshTokenExpiresAt'] as String),
);

Map<String, dynamic> _$AuthSessionToJson(
  _AuthSession instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'displayName': instance.displayName,
  'role': instance.role,
  'adminRole': instance.adminRole,
  'doctorId': instance.doctorId,
  'doctorStatus': _$DoctorStatusEnumMap[instance.doctorStatus],
  'doctorStatusReason': instance.doctorStatusReason,
  'mustChangePassword': instance.mustChangePassword,
  'mustAcceptTerms': instance.mustAcceptTerms,
  'email': instance.email,
  'emailVerified': instance.emailVerified,
  'phone': instance.phone,
  'locale': instance.locale,
  'themeMode': instance.themeMode,
  'trial': instance.trial,
  'accessToken': instance.accessToken,
  'accessTokenExpiresAt': instance.accessTokenExpiresAt?.toIso8601String(),
  'refreshToken': instance.refreshToken,
  'refreshTokenExpiresAt': instance.refreshTokenExpiresAt?.toIso8601String(),
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.doctor: 'doctor',
  UserRole.assistant: 'assistant',
  UserRole.patient: 'patient',
};

const _$DoctorStatusEnumMap = {
  DoctorStatus.pendingApproval: 'pendingApproval',
  DoctorStatus.active: 'active',
  DoctorStatus.rejected: 'rejected',
  DoctorStatus.suspended: 'suspended',
  DoctorStatus.disabled: 'disabled',
};

_TrialInfo _$TrialInfoFromJson(Map<String, dynamic> json) => _TrialInfo(
  endsAt: DateTime.parse(json['endsAt'] as String),
  ended: json['ended'] as bool? ?? false,
  daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TrialInfoToJson(_TrialInfo instance) =>
    <String, dynamic>{
      'endsAt': instance.endsAt.toIso8601String(),
      'ended': instance.ended,
      'daysLeft': instance.daysLeft,
    };
