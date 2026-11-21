/// The medical catalog's API views (backend/docs/api-phase-3-catalogs.md):
/// versions (D0, AD20), custom items (BR-CAT9), doctor reports (BR-CAT8) and
/// specialty profiles (BR-CAT2–CAT4, AD19).
library;

/// The rows of each table in a catalog version.
class CatalogCounts {
  const CatalogCounts({this.drugs = 0, this.labs = 0, this.radiology = 0});

  factory CatalogCounts.fromJson(Map<String, dynamic>? json) => json == null
      ? const CatalogCounts()
      : CatalogCounts(
          drugs: (json['drugs'] as num?)?.toInt() ?? 0,
          labs: (json['labs'] as num?)?.toInt() ?? 0,
          radiology: (json['radiology'] as num?)?.toInt() ?? 0,
        );

  final int drugs;
  final int labs;
  final int radiology;

  Map<String, Object?> toJson() => {'drugs': drugs, 'labs': labs, 'radiology': radiology};
}

/// A published catalog version: `GET /api/catalog/current`,
/// `settings/public.catalog` and each row of AD20's list.
class CatalogVersionInfo {
  const CatalogVersionInfo({
    required this.version,
    required this.schemaVersion,
    required this.sha256,
    required this.sizeBytes,
    this.uncompressedSizeBytes,
    this.counts = const CatalogCounts(),
    this.drugSourceDate,
    this.loincRelease,
    this.publishedAt,
  });

  factory CatalogVersionInfo.fromJson(Map<String, dynamic> json) => CatalogVersionInfo(
    version: (json['version'] as num).toInt(),
    schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
    sha256: (json['sha256'] as String? ?? '').trim().toLowerCase(),
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    uncompressedSizeBytes: (json['uncompressedSizeBytes'] as num?)?.toInt(),
    counts: CatalogCounts.fromJson((json['counts'] as Map?)?.cast<String, dynamic>()),
    drugSourceDate: json['drugSourceDate'] as String?,
    loincRelease: json['loincRelease'] as String?,
    publishedAt: DateTime.tryParse('${json['publishedAt']}'),
  );

  /// The server's number; the file's own `meta.catalog_version` can differ.
  final int version;
  final int schemaVersion;

  /// Of the `.sqlite.gz` file, lower-case hex.
  final String sha256;

  /// Of the `.sqlite.gz` file.
  final int sizeBytes;

  /// The database once unpacked: the space it takes on the device (D0). Null
  /// from an API that doesn't say.
  final int? uncompressedSizeBytes;
  final CatalogCounts counts;

  /// `2026-06-20`.
  final String? drugSourceDate;

  /// `2.83`.
  final String? loincRelease;
  final DateTime? publishedAt;

  Map<String, Object?> toJson() => {
    'version': version,
    'schemaVersion': schemaVersion,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
    'uncompressedSizeBytes': uncompressedSizeBytes,
    'counts': counts.toJson(),
    'drugSourceDate': drugSourceDate,
    'loincRelease': loincRelease,
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
  };
}

/// AD20's list: `GET /api/admin/catalogVersions`.
class CatalogVersionEntry {
  const CatalogVersionEntry({required this.version, required this.current, this.publishedByName});

  factory CatalogVersionEntry.fromJson(Map<String, dynamic> json) => CatalogVersionEntry(
    version: CatalogVersionInfo.fromJson((json['version'] as Map).cast<String, dynamic>()),
    current: json['current'] == true,
    publishedByName: ((json['publishedBy'] as Map?)?['displayName']) as String?,
  );

  final CatalogVersionInfo version;

  /// The one apps download.
  final bool current;
  final String? publishedByName;
}

/// `drug`, `lab` or `radiology`: custom items (BR-CAT9) and test hits.
enum CatalogItemType {
  drug,
  lab,
  radiology;

  static CatalogItemType fromWire(Object? value) =>
      values.firstWhere((type) => type.name == value, orElse: () => CatalogItemType.drug);
}

