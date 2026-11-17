import 'dart:io';

import 'package:catalog_core/catalog_core.dart';
import 'package:sqlite3/sqlite3.dart';

/// A small catalog file in the real schema (catalog_core), for the offline
/// mode (`USE_FAKE_AUTH`) and tests. It is filled the way the catalog builder
/// fills the real one (tools/catalog-builder/lib/src/database.dart): the same
/// tables, and full-text columns made with `normalizeAndDedupe` and
/// `withArabicSkeletons`.
///
/// The medicines are real Egyptian brands (the drug dataset is CC0). The lab
/// and radiology rows are **not LOINC content**: their codes (99xxx) and
/// English names are made up, like the builder's test fixture, so no LOINC
/// text is ever committed (spec A.7).
class SampleCatalog {
  const SampleCatalog({
    this.catalogVersion = 1,
    this.schemaVersion = catalogSchemaVersion,
    this.drugSourceDate = '2026-06-20',
    this.loincRelease = 'sample',
    this.groups = sampleGroups,
    this.drugs = sampleDrugs,
    this.labs = sampleLabs,
    this.radiology = sampleRadiology,
    this.modalities = sampleModalities,
  });

  final int catalogVersion;
  final int schemaVersion;
  final String drugSourceDate;
  final String loincRelease;
  final List<SampleGroup> groups;
  final List<SampleDrug> drugs;
  final List<SampleTest> labs;
  final List<SampleTest> radiology;
  final List<SampleGroup> modalities;

  /// Writes the catalog to a new file at [path].
  void writeTo(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA journal_mode = OFF');
      for (final statement in CatalogSchema.createStatements) {
        db.execute(statement);
      }
      db.execute('BEGIN');
      _insert(db);
      db.execute('COMMIT');
      db.execute('PRAGMA journal_mode = DELETE');
    } finally {
      db.close();
    }
  }

  void _insert(Database db) {
    db.execute('INSERT INTO ${MetaTable.name} VALUES (?, ?, ?, ?, ?)', [
      schemaVersion,
      catalogVersion,
      DateTime.utc(2026, 11, 17).toIso8601String(),
      drugSourceDate,
      loincRelease,
    ]);
    for (final group in groups) {
      db.execute('INSERT INTO ${DrugGroupsTable.name} VALUES (?, ?, ?)', [group.id, group.nameEn, group.nameAr]);
    }
    for (final (index, drug) in drugs.indexed) {
      final id = index + 1;
      db.execute('INSERT INTO ${DrugsTable.name} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        id,
        drug.tradeNameEn,
        drug.tradeNameAr,
        drug.activeIngredient,
        drug.manufacturer,
        drug.groupId,
        drug.route,
        drug.form,
        parseStrength(drug.tradeNameEn),
        drug.priceEgp,
        drug.status,
      ]);
      db.execute('INSERT INTO ${FtsTables.drugs}(rowid, name, ingredient) VALUES (?, ?, ?)', [
        id,
        withArabicSkeletons(normalizeAndDedupe([drug.tradeNameEn, drug.tradeNameAr])),
        normalizeAndDedupe([drug.activeIngredient]),
      ]);
    }
    for (final lab in labs) {
      final id = loincToId(lab.code);
      db.execute('INSERT INTO ${LabTestsTable.name} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        id,
        lab.code,
        lab.nameEn,
        lab.shortName,
        lab.nameAr,
        lab.aliases.isEmpty ? null : lab.aliases.join('; '),
        lab.loincClass,
        lab.priority,
        lab.orderRank,
      ]);
      _insertFts(db, FtsTables.labs, id, lab, const []);
    }
    for (final procedure in radiology) {
      final id = loincToId(procedure.code);
      db.execute('INSERT INTO ${RadiologyTable.name} VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', [
        id,
        procedure.code,
        procedure.nameEn,
        procedure.nameAr,
        procedure.modality,
        procedure.region,
        procedure.aliases.isEmpty ? null : procedure.aliases.join('; '),
        null,
        procedure.focus,
        procedure.priority,
      ]);
      final terms = [
        for (final modality in modalities)
          if ((procedure.modality ?? '').split(';').contains(modality.id)) ...[modality.nameEn, modality.nameAr],
      ];
      _insertFts(db, FtsTables.radiology, id, procedure, terms);
    }
    for (final modality in modalities) {
      db.execute('INSERT INTO ${ModalitiesTable.name} VALUES (?, ?, ?)', [
        modality.id,
        modality.nameEn,
        modality.nameAr,
      ]);
    }
  }

  void _insertFts(Database db, String table, int id, SampleTest test, List<String> terms) {
    final name = normalizeAndDedupe([test.nameEn, test.shortName]);
    final taken = name.split(' ').toSet();
    final alias = withArabicSkeletons(
      normalizeAndDedupe([...test.aliases, test.nameAr, ...test.searchTerms, ...terms]),
    ).split(' ').where((word) => word.isNotEmpty && !taken.contains(word)).join(' ');
    db.execute('INSERT INTO $table(rowid, name, alias, related) VALUES (?, ?, ?, ?)', [id, name, alias, '']);
  }
}

