import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/app_settings.dart';

/// Language switch (ع / EN), appearance menu and log out, for app bars.
class SettingsActions extends ConsumerWidget {
  const SettingsActions({super.key, this.showLogout = true});

  final bool showLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final signedIn = ref.watch(authControllerProvider).value != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: controller.toggleLanguage,
          child: Tooltip(
            message: l10n.switchLanguage,
            child: Text(settings.isArabic ? 'EN' : 'ع'),
          ),
        ),
        PopupMenuButton<ThemeMode>(
          tooltip: l10n.appearance,
          icon: Icon(switch (settings.themeMode) {
            ThemeMode.light => Icons.light_mode_outlined,
            ThemeMode.dark => Icons.dark_mode_outlined,
            ThemeMode.system => Icons.brightness_auto_outlined,
          }),
          onSelected: controller.setThemeMode,
          itemBuilder: (context) => [
            for (final mode in ThemeMode.values)
              CheckedPopupMenuItem(
                value: mode,
                checked: mode == settings.themeMode,
                child: Text(switch (mode) {
                  ThemeMode.system => l10n.themeSystem,
                  ThemeMode.light => l10n.themeLight,
                  ThemeMode.dark => l10n.themeDark,
                }),
              ),
          ],
        ),
        if (showLogout && signedIn)
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