/// An item the admin added for every doctor (BR-CAT9).
class CustomCatalogItem {
  const CustomCatalogItem({
    required this.customItemId,
    required this.type,
    required this.nameEn,
    this.nameAr,
    this.activeIngredient,
    this.drugGroupId,
    this.route,
    this.loincCode,
    this.aliases = const [],
    this.active = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomCatalogItem.fromJson(Map<String, dynamic> json) => CustomCatalogItem(
    customItemId: json['customItemId'] as String,
    type: CatalogItemType.fromWire(json['type']),
    nameEn: json['nameEn'] as String? ?? '',
    nameAr: _text(json['nameAr']),
    activeIngredient: _text(json['activeIngredient']),
    drugGroupId: _text(json['drugGroupId']),
    route: _text(json['route']),
    loincCode: _text(json['loincCode']),
    aliases: [for (final alias in (json['aliases'] as List?) ?? const []) '$alias'],
    active: json['active'] != false,
    createdAt: DateTime.tryParse('${json['createdAt']}'),
    updatedAt: DateTime.tryParse('${json['updatedAt']}'),
  );

  final String customItemId;
  final CatalogItemType type;
  final String nameEn;
  final String? nameAr;

  /// Medicines only.
  final String? activeIngredient;
  final String? drugGroupId;
  final String? route;

  /// Lab tests and radiology only.
  final String? loincCode;
  final List<String> aliases;

  /// False: disabled by the admin; devices drop it at the next sync.
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The prescription's `catalogId` for a custom medicine (BR-CAT7).
  String get catalogId => 'custom:$customItemId';

  Map<String, Object?> toJson() => {
    'customItemId': customItemId,
    'type': type.name,
    'nameEn': nameEn,
    'nameAr': nameAr,
    'activeIngredient': activeIngredient,
    'drugGroupId': drugGroupId,
    'route': route,
    'loincCode': loincCode,
    'aliases': aliases,
    'active': active,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}

/// What AD20 sends to `createCustomItem` and `updateCustomItem`.
class CustomItemDraft {
  const CustomItemDraft({
    required this.type,
    required this.nameEn,
    this.nameAr,
    this.activeIngredient,
    this.drugGroupId,
    this.route,
    this.loincCode,
    this.aliases = const [],
    this.active = true,
  });

  factory CustomItemDraft.of(CustomCatalogItem item) => CustomItemDraft(
    type: item.type,
    nameEn: item.nameEn,
    nameAr: item.nameAr,
    activeIngredient: item.activeIngredient,
    drugGroupId: item.drugGroupId,
    route: item.route,
    loincCode: item.loincCode,
    aliases: item.aliases,
    active: item.active,
  );

  final CatalogItemType type;
  final String nameEn;
  final String? nameAr;
  final String? activeIngredient;
  final String? drugGroupId;
  final String? route;
  final String? loincCode;
  final List<String> aliases;
  final bool active;

  CustomItemDraft copyWith({bool? active}) => CustomItemDraft(
    type: type,
    nameEn: nameEn,
    nameAr: nameAr,
    activeIngredient: activeIngredient,
    drugGroupId: drugGroupId,
    route: route,
    loincCode: loincCode,
    aliases: aliases,
    active: active ?? this.active,
  );

  /// The body without the type and id; the drug-only and test-only fields
  /// are left out for the other kind (the API refuses them).
  Map<String, Object?> toJson() {
    final drug = type == CatalogItemType.drug;
    return {
      'nameEn': nameEn.trim(),
      'nameAr': _text(nameAr),
      if (drug) ...{
        'activeIngredient': _text(activeIngredient),
        'drugGroupId': _text(drugGroupId),
        'route': _text(route),
      } else
        'loincCode': _text(loincCode),
      'aliases': [
        for (final alias in aliases)
          if (alias.trim().isNotEmpty) alias.trim(),
      ],
    };
  }
}

/// `GET /api/catalog/customItems?since=`: one page of changes.
class CustomItemSyncPage {
  const CustomItemSyncPage({required this.items, this.nextSince, this.hasMore = false});

  factory CustomItemSyncPage.fromJson(Map<String, dynamic> json) => CustomItemSyncPage(
    items: [
      for (final row in (json['items'] as List?) ?? const [])
        CustomCatalogItem.fromJson((row as Map).cast<String, dynamic>()),
    ],
    nextSince: json['nextSince'] as String?,
    hasMore: json['hasMore'] == true,
  );

  /// Oldest change first; inactive items included.
  final List<CustomCatalogItem> items;

  /// Sent back as `since`, exactly as the API wrote it.
  final String? nextSince;
  final bool hasMore;
}

/// `missing`, `wrong` or `other` (BR-CAT8).
enum CatalogReportType {
  missing,
  wrong,
  other;

  static CatalogReportType fromWire(Object? value) =>
      values.firstWhere((type) => type.name == value, orElse: () => CatalogReportType.other);
}

/// A doctor's "missing or wrong item" report [S] (AD20).
class CatalogReport {
  const CatalogReport({
    required this.reportId,
    required this.type,
    required this.text,
    this.itemRef,
    required this.done,
    required this.doctorName,
    required this.createdAt,
    this.handledAt,
  });

  factory CatalogReport.fromJson(Map<String, dynamic> json) => CatalogReport(
    reportId: json['reportId'] as String,
    type: CatalogReportType.fromWire(json['type']),
    text: json['text'] as String? ?? '',
    itemRef: _text(json['itemRef']),
    done: json['status'] == 'done',
    doctorName: json['doctorName'] as String? ?? '',
    createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    handledAt: DateTime.tryParse('${json['handledAt']}'),
  );

  final String reportId;
  final CatalogReportType type;
  final String text;

  /// `drug:123`, `loinc:2093-3` or `search:ketofan`.
  final String? itemRef;
  final bool done;
  final String doctorName;
  final DateTime createdAt;
  final DateTime? handledAt;
}

/// Profile item types (`SpecialtyProfileItems.ItemType`).
abstract final class ProfileItemType {
  static const drugGroup = 'drugGroup';
  static const route = 'route';
  static const labCode = 'labCode';
  static const radiologyRegion = 'radiologyRegion';
  static const radiologyModality = 'radiologyModality';
  static const radiologyCode = 'radiologyCode';
}

/// AD19's list: `GET /api/admin/specialties`, General first.
class SpecialtySummary {
  const SpecialtySummary({
    required this.specialtyId,
    required this.nameAr,
    required this.nameEn,
    this.active = true,
    this.isGeneral = false,
    this.includeGeneral = true,
    this.doctorCount = 0,
    this.itemCounts = const {},
  });

  factory SpecialtySummary.fromJson(Map<String, dynamic> json) => SpecialtySummary(
    specialtyId: json['specialtyId'] as String,
    nameAr: json['nameAr'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
    active: json['active'] != false,
    isGeneral: json['isGeneral'] == true,
    includeGeneral: json['includeGeneral'] == true,
    doctorCount: (json['doctorCount'] as num?)?.toInt() ?? 0,
    itemCounts: {
      for (final entry in ((json['itemCounts'] as Map?) ?? const {}).entries)
        '${entry.key}': (entry.value as num?)?.toInt() ?? 0,
    },
  );

  final String specialtyId;
  final String nameAr;
  final String nameEn;
  final bool active;

  /// The General profile (BR-CAT3), added to every specialty that includes it.
  final bool isGeneral;
  final bool includeGeneral;

  /// Doctors with it as their primary or an extra specialty.
  final int doctorCount;

  /// By [ProfileItemType].
  final Map<String, int> itemCounts;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}

/// One specialty's profile (AD19 editor).
class SpecialtyProfile {
  const SpecialtyProfile({
    required this.specialtyId,
    this.nameAr = '',
    this.nameEn = '',
    this.isGeneral = false,
    this.includeGeneral = true,
    this.drugGroups = const [],
    this.routes = const [],
    this.labCodes = const [],
    this.radiologyRegions = const [],
    this.radiologyModalities = const [],
    this.radiologyCodes = const [],
    this.updatedAt,
  });

  factory SpecialtyProfile.fromJson(Map<String, dynamic> json) => SpecialtyProfile(
    specialtyId: json['specialtyId'] as String,
    nameAr: json['nameAr'] as String? ?? '',
    nameEn: json['nameEn'] as String? ?? '',
    isGeneral: json['isGeneral'] == true,
    includeGeneral: json['includeGeneral'] == true,
    drugGroups: _strings(json['drugGroups']),
    routes: _strings(json['routes']),
    labCodes: _strings(json['labCodes']),
    radiologyRegions: _strings(json['radiologyRegions']),
    radiologyModalities: _strings(json['radiologyModalities']),
    radiologyCodes: _strings(json['radiologyCodes']),
    updatedAt: DateTime.tryParse('${json['updatedAt']}'),
  );

  final String specialtyId;
  final String nameAr;
  final String nameEn;
  final bool isGeneral;
  final bool includeGeneral;
  final List<String> drugGroups;
  final List<String> routes;
  final List<String> labCodes;
  final List<String> radiologyRegions;
  final List<String> radiologyModalities;
  final List<String> radiologyCodes;
  final DateTime? updatedAt;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;

  SpecialtyProfile copyWith({
    bool? includeGeneral,
    List<String>? drugGroups,
    List<String>? routes,
    List<String>? labCodes,
    List<String>? radiologyRegions,
    List<String>? radiologyModalities,
    List<String>? radiologyCodes,
  }) => SpecialtyProfile(
    specialtyId: specialtyId,
    nameAr: nameAr,
    nameEn: nameEn,
    isGeneral: isGeneral,
    includeGeneral: includeGeneral ?? this.includeGeneral,
    drugGroups: drugGroups ?? this.drugGroups,
    routes: routes ?? this.routes,
    labCodes: labCodes ?? this.labCodes,
    radiologyRegions: radiologyRegions ?? this.radiologyRegions,
    radiologyModalities: radiologyModalities ?? this.radiologyModalities,
    radiologyCodes: radiologyCodes ?? this.radiologyCodes,
    updatedAt: updatedAt,
  );

  /// `PUT /api/admin/specialties/{id}/profile`: every list replaced.
  Map<String, Object?> toRequestJson() => {
    'includeGeneral': includeGeneral,
    'drugGroups': drugGroups,
    'routes': routes,
    'labCodes': labCodes,
    'radiologyRegions': radiologyRegions,
    'radiologyModalities': radiologyModalities,
    'radiologyCodes': radiologyCodes,
  };

  /// How many values differ from [other], for the save bar.
  int changesFrom(SpecialtyProfile other) {
    int diff(List<String> a, List<String> b) {
      final left = a.toSet();
      final right = b.toSet();
      return left.difference(right).length + right.difference(left).length;
    }

    return (includeGeneral != other.includeGeneral && !isGeneral ? 1 : 0) +
        diff(drugGroups, other.drugGroups) +
        diff(routes, other.routes) +
        diff(labCodes, other.labCodes) +
        diff(radiologyRegions, other.radiologyRegions) +
        diff(radiologyModalities, other.radiologyModalities) +
        diff(radiologyCodes, other.radiologyCodes);
  }
}

/// What ranks a doctor's search first (BR-CAT4 "Your specialty"):
/// `GET /api/catalog/myProfile`, or in AD19's preview one specialty's
/// profile merged with General.
class CatalogProfile {
  const CatalogProfile({
    this.drugGroups = const {},
    this.routes = const {},
    this.labCodes = const {},
    this.radiologyRegions = const {},
    this.radiologyModalities = const {},
    this.radiologyCodes = const {},
    this.includesGeneral = false,
  });

  factory CatalogProfile.fromJson(Map<String, dynamic> json) => CatalogProfile(
    drugGroups: _strings(json['drugGroups']).toSet(),
    routes: _strings(json['routes']).toSet(),
    labCodes: _strings(json['labCodes']).toSet(),
    radiologyRegions: _strings(json['radiologyRegions']).toSet(),
    radiologyModalities: _strings(json['radiologyModalities']).toSet(),
    radiologyCodes: _strings(json['radiologyCodes']).toSet(),
    includesGeneral: json['includesGeneral'] == true,
  );

  /// [profile], plus [general]'s items when it includes General (AD19's
  /// preview: what a doctor of that specialty sees first).
  factory CatalogProfile.ofSpecialty(SpecialtyProfile profile, {SpecialtyProfile? general}) {
    final withGeneral = general != null && (profile.isGeneral || profile.includeGeneral);
    Set<String> both(List<String> own, List<String>? extra) => {...own, if (withGeneral) ...?extra};
    return CatalogProfile(
      drugGroups: both(profile.drugGroups, general?.drugGroups),
      routes: both(profile.routes, general?.routes),
      labCodes: both(profile.labCodes, general?.labCodes),
      radiologyRegions: both(profile.radiologyRegions, general?.radiologyRegions),
      radiologyModalities: both(profile.radiologyModalities, general?.radiologyModalities),
      radiologyCodes: both(profile.radiologyCodes, general?.radiologyCodes),
      includesGeneral: withGeneral,
    );
  }

  static const empty = CatalogProfile();

  final Set<String> drugGroups;

  /// [S] Preferred routes: they order results inside each section.
  final Set<String> routes;
  final Set<String> labCodes;
  final Set<String> radiologyRegions;
  final Set<String> radiologyModalities;
  final Set<String> radiologyCodes;
  final bool includesGeneral;

  bool get isEmpty =>
      drugGroups.isEmpty &&
      routes.isEmpty &&
      labCodes.isEmpty &&
      radiologyRegions.isEmpty &&
      radiologyModalities.isEmpty &&
      radiologyCodes.isEmpty;

  Map<String, Object?> toJson() => {
    'drugGroups': drugGroups.toList(),
    'routes': routes.toList(),
    'labCodes': labCodes.toList(),
    'radiologyRegions': radiologyRegions.toList(),
    'radiologyModalities': radiologyModalities.toList(),
    'radiologyCodes': radiologyCodes.toList(),
    'includesGeneral': includesGeneral,
  };
}

List<String> _strings(Object? value) => [for (final item in (value as List?) ?? const []) '$item'];

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
