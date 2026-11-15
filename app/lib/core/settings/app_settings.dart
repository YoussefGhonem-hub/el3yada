import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the real instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider in main()'),
);

/// Language and appearance, saved on the device (spec section 12). While
/// signed in, changes are also saved on the account (`AuthController`).
class AppSettings {
  const AppSettings({required this.locale, required this.themeMode, this.languageChosen = true});

  final Locale locale;
  final ThemeMode themeMode;

  /// False until the user picks a language on A2 (first launch).
  final bool languageChosen;

  bool get isArabic => locale.languageCode == 'ar';

  AppSettings copyWith({Locale? locale, ThemeMode? themeMode, bool? languageChosen}) => AppSettings(
        locale: locale ?? this.locale,
        themeMode: themeMode ?? this.themeMode,
        languageChosen: languageChosen ?? this.languageChosen,
      );
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(AppSettingsController.new);

class AppSettingsController extends Notifier<AppSettings> {
  static const supportedLanguageCodes = {'ar', 'en'};
  static const _localeKey = 'settings.locale';
  static const _themeKey = 'settings.themeMode';
  static const _languageChosenKey = 'settings.languageChosen';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedTheme = prefs.getString(_themeKey);
    final savedLocale = prefs.getString(_localeKey);
    return AppSettings(
      locale: Locale(savedLocale ?? _deviceLanguage()),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => ThemeMode.system,
      ),
      // Installs from before A2 already saved a language: don't ask again.
      languageChosen: (prefs.getBool(_languageChosenKey) ?? false) || savedLocale != null,
    );
  }

  /// A2: shows the app in [locale] without saving it yet.
  void setLocaleForPreview(Locale locale) => state = state.copyWith(locale: locale);

  /// A2: the first-launch choice.
  Future<void> chooseLanguage(Locale locale) async {
    state = state.copyWith(locale: locale, languageChosen: true);
    await _prefs.setString(_localeKey, locale.languageCode);
    await _prefs.setBool(_languageChosenKey, true);
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
