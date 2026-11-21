import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/clinic/application/clinic_providers.dart';
import '../config/env.dart';
import '../settings/app_settings.dart';
import 'api_exception.dart';

/// HTTP client for the ASP.NET Core Web API (spec section 9), with the access
/// token, the user's language, and token refresh on 401.
///
/// Paths are relative to `/api`: `dio.get('/auth/me')` calls
/// `{API_BASE_URL}/api/auth/me`. Wrap calls in `try`/`on DioException` and
/// throw `ApiException.fromDio(error)`, as the repositories do.
final dioProvider = Provider<Dio>((ref) {
  final dio = _newDio(ref.watch(apiBaseUrlProvider));
  dio.interceptors.add(AuthInterceptor(ref, dio));
  return dio;
});

/// The same client without the auth interceptor: for sign-in, refresh and
/// logout, which must never start a refresh themselves.
final plainDioProvider = Provider<Dio>((ref) {
  final dio = _newDio(ref.watch(apiBaseUrlProvider));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    options.headers['Accept-Language'] = ref.read(appSettingsProvider).locale.languageCode;
    handler.next(options);
  }));
  return dio;
});

/// `API_BASE_URL` from the build config. The contract test overrides it to
/// run this whole stack against a local API.
final apiBaseUrlProvider = Provider<String>((ref) => Env.apiBaseUrl);

/// The base URL ends in `/api`, so request paths are written under it: `/branches`,
/// `/staff/board`, `/patient/home`. Dio appends the path to the base as text, so a
/// path that started with `/api/` would ask for `/api/api/...`
/// (test/core/api_paths_test.dart guards this).
Dio _newDio(String baseUrl) => Dio(
      BaseOptions(
        baseUrl: '$baseUrl/api',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );

/// Adds the access token and the language to every request, and keeps the
/// session alive:
/// - Before sending, refreshes an access token that expires within 30 seconds.
/// - On a 401 for a request that carried a token, refreshes once and retries.
///   Several requests failing together share one refresh
///   (`AuthController.refreshTokens`).
/// - If the refresh is refused, `AuthController` signs the user out (or shows
///   A10 for a disabled account), and the router moves to the right screen.
/// - On 403 `PASSWORD_CHANGE_REQUIRED`, reloads the account so the router
///   opens A9. On 403 `PERMISSION_DENIED` or `DOCTOR_SUSPENDED`, reloads the
///   clinic (`clinicContextProvider`).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref, this._dio);

  final Ref _ref;
  final Dio _dio;

  static const _retriedKey = 'auth.retried';
  static const _refreshMargin = Duration(seconds: 30);

  AuthController get _auth => _ref.read(authControllerProvider.notifier);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers['Accept-Language'] = _ref.read(appSettingsProvider).locale.languageCode;
    if (options.headers.containsKey('Authorization')) return handler.next(options);

    var session = _ref.read(authControllerProvider).value;
    if (session != null && session.accessTokenExpiresWithin(_refreshMargin, DateTime.now().toUtc())) {
      try {
        session = await _auth.refreshTokens();
      } on ApiException {
        // Offline or a server error: send with the old token; a 401 retries later.
      }
    }
    if (session != null) options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final error = err;
    final request = error.requestOptions;
    final status = error.response?.statusCode;
    final sentToken = _bearer(request.headers['Authorization']);

    if (status == 403 && sentToken != null) {
      final code = ApiException.fromDio(error).code;
      if (code == ApiCodes.passwordChangeRequired) _auth.reloadAccount().ignore();
      // The clinic changed under us: permissions or the doctor's status. Read
      // it again so the screens hide what's no longer allowed (BR-AS4).
      if (code == ApiCodes.permissionDenied || code == ApiCodes.doctorSuspended) {
        _ref.read(clinicContextProvider.notifier).reload().ignore();
      }
      // The doctor's status changed (rare: an approval was reversed), or the
      // clinic's free trial ended (A15): the router follows the account.
      if (code == ApiCodes.doctorPendingApproval || code == ApiCodes.doctorRejected || code == ApiCodes.trialEnded) {
        _auth.reloadAccount().ignore();
      }
      // Disabled while signed in, or the clinic closed: sign out and show A10.
      if (AuthBlock.codes.contains(code)) _auth.signOutBlocked(code!).ignore();
      return handler.next(error);
    }

    if (status != 401 || sentToken == null || request.extra[_retriedKey] == true) {
      return handler.next(error);
    }

    try {
      final current = _ref.read(authControllerProvider).value;
      // Another request may have refreshed already while this one was out.
      final session = current != null && current.accessToken != sentToken ? current : await _auth.refreshTokens();
      if (session == null) return handler.next(error);

      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      request.extra[_retriedKey] = true;
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on ApiException {
      handler.next(error);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  static String? _bearer(Object? header) {
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring(7);
  }
}
