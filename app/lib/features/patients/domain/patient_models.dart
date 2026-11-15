import '../../sessions/domain/session_models.dart';

export '../../sessions/domain/session_models.dart' show LastVisit, Paged, SessionType;

/// Models for patients, the medical profile and the register (D4–D7, AS2–AS4).
/// The contract is backend/docs/api-phase-2-patients.md; the API's
/// `Patients/PatientViews.cs` is the source of truth.
///
/// A field the caller may not see arrives as `null` and the screens hide it
/// (spec 7.6, AS18): `totalPaidPiasters` needs `revenueView`, `hasAllergies`
/// and `chronicDiseases` need `clinicalView`.

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();
DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);
Map<String, dynamic> _map(Object? value) => (value as Map).cast<String, dynamic>();
String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;

enum Gender {
  male,
  female;

  static Gender fromWire(Object? value) => value == 'female' ? female : male;

  String get wire => name;
}

/// `Patients.BloodType` values.
const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// This doctor's visits of one patient (non-deleted sessions only, BR-P3).
class PatientVisits {
  const PatientVisits({
    this.firstVisitAt,
    this.lastVisit,
    this.total = 0,
    this.examinations = 0,
    this.consultations = 0,
    this.consultationsSinceExam = 0,
  });

  factory PatientVisits.fromJson(Map<String, dynamic> json) => PatientVisits(
    firstVisitAt: _timeOrNull(json['firstVisitAt']),
    lastVisit: json['lastVisit'] == null ? null : LastVisit.fromJson(_map(json['lastVisit'])),
    total: json['total'] as int,
    examinations: json['examinations'] as int,
    consultations: json['consultations'] as int,
    consultationsSinceExam: json['consultationsSinceExam'] as int,
  );

  final DateTime? firstVisitAt;
  final LastVisit? lastVisit;
  final int total;
  final int examinations;
  final int consultations;
  final int consultationsSinceExam;
}

/// The D6 header and file summary (`GET /api/patients/{patientId}`), also the
/// answer of every patient write.
class PatientView {
  const PatientView({
    required this.patientId,
    required this.fileNumber,
    required this.fullName,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.ageYears,
    required this.linkedAt,
    this.dateOfBirthEstimated = false,
    this.nationalId,
    this.address,
    this.bloodType,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.ownsDetails = true,
    this.accountStatus = 'active',
    this.archived = false,
    this.archivedAt,
    this.visits = const PatientVisits(),
    this.totalPaidPiasters,
    this.hasAllergies,
    this.filesTotal = 0,
    this.prescriptionCount = 0,
  });

  factory PatientView.fromJson(Map<String, dynamic> json) => PatientView(
    patientId: json['patientId'] as String,
    fileNumber: json['fileNumber'] as int,
    fullName: json['fullName'] as String,
    phone: json['phone'] as String,
    gender: Gender.fromWire(json['gender']),
    dateOfBirth: parseDay(json['dateOfBirth']),
    dateOfBirthEstimated: json['dateOfBirthEstimated'] as bool? ?? false,
    ageYears: json['ageYears'] as int,
    nationalId: _text(json['nationalId']),
    address: _text(json['address']),
    bloodType: _text(json['bloodType']),
    emergencyContactName: _text(json['emergencyContactName']),
    emergencyContactPhone: _text(json['emergencyContactPhone']),
    ownsDetails: json['ownsDetails'] as bool? ?? false,
    accountStatus: json['accountStatus'] as String? ?? 'active',
    archived: json['archived'] as bool? ?? false,
    archivedAt: _timeOrNull(json['archivedAt']),
    linkedAt: _time(json['linkedAt']),
    visits: PatientVisits.fromJson(_map(json['visits'])),
    totalPaidPiasters: json['totalPaidPiasters'] as int?,
    hasAllergies: json['hasAllergies'] as bool?,
    filesTotal: json['files'] is Map ? (_map(json['files'])['total'] as int? ?? 0) : 0,
    prescriptionCount: json['prescriptionCount'] as int? ?? 0,
  );

  final String patientId;

  /// Per doctor (BR-P6).
  final int fileNumber;
  final String fullName;

  /// E.164.
  final String phone;
  final Gender gender;
  final DateTime dateOfBirth;

