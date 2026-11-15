import 'json_read.dart';

/// Branch models for D28, D29 (backend/docs/api-phase-2-clinic.md,
/// "Branches"). Plain classes with hand-written `fromJson`, like the admin
/// models. Times are Cairo `HH:mm`; weekdays are ISO (1 = Monday … 7 =
/// Sunday) and the app starts the week on Saturday.

/// `Branches.Status` (BR-BR2).
abstract final class BranchStatuses {
  static const active = 'active';
  static const temporarilyClosed = 'temporarilyClosed';
  static const archived = 'archived';
}

/// The D29 "Clinic info for patients" checklists, in the API's order.
abstract final class BranchChecklists {
  static const paymentMethods = ['cash', 'card', 'instapay', 'wallet'];

  /// [S]
  static const amenities = ['elevator', 'parking', 'wheelchair', 'kidsArea'];
}

/// `contact.phones[i].label`.
abstract final class PhoneLabels {
  static const reception = 'reception';
  static const mobile = 'mobile';
  static const landline = 'landline';

  static const all = [reception, mobile, landline];
}

/// One weekly working period. A period that ends after midnight has
/// [endsNextDay] and still belongs to the day it starts (BR-BR2).
class BranchPeriod {
  const BranchPeriod({
    required this.weekday,
    required this.startLocal,
    required this.endLocal,
    this.endsNextDay = false,
    this.label,
    this.capacity,
  });

  factory BranchPeriod.fromJson(Map<String, dynamic> json) => BranchPeriod(
        weekday: json['weekday'] as int,
        startLocal: json['startLocal'] as String,
        endLocal: json['endLocal'] as String,
        endsNextDay: json['endsNextDay'] as bool? ?? false,
        label: readText(json['label']),
        capacity: json['capacity'] as int?,
      );

  /// ISO: 1 = Monday … 6 = Saturday, 7 = Sunday.
  final int weekday;
  final String startLocal;
  final String endLocal;
  final bool endsNextDay;

  /// صباحي / مسائي, optional.
  final String? label;

  /// Queue mode only; null uses the branch's `defaultCapacity`.
  final int? capacity;

  BranchPeriod copyWith({int? weekday}) => BranchPeriod(
        weekday: weekday ?? this.weekday,
        startLocal: startLocal,
        endLocal: endLocal,
        endsNextDay: endsNextDay,
        label: label,
        capacity: capacity,
      );

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'startLocal': startLocal,
        'endLocal': endLocal,
        'endsNextDay': endsNextDay,
        'label': label,
        'capacity': capacity,
      };

  @override
  bool operator ==(Object other) =>
      other is BranchPeriod &&
      other.weekday == weekday &&
      other.startLocal == startLocal &&
      other.endLocal == endLocal &&
      other.endsNextDay == endsNextDay &&
      other.label == label &&
      other.capacity == capacity;

  @override
  int get hashCode => Object.hash(weekday, startLocal, endLocal, endsNextDay, label, capacity);
}

/// A D28 card (`GET /api/branches` → `items`).
class BranchCard {
  const BranchCard({
    required this.id,
    required this.nameAr,
    this.nameEn,
    required this.governorate,
    required this.city,
    this.area,
    required this.status,
    this.closedMessage,
    this.reopenDate,
    required this.isDefault,
    required this.assigned,
    this.todayPeriods = const [],
    this.upcomingBookings = 0,
  });

  factory BranchCard.fromJson(Map<String, dynamic> json) => BranchCard(
        id: json['id'] as String,
        nameAr: json['nameAr'] as String,
        nameEn: readText(json['nameEn']),
        governorate: json['governorate'] as String,
        city: json['city'] as String,
        area: readText(json['area']),
        status: json['status'] as String,
        closedMessage: readText(json['closedMessage']),
        reopenDate: readDay(json['reopenDate']),
        isDefault: json['isDefault'] as bool? ?? false,
        assigned: json['assigned'] as bool? ?? true,
        todayPeriods: [for (final row in readList(json['todayPeriods'])) BranchPeriod.fromJson(row)],
        upcomingBookings: json['upcomingBookings'] as int? ?? 0,
      );

  final String id;
  final String nameAr;
  final String? nameEn;
  final String governorate;
  final String city;
  final String? area;
  final String status;
  final String? closedMessage;
  final DateTime? reopenDate;
  final bool isDefault;
  final bool assigned;
  final List<BranchPeriod> todayPeriods;
  final int upcomingBookings;

  bool get archived => status == BranchStatuses.archived;

  String name(String languageCode) => branchName(languageCode, nameAr, nameEn);
}

/// The name in [languageCode], falling back to Arabic (spec section 12).
String branchName(String languageCode, String nameAr, String? nameEn) =>
    languageCode == 'en' && nameEn != null && nameEn.trim().isNotEmpty ? nameEn : nameAr;

