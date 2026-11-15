import 'user_role.dart';

/// Every way sign-in can fail. The login screen maps each one to a message.
sealed class AuthException implements Exception {
  const AuthException();
}

class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException();
}

class TooManyAttemptsException extends AuthException {
  const TooManyAttemptsException();
}

class NetworkException extends AuthException {
  const NetworkException();
}

/// The account's role can't use this app, for example a patient on desktop
/// (spec section 4).
class RoleNotAllowedOnPlatformException extends AuthException {
  const RoleNotAllowedOnPlatformException(this.role);

  final UserRole role;
}

class UnknownAuthException extends AuthException {
  const UnknownAuthException([this.cause]);

  final Object? cause;
}
