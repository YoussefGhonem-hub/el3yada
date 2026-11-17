import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../patients/presentation/widgets/clinic_ui.dart' show showAdminSnack;
import '../data/file_sources.dart';

/// D10 review step: the scanned pages as thumbnails, to reorder (drag, or
/// the earlier and later buttons), delete, or add more; then one PDF
/// (BR-F6). Pops with the pages in order, or null when closed.
class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({super.key, required this.pages});

  final List<Uint8List> pages;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  late final List<(int, Uint8List)> _pages = [for (final (i, page) in widget.pages.indexed) (i, page)];
  late int _nextKey = widget.pages.length;
  bool _scanning = false;

  void _move(int from, int to) {
    if (to < 0 || to >= _pages.length) return;
    setState(() => _pages.insert(to, _pages.removeAt(from)));
  }

  Future<void> _scanMore() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _scanning = true);
    try {
      final more = await ref.read(fileSourcesProvider).scan();
      if (more != null && mounted) setState(() => _pages.addAll([for (final page in more) (_nextKey++, page)]));
    } on ScanException catch (error) {
      if (mounted) showAdminSnack(context, error.denied ? l10n.recordScanDenied : l10n.recordScanUnavailable, error: true);
    } catch (_) {
      if (mounted) showAdminSnack(context, l10n.recordScanFailed, error: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recordScanReviewTitle),
        actions: [
          TextButton.icon(
            onPressed: _scanning ? null : _scanMore,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(l10n.recordScanAddPages),
          ),
        ],
      ),
      body: _pages.isEmpty
          ? Center(child: Text(l10n.recordNoFilesYet, style: theme.textTheme.bodyLarge))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _pages.length,
              onReorderItem: _move,
              itemBuilder: (context, i) {
                final (key, bytes) = _pages[i];
                return Card(
                  key: ValueKey(key),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(bytes, width: 72, height: 96, fit: BoxFit.cover, cacheWidth: 216),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(l10n.recordScanPage(i + 1), style: theme.textTheme.titleMedium)),
                        IconButton(
                          tooltip: l10n.recordScanMoveEarlier,
                          onPressed: i > 0 ? () => _move(i, i - 1) : null,
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: l10n.recordScanMoveLater,
                          onPressed: i < _pages.length - 1 ? () => _move(i, i + 1) : null,
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: l10n.recordScanDeletePage,
                          onPressed: () => setState(() => _pages.removeAt(i)),
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: AnimatedScale(
        scale: _pages.isEmpty ? 0 : 1,
        duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
        curve: Motion.spring,
        child: FloatingActionButton.extended(
          onPressed: _pages.isEmpty ? null : () => Navigator.of(context).pop([for (final (_, page) in _pages) page]),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.recordScanMakePdf),
        ),
      ),
    );
  }
}
