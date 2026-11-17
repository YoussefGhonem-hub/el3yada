import 'package:flutter/widgets.dart' show Locale;

import '../../../l10n/gen/app_localizations.dart';
import '../../sessions/domain/session_models.dart' show SessionType;
import '../domain/prescription_models.dart';

/// Words shared by the editors, D15 and the PDF. The PDF passes the
/// prescription language's localizations, not the app's (BR-RX4).

String rxVisitType(AppLocalizations l10n, SessionType type) =>
    type == SessionType.examination ? l10n.rxPdfExamination : l10n.rxPdfConsultation;

String rxKindName(AppLocalizations l10n, PrescriptionKind kind) =>
    kind == PrescriptionKind.medication ? l10n.rxKindMedication : l10n.rxKindInvestigations;

/// One of [DrugForms.all] in [l10n]'s language.
String rxFormName(AppLocalizations l10n, String form) => switch (form) {
      DrugForms.tablet => l10n.rxFormTablet,
      DrugForms.capsule => l10n.rxFormCapsule,
      DrugForms.syrup => l10n.rxFormSyrup,
      DrugForms.injection => l10n.rxFormInjection,
      DrugForms.cream => l10n.rxFormCream,
      DrugForms.drops => l10n.rxFormDrops,
      DrugForms.inhaler => l10n.rxFormInhaler,
      DrugForms.suppository => l10n.rxFormSuppository,
      DrugForms.sachet => l10n.rxFormSachet,
      DrugForms.other => l10n.rxFormOther,
      _ => form,
    };

/// A form for display: the known ones translated, anything typed as typed.
String rxFormLabel(AppLocalizations l10n, String? form) =>
    form == null ? '' : (DrugForms.isKnown(form) ? rxFormName(l10n, form) : form);

String rxTimingName(AppLocalizations l10n, MedicationTiming timing) => switch (timing) {
      MedicationTiming.beforeFood => l10n.rxTimingBeforeFood,
      MedicationTiming.afterFood => l10n.rxTimingAfterFood,
      MedicationTiming.withFood => l10n.rxTimingWithFood,
      MedicationTiming.unspecified => l10n.rxTimingUnspecified,
    };

/// "قرص، كل 12 ساعة، بعد الأكل، بحد أقصى 4 أقراص": the second line of a
/// medicine on the page and in the editor.
String rxInstructionLine(AppLocalizations l10n, MedicationItem item) => [
      ?item.dose,
      ?item.frequency,
      if (item.timing != MedicationTiming.unspecified) rxTimingName(l10n, item.timing),
      ?item.instructions,
    ].where((part) => part.trim().isNotEmpty).join(l10n.rxListSeparator);

/// How long a medicine is taken: a number of days or weeks, or continuous.
enum RxDurationUnit { days, weeks, continuous }

/// «5 أيام», «أسبوعين», «مستمر» (stored as text, spec 6.4).
String rxDurationText(AppLocalizations l10n, RxDurationUnit unit, int count) => switch (unit) {
      RxDurationUnit.days => l10n.rxDurationDays(count),
      RxDurationUnit.weeks => l10n.rxDurationWeeks(count),
      RxDurationUnit.continuous => l10n.rxDurationContinuous,
    };

/// A duration the app wrote with [rxDurationText], in Arabic or English, read
/// back into its parts. Null for a duration the doctor typed freely.
({RxDurationUnit unit, int count})? parseRxDuration(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final digits = RegExp(r'\d+').firstMatch(trimmed)?.group(0);
  // «يوم واحد» and «يومين» have no digits.
  final counts = digits == null ? const [1, 2] : [int.parse(digits)];
  for (final language in const ['ar', 'en']) {
    final l10n = lookupAppLocalizations(Locale(language));
    if (trimmed == l10n.rxDurationContinuous) return (unit: RxDurationUnit.continuous, count: 0);
    for (final count in counts) {
      for (final unit in const [RxDurationUnit.days, RxDurationUnit.weeks]) {
        if (rxDurationText(l10n, unit, count) == trimmed) return (unit: unit, count: count);
      }
    }
  }
  return null;
}

/// A medicine's duration in [l10n]'s language. The duration is stored as text
/// in the language of the app that wrote it, so one the app wrote is
/// translated: an English prescription written from the Arabic app says
/// "7 days", not «7 أيام». A duration the doctor typed stays as typed.
String rxDurationLabel(AppLocalizations l10n, String duration) {
  final parts = parseRxDuration(duration);
  return parts == null ? duration : rxDurationText(l10n, parts.unit, parts.count);
}
