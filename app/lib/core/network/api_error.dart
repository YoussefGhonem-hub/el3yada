import 'package:dio/dio.dart';

import '../../l10n/gen/app_localizations.dart';

/// An API failure, read from the ProblemDetails `code` field (backend `ErrorCodes`).
class ApiError implements Exception {
  const ApiError(this.code, {this.status});

  /// Network problems: no connection, timeout.
  static const network = 'NETWORK';
  static const unknown = 'UNKNOWN';
  static const notFound = 'NOT_FOUND';
  static const forbidden = 'FORBIDDEN';
  static const unauthorized = 'UNAUTHORIZED';
  static const validationFailed = 'VALIDATION_FAILED';
  static const deletionAlreadyRequested = 'DELETION_ALREADY_REQUESTED';
  static const accountDeleted = 'ACCOUNT_DELETED';
  static const fileMissing = 'FILE_MISSING';

  final String code;
  final int? status;

  bool get isNetwork => code == network;

  factory ApiError.from(Object error) {
    if (error is ApiError) return error;
    if (error is! DioException) return const ApiError(unknown);
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiError(network);
      default:
        final data = error.response?.data;
        final code = data is Map ? data['code'] as String? : null;
        return ApiError(code ?? unknown, status: error.response?.statusCode);
    }
  }

  @override
  String toString() => 'ApiError($code, $status)';
}

extension ApiErrorMessage on AppLocalizations {
  /// The message for an error code, in the current language. Add new codes here.
  String apiErrorMessage(Object error) => switch (ApiError.from(error).code) {
        ApiError.network => errorNoInternet,
        ApiError.notFound || ApiError.fileMissing => errorNotFound,
        ApiError.forbidden || ApiError.unauthorized || ApiError.accountDeleted => errorForbidden,
        ApiError.deletionAlreadyRequested => errorDeletionAlreadyRequested,
        _ => errorUnknown,
      };
}
