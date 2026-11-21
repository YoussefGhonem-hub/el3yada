import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Desktop: the rounded canvas every page sits on, over the app background, as in Microsoft Teams. Nothing on a page
/// floats on the background: lists, forms and boards are all inside it. Pages that paint their own background (a
/// `Scaffold`, an `AppBar`) get the canvas colour, so the canvas reads as one card.
class DesktopCanvas extends StatelessWidget {
  const DesktopCanvas({super.key, required this.child});

  final Widget child;

  static const double radius = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canvas = AppTheme.desktopCanvas(scheme);
    return Padding(
      // The side menu is at the start; the canvas keeps a gutter at the end and the bottom.
      padding: const EdgeInsetsDirectional.only(end: 12, bottom: 12),
      // A Material, not a coloured box: list tiles paint their hover and selection on the nearest Material, so a
      // coloured box between them and the page would hide those.
      child: Material(
        color: canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(
            scaffoldBackgroundColor: canvas,
            canvasColor: canvas,
            appBarTheme: theme.appBarTheme.copyWith(backgroundColor: canvas),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A panel that groups content on the canvas: a board column, a toolbar of counters, a filters bar. On phones and
/// tablets it is the same soft surface, one step off the page background.
class DesktopPanel extends StatelessWidget {
  const DesktopPanel({super.key, required this.child, this.padding = const EdgeInsets.all(8), this.margin, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// Overrides the panel colour, for example while a dragged card hovers over a column.
  final Color? color;

  static const double radius = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.desktopPanel(scheme),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}
