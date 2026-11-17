import 'dart:io';

import 'package:path/path.dart' as p;

import 'csv.dart';

/// The files of one unpacked LOINC release (spec A.4.1, A.5.1).
class LoincRelease {
  LoincRelease(this.dir, this.version);

  /// Finds the release under `<sources>/loinc/`. With [version], that folder
  /// is used; otherwise the only (or highest-numbered) folder.
  factory LoincRelease.find(String sourcesDir, {String? version}) {
    final loincDir = Directory(p.join(sourcesDir, 'loinc'));
    if (!loincDir.existsSync()) {
      throw FileSystemException('No loinc folder in the sources folder', loincDir.path);
    }
    if (version != null) return LoincRelease(p.join(loincDir.path, version), version)..check();
    final versions = loincDir
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .where((name) => RegExp(r'^\d+\.\d+$').hasMatch(name))
        .toList()
      ..sort(_compareVersions);
    if (versions.isEmpty) {
      throw FileSystemException('No LOINC release folder (such as 2.83) found', loincDir.path);
    }
    return LoincRelease(p.join(loincDir.path, versions.last), versions.last)..check();
  }

  final String dir;

  /// The release number, e.g. "2.83".
  final String version;

  String get mainTable => p.join(dir, 'LoincTable', 'Loinc.csv');
  String get universalLabOrders =>
      p.join(dir, 'AccessoryFiles', 'LoincUniversalLabOrdersValueSet', 'LoincUniversalLabOrdersValueSet.csv');
  String get playbook => p.join(dir, 'AccessoryFiles', 'LoincRsnaRadiologyPlaybook', 'LoincRsnaRadiologyPlaybook.csv');
  String get linguisticVariantsDir => p.join(dir, 'AccessoryFiles', 'LinguisticVariants');

  void check() {
    for (final file in [mainTable, universalLabOrders, playbook]) {
      if (!File(file).existsSync()) throw FileSystemException('Missing LOINC file', file);
    }
  }

  /// The linguistic-variant file for [language] (e.g. "ar"), found through
  /// the variants index (A.4.4 step 1), or null when the release has none.
  String? variantFile(String language) {
    final index = p.join(linguisticVariantsDir, 'LinguisticVariants.csv');
    if (!File(index).existsSync()) return null;
    final table = CsvTable.read(index)..requireColumns(['ID', 'ISO_LANGUAGE', 'ISO_COUNTRY']);
    for (final row in table.rows) {
      if (CsvTable.cell(row, table.column('ISO_LANGUAGE')).trim().toLowerCase() != language) continue;
      final id = CsvTable.cell(row, table.column('ID')).trim();
      final country = CsvTable.cell(row, table.column('ISO_COUNTRY')).trim();
      final file = p.join(linguisticVariantsDir, '$language$country${id}LinguisticVariant.csv');
      if (File(file).existsSync()) return file;
    }
    return null;
  }
}

int _compareVersions(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return pa.length.compareTo(pb.length);
}

/// The fields we use from one row of the main LOINC table (A.4.2).
class LoincTerm {
  LoincTerm({
    required this.code,
    required this.longName,
    required this.shortName,
    required this.relatedNames,
    required this.loincClass,
    required this.classType,
    required this.orderObs,
    required this.status,
    required this.commonOrderRank,
  });

  final String code;
  final String longName;
  final String shortName;

  /// RELATEDNAMES2, split on ";".
  final List<String> relatedNames;
  final String loincClass;
  final String classType;
  final String orderObs;
  final String status;

  /// COMMON_ORDER_RANK, or 0.
  final int commonOrderRank;

  bool get isActive => status == 'ACTIVE';

  /// A.4.3: a laboratory term (CLASSTYPE 1) that is active and can be
  /// ordered (ORDER_OBS Order or Both). This drops deprecated, discouraged
  /// and trial terms, observation-only result lines, clinical terms, claims
  /// attachments and surveys.
  bool get isOrderableLab => classType == '1' && isActive && (orderObs == 'Order' || orderObs == 'Both');
}

