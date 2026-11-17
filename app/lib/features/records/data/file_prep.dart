import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/record_models.dart';

/// Makes files smaller before they're uploaded, so uploads are quicker and
/// use less data (backend/docs/api-phase-3-files.md, "Making files
/// smaller"). The server does the same again, so this is about the upload;
/// storage is the server's job. Pure Dart (the `image` and `pdf` packages),
/// so it works the same on Android, iOS and Windows.
abstract final class FilePrep {
  /// An A4 page at about 220 dpi (the server's limit too).
  static const maxImageEdge = 2560;
  static const jpegQuality = 80;

  /// Scan pages: an A4 page at about 170 dpi, still sharp for small print.
  static const scanMaxEdge = 2000;
  static const scanQuality = 75;

  /// The first-page thumbnail sent with a scan PDF.
  static const thumbnailEdge = 600;

  /// A rewrite must save at least this share of the size.
  static const minSaving = 0.10;

  /// The image upright, at most [maxImageEdge] on its longest edge, as JPEG
  /// quality 80 with no metadata (EXIF, GPS). Null when the bytes aren't an
  /// image, or when the image has no metadata, is small enough, and JPEG
  /// wouldn't make it at least 10% smaller (upload it as it is).
  static Uint8List? compressImage(Uint8List bytes) {
    // The decoder turns a JPEG upright by its EXIF orientation and drops it,
    // so the metadata is read from the bytes first.
    final exif = _jpegExif(bytes);
    final decoded = _decode(bytes);
    if (decoded == null) return null;
    final upright = img.bakeOrientation(decoded);
    final tooBig = math.max(upright.width, upright.height) > maxImageEdge;
    final jpeg = _jpeg(_fit(upright, maxImageEdge), jpegQuality);
    final hasMetadata = exif != null && !exif.isEmpty;
    if (!hasMetadata && !tooBig && jpeg.length > bytes.length * (1 - minSaving)) return null;
    return jpeg;
  }

  static img.ExifData? _jpegExif(Uint8List bytes) {
    if (bytes.length < 3 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    try {
      return img.decodeJpgExif(bytes);
    } catch (_) {
      return null;
    }
  }

  /// One PDF from scanned pages (BR-F6): each page a JPEG of at most
  /// [scanMaxEdge] px, quality 75, on a page shaped like the image at A4
  /// width; plus a first-page thumbnail for the list.
  static Future<ScanPdf> buildScanPdf(List<Uint8List> pages) async {
    if (pages.isEmpty) throw ArgumentError.value(pages, 'pages', 'A scan needs at least one page.');
    final document = pw.Document(compress: true);
    Uint8List? thumbnail;
    for (final bytes in pages) {
      final decoded = _decode(bytes);
      if (decoded == null) throw const FormatException('A scanned page is not an image.');
      final page = _fit(img.bakeOrientation(decoded), scanMaxEdge);
      thumbnail ??= _jpeg(_fit(page, thumbnailEdge), 70);
      final jpeg = _jpeg(page, scanQuality);
      final width = PdfPageFormat.a4.width;
      final height = width * page.height / page.width;
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(width, height),
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Image(pw.MemoryImage(jpeg), fit: pw.BoxFit.contain),
        ),
      );
    }
    return ScanPdf(pdf: await document.save(), thumbnail: thumbnail!, pageCount: pages.length);
  }

  static img.Image? _decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  static img.Image _fit(img.Image image, int maxEdge) {
    if (math.max(image.width, image.height) <= maxEdge) return image;
    return image.width >= image.height
        ? img.copyResize(image, width: maxEdge, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: maxEdge, interpolation: img.Interpolation.average);
  }

  /// JPEG with no metadata; transparency becomes white (not black).
  static Uint8List _jpeg(img.Image image, int quality) {
    var source = image;
    if (image.hasAlpha) {
      final white = img.Image(width: image.width, height: image.height);
      img.fill(white, color: img.ColorRgb8(255, 255, 255));
      source = img.compositeImage(white, image);
    }
    source.exif = img.ExifData();
    return img.encodeJpg(source, quality: quality);
  }
}

/// A scan made into one PDF.
class ScanPdf {
  const ScanPdf({required this.pdf, required this.thumbnail, required this.pageCount});

  final Uint8List pdf;
  final Uint8List thumbnail;
  final int pageCount;
}

/// Gets a picked or scanned file ready to upload: images compressed in a
/// background isolate, PDFs with a first-page thumbnail. Tests override
/// [uploadPrepProvider] (isolates and the PDF renderer don't run there).
class UploadPrep {
  const UploadPrep();

  /// The file to upload in place of [file]: a compressed image, a PDF with
  /// its thumbnail, or [file] as it is.
  Future<UploadSource> prepare(UploadSource file) async {
    if (file.isImage && !_isHeic(file)) {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final compressed = await Isolate.run(() => FilePrep.compressImage(bytes));
      if (compressed == null) return file;
      return file.copyWith(name: _jpgName(file.name), bytes: compressed, sizeBytes: compressed.length, mimeType: 'image/jpeg');
    }
    if (file.isPdf && file.thumbnail == null) {
      final thumbnail = await pdfThumbnail(file.bytes ?? await File(file.path!).readAsBytes());
      return thumbnail == null ? file : file.copyWith(thumbnail: thumbnail);
    }
    return file;
  }

  /// D10: one PDF from the scanned pages, built in a background isolate.
  Future<ScanPdf> scanPdf(List<Uint8List> pages) => Isolate.run(() => FilePrep.buildScanPdf(pages));

  /// The first page as a PNG, through the system PDF renderer, or null when
  /// it can't be drawn (the upload goes without a thumbnail).
  Future<Uint8List?> pdfThumbnail(Uint8List pdf) async {
    try {
      await for (final page in Printing.raster(pdf, pages: const [0], dpi: 60)) {
        return await page.toPng();
      }
    } catch (_) {
      // No renderer on this platform, or a PDF it can't read.
    }
    return null;
  }

  /// Opens a PDF's pages as images for the viewer (D12).
  Stream<Uint8List> pdfPages(Uint8List pdf, {double dpi = 110}) async* {
    await for (final page in Printing.raster(pdf, dpi: dpi)) {
      yield await page.toPng();
    }
  }

  static bool _isHeic(UploadSource file) => const {'heic', 'heif'}.contains(file.extension);

  static String _jpgName(String name) {
    final dot = name.lastIndexOf('.');
    return '${dot < 0 ? name : name.substring(0, dot)}.jpg';
  }
}

final uploadPrepProvider = Provider<UploadPrep>((ref) => const UploadPrep());
