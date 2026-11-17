import 'package:path/path.dart' as p;

import 'csv.dart';

/// The specialties the backend seeds, by their exact `NameEn`
/// (backend/src/El3yada.Data/Migrations/20261115123601_SeedReferenceData.cs),
/// plus `General` for the profile added to every specialty (BR-CAT3).
const knownSpecialties = {
  'General',
  'Internal Medicine',
  'Pediatrics',
  'Obstetrics and Gynecology',
  'Orthopedics',
  'Dermatology',
  'ENT',
  'Ophthalmology',
  'Cardiology',
  'Neurology',
  'Urology',
  'Chest and Pulmonology',
  'Gastroenterology and Hepatology',
  'Endocrinology and Diabetes',
  'Nephrology',
  'Psychiatry',
  'General Surgery',
  'Dentistry',
  'Physiotherapy',
  'General Practice',
};

/// Values allowed in SpecialtyProfileItems.ItemType (database CHECK
/// constraint CK_SpecialtyProfileItems_ItemType).
const profileItemTypes = {
  'drugGroup',
  'labCode',
  'radiologyRegion',
  'radiologyModality',
  'radiologyCode',
  'route',
};

class DrugGroup {
  const DrugGroup(this.id, this.nameEn, this.nameAr);
  final String id;
  final String nameEn;
  final String nameAr;
}

class FormToken {
  const FormToken(this.words, this.form, this.route);

  /// One or more upper-case words, e.g. ["EYE", "DROPS"].
  final List<String> words;
  final String form;

  /// When set, the token only applies to products with this route.
  final String? route;
}

class Alias {
  const Alias({
    required this.type,
    required this.code,
    required this.aliasEn,
    required this.nameAr,
    required this.priority,
  });

  /// `lab` or `radiology`.
  final String type;
  final String code;
  final String aliasEn;
  final String nameAr;
  final bool priority;
}

class ProfileItem {
  const ProfileItem(this.specialty, this.itemType, this.value);
  final String specialty;
  final String itemType;
  final String value;
}

/// A row of radiology-terms.csv: names and search words for a Playbook
/// modality, modality subtype, region or imaging focus.
class RadiologyTerm {
  const RadiologyTerm(this.kind, this.value, this.nameEn, this.nameAr, this.searchTerms);

  /// `modality`, `subtype`, `region` or `focus`.
  final String kind;
  final String value;
  final String nameEn;
  final String nameAr;
  final String searchTerms;
}

/// Everything in `mappings/`, read and checked for internal consistency.
/// Checks against the source data (unknown LOINC codes, unmapped classes)
/// happen later, in the build.
class Mappings {
  Mappings({
    required this.groups,
    required this.classToGroup,
    required this.formTokens,
    required this.routeToForm,
    required this.aliases,
    required this.profiles,
    required this.radiologyTerms,
  });

