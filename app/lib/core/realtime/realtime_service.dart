import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/domain/auth_session.dart';
import '../config/env.dart';

/// Event names sent by the API's SignalR hub (`Infrastructure/Realtime/AppHub.cs`).
abstract final class RealtimeEvents {
  static const notification = 'notification';
  static const chatMessage = 'chatMessage';
  static const chatRead = 'chatRead';
  static const boardChanged = 'boardChanged';
  static const queueChanged = 'queueChanged';

  static const all = [notification, chatMessage, chatRead, boardChanged, queueChanged];
}

class RealtimeEvent {
  const RealtimeEvent(this.name, this.data);

  final String name;
  final Map<String, dynamic> data;
}

enum RealtimeStatus { disconnected, connecting, connected }

/// One SignalR connection per signed-in session (spec 9.6, 10.2): chat messages, unread counts,
/// notifications for running apps (Windows toasts) and live board changes. Clients only listen;
/// every change goes through the REST API. Reconnects on its own.
abstract interface class RealtimeService {
  Stream<RealtimeEvent> get events;
  ValueListenable<RealtimeStatus> get status;

  Future<void> connect(AuthSession session);
  Future<void> disconnect();

  /// Staff: watch one branch's live board (checked on the server).
  Future<void> joinBoard(String branchId);
  Future<void> leaveBoard(String branchId);

  /// Anyone: "now serving" numbers of a branch, no names (BR-AP15).
  Future<void> joinQueue(String branchId);
}

class SignalRRealtimeService implements RealtimeService {
  SignalRRealtimeService(this.baseUrl);

  final String baseUrl;
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _status = ValueNotifier(RealtimeStatus.disconnected);
  final _boards = <String>{};
  final _queues = <String>{};
  HubConnection? _connection;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  ValueListenable<RealtimeStatus> get status => _status;

  @override
  Future<void> connect(AuthSession session) async {
    await disconnect();
    final connection = HubConnectionBuilder()
        .withUrl('$baseUrl/hubs/app', options: HttpConnectionOptions(accessTokenFactory: () async => session.accessToken))
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .build();
    for (final name in RealtimeEvents.all) {
      connection.on(name, (args) {
        final payload = args != null && args.isNotEmpty ? args.first : null;
        if (payload is Map) _events.add(RealtimeEvent(name, Map<String, dynamic>.from(payload)));
      });
    }
    connection.onreconnecting(({error}) => _status.value = RealtimeStatus.connecting);
    connection.onreconnected(({connectionId}) async {
      _status.value = RealtimeStatus.connected;
      // Groups are per connection: join them again.
      for (final b in _boards) {
        await _invoke('JoinBoard', b);
      }
      for (final q in _queues) {
        await _invoke('JoinQueue', q);
      }
    });
    connection.onclose(({error}) => _status.value = RealtimeStatus.disconnected);
    _connection = connection;
    _status.value = RealtimeStatus.connecting;
    try {
      await connection.start();
      _status.value = RealtimeStatus.connected;
    } catch (error) {
      debugPrint('SignalR connect failed: $error');
      _status.value = RealtimeStatus.disconnected;
    }
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    _boards.clear();
    _queues.clear();
    if (connection != null) await connection.stop();
    _status.value = RealtimeStatus.disconnected;
  }

  Future<void> _invoke(String method, String arg) async {
    try {
      await _connection?.invoke(method, args: [arg]);
    } catch (error) {
      debugPrint('SignalR $method failed: $error');
    }
  }

  @override
  Future<void> joinBoard(String branchId) async {
    _boards.add(branchId);
    await _invoke('JoinBoard', branchId);
  }

  @override
  Future<void> leaveBoard(String branchId) async {
    _boards.remove(branchId);
    await _invoke('LeaveBoard', branchId);
  }

  @override
  Future<void> joinQueue(String branchId) async {
    _queues.add(branchId);
    await _invoke('JoinQueue', branchId);
  }
}

/// Dev builds with the offline test accounts and tests: no server. [emit] lets tests push events.
class FakeRealtimeService implements RealtimeService {
  final _events = StreamController<RealtimeEvent>.broadcast();
  final _status = ValueNotifier(RealtimeStatus.connected);

  void emit(RealtimeEvent event) => _events.add(event);

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  ValueListenable<RealtimeStatus> get status => _status;

  @override
  Future<void> connect(AuthSession session) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> joinBoard(String branchId) async {}

  @override
  Future<void> leaveBoard(String branchId) async {}

  @override
  Future<void> joinQueue(String branchId) async {}
}

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final RealtimeService service = Env.useFakeAuth ? FakeRealtimeService() : SignalRRealtimeService(Env.apiBaseUrl);
  // Follows the session: connect after sign-in, disconnect on sign-out.
  ref.listen(authControllerProvider, (previous, next) {
    final session = next.value;
    // A16 (an account in its deletion grace period) needs no live updates.
    if (session == null || session.isPendingDeletion) {
      service.disconnect();
    } else if (previous?.value?.accessToken != session.accessToken || (previous?.value?.isPendingDeletion ?? false)) {
      service.connect(session);
    }
  }, fireImmediately: true);
  ref.onDispose(service.disconnect);
  return service;
});

/// Every real-time event, for widgets and providers to filter.
final realtimeEventsProvider = StreamProvider<RealtimeEvent>((ref) => ref.watch(realtimeServiceProvider).events);
