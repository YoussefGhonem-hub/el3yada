import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../account_deletion/presentation/account_deletion_text.dart';
import '../domain/dose_text.dart';
import '../domain/patient_models.dart';

/// Formatting for the patient screens: dates, money and labels, in the current language.
extension PatientFormat on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String get _locale => Localizations.localeOf(this).languageCode;

  bool get isArabic => _locale == 'ar';

  String date(DateTime value) => DateFormat.yMMMd(_locale).format(value.toLocal());

  String dateTime(DateTime value) => DateFormat.yMMMd(_locale).add_jm().format(value.toLocal());

  String monthYear(DateTime value) => DateFormat.yMMMM(_locale).format(value.toLocal());

  /// Clinic hours are local `HH:mm` strings; shown as 5:00 PM / ٥:٠٠ م.
  String clock(String hhmm) {
    final parts = hhmm.split(':');
    final time = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.jm(_locale).format(time);
  }

  /// ISO weekday (1 = Monday) to its name.
  String weekday(int isoWeekday) =>
      DateFormat.EEEE(_locale).format(DateTime(2024, 1, isoWeekday)); // 1 Jan 2024 was a Monday

  /// Piasters to "350 EGP" / "350 ج.م". Null means the clinic hasn't set a price (BR-PR6).
  String price(int? piasters) {
    if (piasters == null) return l10n.priceAskClinic;
    final pounds = piasters / 100;
    final pattern = NumberFormat.decimalPatternDigits(locale: _locale, decimalDigits: piasters % 100 == 0 ? 0 : 2);
    return l10n.moneyEgp(pattern.format(pounds));
  }

  /// An erased doctor reads «طبيب محذوف» / "Deleted doctor" (spec 6.17).
  String doctorName(DoctorRef doctor) => l10n.personName(doctor.displayName(arabic: isArabic));

  String branchName(BranchRef branch) => branch.displayName(arabic: isArabic);

  String visitType(VisitType type) => switch (type) {
        VisitType.examination => l10n.visitTypeExamination,
        VisitType.consultation => l10n.visitTypeConsultation,
      };

  String recordCategory(RecordCategory category) => switch (category) {
        RecordCategory.prescription => l10n.fileCategoryPrescription,
        RecordCategory.lab => l10n.fileCategoryLab,
        RecordCategory.radiology => l10n.fileCategoryRadiology,
        RecordCategory.other => l10n.fileCategoryOther,
      };

  /// The [S] type label of an "Other" file (BR-F1).
  String? otherType(String? code, String? text) => switch (code) {
        null => null,
        'report' => l10n.otherTypeReport,
        'referral' => l10n.otherTypeReferral,
        'sickLeave' => l10n.otherTypeSickLeave,
        'ecg' => l10n.otherTypeEcg,
        'eegEmg' => l10n.otherTypeEegEmg,
        'endoscopy' => l10n.otherTypeEndoscopy,
        'consent' => l10n.otherTypeConsent,
        _ => text,
      };

  String prescriptionKind(PrescriptionKind kind) => switch (kind) {
        PrescriptionKind.medication => l10n.rxKindMedication,
        PrescriptionKind.investigations => l10n.rxKindInvestigations,
      };

  String investigationCategory(String category) =>
      category == 'radiology' ? l10n.investigationRadiology : l10n.investigationLab;

  String paymentMethod(String code) => switch (code) {
        'cash' => l10n.paymentCash,
        'card' => l10n.paymentCard,
        'instapay' => l10n.paymentInstapay,
        'wallet' => l10n.paymentWallet,
        _ => code,
      };

  String amenity(String code) => switch (code) {
        'elevator' => l10n.amenityElevator,
        'parking' => l10n.amenityParking,
        'wheelchair' => l10n.amenityWheelchair,
        'kidsArea' => l10n.amenityKidsArea,
        _ => code,
      };

  String phoneLabel(String code) => switch (code) {
        'landline' => l10n.phoneLandline,
        'mobile' => l10n.phoneMobile,
        _ => l10n.phoneReception,
      };

  String gender(String code) => code == 'female' ? l10n.genderFemale : l10n.genderMale;

  /// Egyptian numbers are stored as +201XXXXXXXXX and shown as 01XXXXXXXXX.
  String localPhone(String e164) => e164.startsWith('+20') ? '0${e164.substring(3)}' : e164;

  /// One medicine in plain words (P7), for example
  /// "1 tablet · 1x1 · After food · 5 days".
  List<String> doseParts(MedicationItem item) {
    final parts = DoseParts.of(item);
    final form = parts.form == null ? parts.formText : medicineForm(parts.form!);
    return [
      if (parts.dose != null && form != null) l10n.doseAmountForm(parts.dose!, form)
      else if (parts.dose != null) parts.dose!
      else ?form,
      if (parts.frequency != null) parts.frequency!,
      if (parts.timing != null) medicineTiming(parts.timing!),
      if (parts.duration != null) medicineDuration(parts.duration!),
    ];
  }

  String medicineForm(MedicineForm form) => switch (form) {
        MedicineForm.tablet => l10n.formTablet,
        MedicineForm.capsule => l10n.formCapsule,
        MedicineForm.syrup => l10n.formSyrup,
        MedicineForm.injection => l10n.formInjection,
        MedicineForm.cream => l10n.formCream,
        MedicineForm.drops => l10n.formDrops,
        MedicineForm.inhaler => l10n.formInhaler,
        MedicineForm.suppository => l10n.formSuppository,
        MedicineForm.sachet => l10n.formSachet,
        MedicineForm.other => l10n.formOther,
      };

  String medicineTiming(MedicineTiming timing) => switch (timing) {
        MedicineTiming.beforeFood => l10n.timingBeforeFood,
        MedicineTiming.afterFood => l10n.timingAfterFood,
        MedicineTiming.withFood => l10n.timingWithFood,
      };

  String medicineDuration(MedicineDuration duration) => switch (duration) {
        DaysDuration(:final count) => l10n.durationDays(count),
        WeeksDuration(:final count) => l10n.durationWeeks(count),
        ContinuousDuration() => l10n.durationContinuous,
        FreeTextDuration(:final text) => text,
      };
}