/// D28: `GET /api/branches`.
class BranchList {
  const BranchList({
    required this.items,
    required this.count,
    required this.limit,
    required this.canAdd,
    this.today,
    this.todayWeekday,
  });

  factory BranchList.fromJson(Map<String, dynamic> json) => BranchList(
        items: [for (final row in readList(json['items'])) BranchCard.fromJson(row)],
        count: json['count'] as int,
        limit: json['limit'] as int,
        canAdd: json['canAdd'] as bool,
        today: readDay(json['today']),
        todayWeekday: json['todayWeekday'] as int?,
      );

  final List<BranchCard> items;

  /// Branches that are not archived: what [limit] counts ("2 of 5").
  final int count;
  final int limit;
  final bool canAdd;
  final DateTime? today;
  final int? todayWeekday;
}

/// D29 Info tab.
class BranchInfo {
  const BranchInfo({required this.nameAr, this.nameEn, this.description});

  factory BranchInfo.fromJson(Map<String, dynamic> json) => BranchInfo(
        nameAr: json['nameAr'] as String,
        nameEn: readText(json['nameEn']),
        description: readText(json['description']),
      );

  final String nameAr;
  final String? nameEn;
  final String? description;

  Map<String, dynamic> toJson() => {'nameAr': nameAr, 'nameEn': nameEn, 'description': description};
}

