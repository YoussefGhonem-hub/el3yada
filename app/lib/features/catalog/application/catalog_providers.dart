import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:catalog_core/catalog_core.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/settings/app_settings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';
import '../../clinic/application/clinic_providers.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../data/admin_catalog_repository.dart';
import '../data/catalog_api.dart';
import '../data/catalog_db.dart';
import '../data/catalog_files.dart';
import '../data/catalog_reader.dart';
import '../data/fake_catalog_backend.dart';
import '../data/local_catalog_search.dart';
import '../domain/catalog_models.dart';
import '../domain/catalog_search.dart';

/// The offline catalog server, shared by the device API and AD19/AD20 for
/// the whole app run (`USE_FAKE_AUTH`).
final fakeCatalogBackendProvider = Provider<FakeCatalogBackend>((ref) => FakeCatalogBackend());

/// The device endpoints: real API, or the offline server.
final catalogApiProvider = Provider<CatalogApi>(
  (ref) =>
      Env.useFakeAuth ? FakeCatalogApi(ref.watch(fakeCatalogBackendProvider)) : ApiCatalogApi(ref.watch(dioProvider)),
);

/// AD19 and AD20: real API, or the offline server.
final adminCatalogRepositoryProvider = Provider<AdminCatalogRepository>((ref) {
  if (!Env.useFakeAuth) return ApiAdminCatalogRepository(ref.watch(dioProvider));
  return FakeAdminCatalogRepository(
    ref.watch(fakeCatalogBackendProvider),
    adminName: ref.read(authControllerProvider).value?.displayName ?? 'Admin',
  );
});

/// The catalog folder in the app's support directory (not backed up, not
/// visible to the user). The offline mode keeps its own.
final catalogFilesProvider = FutureProvider<CatalogFiles>((ref) async {
  final base = await getApplicationSupportDirectory();
  final name = Env.useFakeAuth ? 'catalog-offline' : 'catalog';
  final directory = Directory('${base.path}${Platform.pathSeparator}$name');
  await directory.create(recursive: true);
  return CatalogFiles(directory);
});

/// The read-only connection, in its background isolate.
final catalogDbProvider = Provider<CatalogDb>((ref) {
  final db = IsolateCatalogDb();
  ref.onDispose(db.dispose);
  return db;
});

/// Where sha256, gunzip and the schema check run (an isolate).
final catalogBackgroundRunnerProvider = Provider<BackgroundRunner>((ref) => runInIsolate);

/// Who keeps the catalog on this device (BR-CAT11): admins, doctors whose
/// clinic is open, and assistants with `prescriptionsDraft`. Never patients.
final catalogEligibleProvider = Provider<bool>((ref) {
  final session = ref.watch(authControllerProvider.select((auth) => auth.value));
  if (session == null || session.mustChangePassword || session.trialEnded || session.isPendingDeletion) return false;
  return switch (session.role) {
    UserRole.admin => true,
    UserRole.patient => false,
    UserRole.doctor => session.doctorStatus == DoctorStatus.active || session.doctorStatus == DoctorStatus.suspended,
    UserRole.assistant =>
      ref.watch(clinicContextProvider.select((c) => c.value?.can(ClinicPermission.prescriptionsDraft))) ?? false,
  };
});

/// Where the catalog is on this device (D0).
enum CatalogPhase {
  /// Not started: signed out, a patient, or not allowed.
  idle,

  /// This device has no folder for it; the editors use the history.
  unavailable,

  /// Asking the API for the current version.
  checking,

  /// No version is published yet: free text and history only.
  notPublished,
  downloading,

  /// The download is complete: checking its sha256, unpacking, checking
  /// the schema.
  verifying,
  ready,
  failed,
}

class CatalogState {
  const CatalogState({
    this.phase = CatalogPhase.idle,
    this.installed,
    this.target,
    this.received = 0,
    this.total = 0,
    this.failure,
  });

  final CatalogPhase phase;

  /// The version open for search, or null until the first one is ready.
  final CatalogVersionInfo? installed;

  /// The version being downloaded.
  final CatalogVersionInfo? target;

  /// Bytes of [target]'s `.gz` on the device, of [total].
  final int received;
  final int total;
  final CatalogFailure? failure;

  bool get ready => installed != null;

  bool get busy =>
      phase == CatalogPhase.checking || phase == CatalogPhase.downloading || phase == CatalogPhase.verifying;

