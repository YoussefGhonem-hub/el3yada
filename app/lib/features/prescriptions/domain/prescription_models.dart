import '../../sessions/domain/session_models.dart' show dayKey, parseDayOrNull;

export '../../../core/data/paged.dart';

/// Models for prescriptions and requests (D9, D13–D15, D22, D23, AS7, AS8).
/// The contract is backend/docs/api-phase-3-prescriptions.md; the API's
/// `Prescriptions/PrescriptionModels.cs` is the source of truth.

DateTime _time(Object? value) => DateTime.parse(value! as String).toUtc();
DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);
String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;
Map<String, dynamic> _map(Object? value) => (value as Map).cast<String, dynamic>();

/// «روشتة علاج» or «روشتة تحاليل وأشعة» (spec 6.4).
enum PrescriptionKind {
  medication,
  investigations;

  static PrescriptionKind fromWire(Object? value) => value == 'investigations' ? investigations : medication;

  String get wire => name;
}

/// BR-RX2: `draft` → `readyForReview` [S] → `sent` → `cancelled`.
enum PrescriptionStatus {
  draft,
  readyForReview,
  sent,
  cancelled;

  static PrescriptionStatus fromWire(Object? value) => switch (value) {
        'readyForReview' => readyForReview,
        'sent' => sent,
        'cancelled' => cancelled,
        _ => draft,
      };

  String get wire => name;

  /// Drafts and `readyForReview` documents can still be edited and sent.
  bool get editable => this == draft || this == readyForReview;
}

/// When to take a medicine (spec 6.4).
enum MedicationTiming {
  unspecified,
  beforeFood,
  afterFood,
  withFood;

  static MedicationTiming fromWire(Object? value) {
    for (final timing in values) {
      if (timing.name == value) return timing;
    }
    return unspecified;
  }

  String get wire => name;
}

/// The forms the editor offers (spec 6.4). Anything else is typed.
abstract final class DrugForms {
  static const tablet = 'tablet';
  static const capsule = 'capsule';
  static const syrup = 'syrup';
  static const injection = 'injection';
  static const cream = 'cream';
  static const drops = 'drops';
  static const inhaler = 'inhaler';
  static const suppository = 'suppository';
  static const sachet = 'sachet';
  static const other = 'other';

  static const all = [tablet, capsule, syrup, injection, cream, drops, inhaler, suppository, sachet, other];

  static bool isKnown(String? form) => form != null && all.contains(form);
}

/// One medicine on a medication prescription.
class MedicationItem {
  const MedicationItem({
    required this.drugName,
    this.activeIngredient,
    this.catalogId,
    this.form,
    this.strength,
    this.dose,
    this.frequency,
    this.timing = MedicationTiming.unspecified,
    this.duration,
    this.instructions,
  });

  factory MedicationItem.fromJson(Map<String, dynamic> json) => MedicationItem(
        drugName: json['drugName'] as String? ?? '',
        activeIngredient: _text(json['activeIngredient']),
        catalogId: _text(json['catalogId']),
        form: _text(json['form']),
        strength: _text(json['strength']),
        dose: _text(json['dose']),
        frequency: _text(json['frequency']),
        timing: MedicationTiming.fromWire(json['timing']),
        duration: _text(json['duration']),
        instructions: _text(json['instructions']),
      );

  final String drugName;
  final String? activeIngredient;

  /// The catalog row picked (BR-CAT7), or null for typed text (BR-CAT8).
  final String? catalogId;

  /// One of [DrugForms.all], or free text.
  final String? form;
  final String? strength;
  final String? dose;
  final String? frequency;
  final MedicationTiming timing;

  /// Formatted by the app: «5 أيام», «أسبوعين», «مستمر».
  final String? duration;
  final String? instructions;

  Map<String, Object?> toJson() => {
        'drugName': drugName.trim(),
        'activeIngredient': _clean(activeIngredient),
        'catalogId': _clean(catalogId),
        'form': _clean(form),
        'strength': _clean(strength),
        'dose': _clean(dose),
        'frequency': _clean(frequency),
        'timing': timing.wire,
        'duration': _clean(duration),
        'instructions': _clean(instructions),
      };

