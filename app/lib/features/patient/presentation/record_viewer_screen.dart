import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../core/network/api_error.dart';
import '../../../core/platform/file_share.dart';
import '../../../core/theme/app_theme.dart';
import '../application/patient_providers.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'widgets/patient_widgets.dart';

/// P9 File viewer: the D12 viewer without edit or delete. Black background, pinch zoom,
/// swipe between attachments, PDF pages; other file types offer Share / Open with (BR-F4).
class RecordViewerScreen extends ConsumerStatefulWidget {
  const RecordViewerScreen({super.key, required this.recordId, this.initialAttachment = 0});

  final String recordId;
  final int initialAttachment;

  @override
  ConsumerState<RecordViewerScreen> createState() => _RecordViewerScreenState();
}

class _RecordViewerScreenState extends ConsumerState<RecordViewerScreen> {
  late final PageController _pages = PageController(initialPage: widget.initialAttachment);
  late int _index = widget.initialAttachment;
  bool _sharing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _share(Attachment attachment) async {
    setState(() => _sharing = true);
    try {
      final bytes = await ref.read(fileBytesProvider(FileRef.attachment(widget.recordId, attachment.id)).future);
      await FileShare.share(bytes, fileName: attachment.fileName, mimeType: attachment.mimeType);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.apiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showInfo(RecordDetail record) {
    final l10n = context.l10n;
    final typeLabel = context.otherType(record.otherType, record.otherTypeText);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledValue(label: l10n.fileTitle, value: record.title),
              LabeledValue(label: l10n.fileCategory, value: [context.recordCategory(record.category), ?typeLabel].join(' · ')),
              LabeledValue(label: l10n.documentDate, value: context.date(record.documentDate)),
              LabeledValue(label: l10n.doctor, value: context.doctorName(record.doctor)),
              if (record.notes != null && record.notes!.isNotEmpty) LabeledValue(label: l10n.notes, value: record.notes!),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(recordDetailProvider(widget.recordId));
    final data = record.value;
    final attachments = data?.attachments ?? const <Attachment>[];
    final current = attachments.isEmpty ? null : attachments[_index.clamp(0, attachments.length - 1)];

    // The viewer is dark in both themes, like a lightbox (D12: black background).
    final dark = AppTheme.dark();
    final scheme = dark.colorScheme;
    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: scheme.surfaceContainerLowest,
          title: Text(data?.title ?? ''),
          actions: [
            if (data != null)
              IconButton(tooltip: context.l10n.fileDetails, icon: const Icon(Icons.info_outline), onPressed: () => _showInfo(data)),
            if (current != null)
              IconButton(
                tooltip: context.l10n.shareOrSave,
                icon: _sharing
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.ios_share),
                onPressed: _sharing ? null : () => _share(current),
              ),
          ],
        ),
        body: AsyncValueView(
          value: record,
          onRetry: () => ref.invalidate(recordDetailProvider(widget.recordId)),
          data: (data) => data.attachments.isEmpty
              ? EmptyState(icon: Icons.insert_drive_file_outlined, message: context.l10n.noAttachments)
              : Stack(
                  children: [
                    PageView.builder(
                      controller: _pages,
                      itemCount: data.attachments.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _AttachmentView(recordId: data.id, attachment: data.attachments[i]),
                    ),
                    if (data.attachments.length > 1)
                      PositionedDirectional(
                        bottom: 24,
                        start: 0,
                        end: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: scheme.scrim.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
                            child: Text(
                              context.l10n.pageOf(_index + 1, data.attachments.length),
                              style: TextStyle(color: scheme.onSurface),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AttachmentView extends ConsumerWidget {
  const _AttachmentView({required this.recordId, required this.attachment});

  final String recordId;
  final Attachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!attachment.canPreview) {
      return EmptyState(icon: Icons.insert_drive_file_outlined, message: context.l10n.cannotPreview(attachment.fileName));
    }
    final file = FileRef.attachment(recordId, attachment.id);
    final bytes = ref.watch(fileBytesProvider(file));
    return AsyncValueView(
      value: bytes,
      onRetry: () => ref.invalidate(fileBytesProvider(file)),
      data: (data) => attachment.isPdf
          ? PdfViewer.data(data, sourceName: attachment.fileName)
          : InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(child: Image.memory(data, fit: BoxFit.contain, semanticLabel: attachment.fileName)),
            ),
    );
  }
}
