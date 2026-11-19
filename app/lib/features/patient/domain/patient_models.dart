// Models of the patient app (spec 7.4, P1–P14), parsed from the `/api/patient`
// endpoints. They mirror `Features/PatientPortal/PatientPortalDtos.cs` in the API.

typedef Json = Map<String, dynamic>;

DateTime _date(Object? value) => DateTime.parse(value as String);
DateTime? _dateOrNull(Object? value) => value == null ? null : DateTime.parse(value as String);
List<T> _list<T>(Object? value, T Function(Json json) parse) =>
    [for (final item in (value as List<dynamic>? ?? const [])) parse(item as Json)];
List<String> _strings(Object? value) => [for (final item in (value as List<dynamic>? ?? const [])) item as String];

/// A doctor as shown on cards and rows. Names come in Arabic and, optionally, English.
class DoctorRef {
  const DoctorRef({
    required this.id,
    required this.fullName,
    this.fullNameEn,
    required this.title,
    this.titleEn,
  });

  final String id;
  final String fullName;
  final String? fullNameEn;
  final String title;
  final String? titleEn;

  /// The English name when the app is in English and the doctor gave one.
  String displayName({required bool arabic}) => !arabic && fullNameEn != null ? fullNameEn! : fullName;

  String displayTitle({required bool arabic}) => !arabic && titleEn != null ? titleEn! : title;

  factory DoctorRef.fromJson(Json json) => DoctorRef(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        fullNameEn: json['fullNameEn'] as String?,
        title: json['title'] as String,
        titleEn: json['titleEn'] as String?,
      );
}

class BranchRef {
  const BranchRef({required this.id, required this.nameAr, this.nameEn});

  final String id;
  final String nameAr;
  final String? nameEn;

  String displayName({required bool arabic}) => !arabic && nameEn != null ? nameEn! : nameAr;

  factory BranchRef.fromJson(Json json) => BranchRef(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String?,
      );
}

class SpecialtyRef {
  const SpecialtyRef({required this.id, required this.nameAr, required this.nameEn});

  final String id;
  final String nameAr;
  final String nameEn;

  String displayName({required bool arabic}) => arabic ? nameAr : nameEn;

  factory SpecialtyRef.fromJson(Json json) => SpecialtyRef(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String,
      );
}

/// Items the patient hasn't opened yet ("New" badges).
class NewCounts {
  const NewCounts({this.visits = 0, this.prescriptions = 0, this.files = 0});

  final int visits;
  final int prescriptions;
  final int files;

  int get total => visits + prescriptions + files;

  factory NewCounts.fromJson(Json json) => NewCounts(
        visits: json['visits'] as int,
        prescriptions: json['prescriptions'] as int,
        files: json['files'] as int,
      );
}

/// One page of a list (`PagedResult<T>` in the API).
class Paged<T> {
  const Paged({required this.items, required this.page, required this.pageSize, required this.totalCount});

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasMore => page * pageSize < totalCount;

  factory Paged.fromJson(Json json, T Function(Json json) parse) => Paged(
        items: _list(json['items'], parse),
        page: json['page'] as int,
        pageSize: json['pageSize'] as int,
        totalCount: json['totalCount'] as int,
      );
}

enum VisitType {
  examination,
  consultation;

  static VisitType fromJson(String value) => VisitType.values.byName(value);
}

// ---- P2 / P3 --------------------------------------------------------------------------------

class MyDoctor {
  const MyDoctor({
    required this.doctor,
    required this.specialty,
    required this.doctorStatus,
    required this.fileNumber,
    required this.linkedAt,
    this.lastVisitAt,
    this.defaultBranch,
    this.defaultBranchArea,
    this.newCounts = const NewCounts(),
  });

  final DoctorRef doctor;
  final SpecialtyRef specialty;
  final String doctorStatus;
  final int fileNumber;
  final DateTime linkedAt;
  final DateTime? lastVisitAt;
  final BranchRef? defaultBranch;
  final String? defaultBranchArea;
  final NewCounts newCounts;

