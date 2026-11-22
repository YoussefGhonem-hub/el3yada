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
 bool get emailVerified; String? get phone; String get locale; String get themeMode;/// The clinic's free trial (backend/docs/api-free-trial.md): a doctor's
/// own, an assistant's doctor's. Null when there is none (the service is
/// active) and for other roles.
 TrialInfo? get trial;/// `active`, or `pendingDeletion` during the account's deletion grace
/// period (backend/docs/api-account-deletion.md).
 String get accountStatus;/// The account's deletion in progress: the app shows only A16 (restore,
/// sign out and, for a doctor, pay invoices). Null otherwise.
 PendingDeletion? get pendingDeletion; String get accessToken; DateTime? get accessTokenExpiresAt; String get refreshToken; DateTime? get refreshTokenExpiresAt;
/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthSessionCopyWith<AuthSession> get copyWith => _$AuthSessionCopyWithImpl<AuthSession>(this as AuthSession, _$identity);

  /// Serializes this AuthSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthSession&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.adminRole, adminRole) || other.adminRole == adminRole)&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.doctorStatus, doctorStatus) || other.doctorStatus == doctorStatus)&&(identical(other.doctorStatusReason, doctorStatusReason) || other.doctorStatusReason == doctorStatusReason)&&(identical(other.mustChangePassword, mustChangePassword) || other.mustChangePassword == mustChangePassword)&&(identical(other.mustAcceptTerms, mustAcceptTerms) || other.mustAcceptTerms == mustAcceptTerms)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.trial, trial) || other.trial == trial)&&(identical(other.accountStatus, accountStatus) || other.accountStatus == accountStatus)&&(identical(other.pendingDeletion, pendingDeletion) || other.pendingDeletion == pendingDeletion)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.accessTokenExpiresAt, accessTokenExpiresAt) || other.accessTokenExpiresAt == accessTokenExpiresAt)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.refreshTokenExpiresAt, refreshTokenExpiresAt) || other.refreshTokenExpiresAt == refreshTokenExpiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,userId,displayName,role,adminRole,doctorId,doctorStatus,doctorStatusReason,mustChangePassword,mustAcceptTerms,email,emailVerified,phone,locale,themeMode,trial,accountStatus,pendingDeletion,accessToken,accessTokenExpiresAt,refreshToken,refreshTokenExpiresAt]);

@override
String toString() {
  return 'AuthSession(userId: $userId, displayName: $displayName, role: $role, adminRole: $adminRole, doctorId: $doctorId, doctorStatus: $doctorStatus, doctorStatusReason: $doctorStatusReason, mustChangePassword: $mustChangePassword, mustAcceptTerms: $mustAcceptTerms, email: $email, emailVerified: $emailVerified, phone: $phone, locale: $locale, themeMode: $themeMode, trial: $trial, accountStatus: $accountStatus, pendingDeletion: $pendingDeletion, accessToken: $accessToken, accessTokenExpiresAt: $accessTokenExpiresAt, refreshToken: $refreshToken, refreshTokenExpiresAt: $refreshTokenExpiresAt)';
}


}

