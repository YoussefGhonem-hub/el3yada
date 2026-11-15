import 'package:el3yada/features/clinic_admin/presentation/settings/clinic_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart';
import '../support/clinic_admin_support.dart';

/// D24 and AS12 settings, D22 profile, D37 / AS19 visit prices.
void main() {
  Future<void> signedIn(WidgetTester tester, String account, {Size size = const Size(1400, 900)}) async {
    await pumpApp(tester, size: size, extra: [fakeClinicAdminOverride()]);
    await signIn(tester, account);
  }

  group('D24 doctor settings', () {
    testWidgets('shows the profile ticket, prices, preferences and notifications', (tester) async {
      await signedIn(tester, 'doctor@el3yada.dev');
      goTo(tester, '/doctor/settings');
      await settle(tester);

      expect(find.byType(ClinicSettingsScreen), findsOneWidget);
      expect(find.text('Dr. تجريبي'), findsOneWidget);
      expect(find.text('Visit prices'), findsWidgets);
      expect(find.text('Chat messages'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Show message text in notifications'), findsOneWidget);
    });
  });
}