  factory MyDoctor.fromJson(Json json) => MyDoctor(
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        specialty: SpecialtyRef.fromJson(json['specialty'] as Json),
        doctorStatus: json['doctorStatus'] as String,
        fileNumber: json['fileNumber'] as int,
        linkedAt: _date(json['linkedAt']),
        lastVisitAt: _dateOrNull(json['lastVisitAt']),
        defaultBranch: json['defaultBranch'] == null ? null : BranchRef.fromJson(json['defaultBranch'] as Json),
        defaultBranchArea: json['defaultBranchArea'] as String?,
        newCounts: NewCounts.fromJson(json['new'] as Json),
      );
}

class Address {
  const Address({
    required this.governorate,
    required this.city,
    this.area,
    required this.street,
    this.building,
    this.floor,
    this.apartment,
    this.landmark,
    this.lat,
    this.lng,
  });

  final String governorate;
  final String city;
  final String? area;
  final String street;
  final String? building;
  final String? floor;
  final String? apartment;
  final String? landmark;
  final double? lat;
  final double? lng;

  /// One line for cards: street, area, city, governorate.
  String get singleLine => [
        if (building != null) building,
        street,
        if (area != null && area != city) area,
        city,
        governorate,
      ].join('، ');

  String get mapsQuery => lat != null && lng != null ? '$lat,$lng' : singleLine;

  factory Address.fromJson(Json json) => Address(
        governorate: json['governorate'] as String,
        city: json['city'] as String,
        area: json['area'] as String?,
        street: json['street'] as String,
        building: json['building'] as String?,
        floor: json['floor'] as String?,
        apartment: json['apartment'] as String?,
        landmark: json['landmark'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );
}

class BranchPhone {
  const BranchPhone({required this.number, required this.label, required this.isWhatsapp});

  final String number;
  final String label;
  final bool isWhatsapp;

  factory BranchPhone.fromJson(Json json) => BranchPhone(
        number: json['number'] as String,
        label: json['label'] as String,
        isWhatsapp: json['isWhatsapp'] as bool,
      );
}

/// One working period. [weekday] is ISO: 1 = Monday … 7 = Sunday.
class WorkingPeriod {
  const WorkingPeriod({required this.weekday, required this.start, required this.end, this.endsNextDay = false, this.label});

  final int weekday;

  /// Local clinic time, `HH:mm`.
  final String start;
  final String end;
  final bool endsNextDay;
  final String? label;

  factory WorkingPeriod.fromJson(Json json) => WorkingPeriod(
        weekday: json['weekday'] as int,
        start: (json['start'] as String).substring(0, 5),
        end: (json['end'] as String).substring(0, 5),
        endsNextDay: json['endsNextDay'] as bool? ?? false,
        label: json['label'] as String?,
      );
}

/// Visit prices in piasters. Null means "ask the clinic" (BR-PR6).
class VisitPrices {
  const VisitPrices({this.examinationPiasters, this.consultationPiasters});

  final int? examinationPiasters;
  final int? consultationPiasters;

  factory VisitPrices.fromJson(Json json) => VisitPrices(
        examinationPiasters: json['examinationPiasters'] as int?,
        consultationPiasters: json['consultationPiasters'] as int?,
      );
}

enum BranchStatus {
  active,
  temporarilyClosed,
  archived;

  static BranchStatus fromJson(String value) => BranchStatus.values.byName(value);
}

class BranchInfo {
  const BranchInfo({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.description,
    required this.isDefault,
    required this.status,
    this.closedMessage,
    this.reopenDate,
    required this.address,
    this.email,
    this.phones = const [],
    this.workingHours = const [],
    this.prices = const VisitPrices(),
    this.paymentMethods = const [],
    this.amenities = const [],
  });

  final String id;
  final String nameAr;
  final String? nameEn;
  final String? description;
  final bool isDefault;
  final BranchStatus status;
  final String? closedMessage;
  final DateTime? reopenDate;
  final Address address;
  final String? email;
  final List<BranchPhone> phones;
  final List<WorkingPeriod> workingHours;
  final VisitPrices prices;
  final List<String> paymentMethods;
  final List<String> amenities;

  String displayName({required bool arabic}) => !arabic && nameEn != null ? nameEn! : nameAr;