/// @nodoc
abstract mixin class $AuthSessionCopyWith<$Res>  {
  factory $AuthSessionCopyWith(AuthSession value, $Res Function(AuthSession) _then) = _$AuthSessionCopyWithImpl;
@useResult
$Res call({
 String userId, String displayName, UserRole role, String? adminRole, String? doctorId,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? doctorStatus, String? doctorStatusReason, bool mustChangePassword, bool mustAcceptTerms, String? email, bool emailVerified, String? phone, String locale, String themeMode, TrialInfo? trial, String accountStatus, PendingDeletion? pendingDeletion, String accessToken, DateTime? accessTokenExpiresAt, String refreshToken, DateTime? refreshTokenExpiresAt
});


$TrialInfoCopyWith<$Res>? get trial;$PendingDeletionCopyWith<$Res>? get pendingDeletion;

}
/// @nodoc
class _$AuthSessionCopyWithImpl<$Res>
    implements $AuthSessionCopyWith<$Res> {
  _$AuthSessionCopyWithImpl(this._self, this._then);

  final AuthSession _self;
  final $Res Function(AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? displayName = null,Object? role = null,Object? adminRole = freezed,Object? doctorId = freezed,Object? doctorStatus = freezed,Object? doctorStatusReason = freezed,Object? mustChangePassword = null,Object? mustAcceptTerms = null,Object? email = freezed,Object? emailVerified = null,Object? phone = freezed,Object? locale = null,Object? themeMode = null,Object? trial = freezed,Object? accountStatus = null,Object? pendingDeletion = freezed,Object? accessToken = null,Object? accessTokenExpiresAt = freezed,Object? refreshToken = null,Object? refreshTokenExpiresAt = freezed,}) {
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
as String,trial: freezed == trial ? _self.trial : trial // ignore: cast_nullable_to_non_nullable
as TrialInfo?,accountStatus: null == accountStatus ? _self.accountStatus : accountStatus // ignore: cast_nullable_to_non_nullable
as String,pendingDeletion: freezed == pendingDeletion ? _self.pendingDeletion : pendingDeletion // ignore: cast_nullable_to_non_nullable
as PendingDeletion?,accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,accessTokenExpiresAt: freezed == accessTokenExpiresAt ? _self.accessTokenExpiresAt : accessTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,refreshTokenExpiresAt: freezed == refreshTokenExpiresAt ? _self.refreshTokenExpiresAt : refreshTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrialInfoCopyWith<$Res>? get trial {
    if (_self.trial == null) {
    return null;
  }

  return $TrialInfoCopyWith<$Res>(_self.trial!, (value) {
    return _then(_self.copyWith(trial: value));
  });
}/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PendingDeletionCopyWith<$Res>? get pendingDeletion {
    if (_self.pendingDeletion == null) {
    return null;
  }

  return $PendingDeletionCopyWith<$Res>(_self.pendingDeletion!, (value) {
    return _then(_self.copyWith(pendingDeletion: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  String displayName,  UserRole role,  String? adminRole,  String? doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? doctorStatus,  String? doctorStatusReason,  bool mustChangePassword,  bool mustAcceptTerms,  String? email,  bool emailVerified,  String? phone,  String locale,  String themeMode,  TrialInfo? trial,  String accountStatus,  PendingDeletion? pendingDeletion,  String accessToken,  DateTime? accessTokenExpiresAt,  String refreshToken,  DateTime? refreshTokenExpiresAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that.userId,_that.displayName,_that.role,_that.adminRole,_that.doctorId,_that.doctorStatus,_that.doctorStatusReason,_that.mustChangePassword,_that.mustAcceptTerms,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.themeMode,_that.trial,_that.accountStatus,_that.pendingDeletion,_that.accessToken,_that.accessTokenExpiresAt,_that.refreshToken,_that.refreshTokenExpiresAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  String displayName,  UserRole role,  String? adminRole,  String? doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? doctorStatus,  String? doctorStatusReason,  bool mustChangePassword,  bool mustAcceptTerms,  String? email,  bool emailVerified,  String? phone,  String locale,  String themeMode,  TrialInfo? trial,  String accountStatus,  PendingDeletion? pendingDeletion,  String accessToken,  DateTime? accessTokenExpiresAt,  String refreshToken,  DateTime? refreshTokenExpiresAt)  $default,) {final _that = this;
switch (_that) {
case _AuthSession():
return $default(_that.userId,_that.displayName,_that.role,_that.adminRole,_that.doctorId,_that.doctorStatus,_that.doctorStatusReason,_that.mustChangePassword,_that.mustAcceptTerms,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.themeMode,_that.trial,_that.accountStatus,_that.pendingDeletion,_that.accessToken,_that.accessTokenExpiresAt,_that.refreshToken,_that.refreshTokenExpiresAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  String displayName,  UserRole role,  String? adminRole,  String? doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue)  DoctorStatus? doctorStatus,  String? doctorStatusReason,  bool mustChangePassword,  bool mustAcceptTerms,  String? email,  bool emailVerified,  String? phone,  String locale,  String themeMode,  TrialInfo? trial,  String accountStatus,  PendingDeletion? pendingDeletion,  String accessToken,  DateTime? accessTokenExpiresAt,  String refreshToken,  DateTime? refreshTokenExpiresAt)?  $default,) {final _that = this;
switch (_that) {
case _AuthSession() when $default != null:
return $default(_that.userId,_that.displayName,_that.role,_that.adminRole,_that.doctorId,_that.doctorStatus,_that.doctorStatusReason,_that.mustChangePassword,_that.mustAcceptTerms,_that.email,_that.emailVerified,_that.phone,_that.locale,_that.themeMode,_that.trial,_that.accountStatus,_that.pendingDeletion,_that.accessToken,_that.accessTokenExpiresAt,_that.refreshToken,_that.refreshTokenExpiresAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AuthSession extends AuthSession {
  const _AuthSession({required this.userId, this.displayName = '', required this.role, this.adminRole, this.doctorId, @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) this.doctorStatus, this.doctorStatusReason, this.mustChangePassword = false, this.mustAcceptTerms = false, this.email, this.emailVerified = true, this.phone, this.locale = 'ar', this.themeMode = 'system', this.trial, this.accountStatus = 'active', this.pendingDeletion, required this.accessToken, this.accessTokenExpiresAt, required this.refreshToken, this.refreshTokenExpiresAt}): super._();
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
/// The clinic's free trial (backend/docs/api-free-trial.md): a doctor's
/// own, an assistant's doctor's. Null when there is none (the service is
/// active) and for other roles.
@override final  TrialInfo? trial;
/// `active`, or `pendingDeletion` during the account's deletion grace
/// period (backend/docs/api-account-deletion.md).
@override@JsonKey() final  String accountStatus;
/// The account's deletion in progress: the app shows only A16 (restore,
/// sign out and, for a doctor, pay invoices). Null otherwise.
@override final  PendingDeletion? pendingDeletion;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthSession&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.role, role) || other.role == role)&&(identical(other.adminRole, adminRole) || other.adminRole == adminRole)&&(identical(other.doctorId, doctorId) || other.doctorId == doctorId)&&(identical(other.doctorStatus, doctorStatus) || other.doctorStatus == doctorStatus)&&(identical(other.doctorStatusReason, doctorStatusReason) || other.doctorStatusReason == doctorStatusReason)&&(identical(other.mustChangePassword, mustChangePassword) || other.mustChangePassword == mustChangePassword)&&(identical(other.mustAcceptTerms, mustAcceptTerms) || other.mustAcceptTerms == mustAcceptTerms)&&(identical(other.email, email) || other.email == email)&&(identical(other.emailVerified, emailVerified) || other.emailVerified == emailVerified)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.trial, trial) || other.trial == trial)&&(identical(other.accountStatus, accountStatus) || other.accountStatus == accountStatus)&&(identical(other.pendingDeletion, pendingDeletion) || other.pendingDeletion == pendingDeletion)&&(identical(other.accessToken, accessToken) || other.accessToken == accessToken)&&(identical(other.accessTokenExpiresAt, accessTokenExpiresAt) || other.accessTokenExpiresAt == accessTokenExpiresAt)&&(identical(other.refreshToken, refreshToken) || other.refreshToken == refreshToken)&&(identical(other.refreshTokenExpiresAt, refreshTokenExpiresAt) || other.refreshTokenExpiresAt == refreshTokenExpiresAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,userId,displayName,role,adminRole,doctorId,doctorStatus,doctorStatusReason,mustChangePassword,mustAcceptTerms,email,emailVerified,phone,locale,themeMode,trial,accountStatus,pendingDeletion,accessToken,accessTokenExpiresAt,refreshToken,refreshTokenExpiresAt]);

@override
String toString() {
  return 'AuthSession(userId: $userId, displayName: $displayName, role: $role, adminRole: $adminRole, doctorId: $doctorId, doctorStatus: $doctorStatus, doctorStatusReason: $doctorStatusReason, mustChangePassword: $mustChangePassword, mustAcceptTerms: $mustAcceptTerms, email: $email, emailVerified: $emailVerified, phone: $phone, locale: $locale, themeMode: $themeMode, trial: $trial, accountStatus: $accountStatus, pendingDeletion: $pendingDeletion, accessToken: $accessToken, accessTokenExpiresAt: $accessTokenExpiresAt, refreshToken: $refreshToken, refreshTokenExpiresAt: $refreshTokenExpiresAt)';
}


}

/// @nodoc
abstract mixin class _$AuthSessionCopyWith<$Res> implements $AuthSessionCopyWith<$Res> {
  factory _$AuthSessionCopyWith(_AuthSession value, $Res Function(_AuthSession) _then) = __$AuthSessionCopyWithImpl;
@override @useResult
$Res call({
 String userId, String displayName, UserRole role, String? adminRole, String? doctorId,@JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? doctorStatus, String? doctorStatusReason, bool mustChangePassword, bool mustAcceptTerms, String? email, bool emailVerified, String? phone, String locale, String themeMode, TrialInfo? trial, String accountStatus, PendingDeletion? pendingDeletion, String accessToken, DateTime? accessTokenExpiresAt, String refreshToken, DateTime? refreshTokenExpiresAt
});


@override $TrialInfoCopyWith<$Res>? get trial;@override $PendingDeletionCopyWith<$Res>? get pendingDeletion;

}
/// @nodoc
class __$AuthSessionCopyWithImpl<$Res>
    implements _$AuthSessionCopyWith<$Res> {
  __$AuthSessionCopyWithImpl(this._self, this._then);

  final _AuthSession _self;
  final $Res Function(_AuthSession) _then;

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? displayName = null,Object? role = null,Object? adminRole = freezed,Object? doctorId = freezed,Object? doctorStatus = freezed,Object? doctorStatusReason = freezed,Object? mustChangePassword = null,Object? mustAcceptTerms = null,Object? email = freezed,Object? emailVerified = null,Object? phone = freezed,Object? locale = null,Object? themeMode = null,Object? trial = freezed,Object? accountStatus = null,Object? pendingDeletion = freezed,Object? accessToken = null,Object? accessTokenExpiresAt = freezed,Object? refreshToken = null,Object? refreshTokenExpiresAt = freezed,}) {
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
as String,trial: freezed == trial ? _self.trial : trial // ignore: cast_nullable_to_non_nullable
as TrialInfo?,accountStatus: null == accountStatus ? _self.accountStatus : accountStatus // ignore: cast_nullable_to_non_nullable
as String,pendingDeletion: freezed == pendingDeletion ? _self.pendingDeletion : pendingDeletion // ignore: cast_nullable_to_non_nullable
as PendingDeletion?,accessToken: null == accessToken ? _self.accessToken : accessToken // ignore: cast_nullable_to_non_nullable
as String,accessTokenExpiresAt: freezed == accessTokenExpiresAt ? _self.accessTokenExpiresAt : accessTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,refreshToken: null == refreshToken ? _self.refreshToken : refreshToken // ignore: cast_nullable_to_non_nullable
as String,refreshTokenExpiresAt: freezed == refreshTokenExpiresAt ? _self.refreshTokenExpiresAt : refreshTokenExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TrialInfoCopyWith<$Res>? get trial {
    if (_self.trial == null) {
    return null;
  }

  return $TrialInfoCopyWith<$Res>(_self.trial!, (value) {
    return _then(_self.copyWith(trial: value));
  });
}/// Create a copy of AuthSession
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PendingDeletionCopyWith<$Res>? get pendingDeletion {
    if (_self.pendingDeletion == null) {
    return null;
  }

  return $PendingDeletionCopyWith<$Res>(_self.pendingDeletion!, (value) {
    return _then(_self.copyWith(pendingDeletion: value));
  });
}
}