/// Reads the main LOINC table, keeping only the columns we use.
Map<String, LoincTerm> readLoincTable(String path) {
  final terms = <String, LoincTerm>{};
  late int code, longName, shortName, related, loincClass, classType, orderObs, status, rank;
  streamCsvFile(
    path,
    onHeader: (header) {
      int col(String name) {
        final index = header.indexOf(name);
        if (index < 0) throw FormatException('Column $name not found in the LOINC table', path);
        return index;
      }

      code = col('LOINC_NUM');
      longName = col('LONG_COMMON_NAME');
      shortName = col('SHORTNAME');
      related = col('RELATEDNAMES2');
      loincClass = col('CLASS');
      classType = col('CLASSTYPE');
      orderObs = col('ORDER_OBS');
      status = col('STATUS');
      rank = col('COMMON_ORDER_RANK');
    },
    onRow: (row) {
      final number = CsvTable.cell(row, code).trim();
      if (number.isEmpty) return;
      terms[number] = LoincTerm(
        code: number,
        longName: CsvTable.cell(row, longName).trim(),
        shortName: CsvTable.cell(row, shortName).trim(),
        relatedNames: splitRelatedNames(CsvTable.cell(row, related)),
        loincClass: CsvTable.cell(row, loincClass).trim(),
        classType: CsvTable.cell(row, classType).trim(),
        orderObs: CsvTable.cell(row, orderObs).trim(),
        status: CsvTable.cell(row, status).trim(),
        commonOrderRank: int.tryParse(CsvTable.cell(row, rank).trim()) ?? 0,
      );
    },
  );
  return terms;
}

List<String> splitRelatedNames(String value) => [
      for (final part in value.split(';'))
        if (part.trim().isNotEmpty) part.trim(),
    ];

/// The LOINC codes of the Universal Lab Orders Value Set.
Set<String> readUniversalLabOrders(String path) {
  final table = CsvTable.read(path)..requireColumns(['LOINC_NUM']);
  return {for (final row in table.rows) CsvTable.cell(row, table.column('LOINC_NUM')).trim()};
}

/// A LOINC term's names in one linguistic variant.
class VariantNames {
  const VariantNames(this.displayName, this.relatedNames);
  final String displayName;
  final List<String> relatedNames;
}

/// Reads a linguistic-variant file: code → translated display name and
/// related names. In the Arabic (Jordan) file the translation is in
/// LinguisticVariantDisplayName and RELATEDNAMES2; LONG_COMMON_NAME holds the
/// English name.
Map<String, VariantNames> readVariant(String path) {
  final table = CsvTable.read(path)..requireColumns(['LOINC_NUM', 'LinguisticVariantDisplayName', 'RELATEDNAMES2']);
  final result = <String, VariantNames>{};
  for (final row in table.rows) {
    final code = CsvTable.cell(row, table.column('LOINC_NUM')).trim();
    final display = CsvTable.cell(row, table.column('LinguisticVariantDisplayName')).trim();
    final related = splitRelatedNames(CsvTable.cell(row, table.column('RELATEDNAMES2')));
    if (code.isEmpty || (display.isEmpty && related.isEmpty)) continue;
    result[code] = VariantNames(display, related);
  }
  return result;
}

/// The Playbook attributes of one radiology procedure (A.5.2).
class PlaybookEntry {
  final Set<String> modalities = {};
  final Set<String> subtypes = {};
  final Set<String> regions = {};
  final Set<String> foci = {};
}

/// Part types we read from the Playbook. Checked against the real file:
/// "Rad.Modality.Modality Type", "Rad.Modality.Modality Subtype",
/// "Rad.Anatomic Location.Region Imaged", "Rad.Anatomic Location.Imaging
/// Focus".
const playbookModality = 'Rad.Modality.Modality Type';
const playbookSubtype = 'Rad.Modality.Modality Subtype';
const playbookRegion = 'Rad.Anatomic Location.Region Imaged';
const playbookFocus = 'Rad.Anatomic Location.Imaging Focus';

/// Placeholders the Playbook uses for "not specified".
const _unspecified = {'XXX', '{Imaging modality}'};

/// Reads the Playbook: code → modality, subtype, region and focus values.
Map<String, PlaybookEntry> readPlaybook(String path) {
  final entries = <String, PlaybookEntry>{};
  late int code, partType, partName;
  streamCsvFile(
    path,
    onHeader: (header) {
      code = header.indexOf('LoincNumber');
      partType = header.indexOf('PartTypeName');
      partName = header.indexOf('PartName');
      if (code < 0 || partType < 0 || partName < 0) {
        throw FormatException('LoincNumber, PartTypeName or PartName missing from the Playbook', path);
      }
    },
    onRow: (row) {
      final number = CsvTable.cell(row, code).trim();
      if (number.isEmpty) return;
      final entry = entries[number] ??= PlaybookEntry();
      final value = CsvTable.cell(row, partName).trim();
      if (value.isEmpty || _unspecified.contains(value)) return;
      switch (CsvTable.cell(row, partType).trim()) {
        case playbookModality:
          entry.modalities.add(value);
        case playbookSubtype:
          entry.subtypes.add(value);
        case playbookRegion:
          entry.regions.add(value);
        case playbookFocus:
          entry.foci.add(value);
      }
    },
  );
  return entries;
}
