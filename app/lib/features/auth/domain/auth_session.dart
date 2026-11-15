import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_role.dart';

part 'auth_session.freezed.dart';
part 'auth_session.g.dart';

/// The signed-in user, as returned by `POST /auth/login` (spec section 9.1).
///
/// API models use freezed + json_serializable. After changing one, run
/// `dart run build_runner build` and commit the generated files.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String userId,
    @Default('') String displayName,
    required UserRole role,
    required String accessToken,
    required String refreshToken,

    /// For assistants: the doctor they work for (BR-AS3).
    String? doctorId,

    /// Patients and assistants must set a new password at first login (A9).
    @Default(false) bool mustChangePassword,
  }) = _AuthSession;

  factory AuthSession.fromJson(Map<String, dynamic> json) => _$AuthSessionFromJson(json);
}
