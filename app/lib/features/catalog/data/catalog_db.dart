import 'dart:async';
import 'dart:isolate';

import 'package:catalog_core/catalog_core.dart';
import 'package:sqlite3/sqlite3.dart';

/// A row as column name → value.
typedef CatalogRow = Map<String, Object?>;

/// The downloaded catalog file, opened read-only (spec 9.5, BR-CAT11).
///
/// `package:sqlite3` is synchronous FFI, so the app keeps the connection in a
/// long-lived background isolate ([IsolateCatalogDb]) and the UI never waits
/// on SQLite. Tests use [DirectCatalogDb], which runs the same code in the
/// calling isolate.
abstract interface class CatalogDb {
  /// Opens [path] and then closes the file that was open, so searches
  /// switch to a new version without a gap (BR-CAT12). Throws
  /// [CatalogDbException] when the file can't be opened.
  Future<void> open(String path);

  /// The open file, or null.
  String? get path;

  Future<void> close();

  Future<List<CatalogRow>> select(String sql, [List<Object?> parameters = const []]);

  /// Runs [query] and splits its rows into the two catalog sections of
  /// BR-CAT4 in one pass, keeping the statement's order inside each.
  Future<SectionedRows> sectioned(SectionedQuery query);

  /// Closes the file and stops the isolate.
  Future<void> dispose();
}

class CatalogDbException implements Exception {
  const CatalogDbException(this.message);

  final String message;

  @override
  String toString() => 'CatalogDbException: $message';
}

/// Which rows of a search go under "Your specialty" (BR-CAT4), as the
/// builder's README describes it. Plain data, so it crosses isolates.
sealed class SectionRule {
  const SectionRule();

  bool inSpecialty(CatalogRow row);
}

/// A medicine whose clean group is one of [groups].
final class DrugSectionRule extends SectionRule {
  const DrugSectionRule(this.groups);

  final Set<String> groups;

  @override
  bool inSpecialty(CatalogRow row) => groups.contains(row[DrugsTable.groupId]);
}

/// A lab test whose LOINC code is one of [codes].
final class LabSectionRule extends SectionRule {
  const LabSectionRule(this.codes);

  final Set<String> codes;

  @override
  bool inSpecialty(CatalogRow row) => codes.contains(row[LabTestsTable.loincCode]);
}

/// A radiology procedure whose code is one of [codes], whose region or
/// imaging focus is one of [regions] (the Playbook has no "Spine" region:
/// spine studies are found by focus), or whose modality is one of
/// [modalities]. Several values in a column are joined with ";".
final class RadiologySectionRule extends SectionRule {
  const RadiologySectionRule({required this.codes, required this.regions, required this.modalities});

  final Set<String> codes;
  final Set<String> regions;
  final Set<String> modalities;

  @override
  bool inSpecialty(CatalogRow row) =>
      codes.contains(row[RadiologyTable.loincCode]) ||
      _anyIn(row[RadiologyTable.region], regions) ||
      _anyIn(row[RadiologyTable.focus], regions) ||
      _anyIn(row[RadiologyTable.modality], modalities);

  static bool _anyIn(Object? joined, Set<String> values) {
    if (joined is! String || joined.isEmpty || values.isEmpty) return false;
    return joined.split(';').any((value) => values.contains(value.trim()));
  }
}

/// One search to split into sections (see [CatalogDb.sectioned]).
class SectionedQuery {
  const SectionedQuery({
    required this.sql,
    required this.parameters,
    required this.rule,
    required this.keyColumn,
    required this.specialtyLimit,
    required this.othersLimit,
    this.skip = const {},
  });

  /// One of `CatalogSearchSql`'s statements, with a row limit of -1.
  final String sql;
  final List<Object?> parameters;
  final SectionRule rule;

  /// The column [skip] refers to.
  final String keyColumn;

  /// Rows already shown (the "Used before" section): left out of both.
  final Set<Object> skip;

  /// Rows wanted in each section; 0 for none. Reading stops when both are full.
  final int specialtyLimit;
  final int othersLimit;
}

class SectionedRows {
  const SectionedRows({this.specialty = const [], this.others = const [], this.matched = 0});

  final List<CatalogRow> specialty;
  final List<CatalogRow> others;

  /// Rows read before both sections were full.
  final int matched;
}

/// The SQLite work, shared by [DirectCatalogDb] and [IsolateCatalogDb].
class CatalogDbCore {
  Database? _db;
  String? _path;

  String? get path => _path;

  void open(String path) {
    final Database next;
    try {
      next = sqlite3.open(path, mode: OpenMode.readOnly);
    } on SqliteException catch (error) {
      throw CatalogDbException(error.message);
    }
    _db?.close();
    _db = next;
    _path = path;
  }

  void close() {
    _db?.close();
    _db = null;
    _path = null;
  }

  Database get _open {
    final db = _db;
    if (db == null) throw const CatalogDbException('No catalog is open.');
    return db;
  }

  List<CatalogRow> select(String sql, List<Object?> parameters) {
    try {
      return [for (final row in _open.select(sql, parameters)) Map<String, Object?>.of(row)];
    } on SqliteException catch (error) {
      throw CatalogDbException(error.message);
    }
  }

