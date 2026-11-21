import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/pressable.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/application/auth_controller.dart';
import '../clinic/application/clinic_providers.dart';
import 'role_shells.dart';

/// Stands in for a screen until it is built. Shows the screen ID from spec.md.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.destination});

  final NavDestinationSpec destination;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final parts = [
      Icon(destination.icon, size: 48, color: theme.colorScheme.primary),
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          destination.label(l10n),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ),
      Text(l10n.underConstructionTitle, textAlign: TextAlign.center),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          l10n.underConstructionBody(destination.screenId),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ),
    ];
    // SafeArea keeps the text clear of the floating bottom bar.
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < parts.length; i++) StaggeredEntrance(index: i, child: parts[i]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "More" on phones and tablets: the items that aren't in the bottom bar
/// (only those the user may see), as a grid of tiles that rise in one after
/// another.
class MorePage extends ConsumerWidget {
  const MorePage({super.key, required this.shell});

  final RoleShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(authControllerProvider).value;
    final clinic = ref.watch(clinicContextProvider).value;
    final items = shell.secondary.where((d) => d.isVisibleTo(session, clinic: clinic)).toList();
    return StaggerGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final columns = width < 520 ? 2 : (width < 840 ? 3 : 4);
          const gutter = 16.0;
          const spacing = 10.0;
          final tile = (width - 2 * gutter - spacing * (columns - 1)) / columns;
          return ListView(
            // The bottom padding includes the floating bar on phones.
            padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              StaggeredEntrance(
                index: 0,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, bottom: 16),
                  child: Semantics(header: true, child: Text(l10n.navMore, style: theme.textTheme.titleLarge)),
                ),
              ),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final (i, item) in items.indexed)
                    SizedBox(
                      width: tile,
                      child: StaggeredEntrance(
                        index: i + 1,
                        child: _MoreTile(
                          icon: item.icon,
                          label: item.label(l10n),
                          onTap: () => context.go(item.path),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One item under More: its icon on a tinted tile over its name.
class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 60,
        padding: const EdgeInsetsDirectional.only(start: 10, end: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
            ),
          ],
        ),
      ),
    );
  }
}
