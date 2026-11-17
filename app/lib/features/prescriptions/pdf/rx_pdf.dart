import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../l10n/gen/app_localizations.dart';
import '../../sessions/domain/session_models.dart' show SessionType;
import '../domain/prescription_models.dart';
import 'rx_text.dart';

/// The fonts of the prescription PDF (6.4.1): Noto Sans Arabic for Arabic
/// and Alexandria for Latin. The PDF library embeds only the glyphs used
/// (a subset), which keeps the file small.
///
/// Noto Sans Arabic declares a line height of 2.11 em (room for stacked
/// marks the prescriptions never use), so every Arabic line would take as
/// much room as two. The PDF library sizes lines from the font's `hhea`
/// ascender and descender, so the copy used here gets compact ones
/// ([arabicAscender], [arabicDescender]: 1.55 em in all). The glyphs and their
/// drawing are untouched; only the line box is smaller, so an A5 page holds
/// the 6.4.1 layout.
class RxPdfFonts {
  const RxPdfFonts({required this.arabic, required this.arabicBold, required this.latin, required this.latinBold});

  final pw.Font arabic;
  final pw.Font arabicBold;
  final pw.Font latin;
  final pw.Font latinBold;

  static RxPdfFonts? _cached;

  /// From the app's assets, loaded once.
  static Future<RxPdfFonts> load() async {
    if (_cached != null) return _cached!;
    Future<ByteData> bytes(String file) => rootBundle.load('assets/fonts/$file');
    return _cached = RxPdfFonts.fromBytes(
      arabic: await bytes('NotoSansArabic-Regular.ttf'),
      arabicBold: await bytes('NotoSansArabic-Bold.ttf'),
      latin: await bytes('Alexandria-Regular.ttf'),
      latinBold: await bytes('Alexandria-Bold.ttf'),
    );
  }

  /// From any bytes (tests read the files directly).
  factory RxPdfFonts.fromBytes({
    required ByteData arabic,
    required ByteData arabicBold,
    required ByteData latin,
    required ByteData latinBold,
  }) =>
      RxPdfFonts(
        arabic: pw.Font.ttf(compactLineMetrics(arabic)),
        arabicBold: pw.Font.ttf(compactLineMetrics(arabicBold)),
        latin: pw.Font.ttf(latin),
        latinBold: pw.Font.ttf(latinBold),
      );

  /// The Arabic font's line box, in font units (1000 per em).
  static const arabicAscender = 1080;
  static const arabicDescender = -470;

  /// A copy of a TrueType font with [arabicAscender] and [arabicDescender] in
  /// its `hhea` table. Anything that isn't a font with an `hhea` table is
  /// returned as it is.
  static ByteData compactLineMetrics(ByteData font) {
    final copy = ByteData.sublistView(Uint8List.fromList(font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes)));
    if (copy.lengthInBytes < 12) return font;
    final tables = copy.getUint16(4);
    for (var i = 0; i < tables; i++) {
      final entry = 12 + i * 16;
      if (entry + 16 > copy.lengthInBytes) return font;
      final tag = String.fromCharCodes(copy.buffer.asUint8List(copy.offsetInBytes + entry, 4));
      if (tag != 'hhea') continue;
      final offset = copy.getUint32(entry + 8);
      if (offset + 8 > copy.lengthInBytes) return font;
      copy.setInt16(offset + 4, arabicAscender);
      copy.setInt16(offset + 6, arabicDescender);
      return copy;
    }
    return font;
  }
}

/// The doctor's names for the header (D22 profile).
class RxDoctor {
  const RxDoctor({
    required this.nameAr,
    required this.titleAr,
    this.specialtyAr,
    this.degreesAr,
    this.nameEn,
    this.titleEn,
    this.specialtyEn,
    this.degreesEn,
  });

  final String nameAr;
  final String titleAr;
  final String? specialtyAr;
  final String? degreesAr;
  final String? nameEn;
  final String? titleEn;
  final String? specialtyEn;
  final String? degreesEn;
}

/// Zone 2: who and when.
class RxPatient {
  const RxPatient({
    required this.name,
    required this.ageYears,
    required this.fileNumber,
    required this.visitDay,
    required this.visitType,
  });

  final String name;
  final int ageYears;
  final int fileNumber;

  /// The session's Cairo day (UTC midnight).
  final DateTime visitDay;
  final SessionType visitType;
}

/// One branch in the footer (BR-BR6).
class RxBranch {
  const RxBranch({
    required this.nameAr,
    this.nameEn,
    required this.address,
    this.landmark,
    this.phones = const [],
    this.whatsapp = const [],
    this.hours = const [],
  });

