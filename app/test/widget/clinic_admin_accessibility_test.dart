import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// The new clinic screens on a small phone (360 dp) with the largest common
/// text size and reduced motion, in Arabic: nothing overflows (an overflow
/// fails the test) and every screen still opens.
void main() {
  for (final path in [
    '/doctor/settings',
    '/doctor/settings/profile',
    '/doctor/settings/prices',
    '/doctor/branches',
    '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}',
    '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}?tab=hours',
    '/doctor/branches/${FakeClinicAdminRepository.nasrCityBranchId}?tab=clinic',
    '/doctor/branches/new',
    '/doctor/assistants',
    '/doctor/assistants/new',
    '/doctor/activity',
  ]) {
    testWidgets('$path at 360 dp, large text, reduced motion, Arabic', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await pumpApp(
        tester,
        size: const Size(360, 760),
        prefs: const {'settings.locale': 'ar'},
        extra: [fakeClinicAdminOverride()],
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'doctor@el3yada.dev',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
      goTo(tester, path);
      await settle(tester);

      expect(tester.takeException(), isNull);
    });
  }
}
