import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin_support/data/admin_support_repository.dart';
import '../support/app_overrides.dart';
import 'package:material_ui/material_ui.dart';
import '../support/app_flow.dart' show settle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAdmin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await appOverrides(platform: AppPlatform.desktop),
        adminSupportRepositoryProvider.overrideWithValue(
          FakeAdminSupportRepository(),
        ),
      ],
      child: const El3yadaApp(),
    ),
  );
  await settle(tester);
  await tester.enterText(find.byType(TextFormField).at(0), 'admin@el3yada.dev');
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AD11: search by phone shows linked doctors and validates the number',
    (tester) async {
      await pumpAdmin(tester);
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Invalid mobile number'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '01000000002');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('محمد إبراهيم · Patient'), findsOneWidget);
      expect(find.textContaining('د. منى حسن'), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Login disabled'), findsOneWidget);
    },
  );
}
