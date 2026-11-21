import 'package:dio/dio.dart';
import 'package:el3yada/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request itself and keeps the address it would have called.
class _Capture extends Interceptor {
  final uris = <Uri>[];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    uris.add(options.uri);
    handler.resolve(Response<Map<String, dynamic>>(requestOptions: options, data: const {}, statusCode: 200));
  }
}

void main() {
  test('both path styles reach the API once under /api', () async {
    final capture = _Capture();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))
      ..interceptors.add(const ApiPathPrefix())
      ..interceptors.add(capture);

    // Phase 1–3 repositories write the path under /api; Phase 4–6 ones write it in full.
    await dio.get<Map<String, dynamic>>('/branches');
    await dio.put<Map<String, dynamic>>('/api/staff/branches/b1/schedule');
    await dio.get<Map<String, dynamic>>('/api/patient/appointments', queryParameters: {'tab': 'upcoming'});

    expect(capture.uris.map((u) => u.toString()), [
      'http://api.test/api/branches',
      'http://api.test/api/staff/branches/b1/schedule',
      'http://api.test/api/patient/appointments?tab=upcoming',
    ]);
  });
}
