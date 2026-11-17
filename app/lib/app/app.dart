import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/app_platform.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../l10n/gen/app_localizations.dart';
import 'router.dart';

class El3yadaApp extends ConsumerWidget {
  const El3yadaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    // The one place that picks the themes: desktop platforms get the larger
    // type and the graphite dark mode, phones keep theirs.
    final desktop = ref.watch(appPlatformProvider).isDesktop;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: ref.watch(routerProvider),
      // Arabic switches the whole layout to right-to-left automatically.
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: desktop ? AppTheme.desktopLight() : AppTheme.light(),
      darkTheme: desktop ? AppTheme.desktopDark() : AppTheme.dark(),
      themeMode: settings.themeMode,
    );
  }
}
