import 'dart:io';

import 'package:catalog_builder/catalog_builder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'paths.dart';

/// The group ids listed in spec Appendix A.3.6.
const specGroupIds = [
  'analgesics', 'nsaids', 'muscle_relaxants', 'antibiotics', 'antivirals', 'antifungals', 'antiparasitics', //
  'gastric_acid', 'antiemetics', 'laxatives', 'antidiarrheals', 'antispasmodics', 'hepatoprotectives',
  'antihypertensives', 'diuretics', 'lipid_lowering', 'antiplatelets', 'anticoagulants', 'antiarrhythmics',
  'antianginals', 'heart_failure', 'antidiabetics_oral', 'insulins', 'thyroid', 'corticosteroids', 'sex_hormones',
  'fertility', 'osteoporosis', 'vitamins', 'iron_folic', 'antihistamines', 'cold_flu', 'cough',
  'respiratory_inhaled', 'nasal', 'ear', 'eye', 'antiglaucoma', 'topical_steroids', 'anti_acne', 'skin_other',
  'antiepileptics', 'antiparkinson', 'migraine', 'neuropathic', 'antipsychotics', 'antidepressants',
  'anxiolytics_hypnotics', 'mood_stabilizers', 'prostate_urinary', 'urinary_antiseptics', 'erectile', 'gout',
  'dmards', 'antineoplastics', 'vaccines', 'iv_fluids', 'ors', 'local_anesthetics', 'oral_dental', 'supplements',
  'cosmetics', 'other',
];

void main() {
  final mappings = Mappings.load(realMappings);

  group('the committed mapping files', () {
    test('keep every group of spec A.3.6, with English and Arabic names', () {
      final ids = mappings.groups.map((g) => g.id).toSet();
      expect(ids, containsAll(specGroupIds));
      expect(mappings.groups.length, inInclusiveRange(60, 75));
      for (final g in mappings.groups) {
        expect(RegExp(r'[؀-ۿ]').hasMatch(g.nameAr), isTrue, reason: '${g.id} needs an Arabic name');
      }
    });

    test('use every group somewhere in class-to-group.csv', () {
      final used = mappings.classToGroup.values.toSet();
      final unused = mappings.groups.map((g) => g.id).where((id) => !used.contains(id)).toList();
      expect(unused, isEmpty);
    });

    test('give every seeded specialty and General a profile with medicine groups', () {
      for (final specialty in knownSpecialties) {
        final groups = mappings.profiles.where((i) => i.specialty == specialty && i.itemType == 'drugGroup');
        expect(groups, isNotEmpty, reason: specialty);
      }
    });

    test('only use the item types the database accepts', () {
      expect(mappings.profiles.map((i) => i.itemType).toSet(), everyElement(isIn(profileItemTypes)));
    });
  });

  group('class mapping coverage on the real drug dataset', () {
    final csv = realDrugCsv();
    final skip = csv == null ? 'the drug CSV is not in sources/drugs (it is not committed)' : false;

    test('maps every distinct drug_class', () {
      final table = CsvTable.read(csv!);
      final classes = {for (final row in table.rows) CsvTable.cell(row, table.column('drug_class')).trim()};
      final unmapped = classes.where((c) => !mappings.classToGroup.containsKey((c, ''))).toList();
      expect(unmapped, isEmpty, reason: 'add these to class-to-group.csv');
    }, skip: skip);

    test('leaves at most 5% of the products in "other" (A.8)', () {
      final drugs = readDrugs(csv!, mappings).drugs;
      assignGroups(drugs, mappings);
      final other = drugs.where((d) => d.groupId == 'other').length;
      expect(other / drugs.length, lessThanOrEqualTo(0.05));
    }, skip: skip);
  });

  group('validation', () {
    late Directory dir;
    setUp(() => dir = copyToTemp(fixtureMappings));
    tearDown(() => dir.deleteSync(recursive: true));

    void append(String file, String line) =>
        File(p.join(dir.path, file)).writeAsStringSync('$line\n', mode: FileMode.append);

    test('rejects unknown specialties, item types and groups', () {
      append('specialty-profiles.csv', 'Astrology,drugGroup,analgesics');
      append('specialty-profiles.csv', 'Cardiology,favouriteColour,red');
      append('specialty-profiles.csv', 'Cardiology,drugGroup,no_such_group');
      expect(
        () => Mappings.load(dir.path),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', contains('unknown specialty "Astrology"'))
              .having((e) => e.message, 'message', contains('item_type "favouriteColour"'))
              .having((e) => e.message, 'message', contains('unknown drug group "no_such_group"')),
        ),
      );
    });

    test('rejects a class mapped twice to different groups', () {
      append('class-to-group.csv', 'ANTIPYRETIC,nsaids,');
      expect(
        () => Mappings.load(dir.path),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('mapped twice'))),
      );
    });

    test('rejects an alias that is not a LOINC code', () {
      append('aliases.csv', 'lab,CBC,CBC,,1');
      expect(
        () => Mappings.load(dir.path),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('not a LOINC code'))),
      );
    });
  });
}
