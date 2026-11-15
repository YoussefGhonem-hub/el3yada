// Phase 0 check: local catalog search with drift + SQLite FTS5 and Arabic
// normalization (spec 6.9, 9.5 and Appendix A.6). Runs on the host, so on a
// Windows machine it proves the Windows build of SQLite; Android and iOS need
// the same test on a device (integration test, later).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:el3yada/core/search/search_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

class _CatalogDb extends GeneratedDatabase {
  _CatalogDb() : super(NativeDatabase.memory());

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

void main() {
  late _CatalogDb db;

  const drugs = [
    'أوجمنتين 1 جم أقراص',
    'Augmentin 1g tablets',
    'بنادول إكسترا',
    'Panadol Extra',
    'فيتامين د 250/5 مجم',
    'صورة دم كاملة',
    'كَالْسِيُوم مع فيتامين د',
  ];

  setUp(() async {
    db = _CatalogDb();
    await db.customStatement(
      "CREATE VIRTUAL TABLE fts_drugs USING fts5(name, tokenize = 'unicode61 remove_diacritics 2')",
    );
    for (final name in drugs) {
      await db.customStatement(
        'INSERT INTO fts_drugs(name) VALUES (?)',
        [SearchNormalizer.normalize(name)],
      );
    }
  });

  tearDown(() => db.close());

  Future<List<int>> search(String typed) async {
    final query = SearchNormalizer.toFtsQuery(typed);
    if (query == null) return const [];
    final rows = await db.customSelect(
      'SELECT rowid FROM fts_drugs WHERE fts_drugs MATCH ? ORDER BY bm25(fts_drugs)',
      variables: [Variable.withString(query)],
    ).get();
    return rows.map((row) => row.read<int>('rowid')).toList();
  }

  test('SQLite on this platform has FTS5', () async {
    final rows = await db.customSelect("SELECT sqlite_compileoption_used('ENABLE_FTS5') AS fts5").get();
    expect(rows.single.read<int>('fts5'), 1);
  });

  test('typing without hamza finds the name with hamza', () async {
    expect(await search('اوجمن'), [1]);
  });

  test('ة and ه match each other', () async {
    expect(await search('صوره دم'), [6]);
  });

  test('every word must match, each as a prefix', () async {
    expect(await search('فيتا د'), containsAll([5, 7]));
    expect(await search('فيتا كالس'), [7]);
  });

  test('diacritics in the catalog do not stop a match', () async {
    expect(await search('كالسيوم'), [7]);
  });

  test('Arabic-Indic digits find Latin digits, and 250/5 stays one number', () async {
    expect(await search('٢٥٠/٥'), [5]);
  });

  test('English is case-insensitive', () async {
    expect(await search('AUGM'), [2]);
    expect(await search('panadol ext'), [4]);
  });

  test('punctuation only gives no query', () {
    expect(SearchNormalizer.toFtsQuery(' - ،'), isNull);
  });
}
