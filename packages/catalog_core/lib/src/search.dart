/// Turning what the doctor types into an FTS5 query, and the base search
/// statements (BR-CAT6, A.6 "Querying").
library;

import 'normalize.dart';
import 'schema.dart';

/// Builds an FTS5 MATCH expression from what the doctor typed.
///
/// Every word becomes a prefix query and all words must match, so "ator"
/// finds "atorvastatin". An Arabic word also matches through its skeleton
/// ([arabicSkeleton]), so «بنادول» finds the dataset's «بانادول». Returns
/// null when nothing searchable is left (for example only punctuation).
String? ftsPrefixQuery(String typed) {
  final words = searchWords(typed);
  if (words.isEmpty) return null;
  // Normalized words contain only letters, digits and "/" or "." between
  // digits, so quoting is safe; "*" after the closing quote makes a prefix.
  // FTS5 does not accept an implicit AND after a bracketed group, so the
  // words are joined with an explicit AND.
  return words
      .map((word) {
        final skeleton = arabicSkeleton(word);
        return skeleton == null ? '"$word"*' : '("$word"* OR "$skeleton"*)';
      })
      .join(' AND ');
}

/// Base search statements. Each takes two parameters: the MATCH expression
/// from [ftsPrefixQuery] and a row limit. They return catalog rows ordered by
/// relevance only; the app puts them into sections (history, specialty,
/// other specialties) itself.
abstract final class CatalogSearchSql {
  /// Column weights for `bm25()`: a match in the name counts more than a
  /// match in the ingredient or a LOINC synonym.
  static const drugs =
      '''
SELECT d.${DrugsTable.id}, d.${DrugsTable.tradeNameEn}, d.${DrugsTable.activeIngredient},
       d.${DrugsTable.manufacturer}, d.${DrugsTable.groupId}, d.${DrugsTable.route},
       d.${DrugsTable.form}, d.${DrugsTable.strengthHint}, d.${DrugsTable.status}
FROM ${FtsTables.drugs} f
JOIN ${DrugsTable.name} d ON d.${DrugsTable.id} = f.rowid
WHERE ${FtsTables.drugs} MATCH ?1
ORDER BY d.${DrugsTable.status} > 0, bm25(${FtsTables.drugs}, 10.0, 4.0), d.${DrugsTable.tradeNameEn}
LIMIT ?2''';

  static const labs =
      '''
SELECT l.${LabTestsTable.id}, l.${LabTestsTable.loincCode}, l.${LabTestsTable.nameEn},
       l.${LabTestsTable.shortName}, l.${LabTestsTable.nameAr}, l.${LabTestsTable.aliases},
       l.${LabTestsTable.loincClass}, l.${LabTestsTable.priority}
FROM ${FtsTables.labs} f
JOIN ${LabTestsTable.name} l ON l.${LabTestsTable.id} = f.rowid
WHERE ${FtsTables.labs} MATCH ?1
ORDER BY l.${LabTestsTable.priority} DESC, bm25(${FtsTables.labs}, 10.0, 12.0, 2.0),
         l.${LabTestsTable.orderRank} IS NULL, l.${LabTestsTable.orderRank}
LIMIT ?2''';

  static const radiology =
      '''
SELECT r.${RadiologyTable.id}, r.${RadiologyTable.loincCode}, r.${RadiologyTable.nameEn},
       r.${RadiologyTable.nameAr}, r.${RadiologyTable.modality}, r.${RadiologyTable.region},
       r.${RadiologyTable.aliases}, r.${RadiologyTable.focus}, r.${RadiologyTable.priority}
FROM ${FtsTables.radiology} f
JOIN ${RadiologyTable.name} r ON r.${RadiologyTable.id} = f.rowid
WHERE ${FtsTables.radiology} MATCH ?1
ORDER BY r.${RadiologyTable.priority} DESC, bm25(${FtsTables.radiology}, 10.0, 12.0, 2.0)
LIMIT ?2''';
}
