import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../admin/presentation/widgets/admin_widgets.dart';
import '../../../../core/widgets/navigation/app_back_button.dart';

export '../../../../core/widgets/motion_size.dart';
export '../../../admin/presentation/widgets/admin_widgets.dart'
    show
        AdminErrorView,
        AdminHeader,
        InfoRow,
        InitialAvatar,
        PillTone,
        ResponsiveGrid,
        SectionCard,
        StatusPill,
        adminGutter,
        confirmAction,
        kAdminWideLayout,
        showAdminSnack;

/// Shared parts of the clinic's own admin screens (D22–D29, D37, AS12,
/// AS19): the back button, grouped settings rows, the queue-ticket card,
/// the "2 of 5" meter and the money field. The card, header, pill and
/// error view come from the admin screens, so both areas look the same.

/// Back for detail screens inside a tab. Unlike a plain pop it asks the
/// screen first (`PopScope`), so unsaved changes are guarded; opened from a
/// link, it goes to [fallback].
class ClinicBackButton extends StatelessWidget {
  const ClinicBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) =>
      ShellBackScope.handlesBack(context) ? const SizedBox.shrink() : AppBackButton(fallback: fallback);
}

/// Asks before throwing away [count] unsaved changes. True to discard.
Future<bool> confirmDiscardChanges(BuildContext context, int count) {
  final l10n = AppLocalizations.of(context);
  return confirmAction(
    context,
    title: l10n.adminDiscardTitle,
    message: l10n.adminDiscardBody(count),
    confirmLabel: l10n.adminDiscard,
    destructive: true,
  );
}

/// A group of settings rows under a short heading: one white card on the
/// mint ground, rows divided by hairlines (the "grouped list rows" of the
/// queue-ticket design).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children, this.footer});

  final String? title;
  final List<Widget> children;

  /// A note under the card.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
            child: Semantics(
              header: true,
              child: Text(title!, style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
            ),
          ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 68),
                child,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 0),
            child: Text(footer!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}

/// The round icon at the start of a settings row.
class RowIcon extends StatelessWidget {
  const RowIcon(this.icon, {super.key, this.destructive = false, this.muted = false});

  final IconData icon;
  final bool destructive;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = destructive
        ? (scheme.errorContainer, scheme.onErrorContainer)
        : muted
            ? (scheme.surfaceContainerHigh, scheme.onSurfaceVariant)
            : (scheme.primaryContainer, scheme.onPrimaryContainer);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20, color: foreground)),
      ),
    );
  }
}

/// One settings row: icon, title, an optional line under it, and a chevron
/// (or [trailing]). With [onTap] the whole row is the tap target, at least
/// 56 dp high.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.below,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// A control under the title (segmented buttons), full width.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chevron = onTap == null || trailing != null || destructive
        ? null
        : Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
            color: scheme.onSurfaceVariant);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                RowIcon(icon, destructive: destructive),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: destructive ? scheme.error : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                ?chevron,
              ],
            ),
            if (below != null) Padding(padding: const EdgeInsetsDirectional.only(start: 52, top: 10), child: below),
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: row);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, child: Semantics(button: true, child: row)),
    );
  }
}

/// A settings row with a switch: tapping the row flips it.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: SettingsTile(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          trailing: Switch(value: value, onChanged: onChanged),
        ),
      );
}

/// The queue-ticket card (the chosen design's signature): a top part, a
/// perforated tear line with a notch on each side, and a stub. [tone]
/// pine for the one hero ticket on a screen, plain white elsewhere.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.child, this.stub, this.pine = false, this.onTap, this.semanticLabel});

  final Widget child;
  final Widget? stub;
  final bool pine;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = pine ? scheme.primary : scheme.surfaceContainerLow;
    final foreground = pine ? scheme.onPrimary : scheme.onSurface;
    final card = Material(
      color: background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      clipBehavior: Clip.antiAlias,
      child: IconTheme.merge(
        data: IconThemeData(color: foreground),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foreground),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              if (stub != null) ...[
                TicketPerforation(lineColor: pine ? scheme.onPrimary.withValues(alpha: 0.45) : scheme.outlineVariant),
                stub!,
              ],
            ],
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      child: card,
    );
  }
}

