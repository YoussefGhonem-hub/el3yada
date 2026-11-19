import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../auth/application/auth_controller.dart';
import '../auth/domain/user_role.dart';

// ---- Models (mirror Features/Chat/ChatDtos.cs) --------------------------------------------------

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.name,
    this.nameEn,
    this.fileNumber,
    this.lastText,
    this.lastType,
    this.lastSenderRole,
    this.lastAt,
    this.unreadCount = 0,
    this.enabled = true,
    this.canSend = true,
    this.unavailableReason,
  });

  final String id;
  final String doctorId;
  final String patientId;

  /// The other side: the doctor for patients, the patient for staff.
  final String name;
  final String? nameEn;
  final int? fileNumber;
  final String? lastText;
  final String? lastType;
  final String? lastSenderRole;
  final DateTime? lastAt;
  final int unreadCount;
  final bool enabled;
  final bool canSend;

  /// `CHAT_UNAVAILABLE` or `DOCTOR_SUSPENDED` when [canSend] is false.
  final String? unavailableReason;

  String displayName({required bool arabic}) => !arabic && nameEn != null ? nameEn! : name;

  ChatSummary copyWith({int? unreadCount, String? lastText, String? lastType, String? lastSenderRole, DateTime? lastAt, bool? enabled}) =>
      ChatSummary(
        id: id, doctorId: doctorId, patientId: patientId, name: name, nameEn: nameEn, fileNumber: fileNumber,
        lastText: lastText ?? this.lastText, lastType: lastType ?? this.lastType,
        lastSenderRole: lastSenderRole ?? this.lastSenderRole, lastAt: lastAt ?? this.lastAt,
        unreadCount: unreadCount ?? this.unreadCount, enabled: enabled ?? this.enabled, canSend: canSend,
        unavailableReason: unavailableReason,
      );

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    final c = json['counterpart'] as Map<String, dynamic>;
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return ChatSummary(
      id: json['id'] as String,
      doctorId: json['doctorId'] as String,
      patientId: json['patientId'] as String,
      name: c['name'] as String,
      nameEn: c['nameEn'] as String?,
      fileNumber: json['fileNumber'] as int?,
      lastText: last?['text'] as String?,
      lastType: last?['type'] as String?,
      lastSenderRole: last?['senderRole'] as String?,
      lastAt: last == null ? null : DateTime.parse(last['at'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      canSend: json['canSend'] as bool? ?? true,
      unavailableReason: json['unavailableReason'] as String?,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.type,
    this.text,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    required this.createdAt,
    this.readAt,
    this.savedRecordId,
    this.pending = false,
  });

  final String id;
  final String chatId;
  final String senderId;

  /// `patient`, `doctor` or `assistant`.
  final String senderRole;
  final String senderName;

  /// `text`, `image` or `file`.
  final String type;
  final String? text;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? savedRecordId;

  /// Shown while sending, before the server answers.
  final bool pending;

  bool get hasAttachment => type != 'text';
  bool get isImage => type == 'image';

  ChatMessage copyWith({DateTime? readAt, String? savedRecordId}) => ChatMessage(
        id: id, chatId: chatId, senderId: senderId, senderRole: senderRole, senderName: senderName, type: type,
        text: text, fileName: fileName, mimeType: mimeType, sizeBytes: sizeBytes, createdAt: createdAt,
        readAt: readAt ?? this.readAt, savedRecordId: savedRecordId ?? this.savedRecordId,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final a = json['attachment'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      senderRole: json['senderRole'] as String,
      senderName: json['senderName'] as String,
      type: json['type'] as String,
      text: json['text'] as String?,
      fileName: a?['fileName'] as String?,
      mimeType: a?['mimeType'] as String?,
      sizeBytes: a?['sizeBytes'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] == null ? null : DateTime.parse(json['readAt'] as String),
      savedRecordId: json['savedRecordId'] as String?,
    );
  }
}

