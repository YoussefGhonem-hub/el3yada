import 'package:flutter/widgets.dart';

import '../../../../core/format/app_format.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/patient_models.dart';
import 'clinic_ui.dart';

/// Texts the patient screens share (D4–D7).

String genderLabel(AppLocalizations l10n, Gender gender) =>
    gender == Gender.female ? l10n.patientGenderFemale : l10n.patientGenderMale;

/// «36 سنة», with «≈» when the age was typed instead of a date (D5).
String patientAge(AppLocalizations l10n, int years, {bool estimated = false}) {
  final age = l10n.patientAgeYears(years);
  return estimated ? '≈ $age' : age;
}

/// «36 سنة، أنثى» / "36 years, female".
String patientAgeGender(AppLocalizations l10n, int years, Gender gender, {bool estimated = false}) =>
    l10n.patientAgeGender(patientAge(l10n, years, estimated: estimated), genderLabel(l10n, gender));

/// «3 زيارات: 1 كشف، 2 استشارة».
String visitsSummary(AppLocalizations l10n, PatientVisits visits) => l10n.patientVisitsSummary(
      l10n.patientVisitsCount(visits.total),
      l10n.feesExaminationCount(visits.examinations),
      l10n.feesConsultationCount(visits.consultations),
    );

String lastVisitFilterLabel(AppLocalizations l10n, LastVisitFilter filter) => switch (filter) {
      LastVisitFilter.thisWeek => l10n.patientLastVisitThisWeek,
      LastVisitFilter.thisMonth => l10n.patientLastVisitThisMonth,
      LastVisitFilter.notSeen3m => l10n.patientLastVisitNotSeen3m,
      LastVisitFilter.notSeen6m => l10n.patientLastVisitNotSeen6m,
      LastVisitFilter.notSeen12m => l10n.patientLastVisitNotSeen12m,
      LastVisitFilter.never => l10n.patientLastVisitNever,
    };

String registerSortLabel(AppLocalizations l10n, RegisterSort sort) => switch (sort) {
      RegisterSort.lastVisit => l10n.patientColumnLastVisit,
      RegisterSort.fileNumber => l10n.patientSortFileNumber,
      RegisterSort.name => l10n.patientColumnName,
      RegisterSort.phone => l10n.patientColumnPhone,
      RegisterSort.age => l10n.patientColumnAge,
      RegisterSort.gender => l10n.patientSortGender,
      RegisterSort.firstVisit => l10n.patientColumnFirstVisit,
      RegisterSort.visits => l10n.patientColumnVisits,
      RegisterSort.examinations => l10n.patientSortExaminations,
      RegisterSort.consultations => l10n.patientSortConsultations,
      RegisterSort.files => l10n.patientSortFiles,
      RegisterSort.linkedAt => l10n.patientSortLinkedAt,
      RegisterSort.totalPaid => l10n.patientTotalPaid,
      RegisterSort.allergies => l10n.patientColumnAllergies,
    };

/// What a screen reader hears for a register row.
String patientRowSemantics(BuildContext context, PatientRegisterRow row) {
  final l10n = AppLocalizations.of(context);
  final last = row.visits.lastVisit;
  return [
    row.fullName,
    l10n.patientFileNumber('${row.fileNumber}'),
    patientAgeGender(l10n, row.ageYears, row.gender, estimated: row.dateOfBirthEstimated),
    AppFormat.phone(row.phone),
    if (row.hasAllergies ?? false) l10n.patientHasAllergies,
    if (last == null)
      l10n.patientNoVisits
    else
      l10n.patientLastVisitSemantics(
        sessionTypeLabel(l10n, last.type),
        ClinicFormat.day(context, last.day),
        ClinicFormat.daysAgo(l10n, last.daysAgo),
      ),
    if (row.archived) l10n.patientArchived,
  ].join(l10n.adminListSeparator);
}
