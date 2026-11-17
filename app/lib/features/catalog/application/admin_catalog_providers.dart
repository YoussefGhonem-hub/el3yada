import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_catalog_repository.dart';
import '../data/catalog_reader.dart';
import '../domain/catalog_models.dart';
import 'catalog_providers.dart';

/// AD20: every published version, newest first.
final catalogVersionsProvider = FutureProvider.autoDispose<List<CatalogVersionEntry>>(
  (ref) => ref.watch(adminCatalogRepositoryProvider).versions(),
);

/// What AD20's custom items list shows.
typedef CustomItemFilter = ({CatalogItemType? type, bool showDisabled, String search});

/// AD20: the custom items (BR-CAT9), newest change first.
final adminCustomItemsProvider = FutureProvider.autoDispose.family<List<CustomCatalogItem>, CustomItemFilter>(
  (ref, filter) async =>
      (await ref
              .watch(adminCatalogRepositoryProvider)
              .customItems(
                type: filter.type,
                active: filter.showDisabled ? null : true,
                search: filter.search,
                pageSize: 100,
              ))
          .items,
);

/// AD20 [S]: doctor reports; [status] is `open`, `done` or `all`.
final catalogReportsProvider = FutureProvider.autoDispose.family<List<CatalogReport>, String>(
  (ref, status) async => (await ref.watch(adminCatalogRepositoryProvider).reports(status: status, pageSize: 100)).items,
);

/// AD19: every specialty with its doctors, General first.
final adminSpecialtiesProvider = FutureProvider.autoDispose<List<SpecialtySummary>>(
  (ref) => ref.watch(adminCatalogRepositoryProvider).specialties(),
);

/// AD19's editor: one specialty's profile.
final specialtyProfileProvider = FutureProvider.autoDispose.family<SpecialtyProfile, String>(
  (ref, specialtyId) => ref.watch(adminCatalogRepositoryProvider).profile(specialtyId),
);

/// The lists AD19 picks from, read from the catalog on this device: groups
/// with product counts, routes, regions and modalities.
class CatalogChoices {
  const CatalogChoices({
    this.groups = const [],
    this.routes = const [],
    this.regions = const [],
    this.modalities = const [],
  });

  final List<CatalogValueCount> groups;
  final List<CatalogValueCount> routes;
  final List<CatalogValueCount> regions;
  final List<CatalogValueCount> modalities;
}

/// Null until the catalog is on this device (D0).
final catalogChoicesProvider = FutureProvider.autoDispose<CatalogChoices?>((ref) async {
  final reader = ref.watch(catalogReaderProvider);
  if (reader == null) return null;
  return CatalogChoices(
    groups: await reader.drugGroups(),
    routes: await reader.routes(),
    regions: await reader.radiologyRegions(),
    modalities: await reader.modalities(),
  );
});

/// Picks the builder's files for publishCatalog (AD20).
abstract interface class CatalogFilePicker {
  /// The `.sqlite.gz` (and its manifest, when picked together). Empty when
  /// cancelled.
  Future<List<PickedCatalogFile>> pickCatalog();

  /// The manifest `.json` alone.
  Future<PickedCatalogFile?> pickManifest();

  /// The text of the file next to [file] called [name], when there is one
  /// (desktop: the builder writes `catalog-v<n>.json` beside the `.gz`).
  Future<String?> readSibling(PickedCatalogFile file, String name);

  Future<String> readText(PickedCatalogFile file);
}

class FileSelectorCatalogPicker implements CatalogFilePicker {
  const FileSelectorCatalogPicker();

  static const _catalog = XTypeGroup(
    label: 'Catalog',
    extensions: ['gz', 'json'],
    mimeTypes: ['application/gzip', 'application/x-gzip', 'application/json'],
    uniformTypeIdentifiers: ['org.gnu.gnu-zip-archive', 'public.json'],
  );

  static const _manifest = XTypeGroup(
    label: 'Manifest',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    uniformTypeIdentifiers: ['public.json'],
  );

  @override
  Future<List<PickedCatalogFile>> pickCatalog() async => [
    for (final file in await openFiles(acceptedTypeGroups: const [_catalog])) await _picked(file),
  ];

  @override
  Future<PickedCatalogFile?> pickManifest() async {
    final file = await openFile(acceptedTypeGroups: const [_manifest]);
    return file == null ? null : _picked(file);
  }

  @override
  Future<String?> readSibling(PickedCatalogFile file, String name) async {
    final path = file.path;
    if (path == null) return null;
    final sibling = File('${File(path).parent.path}${Platform.pathSeparator}$name');
    try {
      return await sibling.exists() ? await sibling.readAsString() : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<String> readText(PickedCatalogFile file) async =>
      file.path != null ? File(file.path!).readAsString() : String.fromCharCodes(file.bytes ?? const []);

  static Future<PickedCatalogFile> _picked(XFile file) async {
    final path = file.path;
    // Desktop gives a real path (the upload streams it); phones may not.
    if (path.isNotEmpty && !Platform.isAndroid && !Platform.isIOS && File(path).existsSync()) {
      return PickedCatalogFile(name: file.name, sizeBytes: await file.length(), path: path);
    }
    final bytes = await file.readAsBytes();
    return PickedCatalogFile(name: file.name, sizeBytes: bytes.length, bytes: bytes);
  }
}

final catalogFilePickerProvider = Provider<CatalogFilePicker>((ref) => const FileSelectorCatalogPicker());
