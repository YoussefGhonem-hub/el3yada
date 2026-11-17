import 'package:el3yada/core/search/search_normalizer.dart';
import 'package:el3yada/features/catalog/data/history_catalog_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app searches with the catalog builder's own normalization
/// (`package:catalog_core`, spec A.6). These are the cases the app relies on;
/// the package's own tests cover the rest.
void main() {
  group('normalizeForSearch (spec A.6, shared with the catalog builder)', () {
    test('lower-cases Latin text', () {
      expect(normalizeForSearch('Panadol EXTRA'), 'panadol extra');
    });

    test('turns Arabic-Indic and Persian digits into Latin digits', () {
      expect(normalizeForSearch('٢٥٠ ۵'), '250 5');
    });

    test('removes diacritics and tatweel', () {
      expect(normalizeForSearch('كَالْسِيُـــوم'), 'كالسيوم');
    });

    test('unifies alef forms, ة and ى', () {
      expect(normalizeForSearch('أإآٱ صورة مستشفى'), 'اااا صوره مستشفي');
    });

    test('keeps / and . inside numbers only', () {
      expect(normalizeForSearch('250/5 mg, 0.1% (x/y).'), '250/5 mg 0.1 x y');
    });

    test('splits a number from its unit, so 500MG and 500 MG match', () {
      expect(searchWords('PANADOL 500MG'), ['panadol', '500', 'mg']);
    });
  });

  test('ftsPrefixQuery makes every word a quoted prefix, and nothing searchable gives no query', () {
    expect(ftsPrefixQuery('panadol ext'), '"panadol"* AND "ext"*');
    expect(ftsPrefixQuery(' - ،'), isNull);
  });

  test('parseStrength reads the strength out of a trade name (BR-CAT7)', () {
    expect(parseStrength('ABILIFY 15 MG 10 TABS.'), '15 MG');
    expect(parseStrength('SYRUP 120 ML'), isNull);
  });

  group('the history search matches like the catalog (BR-CAT6)', () {
    test('the start of any word, ignoring case and letter variants', () {
      expect(matchesWordStarts('Panadol Extra', searchWords('ext')), isTrue);
      expect(matchesWordStarts('أوجمنتين', searchWords('اوجم')), isTrue);
      expect(matchesWordStarts('Panadol Extra', searchWords('dol')), isFalse);
    });

    test('an Arabic word also matches through its skeleton: «بنادول» finds «بانادول»', () {
      expect(matchesWordStarts('بانادول اكسترا', searchWords('بنادول')), isTrue);
    });

    test('every typed word must match', () {
      expect(matchesWordStarts('Panadol Extra', searchWords('pan ext')), isTrue);
      expect(matchesWordStarts('Panadol Extra', searchWords('pan cold')), isFalse);
    });
  });
}
