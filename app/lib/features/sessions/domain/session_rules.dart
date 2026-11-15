import '../../../core/format/app_format.dart';
import 'session_models.dart';

/// What D8 step 1 shows for the consultation rule (BR-S2, BR-S3, BR-S4),
/// worked out from `newSessionInfo`. The server checks again on save.
class ConsultationRuleView {
  const ConsultationRuleView({
    required this.offerConsultation,
    required this.consultationEnabled,
    required this.block,
    required this.count,
    required this.max,
  });

  factory ConsultationRuleView.from(NewSessionInfo info) {
    final block = info.consultationBlockedReason ??
        (info.isFirstVisit
            ? ConsultationBlock.firstVisit
            : (!info.consultationAllowed || !info.consultation.allowed ? ConsultationBlock.limitReached : null));
    return ConsultationRuleView(
      // A first visit offers only Examination (D8).
      offerConsultation: block != ConsultationBlock.firstVisit,
      consultationEnabled: block == null,
      block: block,
      count: info.consultationsSinceExam,
      max: info.maxConsecutiveConsultations,
    );
  }

  /// False for a first visit: the Consultation card isn't shown at all.
  final bool offerConsultation;

  /// The card can be picked.
  final bool consultationEnabled;
  final ConsultationBlock? block;

  /// Consultations in a row since the last examination.
  final int count;

  /// `maxConsecutiveConsultations` (admin setting, default 2).
  final int max;

  /// Which types can be saved now. An examination always can.
  Set<SessionType> get allowedTypes => {SessionType.examination, if (consultationEnabled) SessionType.consultation};

  /// «استشارة 1 من 2 منذ آخر كشف» is shown after the first visit.
  bool get showCount => block != ConsultationBlock.firstVisit;
}

/// BR-S10: the amount the patient pays the clinic.
abstract final class AmountRules {
  /// 100,000 EGP (spec section 11).
  static const maxPiasters = 10000000;

  /// The visit price for [type] in this branch, or null when none is set
  /// (then the amount must be typed, BR-PR6).
  static int? defaultFor(NewSessionInfo info, SessionType type) => info.option(type).visitPricePiasters;

  /// Whether the amount has to be typed.
  static bool requiredFor(NewSessionInfo info, SessionType type) => defaultFor(info, type) == null;

  /// The text field's value for [piasters]: `300`, `150.50`, or empty.
  static String text(int? piasters) => piasters == null ? '' : AppFormat.egpNumber(piasters).replaceAll(',', '');

  /// The typed amount as piasters, or a problem. Empty is fine unless [required]
  /// (the server then uses the visit price).
  static ({int? piasters, AmountProblem? problem}) parse(String text, {required bool required}) {
    final value = text.trim();
    if (value.isEmpty) return (piasters: null, problem: required ? AmountProblem.required : null);
    final piasters = AppFormat.parseEgp(value);
    if (piasters == null) return (piasters: null, problem: AmountProblem.invalid);
    if (piasters > maxPiasters) return (piasters: null, problem: AmountProblem.outOfRange);
    return (piasters: piasters, problem: null);
  }
}

enum AmountProblem { required, invalid, outOfRange }

/// The vitals D8 and D9 collect, with the API's limits (which refuse) and
/// the usual ranges (which only warn, spec section 11: «القيمة غير معتادة، تأكد منها»).
enum VitalField {
  bpSys(apiMin: 30, apiMax: 300, usualMin: 50, usualMax: 260, decimals: 0),
  bpDia(apiMin: 10, apiMax: 200, usualMin: 30, usualMax: 150, decimals: 0),
  pulse(apiMin: 20, apiMax: 300, usualMin: 40, usualMax: 180, decimals: 0),
  tempC(apiMin: 25, apiMax: 45, usualMin: 34, usualMax: 43, decimals: 1),
  weightKg(apiMin: 0.2, apiMax: 400, usualMin: 0.5, usualMax: 250, decimals: 2),
  heightCm(apiMin: 20, apiMax: 250, usualMin: 40, usualMax: 220, decimals: 1),
  glucose(apiMin: 10, apiMax: 1500, usualMin: 50, usualMax: 400, decimals: 0);

