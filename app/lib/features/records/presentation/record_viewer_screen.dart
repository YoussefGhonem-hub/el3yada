import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/application/clinic_providers.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/records_providers.dart';
import '../data/file_actions.dart';
import '../data/file_prep.dart';
import '../data/records_repository.dart';
import '../domain/record_models.dart';
import 'record_text.dart';

/// D12 / AS6: a record's files on a black background in both themes (pinch
/// and double-tap zoom, swipe between files), PDFs page by page, other types
/// with "Open with" and "Download", the details, and Edit, Share, Download
/// and Delete (doctor only, BR-AS: assistants never delete).
class RecordViewerScreen extends ConsumerStatefulWidget {
  const RecordViewerScreen({super.key, required this.patientId, required this.recordId, this.initial, this.onClose});

  final String patientId;
  final String recordId;

  /// The list's copy, shown at once while the record loads.
  final MedicalRecordView? initial;

  /// Closes the ContainerTransform (from the Files tab); otherwise Back pops.
  final ValueChanged<bool>? onClose;

  @override
  ConsumerState<RecordViewerScreen> createState() => _RecordViewerScreenState();
}

class _RecordViewerScreenState extends ConsumerState<RecordViewerScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ClinicPaths get _paths => ref.read(clinicPathsProvider);

  void _close([bool changed = false]) {
    if (widget.onClose != null) {
      widget.onClose!(changed);
    } else if (context.canPop()) {
      context.pop(changed);
    } else {
      context.go(_paths.patient(widget.patientId));
    }
  }

  void _goTo(int index, int count) {
    if (index < 0 || index >= count) return;
    if (Motion.of(context).reduced) {
      _pages.jumpToPage(index);
    } else {
      _pages.animateToPage(index, duration: Motion.normal, curve: Motion.standardCurve);
    }
  }

  Future<Uint8List?> _bytes(MedicalRecordView record, RecordAttachment file) async {
    try {
      return await ref.read(recordFileProvider((recordId: record.recordId, attachmentId: file.attachmentId)).future);
    } catch (error) {
      if (mounted) showAdminSnack(context, AppLocalizations.of(context).recordError(error), error: true);
      return null;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openWith(MedicalRecordView record, RecordAttachment file) => _run(() async {
        final bytes = await _bytes(record, file);
        if (bytes == null || !mounted) return;
        final opened = await ref.read(fileActionsProvider).openWith(bytes, fileName: file.fileName, mimeType: file.mimeType);
        if (!opened && mounted) showAdminSnack(context, AppLocalizations.of(context).recordCantOpen, error: true);
      });

  Future<void> _download(MedicalRecordView record, RecordAttachment file) => _run(() async {
        final bytes = await _bytes(record, file);
        if (bytes == null || !mounted) return;
        final saved = await ref.read(fileActionsProvider).save(bytes, fileName: file.fileName, mimeType: file.mimeType);
        if (saved && mounted) showAdminSnack(context, AppLocalizations.of(context).recordDownloaded);
      });

  Future<void> _share(MedicalRecordView record, RecordAttachment file) => _run(() async {
        final bytes = await _bytes(record, file);
        if (bytes == null || !mounted) return;
        await ref.read(fileActionsProvider).share(bytes, fileName: file.fileName, mimeType: file.mimeType);
      });

  Future<void> _edit(MedicalRecordView record) async {
    final changed = await context.push<bool>(_paths.editRecord(widget.patientId, record.recordId));
    if (changed == true && mounted) recordsChanged(ref, recordId: record.recordId);
  }

  Future<void> _delete(MedicalRecordView record) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.recordDeleteTitle,
      message: l10n.recordDeleteBody,
      confirmLabel: l10n.recordDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      try {
        await ref.read(recordsRepositoryProvider).deleteRecord(record.recordId);
        if (!mounted) return;
        showAdminSnack(context, l10n.recordDeleted);
        recordsChanged(ref);
        _close(true);
      } on ApiException catch (error) {
        if (mounted) showAdminSnack(context, l10n.recordError(error), error: true);
      }
    });
  }

  void _showDetails(MedicalRecordView record) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: RecordDetails(record: record),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(recordProvider(widget.recordId));
    final record = value.value ?? widget.initial;
    return Theme(
      // The medical file viewer is black in both themes (D12).
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: scheme.scrim,
            body: SafeArea(
              child: record == null
                  ? (value.hasError
                      ? AdminErrorView(error: value.error!, onRetry: () => ref.invalidate(recordProvider(widget.recordId)))
                      : const Center(child: CircularProgressIndicator()))
                  : _viewer(context, record),
            ),
          );
        },
      ),
    );
  }

  Widget _viewer(BuildContext context, MedicalRecordView record) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final clinic = ref.watch(clinicContextProvider).value;
    final canEdit = !(clinic?.isSuspended ?? false);
    final canDelete = canEdit && (clinic?.isDoctor ?? false);
    final files = record.attachments;
    final count = files.length;
    final index = _index.clamp(0, count == 0 ? 0 : count - 1);
    final current = count == 0 ? null : files[index];
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final buttonStyle = IconButton.styleFrom(
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      minimumSize: const Size(48, 48),
    );

    final menu = [
      if (current != null) ...[
        MenuItemButton(
          leadingIcon: const Icon(Icons.open_in_new),
          onPressed: _busy ? null : () => _openWith(record, current),
          child: Text(l10n.recordOpenWith),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.download_outlined),
          onPressed: _busy ? null : () => _download(record, current),
          child: Text(l10n.recordDownload),
        ),
      ],
      if (canEdit)
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: () => _edit(record),
          child: Text(l10n.recordEdit),
        ),
      if (canDelete)
        MenuItemButton(
          leadingIcon: Icon(Icons.delete_outline, color: scheme.error),
          onPressed: _busy ? null : () => _delete(record),
          child: Text(l10n.recordDelete, style: TextStyle(color: scheme.error)),
        ),
    ];

    final top = Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton(
            style: buttonStyle,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            onPressed: _close,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                if (count > 1)
                  Text(
                    l10n.recordAttachmentOf(index + 1, count),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          if (current != null)
            IconButton(
              style: buttonStyle,
              tooltip: l10n.recordShare,
              onPressed: _busy ? null : () => _share(record, current),
              icon: const Icon(Icons.share_outlined),
            ),
          if (!wide) ...[
            const SizedBox(width: 8),
            IconButton(
              style: buttonStyle,
              tooltip: l10n.recordDetails,
              onPressed: () => _showDetails(record),
              icon: const Icon(Icons.info_outline),
            ),
          ],
          const SizedBox(width: 8),
          MenuAnchor(
            menuChildren: menu,
            builder: (context, controller, _) => IconButton(
              style: buttonStyle,
              tooltip: l10n.patientMoreActions,
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
    );

    final pages = PageView.builder(
      controller: _pages,
      itemCount: count,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) => _AttachmentPage(
        record: record,
        file: files[i],
        onOpenWith: () => _openWith(record, files[i]),
        onDownload: () => _download(record, files[i]),
      ),
    );

    final nav = count < 2
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  style: buttonStyle,
                  tooltip: l10n.recordPrevious,
                  onPressed: index > 0 ? () => _goTo(index - 1, count) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 16),
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == index ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                const SizedBox(width: 16),
                IconButton(
                  style: buttonStyle,
                  tooltip: l10n.recordNext,
                  onPressed: index < count - 1 ? () => _goTo(index + 1, count) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          );

    final viewer = Column(children: [top, Expanded(child: pages), nav]);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _goTo(Directionality.of(context) == TextDirection.rtl ? index + 1 : index - 1, count),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _goTo(Directionality.of(context) == TextDirection.rtl ? index - 1 : index + 1, count),
      },
      child: Focus(
        autofocus: true,
        child: !wide
            ? viewer
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: viewer),
                  SizedBox(
                    width: 360,
                    child: Material(
                      color: scheme.surfaceContainer,
                      child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: RecordDetails(record: record)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// One file in the viewer: an image to zoom, a PDF page by page, or the
/// type's icon with "Open with" and "Download".
class _AttachmentPage extends ConsumerWidget {
  const _AttachmentPage({required this.record, required this.file, required this.onOpenWith, required this.onDownload});

  final MedicalRecordView record;
  final RecordAttachment file;
  final VoidCallback onOpenWith;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (!file.previewable) return _OtherFile(file: file, onOpenWith: onOpenWith, onDownload: onDownload);
    final bytes = ref.watch(recordFileProvider((recordId: record.recordId, attachmentId: file.attachmentId)));
    return switch (bytes) {
      AsyncData(:final value) when file.isImage => _ZoomableImage(bytes: value, label: file.fileName),
      AsyncData(:final value) => _PdfPages(bytes: value, file: file, onOpenWith: onOpenWith),
      AsyncError(:final error) => Center(
          child: AdminErrorView(
            error: error,
            onRetry: () => ref.invalidate(recordFileProvider((recordId: record.recordId, attachmentId: file.attachmentId))),
          ),
        ),
      _ => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.recordLoadingFile),
            ],
          ),
        ),
    };
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.bytes, required this.label});

  final Uint8List bytes;
  final String label;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transform = TransformationController();
  Offset _tapAt = Offset.zero;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.05) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-_tapAt.dx * (scale - 1), -_tapAt.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onDoubleTapDown: (details) => _tapAt = details.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transform,
          maxScale: 6,
          child: Center(
            child: Semantics(
              image: true,
              label: widget.label,
              child: Image.memory(widget.bytes, fit: BoxFit.contain, gaplessPlayback: true),
            ),
          ),
        ),
      );
}