  /// Typed as an age in D5: show "≈".
  final bool dateOfBirthEstimated;
  final int ageYears;
  final String? nationalId;
  final String? address;
  final String? bloodType;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  /// This clinic created the account, so it sees and edits the optional
  /// details. A clinic that linked an existing patient doesn't (BR-P3).
  final bool ownsDetails;
  final String accountStatus;
  final bool archived;
  final DateTime? archivedAt;
  final DateTime linkedAt;
  final PatientVisits visits;

  /// `revenueView`, else null.
  final int? totalPaidPiasters;

  /// `clinicalView`, else null.
  final bool? hasAllergies;
  final int filesTotal;
  final int prescriptionCount;

  bool get hasDetails =>
      nationalId != null ||
      address != null ||
      bloodType != null ||
      emergencyContactName != null ||
      emergencyContactPhone != null;
}

/// One D4 row (`GET /api/patients/register`).
class PatientRegisterRow {
  const PatientRegisterRow({
    required this.patientId,
    required this.fileNumber,
    required this.fullName,
    required this.phone,
    required this.gender,
    required this.ageYears,
    required this.linkedAt,
    this.dateOfBirthEstimated = false,
    this.visits = const PatientVisits(),
    this.totalPaidPiasters,
    this.filesCount = 0,
    this.hasAllergies,
    this.chronicDiseases,
    this.archived = false,
  });

  factory PatientRegisterRow.fromJson(Map<String, dynamic> json) => PatientRegisterRow(
    patientId: json['patientId'] as String,
    fileNumber: json['fileNumber'] as int,
    fullName: json['fullName'] as String,
    phone: json['phone'] as String,
    gender: Gender.fromWire(json['gender']),
    dateOfBirthEstimated: json['dateOfBirthEstimated'] as bool? ?? false,
    ageYears: json['ageYears'] as int,
    visits: PatientVisits.fromJson(_map(json['visits'])),
    totalPaidPiasters: json['totalPaidPiasters'] as int?,
    filesCount: json['filesCount'] as int? ?? 0,
    hasAllergies: json['hasAllergies'] as bool?,
    chronicDiseases: json['chronicDiseases'] == null
        ? null
        : [for (final d in json['chronicDiseases'] as List) d as String],
    archived: json['archived'] as bool? ?? false,
    linkedAt: _time(json['linkedAt']),
  );

  final String patientId;
  final int fileNumber;
  final String fullName;
  final String phone;
  final Gender gender;
  final bool dateOfBirthEstimated;
  final int ageYears;
  final PatientVisits visits;
  final int? totalPaidPiasters;
  final int filesCount;
  final bool? hasAllergies;
  final List<String>? chronicDiseases;
  final bool archived;
  final DateTime linkedAt;
}

/// `lookupPhone` (D5): is this number new, ours, or another clinic's?
enum PhoneLookupStatus {
  isNew,
  linkedToYou,
  existsElsewhere;

  static PhoneLookupStatus fromWire(Object? value) => switch (value) {
    'linkedToYou' => linkedToYou,
    'existsElsewhere' => existsElsewhere,
    _ => isNew,
  };
}

class PhoneLookup {
  const PhoneLookup({required this.status, this.patientId, this.fileNumber, this.fullName, this.archived});

  factory PhoneLookup.fromJson(Map<String, dynamic> json) => PhoneLookup(
    status: PhoneLookupStatus.fromWire(json['status']),
    patientId: json['patientId'] as String?,
    fileNumber: json['fileNumber'] as int?,
    fullName: _text(json['fullName']),
    archived: json['archived'] as bool?,
  );

  final PhoneLookupStatus status;

  /// Only for [PhoneLookupStatus.linkedToYou].
  final String? patientId;
  final int? fileNumber;
  final String? fullName;
  final bool? archived;
}

/// `createPatient`'s answer.
class CreatedPatient {
  const CreatedPatient({required this.linked, required this.patient, this.temporaryPassword});

  factory CreatedPatient.fromJson(Map<String, dynamic> json) => CreatedPatient(
    linked: json['linked'] as bool,
    temporaryPassword: json['temporaryPassword'] as String?,
    patient: PatientView.fromJson(_map(json['patient'])),
  );

  /// True: an existing account was linked (BR-P3), no password.
  final bool linked;

  /// A new account's password, shown once (BR-P4).
  final String? temporaryPassword;
  final PatientView patient;
}

