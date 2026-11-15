// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_session.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuthSession {

 String get userId; String get displayName; UserRole get role;/// `superAdmin` or `admin` for admins, otherwise null.
 String? get adminRole;/// A doctor's own user ID, or an assistant's doctor (BR-AS3).
 String? get doctorId;/// For a doctor, their status; for an assistant, their doctor's.
/// Null for patients and admins, and for a value this app doesn't know.
@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? get doctorStatus;/// The admin's reason when a doctor is rejected (A7) or suspended.
 String? get doctorStatusReason;/// The user must set a new password before anything else (A9).
 bool get mustChangePassword;/// A patient who hasn't accepted the Terms yet: A9 shows the checkbox.
 bool get mustAcceptTerms; String? get email;/// False only when the account has an email that isn't verified (A5).
 bool get emailVerified; String? get phone; String get locale; String get themeMode; String get accessToken; DateTime? get accessTokenExpiresAt; String get refreshToken; DateTime? get refreshTokenExpiresAt;
/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSessionCopyWith<AuthSession> get copyWith => _$AuthSessionCopyWithImpl<AuthSession>(this as AuthSession, _$identity);

  /// Serializes this AuthSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSession&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.adminRole, adminRole) || other.adminRole == adminRole)&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.doctorStatus, doctorStatus) || other.doctorStatus == doctorStatus)&&(identical(other.doctorStatusReason, doctorStatusReason) || other.doctorStatusReason == doctorStatusReason)&&(identical(other.mustChangePassword, mustChangePassword) || other.mustChangePassword == mustChangePassword)&&(identical(other.mustAcceptTerms, mustAcceptTerms) || other.mustAcceptTerms == mustAcceptTerms)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.accessTokenExpiresAt, accessTokenExpiresAt) || other.accessTokenExpiresAt == accessTokenExpiresAt)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.refreshTokenExpiresAt, refreshTokenExpiresAt) || other.refreshTokenExpiresAt == refreshTokenExpiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,displayName,role,adminRole,doctorId,doctorStatus,doctorStatusReason,mustChangePassword,mustAcceptTerms,email,emailVerified,phone,locale,themeMode,accessToken,accessTokenExpiresAt,refreshToken,refreshTokenExpiresAt);

@override
String toString() {
  return 'AuthSession(userId: $userId, displayName: $displayName, role: $role, adminRole: $adminRole, doctorId: $doctorId, doctorStatus: $doctorStatus, doctorStatusReason: $doctorStatusReason, mustChangePassword: $mustChangePassword, mustAcceptTerms: $mustAcceptTerms, email: $email, emailVerified: $emailVerified, phone: $phone, locale: $locale, themeMode: $themeMode, accessToken: $accessToken, accessTokenExpiresAt: $accessTokenExpiresAt, refreshToken: $refreshToken, refreshTokenExpiresAt: $refreshTokenExpiresAt)';
}


}

