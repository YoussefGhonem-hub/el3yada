import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/platform/app_platform.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../clinic_admin/presentation/widgets/clinic_admin_widgets.dart' show ClinicPage;
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/records_providers.dart';
import '../application/upload_controller.dart';
import '../data/file_prep.dart';
import '../data/file_sources.dart';
import '../domain/record_models.dart';
import 'record_form.dart';
import 'record_text.dart';
import 'record_widgets.dart';
import 'scan_review_screen.dart';

/// D10 scan and D11 upload (AS6): files come from the picker, the camera,
/// the photos, the scanner (one PDF) or a drop on the window; each is made
/// smaller and uploaded at once with its own progress bar and Retry
/// (AC-14), while the doctor fills in the details. Save claims the uploads.
class UploadRecordScreen extends ConsumerWidget {
  const UploadRecordScreen({super.key, required this.patientId, this.scan = false, this.initialFiles = const []});

  final String patientId;

  /// D10: open the scanner first.
  final bool scan;

  /// Files dropped on the Files tab.
  final List<UploadSource> initialFiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.filesManage)) {
            return AdminErrorView(error: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.permissionDenied));
          }
          if (clinic.isSuspended) return SuspendedNotice(backFallback: paths.patient(patientId));
          return _UploadForm(patientId: patientId, clinic: clinic, scan: scan, initialFiles: initialFiles);
        },
      ),
    );
  }
}

class _UploadForm extends ConsumerStatefulWidget {
  const _UploadForm({required this.patientId, required this.clinic, required this.scan, required this.initialFiles});

  final String patientId;
  final ClinicContext clinic;
  final bool scan;
  final List<UploadSource> initialFiles;

  @override
  ConsumerState<_UploadForm> createState() => _UploadFormState();
}

class _UploadFormState extends ConsumerState<_UploadForm> {
  final _form = GlobalKey<RecordFormState>();
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _fieldErrors = const {};
  String? _error;
  int _failures = 0;
  bool _scanned = false;
  bool _buildingPdf = false;
  bool _dragging = false;