  factory BranchInfo.fromJson(Json json) => BranchInfo(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String?,
        description: json['description'] as String?,
        isDefault: json['isDefault'] as bool,
        status: BranchStatus.fromJson(json['status'] as String),
        closedMessage: json['closedMessage'] as String?,
        reopenDate: _dateOrNull(json['reopenDate']),
        address: Address.fromJson(json['address'] as Json),
        email: json['email'] as String?,
        phones: _list(json['phones'], BranchPhone.fromJson),
        workingHours: _list(json['workingHours'], WorkingPeriod.fromJson),
        prices: VisitPrices.fromJson(json['prices'] as Json),
        paymentMethods: _strings(json['paymentMethods']),
        amenities: _strings(json['amenities']),
      );
}

class DoctorInfo {
  const DoctorInfo({
    required this.doctor,
    required this.specialty,
    this.degreesAr,
    this.degreesEn,
    required this.doctorStatus,
    required this.fileNumber,
    this.branches = const [],
  });

  final DoctorRef doctor;
  final SpecialtyRef specialty;
  final String? degreesAr;
  final String? degreesEn;
  final String doctorStatus;
  final int fileNumber;
  final List<BranchInfo> branches;

  factory DoctorInfo.fromJson(Json json) => DoctorInfo(
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        specialty: SpecialtyRef.fromJson(json['specialty'] as Json),
        degreesAr: json['degreesAr'] as String?,
        degreesEn: json['degreesEn'] as String?,
        doctorStatus: json['doctorStatus'] as String,
        fileNumber: json['fileNumber'] as int,
        branches: _list(json['branches'], BranchInfo.fromJson),
      );
}

// ---- P4 / P5 --------------------------------------------------------------------------------

class VisitListItem {
  const VisitListItem({
    required this.id,
    required this.doctor,
    required this.branch,
    required this.type,
    required this.at,
    required this.day,
    this.diagnosisSnippet,
    this.isNew = false,
  });

  final String id;
  final DoctorRef doctor;
  final BranchRef branch;
  final VisitType type;
  final DateTime at;

  /// The visit's Cairo calendar day.
  final DateTime day;
  final String? diagnosisSnippet;
  final bool isNew;

  factory VisitListItem.fromJson(Json json) => VisitListItem(
        id: json['id'] as String,
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        branch: BranchRef.fromJson(json['branch'] as Json),
        type: VisitType.fromJson(json['type'] as String),
        at: _date(json['at']),
        day: _date(json['dayKey']),
        diagnosisSnippet: json['diagnosisSnippet'] as String?,
        isNew: json['isNew'] as bool? ?? false,
      );
}

class Vitals {
  const Vitals({this.bpSys, this.bpDia, this.pulse, this.tempC, this.weightKg, this.heightCm, this.glucose});

  final int? bpSys;
  final int? bpDia;
  final int? pulse;
  final double? tempC;
  final double? weightKg;
  final double? heightCm;
  final int? glucose;

  bool get isEmpty =>
      bpSys == null && bpDia == null && pulse == null && tempC == null && weightKg == null && heightCm == null && glucose == null;

  factory Vitals.fromJson(Json json) => Vitals(
        bpSys: json['bpSys'] as int?,
        bpDia: json['bpDia'] as int?,
        pulse: json['pulse'] as int?,
        tempC: (json['tempC'] as num?)?.toDouble(),
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        heightCm: (json['heightCm'] as num?)?.toDouble(),
        glucose: json['glucose'] as int?,
      );
}

class VisitBranch {
  const VisitBranch({required this.id, required this.nameAr, this.nameEn, required this.address, this.phones = const []});

  final String id;
  final String nameAr;
  final String? nameEn;
  final Address address;
  final List<BranchPhone> phones;

  String displayName({required bool arabic}) => !arabic && nameEn != null ? nameEn! : nameAr;

  factory VisitBranch.fromJson(Json json) => VisitBranch(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: json['nameEn'] as String?,
        address: Address.fromJson(json['address'] as Json),
        phones: _list(json['phones'], BranchPhone.fromJson),
      );
}

class VisitDetail {
  const VisitDetail({
    required this.id,
    required this.doctor,
    required this.branch,
    required this.type,
    required this.at,
    required this.day,
    this.chiefComplaint,
    this.findings,
    this.vitals = const Vitals(),
    this.diagnosis,
    this.patientNotes,
    this.followUpDate,
    this.isNew = false,
    this.prescriptions = const [],
    this.files = const [],
  });