  MedicationItem copyWith({
    String? drugName,
    String? Function()? activeIngredient,
    String? Function()? catalogId,
    String? Function()? form,
    String? Function()? strength,
    String? Function()? dose,
    String? Function()? frequency,
    MedicationTiming? timing,
    String? Function()? duration,
    String? Function()? instructions,
  }) =>
      MedicationItem(
        drugName: drugName ?? this.drugName,
        activeIngredient: activeIngredient == null ? this.activeIngredient : activeIngredient(),
        catalogId: catalogId == null ? this.catalogId : catalogId(),
        form: form == null ? this.form : form(),
        strength: strength == null ? this.strength : strength(),
        dose: dose == null ? this.dose : dose(),
        frequency: frequency == null ? this.frequency : frequency(),
        timing: timing ?? this.timing,
        duration: duration == null ? this.duration : duration(),
        instructions: instructions == null ? this.instructions : instructions(),
      );
}

/// `lab` or `radiology` on an investigations request.
enum InvestigationCategory {
  lab,
  radiology;

  static InvestigationCategory fromWire(Object? value) => value == 'radiology' ? radiology : lab;

  String get wire => name;
}

/// One test on an investigations request.
class InvestigationItem {
  const InvestigationItem({required this.category, required this.name, this.loincCode, this.notes});

  factory InvestigationItem.fromJson(Map<String, dynamic> json) => InvestigationItem(
        category: InvestigationCategory.fromWire(json['category']),
        name: json['name'] as String? ?? '',
        loincCode: _text(json['loincCode']),
        notes: _text(json['notes']),
      );

  final InvestigationCategory category;
  final String name;

  /// The LOINC code picked from the catalog, or null for typed text.
  final String? loincCode;

  /// «صائم 12 ساعة».
  final String? notes;

  Map<String, Object?> toJson() => {
        'category': category.wire,
        'name': name.trim(),
        'loincCode': _clean(loincCode),
        'notes': _clean(notes),
      };

  InvestigationItem copyWith({InvestigationCategory? category, String? name, String? Function()? notes}) => InvestigationItem(
        category: category ?? this.category,
        name: name ?? this.name,
        loincCode: loincCode,
        notes: notes == null ? this.notes : notes(),
      );
}

