// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'doctor_registration.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RegistrationData {

// Step 1, account
 String get fullName; String get email; String get phone;/// Only on first registration.
 String? get password;/// `ar` or `en`: the language of emails and notifications.
 String get locale;// Step 2, professional
 String get title; String get specialtyId; List<String> get extraSpecialtyIds;/// Medical syndicate number.
 String get licenseNumber;/// Optional, for the English prescription header (also editable in D22).
 String? get fullNameEn; String? get titleEn; String? get degreesAr; String? get degreesEn;// Step 3, first branch and the doctor's visit prices (spec 6.15)
 RegistrationBranch get branch; int? get examinationPricePiasters; int? get consultationPricePiasters;// Step 4, only on first registration
 bool? get acceptTerms;/// The `device` object (see DeviceIdentity), only on first registration.
 Map<String, dynamic>? get device;
/// Create a copy of RegistrationData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegistrationDataCopyWith<RegistrationData> get copyWith => _$RegistrationDataCopyWithImpl<RegistrationData>(this as RegistrationData, _$identity);

  /// Serializes this RegistrationData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegistrationData&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.title, title) || other.title == title)&&(identical(other.specialtyId, specialtyId) || other.specialtyId == specialtyId)&&const DeepCollectionEquality().equals(other.extraSpecialtyIds, extraSpecialtyIds)&&(identical(other.licenseNumber, licenseNumber) || other.licenseNumber == licenseNumber)&&(identical(other.fullNameEn, fullNameEn) || other.fullNameEn == fullNameEn)&&(identical(other.titleEn, titleEn) || other.titleEn == titleEn)&&(identical(other.degreesAr, degreesAr) || other.degreesAr == degreesAr)&&(identical(other.degreesEn, degreesEn) || other.degreesEn == degreesEn)&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.examinationPricePiasters, examinationPricePiasters) || other.examinationPricePiasters == examinationPricePiasters)&&(identical(other.consultationPricePiasters, consultationPricePiasters) || other.consultationPricePiasters == consultationPricePiasters)&&(identical(other.acceptTerms, acceptTerms) || other.acceptTerms == acceptTerms)&&const DeepCollectionEquality().equals(other.device, device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,email,phone,password,locale,title,specialtyId,const DeepCollectionEquality().hash(extraSpecialtyIds),licenseNumber,fullNameEn,titleEn,degreesAr,degreesEn,branch,examinationPricePiasters,consultationPricePiasters,acceptTerms,const DeepCollectionEquality().hash(device));

@override
String toString() {
  return 'RegistrationData(fullName: $fullName, email: $email, phone: $phone, password: $password, locale: $locale, title: $title, specialtyId: $specialtyId, extraSpecialtyIds: $extraSpecialtyIds, licenseNumber: $licenseNumber, fullNameEn: $fullNameEn, titleEn: $titleEn, degreesAr: $degreesAr, degreesEn: $degreesEn, branch: $branch, examinationPricePiasters: $examinationPricePiasters, consultationPricePiasters: $consultationPricePiasters, acceptTerms: $acceptTerms, device: $device)';
}


}

