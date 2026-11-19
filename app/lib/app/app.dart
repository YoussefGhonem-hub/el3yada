import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

<<<<<<< HEAD
import '../core/platform/app_platform.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../features/catalog/presentation/catalog_setup_host.dart';
=======
import '../core/notifications/local_notifier.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../features/notifications/notifications.dart';
>>>>>>> phase-6/appointments-live-board
import '../l10n/gen/app_localizations.dart';
import 'router.dart';

class El3yadaApp extends ConsumerStatefulWidget {
  const El3yadaApp({super.key});

  @override
  ConsumerState<El3yadaApp> createState() => _El3yadaAppState();
}

class _El3yadaAppState extends ConsumerState<El3yadaApp> {
  @override
  void initState() {
    super.initState();
    // Toasts (Windows) and foreground banners; tapping one opens its screen.
    ref.read(localNotifierProvider).init(onTap: (route) {
      if (route != null) ref.read(routerProvider).push(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
<<<<<<< HEAD
    // The one place that picks the themes: desktop platforms get the larger
    // type and the graphite dark mode, phones keep theirs.
    final desktop = ref.watch(appPlatformProvider).isDesktop;
=======
    // Device registration, and live notifications turned into toasts (Phase 5).
    ref.watch(notificationSetupProvider);
>>>>>>> phase-6/appointments-live-board
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
      // Keeps the medical catalog current and opens D0 when it's needed.
      builder: (context, child) => CatalogSetupHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