/// The D5 / D7 identity form: `createPatient` and `updatePatient` bodies.
class PatientDraft {
  const PatientDraft({
    required this.fullName,
    required this.gender,
    this.phone,
    this.dateOfBirth,
    this.ageYears,
    this.nationalId,
    this.address,
    this.bloodType,
    this.emergencyContactName,
    this.emergencyContactPhone,
  }) : linkOnly = false;

  /// BR-P3: linking an existing number sends the phone alone; the account
  /// keeps its own identity.
  const PatientDraft.link(String this.phone)
    : linkOnly = true,
      fullName = '',
      gender = Gender.male,
      dateOfBirth = null,
      ageYears = null,
      nationalId = null,
      address = null,
      bloodType = null,
      emergencyContactName = null,
      emergencyContactPhone = null;

  final bool linkOnly;
  final String fullName;

  /// Only for `createPatient`; D7 changes it through `updatePatientPhone`.
  final String? phone;
  final Gender gender;

  /// A date of birth **or** an age (never both).
  final DateTime? dateOfBirth;
  final int? ageYears;
  final String? nationalId;
  final String? address;
  final String? bloodType;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  Map<String, Object?> toJson() => linkOnly
      ? {'phone': phone}
      : {
          'phone': ?phone,
          'fullName': fullName,
          'gender': gender.wire,
          'dateOfBirth': dateOfBirth == null ? null : dayKey(dateOfBirth!),
          'ageYears': dateOfBirth == null ? ageYears : null,
          'nationalId': nationalId,
          'address': address,
          'bloodType': bloodType,
          'emergencyContactName': emergencyContactName,
          'emergencyContactPhone': emergencyContactPhone,
        };
}

class ProfileItem {
  const ProfileItem({required this.id, required this.text});

  factory ProfileItem.fromJson(Map<String, dynamic> json) =>
      ProfileItem(id: json['id'] as String, text: json['text'] as String);

  final String id;
  final String text;
}

/// The four lists of the medical profile, allergies first (spec 6.1).
enum ProfileList { allergies, chronicDiseases, currentMedications, surgeries }

/// The medical profile of this doctor's link (D6 Overview, D7; `clinicalView`).
class MedicalProfile {
  const MedicalProfile({
    required this.patientId,
    this.allergies = const [],
    this.chronicDiseases = const [],
    this.currentMedications = const [],
    this.surgeries = const [],
    this.familyHistory,
    this.notes,
  });

  factory MedicalProfile.fromJson(Map<String, dynamic> json) {
    List<ProfileItem> items(String key) => [
      for (final row in json[key] as List? ?? const []) ProfileItem.fromJson(_map(row)),
    ];
    return MedicalProfile(
      patientId: json['patientId'] as String,
      allergies: items('allergies'),
      chronicDiseases: items('chronicDiseases'),
      currentMedications: items('currentMedications'),
      surgeries: items('surgeries'),
      familyHistory: _text(json['familyHistory']),
      notes: _text(json['notes']),
    );
  }

  final String patientId;
  final List<ProfileItem> allergies;
  final List<ProfileItem> chronicDiseases;
  final List<ProfileItem> currentMedications;
  final List<ProfileItem> surgeries;
  final String? familyHistory;
  final String? notes;

  bool get hasAllergies => allergies.isNotEmpty;

  List<ProfileItem> list(ProfileList list) => switch (list) {
    ProfileList.allergies => allergies,
    ProfileList.chronicDiseases => chronicDiseases,
    ProfileList.currentMedications => currentMedications,
    ProfileList.surgeries => surgeries,
  };

  bool get isEmpty => ProfileList.values.every((l) => list(l).isEmpty) && familyHistory == null && notes == null;
}

/// `updateMedicalProfile`'s body: the whole profile (a list left out is cleared).
class MedicalProfileDraft {
  const MedicalProfileDraft({
    this.allergies = const [],
    this.chronicDiseases = const [],
    this.currentMedications = const [],
    this.surgeries = const [],
    this.familyHistory,
    this.notes,
  });

  final List<String> allergies;
  final List<String> chronicDiseases;
  final List<String> currentMedications;
  final List<String> surgeries;
  final String? familyHistory;
  final String? notes;