/// @nodoc
abstract mixin class $RegistrationDataCopyWith<$Res>  {
  factory $RegistrationDataCopyWith(RegistrationData value, $Res Function(RegistrationData) _then) = _$RegistrationDataCopyWithImpl;
@useResult
$Res call({
 String fullName, String email, String phone, String? password, String locale, String title, String specialtyId, List<String> extraSpecialtyIds, String licenseNumber, String? fullNameEn, String? titleEn, String? degreesAr, String? degreesEn, RegistrationBranch branch, int? examinationPricePiasters, int? consultationPricePiasters, bool? acceptTerms, Map<String, dynamic>? device
});


$RegistrationBranchCopyWith<$Res> get branch;

}
/// @nodoc
class _$RegistrationDataCopyWithImpl<$Res>
    implements $RegistrationDataCopyWith<$Res> {
  _$RegistrationDataCopyWithImpl(this._self, this._then);

  final RegistrationData _self;
  final $Res Function(RegistrationData) _then;

/// Create a copy of RegistrationData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fullName = null,Object? email = null,Object? phone = null,Object? password = freezed,Object? locale = null,Object? title = null,Object? specialtyId = null,Object? extraSpecialtyIds = null,Object? licenseNumber = null,Object? fullNameEn = freezed,Object? titleEn = freezed,Object? degreesAr = freezed,Object? degreesEn = freezed,Object? branch = null,Object? examinationPricePiasters = freezed,Object? consultationPricePiasters = freezed,Object? acceptTerms = freezed,Object? device = freezed,}) {
  return _then(_self.copyWith(
fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,specialtyId: null == specialtyId ? _self.specialtyId : specialtyId // ignore: cast_nullable_to_non_nullable
as String,extraSpecialtyIds: null == extraSpecialtyIds ? _self.extraSpecialtyIds : extraSpecialtyIds // ignore: cast_nullable_to_non_nullable
as List<String>,licenseNumber: null == licenseNumber ? _self.licenseNumber : licenseNumber // ignore: cast_nullable_to_non_nullable
as String,fullNameEn: freezed == fullNameEn ? _self.fullNameEn : fullNameEn // ignore: cast_nullable_to_non_nullable
as String?,titleEn: freezed == titleEn ? _self.titleEn : titleEn // ignore: cast_nullable_to_non_nullable
as String?,degreesAr: freezed == degreesAr ? _self.degreesAr : degreesAr // ignore: cast_nullable_to_non_nullable
as String?,degreesEn: freezed == degreesEn ? _self.degreesEn : degreesEn // ignore: cast_nullable_to_non_nullable
as String?,branch: null == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as RegistrationBranch,examinationPricePiasters: freezed == examinationPricePiasters ? _self.examinationPricePiasters : examinationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,consultationPricePiasters: freezed == consultationPricePiasters ? _self.consultationPricePiasters : consultationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,acceptTerms: freezed == acceptTerms ? _self.acceptTerms : acceptTerms // ignore: cast_nullable_to_non_nullable
as bool?,device: freezed == device ? _self.device : device // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of RegistrationData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RegistrationBranchCopyWith<$Res> get branch {
  
  return $RegistrationBranchCopyWith<$Res>(_self.branch, (value) {
    return _then(_self.copyWith(branch: value));
  });
}
}


/// Adds pattern-matching-related methods to [RegistrationData].
extension RegistrationDataPatterns on RegistrationData {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RegistrationData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RegistrationData() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RegistrationData value)  $default,){
final _that = this;
switch (_that) {
case _RegistrationData():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RegistrationData value)?  $default,){
final _that = this;
switch (_that) {
case _RegistrationData() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fullName,  String email,  String phone,  String? password,  String locale,  String title,  String specialtyId,  List<String> extraSpecialtyIds,  String licenseNumber,  String? fullNameEn,  String? titleEn,  String? degreesAr,  String? degreesEn,  RegistrationBranch branch,  int? examinationPricePiasters,  int? consultationPricePiasters,  bool? acceptTerms,  Map<String, dynamic>? device)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RegistrationData() when $default != null:
return $default(_that.fullName,_that.email,_that.phone,_that.password,_that.locale,_that.title,_that.specialtyId,_that.extraSpecialtyIds,_that.licenseNumber,_that.fullNameEn,_that.titleEn,_that.degreesAr,_that.degreesEn,_that.branch,_that.examinationPricePiasters,_that.consultationPricePiasters,_that.acceptTerms,_that.device);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fullName,  String email,  String phone,  String? password,  String locale,  String title,  String specialtyId,  List<String> extraSpecialtyIds,  String licenseNumber,  String? fullNameEn,  String? titleEn,  String? degreesAr,  String? degreesEn,  RegistrationBranch branch,  int? examinationPricePiasters,  int? consultationPricePiasters,  bool? acceptTerms,  Map<String, dynamic>? device)  $default,) {final _that = this;
switch (_that) {
case _RegistrationData():
return $default(_that.fullName,_that.email,_that.phone,_that.password,_that.locale,_that.title,_that.specialtyId,_that.extraSpecialtyIds,_that.licenseNumber,_that.fullNameEn,_that.titleEn,_that.degreesAr,_that.degreesEn,_that.branch,_that.examinationPricePiasters,_that.consultationPricePiasters,_that.acceptTerms,_that.device);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fullName,  String email,  String phone,  String? password,  String locale,  String title,  String specialtyId,  List<String> extraSpecialtyIds,  String licenseNumber,  String? fullNameEn,  String? titleEn,  String? degreesAr,  String? degreesEn,  RegistrationBranch branch,  int? examinationPricePiasters,  int? consultationPricePiasters,  bool? acceptTerms,  Map<String, dynamic>? device)?  $default,) {final _that = this;
switch (_that) {
case _RegistrationData() when $default != null:
return $default(_that.fullName,_that.email,_that.phone,_that.password,_that.locale,_that.title,_that.specialtyId,_that.extraSpecialtyIds,_that.licenseNumber,_that.fullNameEn,_that.titleEn,_that.degreesAr,_that.degreesEn,_that.branch,_that.examinationPricePiasters,_that.consultationPricePiasters,_that.acceptTerms,_that.device);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _RegistrationData implements RegistrationData {
  const _RegistrationData({required this.fullName, required this.email, required this.phone, this.password, required this.locale, required this.title, required this.specialtyId, final  List<String> extraSpecialtyIds = const <String>[], required this.licenseNumber, this.fullNameEn, this.titleEn, this.degreesAr, this.degreesEn, required this.branch, this.examinationPricePiasters, this.consultationPricePiasters, this.acceptTerms, final  Map<String, dynamic>? device}): _extraSpecialtyIds = extraSpecialtyIds,_device = device;
  factory _RegistrationData.fromJson(Map<String, dynamic> json) => _$RegistrationDataFromJson(json);

// Step 1, account
@override final  String fullName;
@override final  String email;
@override final  String phone;
/// Only on first registration.
@override final  String? password;
/// `ar` or `en`: the language of emails and notifications.
@override final  String locale;
// Step 2, professional
@override final  String title;
@override final  String specialtyId;
 final  List<String> _extraSpecialtyIds;
@override@JsonKey() List<String> get extraSpecialtyIds {
  if (_extraSpecialtyIds is EqualUnmodifiableListView) return _extraSpecialtyIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extraSpecialtyIds);
}

/// Medical syndicate number.
@override final  String licenseNumber;
/// Optional, for the English prescription header (also editable in D22).
@override final  String? fullNameEn;
@override final  String? titleEn;
@override final  String? degreesAr;
@override final  String? degreesEn;
// Step 3, first branch and the doctor's visit prices (spec 6.15)
@override final  RegistrationBranch branch;
@override final  int? examinationPricePiasters;
@override final  int? consultationPricePiasters;
// Step 4, only on first registration
@override final  bool? acceptTerms;
/// The `device` object (see DeviceIdentity), only on first registration.
 final  Map<String, dynamic>? _device;
/// The `device` object (see DeviceIdentity), only on first registration.
@override Map<String, dynamic>? get device {
  final value = _device;
  if (value == null) return null;
  if (_device is EqualUnmodifiableMapView) return _device;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of RegistrationData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegistrationDataCopyWith<_RegistrationData> get copyWith => __$RegistrationDataCopyWithImpl<_RegistrationData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegistrationDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegistrationData&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.password, password) || other.password == password)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.title, title) || other.title == title)&&(identical(other.specialtyId, specialtyId) || other.specialtyId == specialtyId)&&const DeepCollectionEquality().equals(other._extraSpecialtyIds, _extraSpecialtyIds)&&(identical(other.licenseNumber, licenseNumber) || other.licenseNumber == licenseNumber)&&(identical(other.fullNameEn, fullNameEn) || other.fullNameEn == fullNameEn)&&(identical(other.titleEn, titleEn) || other.titleEn == titleEn)&&(identical(other.degreesAr, degreesAr) || other.degreesAr == degreesAr)&&(identical(other.degreesEn, degreesEn) || other.degreesEn == degreesEn)&&(identical(other.branch, branch) || other.branch == branch)&&(identical(other.examinationPricePiasters, examinationPricePiasters) || other.examinationPricePiasters == examinationPricePiasters)&&(identical(other.consultationPricePiasters, consultationPricePiasters) || other.consultationPricePiasters == consultationPricePiasters)&&(identical(other.acceptTerms, acceptTerms) || other.acceptTerms == acceptTerms)&&const DeepCollectionEquality().equals(other._device, _device));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fullName,email,phone,password,locale,title,specialtyId,const DeepCollectionEquality().hash(_extraSpecialtyIds),licenseNumber,fullNameEn,titleEn,degreesAr,degreesEn,branch,examinationPricePiasters,consultationPricePiasters,acceptTerms,const DeepCollectionEquality().hash(_device));

