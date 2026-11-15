// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctor_registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RegistrationData _$RegistrationDataFromJson(
  Map<String, dynamic> json,
) => _RegistrationData(
  fullName: json['fullName'] as String,
  email: json['email'] as String,
  phone: json['phone'] as String,
  password: json['password'] as String?,
  locale: json['locale'] as String,
  title: json['title'] as String,
  specialtyId: json['specialtyId'] as String,
  extraSpecialtyIds:
      (json['extraSpecialtyIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  licenseNumber: json['licenseNumber'] as String,
  fullNameEn: json['fullNameEn'] as String?,
  titleEn: json['titleEn'] as String?,
  degreesAr: json['degreesAr'] as String?,
  degreesEn: json['degreesEn'] as String?,
  branch: RegistrationBranch.fromJson(json['branch'] as Map<String, dynamic>),
  examinationPricePiasters: (json['examinationPricePiasters'] as num?)?.toInt(),
  consultationPricePiasters: (json['consultationPricePiasters'] as num?)
      ?.toInt(),
  acceptTerms: json['acceptTerms'] as bool?,
  device: json['device'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$RegistrationDataToJson(_RegistrationData instance) =>
    <String, dynamic>{
      'fullName': instance.fullName,
      'email': instance.email,
      'phone': instance.phone,
      'password': ?instance.password,
      'locale': instance.locale,
      'title': instance.title,
      'specialtyId': instance.specialtyId,
      'extraSpecialtyIds': instance.extraSpecialtyIds,
      'licenseNumber': instance.licenseNumber,
      'fullNameEn': ?instance.fullNameEn,
      'titleEn': ?instance.titleEn,
      'degreesAr': ?instance.degreesAr,
      'degreesEn': ?instance.degreesEn,
      'branch': instance.branch.toJson(),
      'examinationPricePiasters': ?instance.examinationPricePiasters,
      'consultationPricePiasters': ?instance.consultationPricePiasters,
      'acceptTerms': ?instance.acceptTerms,
      'device': ?instance.device,
    };

_RegistrationBranch _$RegistrationBranchFromJson(Map<String, dynamic> json) =>
    _RegistrationBranch(
      id: json['id'] as String?,
      nameAr: json['nameAr'] as String? ?? '',
      nameEn: json['nameEn'] as String?,
      governorate: json['governorate'] as String? ?? '',
      city: json['city'] as String? ?? '',
      area: json['area'] as String?,
      street: json['street'] as String? ?? '',
      building: json['building'] as String?,
      floor: json['floor'] as String?,
      apartment: json['apartment'] as String?,
      landmark: json['landmark'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      email: json['email'] as String?,
      phones:
          (json['phones'] as List<dynamic>?)
              ?.map((e) => BranchPhone.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <BranchPhone>[],
    );

Map<String, dynamic> _$RegistrationBranchToJson(_RegistrationBranch instance) =>
    <String, dynamic>{
      'id': ?instance.id,
      'nameAr': instance.nameAr,
      'nameEn': ?instance.nameEn,
      'governorate': instance.governorate,
      'city': instance.city,
      'area': ?instance.area,
      'street': instance.street,
      'building': ?instance.building,
      'floor': ?instance.floor,
      'apartment': ?instance.apartment,
      'landmark': ?instance.landmark,
      'lat': ?instance.lat,
      'lng': ?instance.lng,
      'email': ?instance.email,
      'phones': instance.phones.map((e) => e.toJson()).toList(),
    };

_BranchPhone _$BranchPhoneFromJson(Map<String, dynamic> json) => _BranchPhone(
  number: json['number'] as String,
  label: json['label'] as String? ?? BranchPhone.reception,
  isWhatsapp: json['isWhatsapp'] as bool? ?? false,
);

Map<String, dynamic> _$BranchPhoneToJson(_BranchPhone instance) =>
    <String, dynamic>{
      'number': instance.number,
      'label': instance.label,
      'isWhatsapp': instance.isWhatsapp,
    };

_DoctorRegistration _$DoctorRegistrationFromJson(Map<String, dynamic> json) =>
    _DoctorRegistration(
      doctorId: json['doctorId'] as String? ?? '',
      status: $enumDecodeNullable(
        _$DoctorStatusEnumMap,
        json['status'],
        unknownValue: JsonKey.nullForUndefinedEnumValue,
      ),
      statusReason: json['statusReason'] as String?,
      submittedAt: json['submittedAt'] == null
          ? null
          : DateTime.parse(json['submittedAt'] as String),
      approvedAt: json['approvedAt'] == null
          ? null
          : DateTime.parse(json['approvedAt'] as String),
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      phone: json['phone'] as String?,
      locale: json['locale'] as String? ?? 'ar',
      title: json['title'] as String? ?? '',
      specialty: Specialty.fromJson(json['specialty'] as Map<String, dynamic>),
      extraSpecialties:
          (json['extraSpecialties'] as List<dynamic>?)
              ?.map((e) => Specialty.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Specialty>[],
      licenseNumber: json['licenseNumber'] as String? ?? '',
      licenseContentType: json['licenseContentType'] as String?,
      fullNameEn: json['fullNameEn'] as String?,
      titleEn: json['titleEn'] as String?,
      degreesAr: json['degreesAr'] as String?,
      degreesEn: json['degreesEn'] as String?,
      examinationPricePiasters: (json['examinationPricePiasters'] as num?)
          ?.toInt(),
      consultationPricePiasters: (json['consultationPricePiasters'] as num?)
          ?.toInt(),
      branch: json['branch'] == null
          ? null
          : RegistrationBranch.fromJson(json['branch'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$DoctorRegistrationToJson(_DoctorRegistration instance) =>
    <String, dynamic>{
      'doctorId': instance.doctorId,
      'status': _$DoctorStatusEnumMap[instance.status],
      'statusReason': instance.statusReason,
      'submittedAt': instance.submittedAt?.toIso8601String(),
      'approvedAt': instance.approvedAt?.toIso8601String(),
      'fullName': instance.fullName,
      'email': instance.email,
      'emailVerified': instance.emailVerified,
      'phone': instance.phone,
      'locale': instance.locale,
      'title': instance.title,
      'specialty': instance.specialty,
      'extraSpecialties': instance.extraSpecialties,
      'licenseNumber': instance.licenseNumber,
      'licenseContentType': instance.licenseContentType,
      'fullNameEn': instance.fullNameEn,
      'titleEn': instance.titleEn,
      'degreesAr': instance.degreesAr,
      'degreesEn': instance.degreesEn,
      'examinationPricePiasters': instance.examinationPricePiasters,
      'consultationPricePiasters': instance.consultationPricePiasters,
      'branch': instance.branch,
    };

const _$DoctorStatusEnumMap = {
  DoctorStatus.pendingApproval: 'pendingApproval',
  DoctorStatus.active: 'active',
  DoctorStatus.rejected: 'rejected',
  DoctorStatus.suspended: 'suspended',
  DoctorStatus.disabled: 'disabled',
};
