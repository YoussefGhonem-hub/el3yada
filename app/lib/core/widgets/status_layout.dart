import 'package:material_ui/material_ui.dart';

import 'settings_actions.dart';
import 'staggered_entrance.dart';

/// The full-screen status pages (A5, A6, A7, A10, A11, A13): an icon, a
/// title, a message, optional content, then the actions. Centred, at most
/// 480 dp wide, and enters with the staggered list entrance.
///
/// ```dart
/// StatusLayout(
///   icon: Icons.block,
///   title: l10n.accountDisabledTitle,
///   message: l10n.accountDisabledBody,
///   actions: [FilledButton(onPressed: ..., child: Text(l10n.logout))],
/// )
/// ```
class StatusLayout extends StatelessWidget {
  const StatusLayout({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.details = const [],
    this.actions = const [],
    this.tone = StatusTone.neutral,
    this.showSettings = true,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Between the message and the actions, for example the submitted data (A6)
  /// or the support contact.
  final List<Widget> details;

  /// Full-width buttons, the main one first.
  final List<Widget> actions;
  final StatusTone tone;

  /// The language and appearance switches in the top bar.
  final bool showSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = switch (tone) {
      StatusTone.neutral => (scheme.primaryContainer, scheme.onPrimaryContainer),
      StatusTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      StatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };

    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [if (showSettings) const SettingsActions(showLogout: false)],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: StaggerGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    enter(Center(
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Icon(icon, size: 40, color: foreground),
                          ),
                        ),
                      ),
                    )),
                    const SizedBox(height: 20),
                    enter(Semantics(
                      header: true,
                      child: Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                    )),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      enter(Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                      )),
                    ],
                    for (final child in details) ...[const SizedBox(height: 24), enter(child)],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      for (final (i, action) in actions.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        enter(action),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum StatusTone { neutral, warning, error }