  final String id;
  final DoctorRef doctor;
  final VisitBranch branch;
  final VisitType type;
  final DateTime at;
  final DateTime day;
  final String? chiefComplaint;
  final String? findings;
  final Vitals vitals;
  final String? diagnosis;
  final String? patientNotes;
  final DateTime? followUpDate;
  final bool isNew;
  final List<PrescriptionListItem> prescriptions;
  final List<RecordListItem> files;

  factory VisitDetail.fromJson(Json json) => VisitDetail(
        id: json['id'] as String,
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        branch: VisitBranch.fromJson(json['branch'] as Json),
        type: VisitType.fromJson(json['type'] as String),
        at: _date(json['at']),
        day: _date(json['dayKey']),
        chiefComplaint: json['chiefComplaint'] as String?,
        findings: json['findings'] as String?,
        vitals: Vitals.fromJson(json['vitals'] as Json),
        diagnosis: json['diagnosis'] as String?,
        patientNotes: json['patientNotes'] as String?,
        followUpDate: _dateOrNull(json['followUpDate']),
        isNew: json['isNew'] as bool? ?? false,
        prescriptions: _list(json['prescriptions'], PrescriptionListItem.fromJson),
        files: _list(json['files'], RecordListItem.fromJson),
      );
}

// ---- P6 / P7 --------------------------------------------------------------------------------

enum PrescriptionKind {
  medication,
  investigations;

  static PrescriptionKind fromJson(String value) => PrescriptionKind.values.byName(value);
}

enum PrescriptionStatus {
  sent,
  cancelled;

  static PrescriptionStatus fromJson(String value) => PrescriptionStatus.values.byName(value);
}

class PrescriptionListItem {
  const PrescriptionListItem({
    required this.id,
    required this.kind,
    required this.status,
    required this.doctor,
    required this.sessionId,
    this.sentAt,
    this.cancelledAt,
    required this.itemCount,
    this.isNew = false,
  });

  final String id;
  final PrescriptionKind kind;
  final PrescriptionStatus status;
  final DoctorRef doctor;
  final String sessionId;
  final DateTime? sentAt;
  final DateTime? cancelledAt;
  final int itemCount;
  final bool isNew;

  bool get isCancelled => status == PrescriptionStatus.cancelled;

  factory PrescriptionListItem.fromJson(Json json) => PrescriptionListItem(
        id: json['id'] as String,
        kind: PrescriptionKind.fromJson(json['kind'] as String),
        status: PrescriptionStatus.fromJson(json['status'] as String),
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        sessionId: json['sessionId'] as String,
        sentAt: _dateOrNull(json['sentAt']),
        cancelledAt: _dateOrNull(json['cancelledAt']),
        itemCount: json['itemCount'] as int,
        isNew: json['isNew'] as bool? ?? false,
      );
}

class MedicationItem {
  const MedicationItem({
    required this.drugName,
    this.activeIngredient,
    this.form,
    this.strength,
    this.dose,
    this.frequency,
    this.timing,
    this.duration,
    this.instructions,
  });

  final String drugName;
  final String? activeIngredient;
  final String? form;
  final String? strength;
  final String? dose;
  final String? frequency;
  final String? timing;
  final String? duration;
  final String? instructions;

  factory MedicationItem.fromJson(Json json) => MedicationItem(
        drugName: json['drugName'] as String,
        activeIngredient: json['activeIngredient'] as String?,
        form: json['form'] as String?,
        strength: json['strength'] as String?,
        dose: json['dose'] as String?,
        frequency: json['frequency'] as String?,
        timing: json['timing'] as String?,
        duration: json['duration'] as String?,
        instructions: json['instructions'] as String?,
      );
}

class InvestigationItem {
  const InvestigationItem({required this.category, required this.name, this.notes});

  /// `lab` or `radiology`.
  final String category;
  final String name;
  final String? notes;

  factory InvestigationItem.fromJson(Json json) => InvestigationItem(
        category: json['category'] as String,
        name: json['name'] as String,
        notes: json['notes'] as String?,
      );
}

class PrescriptionDetail {
  const PrescriptionDetail({
    required this.id,
    required this.kind,
    required this.status,
    required this.doctor,
    required this.sessionId,
    required this.visitDay,
    this.diagnosis,
    this.advice,
    this.sentAt,
    this.cancelledAt,
    this.cancelReason,
    this.replacesId,
    this.replacedById,
    this.hasPdf = false,
    this.isNew = false,
    this.medications = const [],
    this.investigations = const [],
  });