@override
String toString() {
  return 'RegistrationData(fullName: $fullName, email: $email, phone: $phone, password: $password, locale: $locale, title: $title, specialtyId: $specialtyId, extraSpecialtyIds: $extraSpecialtyIds, licenseNumber: $licenseNumber, fullNameEn: $fullNameEn, titleEn: $titleEn, degreesAr: $degreesAr, degreesEn: $degreesEn, branch: $branch, examinationPricePiasters: $examinationPricePiasters, consultationPricePiasters: $consultationPricePiasters, acceptTerms: $acceptTerms, device: $device)';
}


}

/// @nodoc
abstract mixin class _$RegistrationDataCopyWith<$Res> implements $RegistrationDataCopyWith<$Res> {
  factory _$RegistrationDataCopyWith(_RegistrationData value, $Res Function(_RegistrationData) _then) = __$RegistrationDataCopyWithImpl;
@override @useResult
$Res call({
 String fullName, String email, String phone, String? password, String locale, String title, String specialtyId, List<String> extraSpecialtyIds, String licenseNumber, String? fullNameEn, String? titleEn, String? degreesAr, String? degreesEn, RegistrationBranch branch, int? examinationPricePiasters, int? consultationPricePiasters, bool? acceptTerms, Map<String, dynamic>? device
});


@override $RegistrationBranchCopyWith<$Res> get branch;

}
/// @nodoc
class __$RegistrationDataCopyWithImpl<$Res>
    implements _$RegistrationDataCopyWith<$Res> {
  __$RegistrationDataCopyWithImpl(this._self, this._then);

  final _RegistrationData _self;
  final $Res Function(_RegistrationData) _then;

/// Create a copy of RegistrationData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fullName = null,Object? email = null,Object? phone = null,Object? password = freezed,Object? locale = null,Object? title = null,Object? specialtyId = null,Object? extraSpecialtyIds = null,Object? licenseNumber = null,Object? fullNameEn = freezed,Object? titleEn = freezed,Object? degreesAr = freezed,Object? degreesEn = freezed,Object? branch = null,Object? examinationPricePiasters = freezed,Object? consultationPricePiasters = freezed,Object? acceptTerms = freezed,Object? device = freezed,}) {
  return _then(_RegistrationData(
fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,phone: null == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String,password: freezed == password ? _self.password : password // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,specialtyId: null == specialtyId ? _self.specialtyId : specialtyId // ignore: cast_nullable_to_non_nullable
as String,extraSpecialtyIds: null == extraSpecialtyIds ? _self._extraSpecialtyIds : extraSpecialtyIds // ignore: cast_nullable_to_non_nullable
as List<String>,licenseNumber: null == licenseNumber ? _self.licenseNumber : licenseNumber // ignore: cast_nullable_to_non_nullable
as String,fullNameEn: freezed == fullNameEn ? _self.fullNameEn : fullNameEn // ignore: cast_nullable_to_non_nullable
as String?,titleEn: freezed == titleEn ? _self.titleEn : titleEn // ignore: cast_nullable_to_non_nullable
as String?,degreesAr: freezed == degreesAr ? _self.degreesAr : degreesAr // ignore: cast_nullable_to_non_nullable
as String?,degreesEn: freezed == degreesEn ? _self.degreesEn : degreesEn // ignore: cast_nullable_to_non_nullable
as String?,branch: null == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as RegistrationBranch,examinationPricePiasters: freezed == examinationPricePiasters ? _self.examinationPricePiasters : examinationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,consultationPricePiasters: freezed == consultationPricePiasters ? _self.consultationPricePiasters : consultationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,acceptTerms: freezed == acceptTerms ? _self.acceptTerms : acceptTerms // ignore: cast_nullable_to_non_nullable
as bool?,device: freezed == device ? _self._device : device // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of RegistrationData
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RegistrationBranchCopyWith<$Res> get branch {
  
  return $RegistrationBranchCopyWith<$Res>(_self.branch, (value) {
    return _then(_self.copyWith(branch: value));
  });
}
}


/// @nodoc
mixin _$RegistrationBranch {

 String? get id; String get nameAr; String? get nameEn; String get governorate; String get city; String? get area;/// «العنوان بالتفصيل»: street, building, floor and apartment in one text.
 String get addressDetails; String? get landmark;/// «لينك جوجل ماب», optional.
 String? get mapUrl; String? get email; List<BranchPhone> get phones;
/// Create a copy of RegistrationBranch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RegistrationBranchCopyWith<RegistrationBranch> get copyWith => _$RegistrationBranchCopyWithImpl<RegistrationBranch>(this as RegistrationBranch, _$identity);

  /// Serializes this RegistrationBranch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RegistrationBranch&&(identical(other.id, id) || other.id == id)&&(identical(other.nameAr, nameAr) || other.nameAr == nameAr)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.governorate, governorate) || other.governorate == governorate)&&(identical(other.city, city) || other.city == city)&&(identical(other.area, area) || other.area == area)&&(identical(other.addressDetails, addressDetails) || other.addressDetails == addressDetails)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.mapUrl, mapUrl) || other.mapUrl == mapUrl)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other.phones, phones));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nameAr,nameEn,governorate,city,area,addressDetails,landmark,mapUrl,email,const DeepCollectionEquality().hash(phones));

@override
String toString() {
  return 'RegistrationBranch(id: $id, nameAr: $nameAr, nameEn: $nameEn, governorate: $governorate, city: $city, area: $area, addressDetails: $addressDetails, landmark: $landmark, mapUrl: $mapUrl, email: $email, phones: $phones)';
}


}

/// @nodoc
abstract mixin class $RegistrationBranchCopyWith<$Res>  {
  factory $RegistrationBranchCopyWith(RegistrationBranch value, $Res Function(RegistrationBranch) _then) = _$RegistrationBranchCopyWithImpl;
@useResult
$Res call({
 String? id, String nameAr, String? nameEn, String governorate, String city, String? area, String addressDetails, String? landmark, String? mapUrl, String? email, List<BranchPhone> phones
});




}
/// @nodoc
class _$RegistrationBranchCopyWithImpl<$Res>
    implements $RegistrationBranchCopyWith<$Res> {
  _$RegistrationBranchCopyWithImpl(this._self, this._then);

  final RegistrationBranch _self;
  final $Res Function(RegistrationBranch) _then;

/// Create a copy of RegistrationBranch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? nameAr = null,Object? nameEn = freezed,Object? governorate = null,Object? city = null,Object? area = freezed,Object? addressDetails = null,Object? landmark = freezed,Object? mapUrl = freezed,Object? email = freezed,Object? phones = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,nameAr: null == nameAr ? _self.nameAr : nameAr // ignore: cast_nullable_to_non_nullable
as String,nameEn: freezed == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String?,governorate: null == governorate ? _self.governorate : governorate // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as String?,addressDetails: null == addressDetails ? _self.addressDetails : addressDetails // ignore: cast_nullable_to_non_nullable
as String,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,mapUrl: freezed == mapUrl ? _self.mapUrl : mapUrl // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phones: null == phones ? _self.phones : phones // ignore: cast_nullable_to_non_nullable
as List<BranchPhone>,
  ));
}

}


