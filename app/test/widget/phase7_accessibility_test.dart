import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin_billing/data/admin_billing_repository.dart';
import 'package:el3yada/features/admin_billing/data/fake_admin_billing_repository.dart';
import 'package:el3yada/features/analytics/data/analytics_repository.dart';
import 'package:el3yada/features/analytics/data/fake_analytics_repository.dart';
import 'package:el3yada/features/billing/data/billing_repository.dart';
import 'package:el3yada/features/billing/data/fake_billing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart' show goTo;
import '../support/app_flow.dart';

/// Phase 8: the Phase 7 screens on a small phone (360 dp) with large text and reduced
/// motion, in both languages and both themes: nothing overflows (an overflow fails the
/// test) and every screen still opens.
void main() {
  const doctorPaths = [
    '/doctor/dashboard',
    '/doctor/billing',
    '/doctor/revenue',
  ];
  const adminPaths = [
    '/admin/dashboard',
    '/admin/doctors',
    '/admin/payments',
    '/admin/invoices',
  ];

  for (final (who, paths) in [('doctor@el3yada.dev', doctorPaths), ('admin@el3yada.dev', adminPaths)]) {
    for (final locale in ['ar', 'en']) {
      for (final theme in ['light', 'dark']) {
        testWidgets('$who: $paths at 360 dp, large text, reduced motion, $locale, $theme', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(tester.platformDispatcher.clearAllTestValues);

          await pumpApp(
            tester,
            size: const Size(360, 760),
            platform: AppPlatform.mobile,
            prefs: {'settings.locale': locale, 'settings.themeMode': theme},
            extra: [
              billingRepositoryProvider.overrideWithValue(FakeBillingRepository()),
              analyticsRepositoryProvider.overrideWithValue(FakeAnalyticsRepository()),
              adminBillingRepositoryProvider.overrideWithValue(FakeAdminBillingRepository()),
            ],
          );
          await tester.enterText(find.byType(TextFormField).at(0), who);
          await tester.enterText(find.byType(TextFormField).at(1), 'dev');
          await tester.tap(find.byType(FilledButton).first);
          await settle(tester);
          for (final path in paths) {
            goTo(tester, path);
            await settle(tester);
            final error = tester.takeException();
            if (error != null) fail('$path: $error');
          }
        });
      }
    }
  }
}
