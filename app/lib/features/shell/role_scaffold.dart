import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/settings_actions.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/application/auth_controller.dart';
import 'role_shells.dart';

/// Adaptive frame around every signed-in screen (spec section 4):
/// - phone (< 600): bottom bar with the primary items + More
/// - tablet (600–1024): navigation rail with the same items
/// - desktop (≥ 1024): side menu with every item
class RoleScaffold extends ConsumerWidget {
  const RoleScaffold({
    super.key,
    required this.shell,
    required this.location,
    required this.child,
  });

  final RoleShell shell;
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final displayName = ref.watch(authControllerProvider).value?.displayName ?? '';
    final actions = [
      if (shell.accountPath != null)
        IconButton(
          tooltip: l10n.navAccount,
          icon: CircleAvatar(radius: 16, child: Icon(Icons.person_outline, size: 18, semanticLabel: l10n.navAccount)),
          onPressed: () => context.go(shell.accountPath!),
        ),
      const SettingsActions(),
    ];
    final title = '${l10n.appTitle} · ${shell.role.label(l10n)}';

    if (width >= Breakpoints.desktop) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: Row(
          children: [
            SizedBox(
              width: 256,
              child: _SideMenu(shell: shell, location: location, displayName: displayName),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    final items = shell.primary;
    final hasMore = shell.secondary.isNotEmpty;
    var index = items.indexWhere((d) => location.startsWith(d.path));
    if (index < 0) index = hasMore ? items.length : 0;

    void onSelected(int i) => context.go(i < items.length ? items[i].path : shell.morePath);

    if (width < Breakpoints.tablet) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onSelected,
          destinations: [
            for (final d in items) NavigationDestination(icon: Icon(d.icon), label: d.label(l10n)),
            if (hasMore) NavigationDestination(icon: const Icon(Icons.more_horiz), label: l10n.navMore),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: onSelected,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in items)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label(l10n))),
              if (hasMore)
                NavigationRailDestination(icon: const Icon(Icons.more_horiz), label: Text(l10n.navMore)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.shell, required this.location, required this.displayName});

  final RoleShell shell;
  final String location;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        children: [
          if (displayName.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, bottom: 12),
              child: Text(displayName, style: Theme.of(context).textTheme.titleSmall),
            ),
          for (final d in shell.destinations)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                leading: Icon(d.icon),
                title: Text(d.label(l10n)),
                selected: location.startsWith(d.path),
                selectedTileColor: scheme.secondaryContainer,
                selectedColor: scheme.onSecondaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => context.go(d.path),
              ),
            ),
        ],
      ),
    );
  }
}