/// Adds pattern-matching-related methods to [RegistrationBranch].
extension RegistrationBranchPatterns on RegistrationBranch {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RegistrationBranch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RegistrationBranch() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RegistrationBranch value)  $default,){
final _that = this;
switch (_that) {
case _RegistrationBranch():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RegistrationBranch value)?  $default,){
final _that = this;
switch (_that) {
case _RegistrationBranch() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id,  String nameAr,  String? nameEn,  String governorate,  String city,  String? area,  String addressDetails,  String? landmark,  String? mapUrl,  String? email,  List<BranchPhone> phones)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RegistrationBranch() when $default != null:
return $default(_that.id,_that.nameAr,_that.nameEn,_that.governorate,_that.city,_that.area,_that.addressDetails,_that.landmark,_that.mapUrl,_that.email,_that.phones);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id,  String nameAr,  String? nameEn,  String governorate,  String city,  String? area,  String addressDetails,  String? landmark,  String? mapUrl,  String? email,  List<BranchPhone> phones)  $default,) {final _that = this;
switch (_that) {
case _RegistrationBranch():
return $default(_that.id,_that.nameAr,_that.nameEn,_that.governorate,_that.city,_that.area,_that.addressDetails,_that.landmark,_that.mapUrl,_that.email,_that.phones);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id,  String nameAr,  String? nameEn,  String governorate,  String city,  String? area,  String addressDetails,  String? landmark,  String? mapUrl,  String? email,  List<BranchPhone> phones)?  $default,) {final _that = this;
switch (_that) {
case _RegistrationBranch() when $default != null:
return $default(_that.id,_that.nameAr,_that.nameEn,_that.governorate,_that.city,_that.area,_that.addressDetails,_that.landmark,_that.mapUrl,_that.email,_that.phones);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class _RegistrationBranch implements RegistrationBranch {
  const _RegistrationBranch({this.id, this.nameAr = '', this.nameEn, this.governorate = '', this.city = '', this.area, this.addressDetails = '', this.landmark, this.mapUrl, this.email, final  List<BranchPhone> phones = const <BranchPhone>[]}): _phones = phones;
  factory _RegistrationBranch.fromJson(Map<String, dynamic> json) => _$RegistrationBranchFromJson(json);

@override final  String? id;
@override@JsonKey() final  String nameAr;
@override final  String? nameEn;
@override@JsonKey() final  String governorate;
@override@JsonKey() final  String city;
@override final  String? area;
/// «العنوان بالتفصيل»: street, building, floor and apartment in one text.
@override@JsonKey() final  String addressDetails;
@override final  String? landmark;
/// «لينك جوجل ماب», optional.
@override final  String? mapUrl;
@override final  String? email;
 final  List<BranchPhone> _phones;
@override@JsonKey() List<BranchPhone> get phones {
  if (_phones is EqualUnmodifiableListView) return _phones;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_phones);
}


/// Create a copy of RegistrationBranch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RegistrationBranchCopyWith<_RegistrationBranch> get copyWith => __$RegistrationBranchCopyWithImpl<_RegistrationBranch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RegistrationBranchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RegistrationBranch&&(identical(other.id, id) || other.id == id)&&(identical(other.nameAr, nameAr) || other.nameAr == nameAr)&&(identical(other.nameEn, nameEn) || other.nameEn == nameEn)&&(identical(other.governorate, governorate) || other.governorate == governorate)&&(identical(other.city, city) || other.city == city)&&(identical(other.area, area) || other.area == area)&&(identical(other.addressDetails, addressDetails) || other.addressDetails == addressDetails)&&(identical(other.landmark, landmark) || other.landmark == landmark)&&(identical(other.mapUrl, mapUrl) || other.mapUrl == mapUrl)&&(identical(other.email, email) || other.email == email)&&const DeepCollectionEquality().equals(other._phones, _phones));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nameAr,nameEn,governorate,city,area,addressDetails,landmark,mapUrl,email,const DeepCollectionEquality().hash(_phones));

@override
String toString() {
  return 'RegistrationBranch(id: $id, nameAr: $nameAr, nameEn: $nameEn, governorate: $governorate, city: $city, area: $area, addressDetails: $addressDetails, landmark: $landmark, mapUrl: $mapUrl, email: $email, phones: $phones)';
}


}

/// @nodoc
abstract mixin class _$RegistrationBranchCopyWith<$Res> implements $RegistrationBranchCopyWith<$Res> {
  factory _$RegistrationBranchCopyWith(_RegistrationBranch value, $Res Function(_RegistrationBranch) _then) = __$RegistrationBranchCopyWithImpl;
@override @useResult
$Res call({
 String? id, String nameAr, String? nameEn, String governorate, String city, String? area, String addressDetails, String? landmark, String? mapUrl, String? email, List<BranchPhone> phones
});




}
/// @nodoc
class __$RegistrationBranchCopyWithImpl<$Res>
    implements _$RegistrationBranchCopyWith<$Res> {
  __$RegistrationBranchCopyWithImpl(this._self, this._then);

  final _RegistrationBranch _self;
  final $Res Function(_RegistrationBranch) _then;

/// Create a copy of RegistrationBranch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? nameAr = null,Object? nameEn = freezed,Object? governorate = null,Object? city = null,Object? area = freezed,Object? addressDetails = null,Object? landmark = freezed,Object? mapUrl = freezed,Object? email = freezed,Object? phones = null,}) {
  return _then(_RegistrationBranch(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,nameAr: null == nameAr ? _self.nameAr : nameAr // ignore: cast_nullable_to_non_nullable
as String,nameEn: freezed == nameEn ? _self.nameEn : nameEn // ignore: cast_nullable_to_non_nullable
as String?,governorate: null == governorate ? _self.governorate : governorate // ignore: cast_nullable_to_non_nullable
as String,city: null == city ? _self.city : city // ignore: cast_nullable_to_non_nullable
as String,area: freezed == area ? _self.area : area // ignore: cast_nullable_to_non_nullable
as String?,addressDetails: null == addressDetails ? _self.addressDetails : addressDetails // ignore: cast_nullable_to_non_nullable
as String,landmark: freezed == landmark ? _self.landmark : landmark // ignore: cast_nullable_to_non_nullable
as String?,mapUrl: freezed == mapUrl ? _self.mapUrl : mapUrl // ignore: cast_nullable_to_non_nullable
as String?,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,phones: null == phones ? _self._phones : phones // ignore: cast_nullable_to_non_nullable
as List<BranchPhone>,
  ));
}


}