  List<String> list(ProfileList list) => switch (list) {
    ProfileList.allergies => allergies,
    ProfileList.chronicDiseases => chronicDiseases,
    ProfileList.currentMedications => currentMedications,
    ProfileList.surgeries => surgeries,
  };

  Map<String, Object?> toJson(String patientId) => {
    'patientId': patientId,
    'allergies': allergies,
    'chronicDiseases': chronicDiseases,
    'currentMedications': currentMedications,
    'surgeries': surgeries,
    'familyHistory': familyHistory,
    'notes': notes,
  };
}

/// D4's "last visit" filter.
enum LastVisitFilter { thisWeek, thisMonth, notSeen3m, notSeen6m, notSeen12m, never }

/// D4's sorts. [totalPaid] needs `revenueView`, [allergies] `clinicalView`.
enum RegisterSort {
  lastVisit(descending: true),
  fileNumber(descending: false),
  name(descending: false),
  phone(descending: false),
  age(descending: false),
  gender(descending: false),
  firstVisit(descending: true),
  visits(descending: true),
  examinations(descending: true),
  consultations(descending: true),
  files(descending: true),
  linkedAt(descending: true),
  totalPaid(descending: true),
  allergies(descending: true);

  const RegisterSort({required this.descending});

  /// The API's default direction for this sort.
  final bool descending;
}

/// What D4 asks the register for. Fields left null aren't sent.
class RegisterQuery {
  const RegisterQuery({
    this.search = '',
    this.lastVisit,
    this.branchId,
    this.minVisits,
    this.maxVisits,
    this.newThisMonth = false,
    this.archived = false,
    this.hasChronicDisease = false,
    this.sort = RegisterSort.lastVisit,
    this.descending,
  });

  final String search;
  final LastVisitFilter? lastVisit;
  final String? branchId;
  final int? minVisits;
  final int? maxVisits;
  final bool newThisMonth;

  /// Archived patients only (BR-P7).
  final bool archived;

  /// `clinicalView` only.
  final bool hasChronicDisease;
  final RegisterSort sort;

  /// Null: the sort's own default.
  final bool? descending;

  bool get isDescending => descending ?? sort.descending;

  /// How many filters (not search or sort) are on, for the filter button.
  int get filterCount => [
    lastVisit != null,
    branchId != null,
    minVisits != null || maxVisits != null,
    newThisMonth,
    archived,
    hasChronicDisease,
  ].where((on) => on).length;

  bool get isFiltered => search.trim().isNotEmpty || filterCount > 0;

  RegisterQuery copyWith({
    String? search,
    LastVisitFilter? Function()? lastVisit,
    String? Function()? branchId,
    int? Function()? minVisits,
    int? Function()? maxVisits,
    bool? newThisMonth,
    bool? archived,
    bool? hasChronicDisease,
    RegisterSort? sort,
    bool? Function()? descending,
  }) => RegisterQuery(
    search: search ?? this.search,
    lastVisit: lastVisit == null ? this.lastVisit : lastVisit(),
    branchId: branchId == null ? this.branchId : branchId(),
    minVisits: minVisits == null ? this.minVisits : minVisits(),
    maxVisits: maxVisits == null ? this.maxVisits : maxVisits(),
    newThisMonth: newThisMonth ?? this.newThisMonth,
    archived: archived ?? this.archived,
    hasChronicDisease: hasChronicDisease ?? this.hasChronicDisease,
    sort: sort ?? this.sort,
    descending: descending == null ? this.descending : descending(),
  );

  /// The filters off, the search and sort kept.
  RegisterQuery withoutFilters() => RegisterQuery(search: search, sort: sort, descending: descending);

  /// The query string, without paging.
  Map<String, Object> toQuery() => {
    if (search.trim().isNotEmpty) 'search': search.trim(),
    if (lastVisit != null) 'lastVisit': lastVisit!.name,
    'branchId': ?branchId,
    'minVisits': ?minVisits,
    'maxVisits': ?maxVisits,
    if (newThisMonth) 'newThisMonth': 'true',
    if (archived) 'archived': 'true',
    if (hasChronicDisease) 'hasChronicDisease': 'true',
    if (sort != RegisterSort.lastVisit) 'sort': sort.name,
    if (descending != null && descending != sort.descending) 'direction': descending! ? 'desc' : 'asc',
  };
}
