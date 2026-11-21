import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/branch_photo_picker.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../data/clinic_admin_repository.dart';
import '../../domain/branch_models.dart';
import '../widgets/clinic_admin_widgets.dart';

/// D29 Info tab: the branch's photos [S] (BR-BR2), up to [BranchPhoto.max].
/// The doctor adds them (picked, made smaller on the device, cut to 1600 px
/// by the server), puts them in order (the first is the cover patients see
/// first in P3) and deletes them. Changes apply at once. Read-only for
/// assistants ([editable] false, AS17).
class BranchPhotosCard extends ConsumerStatefulWidget {
  const BranchPhotosCard({super.key, required this.details, this.editable = true});

  final BranchDetails details;
  final bool editable;

  @override
  ConsumerState<BranchPhotosCard> createState() => _BranchPhotosCardState();
}

class _BranchPhotosCardState extends ConsumerState<BranchPhotosCard> {
  bool _busy = false;

  BranchDetailController get _controller => ref.read(branchDetailProvider(widget.details.id).notifier);

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        ClinicAdminCodes.branchPhotoLimit => l10n.branchPhotosLimit(BranchPhoto.max),
        _ when error.fieldCodes['file'] == 'FILE_TYPE_NOT_ALLOWED' || error.fieldCodes['file'] == 'FILE_CONTENT_INVALID' =>
          l10n.branchPhotosNotImage,
        _ when error.fieldCodes['file'] == 'FILE_TOO_LARGE' => l10n.branchPhotosTooLarge,
        _ => l10n.apiError(error),
      };
      showAdminSnack(context, message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final room = BranchPhoto.max - widget.details.photos.length;
    if (room <= 0) return;
    final picked = await ref.read(branchPhotoPickerProvider).pick(max: room);
    if (picked.isEmpty || !mounted) return;
    await _run(() async {
      for (final photo in picked) {
        await _controller.uploadPhoto(photo.bytes, photo.name);
      }
      if (mounted) showAdminSnack(context, AppLocalizations.of(context).branchPhotosAdded(picked.length));
    });
  }

  Future<void> _move(int from, int to) {
    final ids = [for (final p in widget.details.photos) p.id];
    final id = ids.removeAt(from);
    ids.insert(to, id);
    return _run(() => _controller.reorderPhotos(ids));
  }

  Future<void> _delete(BranchPhoto photo) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.branchPhotosDeleteTitle,
      message: l10n.branchPhotosDeleteBody,
      confirmLabel: l10n.remove,
      destructive: true,
    );
    if (confirmed && mounted) await _run(() => _controller.deletePhoto(photo.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final photos = widget.details.photos;
    final editable = widget.editable;
    final canAdd = editable && photos.length < BranchPhoto.max;
    final reduced = Motion.of(context).reduced;
    return SectionCard(
      icon: Icons.photo_library_outlined,
      title: l10n.branchPhotosTitle,
      subtitle: editable ? l10n.branchPhotosBody(BranchPhoto.max) : null,
      trailing: editable ? Text(l10n.branchPhotosCount(photos.length, BranchPhoto.max), style: theme.textTheme.labelLarge) : null,
      child: MotionSize(
        alignment: AlignmentDirectional.topStart,
        child: photos.isEmpty && !canAdd
            ? Text(l10n.branchPhotosNone, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (i, photo) in photos.indexed)
                    AnimatedSwitcher(
                      key: ValueKey(photo.id),
                      duration: reduced ? Duration.zero : Motion.normal,
                      switchInCurve: Motion.enterCurve,
                      child: _PhotoTile(
                        key: ValueKey('${photo.id}-$i'),
                        branchId: widget.details.id,
                        photo: photo,
                        cover: i == 0,
                        enabled: editable && !_busy,
                        onEarlier: editable && i > 0 ? () => _move(i, i - 1) : null,
                        onLater: editable && i < photos.length - 1 ? () => _move(i, i + 1) : null,
                        onDelete: editable ? () => _delete(photo) : null,
                      ),
                    ),
                  if (canAdd) _AddTile(busy: _busy, onTap: _busy ? null : _add),
                ],
              ),
      ),
    );
  }
}

const _tileWidth = 168.0;
const _tileHeight = 112.0;

class _PhotoTile extends ConsumerWidget {
  const _PhotoTile({
    super.key,
    required this.branchId,
    required this.photo,
    required this.cover,
    required this.enabled,
    this.onEarlier,
    this.onLater,
    this.onDelete,
  });

  final String branchId;
  final BranchPhoto photo;
  final bool cover;
  final bool enabled;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final bytes = ref.watch(branchPhotoProvider((branchId: branchId, photoId: photo.id, thumbnail: true)));
    final image = switch (bytes) {
      AsyncValue(:final value?, hasValue: true) => Image.memory(value, fit: BoxFit.cover, gaplessPlayback: true, semanticLabel: l10n.branchPhotoLabel),
      AsyncValue(hasError: true) => Icon(Icons.broken_image_outlined, color: scheme.outline),
      _ => const Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
    };
    Widget action(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 18),
          visualDensity: VisualDensity.compact,
        );
    final hasActions = onEarlier != null || onLater != null || onDelete != null;
    return SizedBox(
      width: _tileWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: _tileHeight,
              color: scheme.surfaceContainerHighest,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  if (cover)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(color: scheme.primary, shape: const StadiumBorder()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Text(l10n.branchPhotoCover, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimary)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (hasActions)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  action(rtl ? Icons.arrow_forward : Icons.arrow_back, l10n.branchPhotoEarlier, onEarlier),
                  action(rtl ? Icons.arrow_back : Icons.arrow_forward, l10n.branchPhotoLater, onLater),
                  action(Icons.delete_outline, l10n.remove, onDelete),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: _tileWidth,
      height: _tileHeight,
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                busy
                    ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Icon(Icons.add_photo_alternate_outlined, color: scheme.primary, size: 28),
                const SizedBox(height: 8),
                Text(l10n.branchPhotosAdd, style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