  final String nameAr;
  final String? nameEn;
  final String address;
  final String? landmark;
  final List<String> phones;
  final List<String> whatsapp;

  /// Already worded in the prescription's language, one line per group of days.
  final List<String> hours;
}

/// Everything one prescription PDF shows (6.4.1).
class RxPdfData {
  const RxPdfData({
    required this.settings,
    required this.doctor,
    required this.patient,
    required this.kind,
    this.diagnosis,
    this.advice,
    this.followUpDate,
    this.medications = const [],
    this.investigations = const [],
    required this.qrUrl,
    this.branches = const [],
    this.logo,
    this.signature,
  });

  final RxSettings settings;
  final RxDoctor doctor;
  final RxPatient patient;
  final PrescriptionKind kind;
  final String? diagnosis;
  final String? advice;
  final DateTime? followUpDate;
  final List<MedicationItem> medications;
  final List<InvestigationItem> investigations;
  final String qrUrl;

  /// The session's branch first, then the others (BR-BR6).
  final List<RxBranch> branches;
  final Uint8List? logo;
  final Uint8List? signature;
}

/// The page size of [settings] (BR-RX5).
PdfPageFormat rxPageFormat(RxSettings settings) => switch (settings.paperSize) {
      RxPaperSize.a5 => PdfPageFormat.a5,
      RxPaperSize.a4 => PdfPageFormat.a4,
      RxPaperSize.custom => PdfPageFormat(
          (settings.customWidthMm ?? 148) * PdfPageFormat.mm,
          (settings.customHeightMm ?? 210) * PdfPageFormat.mm,
        ),
    };

/// How many branches fit in the footer: 2 on A5, 3 on A4 (6.4.1 zone 7).
int rxFooterBranches(RxSettings settings) => switch (settings.paperSize) {
      RxPaperSize.a5 => 2,
      RxPaperSize.a4 => 3,
      RxPaperSize.custom => (settings.customWidthMm ?? 148) >= 190 ? 3 : 2,
    };

/// Builds the A5 (or A4, or custom) prescription of 6.4.1. A white page in
/// black, grey and one clinic colour; nothing under 9 pt; page 2 repeats the
/// header, the patient strip and the footer with «صفحة 2 من 2».
Future<Uint8List> buildRxPdf(RxPdfData data, RxPdfFonts fonts, {bool compress = true}) async =>
    (await buildRxDocument(data, fonts, compress: compress)).save();

/// The document behind [buildRxPdf]; its pages exist once it is saved (tests
/// count them). [compress] off keeps the drawing commands readable.
Future<pw.Document> buildRxDocument(RxPdfData data, RxPdfFonts fonts, {bool compress = true}) async {
  final english = data.settings.english;
  final language = english ? 'en' : 'ar';
  await initializeDateFormatting(language);
  final l10n = lookupAppLocalizations(Locale(language));
  final en = lookupAppLocalizations(const Locale('en'));
  final doc = pw.Document(
    title: l10n.rxPdfTitle(data.kind == PrescriptionKind.medication ? l10n.rxKindMedication : l10n.rxKindInvestigations),
    creator: 'el3yada',
    theme: pw.ThemeData.withFont(
      base: fonts.arabic,
      bold: fonts.arabicBold,
      fontFallback: [fonts.latin, fonts.latinBold],
    ),
    compress: compress,
  );
  final layout = _RxLayout(data: data, fonts: fonts, l10n: l10n, en: en, english: english);
  final mm = PdfPageFormat.mm;
  const margin = 10.5;
  final top = data.settings.preprinted ? (data.settings.marginTopMm ?? (margin + _RxLayout.headerMm)) : margin;
  final bottom = data.settings.preprinted ? (data.settings.marginBottomMm ?? (margin + _RxLayout.footerMm)) : margin;
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: rxPageFormat(data.settings),
        textDirection: english ? pw.TextDirection.ltr : pw.TextDirection.rtl,
        margin: pw.EdgeInsets.fromLTRB(margin * mm, top * mm, margin * mm, bottom * mm),
        theme: pw.ThemeData.withFont(
          base: fonts.arabic,
          bold: fonts.arabicBold,
          fontFallback: [fonts.latin, fonts.latinBold],
        ),
      ),
      maxPages: 20,
      header: layout.header,
      footer: layout.footer,
      build: layout.body,
    ),
  );
  return doc;
}