/// A PDF's pages drawn by the system's PDF renderer, in a zoomable scroll.
class _PdfPages extends ConsumerStatefulWidget {
  const _PdfPages({required this.bytes, required this.file, required this.onOpenWith});

  final Uint8List bytes;
  final RecordAttachment file;
  final VoidCallback onOpenWith;

  @override
  ConsumerState<_PdfPages> createState() => _PdfPagesState();
}

class _PdfPagesState extends ConsumerState<_PdfPages> {
  final _pages = <Uint8List>[];
  bool _done = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    try {
      await for (final page in ref.read(uploadPrepProvider).pdfPages(widget.bytes)) {
        if (!mounted) return;
        setState(() => _pages.add(page));
      }
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_failed || (_done && _pages.isEmpty)) {
      return _OtherFile(file: widget.file, onOpenWith: widget.onOpenWith, message: l10n.recordPdfFailed);
    }
    if (_pages.isEmpty) return const Center(child: CircularProgressIndicator());
    return InteractiveViewer(
      maxScale: 5,
      constrained: true,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _pages.length + (_done ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => i == _pages.length
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            : Semantics(
                image: true,
                label: l10n.recordScanPage(i + 1),
                child: Image.memory(_pages[i], fit: BoxFit.contain),
              ),
      ),
    );
  }
}

