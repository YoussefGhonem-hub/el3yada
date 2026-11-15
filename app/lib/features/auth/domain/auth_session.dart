import 'user_role.dart';

/// The signed-in user, as returned by `POST /auth/login` (spec section 9.1).
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
    this.doctorId,
    this.mustChangePassword = false,
  });

  final String userId;
  final String displayName;
  final UserRole role;
  final String accessToken;
  final String refreshToken;

  /// For assistants: the doctor they work for (BR-AS3).
  final String? doctorId;

  /// Patients and assistants must set a new password at first login (A9).
  final bool mustChangePassword;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? '',
        role: UserRole.fromJson(json['role'] as String),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        doctorId: json['doctorId'] as String?,
        mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'role': role.toJson(),
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'doctorId': doctorId,
        'mustChangePassword': mustChangePassword,
      };
}