/// @nodoc
mixin _$BranchPhone {

 String get number; String get label; bool get isWhatsapp;
/// Create a copy of BranchPhone
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BranchPhoneCopyWith<BranchPhone> get copyWith => _$BranchPhoneCopyWithImpl<BranchPhone>(this as BranchPhone, _$identity);

  /// Serializes this BranchPhone to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BranchPhone&&(identical(other.number, number) || other.number == number)&&(identical(other.label, label) || other.label == label)&&(identical(other.isWhatsapp, isWhatsapp) || other.isWhatsapp == isWhatsapp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,label,isWhatsapp);

@override
String toString() {
  return 'BranchPhone(number: $number, label: $label, isWhatsapp: $isWhatsapp)';
}


}

/// @nodoc
abstract mixin class $BranchPhoneCopyWith<$Res>  {
  factory $BranchPhoneCopyWith(BranchPhone value, $Res Function(BranchPhone) _then) = _$BranchPhoneCopyWithImpl;
@useResult
$Res call({
 String number, String label, bool isWhatsapp
});




}
/// @nodoc
class _$BranchPhoneCopyWithImpl<$Res>
    implements $BranchPhoneCopyWith<$Res> {
  _$BranchPhoneCopyWithImpl(this._self, this._then);

  final BranchPhone _self;
  final $Res Function(BranchPhone) _then;

/// Create a copy of BranchPhone
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? number = null,Object? label = null,Object? isWhatsapp = null,}) {
  return _then(_self.copyWith(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isWhatsapp: null == isWhatsapp ? _self.isWhatsapp : isWhatsapp // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BranchPhone].
extension BranchPhonePatterns on BranchPhone {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BranchPhone value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BranchPhone() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BranchPhone value)  $default,){
final _that = this;
switch (_that) {
case _BranchPhone():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BranchPhone value)?  $default,){
final _that = this;
switch (_that) {
case _BranchPhone() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String number,  String label,  bool isWhatsapp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BranchPhone() when $default != null:
return $default(_that.number,_that.label,_that.isWhatsapp);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String number,  String label,  bool isWhatsapp)  $default,) {final _that = this;
switch (_that) {
case _BranchPhone():
return $default(_that.number,_that.label,_that.isWhatsapp);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String number,  String label,  bool isWhatsapp)?  $default,) {final _that = this;
switch (_that) {
case _BranchPhone() when $default != null:
return $default(_that.number,_that.label,_that.isWhatsapp);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BranchPhone implements BranchPhone {
  const _BranchPhone({required this.number, this.label = BranchPhone.reception, this.isWhatsapp = false});
  factory _BranchPhone.fromJson(Map<String, dynamic> json) => _$BranchPhoneFromJson(json);

@override final  String number;
@override@JsonKey() final  String label;
@override@JsonKey() final  bool isWhatsapp;

/// Create a copy of BranchPhone
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BranchPhoneCopyWith<_BranchPhone> get copyWith => __$BranchPhoneCopyWithImpl<_BranchPhone>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BranchPhoneToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BranchPhone&&(identical(other.number, number) || other.number == number)&&(identical(other.label, label) || other.label == label)&&(identical(other.isWhatsapp, isWhatsapp) || other.isWhatsapp == isWhatsapp));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,number,label,isWhatsapp);

@override
String toString() {
  return 'BranchPhone(number: $number, label: $label, isWhatsapp: $isWhatsapp)';
}


}

/// @nodoc
abstract mixin class _$BranchPhoneCopyWith<$Res> implements $BranchPhoneCopyWith<$Res> {
  factory _$BranchPhoneCopyWith(_BranchPhone value, $Res Function(_BranchPhone) _then) = __$BranchPhoneCopyWithImpl;
@override @useResult
$Res call({
 String number, String label, bool isWhatsapp
});




}
/// @nodoc
class __$BranchPhoneCopyWithImpl<$Res>
    implements _$BranchPhoneCopyWith<$Res> {
  __$BranchPhoneCopyWithImpl(this._self, this._then);

  final _BranchPhone _self;
  final $Res Function(_BranchPhone) _then;

/// Create a copy of BranchPhone
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? number = null,Object? label = null,Object? isWhatsapp = null,}) {
  return _then(_BranchPhone(
number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isWhatsapp: null == isWhatsapp ? _self.isWhatsapp : isWhatsapp // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$DoctorRegistration {

 String get doctorId;@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? get status; String? get statusReason;/// The latest submission (the first one, or the last resubmission).
 DateTime? get submittedAt; DateTime? get approvedAt; String get fullName; String? get email; bool get emailVerified; String? get phone; String get locale; String get title; Specialty get specialty; List<Specialty> get extraSpecialties; String get licenseNumber;/// `image/jpeg`, `image/png`, `image/webp` or `application/pdf`.
 String? get licenseContentType; String? get fullNameEn; String? get titleEn; String? get degreesAr; String? get degreesEn; int? get examinationPricePiasters; int? get consultationPricePiasters; RegistrationBranch? get branch;
/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DoctorRegistrationCopyWith<DoctorRegistration> get copyWith => _$DoctorRegistrationCopyWithImpl<DoctorRegistration>(this as DoctorRegistration, _$identity);

  /// Serializes this DoctorRegistration to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DoctorRegistration&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.status, status) || other.status == status)&&(identical(other.statusReason, statusReason) || other.statusReason == statusReason)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.title, title) || other.title == title)&&(identical(other.specialty, specialty) || other.specialty == specialty)&&const DeepCollectionEquality().equals(other.extraSpecialties, extraSpecialties)&&(identical(other.licenseNumber, licenseNumber) || other.licenseNumber == licenseNumber)&&(identical(other.licenseContentType, licenseContentType) || other.licenseContentType == licenseContentType)&&(identical(other.fullNameEn, fullNameEn) || other.fullNameEn == fullNameEn)&&(identical(other.titleEn, titleEn) || other.titleEn == titleEn)&&(identical(other.degreesAr, degreesAr) || other.degreesAr == degreesAr)&&(identical(other.degreesEn, degreesEn) || other.degreesEn == degreesEn)&&(identical(other.examinationPricePiasters, examinationPricePiasters) || other.examinationPricePiasters == examinationPricePiasters)&&(identical(other.consultationPricePiasters, consultationPricePiasters) || other.consultationPricePiasters == consultationPricePiasters)&&(identical(other.branch, branch) || other.branch == branch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,doctorId,status,statusReason,submittedAt,approvedAt,fullName,email,emailVerified,phone,locale,title,specialty,const DeepCollectionEquality().hash(extraSpecialties),licenseNumber,licenseContentType,fullNameEn,titleEn,degreesAr,degreesEn,examinationPricePiasters,consultationPricePiasters,branch]);

@override
String toString() {
  return 'DoctorRegistration(doctorId: $doctorId, status: $status, statusReason: $statusReason, submittedAt: $submittedAt, approvedAt: $approvedAt, fullName: $fullName, email: $email, emailVerified: $emailVerified, phone: $phone, locale: $locale, title: $title, specialty: $specialty, extraSpecialties: $extraSpecialties, licenseNumber: $licenseNumber, licenseContentType: $licenseContentType, fullNameEn: $fullNameEn, titleEn: $titleEn, degreesAr: $degreesAr, degreesEn: $degreesEn, examinationPricePiasters: $examinationPricePiasters, consultationPricePiasters: $consultationPricePiasters, branch: $branch)';
}


}

/// @nodoc
abstract mixin class $DoctorRegistrationCopyWith<$Res>  {
  factory $DoctorRegistrationCopyWith(DoctorRegistration value, $Res Function(DoctorRegistration) _then) = _$DoctorRegistrationCopyWithImpl;
@useResult
$Res call({
 String doctorId,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? status, String? statusReason, DateTime? submittedAt, DateTime? approvedAt, String fullName, String? email, bool emailVerified, String? phone, String locale, String title, Specialty specialty, List<Specialty> extraSpecialties, String licenseNumber, String? licenseContentType, String? fullNameEn, String? titleEn, String? degreesAr, String? degreesEn, int? examinationPricePiasters, int? consultationPricePiasters, RegistrationBranch? branch
});


$SpecialtyCopyWith<$Res> get specialty;$RegistrationBranchCopyWith<$Res>? get branch;

}
/// @nodoc
class _$DoctorRegistrationCopyWithImpl<$Res>
    implements $DoctorRegistrationCopyWith<$Res> {
  _$DoctorRegistrationCopyWithImpl(this._self, this._then);

  final DoctorRegistration _self;
  final $Res Function(DoctorRegistration) _then;

/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? doctorId = null,Object? status = freezed,Object? statusReason = freezed,Object? submittedAt = freezed,Object? approvedAt = freezed,Object? fullName = null,Object? email = freezed,Object? emailVerified = null,Object? phone = freezed,Object? locale = null,Object? title = null,Object? specialty = null,Object? extraSpecialties = null,Object? licenseNumber = null,Object? licenseContentType = freezed,Object? fullNameEn = freezed,Object? titleEn = freezed,Object? degreesAr = freezed,Object? degreesEn = freezed,Object? examinationPricePiasters = freezed,Object? consultationPricePiasters = freezed,Object? branch = freezed,}) {
  return _then(_self.copyWith(
doctorId: null == doctorId ? _self.doctorId : doctorId // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DoctorStatus?,statusReason: freezed == statusReason ? _self.statusReason : statusReason // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,specialty: null == specialty ? _self.specialty : specialty // ignore: cast_nullable_to_non_nullable
as Specialty,extraSpecialties: null == extraSpecialties ? _self.extraSpecialties : extraSpecialties // ignore: cast_nullable_to_non_nullable
as List<Specialty>,licenseNumber: null == licenseNumber ? _self.licenseNumber : licenseNumber // ignore: cast_nullable_to_non_nullable
as String,licenseContentType: freezed == licenseContentType ? _self.licenseContentType : licenseContentType // ignore: cast_nullable_to_non_nullable
as String?,fullNameEn: freezed == fullNameEn ? _self.fullNameEn : fullNameEn // ignore: cast_nullable_to_non_nullable
as String?,titleEn: freezed == titleEn ? _self.titleEn : titleEn // ignore: cast_nullable_to_non_nullable
as String?,degreesAr: freezed == degreesAr ? _self.degreesAr : degreesAr // ignore: cast_nullable_to_non_nullable
as String?,degreesEn: freezed == degreesEn ? _self.degreesEn : degreesEn // ignore: cast_nullable_to_non_nullable
as String?,examinationPricePiasters: freezed == examinationPricePiasters ? _self.examinationPricePiasters : examinationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,consultationPricePiasters: freezed == consultationPricePiasters ? _self.consultationPricePiasters : consultationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as RegistrationBranch?,
  ));
}
/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpecialtyCopyWith<$Res> get specialty {
  
  return $SpecialtyCopyWith<$Res>(_self.specialty, (value) {
    return _then(_self.copyWith(specialty: value));
  });
}/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RegistrationBranchCopyWith<$Res>? get branch {
    if (_self.branch == null) {
    return null;
  }

  return $RegistrationBranchCopyWith<$Res>(_self.branch!, (value) {
    return _then(_self.copyWith(branch: value));
  });
}
}


/// Adds pattern-matching-related methods to [DoctorRegistration].
extension DoctorRegistrationPatterns on DoctorRegistration {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DoctorRegistration value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DoctorRegistration() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DoctorRegistration value)  $default,){
final _that = this;
switch (_that) {
case _DoctorRegistration():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DoctorRegistration value)?  $default,){
final _that = this;
switch (_that) {
case _DoctorRegistration() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? status,  String? statusReason,  DateTime? submittedAt,  DateTime? approvedAt,  String fullName,  String? email,  bool emailVerified,  String? phone,  String locale,  String title,  Specialty specialty,  List<Specialty> extraSpecialties,  String licenseNumber,  String? licenseContentType,  String? fullNameEn,  String? titleEn,  String? degreesAr,  String? degreesEn,  int? examinationPricePiasters,  int? consultationPricePiasters,  RegistrationBranch? branch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DoctorRegistration() when $default != null:
return $default(_that.doctorId,_that.status,_that.statusReason,_that.submittedAt,_that.approvedAt,_that.fullName,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.title,_that.specialty,_that.extraSpecialties,_that.licenseNumber,_that.licenseContentType,_that.fullNameEn,_that.titleEn,_that.degreesAr,_that.degreesEn,_that.examinationPricePiasters,_that.consultationPricePiasters,_that.branch);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? status,  String? statusReason,  DateTime? submittedAt,  DateTime? approvedAt,  String fullName,  String? email,  bool emailVerified,  String? phone,  String locale,  String title,  Specialty specialty,  List<Specialty> extraSpecialties,  String licenseNumber,  String? licenseContentType,  String? fullNameEn,  String? titleEn,  String? degreesAr,  String? degreesEn,  int? examinationPricePiasters,  int? consultationPricePiasters,  RegistrationBranch? branch)  $default,) {final _that = this;
switch (_that) {
case _DoctorRegistration():
return $default(_that.doctorId,_that.status,_that.statusReason,_that.submittedAt,_that.approvedAt,_that.fullName,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.title,_that.specialty,_that.extraSpecialties,_that.licenseNumber,_that.licenseContentType,_that.fullNameEn,_that.titleEn,_that.degreesAr,_that.degreesEn,_that.examinationPricePiasters,_that.consultationPricePiasters,_that.branch);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? status,  String? statusReason,  DateTime? submittedAt,  DateTime? approvedAt,  String fullName,  String? email,  bool emailVerified,  String? phone,  String locale,  String title,  Specialty specialty,  List<Specialty> extraSpecialties,  String licenseNumber,  String? licenseContentType,  String? fullNameEn,  String? titleEn,  String? degreesAr,  String? degreesEn,  int? examinationPricePiasters,  int? consultationPricePiasters,  RegistrationBranch? branch)?  $default,) {final _that = this;
switch (_that) {
case _DoctorRegistration() when $default != null:
return $default(_that.doctorId,_that.status,_that.statusReason,_that.submittedAt,_that.approvedAt,_that.fullName,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.title,_that.specialty,_that.extraSpecialties,_that.licenseNumber,_that.licenseContentType,_that.fullNameEn,_that.titleEn,_that.degreesAr,_that.degreesEn,_that.examinationPricePiasters,_that.consultationPricePiasters,_that.branch);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DoctorRegistration extends DoctorRegistration {
  const _DoctorRegistration({this.doctorId = '', @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.status, this.statusReason, this.submittedAt, this.approvedAt, this.fullName = '', this.email, this.emailVerified = false, this.phone, this.locale = 'ar', this.title = '', required this.specialty, final  List<Specialty> extraSpecialties = const <Specialty>[], this.licenseNumber = '', this.licenseContentType, this.fullNameEn, this.titleEn, this.degreesAr, this.degreesEn, this.examinationPricePiasters, this.consultationPricePiasters, this.branch}): _extraSpecialties = extraSpecialties,super._();
  factory _DoctorRegistration.fromJson(Map<String, dynamic> json) => _$DoctorRegistrationFromJson(json);

@override@JsonKey() final  String doctorId;
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  DoctorStatus? status;
@override final  String? statusReason;
/// The latest submission (the first one, or the last resubmission).
@override final  DateTime? submittedAt;
@override final  DateTime? approvedAt;
@override@JsonKey() final  String fullName;
@override final  String? email;
@override@JsonKey() final  bool emailVerified;
@override final  String? phone;
@override@JsonKey() final  String locale;
@override@JsonKey() final  String title;
@override final  Specialty specialty;
 final  List<Specialty> _extraSpecialties;
@override@JsonKey() List<Specialty> get extraSpecialties {
  if (_extraSpecialties is EqualUnmodifiableListView) return _extraSpecialties;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_extraSpecialties);
}

@override@JsonKey() final  String licenseNumber;
/// `image/jpeg`, `image/png`, `image/webp` or `application/pdf`.
@override final  String? licenseContentType;
@override final  String? fullNameEn;
@override final  String? titleEn;
@override final  String? degreesAr;
@override final  String? degreesEn;
@override final  int? examinationPricePiasters;
@override final  int? consultationPricePiasters;
@override final  RegistrationBranch? branch;

/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DoctorRegistrationCopyWith<_DoctorRegistration> get copyWith => __$DoctorRegistrationCopyWithImpl<_DoctorRegistration>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DoctorRegistrationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DoctorRegistration&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.status, status) || other.status == status)&&(identical(other.statusReason, statusReason) || other.statusReason == statusReason)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.approvedAt, approvedAt) || other.approvedAt == approvedAt)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.title, title) || other.title == title)&&(identical(other.specialty, specialty) || other.specialty == specialty)&&const DeepCollectionEquality().equals(other._extraSpecialties, _extraSpecialties)&&(identical(other.licenseNumber, licenseNumber) || other.licenseNumber == licenseNumber)&&(identical(other.licenseContentType, licenseContentType) || other.licenseContentType == licenseContentType)&&(identical(other.fullNameEn, fullNameEn) || other.fullNameEn == fullNameEn)&&(identical(other.titleEn, titleEn) || other.titleEn == titleEn)&&(identical(other.degreesAr, degreesAr) || other.degreesAr == degreesAr)&&(identical(other.degreesEn, degreesEn) || other.degreesEn == degreesEn)&&(identical(other.examinationPricePiasters, examinationPricePiasters) || other.examinationPricePiasters == examinationPricePiasters)&&(identical(other.consultationPricePiasters, consultationPricePiasters) || other.consultationPricePiasters == consultationPricePiasters)&&(identical(other.branch, branch) || other.branch == branch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,doctorId,status,statusReason,submittedAt,approvedAt,fullName,email,emailVerified,phone,locale,title,specialty,const DeepCollectionEquality().hash(_extraSpecialties),licenseNumber,licenseContentType,fullNameEn,titleEn,degreesAr,degreesEn,examinationPricePiasters,consultationPricePiasters,branch]);

