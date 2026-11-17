import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../clinic_admin/data/clinic_admin_repository.dart';
import '../../clinic_admin/domain/branch_models.dart';
import '../../patients/data/patients_repository.dart';
import '../../sessions/data/sessions_repository.dart';
import '../../sessions/domain/session_models.dart' show SessionType;
import '../data/prescriptions_repository.dart';
import '../domain/prescription_models.dart';
import '../pdf/rx_pdf.dart';

/// Gathers what a prescription's PDF shows (6.4.1) from the D22 profile and
/// print settings, the logo and signature, the session, the patient and the
/// branches (BR-BR6). Only the doctor builds PDFs: sending is doctor only.
class RxPdfSource {
  RxPdfSource({
    required this.prescriptions,
    required this.clinicAdmin,
    required this.patients,
    required this.sessions,
  });

  final PrescriptionsRepository prescriptions;
  final ClinicAdminRepository clinicAdmin;
  final PatientsRepository patients;
  final SessionsRepository sessions;

  /// The PDF of [rx] as it stands (a draft's preview, or what is sent).
  Future<Uint8List> build(Prescription rx, {RxSettings? settings}) async =>
      buildRxPdf(await dataFor(rx, settings: settings), await RxPdfFonts.load());

  Future<RxPdfData> dataFor(Prescription rx, {RxSettings? settings}) async {
    final rxSettings = settings ?? await prescriptions.rxSettings();
    final (profile, session, patient) =
        await (clinicAdmin.doctorProfile(), sessions.session(rx.sessionId), patients.patient(rx.patientId)).wait;
    final images = await _images(rxSettings);
    final branches = await branchesFor(rxSettings, firstBranchId: session.branch.id);
    return RxPdfData(
      settings: rxSettings,
      doctor: RxDoctor(
        nameAr: profile.fullName,
        titleAr: profile.title,
        specialtyAr: profile.specialty?.nameAr.nullIfEmpty,
        degreesAr: profile.degreesAr,
        nameEn: profile.fullNameEn,
        titleEn: profile.titleEn,
        specialtyEn: profile.specialty?.nameEn.nullIfEmpty,
        degreesEn: profile.degreesEn,
      ),
      patient: RxPatient(
        name: patient.fullName,
        ageYears: patient.ageYears,
        fileNumber: patient.fileNumber,
        visitDay: session.day,
        visitType: session.type,
      ),
      kind: rx.kind,
      diagnosis: rx.diagnosis,
      advice: rx.advice,
      followUpDate: rx.followUpDate,
      medications: rx.medications,
      investigations: rx.investigations,
      qrUrl: rx.qrUrl,
      branches: branches,
      logo: images.logo,
      signature: images.signature,
    );
  }

  /// The D22 live preview: the doctor's real header and branches with a
  /// sample patient and medicines.
  Future<RxPdfData> sample(RxSettings settings, {required AppLocalizations l10n}) async {
    final profile = await clinicAdmin.doctorProfile();
    final images = await _images(settings);
    final list = await clinicAdmin.branches();
    final defaultBranch = list.items.where((b) => b.isDefault).firstOrNull ?? list.items.firstOrNull;
    final branches = defaultBranch == null ? const <RxBranch>[] : await branchesFor(settings, firstBranchId: defaultBranch.id);
    final today = DateTime.now().toUtc();
    return RxPdfData(
      settings: settings,
      doctor: RxDoctor(
        nameAr: profile.fullName,
        titleAr: profile.title,
        specialtyAr: profile.specialty?.nameAr.nullIfEmpty,
        degreesAr: profile.degreesAr,
        nameEn: profile.fullNameEn,
        titleEn: profile.titleEn,
        specialtyEn: profile.specialty?.nameEn.nullIfEmpty,
        degreesEn: profile.degreesEn,
      ),
      patient: RxPatient(
        name: l10n.rxSamplePatient,
        ageYears: 34,
        fileNumber: 128,
        visitDay: DateTime.utc(today.year, today.month, today.day),
        visitType: SessionType.examination,
      ),
      kind: PrescriptionKind.medication,
      diagnosis: l10n.rxSampleDiagnosis,
      advice: l10n.rxSampleAdvice,
      followUpDate: DateTime.utc(today.year, today.month, today.day).add(const Duration(days: 7)),
      medications: [
        MedicationItem(
          drugName: 'Augmentin',
          strength: '1 g',
          form: DrugForms.tablet,
          dose: l10n.rxSampleDose,
          frequency: l10n.rxSampleFrequency,
          timing: MedicationTiming.afterFood,
          duration: l10n.rxDurationDays(7),
        ),
        MedicationItem(
          drugName: 'Panadol Extra',
          strength: '500 mg',
          form: DrugForms.tablet,
          dose: l10n.rxSampleDose,
          frequency: l10n.rxSampleWhenNeeded,
          duration: l10n.rxDurationDays(5),
        ),
      ],
      qrUrl: 'https://el3yada.app/rx/SAMPLE000000',
      branches: branches,
      logo: images.logo,
      signature: images.signature,
    );
  }

