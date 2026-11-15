import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/user_role.dart';

enum AppFormFactor { mobile, desktop }

/// Which roles may use the app on this platform (spec section 4).
///
/// - Mobile (Android, iOS): admin, doctor, assistant and patient.
/// - Desktop (Windows, macOS): admin, doctor and assistant. Patients use the
///   mobile app only.
class AppPlatform {
  const AppPlatform._(this.formFactor);

  static const mobile = AppPlatform._(AppFormFactor.mobile);
  static const desktop = AppPlatform._(AppFormFactor.desktop);

  static AppPlatform get current => switch (defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux =>
          desktop,
        _ => mobile,
      };

  final AppFormFactor formFactor;

  bool get isDesktop => formFactor == AppFormFactor.desktop;

  Set<UserRole> get allowedRoles => isDesktop
      ? const {UserRole.admin, UserRole.doctor, UserRole.assistant}
      : UserRole.values.toSet();

  bool allows(UserRole role) => allowedRoles.contains(role);
}

final appPlatformProvider = Provider<AppPlatform>((ref) => AppPlatform.current);