class _RxLayout {
  _RxLayout({required this.data, required this.fonts, required this.l10n, required this.en, required this.english})
      : accent = PdfColor.fromInt(data.settings.accentArgb);

  /// Zone heights (A5, 6.4.1).
  static const headerMm = 30.0;
  static const footerMm = 30.0;

  final RxPdfData data;
  final RxPdfFonts fonts;
  final AppLocalizations l10n;

  /// English labels for the drug lines (names and forms are English, 6.4.1 zone 4).
  final AppLocalizations en;
  final bool english;
  final PdfColor accent;

  static const ink = PdfColor.fromInt(0xFF1A1A1A);
  static const muted = PdfColor.fromInt(0xFF5B6664);
  static const hairline = PdfColor.fromInt(0xFFB9C2C0);

  /// The clinic colour, lightened for the patient strip.
  PdfColor get tint => PdfColor(
        1 - (1 - accent.red) * 0.08,
        1 - (1 - accent.green) * 0.08,
        1 - (1 - accent.blue) * 0.08,
      );

  double get mm => PdfPageFormat.mm;

  // ---------------------------------------------------------------------------
  // Text

  static final _arabic = RegExp('[؀-ۿ]');

  /// Arabic text reads right to left, anything else left to right, whatever
  /// the page's direction (English names keep their order, 6.4.1 "Text").
  pw.TextDirection _dirOf(String text) => _arabic.hasMatch(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.Widget text(
    String value, {
    double size = 10.5,
    bool bold = false,
    PdfColor color = ink,
    pw.TextAlign? align,
    int? maxLines,
  }) {
    final arabic = _arabic.hasMatch(value);
    return pw.Text(
      value,
      textDirection: _dirOf(value),
      textAlign: align ?? (english ? pw.TextAlign.left : pw.TextAlign.right),
      maxLines: maxLines,
      style: pw.TextStyle(
        font: arabic ? (bold ? fonts.arabicBold : fonts.arabic) : (bold ? fonts.latinBold : fonts.latin),
        fontFallback: arabic ? [fonts.latin] : [fonts.arabic],
        fontSize: size,
        color: color,
      ),
    );
  }

  String _day(DateTime day) => DateFormat.yMMMMd(english ? 'en' : 'ar').format(day);

  /// The visit date in the patient strip: «17 نوفمبر 2026», "Nov 17, 2026".
  String _shortDay(DateTime day) => DateFormat.yMMMd(english ? 'en' : 'ar').format(day);

  // ---------------------------------------------------------------------------
  // Zones 1 and 2: on every page

  pw.Widget header(pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (!data.settings.preprinted) ...[
            pw.SizedBox(height: (headerMm - 2) * mm, child: _letterhead()),
            pw.Container(height: 1.5, color: accent),
            pw.SizedBox(height: 2 * mm),
          ],
          _patientStrip(),
          pw.SizedBox(height: 2 * mm),
        ],
      );