class SampleGroup {
  const SampleGroup(this.id, this.nameEn, this.nameAr);

  final String id;
  final String nameEn;
  final String nameAr;
}

class SampleDrug {
  const SampleDrug(
    this.tradeNameEn,
    this.tradeNameAr,
    this.activeIngredient,
    this.manufacturer,
    this.groupId,
    this.route,
    this.form, {
    this.status = DrugStatus.available,
    this.priceEgp,
  });

  final String tradeNameEn;
  final String? tradeNameAr;
  final String activeIngredient;
  final String manufacturer;
  final String groupId;
  final String route;
  final String? form;
  final int status;
  final double? priceEgp;
}

class SampleTest {
  const SampleTest(
    this.code,
    this.nameEn, {
    this.shortName,
    this.nameAr,
    this.aliases = const [],
    this.searchTerms = const [],
    this.loincClass,
    this.priority = CatalogPriority.none,
    this.orderRank,
    this.modality,
    this.region,
    this.focus,
  });

  final String code;
  final String nameEn;
  final String? shortName;
  final String? nameAr;
  final List<String> aliases;

  /// More words to index (Arabic synonyms).
  final List<String> searchTerms;
  final String? loincClass;
  final int priority;
  final int? orderRank;
  final String? modality;
  final String? region;
  final String? focus;
}

const sampleGroups = [
  SampleGroup('analgesics', 'Analgesics & antipyretics', 'مسكنات وخافض للحرارة'),
  SampleGroup('nsaids', 'NSAIDs', 'مضادات الالتهاب غير الستيرويدية'),
  SampleGroup('antibiotics', 'Antibiotics', 'مضادات حيوية'),
  SampleGroup('gastric_acid', 'Antacids, PPIs & H2 blockers', 'مضادات الحموضة وحماية المعدة'),
  SampleGroup('antihypertensives', 'Antihypertensives', 'أدوية الضغط'),
  SampleGroup('lipid_lowering', 'Lipid-lowering drugs', 'أدوية الكوليسترول والدهون'),
  SampleGroup('antiplatelets', 'Antiplatelets', 'مضادات الصفائح الدموية'),
  SampleGroup('antidiabetics_oral', 'Oral antidiabetics', 'أدوية السكر بالفم'),
  SampleGroup('vitamins', 'Vitamins & minerals', 'فيتامينات ومعادن'),
  SampleGroup('antihistamines', 'Antihistamines', 'مضادات الحساسية'),
  SampleGroup('cold_flu', 'Cold & flu products', 'أدوية البرد والإنفلونزا'),
  SampleGroup('topical_steroids', 'Topical corticosteroids', 'كريمات الكورتيزون'),
  SampleGroup('other', 'Other', 'أخرى'),
];

