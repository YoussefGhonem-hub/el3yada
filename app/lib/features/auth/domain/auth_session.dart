import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_role.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

/// The signed-in user and their tokens, as returned by every sign-in call
/// (`POST /api/auth/login`, `selectAccount`, `refresh`, `setNewPassword`,
/// `changePassword`, `completeDoctorRegistration`). `GET /api/auth/me` returns
/// the same fields without the tokens; apply it with [AuthSession.withAccount].
///
/// The contract is backend/docs/api-phase-1.md.
///
/// API models use freezed + json_serializable. After changing one, run
/// `dart run build_runner build` and commit the generated files.
@freezed
abstract class AuthSession with _$AuthSession {
  const AuthSession._();

  const factory AuthSession({
    required String userId,
    @Default('') String displayName,
    required UserRole role,

    /// `superAdmin` or `admin` for admins, otherwise null.
    String? adminRole,

    /// A doctor's own user ID, or an assistant's doctor (BR-AS3).
    String? doctorId,

    /// For a doctor, their status; for an assistant, their doctor's.
    /// Null for patients and admins, and for a value this app doesn't know.
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) DoctorStatus? doctorStatus,

    /// The admin's reason when a doctor is rejected (A7) or suspended.
    String? doctorStatusReason,

    /// The user must set a new password before anything else (A9).
    @Default(false) bool mustChangePassword,

    /// A patient who hasn't accepted the Terms yet: A9 shows the checkbox.
    @Default(false) bool mustAcceptTerms,
    String? email,

    /// False only when the account has an email that isn't verified (A5).
    @Default(true) bool emailVerified,
    String? phone,
    @Default('ar') String locale,
    @Default('system') String themeMode,
    required String accessToken,
    DateTime? accessTokenExpiresAt,
    required String refreshToken,
    DateTime? refreshTokenExpiresAt,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) => _$AuthSessionFromJson(json);

  bool get isSuperAdmin => adminRole == 'superAdmin';

  /// The same tokens with the account fields from `GET /api/auth/me`.
  /// (Round-trips through JSON text: `toJson` keeps enums and dates as objects.)
  AuthSession withAccount(Map<String, dynamic> account) {
    final merged = jsonDecode(jsonEncode({...toJson(), ...account})) as Map<String, dynamic>;
    return AuthSession.fromJson({
      ...merged,
      'accessToken': accessToken,
      'accessTokenExpiresAt': accessTokenExpiresAt?.toIso8601String(),
      'refreshToken': refreshToken,
      'refreshTokenExpiresAt': refreshTokenExpiresAt?.toIso8601String(),
    });
  }

  /// The access token expires within [margin] (refresh before sending).
  bool accessTokenExpiresWithin(Duration margin, DateTime now) =>
      accessTokenExpiresAt != null && accessTokenExpiresAt!.isBefore(now.add(margin));
}

/// `Doctors.Status` (spec 8). A disabled doctor never gets a session: the API
/// answers 403 `ACCOUNT_DISABLED` instead.
enum DoctorStatus { pendingApproval, active, rejected, suspended, disabled }