  double? get progress => total > 0 ? (received / total).clamp(0, 1).toDouble() : null;

  CatalogState copyWith({CatalogPhase? phase, int? received, CatalogFailure? failure}) => CatalogState(
    phase: phase ?? this.phase,
    installed: installed,
    target: target,
    received: received ?? this.received,
    total: total,
    failure: failure ?? this.failure,
  );
}

/// Keeps the catalog file current (BR-CAT11, BR-CAT12, spec 9.5): opens the
/// one on the device, asks the API for the current version, downloads a new
/// one in the background (resuming after a failure or a restart), checks
/// it, and only then switches the search to it and deletes the old one. A
/// prescription being written is not affected: picked items keep their
/// values.
///
/// Starts when someone who may keep the catalog signs in
/// ([catalogEligibleProvider]); `CatalogSetupHost` keeps it alive.
final catalogControllerProvider = NotifierProvider<CatalogController, CatalogState>(CatalogController.new);

class CatalogController extends Notifier<CatalogState> {
  CancelToken? _cancel;
  Future<void>? _running;
  int _reported = 0;

  @override
  CatalogState build() {
    ref.listen<bool>(catalogEligibleProvider, (previous, eligible) {
      if (eligible && previous != true) {
        Future.microtask(start);
      } else if (!eligible) {
        _cancel?.cancel();
      }
    }, fireImmediately: true);
    ref.onDispose(() => _cancel?.cancel());
    return const CatalogState();
  }

  /// The open catalog, or null until one is ready.
  CatalogDb? get database => state.ready ? ref.read(catalogDbProvider) : null;

  /// Checks for a new version and downloads it. Runs once at a time.
  Future<void> start() => _running ??= _run().whenComplete(() => _running = null);

  /// D0 Retry: resumes the download.
  Future<void> retry() => start();

  Future<void> _run() async {
    if (!ref.read(catalogEligibleProvider)) return;
    final CatalogFiles files;
    try {
      files = await ref.read(catalogFilesProvider.future);
    } on Object {
      if (ref.mounted) state = const CatalogState(phase: CatalogPhase.unavailable);
      return;
    }
    if (!ref.mounted) return;
    final db = ref.read(catalogDbProvider);

    // 1. The version already on the device.
    if (state.installed == null) {
      final installed = await files.readInstalled();
      if (installed != null && ref.mounted) {
        try {
          await db.open(files.database(installed.fileName).path);
          if (!ref.mounted) return;
          state = CatalogState(phase: CatalogPhase.ready, installed: installed.version);
        } on CatalogDbException {
          // Unreadable: download it again.
        }
      }
    }
    if (!ref.mounted) return;
    final installed = state.installed;
    state = CatalogState(phase: installed == null ? CatalogPhase.checking : CatalogPhase.ready, installed: installed);

    // 2. The published version.
    CatalogVersionInfo? remote;
    try {
      remote = await ref.read(catalogApiProvider).current();
    } on ApiException catch (error) {
      if (!ref.mounted) return;
      if (installed != null) {
        state = CatalogState(phase: CatalogPhase.ready, installed: installed);
      } else if (error.status == 401 || error.status == 403) {
        // Not allowed after all (a permission just changed): history only.
        state = const CatalogState(phase: CatalogPhase.idle);
      } else {
        state = CatalogState(
          phase: CatalogPhase.failed,
          failure: error.isNetwork ? CatalogFailure.network : CatalogFailure.server,
        );
      }
      return;
    }
    if (!ref.mounted) return;
    if (remote == null) {
      state = CatalogState(
        phase: installed == null ? CatalogPhase.notPublished : CatalogPhase.ready,
        installed: installed,
      );
      return;
    }
    if (remote.version == installed?.version) {
      unawaited(files.clean(keep: {CatalogFiles.databaseName(remote.version)}));
      return;
    }
    if (remote.schemaVersion != catalogSchemaVersion) {
      // A newer format than this app reads: keep the current one until the
      // app is updated.
      state = CatalogState(
        phase: installed == null ? CatalogPhase.failed : CatalogPhase.ready,
        installed: installed,
        failure: CatalogFailure.schema,
      );
      return;
    }

    // 3. Download and check the new version, in the background.
    final cancel = _cancel = CancelToken();
    _reported = 0;
    state = CatalogState(
      phase: CatalogPhase.downloading,
      installed: installed,
      target: remote,
      total: remote.sizeBytes,
    );
    final downloader = CatalogDownloader(
      api: ref.read(catalogApiProvider),
      files: files,
      run: ref.read(catalogBackgroundRunnerProvider),
    );
    try {
      final file = await downloader.fetch(
        remote,
        cancel: cancel,
        onProgress: _progress,
        onChecking: () {
          if (ref.mounted) state = state.copyWith(phase: CatalogPhase.verifying, received: state.total);
        },
      );
      if (!ref.mounted) return;
      // 4. The atomic swap: the worker opens the new file and then closes
      //    the old one; only then is the old one deleted.
      await db.open(file.path);
      final name = CatalogFiles.databaseName(remote.version);
      await files.writeInstalled(InstalledCatalog(version: remote, fileName: name));
      if (ref.mounted) state = CatalogState(phase: CatalogPhase.ready, installed: remote);
      await files.clean(keep: {name});
    } on CatalogDownloadException catch (error) {
      if (ref.mounted) state = state.copyWith(phase: CatalogPhase.failed, failure: error.failure);
    } on CatalogDbException {
      if (ref.mounted) state = state.copyWith(phase: CatalogPhase.failed, failure: CatalogFailure.corrupt);
      await files.clean(keep: {?installed == null ? null : CatalogFiles.databaseName(installed.version)});
    } on FileSystemException {
      if (ref.mounted) state = state.copyWith(phase: CatalogPhase.failed, failure: CatalogFailure.storage);
    } finally {
      if (identical(_cancel, cancel)) _cancel = null;
    }
  }

