import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows system notifications from inside the app: Windows toasts for events received over
/// SignalR while the app runs (spec 10.2), and in-app banners on mobile in the foreground.
/// Mobile pushes while the app is closed come from FCM, not from here.
abstract interface class LocalNotifier {
  Future<void> init({required void Function(String? route) onTap});
  Future<void> show({required int id, required String title, required String body, String? route});
}

class SystemLocalNotifier implements LocalNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'el3yada_default',
    'el3yada',
    importance: Importance.high,
    priority: Priority.high,
  );

  @override
  Future<void> init({required void Function(String? route) onTap}) async {
    try {
      _ready = await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: DarwinInitializationSettings(requestAlertPermission: false),
              macOS: DarwinInitializationSettings(requestAlertPermission: false),
              windows: WindowsInitializationSettings(
                appName: 'el3yada',
                appUserModelId: 'com.el3yada.app',
                guid: '6f2a7c1e-4b8d-4e43-9a52-3c1d0b7e9f21',
              ),
            ),
            onDidReceiveNotificationResponse: (response) => onTap(response.payload),
          ) ??
          false;
    } catch (error) {
      debugPrint('Local notifications unavailable: $error');
    }
  }

  @override
  Future<void> show({required int id, required String title, required String body, String? route}) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: route,
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails(), windows: WindowsNotificationDetails()),
    );
  }
}

/// Tests and platforms without a notification service.
class SilentLocalNotifier implements LocalNotifier {
  final shown = <String>[];

  @override
  Future<void> init({required void Function(String? route) onTap}) async {}

  @override
  Future<void> show({required int id, required String title, required String body, String? route}) async => shown.add(title);
}

final localNotifierProvider = Provider<LocalNotifier>((ref) => SystemLocalNotifier());
