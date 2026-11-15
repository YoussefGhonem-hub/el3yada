import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../settings/app_settings.dart';

/// العربية / English, saved on the device and on the account (AD18, D24,
/// AS12). The layout flips at once.
class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appSettingsProvider.select((s) => s.locale));
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(value: 'ar', label: Text(l10n.languageArabic)),
        ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
      ],
      selected: {locale.languageCode},
      onSelectionChanged: (selection) => ref.read(appSettingsProvider.notifier).setLocale(Locale(selection.first)),
    );
  }
}

/// Light / Dark / System (spec section 12, Appearance).
class AppearancePicker extends ConsumerWidget {
  const AppearancePicker({super.key, this.showIcons = true});

  /// Narrow rows drop the icons so the three labels fit.
  final bool showIcons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));
    ButtonSegment<ThemeMode> segment(ThemeMode value, String label, IconData icon) =>
        ButtonSegment(value: value, label: Text(label), icon: showIcons ? Icon(icon) : null);
    return SegmentedButton<ThemeMode>(
      showSelectedIcon: showIcons,
      segments: [
        segment(ThemeMode.light, l10n.themeLight, Icons.light_mode_outlined),
        segment(ThemeMode.dark, l10n.themeDark, Icons.dark_mode_outlined),
        segment(ThemeMode.system, l10n.themeSystem, Icons.brightness_auto_outlined),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => ref.read(appSettingsProvider.notifier).setThemeMode(selection.first),
    );
  }
}
