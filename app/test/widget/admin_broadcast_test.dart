import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin/data/broadcast_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';

const _desktop = Size(1400, 900);
const _phone = Size(400, 860);

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Signs in as the dev admin and opens AD16; returns the offline broadcasts.
Future<FakeBroadcastRepository> _openBroadcast(WidgetTester tester, {Size size = _desktop}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final broadcasts = FakeBroadcastRepository(delay: Duration.zero, senderName: () => 'Nour Adel');
  await tester.pumpWidget(
    ProviderScope(
      overrides: await appOverrides(
        platform: size.width >= 1024 ? AppPlatform.desktop : AppPlatform.mobile,
        extra: [fakeAdminOverride(), broadcastRepositoryProvider.overrideWithValue(broadcasts)],
      ),
      child: const El3yadaApp(),
    ),
  );
  await _settle(tester);
  await tester.enterText(find.byType(TextFormField).at(0), 'admin@el3yada.dev');
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await _settle(tester);
  goTo(tester, '/admin/broadcast');
  await _settle(tester);
  return broadcasts;
}

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _send(WidgetTester tester) async {
  final send = find.widgetWithText(FilledButton, 'Send').first;
  await tester.ensureVisible(send);
  await tester.tap(send);
  await _settle(tester);
}

void main() {
  testWidgets(
    'desktop: one language is enough, the preview follows, and after confirming it is sent and listed',
    (tester) async {
      final broadcasts = await _openBroadcast(tester);
      expect(find.text('Broadcast'), findsWidgets, reason: 'in the menu and as the title');
      expect(find.text('Nothing sent yet'), findsOneWidget);
      expect(find.text('Your message shows here as doctors will see it.'), findsOneWidget);

      await _enter(tester, 'Title (Arabic)', 'صيانة الليلة');
      await _enter(tester, 'Text (Arabic)', 'التطبيق هيقف من 2 لـ 3 الفجر.');
      // The English app shows the Arabic text, as English doctors will get it.
      expect(find.descendant(of: find.bySemanticsLabel('Preview'), matching: find.text('صيانة الليلة')), findsOneWidget);

      await _send(tester);
      expect(find.text('Send this broadcast?'), findsOneWidget);
      expect(find.text("Every doctor gets it at once, in the app and as a push. It can't be taken back."), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Send')));
      await _settle(tester);

      expect(find.text('Sent to 12 doctors'), findsOneWidget);
      final draft = broadcasts.sent.single;
      expect(draft.audience, BroadcastAudience.all);
      expect(draft.toJson().containsKey('titleEn'), isFalse, reason: 'an empty language is left out');
      // The history shows it (in English, filled from the Arabic), and the form is empty again.
      expect(find.text('صيانة الليلة'), findsOneWidget);
      expect(find.textContaining('All doctors, 12 doctors, by Nour Adel'), findsOneWidget);
      expect(tester.widget<TextField>(_field('Title (Arabic)')).controller!.text, isEmpty);
    },
  );

  testWidgets('nothing written, half a language, or no doctor chosen: each is marked and nothing is sent', (tester) async {
    final broadcasts = await _openBroadcast(tester);

    await _send(tester);
    expect(find.text('Write the message in Arabic, English or both.'), findsOneWidget);

    await _enter(tester, 'Title (English)', 'New update');
    await _send(tester);
    expect(find.text('Write the text too.'), findsOneWidget);
    await _enter(tester, 'Text (English)', 'Booking from the app is here.');
    expect(find.text('Write the text too.'), findsNothing, reason: 'typing clears it');

    await tester.tap(find.text('Chosen doctors'));
    await _settle(tester);
    await _send(tester);
    expect(find.text('Choose at least one doctor.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(broadcasts.sent, isEmpty);
  });

  testWidgets('phone: choosing doctors, sending to them, and a refusal when none can receive it', (tester) async {
    final broadcasts = await _openBroadcast(tester, size: _phone);

    await tester.tap(find.text('Chosen doctors'));
    await _settle(tester);
    await tester.tap(find.text('Choose doctors'));
    await _settle(tester);
    // Only doctors who can receive it: active or suspended.
    expect(find.text('Dr Ahmed Ali'), findsOneWidget);
    await tester.tap(find.text('Dr Ahmed Ali'));
    await tester.tap(find.text('Dr Mona Hassan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done (2)'));
    await _settle(tester);
    expect(find.widgetWithText(InputChip, 'Dr Ahmed Ali'), findsOneWidget);
    expect(find.text('2 doctors chosen'), findsOneWidget);

    await _enter(tester, 'Title (English)', 'Holiday hours');
    await _enter(tester, 'Text (English)', 'Support is closed on Friday.');
    await _send(tester);
    expect(find.text("The 2 chosen doctors get it at once, in the app and as a push. It can't be taken back."), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Send')));
    await _settle(tester);
    expect(find.text('Sent to 2 doctors'), findsOneWidget);
    expect(broadcasts.sent.single.doctorIds, ['d1', 'd2']);
    await tester.ensureVisible(find.text('Holiday hours'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chosen doctors, 2 doctors'), findsOneWidget);

    // Nobody chosen can receive it now.
    broadcasts.cannotReceive.add('d3');
    await tester.ensureVisible(find.text('Chosen doctors').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chosen doctors'));
    await _settle(tester);
    await tester.tap(find.text('Choose doctors'));
    await _settle(tester);
    await tester.tap(find.text('Dr Karim Samir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done (1)'));
    await _settle(tester);
    await _enter(tester, 'Title (English)', 'Hello');
    await _enter(tester, 'Text (English)', 'A test');
    await _send(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Send')));
    await _settle(tester);
    expect(find.text("None of these doctors can get it now: they're waiting for review, rejected or disabled."), findsOneWidget);
    expect(broadcasts.sent, hasLength(1));
  });
}