class ChatThread {
  const ChatThread({required this.chat, required this.messages, required this.hasMore});

  final ChatSummary chat;

  /// Newest first.
  final List<ChatMessage> messages;
  final bool hasMore;
}

// ---- Repository -------------------------------------------------------------------------------

/// The same API for both sides: `/api/staff/chats` or `/api/patient/chats`.
abstract interface class ChatRepository {
  /// True for the clinic side (doctor, assistant).
  bool get isStaff;

  Future<List<ChatSummary>> inbox({String? search});
  Future<ChatThread> thread(String chatId, {String? before});
  Future<ChatMessage> sendText(String chatId, String text);
  Future<ChatMessage> sendFile(String chatId, {required Uint8List bytes, required String fileName, required String mimeType});
  Future<void> markRead(String chatId);
  Future<Uint8List> attachment(String chatId, String messageId);

  /// Staff only: BR-C4. Returns the new record id.
  Future<String> saveToFile(String chatId, String messageId, {required String category, String? title});

  /// Staff only: open the chat with a linked patient.
  Future<ChatSummary> openForPatient(String patientId);
}

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._dio, {required this.staff});

  final Dio _dio;
  final bool staff;

  @override
  bool get isStaff => staff;

  String get _base => staff ? '/api/staff/chats' : '/api/patient/chats';

  Future<T> _wrap<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiError.from(error);
    }
  }

  @override
  Future<List<ChatSummary>> inbox({String? search}) => _wrap(() async {
        final r = await _dio.get<List<dynamic>>(_base, queryParameters: {if (search != null && search.isNotEmpty) 'search': search});
        return [for (final c in r.data!) ChatSummary.fromJson(c as Map<String, dynamic>)];
      });

  @override
  Future<ChatThread> thread(String chatId, {String? before}) => _wrap(() async {
        final r = await _dio.get<Map<String, dynamic>>('$_base/$chatId', queryParameters: {'limit': 30, 'before': ?before});
        final d = r.data!;
        return ChatThread(
          chat: ChatSummary.fromJson(d['chat'] as Map<String, dynamic>),
          messages: [for (final m in d['messages'] as List) ChatMessage.fromJson(m as Map<String, dynamic>)],
          hasMore: d['hasMore'] as bool,
        );
      });

  @override
  Future<ChatMessage> sendText(String chatId, String text) => _wrap(() async =>
      ChatMessage.fromJson((await _dio.post<Map<String, dynamic>>('$_base/$chatId/messages', data: {'text': text})).data!));

  @override
  Future<ChatMessage> sendFile(String chatId, {required Uint8List bytes, required String fileName, required String mimeType}) =>
      _wrap(() async {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(mimeType)),
        });
        return ChatMessage.fromJson((await _dio.post<Map<String, dynamic>>('$_base/$chatId/attachments', data: form)).data!);
      });

  @override
  Future<void> markRead(String chatId) => _wrap(() => _dio.post<void>('$_base/$chatId/read'));

  @override
  Future<Uint8List> attachment(String chatId, String messageId) => _wrap(() async {
        final r = await _dio.get<List<int>>('$_base/$chatId/messages/$messageId/attachment', options: Options(responseType: ResponseType.bytes));
        return Uint8List.fromList(r.data ?? const []);
      });

  @override
  Future<String> saveToFile(String chatId, String messageId, {required String category, String? title}) => _wrap(() async =>
      (await _dio.post<Map<String, dynamic>>('$_base/$chatId/messages/$messageId/save-to-file', data: {'category': category, 'title': title}))
          .data!['recordId'] as String);

  @override
  Future<ChatSummary> openForPatient(String patientId) => _wrap(() async =>
      ChatSummary.fromJson((await _dio.post<Map<String, dynamic>>('$_base/by-patient/$patientId')).data!));
}

