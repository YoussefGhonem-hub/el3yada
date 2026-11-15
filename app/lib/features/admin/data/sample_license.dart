import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// Sample license files for the offline admin data (dev builds and tests):
/// a syndicate card as a PNG and a one-page PDF, made in code so the repo
/// carries no binary sample files. Never used with the real API.
abstract final class SampleLicense {
  /// A 640 × 400 picture of a syndicate card. [seed] varies the layout a
  /// little so two doctors' cards don't look the same.
  static Uint8List png({int seed = 0}) {
    const width = 640;
    const height = 400;
    final pixels = Uint8List(width * height * 3);

    void fill(int left, int top, int right, int bottom, int rgb) {
      for (var y = top.clamp(0, height); y < bottom.clamp(0, height); y++) {
        for (var x = left.clamp(0, width); x < right.clamp(0, width); x++) {
          final i = (y * width + x) * 3;
          pixels[i] = rgb >> 16 & 0xFF;
          pixels[i + 1] = rgb >> 8 & 0xFF;
          pixels[i + 2] = rgb & 0xFF;
        }
      }
    }

    void ring(int cx, int cy, int outer, int inner, int rgb) {
      for (var y = cy - outer; y <= cy + outer; y++) {
        for (var x = cx - outer; x <= cx + outer; x++) {
          final d = (x - cx) * (x - cx) + (y - cy) * (y - cy);
          if (d <= outer * outer && d >= inner * inner) fill(x, y, x + 1, y + 1, rgb);
        }
      }
    }

    // Card, header band and border.
    fill(0, 0, width, height, 0xF4EFE2);
    fill(0, 0, width, 72, 0x1F5F57);
    fill(0, height - 14, width, height, 0x1F5F57);
    fill(24, 22, 300, 34, 0xE6F2EC);
    fill(24, 44, 220, 52, 0xA9D3C6);
    // Photo.
    fill(470, 100, 600, 260, 0xC9C2B0);
    ring(535, 160, 34, 0, 0x9C9582);
    fill(490, 205, 580, 260, 0x9C9582);
    // Text lines: name, specialty, number, dates.
    final shift = seed % 3 * 18;
    for (final (row, length) in [(110, 300 - shift), (150, 240 + shift), (190, 200), (230, 260 - shift), (270, 160)]) {
      fill(40, row, 40 + 90, row + 10, 0x7A7465);
      fill(150, row - 2, 150 + length, row + 12, 0x3B3830);
    }
    // Barcode.
    for (var i = 0; i < 46; i++) {
      final bar = (i * 7 + seed) % 5 == 0 ? 5 : 2;
      fill(40 + i * 8, 316, 40 + i * 8 + bar, 360, 0x2B2A26);
    }
    // Stamp.
    ring(520, 320, 44, 39, 0xB0402F);
    ring(520, 320, 30, 27, 0xB0402F);

    return _encodePng(width, height, pixels);
  }

  static Uint8List _encodePng(int width, int height, Uint8List rgb) {
    final raw = BytesBuilder(copy: false);
    for (var y = 0; y < height; y++) {
      raw.addByte(0); // no filter
      raw.add(Uint8List.sublistView(rgb, y * width * 3, (y + 1) * width * 3));
    }
    final header = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8) // bit depth
      ..setUint8(9, 2); // RGB
    return (BytesBuilder(copy: false)
          ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
          ..add(_chunk('IHDR', header.buffer.asUint8List()))
          ..add(_chunk('IDAT', Uint8List.fromList(ZLibCodec(level: 6).encode(raw.takeBytes()))))
          ..add(_chunk('IEND', Uint8List(0))))
        .takeBytes();
  }

  static Uint8List _chunk(String type, Uint8List data) {
    final typeBytes = ascii.encode(type);
    final length = ByteData(4)..setUint32(0, data.length);
    final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
    return (BytesBuilder(copy: false)
          ..add(length.buffer.asUint8List())
          ..add(typeBytes)
          ..add(data)
          ..add(crc.buffer.asUint8List()))
        .takeBytes();
  }

  static final List<int> _crcTable = List.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static int _crc32(List<int> bytes) {
    var crc = 0xFFFFFFFF;
    for (final byte in bytes) {
      crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFF;
  }

  /// A one-page A4 PDF that says what it is.
  static Uint8List pdf({String name = 'Sample doctor', String number = '00000'}) {
    final text = 'BT /F1 22 Tf 72 760 Td (Medical Syndicate - license card) Tj ET\n'
        'BT /F1 14 Tf 72 720 Td (Name: ${_pdfText(name)}) Tj ET\n'
        'BT /F1 14 Tf 72 696 Td (Syndicate number: ${_pdfText(number)}) Tj ET\n'
        'BT /F1 11 Tf 72 660 Td (el3yada offline sample file) Tj ET\n';
    final objects = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R '
          '/Resources << /Font << /F1 5 0 R >> >> >>',
      '<< /Length ${text.length} >>\nstream\n${text}endstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    ];
    final out = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xref = out.length;
    out
      ..write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n')
      ..writeAll([for (final offset in offsets) '${offset.toString().padLeft(10, '0')} 00000 n \n'])
      ..write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    return Uint8List.fromList(latin1.encode(out.toString()));
  }

  /// Latin letters only (Helvetica has no Arabic), with PDF escapes.
  static String _pdfText(String value) {
    final latin = value.runes.where((r) => r < 0x7F).map(String.fromCharCode).join().trim();
    return (latin.isEmpty ? '-' : latin).replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  }
}
