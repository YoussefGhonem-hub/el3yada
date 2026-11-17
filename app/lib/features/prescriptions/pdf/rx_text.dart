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
