namespace El3yada.Api;

/// <summary>
/// Error codes the API returns. The app maps each code to an ARB message, so a code never changes once it ships.
/// A problem+json response carries one top-level <c>code</c>; a validation problem (400) has
/// <c>code = VALIDATION_FAILED</c> plus <c>errorCodes</c> per field. backend/docs/api-phase-1.md lists them all.
/// </summary>
public static class ErrorCodes
{
    // ---- General -------------------------------------------------------------------------------------

    /// <summary>400: one or more fields failed validation; see <c>errors</c> and <c>errorCodes</c>.</summary>
    public const string ValidationFailed = "VALIDATION_FAILED";

    /// <summary>400: the body is not valid JSON or has the wrong shape.</summary>
    public const string InvalidRequest = "INVALID_REQUEST";

    /// <summary>404: no such route or record (or the caller may not know it exists).</summary>
    public const string NotFound = "NOT_FOUND";

    /// <summary>405: the route exists but not for this HTTP method.</summary>
    public const string MethodNotAllowed = "METHOD_NOT_ALLOWED";

    /// <summary>415: wrong Content-Type (for example JSON sent to a multipart endpoint).</summary>
    public const string UnsupportedMediaType = "UNSUPPORTED_MEDIA_TYPE";

    /// <summary>413: the request body is larger than the endpoint accepts.</summary>
    public const string RequestTooLarge = "REQUEST_TOO_LARGE";

    /// <summary>500: an unexpected error. Details are in the server log, never in the response.</summary>
    public const string ServerError = "SERVER_ERROR";

    // ---- Field validation (errorCodes) ----------------------------------------------------------------

    /// <summary>The field is required.</summary>
    public const string Required = "REQUIRED";

    /// <summary>The text is longer than allowed.</summary>
    public const string TooLong = "TOO_LONG";

    /// <summary>A number outside its allowed range.</summary>
    public const string OutOfRange = "OUT_OF_RANGE";

    /// <summary>A value that is not one of the allowed values, or has the wrong format.</summary>
    public const string InvalidValue = "INVALID_VALUE";

    /// <summary>Not an Egyptian mobile number (spec section 11).</summary>
    public const string InvalidMobile = "INVALID_MOBILE";

    /// <summary>Not a valid phone number (branch phones and support numbers accept landlines too).</summary>
    public const string InvalidPhone = "INVALID_PHONE";

    /// <summary>A branch needs at least one phone number («أضف رقم تليفون واحد على الأقل»).</summary>
    public const string PhoneRequired = "PHONE_REQUIRED";

    /// <summary>Not a valid email address («البريد الإلكتروني غير صحيح»).</summary>
    public const string InvalidEmail = "INVALID_EMAIL";

    /// <summary>The login identifier is neither an email nor an Egyptian mobile number.</summary>
    public const string InvalidIdentifier = "INVALID_IDENTIFIER";

    /// <summary>Full name: 2–60 letters and spaces, at least two words («اكتب الاسم ثنائي على الأقل»).</summary>
    public const string InvalidName = "INVALID_NAME";

    /// <summary>Password: at least 8 characters with a letter and a number (spec section 11).</summary>
    public const string WeakPassword = "WEAK_PASSWORD";

    /// <summary>The new password is the same as the current one.</summary>
    public const string PasswordSameAsOld = "PASSWORD_SAME_AS_OLD";

    /// <summary>The current password is wrong (change password).</summary>
    public const string CurrentPasswordIncorrect = "CURRENT_PASSWORD_INCORRECT";

    /// <summary>The Terms and Privacy Policy must be accepted (A4 step 4, A9 for patients).</summary>
    public const string TermsNotAccepted = "TERMS_NOT_ACCEPTED";

    /// <summary>Syndicate number: 3–20 letters, digits, "-" or "/" («رقم النقابة مطلوب»).</summary>
    public const string InvalidLicenseNumber = "INVALID_LICENSE_NUMBER";

    /// <summary>The specialty does not exist or is no longer offered.</summary>
    public const string InvalidSpecialty = "INVALID_SPECIALTY";

    /// <summary>An app version is not in the form 1.2.3.</summary>
    public const string InvalidVersion = "INVALID_VERSION";

    /// <summary>updateSettings got a field it does not know.</summary>
    public const string UnknownSetting = "UNKNOWN_SETTING";

    /// <summary>Rejecting a registration needs a reason.</summary>
    public const string ReasonRequired = "REASON_REQUIRED";

    // ---- Sign-in and sessions ------------------------------------------------------------------------

    /// <summary>401: wrong identifier or password («رقم الهاتف/البريد أو كلمة المرور غير صحيحة»).</summary>
    public const string InvalidCredentials = "INVALID_CREDENTIALS";

    /// <summary>429: too many attempts («محاولات كثيرة، حاول لاحقاً»). See the Retry-After header.</summary>
    public const string TooManyAttempts = "TOO_MANY_ATTEMPTS";

    /// <summary>403: the account is disabled (A10).</summary>
    public const string AccountDisabled = "ACCOUNT_DISABLED";

    /// <summary>403: an assistant whose doctor is pending, rejected or disabled («حساب العيادة غير مفعّل», A10, BR-AS9).</summary>
    public const string ClinicNotActive = "CLINIC_NOT_ACTIVE";

