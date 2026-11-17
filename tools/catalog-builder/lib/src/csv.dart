import 'dart:convert';
import 'dart:io';

/// A CSV file read into memory: its header and its rows (RFC 4180, as used
/// by the drug dataset, LOINC and our mapping files).
class CsvTable {
  CsvTable(this.path, this.header, this.rows)
      : _index = {for (var i = 0; i < header.length; i++) header[i]: i};

  /// Reads [path] as UTF-8. A byte-order mark is ignored, and so are blank
  /// lines.
  factory CsvTable.read(String path) {
    final text = File(path).readAsStringSync(encoding: utf8);
    final rows = parseCsv(text);
    if (rows.isEmpty) throw FormatException('Empty CSV file', path);
    final header = [for (final name in rows.first) name.trim()];
    final body = [
      for (final row in rows.skip(1))
        if (!(row.length == 1 && row.first.trim().isEmpty)) row,
    ];
    return CsvTable(path, header, body);
  }

  final String path;
  final List<String> header;
  final List<List<String>> rows;
  final Map<String, int> _index;

  bool hasColumn(String name) => _index.containsKey(name);

  /// The position of [name] in the header. Throws if it is missing.
  int column(String name) {
    final index = _index[name];
    if (index == null) {
      throw FormatException('Column "$name" not found in $path (header: ${header.join(', ')})');
    }
    return index;
  }

  /// Throws if any of [names] is missing from the header.
  void requireColumns(Iterable<String> names) {
    for (final name in names) {
      column(name);
    }
  }

  /// The value of column [index] in [row], or '' when the row is short.
  static String cell(List<String> row, int index) => index < row.length ? row[index] : '';
}

/// Parses CSV text: fields separated by commas, optionally quoted with `"`,
/// quotes inside quoted fields doubled, rows ending with LF or CRLF.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  forEachCsvRow(text, rows.add);
  return rows;
}

/// Reads the CSV file at [path] row by row: [onHeader] gets the trimmed
/// header, then [onRow] gets each non-blank row. Use it for large files
/// where only a few columns are kept.
void streamCsvFile(
  String path, {
  required void Function(List<String> header) onHeader,
  required void Function(List<String> row) onRow,
}) {
  var first = true;
  forEachCsvRow(File(path).readAsStringSync(encoding: utf8), (row) {
    if (first) {
      first = false;
      onHeader([for (final name in row) name.trim()]);
    } else if (!(row.length == 1 && row.first.trim().isEmpty)) {
      onRow(row);
    }
  });
  if (first) throw FormatException('Empty CSV file', path);
}

/// Calls [onRow] for every row of [text] (see [parseCsv]).
void forEachCsvRow(String text, void Function(List<String> row) onRow) {
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  var i = text.startsWith('﻿') ? 1 : 0;
  final length = text.length;
  while (i < length) {
    final c = text.codeUnitAt(i);
    if (inQuotes) {
      if (c == 0x22) {
        if (i + 1 < length && text.codeUnitAt(i + 1) == 0x22) {
          field.writeCharCode(0x22);
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        field.writeCharCode(c);
      }
      i++;
      continue;
    }
    switch (c) {
      case 0x22: // "
        inQuotes = true;
      case 0x2C: // ,
        row.add(field.toString());
        field.clear();
      case 0x0D: // \r
      case 0x0A: // \n
        row.add(field.toString());
        field.clear();
        onRow(row);
        row = <String>[];
        if (c == 0x0D && i + 1 < length && text.codeUnitAt(i + 1) == 0x0A) i++;
      default:
        field.writeCharCode(c);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    onRow(row);
  }
}

/// Quotes [value] for a CSV file when needed.
String csvField(String value) {
  final needsQuotes = value.isEmpty ||
      value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r') ||
      value != value.trim();
  return needsQuotes ? '"${value.replaceAll('"', '""')}"' : value;
}
