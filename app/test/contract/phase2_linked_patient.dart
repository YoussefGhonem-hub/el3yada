import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/patients/domain/patient_models.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_support.dart';

/// Phase 2 against a running API: a second clinic links the clinic day's
/// patient by her phone number (BR-P3, AC-10). The identity (name, gender,
/// date of birth) is one account shared by both clinics; the optional
/// details stay with the clinic that made the account, and the medical
/// profile and the sessions stay with each clinic.
///
/// Called by `api_contract_test.dart` after [ClinicDay] is filled in.
void phase2LinkedPatient(ClinicDay day, {required String? skip}) {
  // The second clinic.
  late final other = ContractAccount(day.baseUrl, day.plain);
  late String otherBranchId;
  // The first clinic's view of the patient before the second one links her.
  late PatientView first;

  test(
    'another clinic finds the number elsewhere and links the patient',
    () async {
      await signUpDoctor(
        doctor: other,
        fullName: 'هالة يوسف',
        email: 'contract-doctor2-${day.run}@el3yada.dev',
        password: 'Doctor1234',
        device: contractDevice('doctor2', day.run),
      );
      otherBranchId = (await other.clinic.me()).defaultBranchId!;
      first = await day.doctor.patients.patient(day.patientId);
      expect(first.ownsDetails, isTrue);
      expect(first.hasDetails, isTrue);

      // Another clinic's number tells nothing but that (BR-P3).
      var lookup = await other.patients.lookupPhone(day.patientPhone);
      expect(lookup.status, PhoneLookupStatus.existsElsewhere);
      expect(lookup.patientId, isNull);
      expect(lookup.fileNumber, isNull);
      expect(lookup.fullName, isNull);
      expect(lookup.archived, isNull);

      final linked = await other.patients.createPatient(
        PatientDraft.link(day.patientPhone),
      );
      expect(linked.linked, isTrue);
      expect(linked.temporaryPassword, isNull);
      final view = linked.patient;
      expect(view.patientId, day.patientId);
      expect(view.fileNumber, 1, reason: 'each clinic numbers its own files');
      expect(view.fullName, first.fullName);
      expect(view.phone, first.phone);
      expect(view.gender, first.gender);
      expect(view.dateOfBirth, first.dateOfBirth);
      expect(view.dateOfBirthEstimated, first.dateOfBirthEstimated);
      expect(view.ageYears, first.ageYears);
      expect(view.accountStatus, 'active');
      expect(view.linkedAt.isUtc, isTrue);
      // The optional details belong to the first clinic.
      expect(view.ownsDetails, isFalse);
      expect(view.nationalId, isNull);
      expect(view.address, isNull);
      expect(view.bloodType, isNull);
      expect(view.emergencyContactName, isNull);
      expect(view.emergencyContactPhone, isNull);
      // This clinic's own file: no visits, no money, its own (empty) medical profile.
      expect(view.visits.total, 0);
      expect(view.visits.lastVisit, isNull);
      expect(view.totalPaidPiasters, 0);
      expect(view.hasAllergies, isFalse);

      lookup = await other.patients.lookupPhone(day.patientPhone);
      expect(lookup.status, PhoneLookupStatus.linkedToYou);
      expect(lookup.patientId, day.patientId);
      expect(lookup.fileNumber, 1);
      expect(lookup.fullName, first.fullName);
      await expectLater(
        other.patients.createPatient(PatientDraft.link(day.patientPhone)),
        throwsA(
          apiError(409, ApiCodes.patientAlreadyLinked)
              .having((e) => e.details['patientId'], 'patientId', day.patientId)
              .having((e) => e.details['fileNumber'], 'fileNumber', 1),
        ),
      );

      expect(
        (await other.patients.medicalProfile(day.patientId)).isEmpty,
        isTrue,
      );
      expect(
        (await day.doctor.patients.medicalProfile(day.patientId)).hasAllergies,
        isTrue,
      );
      final register = await other.patients.register(const RegisterQuery());
      expect(
        [for (final row in register.items) row.patientId],
        [day.patientId],
      );
      expect(register.items.single.fileNumber, 1);
      expect(register.items.single.hasAllergies, isFalse);
      expect(register.items.single.chronicDiseases, isEmpty);
    },
    skip: skip,
  );

  test(
    'the second clinic edits the shared identity but not the first clinic\'s details (D7)',
    () async {
      final edited = await other.patients.updatePatient(
        day.patientId,
        PatientDraft(
          fullName: 'منة حسن محمود',
          gender: first.gender,
          dateOfBirth: first.dateOfBirth,
          nationalId: '29105010123456',
          address: 'الزمالك',
          bloodType: 'B+',
          emergencyContactName: 'علي حسن',
          emergencyContactPhone: '02 2735 0000',
        ),
      );
      expect(edited.fullName, 'منة حسن محمود');
      expect(edited.ownsDetails, isFalse);
      expect(
        edited.hasDetails,
        isFalse,
        reason: 'the details sent are ignored here',
      );

      final again = await day.doctor.patients.patient(day.patientId);
      expect(
        again.fullName,
        'منة حسن محمود',
        reason: 'one identity in every clinic',
      );
      expect(again.ownsDetails, isTrue);
      expect(again.nationalId, first.nationalId);
      expect(again.address, first.address);
      expect(again.bloodType, first.bloodType);
      expect(again.emergencyContactName, first.emergencyContactName);
      expect(again.emergencyContactPhone, first.emergencyContactPhone);
      final found = await day.doctor.patients.register(
        const RegisterQuery(search: 'منه محمود'),
      );
      expect([for (final row in found.items) row.patientId], [day.patientId]);
    },
    skip: skip,
  );

  test('sessions in one clinic stay out of the other', () async {
    final before = await day.doctor.sessions.patientSessions(day.patientId);
    expect(before.items, isNotEmpty);

    // The first clinic's visits don't count here: a first visit (BR-S2).
    final info = await other.sessions.newSessionInfo(
      patientId: day.patientId,
      branchId: otherBranchId,
    );
    expect(info.isFirstVisit, isTrue);
    expect(info.lastSession, isNull);
    expect(info.consultationsSinceExam, 0);
    expect(info.consultationAllowed, isFalse);
    expect(info.consultationBlockedReason, ConsultationBlock.firstVisit);
    final visit = await other.sessions.createSession(
      NewSessionDraft(
        patientId: day.patientId,
        branchId: otherBranchId,
        type: SessionType.examination,
        chiefComplaint: 'كحة',
        diagnosis: 'نزلة برد',
      ),
    );
    expect(visit.fileNumber, 1);
    expect(visit.patientName, 'منة حسن محمود');
    expect(visit.branch.id, otherBranchId);

    final theirs = await other.sessions.patientSessions(day.patientId);
    expect([for (final row in theirs.items) row.sessionId], [visit.sessionId]);
    final ours = await day.doctor.sessions.patientSessions(day.patientId);
    expect(ours.totalCount, before.totalCount);
    expect(
      [for (final row in ours.items) row.sessionId],
      [for (final row in before.items) row.sessionId],
    );
    expect([
      for (final row in (await day.doctor.sessions.day()).items) row.sessionId,
    ], isNot(contains(visit.sessionId)));

    // Neither clinic can open the other's sessions.
    await expectLater(
      day.doctor.sessions.session(visit.sessionId),
      throwsA(apiError(404, ApiCodes.notFound)),
    );
    await expectLater(
      other.sessions.session(before.items.first.sessionId),
      throwsA(apiError(404, ApiCodes.notFound)),
    );

    expect((await other.patients.patient(day.patientId)).visits.total, 1);
    final firstClinic = await day.doctor.patients.patient(day.patientId);
    expect(firstClinic.visits.total, first.visits.total);
    expect(
      firstClinic.visits.lastVisit!.sessionId,
      first.visits.lastVisit!.sessionId,
    );
    expect(firstClinic.totalPaidPiasters, first.totalPaidPiasters);
  }, skip: skip);
}
