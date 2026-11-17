import 'package:dio/dio.dart';

/// Every failed API call, read from the API's `application/problem+json`
/// answer (backend/README.md, "Validation").
///
/// [code] is the stable error code (`INVALID_CREDENTIALS`, `ACCOUNT_DISABLED`,
/// ...). [fieldCodes] holds the first code for each invalid field, keyed by the
/// JSON field name (`phone`, `newPassword`, ...). Screens turn both into ARB
/// messages with `ApiErrorText` (core/network/api_error_text.dart).
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    this.status,
    this.code,
    this.fieldCodes = const {},
    this.retryAfter,
    this.cause,
    this.details = const {},
  });

  /// Not from the API: used by the app itself (for example a patient on desktop).
  const ApiException.local(String this.code)
      : kind = ApiErrorKind.http,
        status = null,
        fieldCodes = const {},
        retryAfter = null,
        cause = null,
        details = const {};

  factory ApiException.fromDio(DioException error) {
    if (error.error is ApiException) return error.error! as ApiException;
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(kind: ApiErrorKind.network, cause: error);
      case DioExceptionType.cancel:
        return ApiException(kind: ApiErrorKind.cancelled, cause: error);
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        // On mobile a dropped connection often arrives as `unknown` with a
        // SocketException inside.
        if (error.response == null) return ApiException(kind: ApiErrorKind.network, cause: error);
      case DioExceptionType.badResponse:
        break;
    }

    final response = error.response;
    final status = response?.statusCode;
    final body = response?.data;
    String? code;
    final fieldCodes = <String, String>{};
    var details = const <String, Object?>{};
    if (body is Map) {
      code = body['code'] as String?;
      details = body.cast<String, Object?>();
      final errorCodes = body['errorCodes'];
      if (errorCodes is Map) {
        for (final entry in errorCodes.entries) {
          final codes = entry.value;
          if (codes is List && codes.isNotEmpty) fieldCodes['${entry.key}'] = '${codes.first}';
        }
      }
      if (code == null && fieldCodes.isNotEmpty) code = 'VALIDATION_FAILED';
    }

    Duration? retryAfter;
    final retryHeader = response?.headers.value('retry-after');
    final seconds = retryHeader == null ? null : int.tryParse(retryHeader);
    if (seconds != null) retryAfter = Duration(seconds: seconds);

    return ApiException(
      kind: status != null && status >= 500 ? ApiErrorKind.server : ApiErrorKind.http,
      status: status,
      code: code,
      fieldCodes: fieldCodes,
      retryAfter: retryAfter,
      cause: error,
      details: details,
    );
  }

  final ApiErrorKind kind;
  final int? status;
  final String? code;
  final Map<String, String> fieldCodes;
  final Duration? retryAfter;
  final Object? cause;

  /// The whole problem+json body, for the extra fields some codes carry:
  /// `reason` on `CONSULTATION_REQUIRES_EXAM` and `SESSION_NOT_DELETABLE`,
  /// `patientId` on `PATIENT_ALREADY_LINKED` (backend/docs/api-phase-2-patients.md).
  final Map<String, Object?> details;

  bool get isNetwork => kind == ApiErrorKind.network;

  bool hasCode(String value) => code == value;

  @override
  String toString() => 'ApiException($kind, $status, $code, $fieldCodes)';
}

enum ApiErrorKind { network, cancelled, server, http }

/// The codes the app reacts to. The full list is backend/src/El3yada.Api/ErrorCodes.cs.
abstract final class ApiCodes {
  static const validationFailed = 'VALIDATION_FAILED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const tooManyAttempts = 'TOO_MANY_ATTEMPTS';
  static const accountDisabled = 'ACCOUNT_DISABLED';
  static const clinicNotActive = 'CLINIC_NOT_ACTIVE';
  static const patientDesktopNotSupported = 'PATIENT_DESKTOP_NOT_SUPPORTED';
  static const refreshTokenInvalid = 'REFRESH_TOKEN_INVALID';
  static const refreshTokenReused = 'REFRESH_TOKEN_REUSED';
  static const selectionTokenInvalid = 'SELECTION_TOKEN_INVALID';
  static const passwordChangeRequired = 'PASSWORD_CHANGE_REQUIRED';
  static const tokenOutdated = 'TOKEN_OUTDATED';
  static const sessionRevoked = 'SESSION_REVOKED';
  static const verificationEmailCooldown = 'VERIFICATION_EMAIL_COOLDOWN';
  static const emailAlreadyVerified = 'EMAIL_ALREADY_VERIFIED';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';

  // Clinic endpoints (backend/docs/api-phase-2.md).
  static const permissionDenied = 'PERMISSION_DENIED';
  static const branchNotAllowed = 'BRANCH_NOT_ALLOWED';
  static const doctorPendingApproval = 'DOCTOR_PENDING_APPROVAL';
  static const doctorRejected = 'DOCTOR_REJECTED';
  static const doctorSuspended = 'DOCTOR_SUSPENDED';

  // Free trial (backend/docs/api-free-trial.md).
  static const trialEnded = 'TRIAL_ENDED';
  static const serviceAlreadyActive = 'SERVICE_ALREADY_ACTIVE';
  static const doctorStatusNotChangeable = 'DOCTOR_STATUS_NOT_CHANGEABLE';

  // Patients and sessions (backend/docs/api-phase-2-patients.md).
  static const notLinked = 'NOT_LINKED';
  static const patientAlreadyLinked = 'PATIENT_ALREADY_LINKED';
  static const patientPhoneTaken = 'PATIENT_PHONE_TAKEN';
  static const consultationRequiresExam = 'CONSULTATION_REQUIRES_EXAM';
  static const branchArchived = 'BRANCH_ARCHIVED';
  static const amountNotEditable = 'AMOUNT_NOT_EDITABLE';
  static const sessionNotDeletable = 'SESSION_NOT_DELETABLE';

  // Prescriptions (backend/docs/api-phase-3-prescriptions.md).
  static const prescriptionNotEditable = 'PRESCRIPTION_NOT_EDITABLE';
  static const prescriptionNotSent = 'PRESCRIPTION_NOT_SENT';
  static const prescriptionEmpty = 'PRESCRIPTION_EMPTY';
  static const invalidCopySource = 'INVALID_COPY_SOURCE';
}