  const VitalField({
    required this.apiMin,
    required this.apiMax,
    required this.usualMin,
    required this.usualMax,
    required this.decimals,
  });

  final double apiMin;
  final double apiMax;
  final double usualMin;
  final double usualMax;
  final int decimals;

  /// The typed value (Arabic-Indic digits and `٫` too), or null for empty.
  /// Throws [FormatException] when it isn't a number.
  double? parse(String text) {
    final value = text.trim().replaceAll('٫', '.').replaceAll(',', '.');
    if (value.isEmpty) return null;
    final digits = StringBuffer();
    for (final rune in value.runes) {
      digits.writeCharCode(rune >= 0x0660 && rune <= 0x0669 ? 0x30 + rune - 0x0660 : rune);
    }
    final number = double.tryParse(digits.toString());
    if (number == null || number.isNaN || number.isInfinite) throw FormatException('Not a number', text);
    return number;
  }

  /// Null when fine; [VitalProblem.outOfRange] refuses, [VitalProblem.unusual] warns.
  VitalProblem? check(double? value) {
    if (value == null) return null;
    if (decimals == 0 && value != value.roundToDouble()) return VitalProblem.invalid;
    if (value < apiMin || value > apiMax) return VitalProblem.outOfRange;
    if (value < usualMin || value > usualMax) return VitalProblem.unusual;
    return null;
  }

  /// The value as the API stores it (rounded to [decimals]).
  num round(double value) {
    if (decimals == 0) return value.round();
    final factor = [1, 10, 100][decimals];
    return (value * factor).round() / factor;
  }

  /// For the text field: `120`, `37.2`.
  String text(num? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }
}

enum VitalProblem { invalid, outOfRange, unusual }

/// Builds [Vitals] from the typed texts. Blood pressure needs both values or
/// neither. Returns the problems per field (the warnings included) and the
/// vitals when nothing refuses.
({Vitals? vitals, Map<VitalField, VitalProblem> problems, bool bpIncomplete}) readVitals(
  Map<VitalField, String> texts,
) {
  final values = <VitalField, num>{};
  final problems = <VitalField, VitalProblem>{};
  for (final field in VitalField.values) {
    final text = texts[field] ?? '';
    try {
      final value = field.parse(text);
      final problem = field.check(value);
      if (problem != null) problems[field] = problem;
      if (value != null && problem != VitalProblem.outOfRange && problem != VitalProblem.invalid) {
        values[field] = field.round(value);
      }
    } on FormatException {
      problems[field] = VitalProblem.invalid;
    }
  }
  final bpIncomplete = (texts[VitalField.bpSys] ?? '').trim().isEmpty != (texts[VitalField.bpDia] ?? '').trim().isEmpty;
  final refuses = bpIncomplete || problems.values.any((p) => p != VitalProblem.unusual);
  return (
    vitals: refuses
        ? null
        : Vitals(
            bpSys: values[VitalField.bpSys]?.toInt(),
            bpDia: values[VitalField.bpDia]?.toInt(),
            pulse: values[VitalField.pulse]?.toInt(),
            tempC: values[VitalField.tempC]?.toDouble(),
            weightKg: values[VitalField.weightKg]?.toDouble(),
            heightCm: values[VitalField.heightCm]?.toDouble(),
            glucose: values[VitalField.glucose]?.toInt(),
          ),
    problems: problems,
    bpIncomplete: bpIncomplete,
  );
}

/// The typed texts of [vitals], for editing in D9.
Map<VitalField, String> vitalsTexts(Vitals vitals) => {
      VitalField.bpSys: VitalField.bpSys.text(vitals.bpSys),
      VitalField.bpDia: VitalField.bpDia.text(vitals.bpDia),
      VitalField.pulse: VitalField.pulse.text(vitals.pulse),
      VitalField.tempC: VitalField.tempC.text(vitals.tempC),
      VitalField.weightKg: VitalField.weightKg.text(vitals.weightKg),
      VitalField.heightCm: VitalField.heightCm.text(vitals.heightCm),
      VitalField.glucose: VitalField.glucose.text(vitals.glucose),
    };
