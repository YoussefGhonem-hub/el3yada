import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_providers.dart';
import '../../domain/license_file.dart';
import '../registration_text.dart';

/// A small preview of the license: the photo itself, or a PDF file tile.
/// Tapping a photo opens it full size.
class LicenseThumbnail extends StatelessWidget {
  const LicenseThumbnail({super.key, this.file, this.contentType, this.size = 72});

  /// The bytes, when the app has them. Without them a tile shows [contentType].
  final LicenseFile? file;
  final String? contentType;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final type = file?.contentType ?? contentType;
    final image = file != null && file!.isImage;

    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: image
            ? Image.memory(
                file!.bytes,
                fit: BoxFit.cover,
                cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => _TypeTile(type: type),
              )
            : _TypeTile(type: type),
      ),
    );

    if (!image) return Semantics(label: l10n.regLicenseKind(type), excludeSemantics: true, child: tile);
    return Semantics(
      button: true,
      label: l10n.regLicenseOpen,
      excludeSemantics: true,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: () => _open(context, file!), child: tile),
      ),
    );
  }

  static void _open(BuildContext context, LicenseFile file) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Image.memory(file.bytes, fit: BoxFit.contain, semanticLabel: l10n.regLicenseFileLabel),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: IconButton.filledTonal(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pdf = type == LicenseFile.pdf;
    return ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(pdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined, color: scheme.onPrimaryContainer),
            if (pdf)
              Text('PDF', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

/// The license already on the server (A6, and A7's form until it is
/// replaced), loaded from `myRegistration/license` with a skeleton.
class SubmittedLicenseThumbnail extends ConsumerWidget {
  const SubmittedLicenseThumbnail({super.key, required this.contentType, this.size = 72});

  final String? contentType;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(myLicenseProvider);
    return SkeletonLoading(
      loading: license.isLoading && !license.hasValue,
      child: LicenseThumbnail(file: license.value, contentType: contentType, size: size),
    );
  }
}
