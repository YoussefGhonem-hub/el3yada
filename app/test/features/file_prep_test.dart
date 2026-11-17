import 'dart:typed_data';

import 'package:el3yada/features/records/data/file_prep.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Client-side optimization before upload (backend/docs/api-phase-3-files.md).
void main() {
  Uint8List photo(int width, int height, {int orientation = 1, int quality = 95, bool noisy = true}) {
    final image = img.Image(width: width, height: height);
    // Noise, like a real photo: JPEG can't make it tiny.
    var seed = 7;
    for (final pixel in image) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final v = noisy ? seed % 256 : 200;
      pixel
        ..r = v
        ..g = (v * 3) % 256
        ..b = 255 - v;
    }
    if (orientation != 1) image.exif.imageIfd.orientation = orientation;
    return img.encodeJpg(image, quality: quality);
  }

  group('compressImage', () {
    test('cuts a big photo to 2560 px and makes it smaller', () {
      final original = photo(3200, 2400);

      final compressed = FilePrep.compressImage(original)!;

      final decoded = img.decodeImage(compressed)!;
      expect(decoded.width, 2560);
      expect(decoded.height, 1920);
      expect(compressed.length, lessThan(original.length));
    });

    test('turns a sideways photo upright and drops its metadata', () {
      final original = photo(800, 600, orientation: 6, quality: 70);

      final compressed = FilePrep.compressImage(original)!;

      final decoded = img.decodeJpg(compressed)!;
      expect(decoded.width, 600, reason: 'a quarter turn');
      expect(decoded.height, 800);
      expect(img.decodeJpgExif(compressed)?.isEmpty ?? true, isTrue, reason: 'no EXIF left');
    });

    test('leaves a small upright photo alone when JPEG would not save 10%', () {
      final original = photo(800, 600, quality: 60);

      expect(FilePrep.compressImage(original), isNull);
    });

    test('a photo saved as PNG becomes a smaller JPEG with a white background', () {
      final image = img.Image(width: 1200, height: 900, numChannels: 4);
      var seed = 3;
      for (final pixel in image) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        final noise = seed % 7;
        pixel
          ..r = (pixel.x * 255 ~/ 1200 + noise) % 256
          ..g = (pixel.y * 255 ~/ 900 + noise) % 256
          ..b = 128 + noise
          ..a = 255;
      }
      image.getPixel(0, 0).a = 0;
      final png = img.encodePng(image);

      final compressed = FilePrep.compressImage(png)!;

      expect(compressed.length, lessThan(png.length));
      final decoded = img.decodeJpg(compressed)!;
      final corner = decoded.getPixel(0, 0);
      expect(corner.r, greaterThan(200), reason: 'transparent turns white, not black');
    });

    test('not an image: null', () {
      expect(FilePrep.compressImage(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });

  group('buildScanPdf', () {
    test('one PDF with every page as a JPEG of at most 2000 px, and a thumbnail', () async {
      final pages = [photo(3000, 4000, noisy: false), photo(1000, 1400, noisy: false), photo(2000, 1500, orientation: 6, noisy: false)];

      final scan = await FilePrep.buildScanPdf(pages);

      expect(scan.pageCount, 3);
      final text = String.fromCharCodes(scan.pdf);
      expect(text.startsWith('%PDF-'), isTrue);
      expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length, 3);
      expect(RegExp(r'/Filter\s*/DCTDecode').allMatches(text).length, 3, reason: 'the pages are JPEG');
      final widths = RegExp(r'/Width\s+(\d+)').allMatches(text).map((m) => int.parse(m.group(1)!)).toList();
      final heights = RegExp(r'/Height\s+(\d+)').allMatches(text).map((m) => int.parse(m.group(1)!)).toList();
      for (var i = 0; i < widths.length; i++) {
        expect(widths[i] <= 2000 && heights[i] <= 2000, isTrue);
      }
      final thumbnail = img.decodeJpg(scan.thumbnail)!;
      expect(thumbnail.height, FilePrep.thumbnailEdge);
      expect(thumbnail.width, 450);
    });

    test('refuses no pages and a page that is not an image', () async {
      await expectLater(FilePrep.buildScanPdf(const []), throwsArgumentError);
      await expectLater(FilePrep.buildScanPdf([Uint8List.fromList([9, 9, 9])]), throwsFormatException);
    });
  });
}
