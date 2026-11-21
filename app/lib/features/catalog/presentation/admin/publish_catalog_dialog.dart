import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart' show CancelToken;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/success_check.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/admin_catalog_providers.dart';
import '../../application/catalog_providers.dart';
import '../../data/admin_catalog_repository.dart';
import '../../domain/catalog_models.dart';
import '../catalog_text.dart';

/// AD20 "Publish new version": pick the builder's `catalog-v<n>.sqlite.gz`
/// (its manifest `catalog-v<n>.json` is read from the same folder, or
/// picked), check the sha256 here, upload with progress, and show the
/// server's check. A table more than 5% smaller (409 `CATALOG_COUNT_DROP`)
/// asks before sending again with `confirmDrop`.
Future<void> showPublishCatalogDialog(BuildContext context) =>
    showDialog<void>(context: context, barrierDismissible: false, builder: (context) => const _PublishDialog());

enum _Check { none, checking, matches, mismatch, badManifest }

enum _Step { pick, uploading, serverCheck, countDrop, done }

class _PublishDialog extends ConsumerStatefulWidget {
  const _PublishDialog();

  @override
  ConsumerState<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends ConsumerState<_PublishDialog> {
  PickedCatalogFile? _file;
  String? _manifest;
  String? _manifestName;
  _Check _check = _Check.none;
  _Step _step = _Step.pick;
  int _sent = 0;
  int _total = 0;
  String? _error;
  List<({String table, int previous, int current})> _drops = const [];
  CatalogVersionInfo? _published;
  CancelToken? _cancel;

  CatalogFilePicker get _picker => ref.read(catalogFilePickerProvider);

  Future<void> _pickFile() async {
    final picked = await _picker.pickCatalog();
    if (!mounted || picked.isEmpty) return;
    final gz = picked.where((f) => f.name.toLowerCase().endsWith('.gz')).firstOrNull;
    final json = picked.where((f) => f.name.toLowerCase().endsWith('.json')).firstOrNull;
    setState(() {
      _error = null;
      if (gz != null) _file = gz;
    });
    if (json != null) {
      await _useManifest(json.name, await _picker.readText(json));
    } else if (gz != null) {
      // The builder writes catalog-v<n>.json next to catalog-v<n>.sqlite.gz.
      final name = gz.name.replaceFirst(RegExp(r'\.sqlite\.gz$', caseSensitive: false), '.json');
      final sibling = name == gz.name ? null : await _picker.readSibling(gz, name);
      if (sibling != null) {
        await _useManifest(name, sibling);
      } else {
        await _verify();
      }
    }
  }

  Future<void> _pickManifest() async {
    final picked = await _picker.pickManifest();
    if (!mounted || picked == null) return;
    await _useManifest(picked.name, await _picker.readText(picked));
  }

  Future<void> _useManifest(String name, String text) async {
    if (!mounted) return;
    setState(() {
      _manifestName = name;
      _manifest = text;
      _error = null;
    });
    await _verify();
  }

  /// The sha256 of the picked file against the manifest's, before uploading.
  Future<void> _verify() async {
    final file = _file;
    final manifest = _manifest;
    if (file == null || manifest == null) return;
    String? expected;
    try {
      final json = jsonDecode(manifest);
      if (json is Map && json['sha256'] is String) expected = (json['sha256'] as String).trim().toLowerCase();
    } on FormatException {
      expected = null;
    }
    if (expected == null || expected.length != 64) {
      setState(() => _check = _Check.badManifest);
      return;
    }
    setState(() => _check = _Check.checking);
    final run = ref.read(catalogBackgroundRunnerProvider);
    final path = file.path;
    final bytes = file.bytes;
    final actual = await run(path != null ? _shaOfPath(path) : _shaOfBytes(bytes ?? Uint8List(0)));
    if (!mounted || !identical(file, _file)) return;
    setState(() => _check = actual == expected ? _Check.matches : _Check.mismatch);
  }

  Future<void> _publish({bool confirmDrop = false}) async {
    final l10n = AppLocalizations.of(context);
    final file = _file!;
    final cancel = _cancel = CancelToken();
    setState(() {
      _step = _Step.uploading;
      _error = null;
      _sent = 0;
      _total = file.sizeBytes;
    });
    try {
      final published = await ref
          .read(adminCatalogRepositoryProvider)
          .publish(
            file: file,
            manifest: _manifest!,
            confirmDrop: confirmDrop,
            cancel: cancel,
            onProgress: (sent, total) {
              if (!mounted) return;
              setState(() {
                _sent = sent;
                _total = total > 0 ? total : _total;
                if (_total > 0 && sent >= _total) _step = _Step.serverCheck;
              });
            },
          );
      if (!mounted) return;
      ref.invalidate(catalogVersionsProvider);
      // This admin's device downloads it too (AD19 reads the local copy).
      ref.read(catalogControllerProvider.notifier).start().ignore();
      setState(() {
        _published = published;
        _step = _Step.done;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.kind == ApiErrorKind.cancelled) {
        setState(() => _step = _Step.pick);
        return;
      }
      if (error.status == 409 && error.code == 'CATALOG_COUNT_DROP') {
        setState(() {
          _drops = [
            for (final row in (error.details['drops'] as List?) ?? const [])
              if (row is Map)
                (
                  table: '${row['table']}',
                  previous: (row['previous'] as num?)?.toInt() ?? 0,
                  current: (row['current'] as num?)?.toInt() ?? 0,
                ),
          ];
          _step = _Step.countDrop;
        });
        return;
      }
      setState(() {
        _step = _Step.pick;
        _error = l10n.catalogPublishError(error);
      });
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  String _tableName(AppLocalizations l10n, String table) => switch (table) {
    'drugs' => l10n.catalogTypeDrugs,
    'labs' => l10n.catalogTypeLabs,
    _ => l10n.catalogTypeRadiologyPlural,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _step == _Step.uploading || _step == _Step.serverCheck;
    final canPublish = _step == _Step.pick && _file != null && _manifest != null && _check == _Check.matches;
    final count = NumberFormat('#,##0', 'en');

    Widget body;
    if (_step == _Step.done) {
      final v = _published!;
      body = Column(
        key: const ValueKey('done'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: SuccessCheck(size: 72)),
          const SizedBox(height: 12),
          Text(
            l10n.adminCatalogPublished('${v.version}'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.adminCatalogCounts(
              count.format(v.counts.drugs),
              count.format(v.counts.labs),
              count.format(v.counts.radiology),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.adminCatalogPublishedBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.done)),
        ],
      );
    } else {
      body = Column(
        key: const ValueKey('form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(l10n.adminCatalogPublishTitle, style: theme.textTheme.headlineSmall)),
          const SizedBox(height: 8),
          Text(
            l10n.adminCatalogPublishBody,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          _FileRow(
            icon: Icons.inventory_2_outlined,
            label: _file == null ? l10n.adminCatalogNoFile : '${_file!.name} · ${l10n.catalogSize(_file!.sizeBytes)}',
            button: l10n.adminCatalogPickFile,
            onPressed: busy ? null : _pickFile,
          ),
          const SizedBox(height: 10),
          _FileRow(
            icon: Icons.data_object,
            label: _manifestName ?? l10n.adminCatalogNoManifest,
            button: l10n.adminCatalogPickManifest,
            onPressed: busy ? null : _pickManifest,
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: Motion.normal,
            child: switch (_check) {
              _Check.none => const SizedBox.shrink(),
              _Check.checking => _Line(
                key: const ValueKey('checking'),
                icon: Icons.hourglass_top,
                text: l10n.adminCatalogChecking,
                color: scheme.onSurfaceVariant,
              ),
              _Check.matches => _Line(
                key: const ValueKey('ok'),
                icon: Icons.verified_outlined,
                text: l10n.adminCatalogShaMatches,
                color: scheme.primary,
              ),
              _Check.mismatch => _Line(
                key: const ValueKey('bad'),
                icon: Icons.error_outline,
                text: l10n.catalogErrorShaMismatch,
                color: scheme.error,
              ),
              _Check.badManifest => _Line(
                key: const ValueKey('manifest'),
                icon: Icons.error_outline,
                text: l10n.catalogErrorManifest,
                color: scheme.error,
              ),
            },
          ),
          if (busy) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: _step == _Step.serverCheck || _total == 0 ? null : (_sent / _total).clamp(0, 1),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _step == _Step.serverCheck
                    ? l10n.adminCatalogServerChecking
                    : l10n.adminCatalogUploading(l10n.catalogSize(_sent), l10n.catalogSize(_total)),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
          if (_step == _Step.countDrop) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.adminCatalogDropTitle,
                    style: theme.textTheme.titleSmall?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                  const SizedBox(height: 8),
                  for (final drop in _drops)
                    Text(
                      l10n.adminCatalogDropRow(
                        _tableName(l10n, drop.table),
                        count.format(drop.previous),
                        count.format(drop.current),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.adminCatalogDropBody,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  if (busy) {
                    _cancel?.cancel();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(l10n.adminCancel),
              ),
              if (_step == _Step.countDrop)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                  onPressed: () => _publish(confirmDrop: true),
                  child: Text(l10n.adminCatalogPublishAnyway),
                )
              else
                FilledButton.icon(
                  onPressed: canPublish ? _publish : null,
                  icon: const Icon(Icons.publish_outlined),
                  label: Text(l10n.adminCatalogPublish),
                ),
            ],
          ),
        ],
      );
    }

    return PopScope(
      canPop: !busy,
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AnimatedSize(
              duration: Motion.normal,
              curve: Motion.standardCurve,
              child: AnimatedSwitcher(duration: Motion.normal, child: body),
            ),
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.icon, required this.label, required this.button, required this.onPressed});

  final IconData icon;
  final String label;
  final String button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onPressed, child: Text(button)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({super.key, required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
        ),
      ],
    ),
  );
}

// Work for the background runner: closures that capture only sendable data.
Future<String> Function() _shaOfPath(String path) =>
    () async => (await crypto.sha256.bind(File(path).openRead()).first).toString();

Future<String> Function() _shaOfBytes(Uint8List bytes) =>
    () async => crypto.sha256.convert(bytes).toString();
