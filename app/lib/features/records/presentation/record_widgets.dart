import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/records_providers.dart';
import '../application/upload_controller.dart';
import '../domain/record_models.dart';
import 'record_text.dart';

/// A file's small picture: the server's thumbnail when there is one (only
/// thumbnails load in lists, never the files), else the type's icon.
class RecordThumbnail extends ConsumerWidget {
  const RecordThumbnail({super.key, required this.recordId, required this.attachment, this.iconSize = 32});

  final String recordId;
  final RecordAttachment? attachment;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final file = attachment;
    Widget icon() => ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: Center(
            child: Icon(
              file == null ? Icons.insert_drive_file_outlined : fileIcon(file.mimeType, fileName: file.fileName),
              size: iconSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
    if (file == null || !file.hasThumbnail) return icon();
    final thumb = ref.watch(recordThumbnailProvider((recordId: recordId, attachmentId: file.attachmentId)));
    return AnimatedSwitcher(
      duration: Motion.normal,
      switchInCurve: Motion.enterCurve,
      switchOutCurve: Motion.exitCurveReversed,
      child: switch (thumb) {
        AsyncData(:final value?) => Image.memory(
            value,
            key: const ValueKey('image'),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => icon(),
          ),
        AsyncLoading() => ColoredBox(key: const ValueKey('loading'), color: scheme.surfaceContainerHigh),
        _ => KeyedSubtree(key: const ValueKey('icon'), child: icon()),
      },
    );
  }
}

/// A record in the D6 Files tab: its cover, title, date, the Other type,
/// the file count and size, and "Recorded by …" for the doctor (BR-AS10).
class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.record, required this.onTap, this.showRecorder = false});

  final MedicalRecordView record;
  final VoidCallback? onTap;
  final bool showRecorder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = l10n.recordTypeLabel(record);
    final pages = record.attachments.length == 1 ? record.attachments.first.pageCount : null;
    return Semantics(
      button: onTap != null,
      label: '${record.title}, ${l10n.recordCategoryName(record.category)}, ${ClinicFormat.dayAuto(context, record.documentDate)}',
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RecordThumbnail(recordId: record.recordId, attachment: record.cover ?? record.attachments.firstOrNull),
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: _Tag(icon: recordCategoryIcon(record.category), text: type ?? l10n.recordCategoryName(record.category)),
                    ),
                    if (record.attachments.length > 1)
                      PositionedDirectional(
                        bottom: 8,
                        end: 8,
                        child: _Tag(icon: Icons.collections_outlined, text: '${record.attachments.length}'),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        MetaLine(icon: Icons.event_outlined, text: ClinicFormat.dayAuto(context, record.documentDate)),
                        MetaLine(
                          icon: Icons.sd_storage_outlined,
                          text: pages != null && pages > 1
                              ? '${l10n.recordPagesCount(pages)} · ${l10n.fileSize(record.totalSizeBytes)}'
                              : l10n.fileSize(record.totalSizeBytes),
                        ),
                        if (showRecorder && record.createdBy.isAssistant)
                          MetaLine(icon: Icons.person_outline, text: l10n.sessionRecordedBy(record.createdBy.name)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small label over a picture, readable on any image.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: scheme.surface.withValues(alpha: 0.92), shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 14, color: scheme.primary)),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// The category chips with their counts (D6 Files tab).
class RecordCategoryChips extends StatelessWidget {
  const RecordCategoryChips({super.key, required this.selected, required this.counts, required this.onSelected});

  final RecordCategory? selected;
  final RecordCounts? counts;
  final ValueChanged<RecordCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClinicChips(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in <RecordCategory?>[null, ...RecordCategory.values]) ...[
              ChoiceChip(
                label: Text(
                  counts == null
                      ? l10n.recordCategoryName(category)
                      : l10n.recordChip(l10n.recordCategoryName(category), counts!.of(category)),
                ),
                selected: selected == category,
                onSelected: (_) => onSelected(category),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// One file in D10/D11: name, size, its own progress bar, the saving, and
/// Retry or Remove (AC-14).
class UploadItemRow extends StatelessWidget {
  const UploadItemRow({super.key, required this.item, required this.maxMb, this.onRetry, this.onRemove});

  final UploadItem item;
  final int maxMb;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed = item.status == UploadStatus.failed || item.status == UploadStatus.tooLarge;
    final status = switch (item.status) {
      UploadStatus.preparing => l10n.recordPreparing,
      UploadStatus.uploading => l10n.recordUploading((item.progress * 100).round()),
      UploadStatus.done => item.savedTo == null
          ? l10n.recordUploaded
          : l10n.recordSavedSpace(l10n.fileSize(item.pickedBytes), l10n.fileSize(item.savedTo!)),
      UploadStatus.failed => item.error == null ? l10n.recordUploadFailed : l10n.recordError(item.error!, maxMb: maxMb),
      UploadStatus.tooLarge => l10n.recordTooLarge(maxMb),
    };
    final color = failed ? scheme.error : (item.status == UploadStatus.done ? scheme.primary : scheme.onSurfaceVariant);
    final reduced = Motion.of(context).reduced;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(
                  item.status == UploadStatus.done
                      ? Icons.check_circle_outline
                      : (failed ? Icons.error_outline : fileIcon(item.source.mimeType ?? '', fileName: item.name)),
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.fileSize(item.pickedBytes), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(
                  label: status,
                  value: item.status == UploadStatus.uploading ? '${(item.progress * 100).round()}%' : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: item.status == UploadStatus.preparing ? 0 : item.progress),
                      duration: reduced ? Duration.zero : Motion.normal,
                      curve: Motion.standardCurve,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: item.status == UploadStatus.preparing ? null : value,
                        minHeight: 6,
                        color: failed ? scheme.error : null,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(status, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: color)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (item.status == UploadStatus.failed && onRetry != null)
            IconButton(tooltip: l10n.retryButton, onPressed: onRetry, icon: const Icon(Icons.refresh)),
          if (onRemove != null)
            IconButton(tooltip: l10n.recordRemoveFile, onPressed: onRemove, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
