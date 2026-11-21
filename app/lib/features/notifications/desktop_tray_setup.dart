import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/local_notifier.dart';
import '../../core/platform/desktop_tray.dart';
import '../../core/settings/app_settings.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/application/auth_controller.dart';
import 'notifications.dart';

/// The tray's texts in [l10n], with [unread] notifications.
TrayTexts trayTextsOf(AppLocalizations l10n, int unread) => TrayTexts(
      open: l10n.trayOpen(l10n.appTitle),
      startWithWindows: l10n.trayStartWithWindows,
      quit: l10n.trayQuit,
      tooltip: unread > 0 ? l10n.trayTooltipUnread(l10n.appTitle, unread) : l10n.appTitle,
    );

/// The signed-in user's unread notifications for the tray; 0 when signed out
/// (no request then).
final trayUnreadProvider = Provider.autoDispose<int>((ref) {
  final signedIn = ref.watch(authControllerProvider.select((auth) => auth.value != null));
  return signedIn ? ref.watch(unreadNotificationsProvider).value ?? 0 : 0;
});

/// Starts the Windows tray once (spec 10.2 [S]) and keeps it current: the
/// labels follow the app's language, the icon and tooltip the unread count.
/// The first time the window goes to the tray, a toast says the app still
/// runs there. Created once in `El3yadaApp`; does nothing where there is no
/// tray.
final desktopTraySetupProvider = Provider<void>((ref) {
  final trayIcon = ref.read(desktopTrayProvider);
  AppLocalizations l10n() => lookupAppLocalizations(ref.read(appSettingsProvider).locale);

  final started = trayIcon.start(
    trayTextsOf(l10n(), 0),
    onFirstHide: () {
      final texts = l10n();
      ref.read(localNotifierProvider).show(
            id: 'tray-hidden'.hashCode,
            title: texts.trayStillRunningTitle(texts.appTitle),
            body: texts.trayStillRunningBody,
          );
    },
  );
  if (!started) return;

  var unread = 0;
  void refresh() => trayIcon.update(trayTextsOf(l10n(), unread), unread: unread);
  ref.listen(appSettingsProvider.select((settings) => settings.locale), (_, _) => refresh());
  ref.listen(trayUnreadProvider, (_, next) {
    unread = next;
    refresh();
  }, fireImmediately: true);
});