/// A file the app doesn't show: its icon, name and size, "Open with" and
/// "Download" (BR-F4).
class _OtherFile extends StatelessWidget {
  const _OtherFile({required this.file, required this.onOpenWith, this.onDownload, this.message});

  final RecordAttachment file;
  final VoidCallback onOpenWith;
  final VoidCallback? onDownload;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Icon(fileIcon(file.mimeType, fileName: file.fileName), size: 56, color: scheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(file.fileName, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.fileSize(file.sizeBytes), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              Text(
                message ?? l10n.recordNoPreview,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(onPressed: onOpenWith, icon: const Icon(Icons.open_in_new), label: Text(l10n.recordOpenWith)),
                  if (onDownload != null)
                    OutlinedButton.icon(onPressed: onDownload, icon: const Icon(Icons.download_outlined), label: Text(l10n.recordDownload)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The record's details: category and type, dates, visit, notes, who added
/// it, and the files with their sizes.
class RecordDetails extends StatelessWidget {
  const RecordDetails({super.key, required this.record});

  final MedicalRecordView record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = l10n.recordTypeLabel(record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.recordDetails, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        InfoRow(
          label: l10n.recordFieldCategory,
          value: type == null ? l10n.recordCategoryName(record.category) : '${l10n.recordCategoryName(record.category)} · $type',
        ),
        const SizedBox(height: 12),
        InfoRow(label: l10n.recordFieldDate, value: ClinicFormat.day(context, record.documentDate)),
        if (record.session != null) ...[
          const SizedBox(height: 12),
          InfoRow(
            label: l10n.recordVisit,
            value: l10n.recordSessionOption(
              sessionTypeLabel(l10n, record.session!.type),
              ClinicFormat.dayAuto(context, ClinicFormat.today(record.session!.createdAt)),
            ),
          ),
        ],
        if (record.notes != null) ...[
          const SizedBox(height: 12),
          InfoRow(label: l10n.recordFieldNotes, value: record.notes),
        ],
        const SizedBox(height: 12),
        InfoRow(
          label: l10n.recordSourceName(record.source),
          value: [
            l10n.recordAdded(ClinicFormat.dayAuto(context, ClinicFormat.today(record.createdAt))),
            if (record.createdBy.isAssistant) l10n.sessionRecordedBy(record.createdBy.name),
          ].join(' · '),
        ),
        const SizedBox(height: 20),
        Text(l10n.recordFilesHeading, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        for (final file in record.attachments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(fileIcon(file.mimeType, fileName: file.fileName), size: 20, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Expanded(child: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(
                  file.pageCount != null && file.pageCount! > 1
                      ? '${l10n.recordPagesCount(file.pageCount!)} · ${l10n.fileSize(file.sizeBytes)}'
                      : l10n.fileSize(file.sizeBytes),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            Text(l10n.recordSize, style: theme.textTheme.labelLarge),
            const Spacer(),
            Text(l10n.fileSize(record.totalSizeBytes), style: theme.textTheme.labelLarge),
          ],
        ),
      ],
    );
  }
}
