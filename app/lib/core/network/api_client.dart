import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../config/env.dart';
import '../settings/app_settings.dart';

/// HTTP client for the ASP.NET Core Web API (spec section 9).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor(ref));
  return dio;
});

/// Adds the access token and the user's language to every request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = _ref.read(authControllerProvider).value;
    if (session != null) {
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    options.headers['Accept-Language'] =
        _ref.read(appSettingsProvider).locale.languageCode;
    handler.next(options);
  }

  // TODO(Phase 1): on a 401, call POST /auth/refresh once with the refresh
  // token, save the new tokens, then retry the request. If the refresh fails,
  // sign the user out.
}
