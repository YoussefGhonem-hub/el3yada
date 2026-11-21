import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/admin_controllers.dart';
import '../../data/license_opener.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';

/// AD3 license: an image shows inline (tap or "Zoom" for the full-screen
/// viewer); a PDF is a file card that opens in the system viewer. The file
/// streams through the API and is never cached on disk, except the
/// temporary copy a PDF needs to open.
class LicenseCard extends ConsumerWidget {
  const LicenseCard({super.key, required this.doctorId, required this.doctorName, this.previewHeight = 260});

  final String doctorId;
  final String doctorName;
  final double previewHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final file = ref.watch(licenseFileProvider(doctorId));
    return SectionCard(
      icon: Icons.badge_outlined,
      title: l10n.adminLicenseTitle,
      subtitle: l10n.adminLicenseSubtitle,
      child: AnimatedSwitcher(
        duration: Motion.normal,
        reverseDuration: Motion.normalExit,
        switchInCurve: Motion.enterCurve,
        switchOutCurve: Motion.exitCurveReversed,
        child: switch (file) {
          AsyncData(:final value) when value.isImage => _ImagePreview(
            key: const ValueKey('image'),
            file: value,
            height: previewHeight,
            onOpen: () => openLicenseViewer(context, value, doctorName),
          ),
          AsyncData(:final value) => _FileTile(key: const ValueKey('file'), file: value, doctorName: doctorName),
          AsyncError(:final error) => _LicenseError(
            key: const ValueKey('error'),
            error: error,
            onRetry: () => ref.invalidate(licenseFileProvider(doctorId)),
          ),
          _ => SkeletonLoading(
            key: const ValueKey('loading'),
            loading: true,
            child: Container(height: previewHeight, color: Theme.of(context).colorScheme.surfaceContainerHigh),
          ),
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({super.key, required this.file, required this.height, required this.onOpen});

  final LicenseFile file;
  final double height;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          image: true,
          label: l10n.adminLicenseImageLabel,
          onTap: onOpen,
          excludeSemantics: true,
          child: Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: SizedBox(
                height: height,
                child: Image.memory(file.bytes, fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: const Icon(Icons.zoom_in),
            label: Text(l10n.adminLicenseZoom),
          ),
        ),
      ],
    );
  }
}

class _FileTile extends ConsumerStatefulWidget {
  const _FileTile({super.key, required this.file, required this.doctorName});

  final LicenseFile file;
  final String doctorName;

  @override
  ConsumerState<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends ConsumerState<_FileTile> {
  bool _opening = false;

  Future<void> _open() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _opening = true);
    var opened = false;
    try {
      opened = await ref
          .read(licenseOpenerProvider)
          .open(widget.file, name: '${l10n.adminLicenseFileName} ${widget.doctorName}');
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (!opened) showAdminSnack(context, l10n.adminLicenseCantOpen, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kb = (widget.file.bytes.length / 1024).ceil();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    widget.file.isPdf ? 'PDF' : l10n.adminLicenseFile,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.file.isPdf ? l10n.adminLicensePdf : l10n.adminLicenseFile,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.adminFileSizeKb(kb),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          FilledButton.tonalIcon(
            onPressed: _opening ? null : _open,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.adminLicenseOpen),
          ),
        ],
      ),
    );
  }
}

class _LicenseError extends StatelessWidget {
  const _LicenseError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final missing = error is ApiException && (error as ApiException).code == 'LICENSE_FILE_MISSING';
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: scheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l10n.apiError(error), style: TextStyle(color: scheme.onTertiaryContainer)),
              ),
              if (!missing) TextButton(onPressed: onRetry, child: Text(l10n.retryButton)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full-screen license viewer: black background in both themes (spec
/// section 12), pinch, scroll-wheel and double-tap zoom, and buttons for
/// keyboard and mouse users. Escape closes it. It covers the whole window
/// (the root navigator), not just the tab.
Future<void> openLicenseViewer(BuildContext context, LicenseFile file, String doctorName) =>
    Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: Motion.normal,
    reverseTransitionDuration: Motion.normalExit,
    pageBuilder: (context, _, _) => LicenseViewer(file: file, title: doctorName),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Motion.enterCurve, reverseCurve: Motion.exitCurveReversed),
      child: child,
    ),
  ),
);

class LicenseViewer extends StatefulWidget {
  const LicenseViewer({super.key, required this.file, required this.title});

  final LicenseFile file;
  final String title;

  @override
  State<LicenseViewer> createState() => _LicenseViewerState();
}

class _LicenseViewerState extends State<LicenseViewer> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _zoom = AnimationController(vsync: this, duration: Motion.normal);
  Animation<Matrix4>? _zoomAnimation;
  Offset _doubleTapAt = Offset.zero;
  Size _viewport = Size.zero;

  static const _maxScale = 6.0;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      final animation = _zoomAnimation;
      if (animation != null) _transform.value = animation.value;
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  void _animateTo(Matrix4 target) {
    if (Motion.of(context).reduced) {
      _transform.value = target;
      return;
    }
    _zoomAnimation = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).chain(CurveTween(curve: Motion.standardCurve)).animate(_zoom);
    _zoom.forward(from: 0);
  }

  /// Zooms by [factor] around [focus] (the centre when null).
  void _zoomBy(double factor, [Offset? focus]) {
    final center = focus ?? _viewport.center(Offset.zero);
    final next = (_scale * factor).clamp(1.0, _maxScale);
    final scene = _transform.toScene(center);
    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    _animateTo(next == 1 ? Matrix4.identity() : matrix);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      minimumSize: const Size(48, 48),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop(),
        const SingleActivator(LogicalKeyboardKey.equal): () => _zoomBy(1.5),
        const SingleActivator(LogicalKeyboardKey.minus): () => _zoomBy(1 / 1.5),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          // The medical and document viewer is black in both themes.
          backgroundColor: scheme.scrim,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        style: buttonStyle,
                        tooltip: l10n.adminClose,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: DecoratedBox(
                          decoration: ShapeDecoration(color: scheme.surfaceContainerHighest, shape: const StadiumBorder()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Text(
                              l10n.adminLicenseImageOf(widget.title),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _viewport = constraints.biggest;
                        return GestureDetector(
                          onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
                          onDoubleTap: () =>
                              _scale > 1.05 ? _animateTo(Matrix4.identity()) : _zoomBy(2.5, _doubleTapAt),
                          child: InteractiveViewer(
                            transformationController: _transform,
                            maxScale: _maxScale,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: Semantics(
                                image: true,
                                label: l10n.adminLicenseImageOf(widget.title),
                                child: Image.memory(widget.file.bytes, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        style: buttonStyle,
                        tooltip: l10n.adminZoomOut,
                        icon: const Icon(Icons.remove),
                        onPressed: () => _zoomBy(1 / 1.5),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        style: buttonStyle,
                        tooltip: l10n.adminZoomReset,
                        icon: const Icon(Icons.fit_screen_outlined),
                        onPressed: () => _animateTo(Matrix4.identity()),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        style: buttonStyle,
                        tooltip: l10n.adminZoomIn,
                        icon: const Icon(Icons.add),
                        onPressed: () => _zoomBy(1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