/// D29 Address and map tab. [lat] and [lng] come together or not at all.
class BranchAddress {
  const BranchAddress({
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

  factory BranchAddress.fromJson(Map<String, dynamic> json) => BranchAddress(
        governorate: json['governorate'] as String,
        city: json['city'] as String,
        area: readText(json['area']),
        street: json['street'] as String,
        building: readText(json['building']),
        floor: readText(json['floor']),
        apartment: readText(json['apartment']),
        landmark: readText(json['landmark']),
        lat: readDouble(json['lat']),
        lng: readDouble(json['lng']),
      );

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

  bool get hasPin => lat != null && lng != null;

  Map<String, dynamic> toJson() => {
        'governorate': governorate,
        'city': city,
        'area': area,
        'street': street,
        'building': building,
        'floor': floor,
        'apartment': apartment,
        'landmark': landmark,
        'lat': lat,
        'lng': lng,
      };
}

/// One clinic phone: mobile, landline or hotline (E.164 in answers, hotlines
/// as typed).
class BranchContactPhone {
  const BranchContactPhone({required this.number, this.label = PhoneLabels.reception, this.isWhatsapp = false});

  factory BranchContactPhone.fromJson(Map<String, dynamic> json) => BranchContactPhone(
        number: json['number'] as String,
        label: json['label'] as String? ?? PhoneLabels.reception,
        isWhatsapp: json['isWhatsapp'] as bool? ?? false,
      );

  final String number;
  final String label;
  final bool isWhatsapp;

  Map<String, dynamic> toJson() => {'number': number, 'label': label, 'isWhatsapp': isWhatsapp};
}

/// D29 Contact tab: 1–5 phones and an optional email.
class BranchContact {
  const BranchContact({required this.phones, this.email});

  factory BranchContact.fromJson(Map<String, dynamic> json) => BranchContact(
        phones: [for (final row in readList(json['phones'])) BranchContactPhone.fromJson(row)],
        email: readText(json['email']),
      );

  final List<BranchContactPhone> phones;
  final String? email;

  Map<String, dynamic> toJson() => {'phones': [for (final phone in phones) phone.toJson()], 'email': email};
}

/// D29 Working hours tab. [bookingMode] and [defaultCapacity] are read-only
/// until Phase 6.
class BranchWorkingHours {
  const BranchWorkingHours({this.bookingMode = 'queue', this.defaultCapacity = 30, this.periods = const []});

  factory BranchWorkingHours.fromJson(Map<String, dynamic> json) => BranchWorkingHours(
        bookingMode: json['bookingMode'] as String? ?? 'queue',
        defaultCapacity: json['defaultCapacity'] as int? ?? 30,
        periods: [for (final row in readList(json['periods'])) BranchPeriod.fromJson(row)],
      );

  /// `queue` or `timed`.
  final String bookingMode;
  final int defaultCapacity;
  final List<BranchPeriod> periods;

  bool get queueMode => bookingMode == 'queue';
}

/// A branch's visit prices (section 6.15). The branch's own prices are null
/// when it uses the doctor's for that visit type (BR-PR2); the effective
/// ones are what patients see, null for «يُرجى الاستفسار من العيادة» (BR-PR6).
class VisitPrices {
  const VisitPrices({
    this.examinationPricePiasters,
    this.consultationPricePiasters,
    this.usesDoctorPrices = true,
    this.effectiveExaminationPricePiasters,
    this.effectiveConsultationPricePiasters,
  });

  factory VisitPrices.fromJson(Map<String, dynamic> json) => VisitPrices(
        examinationPricePiasters: json['examinationPricePiasters'] as int?,
        consultationPricePiasters: json['consultationPricePiasters'] as int?,
        usesDoctorPrices: json['usesDoctorPrices'] as bool? ?? true,
        effectiveExaminationPricePiasters: json['effectiveExaminationPricePiasters'] as int?,
        effectiveConsultationPricePiasters: json['effectiveConsultationPricePiasters'] as int?,
      );

  final int? examinationPricePiasters;
  final int? consultationPricePiasters;
  final bool usesDoctorPrices;
  final int? effectiveExaminationPricePiasters;
  final int? effectiveConsultationPricePiasters;
}

/// D29 Clinic info for patients.
class BranchClinicInfo {
  const BranchClinicInfo({this.prices = const VisitPrices(), this.paymentMethods = const [], this.amenities = const []});

  factory BranchClinicInfo.fromJson(Map<String, dynamic> json) => BranchClinicInfo(
        prices: json['prices'] == null ? const VisitPrices() : VisitPrices.fromJson(readMap(json['prices'])),
        paymentMethods: readStrings(json['paymentMethods']),
        amenities: readStrings(json['amenities']),
      );

  final VisitPrices prices;
  final List<String> paymentMethods;
  final List<String> amenities;
}

/// What `updateBranch` and `createBranch` take for the clinic info group:
/// the checklists only (prices go through `updatePrices`).
class BranchChecklistInput {
  const BranchChecklistInput({this.paymentMethods = const [], this.amenities = const []});

  final List<String> paymentMethods;
  final List<String> amenities;

  /// In the API's order, each once.
  List<String> get orderedPaymentMethods =>
      [for (final m in BranchChecklists.paymentMethods) if (paymentMethods.contains(m)) m];

  List<String> get orderedAmenities => [for (final a in BranchChecklists.amenities) if (amenities.contains(a)) a];

  Map<String, dynamic> toJson() => {'paymentMethods': orderedPaymentMethods, 'amenities': orderedAmenities};
}

/// D29: `GET /api/branches/{id}`, also the answer of every branch write.
class BranchDetails {
  const BranchDetails({
    required this.id,
    required this.isDefault,
    required this.status,
    this.closedMessage,
    this.reopenDate,
    this.assigned = true,
    required this.info,
    required this.address,
    required this.contact,
    required this.workingHours,
    required this.clinicInfo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BranchDetails.fromJson(Map<String, dynamic> json) => BranchDetails(
        id: json['id'] as String,
        isDefault: json['isDefault'] as bool? ?? false,
        status: json['status'] as String,
        closedMessage: readText(json['closedMessage']),
        reopenDate: readDay(json['reopenDate']),
        assigned: json['assigned'] as bool? ?? true,
        info: BranchInfo.fromJson(readMap(json['info'])),
        address: BranchAddress.fromJson(readMap(json['address'])),
        contact: BranchContact.fromJson(readMap(json['contact'])),
        workingHours: BranchWorkingHours.fromJson(readMap(json['workingHours'])),
        clinicInfo: BranchClinicInfo.fromJson(readMap(json['clinicInfo'])),
        createdAt: readTime(json['createdAt']),
        updatedAt: readTime(json['updatedAt']),
      );

  final String id;
  final bool isDefault;
  final String status;
  final String? closedMessage;
  final DateTime? reopenDate;
  final bool assigned;
  final BranchInfo info;
  final BranchAddress address;
  final BranchContact contact;
  final BranchWorkingHours workingHours;
  final BranchClinicInfo clinicInfo;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get archived => status == BranchStatuses.archived;
  bool get temporarilyClosed => status == BranchStatuses.temporarilyClosed;
  bool get active => status == BranchStatuses.active;

  String name(String languageCode) => branchName(languageCode, info.nameAr, info.nameEn);
}

/// A booking that stops a closure or an archive (BR-BR9), from the
/// `BRANCH_HAS_BOOKINGS` answer.
class BranchBooking {
  const BranchBooking({
    required this.id,
    required this.localDate,
    required this.periodStartLocal,
    required this.status,
    required this.visitType,
    this.patientId,
    this.name,
    this.isGuest = false,
  });

  factory BranchBooking.fromJson(Map<String, dynamic> json) => BranchBooking(
        id: json['id'] as String,
        localDate: readDay(json['localDate'])!,
        periodStartLocal: json['periodStartLocal'] as String? ?? '',
        status: json['status'] as String? ?? '',
        visitType: json['visitType'] as String? ?? 'examination',
        patientId: json['patientId'] as String?,
        name: readText(json['name']),
        isGuest: json['isGuest'] as bool? ?? false,
      );

  final String id;
  final DateTime localDate;
  final String periodStartLocal;
  final String status;

  /// `examination` or `consultation`.
  final String visitType;
  final String? patientId;
  final String? name;
  final bool isGuest;
}
