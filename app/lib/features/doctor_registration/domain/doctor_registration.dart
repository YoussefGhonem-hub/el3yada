import 'package:freezed_annotation/freezed_annotation.dart';

import '../../auth/domain/auth_session.dart';
import 'specialty.dart';

part 'doctor_registration.freezed.dart';
part 'doctor_registration.g.dart';

/// The A4 form as the API takes it: the JSON part `data` of
/// `completeDoctorRegistration` and, without [password] and [acceptTerms],
/// of `resubmitDoctorRegistration` (A7). Contract:
/// backend/docs/api-phase-1.md, "Doctor registration (A4–A7)".
///
/// Null fields are left out of the JSON.
@freezed
abstract class RegistrationData with _$RegistrationData {
  // ignore: invalid_annotation_target
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory RegistrationData({
    // Step 1, account
    required String fullName,
    required String email,
    required String phone,

    /// Only on first registration.
    String? password,

    /// `ar` or `en`: the language of emails and notifications.
    required String locale,

    // Step 2, professional
    required String title,
    required String specialtyId,
    @Default(<String>[]) List<String> extraSpecialtyIds,

    /// Medical syndicate number.
    required String licenseNumber,

    /// Optional, for the English prescription header (also editable in D22).
    String? fullNameEn,
    String? titleEn,
    String? degreesAr,
    String? degreesEn,

    // Step 3, first branch and the doctor's visit prices (spec 6.15)
    required RegistrationBranch branch,
    int? examinationPricePiasters,
    int? consultationPricePiasters,

    // Step 4, only on first registration
    bool? acceptTerms,

    /// The `device` object (see DeviceIdentity), only on first registration.
    Map<String, dynamic>? device,
  }) = _RegistrationData;

  factory RegistrationData.fromJson(Map<String, dynamic> json) => _$RegistrationDataFromJson(json);
}

/// The first branch, in the request and in the registration view ([id] only
/// in the view). JSON with fields this class no longer has (the old street,
/// building, floor, apartment, lat and lng) still reads: they are ignored.
@freezed
abstract class RegistrationBranch with _$RegistrationBranch {
  // ignore: invalid_annotation_target
  @JsonSerializable(includeIfNull: false, explicitToJson: true)
  const factory RegistrationBranch({
    String? id,
    @Default('') String nameAr,
    String? nameEn,
    @Default('') String governorate,
    @Default('') String city,
    String? area,

    /// «العنوان بالتفصيل»: street, building, floor and apartment in one text.
    @Default('') String addressDetails,
    String? landmark,

    /// «لينك جوجل ماب», optional.
    String? mapUrl,
    String? email,
    @Default(<BranchPhone>[]) List<BranchPhone> phones,
  }) = _RegistrationBranch;

  factory RegistrationBranch.fromJson(Map<String, dynamic> json) => _$RegistrationBranchFromJson(json);
}

/// One branch phone: an Egyptian mobile, landline or hotline. The API
/// answers in E.164 (`+20…`), hotlines as typed (`19xxx`).
@freezed
abstract class BranchPhone with _$BranchPhone {
  const factory BranchPhone({
    required String number,
    @Default(BranchPhone.reception) String label,
    @Default(false) bool isWhatsapp,
  }) = _BranchPhone;

  factory BranchPhone.fromJson(Map<String, dynamic> json) => _$BranchPhoneFromJson(json);

  static const reception = 'reception';
  static const mobile = 'mobile';
  static const landline = 'landline';
  static const labels = [reception, mobile, landline];
}

/// A registration as the doctor submitted it (`GET /api/doctors/myRegistration`
/// and the answer of `resubmitDoctorRegistration`): A6 shows it read-only and
/// A7 fills the form with it.
@freezed
abstract class DoctorRegistration with _$DoctorRegistration {
  const DoctorRegistration._();

  const factory DoctorRegistration({
    @Default('') String doctorId,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? status,
    String? statusReason,

    /// The latest submission (the first one, or the last resubmission).
    DateTime? submittedAt,
    DateTime? approvedAt,
    @Default('') String fullName,
    String? email,
    @Default(false) bool emailVerified,
    String? phone,
    @Default('ar') String locale,
    @Default('') String title,
    required Specialty specialty,
    @Default(<Specialty>[]) List<Specialty> extraSpecialties,
    @Default('') String licenseNumber,

    /// `image/jpeg`, `image/png`, `image/webp` or `application/pdf`.
    String? licenseContentType,
    String? fullNameEn,
    String? titleEn,
    String? degreesAr,
    String? degreesEn,
    int? examinationPricePiasters,
    int? consultationPricePiasters,
    RegistrationBranch? branch,
  }) = _DoctorRegistration;

  factory DoctorRegistration.fromJson(Map<String, dynamic> json) => _$DoctorRegistrationFromJson(json);

  bool get licenseIsPdf => licenseContentType == 'application/pdf';
}
