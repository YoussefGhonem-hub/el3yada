/// Small readers shared by the clinic admin models. The API sends `null` for
/// an empty optional text; an empty string is treated the same way.
library;

DateTime readTime(Object? value) => DateTime.parse(value! as String).toUtc();

DateTime? readTimeOrNull(Object? value) => value == null ? null : readTime(value);

String? readText(Object? value) => value is String && value.trim().isNotEmpty ? value : null;

Map<String, dynamic> readMap(Object? value) => (value as Map).cast<String, dynamic>();

Map<String, dynamic>? readMapOrNull(Object? value) => value is Map ? value.cast<String, dynamic>() : null;

List<Map<String, dynamic>> readList(Object? value) =>
    [for (final row in (value as List?) ?? const []) (row as Map).cast<String, dynamic>()];

List<String> readStrings(Object? value) => [for (final item in (value as List?) ?? const []) item as String];

/// JSON numbers can arrive as int or double (`30.038000`).
double? readDouble(Object? value) => value is num ? value.toDouble() : null;

/// A `YYYY-MM-DD` Cairo date as a plain date (no time zone).
DateTime? readDay(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

/// A plain date as the API's `YYYY-MM-DD`.
String writeDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
