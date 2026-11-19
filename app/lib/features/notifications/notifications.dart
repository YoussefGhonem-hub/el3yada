import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/env.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/notifications/local_notifier.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/settings/app_settings.dart';
import '../auth/application/auth_controller.dart';

// ---- Model ------------------------------------------------------------------------------------

/// One in-app notification (spec 10.1). Both languages are stored; the app shows the current one.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    this.route,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;

  /// Where tapping it goes (`data.route`).
  final String? route;
  final bool isRead;
  final DateTime createdAt;

  String title({required bool arabic}) => arabic ? titleAr : titleEn;
  String body({required bool arabic}) => arabic ? bodyAr : bodyEn;

  AppNotification read() => AppNotification(
        id: id, type: type, titleAr: titleAr, titleEn: titleEn, bodyAr: bodyAr, bodyEn: bodyEn,
        route: route, isRead: true, createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        titleAr: json['titleAr'] as String,
        titleEn: json['titleEn'] as String,
        bodyAr: json['bodyAr'] as String,
        bodyEn: json['bodyEn'] as String,
        route: json['route'] as String?,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class NotificationPage {
  const NotificationPage({required this.items, required this.hasMore, required this.unreadCount});

  final List<AppNotification> items;
  final bool hasMore;
  final int unreadCount;
}

// ---- Data -------------------------------------------------------------------------------------

abstract interface class NotificationsRepository {
  Future<NotificationPage> list({int page = 1});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<void> markAllRead();

  /// After sign-in and when the push token changes.
  Future<void> registerDevice({required String deviceId, required String platform, String? pushToken, required String appVersion});

  /// On logout, so this device gets no more pushes (spec 7.2).
  Future<void> unregisterDevice(String deviceId);
}

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository(this._dio);

  final Dio _dio;

  Future<T> _wrap<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ApiError.from(error);
    }
  }

  @override
  Future<NotificationPage> list({int page = 1}) => _wrap(() async {
        final response = await _dio.get<Map<String, dynamic>>('/api/me/notifications', queryParameters: {'page': page, 'pageSize': 25});
        final data = response.data!;
        final p = data['page'] as Map<String, dynamic>;
        final items = [for (final i in p['items'] as List) AppNotification.fromJson(i as Map<String, dynamic>)];
        return NotificationPage(
          items: items,
          hasMore: (p['page'] as int) * (p['pageSize'] as int) < (p['totalCount'] as int),
          unreadCount: data['unreadCount'] as int,
        );
      });

  @override
  Future<int> unreadCount() => _wrap(() async =>
      (await _dio.get<Map<String, dynamic>>('/api/me/notifications/unread-count')).data!['count'] as int);

  @override
  Future<void> markRead(String id) => _wrap(() => _dio.post<void>('/api/me/notifications/$id/read'));

  @override
  Future<void> markAllRead() => _wrap(() => _dio.post<void>('/api/me/notifications/read-all'));

  @override
  Future<void> registerDevice({required String deviceId, required String platform, String? pushToken, required String appVersion}) =>
      _wrap(() => _dio.put<void>('/api/me/devices', data: {
            'deviceId': deviceId, 'platform': platform, 'fcmToken': pushToken, 'appVersion': appVersion,
          }));

  @override
  Future<void> unregisterDevice(String deviceId) => _wrap(() => _dio.delete<void>('/api/me/devices/$deviceId'));
}

class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({DateTime? now}) {
    final t = now ?? DateTime.now();
    _items = [
      AppNotification(
        id: 'n-1', type: 'prescriptionSent', titleAr: 'روشتة جديدة من د. أحمد سامي', titleEn: 'New prescription from Dr. Ahmed Samy',
        bodyAr: 'اضغط لعرض الروشتة', bodyEn: 'Tap to see it', route: '/patient/prescriptions/rx-med', isRead: false,
        createdAt: t.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'n-2', type: 'sessionRecorded', titleAr: 'تم تسجيل زيارة جديدة', titleEn: 'A new visit was recorded',
        bodyAr: 'اضغط لعرض الزيارة', bodyEn: 'Tap to see the visit', route: '/patient/visits/visit-b1', isRead: true,
        createdAt: t.subtract(const Duration(days: 1)),
      ),
    ];
  }

  late List<AppNotification> _items;

  @override
  Future<NotificationPage> list({int page = 1}) async =>
      NotificationPage(items: _items, hasMore: false, unreadCount: _items.where((n) => !n.isRead).length);

  @override
  Future<int> unreadCount() async => _items.where((n) => !n.isRead).length;

  @override
  Future<void> markRead(String id) async => _items = [for (final n in _items) n.id == id ? n.read() : n];

  @override
  Future<void> markAllRead() async => _items = [for (final n in _items) n.read()];

  @override
  Future<void> registerDevice({required String deviceId, required String platform, String? pushToken, required String appVersion}) async {}

  @override
  Future<void> unregisterDevice(String deviceId) async {}
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  if (Env.useFakeAuth) return FakeNotificationsRepository();
  return ApiNotificationsRepository(ref.watch(dioProvider));
});