  int get _maxMb => widget.clinic.limits.maxUploadMb;
  int get _maxBytes => _maxMb * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialFiles.isNotEmpty) _add(widget.initialFiles);
      if (widget.scan) _scan();
    });
  }

  void _add(List<UploadSource> files) {
    if (files.isEmpty) return;
    setState(() => _error = null);
    ref.read(uploadControllerProvider.notifier).add(files, maxBytes: _maxBytes);
  }

  Future<void> _pick(Future<List<UploadSource>> Function(FileSources sources) pick) async {
    try {
      _add(await pick(ref.read(fileSourcesProvider)));
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).errorUnknown);
    }
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context);
    final sources = ref.read(fileSourcesProvider);
    List<Uint8List>? pages;
    try {
      pages = await sources.scan();
    } on ScanException catch (error) {
      if (mounted) showAdminSnack(context, error.denied ? l10n.recordScanDenied : l10n.recordScanUnavailable, error: true);
      return;
    } catch (_) {
      if (mounted) showAdminSnack(context, l10n.recordScanFailed, error: true);
      return;
    }
    if (pages == null || pages.isEmpty || !mounted) return;
    final reviewed = await Navigator.of(context).push<List<Uint8List>>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => ScanReviewScreen(pages: pages!)),
    );
    if (reviewed == null || reviewed.isEmpty || !mounted) return;
    setState(() => _buildingPdf = true);
    try {
      final scan = await ref.read(uploadPrepProvider).scanPdf(reviewed);
      if (!mounted) return;
      _scanned = true;
      final stamp = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      _add([
        UploadSource(
          name: 'scan-${stamp.year}${two(stamp.month)}${two(stamp.day)}-${two(stamp.hour)}${two(stamp.minute)}.pdf',
          bytes: scan.pdf,
          sizeBytes: scan.pdf.length,
          mimeType: 'application/pdf',
          thumbnail: scan.thumbnail,
          pageCount: scan.pageCount,
        ),
      ]);
    } catch (_) {
      if (mounted) showAdminSnack(context, l10n.recordScanFailed, error: true);
    } finally {
      if (mounted) setState(() => _buildingPdf = false);
    }
  }

  Future<void> _dropped(DropDoneDetails details) async {
    setState(() => _dragging = false);
    _add(await ref.read(fileSourcesProvider).fromXFiles(details.files));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final draft = _form.currentState?.validate();
    final upload = ref.read(uploadControllerProvider);
    if (draft == null) {
      setState(() => _failures++);
      return;
    }
    if (upload.isEmpty) {
      setState(() {
        _error = l10n.recordNeedFiles;
        _failures++;
      });
      return;
    }
    if (!upload.ready) {
      setState(() {
        _error = l10n.recordWaitForUploads;
        _failures++;
      });
      return;
    }
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(uploadControllerProvider.notifier).save(
            widget.patientId,
            draft,
            source: _scanned || widget.scan ? RecordSource.scan : RecordSource.upload,
          );
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      recordsChanged(ref);
      showAdminSnack(context, l10n.recordSaved);
      await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(ref.read(clinicPathsProvider).patient(widget.patientId));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _failures++;
        _fieldErrors = recordFieldErrors(l10n, error.fieldCodes);
        _error = _fieldErrors.isEmpty || error.fieldCodes.containsKey('uploadIds') ? l10n.recordError(error) : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final desktop = ref.watch(appPlatformProvider).isDesktop;
    final upload = ref.watch(uploadControllerProvider);
    final controller = ref.read(uploadControllerProvider.notifier);
    final theme = Theme.of(context);

    final sources = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _pick((s) => s.pickFiles()),
          icon: const Icon(Icons.attach_file),
          label: Text(l10n.recordFromFiles),
        ),
        if (!desktop) ...[
          OutlinedButton.icon(
            onPressed: _buildingPdf ? null : _scan,
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(l10n.recordScan),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick((s) async => [?await s.camera()]),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l10n.recordFromCamera),
          ),
          OutlinedButton.icon(
            onPressed: () => _pick((s) => s.gallery()),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.recordFromGallery),
          ),
        ],
      ],
    );

    final filesCard = SectionCard(
      title: l10n.recordFilesHeading,
      icon: Icons.folder_open_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sources,
          const SizedBox(height: 12),
          if (desktop)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l10n.recordDropHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          if (_buildingPdf)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text(l10n.recordScanBuilding),
                ],
              ),
            ),
          if (upload.isEmpty && !_buildingPdf)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.recordNoFilesYet, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          SmoothSize(
            child: Column(
              children: [
                for (final item in upload.items)
                  UploadItemRow(
                    key: ValueKey(item.key),
                    item: item,
                    maxMb: _maxMb,
                    onRetry: () => controller.retry(item.key, maxBytes: _maxBytes),
                    onRemove: _status == SubmitStatus.idle ? () => controller.remove(item.key) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final formCard = SectionCard(
      title: l10n.recordDetailsHeading,
      icon: Icons.edit_note_outlined,
      child: RecordForm(key: _form, patientId: widget.patientId, fieldErrors: _fieldErrors, enabled: _status == SubmitStatus.idle),
    );

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ),
        ShakeOnError(
          trigger: _failures,
          child: SubmitButton(label: l10n.recordSave, status: _status, onPressed: _save),
        ),
      ],
    );

    final page = ClinicPage(
      builder: (context, width) => [
        ClinicHeader(
          title: widget.scan ? l10n.recordScanTitle : l10n.recordUploadTitle,
          backFallback: paths.patient(widget.patientId),
        ),
        const SizedBox(height: 16),
        if (width >= 840)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: filesCard),
              const SizedBox(width: 16),
              Expanded(child: formCard),
            ],
          )
        else ...[
          filesCard,
          const SizedBox(height: 16),
          formCard,
        ],
        const SizedBox(height: 16),
        footer,
      ],
    );

    if (!desktop) return page;
    final scheme = theme.colorScheme;
    return DropTarget(
      enable: ModalRoute.of(context)?.isCurrent ?? true,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _dropped,
      child: Stack(
        children: [
          page,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _dragging ? 1 : 0,
                duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
                child: ColoredBox(
                  color: scheme.primaryContainer.withValues(alpha: 0.9),
                  child: Center(
                    child: Text(l10n.recordDropHint, style: theme.textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
