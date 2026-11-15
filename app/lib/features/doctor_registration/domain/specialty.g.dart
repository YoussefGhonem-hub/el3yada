// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'specialty.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Specialty _$SpecialtyFromJson(Map<String, dynamic> json) => _Specialty(
  id: json['id'] as String,
  nameAr: json['nameAr'] as String? ?? '',
  nameEn: json['nameEn'] as String? ?? '',
);

Map<String, dynamic> _$SpecialtyToJson(_Specialty instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nameAr': instance.nameAr,
      'nameEn': instance.nameEn,
    };
