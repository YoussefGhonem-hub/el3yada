import 'package:catalog_core/catalog_core.dart';
import 'package:test/test.dart';

void main() {
  group('normalizeForSearch', () {
    test('lower-cases Latin text', () {
      expect(normalizeForSearch('PANADOL Extra'), 'panadol extra');
    });

    test('unifies the Arabic alef variants (A.6 step 4)', () {
      for (final alef in ['أ', 'إ', 'آ', 'ٱ', 'ا']) {
        expect(normalizeForSearch('$alef' 'موكسيسيلين'), 'اموكسيسيلين',
            reason: 'alef variant $alef');
      }
    });

    test('treats taa marbuta as haa and alef maqsura as yaa', () {
      expect(normalizeForSearch('صورة'), 'صوره');
      expect(normalizeForSearch('مستشفى'), 'مستشفي');
      expect(normalizeForSearch('صورة دم كاملة'), normalizeForSearch('صوره دم كامله'));
    });

    test('removes Arabic diacritics and tatweel (A.6 step 3)', () {
      // fatha, damma, kasra, shadda, sukun, tanween, superscript alef, tatweel
      expect(normalizeForSearch('بَنَادُول'), 'بنادول');
      expect(normalizeForSearch('مُسَكِّنٌ'), 'مسكن');
      expect(normalizeForSearch('هٰذا'), 'هذا');
      expect(normalizeForSearch('بنــــادول'), 'بنادول');
      expect(normalizeForSearch('دواءً'), 'دواء');
    });

    test('maps Arabic-Indic and Persian digits to 0-9 (A.6 step 2)', () {
      expect(normalizeForSearch('٥٠٠ مجم'), '500 مجم');
      expect(normalizeForSearch('۱۲۳'), '123');
      expect(normalizeForSearch('٠٫٥'), '0.5');
    });

    test('maps Persian keyboard letters', () {
      expect(normalizeForSearch('کلی'), 'كلي');
    });

    test('replaces punctuation with spaces (A.6 step 5)', () {
      expect(
        normalizeForSearch('CHLORPHENIRAMINE+PARACETAMOL(ACETAMINOPHEN)'),
        'chlorpheniramine paracetamol acetaminophen',
      );
      expect(normalizeForSearch('1 2 3 (ONE TWO THREE) 20 F.C.TABS.'),
          '1 2 3 one two three 20 f c tabs');
      expect(normalizeForSearch('ANTI-HISTAMINE.ANTI-ALLERGY'), 'anti histamine anti allergy');
      expect(normalizeForSearch('بنادول، اكسترا؟'), 'بنادول اكسترا');
    });

    test('keeps / and . between digits', () {
      expect(normalizeForSearch('250/5 ML'), '250/5 ml');
      expect(normalizeForSearch('0.1 %'), '0.1');
      expect(normalizeForSearch('875/125 MG'), '875/125 mg');
      expect(normalizeForSearch('end. 5'), 'end 5');
      expect(normalizeForSearch('mg/ml'), 'mg ml');
    });

    test('splits digits from letters so 500MG and 500 MG match', () {
      expect(normalizeForSearch('500MG'), '500 mg');
      expect(normalizeForSearch('250MG/5ML'), '250 mg 5 ml');
      expect(normalizeForSearch('HbA1c'), 'hba 1 c');
      expect(normalizeForSearch('2هك'), '2 هك');
    });

    test('folds Latin accents', () {
      expect(normalizeForSearch('Bénédicte'), 'benedicte');
    });

    test('collapses spaces and trims', () {
      expect(normalizeForSearch('  a   b  '), 'a b');
      expect(normalizeForSearch('...'), '');
      expect(normalizeForSearch(''), '');
    });

    test('keeps other letters such as Greek', () {
      expect(normalizeForSearch('β-hCG'), 'β hcg');
    });
  });

  group('searchWords', () {
    test('splits normalized text into words', () {
      expect(searchWords('Omeprazole 20MG'), ['omeprazole', '20', 'mg']);
      expect(searchWords(' - '), isEmpty);
    });
  });

  group('normalizeAndDedupe', () {
    test('joins values and drops repeated words', () {
      expect(
        normalizeAndDedupe(['CBC panel - Blood', null, 'CBC Pnl Bld', '']),
        'cbc panel blood pnl bld',
      );
    });
  });
}