  pw.Widget _letterhead() {
    final doctor = data.doctor;
    final arabicBlock = pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: english ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        text(doctor.nameAr, size: 14, bold: true, color: accent, maxLines: 1, align: pw.TextAlign.right),
        text([doctor.titleAr, ?doctor.specialtyAr].join(' — '), size: 9.5, color: ink, maxLines: 2, align: pw.TextAlign.right),
        if (doctor.degreesAr != null) text(doctor.degreesAr!, size: 9, color: muted, maxLines: 2, align: pw.TextAlign.right),
      ],
    );
    final englishBlock = pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: english ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
      children: [
        if (doctor.nameEn != null) text(doctor.nameEn!, size: 12.5, bold: true, color: accent, maxLines: 1, align: pw.TextAlign.left),
        if (doctor.titleEn != null || doctor.specialtyEn != null)
          text([?doctor.titleEn, ?doctor.specialtyEn].join(' — '), size: 9, color: ink, maxLines: 2, align: pw.TextAlign.left),
        if (doctor.degreesEn != null) text(doctor.degreesEn!, size: 9, color: muted, maxLines: 2, align: pw.TextAlign.left),
      ],
    );
    final logoSize = 22 * mm;
    final logo = pw.Container(
      width: logoSize,
      height: logoSize,
      alignment: pw.Alignment.center,
      decoration: data.logo == null
          ? pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: hairline, width: 0.8))
          : null,
      child: data.logo == null ? null : pw.Image(pw.MemoryImage(data.logo!), fit: pw.BoxFit.contain),
    );
    // The prescription's language takes the start side (6.4.1, "English prescription").
    final primary = english ? englishBlock : arabicBlock;
    final secondary = english ? arabicBlock : englishBlock;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(child: primary),
        pw.SizedBox(width: 4 * mm),
        logo,
        pw.SizedBox(width: 4 * mm),
        pw.Expanded(child: secondary),
      ],
    );
  }

  pw.Widget _patientStrip() {
    final patient = data.patient;
    pw.Widget field(String label, String value) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            text(label, size: 9, color: muted, maxLines: 1),
            text(value, size: 10.5, bold: true, maxLines: 1),
          ],
        );
    final gap = pw.SizedBox(width: 4 * mm);
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 3 * mm, vertical: 1.2 * mm),
      decoration: pw.BoxDecoration(color: tint, borderRadius: pw.BorderRadius.circular(2 * mm)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: field(l10n.rxPdfPatient, patient.name)),
          gap,
          field(l10n.rxPdfDate, _shortDay(patient.visitDay)),
          gap,
          field(l10n.rxPdfAge, l10n.rxPdfAgeValue(patient.ageYears)),
          gap,
          field(l10n.rxPdfFile, '${patient.fileNumber}'),
          gap,
          field(l10n.rxPdfVisit, rxVisitType(l10n, patient.visitType)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Zone 7 and the page number: on every page

  pw.Widget footer(pw.Context context) {
    final many = context.pagesCount > 1;
    // The page line always takes its space, so the footer is the same height
    // on every pass of the layout (the page count is only known at the end).
    final pageLine = pw.Opacity(
      opacity: many ? 1 : 0,
      child: text(l10n.rxPdfPage(context.pageNumber, context.pagesCount), size: 9, color: muted),
    );
    if (data.settings.preprinted) {
      return pw.Column(children: [pw.SizedBox(height: 1.5 * mm), pw.Center(child: pageLine)]);
    }
    final branches = data.branches.take(rxFooterBranches(data.settings)).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 1.5 * mm),
        pw.Container(height: 1, color: accent),
        pw.SizedBox(height: 1.5 * mm),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      for (final (i, branch) in branches.indexed) ...[
                        if (i > 0) pw.SizedBox(width: 3 * mm),
                        pw.Expanded(child: _branch(branch)),
                      ],
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: data.settings.footerText == null
                            ? pw.SizedBox()
                            : text(data.settings.footerText!, size: 9, color: muted, maxLines: 1),
                      ),
                      pageLine,
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 3 * mm),
            _qr(),
          ],
        ),
      ],
    );
  }

  pw.Widget _branch(RxBranch branch) {
    final name = english ? (branch.nameEn ?? branch.nameAr) : branch.nameAr;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        text(name, size: 9.5, bold: true, color: accent, maxLines: 1),
        text([branch.address, ?branch.landmark].join(' — '), size: 9, maxLines: 1),
        if (branch.phones.isNotEmpty) text('${l10n.rxPdfTel}: ${branch.phones.join('  ')}', size: 9, maxLines: 1),
        if (branch.whatsapp.isNotEmpty) text('${l10n.rxPdfWhatsapp}: ${branch.whatsapp.join('  ')}', size: 9, maxLines: 1),
        if (branch.hours.isNotEmpty) text(branch.hours.first, size: 9, color: muted, maxLines: 1),
      ],
    );
  }

  pw.Widget _qr() => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: data.qrUrl,
            drawText: false,
            width: 20 * mm,
            height: 20 * mm,
            color: PdfColors.black,
          ),
          pw.SizedBox(height: 0.6 * mm),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              text(l10n.rxPdfScan, size: 9, color: muted),
              pw.SizedBox(width: 1 * mm),
              pw.Text('el3yada', style: pw.TextStyle(font: fonts.latinBold, fontSize: 9, color: accent)),
            ],
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // Zones 3 to 6: the flowing body

  List<pw.Widget> body(pw.Context context) => [
        if (data.diagnosis != null) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              text(l10n.rxPdfDiagnosis, size: 10.5, bold: true, color: accent),
              pw.SizedBox(width: 2 * mm),
              pw.Expanded(child: text(data.diagnosis!, size: 10.5)),
            ],
          ),
          pw.SizedBox(height: 1.5 * mm),
        ],
        if (data.kind == PrescriptionKind.medication) ..._medications() else ..._investigations(),
        if (data.advice != null) ...[
          pw.SizedBox(height: 1.5 * mm),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 2.5 * mm, vertical: 1.2 * mm),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: hairline, width: 0.8),
              borderRadius: pw.BorderRadius.circular(2 * mm),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                text(data.kind == PrescriptionKind.medication ? l10n.rxPdfInstructions : l10n.rxPdfNotes,
                    size: 10.5, bold: true),
                pw.SizedBox(width: 2 * mm),
                pw.Expanded(child: text(data.advice!, size: 10.5)),
              ],
            ),
          ),
        ],
        pw.SizedBox(height: 2 * mm),
        _followUpAndSignature(),
      ];

  List<pw.Widget> _medications() => [
        pw.Text('Rx', textDirection: pw.TextDirection.ltr, style: pw.TextStyle(font: fonts.latinBold, fontSize: 16, color: accent)),
        for (final (i, item) in data.medications.indexed) _medication(i + 1, item),
      ];

  pw.Widget _medication(int number, MedicationItem item) {
    final form = item.form == null ? null : (DrugForms.isKnown(item.form) ? rxFormName(en, item.form!) : item.form);
    final title = [item.drugName, ?item.strength, ?form].join(' · ');
    final instructions = rxInstructionLine(l10n, item);
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 0.8 * mm),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 6 * mm,
            child: pw.Text('$number.', style: pw.TextStyle(font: fonts.latinBold, fontSize: 11, color: accent)),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // English names keep their order inside the Arabic page (6.4.1).
                pw.Align(
                  alignment: english ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                  child: text(title, size: 12, bold: true),
                ),
                if (instructions.isNotEmpty) text(instructions, size: 10.5, color: ink),
              ],
            ),
          ),
          if (item.duration != null) ...[
            pw.SizedBox(width: 2 * mm),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 2 * mm, vertical: 0.8 * mm),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: accent, width: 0.8),
                borderRadius: pw.BorderRadius.circular(3 * mm),
              ),
              child: text(item.duration!, size: 9.5, color: accent),
            ),
          ],
        ],
      ),
    );
  }

  List<pw.Widget> _investigations() {
    final labs = data.investigations.where((i) => i.category == InvestigationCategory.lab).toList();
    final scans = data.investigations.where((i) => i.category == InvestigationCategory.radiology).toList();
    return [
      text(l10n.rxPdfTestsIntro, size: 10.5, bold: true),
      pw.SizedBox(height: 2.5 * mm),
      if (labs.isNotEmpty) ...[
        text(l10n.rxPdfLabGroup, size: 10.5, bold: true, color: accent),
        pw.SizedBox(height: 1.5 * mm),
        // Two columns of check boxes.
        for (var row = 0; row < labs.length; row += 2)
          pw.Padding(
            padding: pw.EdgeInsets.only(bottom: 1.5 * mm),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _test(labs[row])),
                pw.SizedBox(width: 3 * mm),
                pw.Expanded(child: row + 1 < labs.length ? _test(labs[row + 1]) : pw.SizedBox()),
              ],
            ),
          ),
        pw.SizedBox(height: 2 * mm),
      ],
      if (scans.isNotEmpty) ...[
        text(l10n.rxPdfRadiologyGroup, size: 10.5, bold: true, color: accent),
        pw.SizedBox(height: 1.5 * mm),
        for (final scan in scans)
          pw.Padding(padding: pw.EdgeInsets.only(bottom: 1.5 * mm), child: _test(scan)),
      ],
    ];
  }

  pw.Widget _test(InvestigationItem item) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 3.2 * mm,
            height: 3.2 * mm,
            margin: pw.EdgeInsets.only(top: 1 * mm),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: ink, width: 0.7)),
          ),
          pw.SizedBox(width: 2 * mm),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                text(item.name, size: 12, bold: true),
                if (item.notes != null) text(item.notes!, size: 10, color: muted),
              ],
            ),
          ),
        ],
      );

  pw.Widget _followUpAndSignature() {
    final date = data.followUpDate;
    final followUp = date == null
        ? null
        : (data.kind == PrescriptionKind.medication ? l10n.rxPdfFollowUp(_day(date)) : l10n.rxPdfResultsOn(_day(date)));
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(child: followUp == null ? pw.SizedBox() : text(followUp, size: 10.5, bold: true, color: accent)),
        pw.SizedBox(width: 4 * mm),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.SizedBox(
              width: 40 * mm,
              height: 10 * mm,
              child: data.signature == null
                  ? null
                  : pw.Image(pw.MemoryImage(data.signature!), fit: pw.BoxFit.contain),
            ),
            pw.Container(width: 40 * mm, height: 0.6, color: ink),
            pw.SizedBox(height: 0.8 * mm),
            text(l10n.rxPdfSignature, size: 9, color: muted),
          ],
        ),
      ],
    );
  }
}