  /// About every 0.5% (a 7 MB file gives a few hundred chunks).
  void _progress(int received, int total) {
    if (!ref.mounted) return;
    if (received < total && received - _reported < total ~/ 200) return;
    _reported = received;
    state = state.copyWith(received: received);
  }
}

/// The admin's custom items (BR-CAT9), synced with
/// `GET /api/catalog/customItems?since=` at start and then every minute
/// while the app is in the foreground (AC-18), and kept on the device so they
/// work offline. Inactive items are removed. Keyed by `customItemId`.
final customItemsProvider = NotifierProvider<CustomItemsController, Map<String, CustomCatalogItem>>(
  CustomItemsController.new,
);

class CustomItemsController extends Notifier<Map<String, CustomCatalogItem>> {
  static const interval = Duration(minutes: 1);

  static String get _key => Env.useFakeAuth ? 'catalog.customItems.offline' : 'catalog.customItems';

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  String? _since;
  Future<void>? _syncing;
  bool _foreground = true;

  @override
  Map<String, CustomCatalogItem> build() {
    ref.listen<bool>(catalogEligibleProvider, (previous, eligible) {
      if (eligible) {
        _lifecycle ??= AppLifecycleListener(onStateChange: _onLifecycle);
        _schedule();
        Future.microtask(sync);
      } else {
        _timer?.cancel();
        _timer = null;
      }
    }, fireImmediately: true);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
    });
    return _load();
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    final foreground = lifecycle == AppLifecycleState.resumed || lifecycle == AppLifecycleState.inactive;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground && ref.read(catalogEligibleProvider)) {
      _schedule();
      sync();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => sync());
  }

  /// Asks for the changes since the last sync. Offline: keeps what it has.
  Future<void> sync() => _syncing ??= _sync().whenComplete(() => _syncing = null);

  Future<void> _sync() async {
    if (!ref.read(catalogEligibleProvider)) return;
    final api = ref.read(catalogApiProvider);
    final items = Map.of(state);
    var since = _since;
    var changed = false;
    try {
      for (var page = 0; page < 50; page++) {
        final result = await api.customItems(since: since);
        for (final item in result.items) {
          changed = true;
          if (item.active) {
            items[item.customItemId] = item;
          } else {
            items.remove(item.customItemId);
          }
        }
        since = result.nextSince ?? since;
        if (!result.hasMore) break;
      }
    } on ApiException {
      // Offline, or not allowed now: try again at the next tick.
      return;
    }
    if (!ref.mounted) return;
    _since = since;
    if (changed) state = items;
    await _save(items, since);
  }

  Map<String, CustomCatalogItem> _load() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const {};
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _since = json['since'] as String?;
      return {
        for (final row in (json['items'] as List?) ?? const [])
          if (CustomCatalogItem.fromJson((row as Map).cast<String, dynamic>()) case final item when item.active)
            item.customItemId: item,
      };
    } on Object {
      return const {};
    }
  }

  Future<void> _save(Map<String, CustomCatalogItem> items, String? since) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode({
            'since': since,
            'items': [for (final item in items.values) item.toJson()],
          }),
        );
  }
}

