// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => _AuthSession(
  userId: json['userId'] as String,
  displayName: json['displayName'] as String? ?? '',
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  accessToken: json['accessToken'] as String,
  refreshToken: json['refreshToken'] as String,
  doctorId: json['doctorId'] as String?,
  mustChangePassword: json['mustChangePassword'] as bool? ?? false,
);

Map<String, dynamic> _$AuthSessionToJson(_AuthSession instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'displayName': instance.displayName,
      'role': instance.role,
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'doctorId': instance.doctorId,
      'mustChangePassword': instance.mustChangePassword,
    };

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.doctor: 'doctor',
  UserRole.assistant: 'assistant',
  UserRole.patient: 'patient',
};
