import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_service.dart';
import 'chat_data.dart';

/// D16 / AS9 / P11. Live: a new message moves its chat to the top and bumps its unread count.
final chatInboxProvider = AsyncNotifierProvider.autoDispose<ChatInboxController, List<ChatSummary>>(ChatInboxController.new);

class ChatInboxController extends AsyncNotifier<List<ChatSummary>> {
  String? _search;

  @override
  Future<List<ChatSummary>> build() {
    final sub = ref.watch(realtimeServiceProvider).events.listen((event) {
      if (event.name == RealtimeEvents.chatMessage) _onMessage(ChatMessage.fromJson(event.data));
    });
    ref.onDispose(sub.cancel);
    return ref.watch(chatRepositoryProvider).inbox(search: _search);
  }

  Future<void> search(String text) async {
    _search = text.trim();
    state = await AsyncValue.guard(() => ref.read(chatRepositoryProvider).inbox(search: _search));
  }

  void _onMessage(ChatMessage m) {
    final list = state.value;
    if (list == null) return;
    final index = list.indexWhere((c) => c.id == m.chatId);
    if (index < 0) {
      ref.invalidateSelf();
      return;
    }
    // Don't count our own side's messages (the server doesn't either).
    final mine = ref.read(_openChatProvider) == m.chatId;
    final chat = list[index].copyWith(
      lastText: m.text, lastType: m.type, lastSenderRole: m.senderRole, lastAt: m.createdAt,
      unreadCount: mine ? 0 : list[index].unreadCount + (_fromOtherSide(m) ? 1 : 0),
    );
    state = AsyncData([chat, ...list.where((c) => c.id != m.chatId)]);
  }

  bool _fromOtherSide(ChatMessage m) {
    return ref.read(chatRepositoryProvider).isStaff ? m.senderRole == 'patient' : m.senderRole != 'patient';
  }

  void markLocallyRead(String chatId) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final c in list) c.id == chatId ? c.copyWith(unreadCount: 0) : c]);
  }
}

/// The chat currently open on screen (its messages are read as they arrive).
final _openChatProvider = NotifierProvider<_OpenChat, String?>(_OpenChat.new);

class _OpenChat extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

/// Total unread chats, for the navigation badge.
final chatUnreadTotalProvider = Provider.autoDispose<int>((ref) =>
    ref.watch(chatInboxProvider).value?.fold<int>(0, (sum, c) => sum + c.unreadCount) ?? 0);

/// D17 / P12: one conversation. Sending shows the message at once; live messages and read ticks
/// arrive over SignalR. Opening it marks it read.
final chatThreadProvider =
    AsyncNotifierProvider.autoDispose.family<ChatThreadController, ChatThread, String>(ChatThreadController.new);

class ChatThreadController extends AsyncNotifier<ChatThread> {
  ChatThreadController(this.chatId);

  final String chatId;
  bool _loadingOlder = false;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  @override
  Future<ChatThread> build() async {
    final sub = ref.watch(realtimeServiceProvider).events.listen(_onEvent);
    ref.onDispose(sub.cancel);
    Future.microtask(() => ref.read(_openChatProvider.notifier).set(chatId));
    ref.onDispose(() {
      // Clear only if no other thread took over.
      try {
        if (ref.read(_openChatProvider) == chatId) ref.read(_openChatProvider.notifier).set(null);
      } catch (_) {}
    });

    final thread = await ref.watch(chatRepositoryProvider).thread(chatId);
    unawaited(_markRead());
    return thread;
  }

  Future<void> _markRead() async {
    try {
      await _repository.markRead(chatId);
      ref.read(chatInboxProvider.notifier).markLocallyRead(chatId);
    } catch (_) {}
  }

  void _onEvent(RealtimeEvent event) {
    final thread = state.value;
    if (thread == null) return;
    if (event.name == RealtimeEvents.chatMessage && event.data['chatId'] == chatId) {
      final m = ChatMessage.fromJson(event.data);
      if (thread.messages.any((x) => x.id == m.id)) return;
      state = AsyncData(ChatThread(chat: thread.chat, messages: [m, ...thread.messages], hasMore: thread.hasMore));
      unawaited(_markRead());
    } else if (event.name == RealtimeEvents.chatRead && event.data['chatId'] == chatId) {
      final at = DateTime.tryParse(event.data['at'] as String? ?? '') ?? DateTime.now();
      final readerIsPatient = event.data['readerRole'] == 'patient';
      state = AsyncData(ChatThread(
        chat: thread.chat,
        messages: [
          for (final m in thread.messages)
            m.readAt == null && (readerIsPatient ? m.senderRole != 'patient' : m.senderRole == 'patient') ? m.copyWith(readAt: at) : m,
        ],
        hasMore: thread.hasMore,
      ));
    }
  }

  Future<void> loadOlder() async {
    final thread = state.value;
    if (thread == null || !thread.hasMore || _loadingOlder || thread.messages.isEmpty) return;
    _loadingOlder = true;
    try {
      final older = await _repository.thread(chatId, before: thread.messages.last.id);
      state = AsyncData(ChatThread(chat: thread.chat, messages: [...thread.messages, ...older.messages], hasMore: older.hasMore));
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> sendText(String text) => _send(() => _repository.sendText(chatId, text));

  Future<void> sendFile(Uint8List bytes, String fileName, String mimeType) =>
      _send(() => _repository.sendFile(chatId, bytes: bytes, fileName: fileName, mimeType: mimeType));

  Future<void> _send(Future<ChatMessage> Function() call) async {
    final message = await call();
    final thread = state.value;
    if (thread == null || thread.messages.any((m) => m.id == message.id)) return;
    state = AsyncData(ChatThread(chat: thread.chat, messages: [message, ...thread.messages], hasMore: thread.hasMore));
  }

  Future<void> saveToFile(ChatMessage message, String category) async {
    final recordId = await _repository.saveToFile(chatId, message.id, category: category);
    final thread = state.value;
    if (thread == null) return;
    state = AsyncData(ChatThread(
      chat: thread.chat,
      messages: [for (final m in thread.messages) m.id == message.id ? m.copyWith(savedRecordId: recordId) : m],
      hasMore: thread.hasMore,
    ));
  }
}

final chatAttachmentProvider = FutureProvider.autoDispose.family<Uint8List, (String, String)>(
  (ref, ids) => ref.watch(chatRepositoryProvider).attachment(ids.$1, ids.$2),
);
