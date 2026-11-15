import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import 'role_shells.dart';

/// Stands in for a screen until it is built. Shows the screen ID from spec.md.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.destination});

  final NavDestinationSpec destination;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                destination.label(l10n),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(l10n.underConstructionTitle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                l10n.underConstructionBody(destination.screenId),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "More" on phones and tablets: the items that aren't in the bottom bar.
class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.shell});

  final RoleShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final d in shell.secondary)
          ListTile(
            leading: Icon(d.icon),
            title: Text(d.label(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(d.path),
          ),
      ],
    );
  }
}