  Future<({Uint8List? logo, Uint8List? signature})> _images(RxSettings settings) async {
    final logo = settings.hasLogo ? await prescriptions.rxImage(RxImageKind.logo) : null;
    final signature = settings.hasSignature ? await prescriptions.rxImage(RxImageKind.signature) : null;
    return (logo: logo, signature: signature);
  }

  /// BR-BR6: [firstBranchId] (the session's), then the default, then the
  /// others, without archived ones; as many as the paper has room for.
  Future<List<RxBranch>> branchesFor(RxSettings settings, {required String firstBranchId}) async {
    final list = await clinicAdmin.branches();
    final cards = list.items.where((b) => b.status != BranchStatuses.archived).toList()
      ..sort((a, b) {
        int rank(BranchCard card) => card.id == firstBranchId ? 0 : (card.isDefault ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });
    final language = settings.english ? 'en' : 'ar';
    await initializeDateFormatting(language);
    final l10n = lookupAppLocalizations(Locale(language));
    final details = await Future.wait([
      for (final card in cards.take(rxFooterBranches(settings))) clinicAdmin.branch(card.id),
    ]);
    return [for (final branch in details) rxBranchOf(branch, l10n: l10n, language: language)];
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// The footer lines of one branch in the prescription's language.
RxBranch rxBranchOf(BranchDetails branch, {required AppLocalizations l10n, required String language}) {
  final address = [
    branch.address.details,
    ?branch.address.area,
    branch.address.city,
  ].where((part) => part.trim().isNotEmpty).join(l10n.rxListSeparator);
  return RxBranch(
    nameAr: branch.info.nameAr,
    nameEn: branch.info.nameEn,
    address: address,
    landmark: branch.address.landmark,
    phones: [for (final phone in branch.contact.phones) if (!phone.isWhatsapp) localPhone(phone.number)],
    whatsapp: [for (final phone in branch.contact.phones) if (phone.isWhatsapp) localPhone(phone.number)],
    hours: rxHoursLines(branch.workingHours.periods, l10n: l10n, language: language),
  );
}

/// `+201001234567` → `01001234567` (how Egyptians read a number).
String localPhone(String number) => number.startsWith('+20') ? '0${number.substring(3)}' : number;

/// The week's hours, grouping days that have the same periods: «السبت –
/// الأربعاء: 5:00 م – 10:00 م». Days start on Saturday, as in Egypt.
List<String> rxHoursLines(List<BranchPeriod> periods, {required AppLocalizations l10n, required String language}) {
  const order = [6, 7, 1, 2, 3, 4, 5];
  String time(String hhmm) {
    final parts = hhmm.split(':');
    return DateFormat.jm(language).format(DateTime(2024, 1, 1, int.parse(parts[0]), int.parse(parts[1])));
  }

  String dayName(int weekday) => DateFormat.EEEE(language).format(DateTime(2024, 1, weekday));

  String signature(int weekday) {
    final day = periods.where((p) => p.weekday == weekday).toList()..sort((a, b) => a.startLocal.compareTo(b.startLocal));
    return day.map((p) => '${time(p.startLocal)} – ${time(p.endLocal)}').join(l10n.rxListSeparator);
  }

  final lines = <String>[];
  var start = 0;
  while (start < order.length) {
    final value = signature(order[start]);
    var end = start;
    while (end + 1 < order.length && signature(order[end + 1]) == value) {
      end++;
    }
    if (value.isNotEmpty) {
      final days = start == end ? dayName(order[start]) : '${dayName(order[start])} – ${dayName(order[end])}';
      lines.add('$days: $value');
    }
    start = end + 1;
  }
  return lines;
}

final rxPdfSourceProvider = Provider<RxPdfSource>(
  (ref) => RxPdfSource(
    prescriptions: ref.watch(prescriptionsRepositoryProvider),
    clinicAdmin: ref.watch(clinicAdminRepositoryProvider),
    patients: ref.watch(patientsRepositoryProvider),
    sessions: ref.watch(sessionsRepositoryProvider),
  ),
);