/// @nodoc
abstract mixin class $AuthSessionCopyWith<$Res>  {
  factory $AuthSessionCopyWith(AuthSession value, $Res Function(AuthSession) _then) = _$AuthSessionCopyWithImpl;
@useResult
$Res call({
 String userId, String displayName, UserRole role, String? adminRole, String? doctorId,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? doctorStatus, String? doctorStatusReason, bool mustChangePassword, bool mustAcceptTerms, String? email, bool emailVerified, String? phone, String locale, String themeMode, String accessToken, DateTime? accessTokenExpiresAt, String refreshToken, DateTime? refreshTokenExpiresAt
});




}
/// @nodoc
class _$AuthSessionCopyWithImpl<$Res>
    implements $AuthSessionCopyWith<$Res> {
  _$AuthSessionCopyWithImpl(this._self, this._then);

  final AuthSession _self;
  final $Res Function(AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? displayName = null,Object? role = null,Object? adminRole = freezed,Object? doctorId = freezed,Object? doctorStatus = freezed,Object? doctorStatusReason = freezed,Object? mustChangePassword = null,Object? mustAcceptTerms = null,Object? email = freezed,Object? emailVerified = null,Object? phone = freezed,Object? locale = null,Object? themeMode = null,Object? accessToken = null,Object? accessTokenExpiresAt = freezed,Object? refreshToken = null,Object? refreshTokenExpiresAt = freezed,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,adminRole: freezed == adminRole ? _self.adminRole : adminRole // ignore: cast_nullable_to_non_nullable
as String?,doctorId: freezed == doctorId ? _self.doctorId : doctorId // ignore: cast_nullable_to_non_nullable
as String?,doctorStatus: freezed == doctorStatus ? _self.doctorStatus : doctorStatus // ignore: cast_nullable_to_non_nullable
as DoctorStatus?,doctorStatusReason: freezed == doctorStatusReason ? _self.doctorStatusReason : doctorStatusReason // ignore: cast_nullable_to_non_nullable
as String?,mustChangePassword: null == mustChangePassword ? _self.mustChangePassword : mustChangePassword // ignore: cast_nullable_to_non_nullable
as bool,mustAcceptTerms: null == mustAcceptTerms ? _self.mustAcceptTerms : mustAcceptTerms // ignore: cast_nullable_to_non_nullable
as bool,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as String,accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,accessTokenExpiresAt: freezed == accessTokenExpiresAt ? _self.accessTokenExpiresAt : accessTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,refreshTokenExpiresAt: freezed == refreshTokenExpiresAt ? _self.refreshTokenExpiresAt : refreshTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AuthSession].
extension AuthSessionPatterns on AuthSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthSession value)  $default,){
final _that = this;
switch (_that) {
case _AuthSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthSession value)?  $default,){
final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String displayName,  UserRole role,  String? adminRole,  String? doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? doctorStatus,  String? doctorStatusReason,  bool mustChangePassword,  bool mustAcceptTerms,  String? email,  bool emailVerified,  String? phone,  String locale,  String themeMode,  String accessToken,  DateTime? accessTokenExpiresAt,  String refreshToken,  DateTime? refreshTokenExpiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that.userId,_that.displayName,_that.role,_that.adminRole,_that.doctorId,_that.doctorStatus,_that.doctorStatusReason,_that.mustChangePassword,_that.mustAcceptTerms,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.themeMode,_that.accessToken,_that.accessTokenExpiresAt,_that.refreshToken,_that.refreshTokenExpiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String displayName,  UserRole role,  String? adminRole,  String? doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? doctorStatus,  String? doctorStatusReason,  bool mustChangePassword,  bool mustAcceptTerms,  String? email,  bool emailVerified,  String? phone,  String locale,  String themeMode,  String accessToken,  DateTime? accessTokenExpiresAt,  String refreshToken,  DateTime? refreshTokenExpiresAt)  $default,) {final _that = this;
switch (_that) {
case _AuthSession():
return $default(_that.userId,_that.displayName,_that.role,_that.adminRole,_that.doctorId,_that.doctorStatus,_that.doctorStatusReason,_that.mustChangePassword,_that.mustAcceptTerms,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.themeMode,_that.accessToken,_that.accessTokenExpiresAt,_that.refreshToken,_that.refreshTokenExpiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String displayName,  UserRole role,  String? adminRole,  String? doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? doctorStatus,  String? doctorStatusReason,  bool mustChangePassword,  bool mustAcceptTerms,  String? email,  bool emailVerified,  String? phone,  String locale,  String themeMode,  String accessToken,  DateTime? accessTokenExpiresAt,  String refreshToken,  DateTime? refreshTokenExpiresAt)?  $default,) {final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that.userId,_that.displayName,_that.role,_that.adminRole,_that.doctorId,_that.doctorStatus,_that.doctorStatusReason,_that.mustChangePassword,_that.mustAcceptTerms,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.themeMode,_that.accessToken,_that.accessTokenExpiresAt,_that.refreshToken,_that.refreshTokenExpiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthSession extends AuthSession {
  const _AuthSession({required this.userId, this.displayName = '', required this.role, this.adminRole, this.doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.doctorStatus, this.doctorStatusReason, this.mustChangePassword = false, this.mustAcceptTerms = false, this.email, this.emailVerified = true, this.phone, this.locale = 'ar', this.themeMode = 'system', required this.accessToken, this.accessTokenExpiresAt, required this.refreshToken, this.refreshTokenExpiresAt}): super._();
  factory _AuthSession.fromJson(Map<String, dynamic> json) => _$AuthSessionFromJson(json);

@override final  String userId;
@override@JsonKey() final  String displayName;
@override final  UserRole role;
/// `superAdmin` or `admin` for admins, otherwise null.
@override final  String? adminRole;
/// A doctor's own user ID, or an assistant's doctor (BR-AS3).
@override final  String? doctorId;
/// For a doctor, their status; for an assistant, their doctor's.
/// Null for patients and admins, and for a value this app doesn't know.
@override@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) final  DoctorStatus? doctorStatus;
/// The admin's reason when a doctor is rejected (A7) or suspended.
@override final  String? doctorStatusReason;
/// The user must set a new password before anything else (A9).
@override@JsonKey() final  bool mustChangePassword;
/// A patient who hasn't accepted the Terms yet: A9 shows the checkbox.
@override@JsonKey() final  bool mustAcceptTerms;
@override final  String? email;
/// False only when the account has an email that isn't verified (A5).
@override@JsonKey() final  bool emailVerified;
@override final  String? phone;
@override@JsonKey() final  String locale;
@override@JsonKey() final  String themeMode;
@override final  String accessToken;
@override final  DateTime? accessTokenExpiresAt;
@override final  String refreshToken;
@override final  DateTime? refreshTokenExpiresAt;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthSessionCopyWith<_AuthSession> get copyWith => __$AuthSessionCopyWithImpl<_AuthSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AuthSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthSession&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.adminRole, adminRole) || other.adminRole == adminRole)&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.doctorStatus, doctorStatus) || other.doctorStatus == doctorStatus)&&(identical(other.doctorStatusReason, doctorStatusReason) || other.doctorStatusReason == doctorStatusReason)&&(identical(other.mustChangePassword, mustChangePassword) || other.mustChangePassword == mustChangePassword)&&(identical(other.mustAcceptTerms, mustAcceptTerms) || other.mustAcceptTerms == mustAcceptTerms)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.accessTokenExpiresAt, accessTokenExpiresAt) || other.accessTokenExpiresAt == accessTokenExpiresAt)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.refreshTokenExpiresAt, refreshTokenExpiresAt) || other.refreshTokenExpiresAt == refreshTokenExpiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,displayName,role,adminRole,doctorId,doctorStatus,doctorStatusReason,mustChangePassword,mustAcceptTerms,email,emailVerified,phone,locale,themeMode,accessToken,accessTokenExpiresAt,refreshToken,refreshTokenExpiresAt);

