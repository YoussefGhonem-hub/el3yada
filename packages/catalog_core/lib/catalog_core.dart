/// Shared code for the el3yada medical catalog (spec 6.9, 9.5, Appendix A):
/// search normalization, the strength parser, the local database schema and
/// FTS5 query helpers. Pure Dart, so the catalog builder and the Flutter app
/// both use it.
library;

export 'src/normalize.dart';
export 'src/schema.dart';
export 'src/search.dart';
export 'src/strength.dart';