  final String id;
  final PrescriptionKind kind;
  final PrescriptionStatus status;
  final DoctorRef doctor;
  final String sessionId;
  final DateTime visitDay;
  final String? diagnosis;
  final String? advice;
  final DateTime? sentAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? replacesId;
  final String? replacedById;
  final bool hasPdf;
  final bool isNew;
  final List<MedicationItem> medications;
  final List<InvestigationItem> investigations;

  bool get isCancelled => status == PrescriptionStatus.cancelled;

  factory PrescriptionDetail.fromJson(Json json) => PrescriptionDetail(
        id: json['id'] as String,
        kind: PrescriptionKind.fromJson(json['kind'] as String),
        status: PrescriptionStatus.fromJson(json['status'] as String),
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        sessionId: json['sessionId'] as String,
        visitDay: _date(json['visitDay']),
        diagnosis: json['diagnosis'] as String?,
        advice: json['advice'] as String?,
        sentAt: _dateOrNull(json['sentAt']),
        cancelledAt: _dateOrNull(json['cancelledAt']),
        cancelReason: json['cancelReason'] as String?,
        replacesId: json['replacesId'] as String?,
        replacedById: json['replacedById'] as String?,
        hasPdf: json['hasPdf'] as bool? ?? false,
        isNew: json['isNew'] as bool? ?? false,
        medications: _list(json['medications'], MedicationItem.fromJson),
        investigations: _list(json['investigations'], InvestigationItem.fromJson),
      );
}

// ---- P8 / P9 --------------------------------------------------------------------------------

/// File categories (BR-F1), in the order of the P8 tabs.
enum RecordCategory {
  prescription,
  lab,
  radiology,
  other;

  static RecordCategory fromJson(String value) => RecordCategory.values.byName(value);
}

class Attachment {
  const Attachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.pageCount,
    this.hasThumbnail = false,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int? pageCount;
  final bool hasThumbnail;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  /// Images and PDF open in the app; anything else is shared to another app (BR-F4).
  bool get canPreview => isImage || isPdf;

  factory Attachment.fromJson(Json json) => Attachment(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        mimeType: json['mimeType'] as String,
        sizeBytes: json['sizeBytes'] as int,
        pageCount: json['pageCount'] as int?,
        hasThumbnail: json['hasThumbnail'] as bool? ?? false,
      );
}

class RecordListItem {
  const RecordListItem({
    required this.id,
    required this.doctor,
    this.sessionId,
    required this.category,
    this.otherType,
    this.otherTypeText,
    required this.title,
    required this.documentDate,
    required this.attachmentCount,
    this.cover,
    this.isNew = false,
  });

  final String id;
  final DoctorRef doctor;
  final String? sessionId;
  final RecordCategory category;
  final String? otherType;
  final String? otherTypeText;
  final String title;
  final DateTime documentDate;
  final int attachmentCount;
  final Attachment? cover;
  final bool isNew;

  factory RecordListItem.fromJson(Json json) => RecordListItem(
        id: json['id'] as String,
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        sessionId: json['sessionId'] as String?,
        category: RecordCategory.fromJson(json['category'] as String),
        otherType: json['otherType'] as String?,
        otherTypeText: json['otherTypeText'] as String?,
        title: json['title'] as String,
        documentDate: _date(json['documentDate']),
        attachmentCount: json['attachmentCount'] as int,
        cover: json['cover'] == null ? null : Attachment.fromJson(json['cover'] as Json),
        isNew: json['isNew'] as bool? ?? false,
      );
}

class RecordDetail {
  const RecordDetail({
    required this.id,
    required this.doctor,
    this.sessionId,
    required this.category,
    this.otherType,
    this.otherTypeText,
    required this.title,
    required this.documentDate,
    this.notes,
    required this.source,
    this.isNew = false,
    this.attachments = const [],
  });

  final String id;
  final DoctorRef doctor;
  final String? sessionId;
  final RecordCategory category;
  final String? otherType;
  final String? otherTypeText;
  final String title;
  final DateTime documentDate;
  final String? notes;
  final String source;
  final bool isNew;
  final List<Attachment> attachments;