/// The signed-in doctor's (or assistant's doctor's) specialty profile
/// merged with General (`GET /api/catalog/myProfile`, BR-CAT4). Kept on the
/// device for offline search; fetched again at each sign-in and when it is
/// older than [MyCatalogProfileController.maxAge]. Empty for admins.
final myCatalogProfileProvider = NotifierProvider<MyCatalogProfileController, CatalogProfile>(
  MyCatalogProfileController.new,
);

class MyCatalogProfileController extends Notifier<CatalogProfile> {
  static const maxAge = Duration(hours: 6);

  DateTime? _fetchedAt;
  String? _key;
  Future<void>? _refreshing;
  AppLifecycleListener? _lifecycle;

  @override
  CatalogProfile build() {
    final session = ref.watch(authControllerProvider.select((auth) => auth.value));
    final eligible = ref.watch(catalogEligibleProvider);
    ref.onDispose(() => _lifecycle?.dispose());
    _lifecycle = null;
    _fetchedAt = null;
    if (session == null || !eligible || session.role == UserRole.admin) {
      _key = null;
      return CatalogProfile.empty;
    }
    _key = 'catalog.profile${Env.useFakeAuth ? '.offline' : ''}.${session.userId}';
    _lifecycle = AppLifecycleListener(onResume: refreshIfStale);
    final cached = _load();
    // A sign-in (or a new account) always asks again.
    Future.microtask(refresh);
    return cached;
  }

  /// When the profile is older than [maxAge] (the editors call this).
  void refreshIfStale() {
    final fetched = _fetchedAt;
    if (_key != null && (fetched == null || DateTime.now().difference(fetched) > maxAge)) refresh();
  }

  Future<void> refresh() => _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    final key = _key;
    if (key == null) return;
    try {
      final profile = await ref.read(catalogApiProvider).myProfile();
      if (!ref.mounted || key != _key) return;
      _fetchedAt = DateTime.now();
      state = profile;
      await ref
          .read(sharedPreferencesProvider)
          .setString(
            key,
            jsonEncode({'fetchedAt': _fetchedAt!.toUtc().toIso8601String(), 'profile': profile.toJson()}),
          );
    } on ApiException {
      // Offline: the cached one ranks the search.
    }
  }

  CatalogProfile _load() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key!);
    if (raw == null) return CatalogProfile.empty;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _fetchedAt = DateTime.tryParse('${json['fetchedAt']}');
      return CatalogProfile.fromJson((json['profile'] as Map).cast<String, dynamic>());
    } on Object {
      return CatalogProfile.empty;
    }
  }
}

/// Lookups in the open catalog (AD19's lists), or null until it is ready.
final catalogReaderProvider = Provider<CatalogReader?>((ref) {
  final ready = ref.watch(catalogControllerProvider.select((s) => s.installed?.version));
  return ready == null ? null : CatalogReader(ref.read(catalogDbProvider));
});

/// The editors' search (D13, D14) over the local catalog, with [history]
/// for "Used before" (BR-CAT4): what `catalogSearchProvider` answers once
/// the catalog file is open.
CatalogSearch localCatalogSearch(Ref ref, CatalogSearch history) {
  // Keep the catalog, the custom items and the profile alive with the search.
  ref.watch(catalogControllerProvider.select((s) => s.installed?.version));
  ref.listen(customItemsProvider, (_, _) {});
  ref.listen(myCatalogProfileProvider, (_, _) {});
  return LocalCatalogSearch(
    history: history,
    database: () => ref.read(catalogControllerProvider.notifier).database,
    profile: () {
      ref.read(myCatalogProfileProvider.notifier).refreshIfStale();
      return ref.read(myCatalogProfileProvider);
    },
    customItems: () => ref.read(customItemsProvider).values,
  );
}

/// A search without "Used before" (AD19's preview, the admin's own search).
class NoHistorySearch implements CatalogSearch {
  const NoHistorySearch();

  @override
  Future<CatalogHits<DrugHit>> drugs(String query, {bool mySpecialtyOnly = false, int limit = 30}) async =>
      const CatalogHits();

  @override
  Future<CatalogHits<TestHit>> tests(
    String query, {
    String? category,
    bool mySpecialtyOnly = false,
    int limit = 30,
  }) async => const CatalogHits();
}