    /// <summary>403: a patient account signing in on Windows or macOS (A14).</summary>
    public const string PatientDesktopNotSupported = "PATIENT_DESKTOP_NOT_SUPPORTED";

    /// <summary>401: no access token, or not a valid one.</summary>
    public const string Unauthenticated = "UNAUTHENTICATED";

    /// <summary>401: the access token has expired. Refresh and retry.</summary>
    public const string TokenExpired = "TOKEN_EXPIRED";

    /// <summary>401: the account's role changed since the token was issued. Refresh and retry.</summary>
    public const string TokenOutdated = "TOKEN_OUTDATED";

    /// <summary>401: the password changed (or the account was signed out everywhere) after the token was issued.</summary>
    public const string SessionRevoked = "SESSION_REVOKED";

    /// <summary>401: the refresh token is unknown, expired or revoked. Sign in again.</summary>
    public const string RefreshTokenInvalid = "REFRESH_TOKEN_INVALID";

    /// <summary>401: an already-rotated refresh token came back, so the whole session was revoked. Sign in again.</summary>
    public const string RefreshTokenReused = "REFRESH_TOKEN_REUSED";

    /// <summary>401: the "log in as" selection token is unknown, expired or already used. Sign in again.</summary>
    public const string SelectionTokenInvalid = "SELECTION_TOKEN_INVALID";

    /// <summary>403: signed in, but this role (or admin role) may not do this.</summary>
    public const string Forbidden = "FORBIDDEN";

    /// <summary>403: the account must set a new password first (A9, <c>setNewPassword</c>).</summary>
    public const string PasswordChangeRequired = "PASSWORD_CHANGE_REQUIRED";

    /// <summary>409: setNewPassword is only for accounts that must change their password; use changePassword.</summary>
    public const string PasswordChangeNotRequired = "PASSWORD_CHANGE_NOT_REQUIRED";

    /// <summary>400: the emailed link (reset password, verify email) is unknown.</summary>
    public const string EmailTokenInvalid = "EMAIL_TOKEN_INVALID";

    /// <summary>400: the emailed link has expired; request a new one.</summary>
    public const string EmailTokenExpired = "EMAIL_TOKEN_EXPIRED";

    /// <summary>400: the emailed link was already used.</summary>
    public const string EmailTokenUsed = "EMAIL_TOKEN_USED";

    /// <summary>409: the email address is already verified.</summary>
    public const string EmailAlreadyVerified = "EMAIL_ALREADY_VERIFIED";

    /// <summary>429: a verification email was sent less than a minute ago (A5).</summary>
    public const string VerificationEmailCooldown = "VERIFICATION_EMAIL_COOLDOWN";

    // ---- Doctors and registration ---------------------------------------------------------------------

    /// <summary>409: an account with this email already exists.</summary>
    public const string EmailAlreadyRegistered = "EMAIL_ALREADY_REGISTERED";

    /// <summary>409: the registration can only be edited and resubmitted after a rejection (A7).</summary>
    public const string RegistrationNotEditable = "REGISTRATION_NOT_EDITABLE";

    /// <summary>409: the registration was already reviewed (it is not pendingApproval).</summary>
    public const string RegistrationNotPending = "REGISTRATION_NOT_PENDING";

    /// <summary>404: the stored license file is missing.</summary>
    public const string LicenseFileMissing = "LICENSE_FILE_MISSING";

    /// <summary>403: the doctor's sign-up is still waiting for approval (A6). Used by doctor endpoints from Phase 2.</summary>
    public const string DoctorPendingApproval = "DOCTOR_PENDING_APPROVAL";

    /// <summary>403: the doctor's sign-up was rejected (A7). Used by doctor endpoints from Phase 2.</summary>
    public const string DoctorRejected = "DOCTOR_REJECTED";

    /// <summary>403: the doctor is suspended for an unpaid invoice (spec 9.1, BR-G5). Used from Phase 2.</summary>
    public const string DoctorSuspended = "DOCTOR_SUSPENDED";

    /// <summary>403: the doctor account is disabled by the admin. Used from Phase 2.</summary>
    public const string DoctorDisabled = "DOCTOR_DISABLED";

    // ---- Admin users ---------------------------------------------------------------------------------

    /// <summary>409: an admin cannot change their own admin role.</summary>
    public const string CannotChangeOwnRole = "CANNOT_CHANGE_OWN_ROLE";

    /// <summary>409: an admin cannot disable their own account.</summary>
    public const string CannotDisableSelf = "CANNOT_DISABLE_SELF";

    /// <summary>409: the change would leave no active super admin.</summary>
    public const string LastSuperAdmin = "LAST_SUPER_ADMIN";

    // ---- Files ---------------------------------------------------------------------------------------

    /// <summary>The file is larger than the upload limit.</summary>
    public const string FileTooLarge = "FILE_TOO_LARGE";

    /// <summary>The file type is not accepted (JPEG, PNG, WebP and PDF are).</summary>
    public const string FileTypeNotAllowed = "FILE_TYPE_NOT_ALLOWED";

    /// <summary>The file content does not match its type, or the image cannot be read.</summary>
    public const string FileContentInvalid = "FILE_CONTENT_INVALID";
}
