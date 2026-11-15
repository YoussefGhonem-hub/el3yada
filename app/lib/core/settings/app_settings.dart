import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

/// Language and appearance, saved on the device (spec section 12).
/// TODO(Phase 1): also sync them to `users.locale` and `users.themeMode`.
class AppSettings {
  const AppSettings({required this.locale, required this.themeMode});

  final Locale locale;
  final ThemeMode themeMode;

  bool get isArabic => locale.languageCode == 'ar';

  AppSettings copyWith({Locale? locale, ThemeMode? themeMode}) => AppSettings(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
      );
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);

class AppSettingsController extends Notifier<AppSettings> {
  static const supportedLanguageCodes = {'ar', 'en'};
  static const _localeKey = 'settings.locale';
  static const _themeKey = 'settings.themeMode';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);
    return AppSettings(
      locale: Locale(prefs.getString(_localeKey) ?? _deviceLanguage()),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      ),
    );
  }

  /// The device language if it is Arabic or English, otherwise Arabic.
  static String _deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return supportedLanguageCodes.contains(code) ? code : 'ar';
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _prefs.setString(_localeKey, locale.languageCode);
  }

  Future<void> toggleLanguage() =>
      setLocale(Locale(state.isArabic ? 'en' : 'ar'));

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_themeKey, mode.name);
  }
}