  factory RecordDetail.fromJson(Json json) => RecordDetail(
        id: json['id'] as String,
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        sessionId: json['sessionId'] as String?,
        category: RecordCategory.fromJson(json['category'] as String),
        otherType: json['otherType'] as String?,
        otherTypeText: json['otherTypeText'] as String?,
        title: json['title'] as String,
        documentDate: _date(json['documentDate']),
        notes: json['notes'] as String?,
        source: json['source'] as String,
        isNew: json['isNew'] as bool? ?? false,
        attachments: _list(json['attachments'], Attachment.fromJson),
      );
}

class RecordCounts {
  const RecordCounts({this.prescription = 0, this.lab = 0, this.radiology = 0, this.other = 0});

  final int prescription;
  final int lab;
  final int radiology;
  final int other;

  int of(RecordCategory category) => switch (category) {
        RecordCategory.prescription => prescription,
        RecordCategory.lab => lab,
        RecordCategory.radiology => radiology,
        RecordCategory.other => other,
      };

  factory RecordCounts.fromJson(Json json) => RecordCounts(
        prescription: json['prescription'] as int,
        lab: json['lab'] as int,
        radiology: json['radiology'] as int,
        other: json['other'] as int,
      );
}

// ---- P10 ------------------------------------------------------------------------------------

class PersonalInfo {
  const PersonalInfo({
    required this.patientId,
    required this.fullName,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    this.dateOfBirthEstimated = false,
    this.bloodType,
  });

  final String patientId;
  final String fullName;
  final String phone;

  /// `male` or `female`.
  final String gender;
  final DateTime dateOfBirth;
  final bool dateOfBirthEstimated;
  final String? bloodType;

  int ageOn(DateTime today) {
    var age = today.year - dateOfBirth.year;
    if (today.month < dateOfBirth.month || (today.month == dateOfBirth.month && today.day < dateOfBirth.day)) age--;
    return age;
  }

  factory PersonalInfo.fromJson(Json json) => PersonalInfo(
        patientId: json['patientId'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        gender: json['gender'] as String,
        dateOfBirth: _date(json['dateOfBirth']),
        dateOfBirthEstimated: json['dateOfBirthEstimated'] as bool? ?? false,
        bloodType: json['bloodType'] as String?,
      );
}

class DoctorMedicalProfile {
  const DoctorMedicalProfile({
    required this.doctor,
    this.allergies = const [],
    this.chronicDiseases = const [],
    this.currentMedications = const [],
    this.surgeries = const [],
    this.familyHistory,
    this.notes,
  });

  final DoctorRef doctor;
  final List<String> allergies;
  final List<String> chronicDiseases;
  final List<String> currentMedications;
  final List<String> surgeries;
  final String? familyHistory;
  final String? notes;

  bool get isEmpty =>
      allergies.isEmpty &&
      chronicDiseases.isEmpty &&
      currentMedications.isEmpty &&
      surgeries.isEmpty &&
      (familyHistory ?? '').isEmpty &&
      (notes ?? '').isEmpty;

  factory DoctorMedicalProfile.fromJson(Json json) => DoctorMedicalProfile(
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        allergies: _strings(json['allergies']),
        chronicDiseases: _strings(json['chronicDiseases']),
        currentMedications: _strings(json['currentMedications']),
        surgeries: _strings(json['surgeries']),
        familyHistory: json['familyHistory'] as String?,
        notes: json['notes'] as String?,
      );
}

class MedicalProfile {
  const MedicalProfile({required this.personal, this.doctors = const []});

  final PersonalInfo personal;
  final List<DoctorMedicalProfile> doctors;

  factory MedicalProfile.fromJson(Json json) => MedicalProfile(
        personal: PersonalInfo.fromJson(json['personal'] as Json),
        doctors: _list(json['doctors'], DoctorMedicalProfile.fromJson),
      );
}

// ---- P1 -------------------------------------------------------------------------------------

class FollowUp {
  const FollowUp({required this.date, required this.doctor, required this.sessionId});

  final DateTime date;
  final DoctorRef doctor;
  final String sessionId;

