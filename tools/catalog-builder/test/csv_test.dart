import 'package:catalog_builder/catalog_builder.dart';
import 'package:test/test.dart';

void main() {
  test('parses quoted fields, doubled quotes, commas and newlines', () {
    final rows = parseCsv('a,"b,c","say ""hi""","line\none"\r\n1,2,3,4\n');
    expect(rows, [
      ['a', 'b,c', 'say "hi"', 'line\none'],
      ['1', '2', '3', '4'],
    ]);
  });

  test('ignores a byte-order mark and keeps empty fields', () {
    expect(parseCsv('﻿x,,z'), [
      ['x', '', 'z'],
    ]);
  });

  test('quotes fields that need it', () {
    expect(csvField('plain'), 'plain');
    expect(csvField('a,b'), '"a,b"');
    expect(csvField('say "hi"'), '"say ""hi"""');
    expect(csvField(''), '""');
    expect(csvField(' padded'), '" padded"');
  });
}
