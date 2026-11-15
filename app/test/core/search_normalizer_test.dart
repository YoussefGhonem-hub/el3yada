import 'package:el3yada/core/search/search_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchNormalizer.normalize (spec A.6)', () {
    test('lower-cases Latin text', () {
      expect(SearchNormalizer.normalize('Panadol EXTRA'), 'panadol extra');
    });

    test('turns Arabic-Indic and Persian digits into Latin digits', () {
      expect(SearchNormalizer.normalize('٢٥٠ ۵'), '250 5');
    });

    test('removes diacritics and tatweel', () {
      expect(SearchNormalizer.normalize('كَالْسِيُـــوم'), 'كالسيوم');
    });

    test('unifies alef forms, ة and ى', () {
      expect(SearchNormalizer.normalize('أإآٱ صورة مستشفى'), 'اااا صوره مستشفي');
    });

    test('keeps / and . inside numbers only', () {
      expect(SearchNormalizer.normalize('250/5 mg, 0.1% (x/y).'), '250/5 mg 0.1 x y');
    });
  });

  test('toFtsQuery makes every word a quoted prefix', () {
    expect(SearchNormalizer.toFtsQuery('أوجمنتين 1جم'), '"اوجمنتين"* "1جم"*');
  });
}
