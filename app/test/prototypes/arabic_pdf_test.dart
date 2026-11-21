// Phase 0 check: an A5 prescription with Arabic and English text (spec 6.4.1).
// Writes build/prototypes/rx_a5_prototype.pdf so a person can open, print and
// share it. Printing and sharing need the `printing` plugin on a device and
// are checked by hand.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

pw.Font _font(String file) => pw.Font.ttf(
  File('assets/fonts/$file').readAsBytesSync().buffer.asByteData(),
);

void main() {
  test('A5 prescription with Arabic and English renders to PDF', () async {
    final latin = _font('Alexandria-Regular.ttf');
    final latinBold = _font('Alexandria-Bold.ttf');
    final doc = pw.Document(
      // Arabic text uses Noto Sans Arabic: the PDF library shapes Arabic into
      // presentation forms and Alexandria lacks the isolated ي (see
      // font_coverage_test.dart). Latin text uses Alexandria, set per widget.
      theme: pw.ThemeData.withFont(
        base: _font('NotoSansArabic-Regular.ttf'),
        bold: _font('NotoSansArabic-Bold.ttf'),
        fontFallback: [latin],
      ),
    );
    const pine = PdfColor.fromInt(0xFF0F4C45);
    const muted = PdfColor.fromInt(0xFF4C6964);

    pw.Widget medicine(String name, String dose) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            name,
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(font: latinBold, fontSize: 12),
          ),
          pw.Text(dose, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(12 * PdfPageFormat.mm),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'د. سارة عادل',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: pine,
                        ),
                      ),
                      pw.Text(
                        'استشاري الباطنة',
                        style: const pw.TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Dr. Sara Adel',
                      textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(
                        font: latinBold,
                        fontSize: 13,
                        color: pine,
                      ),
                    ),
                    pw.Text(
                      'Internal Medicine Consultant',
                      textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(
                        font: latin,
                        fontSize: 9,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: pine, thickness: 1.2),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'المريض: محمود حسن',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
                pw.Text(
                  'التاريخ: 15 نوفمبر 2026',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            medicine('Augmentin 1g', 'قرص كل 12 ساعة بعد الأكل، لمدة 7 أيام'),
            medicine(
              'Panadol Extra',
              'قرص عند اللزوم، 4 أقراص في اليوم بحد أقصى',
            ),
            pw.Spacer(),
            pw.Divider(color: muted, thickness: 0.5),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'فرع مدينة نصر، شارع عباس العقاد',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '0100 123 4567',
                        textDirection: pw.TextDirection.ltr,
                        style: pw.TextStyle(font: latin, fontSize: 9),
                      ),
                      pw.Text(
                        'امسح الكود لفتح الروشتة في تطبيق العيادة',
                        style: const pw.TextStyle(fontSize: 8, color: muted),
                      ),
                    ],
                  ),
                ),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'https://el3yada.app/rx/AB12CD',
                  drawText: false,
                  width: 22 * PdfPageFormat.mm,
                  height: 22 * PdfPageFormat.mm,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    final out = File('build/prototypes/rx_a5_prototype.pdf')
      ..createSync(recursive: true);
    out.writeAsBytesSync(bytes);

    expect(bytes.length, greaterThan(5000));
    expect(PdfPageFormat.a5.width / PdfPageFormat.mm, closeTo(148, 0.5));
    expect(PdfPageFormat.a5.height / PdfPageFormat.mm, closeTo(210, 0.5));
  });
}
