// Phase 0 check: the PDF library shapes Arabic into presentation forms
// (U+FE70–U+FEFF) before it looks for fallback fonts, so the font used for
// Arabic text in PDFs must contain every presentation form itself.
//
// Result: Alexandria lacks U+FEF1 (isolated ي, as in «استشاري»), so Arabic
// text in PDFs uses Noto Sans Arabic and Latin text uses Alexandria. The app
// UI is not affected: Flutter shapes text with the font's OpenType tables.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

PdfTtfFont _load(PdfDocument doc, String file) => PdfTtfFont(
  doc,
  File('assets/fonts/$file').readAsBytesSync().buffer.asByteData(),
);

List<int> _missingForms(PdfTtfFont font) => [
  for (var rune = 0xFE80; rune <= 0xFEFC; rune++)
    if (!font.isRuneSupported(rune)) rune,
];

void main() {
  test(
    'Noto Sans Arabic has every Arabic presentation form (regular and bold)',
    () {
      final doc = PdfDocument();
      expect(_missingForms(_load(doc, 'NotoSansArabic-Regular.ttf')), isEmpty);
      expect(_missingForms(_load(doc, 'NotoSansArabic-Bold.ttf')), isEmpty);
    },
  );

  test(
    'Alexandria still lacks the isolated ي, so PDFs keep Noto Sans Arabic for Arabic',
    () {
      final doc = PdfDocument();
      expect(
        _missingForms(_load(doc, 'Alexandria-Regular.ttf')),
        [0xFEF1],
        reason:
            'If this changes, Alexandria could be used for Arabic in PDFs too.',
      );
    },
  );
}