/// The tear line of a [TicketCard]: a dashed line between two half-circle
/// notches in the page colour.
class TicketPerforation extends StatelessWidget {
  const TicketPerforation({super.key, required this.lineColor, this.notchColor});

  final Color lineColor;

  /// The page behind the card; defaults to the theme's surface.
  final Color? notchColor;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: 20,
          width: double.infinity,
          child: CustomPaint(
            painter: _PerforationPainter(line: lineColor, notch: notchColor ?? Theme.of(context).colorScheme.surface),
          ),
        ),
      );
}

class _PerforationPainter extends CustomPainter {
  _PerforationPainter({required this.line, required this.notch});

  final Color line;
  final Color notch;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 10.0;
    final y = size.height / 2;
    final notchPaint = Paint()..color = notch;
    canvas
      ..drawCircle(Offset(0, y), radius, notchPaint)
      ..drawCircle(Offset(size.width, y), radius, notchPaint);
    final dash = Paint()
      ..color = line
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashLength = 6.0;
    const gap = 5.0;
    var x = radius + 6;
    while (x + dashLength < size.width - radius - 6) {
      canvas.drawLine(Offset(x, y), Offset(x + dashLength, y), dash);
      x += dashLength + gap;
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter oldDelegate) => oldDelegate.line != line || oldDelegate.notch != notch;
}

/// "2 of 5" with a dot per place, filled for the used ones (BR-AS1, BR-BR1).
class CapacityMeter extends StatelessWidget {
  const CapacityMeter({super.key, required this.count, required this.limit, required this.label});

  final int count;
  final int limit;

  /// The text, for example «2 من 5 مساعدين».
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final full = count >= limit;
    final reduced = Motion.of(context).reduced;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < limit.clamp(0, 12); i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: AnimatedContainer(
                duration: reduced ? Duration.zero : Motion.normal,
                curve: Motion.standardCurve,
                width: i < count ? 18 : 10,
                height: 10,
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: i < count ? (full ? scheme.tertiary : scheme.primary) : scheme.outlineVariant,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}

/// A tinted note: what a change will do, or why something is unavailable.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.icon = Icons.info_outline, this.tone = PillTone.positive, this.action});

  final String message;
  final IconData icon;
  final PillTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground) = switch (tone) {
      PillTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      PillTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
      PillTone.neutral => (scheme.surfaceContainerHigh, scheme.onSurface),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 20, color: foreground)),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: foreground))),
              if (action != null) ...[const SizedBox(width: 8), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// An amount in EGP (spec section 11: up to 2 decimals). Digits read on
/// their own; «ج.م» sits at the end.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.errorText,
    this.helperText,
    this.hintText,
    this.onChanged,
    this.fieldKey,
  });

  /// Digits (Western or Arabic-Indic) and one decimal separator.
  static final _characters = FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.٫,]'));

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_characters],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: l10n.regCurrency,
        helperText: helperText,
        helperMaxLines: 3,
        errorText: errorText,
        errorMaxLines: 3,
      ),
    );
  }
}

/// A page of stacked sections: gutter by width, at most [maxWidth] wide,
/// room for the phone's floating bar at the end, and the stagger.
class ClinicPage extends StatelessWidget {
  const ClinicPage({super.key, required this.builder, this.maxWidth = 1040, this.controller, this.bottomBarVisible = false});

  final List<Widget> Function(BuildContext context, double width) builder;
  final double maxWidth;
  final ScrollController? controller;

  /// A save bar under the page already keeps clear of the floating bar.
  final bool bottomBarVisible;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final gutter = adminGutter(width);
          final bottom = 24 + (bottomBarVisible ? 0.0 : MediaQuery.paddingOf(context).bottom);
          var index = 0;
          return StaggerGroup(
            child: SingleChildScrollView(
              controller: controller,
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, bottom),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final child in builder(context, (width - 2 * gutter).clamp(0.0, maxWidth)))
                        child is SizedBox ? child : StaggeredEntrance(index: index++, child: child),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
}