@override
String toString() {
  return 'AuthSession(userId: $userId, displayName: $displayName, role: $role, adminRole: $adminRole, doctorId: $doctorId, doctorStatus: $doctorStatus, doctorStatusReason: $doctorStatusReason, mustChangePassword: $mustChangePassword, mustAcceptTerms: $mustAcceptTerms, email: $email, emailVerified: $emailVerified, phone: $phone, locale: $locale, themeMode: $themeMode, accessToken: $accessToken, accessTokenExpiresAt: $accessTokenExpiresAt, refreshToken: $refreshToken, refreshTokenExpiresAt: $refreshTokenExpiresAt)';
}


}

/// @nodoc
abstract mixin class _$AuthSessionCopyWith<$Res> implements $AuthSessionCopyWith<$Res> {
  factory _$AuthSessionCopyWith(_AuthSession value, $Res Function(_AuthSession) _then) = __$AuthSessionCopyWithImpl;
@override @useResult
$Res call({
 String userId, String displayName, UserRole role, String? adminRole, String? doctorId,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? doctorStatus, String? doctorStatusReason, bool mustChangePassword, bool mustAcceptTerms, String? email, bool emailVerified, String? phone, String locale, String themeMode, String accessToken, DateTime? accessTokenExpiresAt, String refreshToken, DateTime? refreshTokenExpiresAt
});




}
/// @nodoc
class __$AuthSessionCopyWithImpl<$Res>
    implements _$AuthSessionCopyWith<$Res> {
  __$AuthSessionCopyWithImpl(this._self, this._then);

  final _AuthSession _self;
  final $Res Function(_AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? displayName = null,Object? role = null,Object? adminRole = freezed,Object? doctorId = freezed,Object? doctorStatus = freezed,Object? doctorStatusReason = freezed,Object? mustChangePassword = null,Object? mustAcceptTerms = null,Object? email = freezed,Object? emailVerified = null,Object? phone = freezed,Object? locale = null,Object? themeMode = null,Object? accessToken = null,Object? accessTokenExpiresAt = freezed,Object? refreshToken = null,Object? refreshTokenExpiresAt = freezed,}) {
  return _then(_AuthSession(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as UserRole,adminRole: freezed == adminRole ? _self.adminRole : adminRole // ignore: cast_nullable_to_non_nullable
as String?,doctorId: freezed == doctorId ? _self.doctorId : doctorId // ignore: cast_nullable_to_non_nullable
as String?,doctorStatus: freezed == doctorStatus ? _self.doctorStatus : doctorStatus // ignore: cast_nullable_to_non_nullable
as DoctorStatus?,doctorStatusReason: freezed == doctorStatusReason ? _self.doctorStatusReason : doctorStatusReason // ignore: cast_nullable_to_non_nullable
as String?,mustChangePassword: null == mustChangePassword ? _self.mustChangePassword : mustChangePassword // ignore: cast_nullable_to_non_nullable
as bool,mustAcceptTerms: null == mustAcceptTerms ? _self.mustAcceptTerms : mustAcceptTerms // ignore: cast_nullable_to_non_nullable
as bool,email: freezed == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String?,emailVerified: null == emailVerified ? _self.emailVerified : emailVerified // ignore: cast_nullable_to_non_nullable
as bool,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,locale: null == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as String,accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,accessTokenExpiresAt: freezed == accessTokenExpiresAt ? _self.accessTokenExpiresAt : accessTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,refreshTokenExpiresAt: freezed == refreshTokenExpiresAt ? _self.refreshTokenExpiresAt : refreshTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
