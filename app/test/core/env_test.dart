import 'dart:convert';
import 'dart:io';

import 'package:el3yada/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds without a flavor (Windows, tests) pass', () {
    expect(Env.flavorMismatch(flavor: null, env: 'prod'), isNull);
  });

  test('a matching flavor and config pass', () {
    expect(Env.flavorMismatch(flavor: 'dev', env: 'dev'), isNull);
  });

  test('a prod flavor with the dev config is refused', () {
    expect(
      Env.flavorMismatch(flavor: 'prod', env: 'dev'),
      contains('config/prod.json'),
    );
  });

  // TestFlight builds with these (ios-testflight.yml). uat.json has APP_ENV
  // dev, where a missing USE_FAKE_AUTH means on, so it must say false.
  test('the TestFlight and store configs never show the test accounts', () {
    for (final name in ['uat', 'prod']) {
      final config = jsonDecode(File('config/$name.json').readAsStringSync()) as Map<String, dynamic>;
      expect(config['USE_FAKE_AUTH'], isFalse, reason: 'config/$name.json');
    }
  });
}
