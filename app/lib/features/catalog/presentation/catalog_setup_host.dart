import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/settings/app_settings.dart';
import '../../shell/role_shells.dart';
import '../application/catalog_providers.dart';

/// Keeps the catalog, the custom items and the specialty profile running
/// while the app is open (they start when an eligible user signs in), and
/// opens D0 over the role's area:
///
/// * the first time a catalog is downloaded on this device (or the first
///   download failed), once per app run;
/// * when a new version is at least [largeUpdateBytes], once per version.
///
/// Smaller updates download silently.
class CatalogSetupHost extends ConsumerStatefulWidget {
  const CatalogSetupHost({super.key, required this.child});

  final Widget child;

  /// A new version this big shows D0 (spec: "when a new version is large").
  static const largeUpdateBytes = 15 * 1024 * 1024;

  static const _announcedKey = 'catalog.announcedVersion';

  @override
  ConsumerState<CatalogSetupHost> createState() => _CatalogSetupHostState();
}

class _CatalogSetupHostState extends ConsumerState<CatalogSetupHost> {
  bool _shownFirstRun = false;
  bool _pending = false;

  void _onCatalog(CatalogState? previous, CatalogState next) {
    if (_pending || !ref.read(catalogEligibleProvider)) return;
    final firstDownload =
        next.installed == null &&
        (next.phase == CatalogPhase.downloading || next.phase == CatalogPhase.failed) &&
        !_shownFirstRun;
    final target = next.target;
    final prefs = ref.read(sharedPreferencesProvider);
    final largeUpdate =
        next.installed != null &&
        next.phase == CatalogPhase.downloading &&
        target != null &&
        target.sizeBytes >= CatalogSetupHost.largeUpdateBytes &&
        prefs.getInt(CatalogSetupHost._announcedKey) != target.version;
    if (!firstDownload && !largeUpdate) return;

    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) return;
      final router = ref.read(routerProvider);
      final location = router.routerDelegate.currentConfiguration.uri.path;
      // Only over the role's area: never over sign-in, A9, A15 or itself.
      final inShell = RoleShell.all.any((shell) => location.startsWith('${shell.basePath}/'));
      if (!inShell) return;
      if (firstDownload) _shownFirstRun = true;
      if (largeUpdate) prefs.setInt(CatalogSetupHost._announcedKey, target.version);
      router.push(AppRoutes.catalogSetup);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CatalogState>(catalogControllerProvider, _onCatalog);
    ref.listen(customItemsProvider, (_, _) {});
    ref.listen(myCatalogProfileProvider, (_, _) {});
    return widget.child;
  }
}