/// Offline chats for dev builds and tests.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({required this.staff, DateTime? now}) {
    final t = now ?? DateTime.now();
    _chats = [
      ChatSummary(
        id: 'chat-a', doctorId: 'doc-a', patientId: 'pat-1',
        name: staff ? 'محمد إبراهيم' : 'د. أحمد سامي', nameEn: staff ? null : 'Dr. Ahmed Samy', fileNumber: staff ? 1 : null,
        lastText: 'صباح الخير يا دكتور', lastType: 'text', lastSenderRole: 'patient', lastAt: t.subtract(const Duration(hours: 1)),
        unreadCount: 1,
      ),
      if (!staff)
        ChatSummary(id: 'chat-b', doctorId: 'doc-b', patientId: 'pat-1', name: 'د. منى حسن', nameEn: 'Dr. Mona Hassan'),
    ];
    _messages = {
      'chat-a': [
        ChatMessage(id: 'm-1', chatId: 'chat-a', senderId: 'dev-patient', senderRole: 'patient', senderName: 'محمد إبراهيم',
            type: 'text', text: 'صباح الخير يا دكتور', createdAt: t.subtract(const Duration(hours: 1))),
      ],
      'chat-b': [],
    };
  }

  final bool staff;

  @override
  bool get isStaff => staff;
  late List<ChatSummary> _chats;
  late final Map<String, List<ChatMessage>> _messages;
  int _next = 100;

  String get _me => staff ? 'dev-doctor' : 'dev-patient';

  @override
  Future<List<ChatSummary>> inbox({String? search}) async =>
      _chats.where((c) => search == null || search.isEmpty || c.name.contains(search)).toList();

  @override
  Future<ChatThread> thread(String chatId, {String? before}) async {
    final chat = _chats.firstWhere((c) => c.id == chatId, orElse: () => throw const ApiError(ApiError.notFound, status: 404));
    return ChatThread(chat: chat, messages: before == null ? [...?_messages[chatId]] : const [], hasMore: false);
  }

  ChatMessage _add(String chatId, ChatMessage m) {
    _messages[chatId] = [m, ...?_messages[chatId]];
    _chats = [for (final c in _chats) c.id == chatId ? c.copyWith(lastText: m.text, lastType: m.type, lastSenderRole: m.senderRole, lastAt: m.createdAt) : c];
    return m;
  }

  @override
  Future<ChatMessage> sendText(String chatId, String text) async => _add(chatId, ChatMessage(
        id: 'm-${_next++}', chatId: chatId, senderId: _me, senderRole: staff ? 'doctor' : 'patient',
        senderName: staff ? 'د. أحمد سامي' : 'محمد إبراهيم', type: 'text', text: text, createdAt: DateTime.now()));

  @override
  Future<ChatMessage> sendFile(String chatId, {required Uint8List bytes, required String fileName, required String mimeType}) async =>
      _add(chatId, ChatMessage(
        id: 'm-${_next++}', chatId: chatId, senderId: _me, senderRole: staff ? 'doctor' : 'patient',
        senderName: staff ? 'د. أحمد سامي' : 'محمد إبراهيم', type: mimeType.startsWith('image/') ? 'image' : 'file',
        fileName: fileName, mimeType: mimeType, sizeBytes: bytes.length, createdAt: DateTime.now()));

  @override
  Future<void> markRead(String chatId) async => _chats = [for (final c in _chats) c.id == chatId ? c.copyWith(unreadCount: 0) : c];

  @override
  Future<Uint8List> attachment(String chatId, String messageId) async => Uint8List(0);

  @override
  Future<String> saveToFile(String chatId, String messageId, {required String category, String? title}) async => 'rec-chat';

  @override
  Future<ChatSummary> openForPatient(String patientId) async => _chats.first;
}

/// The chat API for the signed-in role.
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final role = ref.watch(authControllerProvider).value?.role;
  final staff = role == UserRole.doctor || role == UserRole.assistant;
  if (Env.useFakeAuth) return FakeChatRepository(staff: staff);
  return ApiChatRepository(ref.watch(dioProvider), staff: staff);
});
