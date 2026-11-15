import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/search/search_normalizer.dart';

part 'specialty.freezed.dart';
part 'specialty.g.dart';

/// A medical specialty from `GET /api/specialties` (the list the admin
/// manages). A4 step 2 picks the primary one and up to 2 extras.
@freezed
abstract class Specialty with _$Specialty {
  const Specialty._();

  const factory Specialty({
    required String id,
    @Default('') String nameAr,
    @Default('') String nameEn,
  }) = _Specialty;

  factory Specialty.fromJson(Map<String, dynamic> json) => _$SpecialtyFromJson(json);

  /// The name in [languageCode], or the other language when it is empty
  /// (spec section 12).
  String name(String languageCode) {
    final (preferred, other) = languageCode == 'ar' ? (nameAr, nameEn) : (nameEn, nameAr);
    return preferred.trim().isNotEmpty ? preferred : other;
  }

  /// True when every typed word starts a word of either name (spec A.6
  /// normalization: hamza forms, ة/ه, ى/ي, Arabic-Indic digits).
  bool matches(String query) => matchesNames(query, [nameAr, nameEn]);
}

/// Shared by the specialty and governorate pickers.
bool matchesNames(String query, List<String> names) {
  final words = SearchNormalizer.normalize(query).split(' ').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return true;
  final haystack = names.map(SearchNormalizer.normalize).join(' ').split(' ');
  return words.every((word) => haystack.any((candidate) => candidate.startsWith(word)));
}
