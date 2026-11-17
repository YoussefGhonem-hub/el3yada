import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/admin/domain/admin_models.dart' show DoctorStatuses;
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:el3yada/features/clinic_admin/domain/assistant_models.dart';
import 'package:el3yada/features/patients/domain/patient_models.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_support.dart';

/// Phase 2 against a running API: the admin suspends the clinic day's doctor
/// by hand (`setDoctorStatus`, BR-G4), then reactivates them. While suspended,
/// adding patients and recording sessions answer `DOCTOR_SUSPENDED` (BR-G5),
/// for their assistant too (BR-G8), and reading still works.
///
/// Called by `api_contract_test.dart` after [ClinicDay] is filled in.
void phase2SuspendedDoctor(ClinicDay day, {required String? skip}) {
  late final assistant = ContractAccount(day.baseUrl, day.plain);
  late String assistantUserId;
  const reason = 'فاتورة أكتوبر غير مدفوعة';

  NewSessionDraft examination() =>
      NewSessionDraft(patientId: day.patientId, branchId: day.maadiId, type: SessionType.examination);
  PatientDraft newPatient() =>
      PatientDraft(fullName: 'ياسر فؤاد', gender: Gender.male, phone: contractMobile(), ageYears: 40);

  test('the admin suspends the doctor: no new patients or sessions, for the assistant too; reads go on', () async {
    // A reception assistant in every branch.
    final created = await day.doctor.clinicAdmin.createAssistant(AssistantDraft(
      fullName: 'نهى سمير',
      phone: contractMobile(),
      allBranches: true,
      branchIds: const {},
      permissions: AssistantPreset.permissions[AssistantPreset.reception]!,
    ));
    assistantUserId = created.assistant.userId;
    final device = contractDevice('suspension-assistant', day.run);
    final first =
        await assistant.auth.login(identifier: created.assistant.phone, password: created.temporaryPassword, device: device);
    assistant.token = (first as SignedIn).session.accessToken;
    assistant.token = (await assistant.auth.setNewPassword(newPassword: 'Assist1234', device: device)).accessToken;

    final suspended = await day.admin.admin.setDoctorStatus(day.doctorId, suspended: true, reason: '  فاتورة أكتوبر   غير مدفوعة ');
    expect(suspended.doctorId, day.doctorId);
    expect(suspended.fullName, 'سامي عبد الله');
    expect(suspended.status, DoctorStatuses.suspended);
    expect(suspended.isSuspended, isTrue);
    expect(suspended.statusReason, reason);
    expect(suspended.statusChangedAt!.isUtc, isTrue);
    // Asking again changes nothing.
    expect((await day.admin.admin.setDoctorStatus(day.doctorId, suspended: true, reason: 'مرة أخرى')).statusReason, reason);

    // The doctor still signs in, and the session says why (the banner, BR-G5).
    final signedIn = await day.doctor.auth
        .login(identifier: day.doctorEmail, password: day.doctorPassword, device: contractDevice('doctor', day.run));
    final session = (signedIn as SignedIn).session;
    expect(session.doctorStatus, DoctorStatus.suspended);
    expect(session.doctorStatusReason, reason);
    day.doctor.token = session.accessToken;
    final assistantAgain =
        await assistant.auth.login(identifier: created.assistant.phone, password: 'Assist1234', device: device);
    expect((assistantAgain as SignedIn).session.doctorStatus, DoctorStatus.suspended);
    expect(assistantAgain.session.doctorStatusReason, isNull, reason: 'the reason is for the doctor only');

    for (final (who, name) in [(day.doctor, 'doctor'), (assistant, 'assistant')]) {
      final context = await who.clinic.me();
      expect(context.isSuspended, isTrue, reason: name);
      expect(context.doctor.status, DoctorStatuses.suspended, reason: name);
      await expectLater(who.sessions.createSession(examination()), throwsA(apiError(403, ApiCodes.doctorSuspended)),
          reason: name);
      await expectLater(who.patients.createPatient(newPatient()), throwsA(apiError(403, ApiCodes.doctorSuspended)),
          reason: name);
      await expectLater(who.patients.createPatient(PatientDraft.link(day.patientPhone)),
          throwsA(apiError(403, ApiCodes.doctorSuspended)), reason: '$name: linking is adding too');
      // Reading goes on.
      expect((await who.patients.register(const RegisterQuery())).items.map((r) => r.patientId), contains(day.patientId),
          reason: name);
      expect((await who.patients.patient(day.patientId)).patientId, day.patientId, reason: name);
      expect((await who.sessions.patientSessions(day.patientId)).items, isNotEmpty, reason: name);
      expect((await who.sessions.newSessionInfo(patientId: day.patientId, branchId: day.maadiId)).patientId, day.patientId,
          reason: name);
      expect((await who.sessions.day()).items, isNotEmpty, reason: name);
      expect((await who.clinicAdmin.branches()).items, isNotEmpty, reason: name);
    }

    // Managing the clinic isn't blocked (BR-G5 lists what is).
    final renamed = await day.doctor.clinicAdmin.updateAssistant(assistantUserId, fullName: 'نهى سمير علي');
    expect(renamed.fullName, 'نهى سمير علي');
  }, skip: skip);

  test('a doctor who just signed up is active, so the admin can suspend them at once', () async {
    final fresh = ContractAccount(day.baseUrl, day.plain);
    final specialties = await fresh.registration.specialties();
    final session = await fresh.registration.register(
      doctorRegistration(
        fullName: 'كمال رشدي',
        email: 'contract-fresh-${day.run}@el3yada.dev',
        phone: contractMobile(),
        password: 'Doctor1234',
        licenseNumber: 'P${day.run.substring(day.run.length - 9)}',
        specialtyId: specialties.first.id,
        device: contractDevice('fresh', day.run),
      ),
      contractLicense(),
    );
    expect(session.doctorStatus, DoctorStatus.active);
    expect(session.trial?.ended, isFalse);
    final suspended = await day.admin.admin.setDoctorStatus(session.doctorId!, suspended: true, reason: reason);
    expect(suspended.status, DoctorStatuses.suspended);
    fresh.token = session.accessToken;
    final clinic = await fresh.clinic.me();
    expect(clinic.isSuspended, isTrue);
    expect(clinic.freeTrial, isTrue, reason: 'the trial goes on while suspended');
    expect(
      (await day.admin.admin.setDoctorStatus(session.doctorId!, suspended: false, reason: 'تم التحقق')).status,
      DoctorStatuses.active,
    );
    await expectLater(
      day.admin.admin.setDoctorStatus(day.doctorId, suspended: false, reason: ' ab '),
      throwsA(apiError(400, ApiCodes.validationFailed).having((e) => e.fieldCodes['reason'], 'reason', 'REASON_REQUIRED')),
    );
  }, skip: skip);

  test('the admin reactivates the doctor: sessions work again', () async {
    final active = await day.admin.admin.setDoctorStatus(day.doctorId, suspended: false, reason: 'تم السداد');
    expect(active.status, DoctorStatuses.active);
    expect(active.isSuspended, isFalse);
    expect(active.statusReason, isNull);

    expect((await day.doctor.clinic.me()).isSuspended, isFalse);
    expect((await assistant.clinic.me()).isSuspended, isFalse);
    final byDoctor = await day.doctor.sessions.createSession(examination());
    expect(byDoctor.type, SessionType.examination);
    expect(byDoctor.recordedBy.isAssistant, isFalse);
    final byAssistant = await assistant.sessions.createSession(examination());
    expect(byAssistant.recordedBy.userId, assistantUserId);
    final added = await assistant.patients.createPatient(newPatient());
    expect(added.linked, isFalse);
  }, skip: skip);
}