const sampleDrugs = [
  SampleDrug(
    'PANADOL 500 MG 24 TABS.',
    'بانادول',
    'PARACETAMOL(ACETAMINOPHEN)',
    'GSK',
    'analgesics',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'PANADOL EXTRA 24 F.C.TABS.',
    'بانادول اكسترا',
    'PARACETAMOL+CAFFEINE',
    'GSK',
    'analgesics',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'PANADOL COLD & FLU 24 TABS.',
    'بانادول كولد اند فلو',
    'PARACETAMOL+PSEUDOEPHEDRINE',
    'GSK',
    'cold_flu',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'ABIMOL 500 MG 20 TABS.',
    'ابيمول',
    'PARACETAMOL(ACETAMINOPHEN)',
    'Pharco',
    'analgesics',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'CETAL 250MG/5ML SYRUP 100 ML',
    'سيتال',
    'PARACETAMOL(ACETAMINOPHEN)',
    'EIPICO',
    'analgesics',
    'ORAL.LIQUID',
    'Syrup',
  ),
  SampleDrug(
    'PARAMOL 125 MG 5 SUPP.',
    'بارامول',
    'PARACETAMOL(ACETAMINOPHEN)',
    'Pharco',
    'analgesics',
    'RECTAL',
    'Suppository',
    status: DrugStatus.notAvailableYet,
  ),
  SampleDrug(
    'LIPITOR 20 MG 30 F.C.TABS.',
    'ليبيتور',
    'ATORVASTATIN',
    'Pfizer',
    'lipid_lowering',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug('ATOR 20 MG 30 F.C.TABS.', 'اتور', 'ATORVASTATIN', 'EIPICO', 'lipid_lowering', 'ORAL.SOLID', 'Tablet'),
  SampleDrug(
    'ATORSTAT 40 MG 10 TABS.',
    'اتورستات',
    'ATORVASTATIN',
    'Delta Pharma',
    'lipid_lowering',
    'ORAL.SOLID',
    'Tablet',
    status: DrugStatus.notAvailable,
  ),
  SampleDrug(
    'LIPONORM 10 MG 30 TABS.',
    'ليبونورم',
    'ATORVASTATIN',
    'Minapharm',
    'lipid_lowering',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'CRESTOR 10 MG 28 F.C.TABS.',
    'كريستور',
    'ROSUVASTATIN',
    'AstraZeneca',
    'lipid_lowering',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'GASTRAZOLE 20 MG 14 CAPS.',
    'جاسترازول',
    'OMEPRAZOLE',
    'Global Napi',
    'gastric_acid',
    'ORAL.SOLID',
    'Capsule',
  ),
  SampleDrug('RISEK 20 MG 14 CAPS.', 'ريسك', 'OMEPRAZOLE', 'Julphar', 'gastric_acid', 'ORAL.SOLID', 'Capsule'),
  SampleDrug('O.P.Z 40 MG 14 CAPS.', 'او بي زد', 'OMEPRAZOLE', 'Sedico', 'gastric_acid', 'ORAL.SOLID', 'Capsule'),
  SampleDrug('CONCOR 5 MG 30 F.C.TABS.', 'كونكور', 'BISOPROLOL', 'Merck', 'antihypertensives', 'ORAL.SOLID', 'Tablet'),
  SampleDrug(
    'ASPOCID 75 MG 30 TABS.',
    'اسبوسيد',
    'ACETYLSALICYLIC ACID',
    'CID',
    'antiplatelets',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'AUGMENTIN 1 GM 14 F.C.TABS.',
    'اوجمنتين',
    'AMOXICILLIN+CLAVULANIC ACID',
    'GSK',
    'antibiotics',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'AUGMENTIN 457MG/5ML SUSP. 70 ML',
    'اوجمنتين',
    'AMOXICILLIN+CLAVULANIC ACID',
    'GSK',
    'antibiotics',
    'ORAL.LIQUID',
    'Suspension',
  ),
  SampleDrug('BRUFEN 400 MG 30 F.C.TABS.', 'بروفين', 'IBUPROFEN', 'Abbott', 'nsaids', 'ORAL.SOLID', 'Tablet'),
  SampleDrug(
    'CATAFLAM 50 MG 20 TABS.',
    'كتافلام',
    'DICLOFENAC POTASSIUM',
    'Novartis',
    'nsaids',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug(
    'GLUCOPHAGE 500 MG 50 F.C.TABS.',
    'جلوكوفاج',
    'METFORMIN',
    'Merck',
    'antidiabetics_oral',
    'ORAL.SOLID',
    'Tablet',
  ),
  SampleDrug('CLARITINE 10 MG 20 TABS.', 'كلاريتين', 'LORATADINE', 'Bayer', 'antihistamines', 'ORAL.SOLID', 'Tablet'),
  SampleDrug('DERMOVATE 0.05% CREAM 25 GM', 'ديرموفيت', 'CLOBETASOL', 'GSK', 'topical_steroids', 'TOPICAL', 'Cream'),
  SampleDrug(
    'VIDROP 2800 IU/ML ORAL DROPS 15 ML',
    'فيدروب',
    'CHOLECALCIFEROL',
    'Medical Union',
    'vitamins',
    'ORAL.LIQUID',
    'Oral drops',
  ),
];

const sampleLabs = [
  SampleTest(
    '99001-0',
    'Complete blood count panel - Blood',
    shortName: 'Blood count panel',
    nameAr: 'صورة دم كاملة',
    aliases: ['CBC'],
    searchTerms: ['صورة دم'],
    loincClass: 'PANEL.HEM/BC',
    priority: CatalogPriority.egypt,
    orderRank: 1,
  ),
  SampleTest(
    '99002-8',
    'White cell differential count - Blood',
    shortName: 'Differential count',
    loincClass: 'HEM/BC',
    priority: CatalogPriority.common,
    orderRank: 40,
  ),
  SampleTest(
    '99003-6',
    'Glycated hemoglobin - Blood',
    shortName: 'Glycated Hb',
    nameAr: 'سكر تراكمي',
    aliases: ['HbA1c'],
    searchTerms: ['هيموجلوبين سكري'],
    loincClass: 'CHEM',
    priority: CatalogPriority.egypt,
    orderRank: 5,
  ),
  SampleTest(
    '99004-4',
    'Glucose after fasting - Serum or Plasma',
    shortName: 'Fasting glucose',
    nameAr: 'سكر صائم',
    aliases: ['FBS'],
    loincClass: 'CHEM',
    priority: CatalogPriority.egypt,
    orderRank: 3,
  ),
  SampleTest(
    '99005-1',
    'Thyrotropin - Serum',
    shortName: 'Thyrotropin',
    nameAr: 'هرمون الغدة الدرقية',
    aliases: ['TSH'],
    loincClass: 'CHEM',
    priority: CatalogPriority.egypt,
    orderRank: 7,
  ),
  SampleTest(
    '99006-9',
    'Lipid panel - Serum',
    shortName: 'Lipid panel',
    nameAr: 'دهون الدم',
    aliases: ['Lipid profile'],
    loincClass: 'PANEL.CHEM',
    priority: CatalogPriority.egypt,
    orderRank: 4,
  ),
  SampleTest(
    '99007-7',
    'Cardiac troponin T - Serum',
    shortName: 'Troponin T',
    nameAr: 'تروبونين',
    aliases: ['Troponin'],
    loincClass: 'CHEM',
    priority: CatalogPriority.common,
    orderRank: 60,
  ),
  SampleTest(
    '99008-5',
    'Creatinine - Serum or Plasma',
    shortName: 'Creatinine',
    nameAr: 'كرياتينين',
    loincClass: 'CHEM',
    priority: CatalogPriority.common,
    orderRank: 2,
  ),
  SampleTest(
    '99009-3',
    'Alanine aminotransferase - Serum',
    shortName: 'ALT',
    nameAr: 'إنزيم الكبد ALT',
    aliases: ['SGPT'],
    loincClass: 'CHEM',
    priority: CatalogPriority.common,
    orderRank: 6,
  ),
  SampleTest(
    '99010-1',
    'Urinalysis complete panel - Urine',
    shortName: 'Urinalysis panel',
    nameAr: 'تحليل بول كامل',
    aliases: ['Urine analysis'],
    loincClass: 'PANEL.UA',
    priority: CatalogPriority.egypt,
    orderRank: 8,
  ),
  SampleTest(
    '99011-9',
    'C reactive protein - Serum',
    shortName: 'CRP',
    nameAr: 'بروتين سي التفاعلي',
    aliases: ['CRP'],
    loincClass: 'CHEM',
    priority: CatalogPriority.common,
    orderRank: 20,
  ),
  SampleTest(
    '99012-7',
    'Vitamin D 25-hydroxy - Serum',
    shortName: '25-OH vitamin D',
    nameAr: 'فيتامين د',
    aliases: ['Vit D'],
    loincClass: 'CHEM',
    priority: CatalogPriority.common,
    orderRank: 30,
  ),
];

const sampleRadiology = [
  SampleTest(
    '99101-8',
    'Chest X-ray, 2 views',
    nameAr: 'أشعة عادية على الصدر',
    aliases: ['CXR'],
    searchTerms: ['صدر'],
    modality: 'XR',
    region: 'Chest',
    priority: CatalogPriority.egypt,
  ),
  SampleTest(
    '99102-6',
    'Abdominal ultrasound',
    nameAr: 'سونار على البطن',
    searchTerms: ['بطن'],
    modality: 'US',
    region: 'Abdomen',
    priority: CatalogPriority.egypt,
  ),
  SampleTest(
    '99103-4',
    'Echocardiography',
    nameAr: 'إيكو على القلب',
    aliases: ['Echo'],
    searchTerms: ['قلب'],
    modality: 'US',
    region: 'Chest',
    focus: 'Heart',
    priority: CatalogPriority.egypt,
  ),
  SampleTest(
    '99104-2',
    'CT brain without contrast',
    nameAr: 'أشعة مقطعية على المخ',
    searchTerms: ['مخ'],
    modality: 'CT',
    region: 'Head',
    focus: 'Brain',
  ),
  SampleTest(
    '99105-9',
    'MRI lumbar spine without contrast',
    nameAr: 'رنين على الفقرات القطنية',
    searchTerms: ['ظهر'],
    modality: 'MR',
    region: 'Abdomen',
    focus: 'Spine.lumbar',
  ),
  SampleTest(
    '99106-7',
    'Knee X-ray, 3 views',
    nameAr: 'أشعة عادية على الركبة',
    searchTerms: ['ركبة'],
    modality: 'XR',
    region: 'Lower extremity',
    focus: 'Knee',
  ),
  SampleTest('99107-5', 'Mammography, both breasts', nameAr: 'ماموجرام', modality: 'MG', region: 'Breast'),
  SampleTest(
    '99108-3',
    'Pelvic ultrasound',
    nameAr: 'سونار على الحوض',
    searchTerms: ['حوض'],
    modality: 'US',
    region: 'Pelvis',
  ),
  SampleTest(
    '99109-1',
    'Bone density scan (DXA)',
    nameAr: 'قياس كثافة العظام',
    modality: 'DXA',
    focus: 'Hip;Spine.lumbar',
  ),
  SampleTest(
    '99110-9',
    'CT coronary angiography',
    nameAr: 'أشعة مقطعية على الشرايين التاجية',
    modality: 'CT',
    region: 'Chest',
    focus: 'Coronary arteries',
  ),
];

const sampleModalities = [
  SampleGroup('XR', 'X-ray', 'أشعة عادية'),
  SampleGroup('US', 'Ultrasound', 'سونار'),
  SampleGroup('CT', 'CT', 'أشعة مقطعية'),
  SampleGroup('MR', 'MRI', 'رنين مغناطيسي'),
  SampleGroup('MG', 'Mammography', 'ماموجرام'),
  SampleGroup('DXA', 'Bone densitometry', 'قياس كثافة العظام'),
];
