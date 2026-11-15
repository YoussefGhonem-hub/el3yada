import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
/// (only those the user may see).
class MorePage extends ConsumerWidget {
  const MorePage({super.key, required this.shell});

  final RoleShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).value;
    final clinic = ref.watch(clinicContextProvider).value;
    final items = shell.secondary.where((d) => d.isVisibleTo(session, clinic: clinic)).toList();
    return StaggerGroup(
      child: ListView.builder(
        // The bottom padding includes the floating bar on phones.
        padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.paddingOf(context).bottom),
        itemCount: items.length,
        itemBuilder: (context, i) => StaggeredEntrance(
          index: i,
          child: ListTile(
            leading: Icon(items[i].icon),
            title: Text(items[i].label(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(items[i].path),
          ),
        ),
      ),
    );
  }
}
