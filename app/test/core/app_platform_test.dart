import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile allows every role', () {
    for (final role in UserRole.values) {
      expect(AppPlatform.mobile.allows(role), isTrue, reason: role.name);
    }
  });

  test('desktop allows admin, doctor and assistant, but not patient', () {
    expect(AppPlatform.desktop.allows(UserRole.admin), isTrue);
    expect(AppPlatform.desktop.allows(UserRole.doctor), isTrue);
    expect(AppPlatform.desktop.allows(UserRole.assistant), isTrue);
    expect(AppPlatform.desktop.allows(UserRole.patient), isFalse);
  });
}
