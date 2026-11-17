import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:catalog_core/catalog_core.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart' show CancelToken, DioException;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/network/api_exception.dart';
import '../domain/catalog_models.dart';
import 'catalog_api.dart';

/// The catalog in use on this device, as `state.json` records it.
class InstalledCatalog {
  const InstalledCatalog({required this.version, required this.fileName});

  factory InstalledCatalog.fromJson(Map<String, dynamic> json) => InstalledCatalog(
    version: CatalogVersionInfo.fromJson((json['version'] as Map).cast<String, dynamic>()),
    fileName: json['fileName'] as String,
  );

  final CatalogVersionInfo version;
  final String fileName;

  Map<String, Object?> toJson() => {'version': version.toJson(), 'fileName': fileName};
}

/// The catalog folder (spec 9.5, BR-CAT12):
///
/// * `state.json`: which file is in use;
/// * `catalog-v{n}.sqlite`: the file in use (and, for a moment during a
///   swap, the previous one);
/// * `download-v{n}.gz.part`: a download in progress, kept across restarts
///   so it resumes with an HTTP range request;
/// * `catalog-v{n}.sqlite.tmp`: a download being unpacked and checked.
class CatalogFiles {
  CatalogFiles(this.directory);

  final Directory directory;

  File _file(String name) => File('${directory.path}${Platform.pathSeparator}$name');

  File get _state => _file('state.json');

  File part(int version) => _file('download-v$version.gz.part');

  File unpacking(int version) => _file('catalog-v$version.sqlite.tmp');

  static String databaseName(int version) => 'catalog-v$version.sqlite';

  File database(String fileName) => _file(fileName);

  Future<InstalledCatalog?> readInstalled() async {
    try {
      if (!await _state.exists()) return null;
      final installed = InstalledCatalog.fromJson(jsonDecode(await _state.readAsString()) as Map<String, dynamic>);
      return await database(installed.fileName).exists() ? installed : null;
    } on Object {
      // A broken state file is the same as none: the catalog downloads again.
      return null;
    }
  }

  /// Written to a temporary file and renamed, so a crash never leaves half
  /// a state file.
  Future<void> writeInstalled(InstalledCatalog installed) async {
    final temp = _file('state.json.tmp');
    await temp.writeAsString(jsonEncode(installed.toJson()), flush: true);
    await temp.rename(_state.path);
  }

  /// Deletes what is neither [keep] nor the resumable download of
  /// [resumable]. Files still open (Windows) are left for next time.
  Future<void> clean({required Set<String> keep, int? resumable}) async {
    if (!await directory.exists()) return;
    await for (final entry in directory.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name == 'state.json' || keep.contains(name)) continue;
      if (resumable != null && name == 'download-v$resumable.gz.part') continue;
      await _deleteQuietly(entry);
    }
  }
}

/// Why a catalog could not be downloaded or used (D0 says which).
enum CatalogFailure {
  /// No internet, or the connection dropped: Retry resumes.
  network,

  /// The server failed or refused.
  server,

  /// The file is not the one published (sha256): it is deleted.
  checksum,

  /// Not a gzip-compressed catalog database: it is deleted.
  corrupt,

  /// A catalog format this app version can't read: update the app.
  schema,

  /// The device has no room, or the folder can't be written.
  storage,
}

class CatalogDownloadException implements Exception {
  const CatalogDownloadException(this.failure, {this.cause, this.schemaVersion});

  final CatalogFailure failure;
  final Object? cause;

  /// The file's schema version, for [CatalogFailure.schema].
  final int? schemaVersion;

  @override
  String toString() => 'CatalogDownloadException(${failure.name}${cause == null ? '' : ': $cause'})';
}

/// Runs [work] away from the UI isolate (sha256, gunzip, the schema check).
typedef BackgroundRunner = Future<T> Function<T>(FutureOr<T> Function() work);

Future<T> runInIsolate<T>(FutureOr<T> Function() work) => Isolate.run(work, debugName: 'catalog-file');

Future<T> runInline<T>(FutureOr<T> Function() work) async => work();

/// Downloads one catalog version into a checked database file (D0, spec 9.5):
///
/// 1. Download `download-v{n}.gz.part`, resuming with an HTTP range request
///    after a failure or an app restart.
/// 2. Check its sha256 against the published one.
/// 3. Gunzip it to `catalog-v{n}.sqlite.tmp`.
/// 4. Check `meta.schema_version` and the tables against catalog_core.
/// 5. Rename it to `catalog-v{n}.sqlite`.
///
/// A failed check deletes the partial files; the caller offers Retry. The
/// caller then opens the new file and records it (the atomic swap).
class CatalogDownloader {
  CatalogDownloader({required this.api, required this.files, BackgroundRunner? run}) : _run = run ?? runInIsolate;

  final CatalogApi api;
  final CatalogFiles files;
  final BackgroundRunner _run;

