import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/realtime/realtime_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets(
    'patient with two doctors sees the chats list and sends a message (P11, P12)',
    (tester) async {
      await pumpSignedIn(tester, identifier: '01000000002');
      await tester.tap(find.byTooltip('Chats'));
      await tester.pumpAndSettle();

      expect(find.text('Dr. Ahmed Samy'), findsOneWidget);
      expect(find.text('Dr. Mona Hassan'), findsOneWidget);
      await tester.tap(find.text('Dr. Ahmed Samy'));
      await tester.pumpAndSettle();

      expect(find.text('صباح الخير يا دكتور'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'شكراً');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('شكراً'), findsOneWidget);
    },
  );

  testWidgets(
    'a live message from the clinic appears in the open thread, labelled for assistants',
    (tester) async {
      final rig = await pumpSignedIn(tester, identifier: '01000000002');
      await tester.tap(find.byTooltip('Chats'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dr. Ahmed Samy'));
      await tester.pumpAndSettle();

      rig.realtime.emit(
        RealtimeEvent(RealtimeEvents.chatMessage, {
          'id': 'live-1',
          'chatId': 'chat-a',
          'senderId': 'as-1',
          'senderRole': 'assistant',
          'senderName': 'سارة',
          'type': 'text',
          'text': 'الدكتور سيرد قريباً',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('الدكتور سيرد قريباً'), findsOneWidget);
      expect(find.text('Clinic assistant — سارة'), findsOneWidget); // BR-C8
    },
  );

  testWidgets('doctor on desktop: inbox with unread badge and the thread', (
    tester,
  ) async {
    await pumpSignedIn(
      tester,
      identifier: 'doctor@el3yada.dev',
      platform: AppPlatform.desktop,
      size: const Size(1400, 900),
    );
    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();

    expect(find.text('محمد إبراهيم · File no. 1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.widgetWithText(Badge, '1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('محمد إبراهيم · File no. 1'));
    await tester.pumpAndSettle();
    expect(find.text('صباح الخير يا دكتور'), findsOneWidget);
    expect(find.byTooltip('Attach'), findsOneWidget);
  });

  testWidgets(
    'notification centre: badge, list, live arrival with a toast, mark all read',
    (tester) async {
      final rig = await pumpSignedIn(tester, identifier: '01000000002');

      expect(find.widgetWithText(Badge, '1'), findsOneWidget); // the bell
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('New prescription from Dr. Ahmed Samy'), findsOneWidget);

      rig.realtime.emit(
        RealtimeEvent(RealtimeEvents.notification, {
          'id': 'n-live',
          'type': 'fileAdded',
          'titleAr': 'ملف جديد',
          'titleEn': 'New file',
          'bodyAr': 'تمت إضافة ملف',
          'bodyEn': 'A file was added',
          'route': '/patient/records/rec-1',
          'isRead': false,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('New file'), findsOneWidget);
      expect(
        rig.notifier.shown,
        contains('New file'),
      ); // Windows toast path (spec 10.2)

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      final markAll = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Mark all as read'),
      );
      expect(markAll.onPressed, isNull);
    },
  );

  testWidgets('tapping a notification opens its screen', (tester) async {
    await pumpSignedIn(tester, identifier: '01000000002');
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New prescription from Dr. Ahmed Samy'));
    await tester.pumpAndSettle();
    expect(find.text('Medication prescription'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
  });
}