String? _clean(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

/// Who created the draft (BR-AS10: the doctor sees "Prepared by …").
class PreparedBy {
  const PreparedBy({required this.userId, required this.role, required this.name});

  factory PreparedBy.fromJson(Map<String, dynamic> json) =>
      PreparedBy(userId: json['userId'] as String, role: json['role'] as String, name: json['name'] as String? ?? '');

  final String userId;
  final String role;
  final String name;

  bool get isAssistant => role == 'assistant';
}

/// One prescription or request (the API's view).
class Prescription {
  const Prescription({
    required this.prescriptionId,
    required this.patientId,
    required this.sessionId,
    required this.kind,
    required this.status,
    this.diagnosis,
    this.advice,
    this.followUpDate,
    this.medications = const [],
    this.investigations = const [],
    this.preparedBy,
    this.sentAt,
    this.cancelledAt,
    this.cancelReason,
    this.replacesRxId,
    this.replacedById,
    required this.qrShortCode,
    required this.qrUrl,
    this.hasPdf = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final kind = PrescriptionKind.fromWire(json['kind']);
    final items = [for (final row in (json['items'] as List?) ?? const []) _map(row)];
    return Prescription(
      prescriptionId: json['prescriptionId'] as String,
      patientId: json['patientId'] as String,
      sessionId: json['sessionId'] as String,
      kind: kind,
      status: PrescriptionStatus.fromWire(json['status']),
      diagnosis: _text(json['diagnosis']),
      advice: _text(json['advice']),
      followUpDate: parseDayOrNull(json['followUpDate']),
      medications: kind == PrescriptionKind.medication ? [for (final item in items) MedicationItem.fromJson(item)] : const [],
      investigations:
          kind == PrescriptionKind.investigations ? [for (final item in items) InvestigationItem.fromJson(item)] : const [],
      preparedBy: json['preparedBy'] == null ? null : PreparedBy.fromJson(_map(json['preparedBy'])),
      sentAt: _timeOrNull(json['sentAt']),
      cancelledAt: _timeOrNull(json['cancelledAt']),
      cancelReason: _text(json['cancelReason']),
      replacesRxId: _text(json['replacesRxId']),
      replacedById: _text(json['replacedById']),
      qrShortCode: json['qrShortCode'] as String? ?? '',
      qrUrl: json['qrUrl'] as String? ?? '',
      hasPdf: json['hasPdf'] as bool? ?? false,
      createdAt: _time(json['createdAt']),
      updatedAt: _time(json['updatedAt']),
    );
  }

  final String prescriptionId;
  final String patientId;
  final String sessionId;
  final PrescriptionKind kind;
  final PrescriptionStatus status;
  final String? diagnosis;
  final String? advice;

  /// Zone 6: «موعد المتابعة» (medication) or «إحضار النتائج في» (investigations).
  final DateTime? followUpDate;
  final List<MedicationItem> medications;
  final List<InvestigationItem> investigations;
  final PreparedBy? preparedBy;
  final DateTime? sentAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  /// This document is a new copy of a cancelled one.
  final String? replacesRxId;

  /// The new copy made from this cancelled document.
  final String? replacedById;
  final String qrShortCode;

  /// Printed as the QR code (6.4.1).
  final String qrUrl;
  final bool hasPdf;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get itemCount => kind == PrescriptionKind.medication ? medications.length : investigations.length;

  bool get isEmpty => itemCount == 0;

  /// What the editor saves (`updatePrescriptionDraft`).
  PrescriptionDraftInput toInput() => PrescriptionDraftInput(
        diagnosis: diagnosis,
        advice: advice,
        followUpDate: followUpDate,
        medications: medications,
        investigations: investigations,
      );
}

/// `updatePrescriptionDraft`: everything replaced; items in display order.
class PrescriptionDraftInput {
  const PrescriptionDraftInput({
    this.diagnosis,
    this.advice,
    this.followUpDate,
    this.medications = const [],
    this.investigations = const [],
  });

  final String? diagnosis;
  final String? advice;
  final DateTime? followUpDate;
  final List<MedicationItem> medications;
  final List<InvestigationItem> investigations;

  Map<String, Object?> toJson(PrescriptionKind kind) => {
        'diagnosis': _clean(diagnosis),
        'advice': _clean(advice),
        'followUpDate': followUpDate == null ? null : dayKey(followUpDate!),
        'items': kind == PrescriptionKind.medication
            ? [for (final item in medications) item.toJson()]
            : [for (final item in investigations) item.toJson()],
      };
}

/// One line of the doctor's item history ("used before", BR-CAT4 group 1).
class ItemHistoryEntry {
  const ItemHistoryEntry({
    required this.itemId,
    required this.kind,
    required this.name,
    this.catalogId,
    this.form = '',
    this.strength = '',
    required this.useCount,
    required this.lastUsedAt,
  });

  factory ItemHistoryEntry.fromJson(Map<String, dynamic> json) => ItemHistoryEntry(
        itemId: json['itemId'] as String,
        kind: json['kind'] as String,
        name: json['name'] as String,
        catalogId: _text(json['catalogId']),
        form: json['form'] as String? ?? '',
        strength: json['strength'] as String? ?? '',
        useCount: (json['useCount'] as num).toInt(),
        lastUsedAt: _time(json['lastUsedAt']),
      );

  final String itemId;

  /// `drug`, `lab` or `radiology`.
  final String kind;
  final String name;

  /// The drug's catalog ID, or a test's LOINC code.
  final String? catalogId;
  final String form;
  final String strength;
  final int useCount;
  final DateTime lastUsedAt;

  bool get isDrug => kind == 'drug';
}

/// A saved template (BR-RX6, D23).
class PrescriptionTemplate {
  const PrescriptionTemplate({
    required this.templateId,
    required this.kind,
    required this.name,
    this.medications = const [],
    this.investigations = const [],
    this.advice,
    required this.updatedAt,
  });

  factory PrescriptionTemplate.fromJson(Map<String, dynamic> json) {
    final kind = PrescriptionKind.fromWire(json['kind']);
    final items = [for (final row in (json['items'] as List?) ?? const []) _map(row)];
    return PrescriptionTemplate(
      templateId: json['templateId'] as String,
      kind: kind,
      name: json['name'] as String,
      medications: kind == PrescriptionKind.medication ? [for (final item in items) MedicationItem.fromJson(item)] : const [],
      investigations:
          kind == PrescriptionKind.investigations ? [for (final item in items) InvestigationItem.fromJson(item)] : const [],
      advice: _text(json['advice']),
      updatedAt: _time(json['updatedAt']),
    );
  }

  final String templateId;
  final PrescriptionKind kind;
  final String name;
  final List<MedicationItem> medications;
  final List<InvestigationItem> investigations;
  final String? advice;
  final DateTime updatedAt;

  int get itemCount => kind == PrescriptionKind.medication ? medications.length : investigations.length;

  List<Map<String, Object?>> itemsJson() => kind == PrescriptionKind.medication
      ? [for (final item in medications) item.toJson()]
      : [for (final item in investigations) item.toJson()];
}

/// The paper the prescription prints on (BR-RX5).
enum RxPaperSize {
  a5,
  a4,
  custom;

  static RxPaperSize fromWire(Object? value) => switch (value) {
        'A4' => a4,
        'custom' => custom,
        _ => a5,
      };

  String get wire => switch (this) {
        a5 => 'A5',
        a4 => 'A4',
        custom => 'custom',
      };
}

/// D22: the prescription header and print settings (`GET /api/doctor/rxSettings`).
class RxSettings {
  const RxSettings({
    this.language = 'ar',
    this.accentColor = defaultColor,
    this.paperSize = RxPaperSize.a5,
    this.customWidthMm,
    this.customHeightMm,
    this.preprinted = false,
    this.marginTopMm,
    this.marginBottomMm,
    this.footerText,
    this.hasLogo = false,
    this.hasSignature = false,
    this.updatedAt,
  });

  factory RxSettings.fromJson(Map<String, dynamic> json) => RxSettings(
        language: json['language'] == 'en' ? 'en' : 'ar',
        accentColor: (json['accentColor'] as String?) ?? defaultColor,
        paperSize: RxPaperSize.fromWire(json['paperSize']),
        customWidthMm: (json['customWidthMm'] as num?)?.toDouble(),
        customHeightMm: (json['customHeightMm'] as num?)?.toDouble(),
        preprinted: json['preprinted'] as bool? ?? false,
        marginTopMm: (json['marginTopMm'] as num?)?.toDouble(),
        marginBottomMm: (json['marginBottomMm'] as num?)?.toDouble(),
        footerText: _text(json['footerText']),
        hasLogo: json['hasLogo'] as bool? ?? false,
        hasSignature: json['hasSignature'] as bool? ?? false,
        updatedAt: _timeOrNull(json['updatedAt']),
      );

  /// The brand pine.
  static const defaultColor = '#0F4C45';

  /// `ar` or `en`: the prescription's language, independent of the app's.
  final String language;

  /// `#RRGGBB`.
  final String accentColor;
  final RxPaperSize paperSize;
  final double? customWidthMm;
  final double? customHeightMm;

  /// Pre-printed paper: no header or footer, the margins leave their space.
  final bool preprinted;
  final double? marginTopMm;
  final double? marginBottomMm;
  final String? footerText;
  final bool hasLogo;
  final bool hasSignature;
  final DateTime? updatedAt;

  bool get english => language == 'en';

  /// `0xFF0F4C45`.
  int get accentArgb => 0xFF000000 | int.parse(accentColor.substring(1), radix: 16);

  Map<String, Object?> toJson() => {
        'language': language,
        'accentColor': accentColor.toUpperCase(),
        'paperSize': paperSize.wire,
        'customWidthMm': paperSize == RxPaperSize.custom ? customWidthMm : null,
        'customHeightMm': paperSize == RxPaperSize.custom ? customHeightMm : null,
        'preprinted': preprinted,
        'marginTopMm': marginTopMm,
        'marginBottomMm': marginBottomMm,
        'footerText': _clean(footerText),
      };

  RxSettings copyWith({
    String? language,
    String? accentColor,
    RxPaperSize? paperSize,
    double? Function()? customWidthMm,
    double? Function()? customHeightMm,
    bool? preprinted,
    double? Function()? marginTopMm,
    double? Function()? marginBottomMm,
    String? Function()? footerText,
    bool? hasLogo,
    bool? hasSignature,
  }) =>
      RxSettings(
        language: language ?? this.language,
        accentColor: accentColor ?? this.accentColor,
        paperSize: paperSize ?? this.paperSize,
        customWidthMm: customWidthMm == null ? this.customWidthMm : customWidthMm(),
        customHeightMm: customHeightMm == null ? this.customHeightMm : customHeightMm(),
        preprinted: preprinted ?? this.preprinted,
        marginTopMm: marginTopMm == null ? this.marginTopMm : marginTopMm(),
        marginBottomMm: marginBottomMm == null ? this.marginBottomMm : marginBottomMm(),
        footerText: footerText == null ? this.footerText : footerText(),
        hasLogo: hasLogo ?? this.hasLogo,
        hasSignature: hasSignature ?? this.hasSignature,
        updatedAt: updatedAt,
      );
}

/// The two images of the prescription header (D22).
enum RxImageKind {
  logo,
  signature;

  String get wire => name;
}
