import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/app_settings.dart';
import '../theme/motion.dart';
import 'pressable.dart';

/// Desktop quick settings, at the top of every page: the appearance as a
/// three-way switch (light, dark, the system's) whose thumb slides to the
/// choice, and the language, together in one pill.
class DesktopQuickSettings extends ConsumerWidget {
  const DesktopQuickSettings({super.key});

  static const double height = 42;
  static const double _segment = 36;

  static const _modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final selected = _modes.indexOf(settings.themeMode);

    Widget segment(ThemeMode mode) {
      final on = mode == settings.themeMode;
      final label = switch (mode) {
        ThemeMode.light => l10n.themeLight,
        ThemeMode.dark => l10n.themeDark,
        ThemeMode.system => l10n.themeSystem,
      };
      return Tooltip(
        message: '${l10n.appearance}: $label',
        child: Pressable(
          onTap: () => controller.setThemeMode(mode),
          semanticLabel: '${l10n.appearance}: $label',
          selected: on,
          pressedScale: 0.88,
          borderRadius: BorderRadius.circular(_segment / 2),
          child: _HoverDisc(
            size: _segment,
            color: on ? null : scheme.onSurface.withValues(alpha: 0.08),
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: on ? scheme.onPrimary : scheme.onSurfaceVariant),
              duration: Motion.fast,
              builder: (context, color, _) => Icon(
                switch (mode) {
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.dark => Icons.dark_mode_rounded,
                  ThemeMode.system => Icons.brightness_auto_rounded,
                },
                size: 19,
                color: color,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerLow,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _segment * _modes.length,
            height: _segment,
            child: Stack(
              children: [
                AnimatedPositionedDirectional(
                  start: _segment * (selected < 0 ? 0 : selected),
                  top: 0,
                  width: _segment,
                  height: _segment,
                  duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
                  curve: Motion.spring,
                  child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary)),
                ),
                Row(children: [for (final mode in _modes) segment(mode)]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(height: 20, child: VerticalDivider(width: 1, color: scheme.outlineVariant)),
          ),
          Tooltip(
            message: l10n.switchLanguage,
            child: TextButton(
              onPressed: controller.toggleLanguage,
              style: TextButton.styleFrom(
                minimumSize: const Size(_segment + 6, _segment),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: scheme.onSurface,
                textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Text(settings.isArabic ? 'EN' : 'ع'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round [size] slot that tints with [color] under the mouse (null: never).
class _HoverDisc extends StatefulWidget {
  const _HoverDisc({required this.size, required this.color, required this.child});

  final double size;
  final Color? color;
  final Widget child;

  @override
  State<_HoverDisc> createState() => _HoverDiscState();
}

class _HoverDiscState extends State<_HoverDisc> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: Motion.fast,
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered && widget.color != null ? widget.color : Colors.transparent,
          ),
          child: widget.child,
        ),
      );
}

/// Language switch (ع / EN), appearance menu and log out, for app bars.
class SettingsActions extends ConsumerWidget {
  const SettingsActions({super.key, this.showLogout = true});

  final bool showLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final signedIn = ref.watch(authControllerProvider).value != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: controller.toggleLanguage,
          child: Tooltip(
            message: l10n.switchLanguage,
            child: Text(settings.isArabic ? 'EN' : 'ع'),
          ),
        ),
        PopupMenuButton<ThemeMode>(
          tooltip: l10n.appearance,
          icon: Icon(switch (settings.themeMode) {
            ThemeMode.light => Icons.light_mode_outlined,
            ThemeMode.dark => Icons.dark_mode_outlined,
            ThemeMode.system => Icons.brightness_auto_outlined,
          }),
          onSelected: controller.setThemeMode,
          itemBuilder: (context) => [
            for (final mode in ThemeMode.values)
              CheckedPopupMenuItem(
                value: mode,
                checked: mode == settings.themeMode,
                child: Text(switch (mode) {
                  ThemeMode.system => l10n.themeSystem,
                  ThemeMode.light => l10n.themeLight,
                  ThemeMode.dark => l10n.themeDark,
                }),
              ),
          ],
        ),
        if (showLogout && signedIn)
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
