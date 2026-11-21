import 'package:animations/animations.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/motion.dart';

/// List → detail: the tapped card grows into the detail screen (spec: "a
/// patient card grows into the profile D6, an appointment into P17").
/// A themed `OpenContainer` from the `animations` package; with reduced
/// motion the detail simply fades in.
///
/// ```dart
/// ContainerTransform<void>(
///   closedBuilder: (context, open) => PatientCard(patient, onTap: open),
///   openBuilder: (context, close) => PatientProfileScreen(patient.id),
/// )
/// ```
///
/// The detail is pushed on the nearest `Navigator` without changing the URL.
/// Detail screens that need a deep link also get a `GoRoute`; this helper is
/// for the in-app tap.
class ContainerTransform<T> extends StatelessWidget {
  const ContainerTransform({
    super.key,
    required this.closedBuilder,
    required this.openBuilder,
    this.onClosed,
    this.closedShape = const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    this.closedColor,
    this.tappable = true,
  });

  /// The card in the list. Call `open` to open it (or leave [tappable] on).
  final CloseContainerBuilder closedBuilder;

  /// The detail screen. Call `close` to go back (the back button also works).
  final OpenContainerBuilder<T> openBuilder;

  /// Called with the detail's result after it closes.
  final ClosedCallback<T?>? onClosed;

  /// Matches the card shape (cards are 20 dp rounded in `AppTheme`).
  final ShapeBorder closedShape;

  /// Defaults to the card colour.
  final Color? closedColor;

  /// Whether a tap anywhere on the closed card opens it (with a ripple).
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor = closedColor ?? scheme.surfaceContainerLow;

    if (Motion.of(context).reduced) {
      Future<void> open() async {
        final result = await Navigator.of(context).push<T>(
          PageRouteBuilder<T>(
            transitionDuration: Motion.fast,
            reverseTransitionDuration: Motion.fastExit,
            pageBuilder: (context, _, _) => openBuilder(
              context,
              ({T? returnValue}) => Navigator.of(context).pop(returnValue),
            ),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
        onClosed?.call(result);
      }

      final closed = closedBuilder(context, open);
      return tappable
          ? Material(
              color: cardColor,
              shape: closedShape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: open, child: closed),
            )
          : closed;
    }

    return OpenContainer<T>(
      transitionDuration: Motion.slow,
      transitionType: ContainerTransitionType.fadeThrough,
      closedColor: cardColor,
      openColor: scheme.surface,
      middleColor: scheme.surface,
      closedElevation: 0,
      openElevation: 0,
      closedShape: closedShape,
      tappable: tappable,
      onClosed: onClosed,
      closedBuilder: closedBuilder,
      openBuilder: openBuilder,
    );
  }
}
