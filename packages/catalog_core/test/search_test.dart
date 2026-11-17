import 'package:catalog_core/catalog_core.dart';
import 'package:test/test.dart';

void main() {
  group('ftsPrefixQuery', () {
    test('makes every word a prefix query', () {
      expect(ftsPrefixQuery('ator'), '"ator"*');
      expect(ftsPrefixQuery('Omep 20'), '"omep"* "20"*');
    });

    test('normalizes Arabic before querying', () {
      expect(ftsPrefixQuery('بَنادول'), '"بنادول"*');
      expect(ftsPrefixQuery('صورة دم كاملة'), '"صوره"* "دم"* "كامله"*');
    });

    test('keeps numbers with / and . as one word', () {
      expect(ftsPrefixQuery('250/5'), '"250/5"*');
    });

    test('returns null when nothing is left to search', () {
      expect(ftsPrefixQuery('  -  '), isNull);
      expect(ftsPrefixQuery(''), isNull);
    });

    test('never lets FTS5 syntax through', () {
      expect(ftsPrefixQuery('a" OR b*'), '"a"* "or"* "b"*');
      expect(ftsPrefixQuery('NEAR(x y)'), '"near"* "x"* "y"*');
    });
  });

  group('loinc ids', () {
    test('round-trip', () {
      for (final code in ['58410-2', '4548-4', '1-8', '100898-6']) {
        expect(loincFromId(loincToId(code)), code);
      }
      expect(loincToId('58410-2'), 584102);
    });

    test('reject what is not a LOINC code', () {
      expect(() => loincToId('58410'), throwsFormatException);
      expect(() => loincToId('LP1234-5'), throwsFormatException);
      expect(() => loincToId('1-23'), throwsFormatException);
    });
  });

  test('the schema creates every table the app reads', () {
    final sql = CatalogSchema.createStatements.join('\n');
    for (final table in [
      MetaTable.name,
      DrugGroupsTable.name,
      DrugsTable.name,
      IngredientsTable.name,
      DrugIngredientsTable.name,
      LabTestsTable.name,
      RadiologyTable.name,
      ModalitiesTable.name,
      FtsTables.drugs,
      FtsTables.labs,
      FtsTables.radiology,
    ]) {
      expect(sql, contains('TABLE $table '), reason: table);
    }
  });
}
