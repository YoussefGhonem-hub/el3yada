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
    expect(Env.flavorMismatch(flavor: 'prod', env: 'dev'), contains('config/prod.json'));
  });
}
