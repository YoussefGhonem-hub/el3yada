import '../../l10n/gen/app_localizations.dart';
import 'api_exception.dart';

/// Turns API error codes into ARB messages. The API's `title` is English
/// text for developers and is never shown.
///
/// Add a case here when a screen needs a new code, rather than mapping codes
/// in the screen.
extension ApiErrorText on AppLocalizations {
  /// A message for the whole request (shown above the submit button or in a
  /// snack bar). Field errors go next to their fields: see [fieldError].
  String apiError(Object error) {
    if (error is! ApiException) return errorUnknown;
    if (error.isNetwork) return errorNoInternet;
    if (error.kind == ApiErrorKind.server) return errorServer;
    return switch (error.code) {
      ApiCodes.invalidCredentials => errorInvalidCredentials,
      ApiCodes.tooManyAttempts => _tooManyAttempts(error.retryAfter),
      ApiCodes.accountDisabled => accountDisabledBody,
      ApiCodes.clinicNotActive => clinicNotActiveBody,
      ApiCodes.patientDesktopNotSupported => patientDesktopTitle,
      ApiCodes.selectionTokenInvalid ||
      ApiCodes.refreshTokenInvalid ||
      ApiCodes.refreshTokenReused ||
      ApiCodes.sessionRevoked ||
      ApiCodes.tokenOutdated =>
        errorSignInAgain,
      ApiCodes.validationFailed => error.fieldCodes.values.map(fieldError).nonNulls.firstOrNull ?? errorUnknown,
      _ => fieldError(error.code) ?? errorUnknown,
    };
  }

  /// The message for one field's code, or null when it has no specific text.
  String? fieldError(String? code) => switch (code) {
        'REQUIRED' => errorRequired,
        'TOO_LONG' => errorTooLong,
        'INVALID_EMAIL' => errorInvalidEmail,
        'INVALID_MOBILE' => errorInvalidMobile,
        // Branch and support phones: landlines and hotlines are allowed too.
        'INVALID_PHONE' => regErrorInvalidPhone,
        'INVALID_IDENTIFIER' => errorInvalidIdentifier,
        'WEAK_PASSWORD' => errorWeakPassword,
        'PASSWORD_SAME_AS_OLD' => errorPasswordSameAsOld,
        'CURRENT_PASSWORD_INCORRECT' => errorCurrentPasswordIncorrect,
        'TERMS_NOT_ACCEPTED' => errorTermsNotAccepted,
        'EMAIL_TOKEN_INVALID' => errorEmailTokenInvalid,
        'EMAIL_TOKEN_EXPIRED' => errorEmailTokenExpired,
        'EMAIL_TOKEN_USED' => errorEmailTokenUsed,
        // Doctor registration (A4–A7).
        'INVALID_NAME' => regErrorInvalidName,
        'INVALID_LICENSE_NUMBER' => regErrorInvalidLicenseNumber,
        'INVALID_SPECIALTY' => regErrorInvalidSpecialty,
        'EMAIL_ALREADY_REGISTERED' => regErrorEmailTaken,
        'PHONE_REQUIRED' => regErrorPhoneRequired,
        'OUT_OF_RANGE' || 'INVALID_VALUE' => regErrorInvalidValue,
        'FILE_TOO_LARGE' || 'REQUEST_TOO_LARGE' => regErrorFileTooLarge,
        'FILE_TYPE_NOT_ALLOWED' => regErrorFileType,
        'FILE_CONTENT_INVALID' => regErrorFileContent,
        'REGISTRATION_NOT_EDITABLE' => regErrorNotEditable,
        'VERIFICATION_EMAIL_COOLDOWN' => regErrorResendCooldown,
        _ => null,
      };

  String _tooManyAttempts(Duration? retryAfter) {
    if (retryAfter == null || retryAfter.inSeconds < 60) return errorTooManyAttempts;
    return errorRetryInMinutes((retryAfter.inSeconds / 60).ceil());
  }
}