  /// Returns the checked database file. [onProgress] gets the bytes of the
  /// `.gz` received so far; [onChecking] is called when they are all there.
  Future<File> fetch(
    CatalogVersionInfo target, {
    void Function(int received, int total)? onProgress,
    void Function()? onChecking,
    CancelToken? cancel,
  }) async {
    final part = files.part(target.version);
    final total = target.sizeBytes;
    try {
      await files.directory.create(recursive: true);
    } on FileSystemException catch (error) {
      throw CatalogDownloadException(CatalogFailure.storage, cause: error);
    }

    var have = await _lengthOf(part);
    if (total > 0 && have > total) {
      await _deleteQuietly(part);
      have = 0;
    }
    if (total <= 0 || have < total) {
      await _download(target, part, have, total, onProgress, cancel);
    } else {
      onProgress?.call(have, total);
    }

    onChecking?.call();
    final partPath = part.path;
    final String sha;
    try {
      sha = await _run(_sha256Task(partPath));
    } on FileSystemException catch (error) {
      throw CatalogDownloadException(CatalogFailure.storage, cause: error);
    }
    if (sha != target.sha256.toLowerCase()) {
      await _deleteQuietly(part);
      throw CatalogDownloadException(CatalogFailure.checksum, cause: 'sha256 $sha');
    }

    final temp = files.unpacking(target.version);
    final tempPath = temp.path;
    try {
      await _run(_gunzipTask(partPath, tempPath));
    } on FileSystemException catch (error) {
      await _deleteQuietly(temp);
      // No room to unpack: keep the download, it is fine.
      throw CatalogDownloadException(CatalogFailure.storage, cause: error);
    } on Object catch (error) {
      await _deleteQuietly(temp);
      await _deleteQuietly(part);
      throw CatalogDownloadException(CatalogFailure.corrupt, cause: error);
    }

    final schema = await _run(_schemaTask(tempPath));
    if (schema != catalogSchemaVersion) {
      await _deleteQuietly(temp);
      await _deleteQuietly(part);
      throw schema == null
          ? const CatalogDownloadException(CatalogFailure.corrupt, cause: 'not a catalog database')
          : CatalogDownloadException(CatalogFailure.schema, schemaVersion: schema);
    }

    final database = files.database(CatalogFiles.databaseName(target.version));
    try {
      if (await database.exists()) await database.delete();
      await temp.rename(database.path);
    } on FileSystemException catch (error) {
      await _deleteQuietly(temp);
      throw CatalogDownloadException(CatalogFailure.storage, cause: error);
    }
    await _deleteQuietly(part);
    return database;
  }

  Future<void> _download(
    CatalogVersionInfo target,
    File part,
    int have,
    int total,
    void Function(int received, int total)? onProgress,
    CancelToken? cancel,
  ) async {
    IOSink? sink;
    try {
      final response = await api.file(target.version, from: have, ifRange: target.sha256, cancel: cancel);
      // 200 to a range request: the server sends the whole file again.
      final resumed = response.partial && have > 0;
      var received = resumed ? have : 0;
      sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      onProgress?.call(received, total);
      await for (final chunk in response.body) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } on ApiException catch (error) {
      if (error.status == 416) await _deleteQuietly(part);
      throw CatalogDownloadException(
        error.isNetwork || error.kind == ApiErrorKind.cancelled ? CatalogFailure.network : CatalogFailure.server,
        cause: error,
      );
    } on DioException catch (error) {
      throw CatalogDownloadException(CatalogFailure.network, cause: ApiException.fromDio(error));
    } on FileSystemException catch (error) {
      throw CatalogDownloadException(CatalogFailure.storage, cause: error);
    } on IOException catch (error) {
      // The connection dropped mid-way (SocketException, HttpException).
      throw CatalogDownloadException(CatalogFailure.network, cause: error);
    } finally {
      try {
        await sink?.close();
      } on Object {
        // Already reported above.
      }
    }
  }
}

/// `meta.schema_version` of the catalog database at [path], or null when it
/// is not a catalog (no `meta` row, or one of the tables is missing).
int? catalogFileSchemaVersion(String path) {
  final Database db;
  try {
    db = sqlite3.open(path, mode: OpenMode.readOnly);
  } on SqliteException {
    return null;
  }
  try {
    final tables = {
      for (final row in db.select("SELECT name FROM sqlite_master WHERE type IN ('table', 'view')")) row['name'],
    };
    const needed = [
      MetaTable.name,
      DrugsTable.name,
      LabTestsTable.name,
      RadiologyTable.name,
      FtsTables.drugs,
      FtsTables.labs,
      FtsTables.radiology,
    ];
    if (!needed.every(tables.contains)) return null;
    final rows = db.select('SELECT ${MetaTable.schemaVersion} FROM ${MetaTable.name} LIMIT 1');
    return rows.isEmpty ? null : rows.first[MetaTable.schemaVersion] as int?;
  } on SqliteException {
    return null;
  } finally {
    db.close();
  }
}

Future<String> _sha256Of(String path) async {
  final digest = await crypto.sha256.bind(File(path).openRead()).first;
  return digest.toString();
}

Future<void> _gunzip(String from, String to) async {
  await File(from).openRead().transform(gzip.decoder).pipe(File(to).openWrite());
}

Future<int> _lengthOf(File file) async {
  try {
    return await file.exists() ? await file.length() : 0;
  } on FileSystemException {
    return 0;
  }
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // Still open (Windows) or already gone: cleaned up next time.
  }
}

// Work for [BackgroundRunner]: made by top-level functions so the closures
// capture only their paths, which an isolate can receive.
Future<String> Function() _sha256Task(String path) =>
    () => _sha256Of(path);

Future<void> Function() _gunzipTask(String from, String to) =>
    () => _gunzip(from, to);

int? Function() _schemaTask(String path) =>
    () => catalogFileSchemaVersion(path);
