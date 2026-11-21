import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nativeapi/nativeapi.dart' show LaunchAtLogin;
import 'package:tray_manager/tray_manager.dart' as tray;
import 'package:window_manager/window_manager.dart' as win;

/// What the tray shows, in the app's language.
@immutable
class TrayTexts {
  const TrayTexts({required this.open, required this.startWithWindows, required this.quit, required this.tooltip});

  final String open;
  final String startWithWindows;
  final String quit;

  /// The app's name, and the unread count when there is one.
  final String tooltip;

  @override
  bool operator ==(Object other) =>
      other is TrayTexts &&
      other.open == open &&
      other.startWithWindows == startWithWindows &&
      other.quit == quit &&
      other.tooltip == tooltip;

  @override
  int get hashCode => Object.hash(open, startWithWindows, quit, tooltip);
}

/// The Windows system tray (spec 10.2 [S]): Windows gets no push, so
/// closing the window hides it to the tray instead of quitting, and the
/// toasts for new notifications keep coming. The tray icon opens the window
/// again; its menu has Open, "Start with Windows" and Quit. A coral dot on
/// the icon means unread notifications.
abstract interface class DesktopTray {
  /// Puts the icon in the tray and starts hiding the window on close. False
  /// where there is no tray (then closing quits, as before).
  /// [onFirstHide] runs the first time the window goes to the tray.
  bool start(TrayTexts texts, {required VoidCallback onFirstHide});

  /// New labels (the language changed) or a new unread count.
  void update(TrayTexts texts, {required int unread});

  /// Brings the window back (a toast was tapped, or the tray icon).
  void showWindow();
}

/// Phones, macOS, tests: no tray.
class NoDesktopTray implements DesktopTray {
  const NoDesktopTray();

  @override
  bool start(TrayTexts texts, {required VoidCallback onFirstHide}) => false;

  @override
  void update(TrayTexts texts, {required int unread}) {}

  @override
  void showWindow() {}
}

final desktopTrayProvider = Provider<DesktopTray>((ref) {
  // `flutter test` runs on the developer's Windows too, without a window.
  final testing = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  if (kIsWeb || !Platform.isWindows || testing) return const NoDesktopTray();
  return WindowsDesktopTray();
});

/// tray_manager and window_manager (their native API) on Windows.
class WindowsDesktopTray implements DesktopTray {
  static const _icon = 'assets/tray/tray_icon.png';
  static const _iconUnread = 'assets/tray/tray_icon_unread.png';

  tray.TrayIcon? _tray;
  tray.Menu? _menu;
  win.Window? _window;
  LaunchAtLogin? _startup;
  bool _quitting = false;
  bool _hiddenOnce = false;
  bool? _showsUnread;
  TrayTexts? _texts;

  @override
  bool start(TrayTexts texts, {required VoidCallback onFirstHide}) {
    try {
      final window = win.WindowManager.instance.getCurrent();
      final icon = window == null ? null : tray.TrayIcon.create();
      if (window == null || icon == null) return false;
      _window = window;
      _tray = icon;
      _startup = LaunchAtLogin.createWithIdAndDisplayName('com.el3yada.app', 'el3yada')
        ?..setProgram(Platform.resolvedExecutable, const []);
      icon
        ..setContextMenuTrigger(tray.ContextMenuTrigger.rightClicked)
        ..addListener((event) {
          if (event is tray.TrayIconClickedEvent || event is tray.TrayIconDoubleClickedEvent) showWindow();
        });
      update(texts, unread: 0);
      icon.setVisible(true);
      // The close button hides the window; Quit in the menu really closes it.
      window.addListener((event) {
        if (event is! win.WindowCloseRequestedEvent || _quitting) return;
        event.request.cancel();
        window.hide();
        if (!_hiddenOnce) {
          _hiddenOnce = true;
          onFirstHide();
        }
      });
      return true;
    } catch (error) {
      debugPrint('System tray unavailable: $error');
      return false;
    }
  }

  @override
  void update(TrayTexts texts, {required int unread}) {
    final icon = _tray;
    if (icon == null) return;
    final unreadNow = unread > 0;
    if (unreadNow != _showsUnread) {
      final image = tray.ImageAsset.fromAsset(unreadNow ? _iconUnread : _icon);
      if (image != null) {
        icon.icon = image;
        _showsUnread = unreadNow;
      }
    }
    icon.setTooltip(texts.tooltip);
    if (texts != _texts) {
      _texts = texts;
      _setMenu(texts);
    }
  }

  void _setMenu(TrayTexts texts) {
    final menu = tray.Menu.create();
    if (menu == null) return;
    tray.MenuItem? item(String label, tray.MenuItemType type, VoidCallback onClick) {
      final item = tray.MenuItem.createWithLabelAndType(label, type);
      item?.addListener((event) {
        if (event is tray.MenuItemClickedEvent) onClick();
      });
      return item;
    }

    final startup = _startup;
    menu.addItem(item(texts.open, tray.MenuItemType.normal, showWindow));
    if (startup != null) {
      final toggle = item(texts.startWithWindows, tray.MenuItemType.checkbox, () {});
      if (toggle != null) {
        toggle.state = startup.isEnabled ? tray.MenuItemState.checked : tray.MenuItemState.unchecked;
        toggle.addListener((event) {
          if (event is! tray.MenuItemClickedEvent) return;
          final on = startup.isEnabled ? !startup.disable() : startup.enable();
          toggle.state = on ? tray.MenuItemState.checked : tray.MenuItemState.unchecked;
        });
        menu.addItem(toggle);
      }
    }
    menu.addSeparator();
    menu.addItem(item(texts.quit, tray.MenuItemType.normal, _quit));
    _tray?.setContextMenu(menu);
    final previous = _menu;
    _menu = menu;
    previous?.dispose();
  }

  @override
  void showWindow() {
    final window = _window;
    if (window == null) return;
    if (window.isMinimized) window.restore();
    window
      ..show()
      ..focus();
  }

  void _quit() {
    _quitting = true;
    _tray?.setVisible(false);
    // Closing the only window ends the app (the runner quits on close).
    _window?.close();
  }
}
