import 'package:go_router/go_router.dart';

import '../notifications/notifications_screen.dart';
import 'chat_screens.dart';

/// Chat (Phase 5) and notification centre pages for every role.
abstract final class ChatRoutes {
  static final Map<String, GoRouterWidgetBuilder> shellPages = {
    '/doctor/chats': (context, state) => const ChatInboxScreen(basePath: '/doctor'),
    '/assistant/chats': (context, state) => const ChatInboxScreen(basePath: '/assistant'),
    // P11 is shown only with several doctors; with one, the thread opens directly.
    '/patient/chat': (context, state) => const ChatInboxScreen(basePath: '/patient', openSingle: true),
    for (final role in ['doctor', 'assistant', 'patient', 'admin'])
      '/$role/notifications': (context, state) => const NotificationsScreen(),
  };

  static final List<GoRoute> detailRoutes = [
    GoRoute(
      path: '/doctor/chats/:id',
      builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['id']!, staff: true, canSaveToFile: true),
    ),
    // The server checks `filesManage` again when an assistant saves a file.
    GoRoute(
      path: '/assistant/chats/:id',
      builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['id']!, staff: true, canSaveToFile: true),
    ),
    GoRoute(
      path: '/patient/chats/:id',
      builder: (context, state) => ChatThreadScreen(chatId: state.pathParameters['id']!, staff: false),
    ),
  ];
}
