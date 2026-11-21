import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Printing and sharing PDFs (BR-RX5) through the system dialogs, behind an
/// interface so tests can record what would print.
abstract interface class RxPrinter {
  /// The system print dialog (choose the printer and the copies).
  Future<bool> print(Uint8List pdf, {required String name});

  /// Share sheet on phones, save dialog on desktop (WhatsApp and so on).
  Future<bool> share(Uint8List pdf, {required String fileName});

  /// "Print all" (BR-RX5): one job with each stored document on its own page.
  Future<bool> printAll(List<Uint8List> pdfs, {required String name});
}

/// The `printing` plugin.
class PlatformRxPrinter implements RxPrinter {
  const PlatformRxPrinter();

  @override
  Future<bool> print(Uint8List pdf, {required String name}) =>
      Printing.layoutPdf(onLayout: (_) async => pdf, name: name, usePrinterSettings: true);

  @override
  Future<bool> share(Uint8List pdf, {required String fileName}) => Printing.sharePdf(bytes: pdf, filename: fileName);

  @override
  Future<bool> printAll(List<Uint8List> pdfs, {required String name}) async {
    final combined = await combineForPrint(pdfs, (pdf) => Printing.raster(pdf, dpi: printDpi));
    return Printing.layoutPdf(onLayout: (_) async => combined, name: name, usePrinterSettings: true);
  }

  /// Print quality for the combined job: the stored pages are drawn at this
  /// resolution, so small text stays sharp on paper.
  static const printDpi = 300.0;
}

/// Joins stored PDFs into one print job, page after page. The `pdf` package
/// can't import pages of another PDF, so each stored page is drawn as a
/// [printDpi] image at its own paper size: what prints is exactly what was
/// sent (BR-RX5 "every copy is identical"), at print resolution.
Future<Uint8List> combineForPrint(List<Uint8List> pdfs, Stream<PdfRaster> Function(Uint8List pdf) raster,
    {double dpi = PlatformRxPrinter.printDpi}) async {
  final doc = pw.Document(compress: true);
  for (final pdf in pdfs) {
    await for (final page in raster(pdf)) {
      final png = await page.toPng();
      final format = PdfPageFormat(page.width * PdfPageFormat.inch / dpi, page.height * PdfPageFormat.inch / dpi);
      doc.addPage(pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill),
      ));
    }
  }
  return doc.save();
}

final rxPrinterProvider = Provider<RxPrinter>((ref) => const PlatformRxPrinter());

/// Shows a PDF's pages (D15 preview, D22 live preview). Tests replace it,
/// because drawing pages needs the platform's PDF renderer.
final rxPdfViewProvider = Provider<Widget Function(Uint8List pdf, {double? maxPageWidth})>(
  (ref) => (pdf, {maxPageWidth}) => RxPdfPreview(pdf: pdf, maxPageWidth: maxPageWidth),
);

/// The pages of [pdf] on a neutral background, zoomable.
class RxPdfPreview extends StatelessWidget {
  const RxPdfPreview({super.key, required this.pdf, this.maxPageWidth});

  final Uint8List pdf;
  final double? maxPageWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PdfPreview(
      build: (_) async => pdf,
      useActions: false,
      allowPrinting: false,
      allowSharing: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      maxPageWidth: maxPageWidth ?? 700,
      scrollViewDecoration: BoxDecoration(color: scheme.surfaceContainerHigh),
      pdfPreviewPageDecoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))],
      ),
    );
  }
}
