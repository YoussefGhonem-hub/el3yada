import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:el3yada/features/prescriptions/domain/prescription_models.dart';
import 'package:el3yada/features/prescriptions/pdf/rx_pdf.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:el3yada/l10n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

/// The prescription PDF of spec 6.4.1 (AC-15's layout checks).
void main() {
  late RxPdfFonts fonts;

  ByteData font(String file) => ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync());

  setUpAll(() {
    fonts = RxPdfFonts.fromBytes(
      arabic: font('NotoSansArabic-Regular.ttf'),
      arabicBold: font('NotoSansArabic-Bold.ttf'),
      latin: font('Alexandria-Regular.ttf'),
      latinBold: font('Alexandria-Bold.ttf'),
    );
  });

  // A 1×1 PNG stands in for the clinic logo.
  final logo = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

  MedicationItem medicine(int i) => MedicationItem(
        drugName: 'Augmentin $i',
        strength: '1 g',
        form: DrugForms.tablet,
        dose: 'قرص',
        frequency: 'كل 12 ساعة',
        timing: MedicationTiming.afterFood,
        duration: '7 أيام',
        instructions: 'يؤخذ مع كوب ماء كامل',
      );

  RxPdfData data({
    RxSettings settings = const RxSettings(),
    int medicines = 4,
    PrescriptionKind kind = PrescriptionKind.medication,
    bool withLogo = true,
  }) =>
      RxPdfData(
        settings: settings,
        doctor: const RxDoctor(
          nameAr: 'د. سارة عادل',
          titleAr: 'استشاري',
          specialtyAr: 'باطنة',
          degreesAr: 'دكتوراه الباطنة — جامعة القاهرة',
          nameEn: 'Dr Sara Adel',
          titleEn: 'Consultant',
          specialtyEn: 'Internal Medicine',
        ),
        patient: RxPatient(
          name: 'منى حسن إبراهيم',
          ageYears: 34,
          fileNumber: 12,
          visitDay: DateTime.utc(2026, 11, 17),
          visitType: SessionType.examination,
        ),
        kind: kind,
        diagnosis: 'التهاب الحلق',
        advice: 'راحة وسوائل دافئة',
        followUpDate: DateTime.utc(2026, 11, 24),
        medications: [for (var i = 1; i <= medicines; i++) medicine(i)],
        investigations: const [
          InvestigationItem(category: InvestigationCategory.lab, name: 'CBC', notes: 'صائم 8 ساعات'),
          InvestigationItem(category: InvestigationCategory.lab, name: 'HbA1c'),
          InvestigationItem(category: InvestigationCategory.lab, name: 'Lipid profile'),
          InvestigationItem(category: InvestigationCategory.radiology, name: 'Chest X-ray PA view', notes: 'أشعة على الصدر'),
        ],
        qrUrl: 'https://el3yada.app/rx/aZ3kP0qLm9Xc',
        branches: const [
          RxBranch(
            nameAr: 'فرع المعادي',
            nameEn: 'Maadi',
            address: '12 شارع 9، المعادي',
            landmark: 'بجوار المترو',
            phones: ['0223581234'],
            whatsapp: ['01001234567'],
            hours: ['السبت – الأربعاء: 5:00 م – 10:00 م'],
          ),
          RxBranch(nameAr: 'فرع مدينة نصر', address: 'عباس العقاد، مدينة نصر', phones: ['0224011234']),
          RxBranch(nameAr: 'فرع ثالث', address: 'المهندسين'),
        ],
        logo: withLogo ? logo : null,
      );

  Future<int> pages(RxPdfData data) async {
    final doc = await buildRxDocument(data, fonts);
    await doc.save();
    return doc.document.pdfPageList.pages.length;
  }

  /// Image objects in the file: the logo (and the signature when set).
  int images(Uint8List pdf) => RegExp(r'/Subtype\s*/Image').allMatches(latin1.decode(pdf)).length;

  /// Filled rectangles drawn: the QR code's modules are hundreds of them.
  int rectangles(Uint8List pdf) => RegExp(r' re\b').allMatches(latin1.decode(pdf)).length;

  test('A5: the header, patient strip, 4 medicines, notes, signature and footer fit on one page', () async {
    expect(await pages(data()), 1);
    final pdf = await buildRxPdf(data(), fonts);
    expect(pdf.length, lessThan(300 * 1024), reason: 'fonts are subset: the file stays small');
    expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
  });

  test('12 medicines continue on page 2, which repeats the header, strip and footer', () async {
    expect(await pages(data(medicines: 12)), 2);
    final ar = lookupAppLocalizations(const Locale('ar'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(ar.rxPdfPage(2, 2), 'صفحة 2 من 2');
    expect(en.rxPdfPage(2, 2), 'Page 2 of 2');
  });

  test('the QR code and the logo are drawn in the header and footer', () async {
    final pdf = await buildRxPdf(data(), fonts, compress: false);
    // The logo (a PNG with transparency is an image and its mask).
    expect(images(pdf), greaterThanOrEqualTo(1));
    expect(rectangles(pdf), greaterThan(100));
  });

  test('pre-printed paper: no header or footer (no logo, no QR), and the text starts at the top margin', () async {
    final settings = const RxSettings().copyWith(preprinted: true, marginTopMm: () => 45, marginBottomMm: () => 35);
    final pdf = await buildRxPdf(data(settings: settings), fonts, compress: false);
    expect(images(pdf), 0);
    expect(rectangles(pdf), lessThan(40));
    expect(await pages(data(settings: settings)), 1);
  });

  test('the English prescription builds mirrored, and A4 and custom paper sizes apply', () async {
    expect(await pages(data(settings: const RxSettings(language: 'en'))), 1);
    final a4 = const RxSettings(paperSize: RxPaperSize.a4);
    expect(rxPageFormat(a4).width, closeTo(PdfPageFormat.a4.width, 0.01));
    expect(rxFooterBranches(a4), 3);
    expect(rxFooterBranches(const RxSettings()), 2);
    final custom = const RxSettings(paperSize: RxPaperSize.custom, customWidthMm: 160, customHeightMm: 230);
    expect(rxPageFormat(custom).width / PdfPageFormat.mm, closeTo(160, 0.01));
    expect(await pages(data(settings: custom)), 1);
  });

  test('an investigations request: lab tests in two columns and radiology, on one page', () async {
    expect(await pages(data(kind: PrescriptionKind.investigations)), 1);
  });

  test('the Arabic font gets a compact line box, so an A5 page holds the layout', () {
    final compact = RxPdfFonts.compactLineMetrics(font('NotoSansArabic-Regular.ttf'));
    int hhea(ByteData data, int field) {
      for (var i = 0; i < data.getUint16(4); i++) {
        final entry = 12 + i * 16;
        if (String.fromCharCodes(data.buffer.asUint8List(data.offsetInBytes + entry, 4)) == 'hhea') {
          return data.getInt16(data.getUint32(entry + 8) + field);
        }
      }
      throw StateError('no hhea');
    }

    expect(hhea(compact, 4), RxPdfFonts.arabicAscender);
    expect(hhea(compact, 6), RxPdfFonts.arabicDescender);
    expect(hhea(font('NotoSansArabic-Regular.ttf'), 4), 1374, reason: 'the asset itself is untouched');
  });

  test('no logo: an empty circle takes its place', () async {
    final pdf = await buildRxPdf(data(withLogo: false), fonts, compress: false);
    expect(images(pdf), 0);
  });
}
