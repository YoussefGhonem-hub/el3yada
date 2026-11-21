import 'package:desktop_drop/desktop_drop.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/app_platform.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/container_transform.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/records_providers.dart';
import '../data/file_sources.dart';
import '../domain/record_models.dart';
import 'record_viewer_screen.dart';
import 'record_widgets.dart';

/// D6 Files tab and AS6 (`filesManage`): the category chips with counts,
/// the records (newest first, thumbnails only), and Upload and Scan. On
/// desktop, files dropped on the tab open the upload screen with them
/// (BR-F7). Hidden while the doctor is suspended: the actions only.
class FilesTab extends ConsumerStatefulWidget {
  const FilesTab({super.key, required this.patientId, required this.clinic});

  final String patientId;
  final ClinicContext clinic;

  @override
  ConsumerState<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<FilesTab> {
  RecordCategory? _category;
  bool _dragging = false;

  RecordFilter get _filter => (patientId: widget.patientId, category: _category);

  bool get _canAdd => !widget.clinic.isSuspended;

  ClinicPaths get _paths => ref.read(clinicPathsProvider);

  Future<void> _upload({List<UploadSource> files = const [], bool scan = false}) async {
    await context.push(_paths.uploadFiles(widget.patientId, scan: scan), extra: files);
    if (mounted) recordsChanged(ref);
  }

  Future<void> _dropped(DropDoneDetails details) async {
    setState(() => _dragging = false);
    if (!_canAdd || details.files.isEmpty) return;
    final files = await ref.read(fileSourcesProvider).fromXFiles(details.files);
    if (mounted) await _upload(files: files);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = ref.watch(appPlatformProvider).isDesktop;
    final content = _content(context, desktop: desktop);
    if (!desktop) return content;
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      // A drop target keeps listening under a pushed page: only the visible one takes files.
      enable: _canAdd && (ModalRoute.of(context)?.isCurrent ?? true),
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _dropped,
      child: Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _dragging ? 1 : 0,
                duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_download_outlined, size: 40, color: scheme.onPrimaryContainer),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).recordDropHint,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, {required bool desktop}) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(recordListProvider(_filter));
    final controller = ref.read(recordListProvider(_filter).notifier);
    final actions = !_canAdd
        ? const <Widget>[]
        : [
            FilledButton.tonalIcon(
              onPressed: () => _upload(),
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(l10n.recordAddFiles),
            ),
            if (!desktop)
              OutlinedButton.icon(
                onPressed: () => _upload(scan: true),
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l10n.recordScan),
              ),
          ];

    final Widget body;
    if (state.loading) {
      body = SkeletonLoading(loading: true, child: _grid(context, [for (var i = 0; i < 3; i++) _placeholder(i)], skeleton: true));
    } else if (state.error != null && state.items.isEmpty) {
      body = AdminErrorView(error: state.error!, compact: true, onRetry: controller.reload);
    } else if (state.items.isEmpty) {
      body = EmptyState(
        title: _category == null ? l10n.recordsEmptyTitle : l10n.recordsEmptyCategory,
        message: _category == null && _canAdd ? l10n.recordsEmptyBody : null,
        actionLabel: _canAdd ? l10n.recordAddFiles : null,
        onAction: _canAdd ? () => _upload() : null,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggerGroup(child: _grid(context, state.items)),
          if (state.moreError != null)
            AdminErrorView(error: state.moreError!, compact: true, onRetry: controller.loadMore)
          else if (state.hasMore)
            Center(
              child: TextButton(
                onPressed: state.loadingMore ? null : controller.loadMore,
                child: Text(state.loadingMore ? l10n.loading : l10n.patientLoadMore),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (actions.isNotEmpty) ...[
          Wrap(spacing: 8, runSpacing: 8, children: actions),
          const SizedBox(height: 12),
        ],
        RecordCategoryChips(
          selected: _category,
          counts: state.counts,
          onSelected: (category) => setState(() => _category = category),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: Motion.normal,
          reverseDuration: Motion.normalExit,
          switchInCurve: Motion.enterCurve,
          switchOutCurve: Motion.exitCurveReversed,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.topStart,
            children: [...previous, ?current],
          ),
          child: KeyedSubtree(key: ValueKey((_category, state.loading, state.items.isEmpty)), child: body),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, List<MedicalRecordView> records, {bool skeleton = false}) => LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          // Two cards a row even on a small phone; up to four on desktop.
          final columns = constraints.maxWidth < 300 ? 1 : (constraints.maxWidth / 200).floor().clamp(2, 4);
          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final (i, record) in records.indexed)
                SizedBox(
                  width: width,
                  child: skeleton
                      ? RecordCard(record: record, onTap: null)
                      : StaggeredEntrance(
                          index: i,
                          child: ContainerTransform<bool>(
                            tappable: false,
                            closedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
                            onClosed: (_) {
                              if (mounted) recordsChanged(ref);
                            },
                            closedBuilder: (context, open) =>
                                RecordCard(record: record, onTap: open, showRecorder: widget.clinic.isDoctor),
                            openBuilder: (context, close) => RecordViewerScreen(
                              patientId: widget.patientId,
                              recordId: record.recordId,
                              initial: record,
                              onClose: (changed) => close(returnValue: changed),
                            ),
                          ),
                        ),
                ),
            ],
          );
        },
      );

  MedicalRecordView _placeholder(int i) => MedicalRecordView(
        recordId: 'placeholder-$i',
        patientId: widget.patientId,
        category: RecordCategory.lab,
        title: '——————————',
        documentDate: DateTime.utc(2026),
        source: RecordSource.upload,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        createdBy: const RecordCreator(userId: '', isAssistant: false, name: ''),
        attachments: const [],
        totalSizeBytes: 1000,
      );
}
