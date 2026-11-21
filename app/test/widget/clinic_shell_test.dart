import 'package:el3yada/core/widgets/temporary_password_dialog.dart';
import 'package:el3yada/features/clinic/presentation/clinic_shell_parts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/app_flow.dart';
import '../support/harness.dart';

/// The clinic shell (Phase 2 foundation): menus by permission (spec 7.6),
/// the current-branch picker (BR-BR3), the suspension banner (BR-G5).
void main() {
  testWidgets('a reception assistant sees only what their permissions allow', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, '01000000001');

    expect(find.text("Dr تجريبي's clinic"), findsOneWidget);
    // Reception has appointments (so the dashboard's booking charts, AS18) but no chat or billing (spec 6.10).
    expect(find.text('Appointments'), findsOneWidget);
    expect(find.text('Chats'), findsNothing);
    expect(find.text('Billing'), findsNothing);
    // One branch: no picker.
    expect(find.byType(BranchPicker), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BranchPicker),
        matching: find.text('Maadi'),
      ),
      findsNothing,
    );
  });

  testWidgets("an assistant can't open a hidden item by its address", (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, '01000000001');

    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/assistant/billing');
    await settle(tester);

    expect(find.textContaining('AS10'), findsNothing);
    // Back on AS1, the home.
    expect(find.text('Walk-in'), findsOneWidget);
  });

  testWidgets('an office manager sees billing, the dashboard and chats', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, '01000000005');

    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
  });

  testWidgets('the doctor picks the current branch, and it is remembered', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, 'doctor@el3yada.dev');

    Finder inPicker(String name) => find.descendant(
      of: find.byType(BranchPicker),
      matching: find.text(name),
    );
    expect(inPicker('Maadi'), findsOneWidget);
    await tester.tap(inPicker('Maadi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nasr City').last);
    await tester.pumpAndSettle();

    expect(inPicker('Nasr City'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((k) => k.startsWith('clinic.currentBranch.')),
      isNotEmpty,
    );
  });

  testWidgets('a suspended doctor sees the banner with Pay now', (
    tester,
  ) async {
    await pumpApp(tester);
    await signIn(tester, 'suspended@el3yada.dev');

    expect(
      find.text(
        'Service is suspended because an invoice is unpaid. Pay it to reactivate.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pay now'), findsOneWidget);
  });

  testWidgets('an active doctor has no banner', (tester) async {
    await pumpApp(tester);
    await signIn(tester, 'doctor@el3yada.dev');

    expect(find.text('Pay now'), findsNothing);
  });

  testWidgets('the temporary password shows once, with copy and share', (
    tester,
  ) async {
    await pumpHarness(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showTemporaryPasswordDialog(
            context,
            name: 'منى حسن',
            phone: '+201012345678',
            password: 'Ab3dE7gH',
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Ab3dE7gH'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy'));
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsOneWidget);

    // Tapping outside doesn't close it; Done does.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Ab3dE7gH'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Ab3dE7gH'), findsNothing);
  });
}
