import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/admin_models.dart';

/// Content wider than this gets the desktop layout inside admin screens
/// (tables, master-detail, two columns). It is measured on the content
/// area, so a tablet in landscape gets it too.
const double kAdminWideLayout = 840;

/// Side padding of admin screens: 16 on phones, more on wide windows.
double adminGutter(double width) => width >= kAdminWideLayout ? 32 : 16;

/// The title row of an admin screen: title, a line under it, and actions at
/// the end (they wrap under the title on narrow screens).
class AdminHeader extends StatelessWidget {
  const AdminHeader({super.key, required this.title, this.subtitle, this.actions = const [], this.leading});

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// A back button for detail screens.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;
        // On phones, icon buttons stay next to the title; the others go in
        // one row under it, which scrolls sideways if it doesn't fit.
        final inline = narrow ? actions.whereType<IconButton>().toList() : actions;
        final below = narrow ? actions.where((a) => a is! IconButton).toList() : const <Widget>[];
        final head = Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 4)],
            Expanded(child: titleBlock),
            for (final action in inline) ...[const SizedBox(width: 8), action],
          ],
        );
        if (below.isEmpty) return head;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            head,
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [for (final (i, action) in below.indexed) ...[if (i > 0) const SizedBox(width: 8), action]]),
            ),
          ],
        );
      },
    );
  }
}

/// Back for detail screens inside a tab (the tab's top bar has no back
/// button): pops, or goes to [fallback] when opened from a link.
class AdminBackButton extends StatelessWidget {
  const AdminBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) => BackButton(
        onPressed: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            context.go(fallback);
          }
        },
      );
}

/// A white card (radius 20) with a title row and content: one section of a
/// detail or settings screen.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// A label over its value (read-only data in AD3, AD18).
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, this.value, this.child, this.ltr = false});

  final String label;
  final String? value;

  /// Instead of [value], for values with chips or buttons.
  final Widget? child;

  /// Phone numbers, emails, IDs and amounts read left to right.
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final missing = value == null && child == null;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          child ??
              Text(
                missing ? l10n.adminNotProvided : value!,
                textDirection: ltr && !missing ? TextDirection.ltr : null,
                style: missing
                    ? theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic)
                    : theme.textTheme.bodyLarge,
              ),
        ],
      ),
    );
  }
}

/// Lays [children] out in [columns] columns when there is room (at least
/// [minColumnWidth] each), otherwise in one.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.minColumnWidth = 240,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  final List<Widget> children;
  final int columns;
  final double minColumnWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          var count = columns;
          while (count > 1 && (constraints.maxWidth - spacing * (count - 1)) / count < minColumnWidth) {
            count--;
          }
          final width = (constraints.maxWidth - spacing * (count - 1)) / count;
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: [for (final child in children) SizedBox(width: count == 1 ? constraints.maxWidth : width, child: child)],
          );
        },
      );
}

/// How a [StatusPill] is coloured.
enum PillTone { neutral, positive, warning, danger, accent }

/// A small rounded label: statuses and roles. Always text, never colour alone.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.el3yadaColors;
    final (background, foreground) = switch (tone) {
      PillTone.neutral => (scheme.surfaceContainerHigh, scheme.onSurface),
      PillTone.positive => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PillTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      PillTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
      PillTone.accent => (colors.attention, colors.onAttention),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: background, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(child: Icon(icon, size: 14, color: foreground)),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coral "new" mark on fresh sign-up requests.
class NewMark extends StatelessWidget {
  const NewMark({super.key});

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: AppLocalizations.of(context).adminNew, tone: PillTone.accent);
}

/// A round initial for a person: the first letter of the name, skipping
/// titles such as «د.».
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 44, this.muted = false});

  final String name;
  final double size;
  final bool muted;

  static String initialOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !w.endsWith('.')).toList();
    if (words.isEmpty) return '؟';
    return String.fromCharCode(words.first.runes.first);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: muted ? scheme.surfaceContainerHigh : scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Text(
          initialOf(name),
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w600,
            color: muted ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// A failed load: what happened and Try again. Announced to screen readers.
class AdminErrorView extends StatelessWidget {
  const AdminErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;

  /// One row, for the end of a list (a failed next page).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final message = l10n.apiError(error);
    if (compact) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
              if (onRetry != null) TextButton(onPressed: onRetry, child: Text(l10n.retryButton)),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: scheme.errorContainer, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Icon(Icons.cloud_off_outlined, size: 32, color: scheme.onErrorContainer),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retryButton)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks before an action. Returns true when the user confirms.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(message)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.adminCancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A short message at the bottom of the screen (above the phone's bar).
void showAdminSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final scheme = Theme.of(context).colorScheme;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? scheme.error : null,
    ));
}

/// The role's name: «مسؤول رئيسي» / «مسؤول».
String adminRoleLabel(AppLocalizations l10n, AdminRole role) =>
    role == AdminRole.superAdmin ? l10n.adminRoleSuperAdmin : l10n.adminRoleAdmin;

/// Grows and shrinks with its child; instant with reduced motion.
class AdminAnimatedSize extends StatelessWidget {
  const AdminAnimatedSize({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
        curve: Motion.standardCurve,
        alignment: AlignmentDirectional.topStart,
        child: child,
      );
}