/// @nodoc
mixin _$TrialInfo {

/// UTC: the approval time plus the `trialDays` setting.
 DateTime get endsAt; bool get ended;/// Whole days left, rounded up; 0 once [ended].
 int get daysLeft;
/// Create a copy of TrialInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TrialInfoCopyWith<TrialInfo> get copyWith => _$TrialInfoCopyWithImpl<TrialInfo>(this as TrialInfo, _$identity);

  /// Serializes this TrialInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TrialInfo&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.ended, ended) || other.ended == ended)&&(identical(other.daysLeft, daysLeft) || other.daysLeft == daysLeft));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,endsAt,ended,daysLeft);

@override
String toString() {
  return 'TrialInfo(endsAt: $endsAt, ended: $ended, daysLeft: $daysLeft)';
}


}

/// @nodoc
abstract mixin class $TrialInfoCopyWith<$Res>  {
  factory $TrialInfoCopyWith(TrialInfo value, $Res Function(TrialInfo) _then) = _$TrialInfoCopyWithImpl;
@useResult
$Res call({
 DateTime endsAt, bool ended, int daysLeft
});




}
/// @nodoc
class _$TrialInfoCopyWithImpl<$Res>
    implements $TrialInfoCopyWith<$Res> {
  _$TrialInfoCopyWithImpl(this._self, this._then);

  final TrialInfo _self;
  final $Res Function(TrialInfo) _then;

/// Create a copy of TrialInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? endsAt = null,Object? ended = null,Object? daysLeft = null,}) {
  return _then(_self.copyWith(
endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,ended: null == ended ? _self.ended : ended // ignore: cast_nullable_to_non_nullable
as bool,daysLeft: null == daysLeft ? _self.daysLeft : daysLeft // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TrialInfo].
extension TrialInfoPatterns on TrialInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TrialInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TrialInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TrialInfo value)  $default,){
final _that = this;
switch (_that) {
case _TrialInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TrialInfo value)?  $default,){
final _that = this;
switch (_that) {
case _TrialInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime endsAt,  bool ended,  int daysLeft)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TrialInfo() when $default != null:
return $default(_that.endsAt,_that.ended,_that.daysLeft);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime endsAt,  bool ended,  int daysLeft)  $default,) {final _that = this;
switch (_that) {
case _TrialInfo():
return $default(_that.endsAt,_that.ended,_that.daysLeft);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime endsAt,  bool ended,  int daysLeft)?  $default,) {final _that = this;
switch (_that) {
case _TrialInfo() when $default != null:
return $default(_that.endsAt,_that.ended,_that.daysLeft);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TrialInfo extends TrialInfo {
  const _TrialInfo({required this.endsAt, this.ended = false, this.daysLeft = 0}): super._();
  factory _TrialInfo.fromJson(Map<String, dynamic> json) => _$TrialInfoFromJson(json);

/// UTC: the approval time plus the `trialDays` setting.
@override final  DateTime endsAt;
@override@JsonKey() final  bool ended;
/// Whole days left, rounded up; 0 once [ended].
@override@JsonKey() final  int daysLeft;

/// Create a copy of TrialInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TrialInfoCopyWith<_TrialInfo> get copyWith => __$TrialInfoCopyWithImpl<_TrialInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TrialInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TrialInfo&&(identical(other.endsAt, endsAt) || other.endsAt == endsAt)&&(identical(other.ended, ended) || other.ended == ended)&&(identical(other.daysLeft, daysLeft) || other.daysLeft == daysLeft));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,endsAt,ended,daysLeft);

@override
String toString() {
  return 'TrialInfo(endsAt: $endsAt, ended: $ended, daysLeft: $daysLeft)';
}


}

/// @nodoc
abstract mixin class _$TrialInfoCopyWith<$Res> implements $TrialInfoCopyWith<$Res> {
  factory _$TrialInfoCopyWith(_TrialInfo value, $Res Function(_TrialInfo) _then) = __$TrialInfoCopyWithImpl;
@override @useResult
$Res call({
 DateTime endsAt, bool ended, int daysLeft
});




}
/// @nodoc
class __$TrialInfoCopyWithImpl<$Res>
    implements _$TrialInfoCopyWith<$Res> {
  __$TrialInfoCopyWithImpl(this._self, this._then);

  final _TrialInfo _self;
  final $Res Function(_TrialInfo) _then;

/// Create a copy of TrialInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? endsAt = null,Object? ended = null,Object? daysLeft = null,}) {
  return _then(_TrialInfo(
endsAt: null == endsAt ? _self.endsAt : endsAt // ignore: cast_nullable_to_non_nullable
as DateTime,ended: null == ended ? _self.ended : ended // ignore: cast_nullable_to_non_nullable
as bool,daysLeft: null == daysLeft ? _self.daysLeft : daysLeft // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PendingDeletion {

 String get requestId;/// `scheduled`, or `waitingPayment` once a doctor's grace period
/// passed with an invoice unpaid.
 String get status; DateTime get requestedAt;/// When the identity is erased (for a doctor, once every invoice is paid).
 DateTime get scheduledFor; String? get reason;/// An admin started it (a support case).
 bool get requestedByAdmin;/// Doctors: the invoices still to pay, and their total in piasters.
 int get unpaidInvoices; int get outstandingPiasters;/// The erasure waits for those invoices, even after [scheduledFor].
 bool get waitsForPayment;
/// Create a copy of PendingDeletion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PendingDeletionCopyWith<PendingDeletion> get copyWith => _$PendingDeletionCopyWithImpl<PendingDeletion>(this as PendingDeletion, _$identity);

  /// Serializes this PendingDeletion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PendingDeletion&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.status, status) || other.status == status)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.requestedByAdmin, requestedByAdmin) || other.requestedByAdmin == requestedByAdmin)&&(identical(other.unpaidInvoices, unpaidInvoices) || other.unpaidInvoices == unpaidInvoices)&&(identical(other.outstandingPiasters, outstandingPiasters) || other.outstandingPiasters == outstandingPiasters)&&(identical(other.waitsForPayment, waitsForPayment) || other.waitsForPayment == waitsForPayment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,status,requestedAt,scheduledFor,reason,requestedByAdmin,unpaidInvoices,outstandingPiasters,waitsForPayment);

@override
String toString() {
  return 'PendingDeletion(requestId: $requestId, status: $status, requestedAt: $requestedAt, scheduledFor: $scheduledFor, reason: $reason, requestedByAdmin: $requestedByAdmin, unpaidInvoices: $unpaidInvoices, outstandingPiasters: $outstandingPiasters, waitsForPayment: $waitsForPayment)';
}


}

/// @nodoc
abstract mixin class $PendingDeletionCopyWith<$Res>  {
  factory $PendingDeletionCopyWith(PendingDeletion value, $Res Function(PendingDeletion) _then) = _$PendingDeletionCopyWithImpl;
@useResult
$Res call({
 String requestId, String status, DateTime requestedAt, DateTime scheduledFor, String? reason, bool requestedByAdmin, int unpaidInvoices, int outstandingPiasters, bool waitsForPayment
});




}
/// @nodoc
class _$PendingDeletionCopyWithImpl<$Res>
    implements $PendingDeletionCopyWith<$Res> {
  _$PendingDeletionCopyWithImpl(this._self, this._then);

  final PendingDeletion _self;
  final $Res Function(PendingDeletion) _then;

/// Create a copy of PendingDeletion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? requestId = null,Object? status = null,Object? requestedAt = null,Object? scheduledFor = null,Object? reason = freezed,Object? requestedByAdmin = null,Object? unpaidInvoices = null,Object? outstandingPiasters = null,Object? waitsForPayment = null,}) {
  return _then(_self.copyWith(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,requestedAt: null == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,requestedByAdmin: null == requestedByAdmin ? _self.requestedByAdmin : requestedByAdmin // ignore: cast_nullable_to_non_nullable
as bool,unpaidInvoices: null == unpaidInvoices ? _self.unpaidInvoices : unpaidInvoices // ignore: cast_nullable_to_non_nullable
as int,outstandingPiasters: null == outstandingPiasters ? _self.outstandingPiasters : outstandingPiasters // ignore: cast_nullable_to_non_nullable
as int,waitsForPayment: null == waitsForPayment ? _self.waitsForPayment : waitsForPayment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PendingDeletion].
extension PendingDeletionPatterns on PendingDeletion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PendingDeletion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PendingDeletion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PendingDeletion value)  $default,){
final _that = this;
switch (_that) {
case _PendingDeletion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PendingDeletion value)?  $default,){
final _that = this;
switch (_that) {
case _PendingDeletion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String requestId,  String status,  DateTime requestedAt,  DateTime scheduledFor,  String? reason,  bool requestedByAdmin,  int unpaidInvoices,  int outstandingPiasters,  bool waitsForPayment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PendingDeletion() when $default != null:
return $default(_that.requestId,_that.status,_that.requestedAt,_that.scheduledFor,_that.reason,_that.requestedByAdmin,_that.unpaidInvoices,_that.outstandingPiasters,_that.waitsForPayment);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String requestId,  String status,  DateTime requestedAt,  DateTime scheduledFor,  String? reason,  bool requestedByAdmin,  int unpaidInvoices,  int outstandingPiasters,  bool waitsForPayment)  $default,) {final _that = this;
switch (_that) {
case _PendingDeletion():
return $default(_that.requestId,_that.status,_that.requestedAt,_that.scheduledFor,_that.reason,_that.requestedByAdmin,_that.unpaidInvoices,_that.outstandingPiasters,_that.waitsForPayment);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String requestId,  String status,  DateTime requestedAt,  DateTime scheduledFor,  String? reason,  bool requestedByAdmin,  int unpaidInvoices,  int outstandingPiasters,  bool waitsForPayment)?  $default,) {final _that = this;
switch (_that) {
case _PendingDeletion() when $default != null:
return $default(_that.requestId,_that.status,_that.requestedAt,_that.scheduledFor,_that.reason,_that.requestedByAdmin,_that.unpaidInvoices,_that.outstandingPiasters,_that.waitsForPayment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PendingDeletion extends PendingDeletion {
  const _PendingDeletion({required this.requestId, this.status = 'scheduled', required this.requestedAt, required this.scheduledFor, this.reason, this.requestedByAdmin = false, this.unpaidInvoices = 0, this.outstandingPiasters = 0, this.waitsForPayment = false}): super._();
  factory _PendingDeletion.fromJson(Map<String, dynamic> json) => _$PendingDeletionFromJson(json);

@override final  String requestId;
/// `scheduled`, or `waitingPayment` once a doctor's grace period
/// passed with an invoice unpaid.
@override@JsonKey() final  String status;
@override final  DateTime requestedAt;
/// When the identity is erased (for a doctor, once every invoice is paid).
@override final  DateTime scheduledFor;
@override final  String? reason;
/// An admin started it (a support case).
@override@JsonKey() final  bool requestedByAdmin;
/// Doctors: the invoices still to pay, and their total in piasters.
@override@JsonKey() final  int unpaidInvoices;
@override@JsonKey() final  int outstandingPiasters;
/// The erasure waits for those invoices, even after [scheduledFor].
@override@JsonKey() final  bool waitsForPayment;

/// Create a copy of PendingDeletion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PendingDeletionCopyWith<_PendingDeletion> get copyWith => __$PendingDeletionCopyWithImpl<_PendingDeletion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PendingDeletionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PendingDeletion&&(identical(other.requestId, requestId) || other.requestId == requestId)&&(identical(other.status, status) || other.status == status)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.scheduledFor, scheduledFor) || other.scheduledFor == scheduledFor)&&(identical(other.reason, reason) || other.reason == reason)&&(identical(other.requestedByAdmin, requestedByAdmin) || other.requestedByAdmin == requestedByAdmin)&&(identical(other.unpaidInvoices, unpaidInvoices) || other.unpaidInvoices == unpaidInvoices)&&(identical(other.outstandingPiasters, outstandingPiasters) || other.outstandingPiasters == outstandingPiasters)&&(identical(other.waitsForPayment, waitsForPayment) || other.waitsForPayment == waitsForPayment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,requestId,status,requestedAt,scheduledFor,reason,requestedByAdmin,unpaidInvoices,outstandingPiasters,waitsForPayment);

@override
String toString() {
  return 'PendingDeletion(requestId: $requestId, status: $status, requestedAt: $requestedAt, scheduledFor: $scheduledFor, reason: $reason, requestedByAdmin: $requestedByAdmin, unpaidInvoices: $unpaidInvoices, outstandingPiasters: $outstandingPiasters, waitsForPayment: $waitsForPayment)';
}


}

/// @nodoc
abstract mixin class _$PendingDeletionCopyWith<$Res> implements $PendingDeletionCopyWith<$Res> {
  factory _$PendingDeletionCopyWith(_PendingDeletion value, $Res Function(_PendingDeletion) _then) = __$PendingDeletionCopyWithImpl;
@override @useResult
$Res call({
 String requestId, String status, DateTime requestedAt, DateTime scheduledFor, String? reason, bool requestedByAdmin, int unpaidInvoices, int outstandingPiasters, bool waitsForPayment
});




}
/// @nodoc
class __$PendingDeletionCopyWithImpl<$Res>
    implements _$PendingDeletionCopyWith<$Res> {
  __$PendingDeletionCopyWithImpl(this._self, this._then);

  final _PendingDeletion _self;
  final $Res Function(_PendingDeletion) _then;

/// Create a copy of PendingDeletion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? requestId = null,Object? status = null,Object? requestedAt = null,Object? scheduledFor = null,Object? reason = freezed,Object? requestedByAdmin = null,Object? unpaidInvoices = null,Object? outstandingPiasters = null,Object? waitsForPayment = null,}) {
  return _then(_PendingDeletion(
requestId: null == requestId ? _self.requestId : requestId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,requestedAt: null == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime,scheduledFor: null == scheduledFor ? _self.scheduledFor : scheduledFor // ignore: cast_nullable_to_non_nullable
as DateTime,reason: freezed == reason ? _self.reason : reason // ignore: cast_nullable_to_non_nullable
as String?,requestedByAdmin: null == requestedByAdmin ? _self.requestedByAdmin : requestedByAdmin // ignore: cast_nullable_to_non_nullable
as bool,unpaidInvoices: null == unpaidInvoices ? _self.unpaidInvoices : unpaidInvoices // ignore: cast_nullable_to_non_nullable
as int,outstandingPiasters: null == outstandingPiasters ? _self.outstandingPiasters : outstandingPiasters // ignore: cast_nullable_to_non_nullable
as int,waitsForPayment: null == waitsForPayment ? _self.waitsForPayment : waitsForPayment // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