// ---- Application ------------------------------------------------------------------------------

/// The notification centre list. A notification that arrives over SignalR is added on top.
final notificationsProvider = AsyncNotifierProvider.autoDispose<NotificationsController, NotificationPage>(NotificationsController.new);

class NotificationsController extends AsyncNotifier<NotificationPage> {
  int _page = 1;

  NotificationsRepository get _repository => ref.read(notificationsRepositoryProvider);

  @override
  Future<NotificationPage> build() async {
    _page = 1;
    final sub = ref.watch(realtimeServiceProvider).events.where((e) => e.name == RealtimeEvents.notification).listen((event) {
      final current = state.value;
      if (current == null) return;
      final n = AppNotification.fromJson(event.data);
      if (current.items.any((x) => x.id == n.id)) return;
      state = AsyncData(NotificationPage(items: [n, ...current.items], hasMore: current.hasMore, unreadCount: current.unreadCount + 1));
    });
    ref.onDispose(sub.cancel);
    return ref.watch(notificationsRepositoryProvider).list();
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore) return;
    final next = await _repository.list(page: _page + 1);
    _page++;
    state = AsyncData(NotificationPage(items: [...current.items, ...next.items], hasMore: next.hasMore, unreadCount: next.unreadCount));
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    final current = state.value;
    if (current != null) {
      state = AsyncData(NotificationPage(
        items: [for (final x in current.items) x.id == n.id ? x.read() : x],
        hasMore: current.hasMore,
        unreadCount: (current.unreadCount - 1).clamp(0, 1 << 30),
      ));
    }
    ref.invalidate(unreadNotificationsProvider);
    await _repository.markRead(n.id);
  }

  Future<void> markAllRead() async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(NotificationPage(items: [for (final x in current.items) x.read()], hasMore: current.hasMore, unreadCount: 0));
    }
    await _repository.markAllRead();
    ref.invalidate(unreadNotificationsProvider);
  }
}

/// The bell badge. Refreshed when a notification arrives live.
final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  final sub = ref.watch(realtimeServiceProvider).events
      .where((e) => e.name == RealtimeEvents.notification)
      .listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});

// ---- Device registration and toasts -----------------------------------------------------------

/// The FCM token of this device. Returns null until Firebase is configured (`flutterfire configure`,
/// then a firebase_messaging implementation of this interface). Windows never has one (spec 10.2).
abstract interface class PushTokenSource {
  Future<String?> token();

  /// Asks for permission after login, not on first launch (spec 10.2).
  Future<void> requestPermission();
}

class NoPushTokenSource implements PushTokenSource {
  @override
  Future<String?> token() async => null;

  @override
  Future<void> requestPermission() async {}
}

final pushTokenSourceProvider = Provider<PushTokenSource>((ref) => NoPushTokenSource());

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0');

String currentPlatform() {
  if (kIsWeb) return 'android';
  if (Platform.isIOS) return 'ios';
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  return 'android';
}

/// Registers the device after sign-in, removes it on sign-out, and turns live notifications into
/// system toasts on desktop (Windows has no FCM, spec 10.2). Created once in `El3yadaApp`.
final notificationSetupProvider = Provider<void>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  const deviceKey = 'device.id';
  var deviceId = prefs.getString(deviceKey);
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    prefs.setString(deviceKey, deviceId);
  }
  final id = deviceId;

  ref.listen(authControllerProvider, (previous, next) async {
    final before = previous?.value;
    final now = next.value;
    final repository = ref.read(notificationsRepositoryProvider);
    try {
      if (now != null && before?.userId != now.userId) {
        final push = ref.read(pushTokenSourceProvider);
        await push.requestPermission();
        await repository.registerDevice(deviceId: id, platform: currentPlatform(), pushToken: await push.token(), appVersion: appVersion);
      } else if (now == null && before != null) {
        await repository.unregisterDevice(id);
      }
    } catch (error) {
      debugPrint('Device registration failed: $error');
    }
  }, fireImmediately: true);

  final realtime = ref.watch(realtimeServiceProvider);
  final sub = realtime.events.where((e) => e.name == RealtimeEvents.notification).listen((event) {
    final n = AppNotification.fromJson(event.data);
    final arabic = ref.read(appSettingsProvider).isArabic;
    ref.read(localNotifierProvider).show(id: n.id.hashCode, title: n.title(arabic: arabic), body: n.body(arabic: arabic), route: n.route);
  });
  ref.onDispose(sub.cancel);
});
