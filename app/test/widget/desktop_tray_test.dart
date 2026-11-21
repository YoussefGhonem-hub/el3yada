import 'package:el3yada/core/notifications/local_notifier.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/core/platform/desktop_tray.dart';
import 'package:el3yada/core/settings/app_settings.dart';
import 'package:el3yada/features/notifications/notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/admin_support.dart' show appContainer;
import '../support/app_flow.dart';

/// Records what the app asks of the tray.
class _FakeTray implements DesktopTray {
  TrayTexts? startedWith;
  VoidCallback? onFirstHide;
  final updates = <(TrayTexts, int)>[];
  int shown = 0;

  @override
  bool start(TrayTexts texts, {required VoidCallback onFirstHide}) {
    startedWith = texts;
    this.onFirstHide = onFirstHide;
    return true;
  }

  @override
  void update(TrayTexts texts, {required int unread}) => updates.add((texts, unread));

  @override
  void showWindow() => shown++;
}

/// Keeps the tap handler so the test can tap a toast.
class _TappableNotifier extends SilentLocalNotifier {
  void Function(String? route)? onTap;

  @override
  Future<void> init({required void Function(String? route) onTap}) async => this.onTap = onTap;
}

void main() {
  testWidgets(
    'Windows tray: started once with the labels, follows the unread count and the language, '
    'says it still runs when hidden, and a toast brings the window back',
    (tester) async {
      final trayIcon = _FakeTray();
      final notifier = _TappableNotifier();
      await pumpApp(
        tester,
        platform: AppPlatform.desktop,
        extra: [
          desktopTrayProvider.overrideWithValue(trayIcon),
          localNotifierProvider.overrideWithValue(notifier),
          notificationsRepositoryProvider.overrideWithValue(FakeNotificationsRepository()),
        ],
      );

      expect(
        trayIcon.startedWith,
        const TrayTexts(open: 'Open el3yada', startWithWindows: 'Start with Windows', quit: 'Quit', tooltip: 'el3yada'),
      );

      await signIn(tester, 'doctor@el3yada.dev');
      // The offline notifications have one unread: a dot on the icon and a count in the tooltip.
      expect(trayIcon.updates.last.$2, 1);
      expect(trayIcon.updates.last.$1.tooltip, 'el3yada · 1 unread');

      await appContainer(tester).read(appSettingsProvider.notifier).setLocale(const Locale('ar'));
      await settle(tester);
      final arabic = trayIcon.updates.last.$1;
      expect(arabic.quit, 'خروج');
      expect(arabic.startWithWindows, 'يشتغل مع بداية ويندوز');

      // The window went to the tray: say so once, with a toast.
      trayIcon.onFirstHide!();
      expect(notifier.shown.single, isNotEmpty);

      // Tapping a toast shows the window again, then opens its screen.
      notifier.onTap!('/doctor/notifications');
      await settle(tester);
      expect(trayIcon.shown, 1);
    },
  );

  testWidgets('elsewhere there is no tray: nothing starts and nothing updates', (tester) async {
    await pumpApp(tester, platform: AppPlatform.mobile);
    expect(appContainer(tester).read(desktopTrayProvider), isA<NoDesktopTray>(), reason: 'tests and non-Windows platforms');
  });
}
