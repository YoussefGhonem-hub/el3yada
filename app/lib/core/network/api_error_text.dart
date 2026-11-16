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
      // Clinic endpoints (backend/docs/api-phase-2.md).
      // FORBIDDEN and NOT_FOUND use the shared texts in fieldError.
      ApiCodes.permissionDenied => errorPermissionDenied,
      ApiCodes.doctorSuspended => errorDoctorSuspended,
      ApiCodes.branchNotAllowed => errorBranchNotAllowed,
      // Branches, assistants (backend/docs/api-phase-2-clinic.md).
      'BRANCH_LIMIT_REACHED' => branchErrorLimitReached,
      'CANNOT_ARCHIVE_DEFAULT_BRANCH' => branchErrorArchiveDefault,
      'LAST_ACTIVE_BRANCH' => branchErrorLastActive,
      'BRANCH_HAS_BOOKINGS' => branchErrorHasBookings,
      'BRANCH_NOT_ACTIVE' => branchErrorNotActive,
      'ASSISTANT_LIMIT_REACHED' => assistantErrorLimitReached,
      'ASSISTANT_PHONE_TAKEN' => assistantErrorPhoneTaken,
      'ASSISTANT_REMOVED' => assistantErrorRemoved,
      // Patients and sessions (backend/docs/api-phase-2-patients.md).
      ApiCodes.notLinked => sessionErrorNotLinked,
      ApiCodes.patientAlreadyLinked => patientErrorAlreadyLinked,
      ApiCodes.patientPhoneTaken => patientErrorPhoneTaken,
      // BR-S4: the number follows the admin's setting, sent with the error.
      ApiCodes.consultationRequiresExam => error.details['reason'] == 'firstVisit'
          ? sessionRuleFirstVisit
          : sessionConsultationLimit((error.details['maxConsecutiveConsultations'] as num?)?.toInt() ?? 2),
      ApiCodes.branchArchived => sessionErrorBranchArchived,
      ApiCodes.amountNotEditable => sessionErrorAmountNotEditable,
      ApiCodes.sessionNotDeletable =>
        error.details['reason'] == 'notSameDay' ? sessionNotDeletableDay : sessionNotDeletableLatest,
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
        // Patients and sessions.
        'INVALID_DATE_OF_BIRTH' => patientErrorDateOfBirth,
        'INVALID_NATIONAL_ID' => patientErrorNationalId,
        'AMOUNT_REQUIRED' => sessionAmountRequired,
        'INVALID_EMAIL' => errorInvalidEmail,
        'INVALID_MOBILE' => errorInvalidMobile,
        // Branch and support phones: landlines and hotlines are allowed too.
        'INVALID_PHONE' => regErrorInvalidPhone,
        // A branch's map link (sign-up step 3 and D29).
        'INVALID_MAP_LINK' => mapLinkInvalid,
        'INVALID_IDENTIFIER' => errorInvalidIdentifier,
        'WEAK_PASSWORD' => errorWeakPassword,
        'PASSWORD_SAME_AS_OLD' => errorPasswordSameAsOld,
        'CURRENT_PASSWORD_INCORRECT' => errorCurrentPasswordIncorrect,
        'TERMS_NOT_ACCEPTED' => errorTermsNotAccepted,
        'EMAIL_TOKEN_INVALID' => errorEmailTokenInvalid,
        'EMAIL_TOKEN_EXPIRED' => errorEmailTokenExpired,
        'EMAIL_TOKEN_USED' => errorEmailTokenUsed,
        // Doctor registration (A4–A7).
        'INVALID_LICENSE_NUMBER' => regErrorInvalidLicenseNumber,
        'INVALID_SPECIALTY' => regErrorInvalidSpecialty,
        'PHONE_REQUIRED' => regErrorPhoneRequired,
        'FILE_TOO_LARGE' || 'REQUEST_TOO_LARGE' => regErrorFileTooLarge,
        'FILE_TYPE_NOT_ALLOWED' => regErrorFileType,
        'FILE_CONTENT_INVALID' => regErrorFileContent,
        'REGISTRATION_NOT_EDITABLE' => regErrorNotEditable,
        'VERIFICATION_EMAIL_COOLDOWN' => regErrorResendCooldown,
        // Shared by registration and admin, then admin only (AD2–AD18).
        'OUT_OF_RANGE' => adminErrorOutOfRange,
        'INVALID_VALUE' => adminErrorInvalidValue,
        'INVALID_VERSION' => adminErrorInvalidVersion,
        'UNKNOWN_SETTING' => adminErrorUnknownSetting,
        'INVALID_NAME' => adminErrorInvalidName,
        'REASON_REQUIRED' => adminErrorReasonRequired,
        'REGISTRATION_NOT_PENDING' => adminErrorRegistrationNotPending,
        'EMAIL_ALREADY_REGISTERED' => adminErrorEmailTaken,
        'LICENSE_FILE_MISSING' => adminErrorLicenseMissing,
        'CANNOT_CHANGE_OWN_ROLE' => adminErrorOwnRole,
        'CANNOT_DISABLE_SELF' => adminErrorDisableSelf,
        'LAST_SUPER_ADMIN' => adminErrorLastSuperAdmin,
        'NOT_FOUND' => adminErrorNotFound,
        'FORBIDDEN' => adminErrorForbidden,
        // Clinic admin fields (backend/docs/api-phase-2-clinic.md).
        'INVALID_BRANCH' => branchErrorInvalidBranch,
        'PERIOD_END_BEFORE_START' => branchErrorPeriodEndBeforeStart,
        'PERIOD_LENGTH_OUT_OF_RANGE' => branchErrorPeriodLength,
        'PERIODS_OVERLAP' => branchErrorPeriodsOverlap,
        'ASSISTANT_PHONE_TAKEN' => assistantErrorPhoneTaken,
        _ => null,
      };

  String _tooManyAttempts(Duration? retryAfter) {
    if (retryAfter == null || retryAfter.inSeconds < 60) return errorTooManyAttempts;
    return errorRetryInMinutes((retryAfter.inSeconds / 60).ceil());
  }
}
