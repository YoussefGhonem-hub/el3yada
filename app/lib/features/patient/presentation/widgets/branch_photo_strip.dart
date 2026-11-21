import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../data/patient_repository.dart';
import '../../domain/patient_models.dart';

typedef _PhotoKey = ({String doctorId, String branchId, String photoId, bool thumbnail});

/// A branch photo's bytes, kept a few minutes after the screen stops showing it.
final _branchPhotoProvider = FutureProvider.autoDispose.family<Uint8List, _PhotoKey>((ref, key) async {
  final bytes = await ref.read(patientRepositoryProvider).branchPhoto(key.doctorId, key.branchId, key.photoId, thumbnail: key.thumbnail);
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  return bytes;
});

/// P3: the branch's photos (D29 [S]) as a row of thumbnails; a tap opens
/// them full screen, to swipe through. Nothing shows without photos.
class BranchPhotoStrip extends StatelessWidget {
  const BranchPhotoStrip({super.key, required this.doctorId, required this.branch});

  final String doctorId;
  final BranchInfo branch;

  @override
  Widget build(BuildContext context) {
    final ids = branch.photoIds;
    if (ids.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ids.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _Thumb(
          photo: (doctorId: doctorId, branchId: branch.id, photoId: ids[i], thumbnail: true),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => _PhotoViewer(doctorId: doctorId, branchId: branch.id, ids: ids, initial: i),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.photo, required this.onTap});

  final _PhotoKey photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: AppLocalizations.of(context).branchPhotoLabel,
            child: _Photo(photo: photo, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.photo, required this.fit});

  final _PhotoKey photo;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = ref.watch(_branchPhotoProvider(photo));
    return AnimatedSwitcher(
      duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
      switchInCurve: Motion.enterCurve,
      child: switch (bytes) {
        AsyncValue(:final value?, hasValue: true) => Image.memory(value, key: const ValueKey('image'), fit: fit, gaplessPlayback: true),
        AsyncValue(hasError: true) => Center(key: const ValueKey('error'), child: Icon(Icons.broken_image_outlined, color: scheme.outline)),
        _ => const Center(key: ValueKey('loading'), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      },
    );
  }
}

/// The photos full screen, to swipe through and zoom.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.doctorId, required this.branchId, required this.ids, required this.initial});

  final String doctorId;
  final String branchId;
  final List<String> ids;
  final int initial;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Dialog.fullscreen(
      backgroundColor: scheme.scrim,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.ids.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => InteractiveViewer(
              child: Center(
                child: _Photo(
                  photo: (doctorId: widget.doctorId, branchId: widget.branchId, photoId: widget.ids[i], thumbnail: false),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  if (widget.ids.length > 1)
                    DecoratedBox(
                      decoration: ShapeDecoration(color: scheme.surface, shape: const StadiumBorder()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text(l10n.branchPhotosCount(_page + 1, widget.ids.length)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
