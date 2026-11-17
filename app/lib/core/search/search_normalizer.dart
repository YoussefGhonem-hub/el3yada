/// Search normalization (spec Appendix A.6) comes from the shared
/// `catalog_core` package, which the catalog builder uses too, so what the
/// doctor types and what the catalog indexed can never be normalized
/// differently. Import this file, or `package:catalog_core/catalog_core.dart`.
library;

export 'package:catalog_core/catalog_core.dart'
    show arabicSkeleton, ftsPrefixQuery, normalizeForSearch, parseStrength, searchWords, withArabicSkeletons;