  factory FollowUp.fromJson(Json json) => FollowUp(
        date: _date(json['date']),
        doctor: DoctorRef.fromJson(json['doctor'] as Json),
        sessionId: json['sessionId'] as String,
      );
}

class PatientHome {
  const PatientHome({
    required this.fullName,
    this.latestVisit,
    this.latestPrescription,
    this.nextFollowUp,
    this.recentFiles = const [],
    this.newCounts = const NewCounts(),
  });

  final String fullName;
  final VisitListItem? latestVisit;
  final PrescriptionListItem? latestPrescription;
  final FollowUp? nextFollowUp;
  final List<RecordListItem> recentFiles;
  final NewCounts newCounts;

  factory PatientHome.fromJson(Json json) => PatientHome(
        fullName: json['fullName'] as String,
        latestVisit: json['latestVisit'] == null ? null : VisitListItem.fromJson(json['latestVisit'] as Json),
        latestPrescription:
            json['latestPrescription'] == null ? null : PrescriptionListItem.fromJson(json['latestPrescription'] as Json),
        nextFollowUp: json['nextFollowUp'] == null ? null : FollowUp.fromJson(json['nextFollowUp'] as Json),
        recentFiles: _list(json['recentFiles'], RecordListItem.fromJson),
        newCounts: NewCounts.fromJson(json['new'] as Json),
      );
}

// ---- P14 ------------------------------------------------------------------------------------

enum DeletionRequestStatus {
  pending,
  approved,
  rejected;

  static DeletionRequestStatus fromJson(String value) => DeletionRequestStatus.values.byName(value);
}

class DeletionRequest {
  const DeletionRequest({
    required this.id,
    required this.status,
    this.reason,
    required this.createdAt,
    this.reviewedAt,
    this.reviewNote,
  });

  final String id;
  final DeletionRequestStatus status;
  final String? reason;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewNote;

  factory DeletionRequest.fromJson(Json json) => DeletionRequest(
        id: json['id'] as String,
        status: DeletionRequestStatus.fromJson(json['status'] as String),
        reason: json['reason'] as String?,
        createdAt: _date(json['createdAt']),
        reviewedAt: _dateOrNull(json['reviewedAt']),
        reviewNote: json['reviewNote'] as String?,
      );
}

class NotificationPrefs {
  const NotificationPrefs({required this.chat, required this.reminders, required this.showPreview});

  final bool chat;
  final bool reminders;

  /// Show the message text in chat pushes (off by default, spec 10.1).
  final bool showPreview;

  NotificationPrefs copyWith({bool? chat, bool? reminders, bool? showPreview}) => NotificationPrefs(
        chat: chat ?? this.chat,
        reminders: reminders ?? this.reminders,
        showPreview: showPreview ?? this.showPreview,
      );
}

class PatientAccount {
  const PatientAccount({
    required this.personal,
    required this.locale,
    required this.themeMode,
    required this.notifications,
    this.acceptedTermsAt,
    this.deletionRequest,
  });

  final PersonalInfo personal;
  final String locale;
  final String themeMode;
  final NotificationPrefs notifications;
  final DateTime? acceptedTermsAt;
  final DeletionRequest? deletionRequest;

  bool get hasPendingDeletion => deletionRequest?.status == DeletionRequestStatus.pending;

  PatientAccount copyWith({
    NotificationPrefs? notifications,
    DateTime? acceptedTermsAt,
    DeletionRequest? deletionRequest,
  }) =>
      PatientAccount(
        personal: personal,
        locale: locale,
        themeMode: themeMode,
        notifications: notifications ?? this.notifications,
        acceptedTermsAt: acceptedTermsAt ?? this.acceptedTermsAt,
        deletionRequest: deletionRequest ?? this.deletionRequest,
      );

  factory PatientAccount.fromJson(Json json) => PatientAccount(
        personal: PersonalInfo.fromJson(json['personal'] as Json),
        locale: json['locale'] as String,
        themeMode: json['themeMode'] as String,
        notifications: NotificationPrefs(
          chat: json['notifyChat'] as bool,
          reminders: json['notifyReminders'] as bool,
          showPreview: json['notifyShowPreview'] as bool,
        ),
        acceptedTermsAt: _dateOrNull(json['acceptedTermsAt']),
        deletionRequest:
            json['deletionRequest'] == null ? null : DeletionRequest.fromJson(json['deletionRequest'] as Json),
      );
}
