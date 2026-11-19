import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/core/storage/token_store.dart';
import 'package:el3yada/features/admin_support/data/admin_support_repository.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpAdmin(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'settings.locale': 'en'});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appPlatformProvider.overrideWithValue(AppPlatform.desktop),
      tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(delay: Duration.zero)),
      adminSupportRepositoryProvider.overrideWithValue(FakeAdminSupportRepository()),
    ],
    child: const El3yadaApp(),
  ));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'admin@el3yada.dev');
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AD12: rejecting needs a reason, then the request leaves the queue', (tester) async {
    await pumpAdmin(tester);
    await tester.tap(find.text('Deletion requests'));
    await tester.pumpAndSettle();

    expect(find.text('خالد يوسف'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Reject'));
    await tester.pumpAndSettle();
    final confirm = find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Reject'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Duplicate request');
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(find.text('No requests here.'), findsOneWidget);
  });

  testWidgets('AD11: search by phone shows linked doctors and validates the number', (tester) async {
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
  });
}