@override
String toString() {
  return 'DoctorRegistration(doctorId: $doctorId, status: $status, statusReason: $statusReason, submittedAt: $submittedAt, approvedAt: $approvedAt, fullName: $fullName, email: $email, emailVerified: $emailVerified, phone: $phone, locale: $locale, title: $title, specialty: $specialty, extraSpecialties: $extraSpecialties, licenseNumber: $licenseNumber, licenseContentType: $licenseContentType, fullNameEn: $fullNameEn, titleEn: $titleEn, degreesAr: $degreesAr, degreesEn: $degreesEn, examinationPricePiasters: $examinationPricePiasters, consultationPricePiasters: $consultationPricePiasters, branch: $branch)';
}


}

/// @nodoc
abstract mixin class _$DoctorRegistrationCopyWith<$Res> implements $DoctorRegistrationCopyWith<$Res> {
  factory _$DoctorRegistrationCopyWith(_DoctorRegistration value, $Res Function(_DoctorRegistration) _then) = __$DoctorRegistrationCopyWithImpl;
@override @useResult
$Res call({
 String doctorId,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? status, String? statusReason, DateTime? submittedAt, DateTime? approvedAt, String fullName, String? email, bool emailVerified, String? phone, String locale, String title, Specialty specialty, List<Specialty> extraSpecialties, String licenseNumber, String? licenseContentType, String? fullNameEn, String? titleEn, String? degreesAr, String? degreesEn, int? examinationPricePiasters, int? consultationPricePiasters, RegistrationBranch? branch
});


@override $SpecialtyCopyWith<$Res> get specialty;@override $RegistrationBranchCopyWith<$Res>? get branch;

}
/// @nodoc
class __$DoctorRegistrationCopyWithImpl<$Res>
    implements _$DoctorRegistrationCopyWith<$Res> {
  __$DoctorRegistrationCopyWithImpl(this._self, this._then);

  final _DoctorRegistration _self;
  final $Res Function(_DoctorRegistration) _then;

/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? doctorId = null,Object? status = freezed,Object? statusReason = freezed,Object? submittedAt = freezed,Object? approvedAt = freezed,Object? fullName = null,Object? email = freezed,Object? emailVerified = null,Object? phone = freezed,Object? locale = null,Object? title = null,Object? specialty = null,Object? extraSpecialties = null,Object? licenseNumber = null,Object? licenseContentType = freezed,Object? fullNameEn = freezed,Object? titleEn = freezed,Object? degreesAr = freezed,Object? degreesEn = freezed,Object? examinationPricePiasters = freezed,Object? consultationPricePiasters = freezed,Object? branch = freezed,}) {
  return _then(_DoctorRegistration(
doctorId: null == doctorId ? _self.doctorId : doctorId // ignore: cast_nullable_to_non_nullable
as String,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DoctorStatus?,statusReason: freezed == statusReason ? _self.statusReason : statusReason // ignore: cast_nullable_to_non_nullable
as String?,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,approvedAt: freezed == approvedAt ? _self.approvedAt : approvedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
as String,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,specialty: null == specialty ? _self.specialty : specialty // ignore: cast_nullable_to_non_nullable
as Specialty,extraSpecialties: null == extraSpecialties ? _self._extraSpecialties : extraSpecialties // ignore: cast_nullable_to_non_nullable
as List<Specialty>,licenseNumber: null == licenseNumber ? _self.licenseNumber : licenseNumber // ignore: cast_nullable_to_non_nullable
as String,licenseContentType: freezed == licenseContentType ? _self.licenseContentType : licenseContentType // ignore: cast_nullable_to_non_nullable
as String?,fullNameEn: freezed == fullNameEn ? _self.fullNameEn : fullNameEn // ignore: cast_nullable_to_non_nullable
as String?,titleEn: freezed == titleEn ? _self.titleEn : titleEn // ignore: cast_nullable_to_non_nullable
as String?,degreesAr: freezed == degreesAr ? _self.degreesAr : degreesAr // ignore: cast_nullable_to_non_nullable
as String?,degreesEn: freezed == degreesEn ? _self.degreesEn : degreesEn // ignore: cast_nullable_to_non_nullable
as String?,examinationPricePiasters: freezed == examinationPricePiasters ? _self.examinationPricePiasters : examinationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,consultationPricePiasters: freezed == consultationPricePiasters ? _self.consultationPricePiasters : consultationPricePiasters // ignore: cast_nullable_to_non_nullable
as int?,branch: freezed == branch ? _self.branch : branch // ignore: cast_nullable_to_non_nullable
as RegistrationBranch?,
  ));
}

/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SpecialtyCopyWith<$Res> get specialty {
  
  return $SpecialtyCopyWith<$Res>(_self.specialty, (value) {
    return _then(_self.copyWith(specialty: value));
  });
}/// Create a copy of DoctorRegistration
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$RegistrationBranchCopyWith<$Res>? get branch {
    if (_self.branch == null) {
    return null;
  }

  return $RegistrationBranchCopyWith<$Res>(_self.branch!, (value) {
    return _then(_self.copyWith(branch: value));
  });
}
}

// dart format on