  /// Reads the mapping files in [dir]. Throws [FormatException] listing
  /// every problem found.
  factory Mappings.load(String dir) {
    final problems = <String>[];
    String file(String name) => p.join(dir, name);

    // groups.csv
    final groupsCsv = CsvTable.read(file('groups.csv'))..requireColumns(['id', 'name_en', 'name_ar']);
    final groups = <DrugGroup>[];
    final groupIds = <String>{};
    for (final row in groupsCsv.rows) {
      final id = CsvTable.cell(row, groupsCsv.column('id')).trim();
      final nameEn = CsvTable.cell(row, groupsCsv.column('name_en')).trim();
      final nameAr = CsvTable.cell(row, groupsCsv.column('name_ar')).trim();
      if (id.isEmpty || nameEn.isEmpty || nameAr.isEmpty) {
        problems.add('groups.csv: every group needs an id, an English and an Arabic name ($row)');
        continue;
      }
      if (!groupIds.add(id)) problems.add('groups.csv: duplicate id "$id"');
      groups.add(DrugGroup(id, nameEn, nameAr));
    }
    if (!groupIds.contains('other')) problems.add('groups.csv: the "other" group is missing');

    // class-to-group.csv: raw_drug_class, group_id, optional route
    final classCsv = CsvTable.read(file('class-to-group.csv'))..requireColumns(['raw_drug_class', 'group_id']);
    final hasRoute = classCsv.hasColumn('route');
    final classToGroup = <(String, String), String>{};
    for (final row in classCsv.rows) {
      final rawClass = CsvTable.cell(row, classCsv.column('raw_drug_class')).trim();
      final group = CsvTable.cell(row, classCsv.column('group_id')).trim();
      final route = hasRoute ? CsvTable.cell(row, classCsv.column('route')).trim() : '';
      if (!groupIds.contains(group)) {
        problems.add('class-to-group.csv: "$rawClass" points to unknown group "$group"');
      }
      final key = (rawClass, route);
      final previous = classToGroup[key];
      if (previous != null && previous != group) {
        problems.add('class-to-group.csv: "$rawClass" (route "$route") is mapped twice: $previous and $group');
      }
      classToGroup[key] = group;
    }

    // form-tokens.csv: token, form, optional route
    final formCsv = CsvTable.read(file('form-tokens.csv'))..requireColumns(['token', 'form']);
    final formHasRoute = formCsv.hasColumn('route');
    final formTokens = <FormToken>[];
    final seenTokens = <String>{};
    for (final row in formCsv.rows) {
      final token = CsvTable.cell(row, formCsv.column('token')).trim().toUpperCase();
      final form = CsvTable.cell(row, formCsv.column('form')).trim();
      final route = formHasRoute ? CsvTable.cell(row, formCsv.column('route')).trim() : '';
      final words = token.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      if (words.isEmpty || form.isEmpty || words.any((w) => !RegExp(r'^[A-Z]+$').hasMatch(w))) {
        problems.add('form-tokens.csv: a token is letters only and needs a form ($row)');
        continue;
      }
      if (!seenTokens.add('${words.join(' ')}|$route')) {
        problems.add('form-tokens.csv: "$token" (route "$route") is listed twice');
      }
      formTokens.add(FormToken(words, form, route.isEmpty ? null : route));
    }

    // route-to-form.csv: route, default_form (empty = no suggestion)
    final routeCsv = CsvTable.read(file('route-to-form.csv'))..requireColumns(['route', 'default_form']);
    final routeToForm = <String, String>{};
    for (final row in routeCsv.rows) {
      final route = CsvTable.cell(row, routeCsv.column('route')).trim();
      final form = CsvTable.cell(row, routeCsv.column('default_form')).trim();
      if (route.isEmpty) continue;
      if (routeToForm.containsKey(route)) problems.add('route-to-form.csv: route "$route" is listed twice');
      routeToForm[route] = form;
    }

    // aliases.csv: type, code, alias_en, name_ar, priority
    final aliasCsv = CsvTable.read(file('aliases.csv'))
      ..requireColumns(['type', 'code', 'alias_en', 'name_ar', 'priority']);
    final aliases = <Alias>[];
    for (final row in aliasCsv.rows) {
      final type = CsvTable.cell(row, aliasCsv.column('type')).trim();
      final code = CsvTable.cell(row, aliasCsv.column('code')).trim();
      final aliasEn = CsvTable.cell(row, aliasCsv.column('alias_en')).trim();
      final nameAr = CsvTable.cell(row, aliasCsv.column('name_ar')).trim();
      final priority = CsvTable.cell(row, aliasCsv.column('priority')).trim();
      if (type != 'lab' && type != 'radiology') {
        problems.add('aliases.csv: type must be "lab" or "radiology" ($row)');
        continue;
      }
      if (!RegExp(r'^\d{1,7}-\d$').hasMatch(code)) {
        problems.add('aliases.csv: "$code" is not a LOINC code');
        continue;
      }
      if (aliasEn.isEmpty && nameAr.isEmpty) {
        problems.add('aliases.csv: $code has neither an English alias nor an Arabic name');
      }
      if (priority != '0' && priority != '1') problems.add('aliases.csv: priority must be 0 or 1 ($row)');
      aliases.add(Alias(type: type, code: code, aliasEn: aliasEn, nameAr: nameAr, priority: priority == '1'));
    }

    // specialty-profiles.csv: specialty_name_en, item_type, value
    final profileCsv = CsvTable.read(file('specialty-profiles.csv'))
      ..requireColumns(['specialty_name_en', 'item_type', 'value']);
    final profiles = <ProfileItem>[];
    final seenProfileItems = <String>{};
    for (final row in profileCsv.rows) {
      final specialty = CsvTable.cell(row, profileCsv.column('specialty_name_en')).trim();
      final itemType = CsvTable.cell(row, profileCsv.column('item_type')).trim();
      final value = CsvTable.cell(row, profileCsv.column('value')).trim();
      if (!knownSpecialties.contains(specialty)) {
        problems.add('specialty-profiles.csv: unknown specialty "$specialty"');
      }
      if (!profileItemTypes.contains(itemType)) {
        problems.add('specialty-profiles.csv: item_type "$itemType" is not allowed');
      }
      if (value.isEmpty || value.length > 100) {
        problems.add('specialty-profiles.csv: value must have 1 to 100 characters ($row)');
      }
      if (!seenProfileItems.add('$specialty|$itemType|$value')) {
        problems.add('specialty-profiles.csv: duplicate row $specialty, $itemType, $value');
      }
      if (itemType == 'drugGroup' && !groupIds.contains(value)) {
        problems.add('specialty-profiles.csv: $specialty uses unknown drug group "$value"');
      }
      profiles.add(ProfileItem(specialty, itemType, value));
    }

    // radiology-terms.csv: kind, value, name_en, name_ar, search_terms
    final termsCsv = CsvTable.read(file('radiology-terms.csv'))
      ..requireColumns(['kind', 'value', 'name_en', 'name_ar', 'search_terms']);
    final radiologyTerms = <RadiologyTerm>[];
    final seenTerms = <String>{};
    for (final row in termsCsv.rows) {
      final kind = CsvTable.cell(row, termsCsv.column('kind')).trim();
      final value = CsvTable.cell(row, termsCsv.column('value')).trim();
      if (!const {'modality', 'subtype', 'region', 'focus'}.contains(kind) || value.isEmpty) {
        problems.add('radiology-terms.csv: kind must be modality, subtype, region or focus, with a value ($row)');
        continue;
      }
      if (!seenTerms.add('$kind|$value')) problems.add('radiology-terms.csv: $kind "$value" is listed twice');
      radiologyTerms.add(RadiologyTerm(
        kind,
        value,
        CsvTable.cell(row, termsCsv.column('name_en')).trim(),
        CsvTable.cell(row, termsCsv.column('name_ar')).trim(),
        CsvTable.cell(row, termsCsv.column('search_terms')).trim(),
      ));
    }

    if (problems.isNotEmpty) {
      throw FormatException('Problems in the mapping files:\n  ${problems.join('\n  ')}');
    }
    return Mappings(
      groups: groups,
      classToGroup: classToGroup,
      formTokens: formTokens,
      routeToForm: routeToForm,
      aliases: aliases,
      profiles: profiles,
      radiologyTerms: radiologyTerms,
    );
  }

  final List<DrugGroup> groups;

  /// (raw class, route) → group id. A route of '' applies to every route.
  final Map<(String, String), String> classToGroup;
  final List<FormToken> formTokens;
  final Map<String, String> routeToForm;
  final List<Alias> aliases;
  final List<ProfileItem> profiles;
  final List<RadiologyTerm> radiologyTerms;

  /// The group for a product's raw class and route, or null when the class
  /// is not in class-to-group.csv.
  String? groupFor(String rawClass, String route) =>
      classToGroup[(rawClass.trim(), route)] ?? classToGroup[(rawClass.trim(), '')];
}