  SectionedRows sectioned(SectionedQuery query) {
    final specialty = <CatalogRow>[];
    final others = <CatalogRow>[];
    var matched = 0;
    final PreparedStatement statement;
    try {
      statement = _open.prepare(query.sql);
    } on SqliteException catch (error) {
      throw CatalogDbException(error.message);
    }
    try {
      final cursor = statement.selectCursor(query.parameters);
      while ((specialty.length < query.specialtyLimit || others.length < query.othersLimit) && cursor.moveNext()) {
        final row = cursor.current;
        matched++;
        if (query.skip.isNotEmpty && query.skip.contains(row[query.keyColumn])) continue;
        if (query.rule.inSpecialty(row)) {
          if (specialty.length < query.specialtyLimit) specialty.add(Map<String, Object?>.of(row));
        } else if (others.length < query.othersLimit) {
          others.add(Map<String, Object?>.of(row));
        }
      }
    } on SqliteException catch (error) {
      throw CatalogDbException(error.message);
    } finally {
      statement.close();
    }
    return SectionedRows(specialty: specialty, others: others, matched: matched);
  }
}

/// Runs SQLite in the calling isolate: tests, and the screenshot runs.
class DirectCatalogDb implements CatalogDb {
  final _core = CatalogDbCore();

  @override
  String? get path => _core.path;

  @override
  Future<void> open(String path) async => _core.open(path);

  @override
  Future<void> close() async => _core.close();

  @override
  Future<List<CatalogRow>> select(String sql, [List<Object?> parameters = const []]) async =>
      _core.select(sql, parameters);

  @override
  Future<SectionedRows> sectioned(SectionedQuery query) async => _core.sectioned(query);

  @override
  Future<void> dispose() async => _core.close();
}

/// Keeps the read-only connection in one long-lived background isolate, so
/// searches never block a frame. Requests are answered in order.
class IsolateCatalogDb implements CatalogDb {
  Future<SendPort>? _worker;
  Isolate? _isolate;
  ReceivePort? _replies;
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 0;
  String? _path;

  @override
  String? get path => _path;

  Future<SendPort> _start() => _worker ??= () async {
    final replies = ReceivePort('catalog-db-replies');
    _replies = replies;
    final ready = Completer<SendPort>();
    replies.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final (id, result, error) = message as (int, Object?, String?);
      final completer = _pending.remove(id);
      if (completer == null) return;
      if (error != null) {
        completer.completeError(CatalogDbException(error));
      } else {
        completer.complete(result);
      }
    });
    _isolate = await Isolate.spawn(_workerMain, replies.sendPort, debugName: 'catalog-db');
    return ready.future;
  }();

  Future<T> _call<T>(_Command command) async {
    final worker = await _start();
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    worker.send((id, command));
    return (await completer.future) as T;
  }

  @override
  Future<void> open(String path) async {
    await _call<void>(_Open(path));
    _path = path;
  }

  @override
  Future<void> close() async {
    if (_worker == null) return;
    await _call<void>(const _Close());
    _path = null;
  }

  @override
  Future<List<CatalogRow>> select(String sql, [List<Object?> parameters = const []]) async => [
    for (final row in await _call<List<Object?>>(_Select(sql, parameters))) (row as Map).cast<String, Object?>(),
  ];

  @override
  Future<SectionedRows> sectioned(SectionedQuery query) => _call<SectionedRows>(_Sectioned(query));

  @override
  Future<void> dispose() async {
    if (_worker != null) {
      try {
        await close();
      } on Object {
        // Stopping anyway.
      }
    }
    _isolate?.kill(priority: Isolate.immediate);
    _replies?.close();
    _isolate = null;
    _worker = null;
    for (final completer in _pending.values) {
      completer.completeError(const CatalogDbException('The catalog was closed.'));
    }
    _pending.clear();
  }
}

sealed class _Command {
  const _Command();
}

final class _Open extends _Command {
  const _Open(this.path);
  final String path;
}

final class _Close extends _Command {
  const _Close();
}

final class _Select extends _Command {
  const _Select(this.sql, this.parameters);
  final String sql;
  final List<Object?> parameters;
}

final class _Sectioned extends _Command {
  const _Sectioned(this.query);
  final SectionedQuery query;
}

void _workerMain(SendPort replies) {
  final requests = ReceivePort('catalog-db-requests');
  replies.send(requests.sendPort);
  final core = CatalogDbCore();
  requests.listen((message) {
    final (id, command) = message as (int, _Command);
    try {
      Object? result;
      switch (command) {
        case _Open(:final path):
          core.open(path);
        case _Close():
          core.close();
        case _Select(:final sql, :final parameters):
          result = core.select(sql, parameters);
        case _Sectioned(:final query):
          result = core.sectioned(query);
      }
      replies.send((id, result, null));
    } on CatalogDbException catch (error) {
      replies.send((id, null, error.message));
    } on Object catch (error) {
      replies.send((id, null, '$error'));
    }
  });
}
