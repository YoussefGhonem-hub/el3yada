import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/admin/data/admin_repository.dart';
import 'package:el3yada/features/admin/domain/admin_models.dart'
    show TrialFilter;
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:el3yada/features/clinic_admin/data/clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/domain/activity_models.dart';
import 'package:el3yada/features/clinic_admin/domain/assistant_models.dart';
import 'package:el3yada/features/clinic_admin/domain/branch_models.dart';
import 'package:el3yada/features/clinic_admin/domain/json_read.dart';
import 'package:el3yada/features/doctor_registration/data/registration_repository.dart';
import 'package:el3yada/features/patients/domain/patient_models.dart';
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract_support.dart';

/// Phase 2 against a running API: one clinic day through the app's real
/// repositories (backend/docs/api-phase-2*.md). A doctor signs up and is
/// active at once in a free trial (api-free-trial.md); the admin extends the
/// trial, then activates the service so the day runs with the platform
/// fees. The doctor sets up the clinic, adds a patient and
/// records sessions; a reception assistant in one branch works the desk;
/// the doctor reads the activity log, then disables and removes the assistant.
///
/// Called by `api_contract_test.dart` after its Phase 1 tests, in the same
/// isolate: both sign in as the seeded admin, and the files of a directory
/// run at the same time. Every run makes its own doctor, patients and
/// assistant (unique email and mobile numbers), so it can run again on the
/// same database. Returns what the groups after it need ([ClinicDay]).
ClinicDay phase2ClinicDay({
  required String? baseUrl,
  required String? adminEmail,
  required String? adminTemporaryPassword,
  required String adminPassword,
  required String? skip,
}) {
  final clinicDay = ClinicDay(baseUrl);
  final run = contractRunId();
  const mobile = contractMobile;
  const e164 = contractE164;

  final doctorEmail = 'contract-doctor-$run@el3yada.dev';
  final doctorPhone = mobile();
  const doctorPassword = 'Doctor1234';
  final licenseNumber = 'C${run.substring(run.length - 9)}';
  final patientPhone = mobile();
  final assistantPatientPhone = mobile();
  final assistantPhone = mobile();
  const assistantPassword = 'Assist1234';

  Map<String, dynamic> device(String who) => contractDevice(who, run);

  // Lazy: without the variables the tests skip, and a client needs a valid URL.
  late final plain = clinicDay.plain;
  late final admin = clinicDay.admin;
  late final doctor = clinicDay.doctor;
  late final assistant = ContractAccount(baseUrl, plain);

  // Shared by the steps, which run in order.
  late String doctorUserId;
  late String doctorId;
  late String today;
  late String maadiId;
  late String dokkiId;
  late int examinationFee;
  late int consultationFee;
  late int maxConsultations;
  late String patientId;
  late String examinationId;
  final amounts = <int>[];
  late String assistantUserId;
  late String assistantPatientId;

  test(
    'a doctor signs up and is active in a free trial; the admin extends it, then activates the service',
    () async {
      final registration = ApiRegistrationRepository(doctor.dio, plain);
      final specialties = await registration.specialties();
      expect(specialties, isNotEmpty);
      expect(specialties.first.nameAr, isNotEmpty);

      final registered = await registration.register(
        doctorRegistration(
          fullName: 'سامي عبد الله',
          fullNameEn: 'Sami Abdallah',
          email: doctorEmail.toUpperCase(),
          phone: doctorPhone,
          password: doctorPassword,
          licenseNumber: licenseNumber,
          specialtyId: specialties.first.id,
          device: device('doctor'),
        ),
        contractLicense(),
      );
      // No approval: active at once, in a free trial (api-free-trial.md).
      expect(registered.role, UserRole.doctor);
      expect(registered.doctorStatus, DoctorStatus.active);
      expect(registered.email, doctorEmail);
      expect(registered.emailVerified, isFalse);
      expect(registered.phone, e164(doctorPhone));
      expect(registered.doctorId, isNotNull);
      final trial = registered.trial!;
      expect(trial.ended, isFalse);
      expect(trial.daysLeft, greaterThan(0));
      expect(trial.endsAt.isAfter(DateTime.now().toUtc()), isTrue);
      doctorUserId = registered.userId;
      doctorId = registered.doctorId!;

      // The clinic opens at once, and sessions carry no fee during the trial (BR-T3).
      doctor.token = registered.accessToken;
      final during = await doctor.clinic.me();
      expect(during.doctor.status, 'active');
      expect(during.freeTrial, isTrue);
      expect(during.trial?.endsAt, trial.endsAt);
      expect(during.fees.examinationFeePiasters, 0);
      expect(during.fees.consultationFeePiasters, 0);

      // The admin finds the new doctor (every doctor, and those in a trial).
      // Email verification doesn't block anything (api-phase-1.md, "emailVerified").
      admin.token = (await signInAdmin(
        admin,
        adminEmail!,
        adminTemporaryPassword!,
        adminPassword,
        device('admin'),
      )).accessToken;
      final adminRepository = ApiAdminRepository(admin.dio);
      final all = await adminRepository.doctorRegistrations(
        search: doctorEmail,
      );
      final summary = all.items.singleWhere((row) => row.doctorId == doctorId);
      expect(summary.fullName, 'سامي عبد الله');
      expect(summary.status, 'active');
      expect(summary.emailVerified, isFalse);
      expect(summary.trial?.ended, isFalse);
      final inTrial = await adminRepository.doctorRegistrations(
        search: doctorEmail,
        trial: TrialFilter.running,
      );
      expect(inTrial.items.map((row) => row.doctorId), contains(doctorId));
      final ended = await adminRepository.doctorRegistrations(
        search: doctorEmail,
        trial: TrialFilter.ended,
      );
      expect(ended.items.map((row) => row.doctorId), isNot(contains(doctorId)));
      final detail = await adminRepository.doctorRegistration(doctorId);
      expect(detail.registration.status, 'active');
      expect(detail.registration.approvedAt, isNotNull);
      expect(detail.registration.trial?.daysLeft, trial.daysLeft);

      // Extend by 3 days, then activate: the trial ends and the fees apply.
      final extended = await adminRepository.extendDoctorTrial(
        doctorId,
        days: 3,
      );
      expect(extended.trial!.endsAt, trial.endsAt.add(const Duration(days: 3)));
      expect(extended.trial!.daysLeft, trial.daysLeft + 3);
      final activated = await adminRepository.activateDoctorService(doctorId);
      expect(activated.status, 'active');
      expect(activated.trial, isNull);
      await expectLater(
        adminRepository.extendDoctorTrial(doctorId, days: 3),
        throwsA(_apiError(409, ApiCodes.serviceAlreadyActive)),
      );
      final after = await doctor.clinic.me();
      expect(after.trial, isNull);
      expect(after.freeTrial, isFalse);
      expect(after.fees.examinationFeePiasters, greaterThan(0));

      final signedIn = await doctor.auth.login(
        identifier: doctorEmail,
        password: doctorPassword,
        device: device('doctor'),
      );
      final session = (signedIn as SignedIn).session;
      expect(session.role, UserRole.doctor);
      expect(session.userId, doctorUserId);
      expect(session.doctorId, doctorId);
      expect(session.doctorStatus, DoctorStatus.active);
      expect(session.mustChangePassword, isFalse);
      doctor.token = session.accessToken;
      clinicDay
        ..run = run
        ..doctorEmail = doctorEmail
        ..doctorPassword = doctorPassword
        ..doctorId = doctorId;
    },
    skip: skip,
  );

  test(
    'the doctor sets up the clinic: branches, hours, prices, notifications, profile',
    () async {
      final context = await doctor.clinic.me();
      expect(context.isDoctor, isTrue);
      expect(context.assistant, isNull);
      expect(context.doctor.id, doctorId);
      expect(context.doctor.fullName, 'سامي عبد الله');
      expect(context.doctor.fullNameEn, 'Sami Abdallah');
      expect(context.doctor.title, 'استشاري');
      expect(context.doctor.specialtyNameAr, isNotEmpty);
      expect(context.doctor.status, 'active');
      expect(context.permissions, ClinicPermission.all.toSet());
      expect(context.branches, hasLength(1));
      final maadi = context.branches.single;
      expect(maadi.isDefault, isTrue);
      expect(maadi.assigned, isTrue);
      expect(maadi.status, BranchStatuses.active);
      expect(maadi.nameAr, 'فرع المعادي');
      expect(maadi.governorate, 'القاهرة');
      expect(maadi.city, 'المعادي');
      expect(context.defaultBranchId, maadi.id);
      expect(context.fees.maxConsecutiveConsultations, greaterThan(0));
      expect(context.limits.maxBranches, greaterThan(1));
      expect(context.limits.maxAssistants, greaterThan(0));
      expect(context.limits.maxUploadMb, greaterThan(0));
      maadiId = maadi.id;
      examinationFee = context.fees.examinationFeePiasters;
      consultationFee = context.fees.consultationFeePiasters;
      maxConsultations = context.fees.maxConsecutiveConsultations;

      final repository = doctor.clinicAdmin;
      var list = await repository.branches();
      expect(list.count, 1);
      expect(list.limit, context.limits.maxBranches);
      expect(list.canAdd, isTrue);
      expect(list.today, isNotNull);
      expect(list.todayWeekday, inInclusiveRange(1, 7));
      expect(list.todayWeekday, list.today!.weekday);
      today = writeDay(list.today!);
      final card = list.items.single;
      expect(card.id, maadiId);
      expect(card.isDefault, isTrue);
      expect(card.assigned, isTrue);
      expect(card.status, BranchStatuses.active);
      expect(card.todayPeriods, isEmpty);
      expect(card.upcomingBookings, 0);

      final details = await repository.branch(maadiId);
      expect(details.id, maadiId);
      expect(details.isDefault, isTrue);
      expect(details.info.nameAr, 'فرع المعادي');
      expect(details.address.details, 'شارع 9');
      expect(details.address.landmark, 'بجوار المترو');
      expect(details.address.mapUrl, isNull);
      expect(details.contact.phones.single.number, '+20223581234');
      expect(details.contact.phones.single.label, PhoneLabels.landline);
      expect(details.workingHours.periods, isEmpty);
      expect(details.workingHours.bookingMode, isIn(['queue', 'timed']));
      expect(details.workingHours.defaultCapacity, greaterThan(0));
      expect(details.clinicInfo.prices.usesDoctorPrices, isTrue);
      expect(details.clinicInfo.prices.examinationPricePiasters, isNull);
      expect(
        details.clinicInfo.prices.effectiveExaminationPricePiasters,
        30000,
      );
      expect(
        details.clinicInfo.prices.effectiveConsultationPricePiasters,
        15000,
      );

      // A second branch.
      final dokki = await repository.createBranch(
        info: const BranchInfo(
          nameAr: 'فرع الدقي',
          nameEn: 'Dokki',
          description: 'الدور الثاني',
        ),
        address: const BranchAddress(
          governorate: 'الجيزة',
          city: 'الدقي',
          details: '12 شارع التحرير',
          mapUrl: 'https://maps.app.goo.gl/AbCd1234XyZ',
        ),
        contact: BranchContact(
          phones: [
            BranchContactPhone(
              number: mobile(),
              label: PhoneLabels.mobile,
              isWhatsapp: true,
            ),
          ],
          email: 'Dokki@Clinic.example',
        ),
        clinicInfo: const BranchChecklistInput(
          paymentMethods: ['instapay', 'cash'],
          amenities: ['elevator'],
        ),
      );
      dokkiId = dokki.id;
      expect(dokki.isDefault, isFalse);
      expect(dokki.status, BranchStatuses.active);
      expect(dokki.assigned, isTrue);
      expect(dokki.info.nameEn, 'Dokki');
      expect(dokki.info.description, 'الدور الثاني');
      expect(dokki.address.details, '12 شارع التحرير');
      expect(dokki.address.mapUrl, 'https://maps.app.goo.gl/AbCd1234XyZ');
      expect(dokki.contact.email, 'dokki@clinic.example');
      expect(dokki.contact.phones.single.number, startsWith('+2010'));
      expect(dokki.contact.phones.single.isWhatsapp, isTrue);
      expect(dokki.contact.phones.single.label, PhoneLabels.mobile);
      expect(dokki.clinicInfo.paymentMethods, ['cash', 'instapay']);
      expect(dokki.clinicInfo.amenities, ['elevator']);
      expect(dokki.createdAt.isUtc, isTrue);

      // Working hours: Saturday's two periods (one past midnight), Sunday, and
      // a period today so the D28 card shows it.
      final todayWeekday = list.todayWeekday!;
      final todayPeriod = BranchPeriod(
        weekday: todayWeekday,
        startLocal: '15:00',
        endLocal: '17:00',
        label: 'عصر',
      );
      final periods = [
        const BranchPeriod(
          weekday: 6,
          startLocal: '10:00',
          endLocal: '14:00',
          label: 'صباحي',
          capacity: 25,
        ),
        const BranchPeriod(
          weekday: 6,
          startLocal: '20:00',
          endLocal: '01:00',
          endsNextDay: true,
          label: 'مسائي',
        ),
        const BranchPeriod(weekday: 7, startLocal: '10:00', endLocal: '14:00'),
        todayPeriod,
      ];
      final withHours = await repository.updateBranchHours(dokkiId, periods);
      final sorted = [...periods]
        ..sort(
          (a, b) => a.weekday != b.weekday
              ? a.weekday.compareTo(b.weekday)
              : a.startLocal.compareTo(b.startLocal),
        );
      expect(withHours.workingHours.periods, sorted);

      list = await repository.branches();
      expect(list.count, 2);
      expect(list.items.first.id, maadiId);
      final dokkiCard = list.items.singleWhere((b) => b.id == dokkiId);
      expect(dokkiCard.nameEn, 'Dokki');
      expect(dokkiCard.isDefault, isFalse);
      expect(dokkiCard.todayPeriods, contains(todayPeriod));

      // D29 Info tab: the group is replaced whole (the description is
      // cleared), the other groups stay.
      final renamed = await repository.updateBranch(
        dokkiId,
        info: const BranchInfo(nameAr: 'فرع الدقي', nameEn: 'Dokki'),
      );
      expect(renamed.info.description, isNull);
      expect(renamed.address.details, '12 شارع التحرير');
      expect(renamed.workingHours.periods, hasLength(4));

      // A closure with a message and a reopening date, then open again.
      final reopen = dayKey(_day(today).add(const Duration(days: 3)));
      final closed = await repository.setBranchStatus(
        dokkiId,
        BranchStatuses.temporarilyClosed,
        closedMessage: 'مغلق للتجديدات',
        reopenDate: _day(reopen),
      );
      expect(closed.status, BranchStatuses.temporarilyClosed);
      expect(closed.temporarilyClosed, isTrue);
      expect(closed.closedMessage, 'مغلق للتجديدات');
      expect(writeDay(closed.reopenDate!), reopen);
      final closedCard = (await repository.branches()).items.singleWhere(
        (b) => b.id == dokkiId,
      );
      expect(closedCard.status, BranchStatuses.temporarilyClosed);
      expect(closedCard.closedMessage, 'مغلق للتجديدات');
      expect(writeDay(closedCard.reopenDate!), reopen);
      final opened = await repository.setBranchStatus(
        dokkiId,
        BranchStatuses.active,
      );
      expect(opened.active, isTrue);
      expect(opened.closedMessage, isNull);
      expect(opened.reopenDate, isNull);

      // The default branch moves and comes back; the default is listed first.
      expect((await repository.setDefaultBranch(dokkiId)).isDefault, isTrue);
      list = await repository.branches();
      expect(
        [for (final b in list.items) (b.id, b.isDefault)],
        [(dokkiId, true), (maadiId, false)],
      );
      expect((await doctor.clinic.me()).defaultBranchId, dokkiId);
      expect((await repository.setDefaultBranch(maadiId)).isDefault, isTrue);
      expect((await repository.branch(dokkiId)).isDefault, isFalse);

      // Prices: the doctor's, then the Dokki examination price.
      var prices = await repository.prices();
      expect(prices.doctor.examinationPricePiasters, 30000);
      expect(prices.doctor.consultationPricePiasters, 15000);
      prices = await repository.updatePrices(
        examinationPricePiasters: 35000,
        consultationPricePiasters: 17500,
      );
      expect(prices.doctor.examinationPricePiasters, 35000);
      expect(prices.doctor.consultationPricePiasters, 17500);
      final doctorChange = prices.history.items.first;
      expect(doctorChange.branchId, isNull);
      expect(doctorChange.changedBy.userId, doctorUserId);
      expect(doctorChange.changedBy.role, 'doctor');
      expect(doctorChange.changedBy.name, 'سامي عبد الله');
      expect(doctorChange.before.examinationPricePiasters, 30000);
      expect(doctorChange.after.examinationPricePiasters, 35000);
      expect(doctorChange.after.consultationPricePiasters, 17500);

      prices = await repository.updatePrices(
        branchId: dokkiId,
        examinationPricePiasters: 40000,
      );
      final dokkiPrices = prices.branches.singleWhere(
        (row) => row.branchId == dokkiId,
      );
      expect(dokkiPrices.nameAr, 'فرع الدقي');
      expect(dokkiPrices.isDefault, isFalse);
      expect(dokkiPrices.assigned, isTrue);
      expect(dokkiPrices.status, BranchStatuses.active);
      expect(dokkiPrices.prices.examinationPricePiasters, 40000);
      expect(dokkiPrices.prices.consultationPricePiasters, isNull);
      expect(dokkiPrices.prices.usesDoctorPrices, isFalse);
      expect(dokkiPrices.prices.effectiveExaminationPricePiasters, 40000);
      expect(dokkiPrices.prices.effectiveConsultationPricePiasters, 17500);
      final maadiPrices = prices.branches.singleWhere(
        (row) => row.branchId == maadiId,
      );
      expect(maadiPrices.isDefault, isTrue);
      expect(maadiPrices.prices.usesDoctorPrices, isTrue);
      expect(maadiPrices.prices.effectiveExaminationPricePiasters, 35000);
      final branchChange = prices.history.items.first;
      expect(branchChange.branchId, dokkiId);
      expect(branchChange.branchNameAr, 'فرع الدقي');
      expect(branchChange.branchNameEn, 'Dokki');
      expect(branchChange.before.isEmpty, isTrue);
      expect(branchChange.after.examinationPricePiasters, 40000);
      expect(prices.history.totalCount, 2);
      expect(prices.history.page, 1);

      // Notification preferences: the defaults, then every value away from its
      // default, two at a time (only the values sent change).
      var prefs = await repository.notificationPrefs();
      expect(prefs.toJson(), {
        'chat': true,
        'reminders': true,
        'showPreview': false,
        'bookings': false,
      });
      prefs = await repository.updateNotificationPrefs(
        showPreview: true,
        bookings: true,
      );
      expect(prefs.toJson(), {
        'chat': true,
        'reminders': true,
        'showPreview': true,
        'bookings': true,
      });
      prefs = await repository.updateNotificationPrefs(
        chat: false,
        reminders: false,
      );
      expect(prefs.toJson(), {
        'chat': false,
        'reminders': false,
        'showPreview': true,
        'bookings': true,
      });
      prefs = await repository.notificationPrefs();
      expect(prefs.toJson(), {
        'chat': false,
        'reminders': false,
        'showPreview': true,
        'bookings': true,
      });

      final profile = await repository.doctorProfile();
      expect(profile.doctorId, doctorId);
      expect(profile.fullName, 'سامي عبد الله');
      expect(profile.fullNameEn, 'Sami Abdallah');
      expect(profile.title, 'استشاري');
      expect(profile.specialtyId, context.doctor.specialtyId);
      expect(profile.specialty?.id, context.doctor.specialtyId);
      expect(profile.specialty?.nameAr, context.doctor.specialtyNameAr);
      expect(profile.extraSpecialties, isEmpty);
      expect(profile.email, doctorEmail);
      expect(profile.emailVerified, isFalse);
      expect(profile.phone, e164(doctorPhone));
      expect(profile.licenseNumber, licenseNumber);
      expect(profile.status, 'active');
      expect(profile.updatedAt, isNotNull);
      clinicDay
        ..today = today
        ..maadiId = maadiId
        ..dokkiId = dokkiId;
    },
    skip: skip,
  );

  test('patients: lookup, add, view, medical profile, register', () async {
    final patients = doctor.patients;
    var lookup = await patients.lookupPhone(patientPhone);
    expect(lookup.status, PhoneLookupStatus.isNew);
    expect(lookup.patientId, isNull);

    final created = await patients.createPatient(
      PatientDraft(
        fullName: 'منة حسن',
        gender: Gender.female,
        phone:
            '${patientPhone.substring(0, 3)} ${patientPhone.substring(3, 7)} ${patientPhone.substring(7)}',
        dateOfBirth: DateTime.utc(1990, 5, 1),
        address: 'المعادي',
        bloodType: 'A+',
        emergencyContactName: 'حسن علي',
        emergencyContactPhone: '02 2358 1234',
      ),
    );
    expect(created.linked, isFalse);
    expect(created.temporaryPassword, hasLength(8));
    final view = created.patient;
    patientId = view.patientId;
    expect(view.fileNumber, 1);
    expect(view.fullName, 'منة حسن');
    expect(view.phone, e164(patientPhone));
    expect(view.gender, Gender.female);
    expect(dayKey(view.dateOfBirth), '1990-05-01');
    expect(view.dateOfBirthEstimated, isFalse);
    expect(view.ageYears, _age(today, 1990, 5, 1));
    expect(view.ownsDetails, isTrue);
    expect(view.address, 'المعادي');
    expect(view.bloodType, 'A+');
    expect(view.emergencyContactName, 'حسن علي');
    expect(view.emergencyContactPhone, '+20223581234');
    expect(view.accountStatus, 'active');
    expect(view.archived, isFalse);
    expect(view.linkedAt.isUtc, isTrue);
    expect(view.visits.total, 0);
    expect(view.visits.lastVisit, isNull);
    expect(view.visits.firstVisitAt, isNull);
    expect(view.totalPaidPiasters, 0);
    expect(view.hasAllergies, isFalse);

    lookup = await patients.lookupPhone(e164(patientPhone));
    expect(lookup.status, PhoneLookupStatus.linkedToYou);
    expect(lookup.patientId, patientId);
    expect(lookup.fileNumber, 1);
    expect(lookup.fullName, 'منة حسن');
    expect(lookup.archived, isFalse);

    await expectLater(
      patients.createPatient(PatientDraft.link(patientPhone)),
      throwsA(
        _apiError(409, ApiCodes.patientAlreadyLinked)
            .having((e) => e.details['patientId'], 'patientId', patientId)
            .having((e) => e.details['fileNumber'], 'fileNumber', 1),
      ),
    );

    final profile = await patients.updateMedicalProfile(
      patientId,
      const MedicalProfileDraft(
        allergies: ['Penicillin'],
        chronicDiseases: ['سكر', 'ضغط'],
        currentMedications: ['Metformin 500'],
        familyHistory: 'الأب: سكر',
      ),
    );
    expect(profile.patientId, patientId);
    expect([for (final item in profile.allergies) item.text], ['Penicillin']);
    expect(
      [for (final item in profile.chronicDiseases) item.text],
      ['سكر', 'ضغط'],
    );
    expect(
      [for (final item in profile.currentMedications) item.text],
      ['Metformin 500'],
    );
    expect(profile.surgeries, isEmpty);
    expect(profile.familyHistory, 'الأب: سكر');
    expect(profile.notes, isNull);
    expect(profile.allergies.single.id, isNotEmpty);

    final read = await patients.medicalProfile(patientId);
    expect(read.allergies.single.id, profile.allergies.single.id);
    expect(
      [for (final item in read.chronicDiseases) item.id],
      [for (final item in profile.chronicDiseases) item.id],
    );
    expect(read.familyHistory, 'الأب: سكر');

    final withAllergy = await patients.patient(patientId);
    expect(withAllergy.hasAllergies, isTrue);
    expect(withAllergy.fileNumber, 1);
    expect(withAllergy.fullName, 'منة حسن');

    // «منه» finds «منة» (search normalization), and so does the phone.
    for (final search in ['منه', patientPhone.substring(0, 7)]) {
      final page = await patients.register(RegisterQuery(search: search));
      expect(page.totalCount, 1, reason: search);
      final row = page.items.single;
      expect(row.patientId, patientId);
      expect(row.fileNumber, 1);
      expect(row.fullName, 'منة حسن');
      expect(row.phone, e164(patientPhone));
      expect(row.gender, Gender.female);
      expect(row.ageYears, view.ageYears);
      expect(row.hasAllergies, isTrue);
      expect(row.chronicDiseases, ['سكر', 'ضغط']);
      expect(row.totalPaidPiasters, 0);
      expect(row.visits.total, 0);
      expect(row.archived, isFalse);
      expect(row.linkedAt, view.linkedAt);
    }
    final none = await patients.register(
      const RegisterQuery(search: 'غيرموجود'),
    );
    expect(none.totalCount, 0);
    expect(none.items, isEmpty);

    // D7: the whole form is replaced (the emergency name left out is cleared).
    final edited = await patients.updatePatient(
      patientId,
      PatientDraft(
        fullName: 'منة حسن',
        gender: Gender.female,
        dateOfBirth: DateTime.utc(1990, 5, 1),
        nationalId: '٢٩٠٠٥٠١٠١٢٣٤٥٦',
        address: 'مدينة نصر',
        bloodType: 'O-',
        emergencyContactPhone: '02 2358 1234',
      ),
    );
    expect(edited.fullName, 'منة حسن');
    expect(edited.nationalId, '29005010123456');
    expect(edited.address, 'مدينة نصر');
    expect(edited.bloodType, 'O-');
    expect(edited.emergencyContactName, isNull);
    expect(edited.emergencyContactPhone, '+20223581234');
    expect(edited.phone, e164(patientPhone));

    final newPhone = mobile();
    final moved = await patients.updatePatientPhone(patientId, newPhone);
    expect(moved.phone, e164(newPhone));
    expect((await patients.lookupPhone(newPhone)).patientId, patientId);
    expect(
      (await patients.lookupPhone(patientPhone)).status,
      PhoneLookupStatus.isNew,
    );
    expect(await patients.resetPatientPassword(patientId), hasLength(8));

    // BR-P7: archived patients leave the default register.
    final archived = await patients.setArchived(patientId, archived: true);
    expect(archived.archived, isTrue);
    expect(archived.archivedAt, isNotNull);
    expect((await patients.register(const RegisterQuery())).totalCount, 0);
    final archive = await patients.register(
      const RegisterQuery(archived: true),
    );
    expect(archive.items.single.patientId, patientId);
    expect(archive.items.single.archived, isTrue);
    final back = await patients.setArchived(patientId, archived: false);
    expect(back.archived, isFalse);
    expect(back.archivedAt, isNull);
    clinicDay
      ..patientId = patientId
      ..patientPhone = newPhone;
  }, skip: skip);

  test(
    'sessions: an examination, consultations to the limit, edits, delete, lists and fees',
    () async {
      final sessions = doctor.sessions;
      var info = await sessions.newSessionInfo(
        patientId: patientId,
        branchId: maadiId,
      );
      expect(info.patientId, patientId);
      expect(info.branchId, maadiId);
      expect(info.isFirstVisit, isTrue);
      expect(info.lastSession, isNull);
      expect(info.consultationsSinceExam, 0);
      expect(info.maxConsecutiveConsultations, maxConsultations);
      expect(info.consultationAllowed, isFalse);
      expect(info.consultationBlockedReason, ConsultationBlock.firstVisit);
      expect(info.examination.allowed, isTrue);
      expect(info.examination.platformFeePiasters, examinationFee);
      expect(info.examination.visitPricePiasters, 35000);
      expect(info.examination.priceSource, 'doctor');
      expect(info.consultation.allowed, isFalse);
      expect(info.consultation.platformFeePiasters, consultationFee);
      expect(info.consultation.visitPricePiasters, 17500);

      final followUp = dayKey(_day(today).add(const Duration(days: 7)));
      final examination = await sessions.createSession(
        NewSessionDraft(
          patientId: patientId,
          branchId: maadiId,
          type: SessionType.examination,
          chiefComplaint: 'صداع',
          vitals: const Vitals(
            bpSys: 120,
            bpDia: 80,
            pulse: 75,
            tempC: 37.2,
            weightKg: 70.5,
            heightCm: 165,
            glucose: 95,
          ),
          findings: 'سليم',
          diagnosis: 'صداع نصفي',
          patientNotes: 'راحة',
          privateNote: 'ملاحظة خاصة',
          followUpDate: _day(followUp),
          paymentMethod: PaymentMethod.cash,
        ),
      );
      examinationId = examination.sessionId;
      amounts.add(35000);
      expect(examination.patientId, patientId);
      expect(examination.fileNumber, 1);
      expect(examination.patientName, 'منة حسن');
      expect(examination.type, SessionType.examination);
      expect(examination.at.isUtc, isTrue);
      expect(dayKey(examination.day), today);
      expect(examination.branch.id, maadiId);
      expect(examination.branch.nameAr, 'فرع المعادي');
      expect(examination.platformFeePiasters, examinationFee);
      expect(examination.amountChargedPiasters, 35000);
      expect(examination.listPricePiasters, 35000);
      expect(examination.paymentMethod, PaymentMethod.cash);
      expect(examination.recordedBy.userId, doctorUserId);
      expect(examination.recordedBy.name, 'سامي عبد الله');
      expect(examination.recordedBy.isAssistant, isFalse);
      expect(examination.awaitingDoctor, isFalse);
      final clinical = examination.clinical!;
      expect(clinical.chiefComplaint, 'صداع');
      expect(clinical.findings, 'سليم');
      expect(clinical.diagnosis, 'صداع نصفي');
      expect(clinical.patientNotes, 'راحة');
      expect(
        clinical.followUpDate == null ? null : dayKey(clinical.followUpDate!),
        followUp,
      );
      expect(clinical.vitals.bpSys, 120);
      expect(clinical.vitals.bpDia, 80);
      expect(clinical.vitals.pulse, 75);
      expect(clinical.vitals.tempC, 37.2);
      expect(clinical.vitals.weightKg, 70.5);
      expect(clinical.vitals.heightCm, 165);
      expect(clinical.vitals.glucose, 95);
      expect(examination.hasPrivateNote, isTrue);
      expect(examination.can.editClinical, isTrue);
      expect(examination.can.editAmount, isTrue);
      expect(examination.can.delete, isTrue);
      expect(examination.can.deleteBlockedReason, isNull);
      expect(examination.can.privateNote, isTrue);

      // Consultations up to the limit (BR-S3); the first one is cheaper.
      final consultationIds = <String>[];
      for (var i = 1; i <= maxConsultations; i++) {
        final consultation = await sessions.createSession(
          NewSessionDraft(
            patientId: patientId,
            branchId: maadiId,
            type: SessionType.consultation,
            amountChargedPiasters: i == 1 ? 10000 : null,
          ),
        );
        consultationIds.add(consultation.sessionId);
        amounts.add(i == 1 ? 10000 : 17500);
        expect(consultation.type, SessionType.consultation);
        expect(consultation.platformFeePiasters, consultationFee);
        expect(consultation.listPricePiasters, 17500);
        expect(consultation.amountChargedPiasters, amounts.last);
        expect(consultation.paymentMethod, isNull);
        expect(consultation.clinical, isNotNull);
        expect(consultation.clinical!.isEmpty, isTrue);
        expect(consultation.hasPrivateNote, isFalse);

        info = await sessions.newSessionInfo(
          patientId: patientId,
          branchId: maadiId,
        );
        expect(info.isFirstVisit, isFalse);
        expect(info.consultationsSinceExam, i);
        expect(info.consultationAllowed, i < maxConsultations);
        expect(info.consultation.allowed, i < maxConsultations);
        expect(
          info.consultationBlockedReason,
          i < maxConsultations ? isNull : ConsultationBlock.limitReached,
        );
        expect(info.lastSession!.sessionId, consultation.sessionId);
        expect(info.lastSession!.type, SessionType.consultation);
        expect(info.lastSession!.daysAgo, 0);
        expect(dayKey(info.lastSession!.day), today);
        expect(info.lastSession!.branchId, maadiId);
        expect(info.lastSession!.branchNameAr, 'فرع المعادي');
      }

      // One more is refused, with the numbers for the BR-S4 message.
      await expectLater(
        sessions.createSession(
          NewSessionDraft(
            patientId: patientId,
            branchId: maadiId,
            type: SessionType.consultation,
          ),
        ),
        throwsA(
          _apiError(409, ApiCodes.consultationRequiresExam)
              .having((e) => e.details['reason'], 'reason', 'limitReached')
              .having(
                (e) => e.details['consultationsSinceExam'],
                'consultationsSinceExam',
                maxConsultations,
              )
              .having(
                (e) => e.details['maxConsecutiveConsultations'],
                'maxConsecutiveConsultations',
                maxConsultations,
              ),
        ),
      );

      // D9: the examination is no longer the latest.
      var view = await sessions.session(examinationId);
      expect(view.sessionId, examinationId);
      expect(view.clinical!.diagnosis, 'صداع نصفي');
      expect(view.can.delete, isFalse);
      expect(view.can.deleteBlockedReason, DeleteBlock.notLatest);
      expect(view.updatedAt.isUtc, isTrue);
      await expectLater(
        sessions.deleteSession(examinationId, 'سجلت للمريض الخطأ'),
        throwsA(
          _apiError(
            409,
            ApiCodes.sessionNotDeletable,
          ).having((e) => e.details['reason'], 'reason', 'notLatest'),
        ),
      );

      final newFollowUp = dayKey(_day(today).add(const Duration(days: 14)));
      view = await sessions.updateClinical(
        examinationId,
        ClinicalDraft(
          chiefComplaint: 'كحة',
          findings: 'صفير',
          vitals: const Vitals(tempC: 38.2),
          diagnosis: 'التهاب شعبي',
          patientNotes: 'مضاد حيوي',
          followUpDate: _day(newFollowUp),
        ),
      );
      expect(view.clinical!.chiefComplaint, 'كحة');
      expect(view.clinical!.diagnosis, 'التهاب شعبي');
      expect(view.clinical!.vitals.tempC, 38.2);
      expect(
        view.clinical!.vitals.bpSys,
        isNull,
        reason: 'the whole form is replaced',
      );
      expect(dayKey(view.clinical!.followUpDate!), newFollowUp);
      expect(view.type, SessionType.examination);

      var note = await sessions.privateNote(examinationId);
      expect(note.sessionId, examinationId);
      expect(note.text, 'ملاحظة خاصة');
      expect(note.updatedAt, isNotNull);
      note = await sessions.setPrivateNote(examinationId, 'نص جديد');
      expect(note.text, 'نص جديد');
      expect((await sessions.privateNote(examinationId)).text, 'نص جديد');

      // The latest consultation: a new amount, then deleted (same day, BR-S7).
      final latestId = consultationIds.last;
      view = await sessions.updateAmountCharged(
        latestId,
        amountChargedPiasters: 15000,
        paymentMethod: PaymentMethod.card,
      );
      expect(view.amountChargedPiasters, 15000);
      expect(view.paymentMethod, PaymentMethod.card);
      expect(view.platformFeePiasters, consultationFee);
      expect(view.can.delete, isTrue);
      await sessions.deleteSession(latestId, 'سجلت للمريض الخطأ');
      amounts.removeLast();
      await expectLater(
        sessions.session(latestId),
        throwsA(_apiError(404, ApiCodes.notFound)),
      );
      info = await sessions.newSessionInfo(
        patientId: patientId,
        branchId: maadiId,
      );
      expect(info.consultationsSinceExam, maxConsultations - 1);
      expect(info.consultationAllowed, isTrue);

      // The patient's sessions, newest first.
      final list = await sessions.patientSessions(patientId);
      expect(list.totalCount, maxConsultations);
      expect(
        list.items.first.type,
        maxConsultations > 1
            ? SessionType.consultation
            : SessionType.examination,
      );
      final examRow = list.items.last;
      expect(examRow.sessionId, examinationId);
      expect(examRow.type, SessionType.examination);
      expect(dayKey(examRow.day), today);
      expect(examRow.patientId, patientId);
      expect(examRow.fileNumber, 1);
      expect(examRow.patientName, 'منة حسن');
      expect(examRow.branch.id, maadiId);
      expect(examRow.platformFeePiasters, examinationFee);
      expect(examRow.amountChargedPiasters, 35000);
      expect(examRow.paymentMethod, PaymentMethod.cash);
      expect(examRow.recordedBy.userId, doctorUserId);
      expect(examRow.awaitingDoctor, isFalse);
      expect(examRow.chiefComplaint, 'كحة');
      expect(examRow.diagnosis, 'التهاب شعبي');

      // Fees: one examination and the consultations left.
      final expected = FeeTotals(
        examinationCount: 1,
        consultationCount: maxConsultations - 1,
        examinationFeePiasters: examinationFee,
        consultationFeePiasters: consultationFee * (maxConsultations - 1),
        totalPiasters:
            examinationFee + consultationFee * (maxConsultations - 1),
      );
      final day = await sessions.day();
      expect(dayKey(day.day), today);
      expect(
        [for (final row in day.items) row.sessionId],
        [for (final row in list.items) row.sessionId],
      );
      expect(day.totals.toJson(), expected.toJson());
      expect(day.amountChargedTotalPiasters, amounts.fold(0, (a, b) => a + b));
      final dokkiDay = await sessions.day(
        branchId: dokkiId,
        type: SessionType.examination,
      );
      expect(dokkiDay.items, isEmpty);
      expect(dokkiDay.totals.toJson(), FeeTotals.zero.toJson());
      final sameDay = await sessions.day(
        day: _day(today),
        type: SessionType.examination,
        recordedBy: doctorUserId,
      );
      expect([for (final row in sameDay.items) row.sessionId], [examinationId]);
      final yesterday = _day(today).subtract(const Duration(days: 1));
      final dayBefore = await sessions.day(day: yesterday);
      expect(dayKey(dayBefore.day), dayKey(yesterday));
      expect(dayBefore.items, isEmpty);

      final summary = await sessions.feeSummary();
      expect(dayKey(summary.day), today);
      expect(monthKey(summary.month), today.substring(0, 7));
      expect(summary.today.toJson(), expected.toJson());
      expect(summary.thisMonth.toJson(), expected.toJson());

      final month = await sessions.month();
      expect(monthKey(month.month), today.substring(0, 7));
      expect(month.branchId, isNull);
      expect(month.totals.toJson(), expected.toJson());
      expect(month.branches, hasLength(1));
      expect(month.branches.single.branchId, maadiId);
      expect(month.branches.single.nameAr, 'فرع المعادي');
      expect(month.branches.single.totals.toJson(), expected.toJson());
      expect(month.days, hasLength(int.parse(today.substring(8))));
      expect(dayKey(month.days.first.day), '${today.substring(0, 7)}-01');
      expect(dayKey(month.days.last.day), today);
      expect(month.days.last.totals.toJson(), expected.toJson());
      final dokkiMonth = await sessions.month(
        month: _day(today),
        branchId: dokkiId,
      );
      expect(monthKey(dokkiMonth.month), today.substring(0, 7));
      expect(dokkiMonth.branchId, dokkiId);
      expect(dokkiMonth.totals.toJson(), FeeTotals.zero.toJson());
      expect(dokkiMonth.branches, isEmpty);

      final patient = await doctor.patients.patient(patientId);
      expect(patient.visits.total, maxConsultations);
      expect(patient.visits.examinations, 1);
      expect(patient.visits.consultations, maxConsultations - 1);
      expect(patient.visits.consultationsSinceExam, maxConsultations - 1);
      expect(patient.visits.firstVisitAt, examination.at);
      expect(patient.visits.lastVisit!.sessionId, list.items.first.sessionId);
      expect(patient.visits.lastVisit!.daysAgo, 0);
      expect(patient.totalPaidPiasters, amounts.fold(0, (a, b) => a + b));
    },
    skip: skip,
  );

  test('a reception assistant in one branch works the desk', () async {
    final created = await doctor.clinicAdmin.createAssistant(
      AssistantDraft(
        fullName: 'سارة محمود',
        phone: assistantPhone,
        allBranches: false,
        branchIds: {dokkiId},
        permissions: AssistantPreset.permissions[AssistantPreset.reception]!,
      ),
    );
    expect(created.temporaryPassword, hasLength(8));
    final made = created.assistant;
    assistantUserId = made.userId;
    expect(made.fullName, 'سارة محمود');
    expect(made.phone, e164(assistantPhone));
    expect(made.preset, AssistantPreset.reception);
    expect(made.status, AssistantStatuses.active);
    expect(made.allBranches, isFalse);
    expect(made.branchIds, [dokkiId]);
    expect(made.branches.single.id, dokkiId);
    expect(made.branches.single.nameAr, 'فرع الدقي');
    expect(made.branches.single.nameEn, 'Dokki');
    expect(made.branches.single.status, BranchStatuses.active);
    expect(
      made.permissions,
      AssistantPreset.permissions[AssistantPreset.reception],
    );
    expect(made.mustChangePassword, isTrue);
    expect(made.lastActiveAt, isNull);
    expect(made.removedAt, isNull);
    expect(made.createdAt.isUtc, isTrue);

    final team = await doctor.clinicAdmin.assistants();
    expect(team.count, 1);
    expect(team.canAdd, team.limit > 1);
    expect(team.items.single.userId, assistantUserId);
    expect(
      (await doctor.clinicAdmin.assistant(assistantUserId)).phone,
      e164(assistantPhone),
    );

    // First sign-in with the temporary password, then A9.
    final first = await assistant.auth.login(
      identifier: e164(assistantPhone),
      password: created.temporaryPassword,
      device: device('assistant'),
    );
    final temporary = (first as SignedIn).session;
    expect(temporary.role, UserRole.assistant);
    expect(temporary.userId, assistantUserId);
    expect(temporary.doctorId, doctorId);
    expect(temporary.doctorStatus, DoctorStatus.active);
    expect(temporary.mustChangePassword, isTrue);
    assistant.token = temporary.accessToken;
    await expectLater(
      assistant.clinic.me(),
      throwsA(_apiError(403, ApiCodes.passwordChangeRequired)),
    );
    final session = await assistant.auth.setNewPassword(
      newPassword: assistantPassword,
      device: device('assistant'),
    );
    expect(session.mustChangePassword, isFalse);
    assistant.token = session.accessToken;

    final context = await assistant.clinic.me();
    expect(context.role, UserRole.assistant);
    expect(context.isDoctor, isFalse);
    expect(context.doctor.id, doctorId);
    expect(context.doctor.fullName, 'سامي عبد الله');
    expect(context.assistant!.userId, assistantUserId);
    expect(context.assistant!.fullName, 'سارة محمود');
    expect(context.assistant!.preset, AssistantPreset.reception);
    expect(context.assistant!.allBranches, isFalse);
    expect(context.assistant!.branchIds, [dokkiId]);
    expect(
      context.permissions,
      AssistantPreset.permissions[AssistantPreset.reception],
    );
    expect(context.can(ClinicPermission.sessionsCreate), isTrue);
    expect(context.can(ClinicPermission.clinicalView), isFalse);
    expect(context.branches, hasLength(2));
    expect(context.branch(maadiId)!.assigned, isFalse);
    expect(context.branch(dokkiId)!.assigned, isTrue);
    expect([for (final b in context.workBranches) b.id], [dokkiId]);

    // Every branch is readable (AS17); `assigned` says where they work.
    final branches = await assistant.clinicAdmin.branches();
    expect(
      [for (final b in branches.items) (b.id, b.assigned)],
      [(maadiId, false), (dokkiId, true)],
    );
    expect((await assistant.clinicAdmin.branch(maadiId)).assigned, isFalse);
    expect((await assistant.clinicAdmin.branch(dokkiId)).assigned, isTrue);
    await expectLater(
      assistant.clinicAdmin.prices(),
      throwsA(
        _apiError(
          403,
          ApiCodes.permissionDenied,
        ).having((e) => e.details['permission'], 'permission', 'pricesManage'),
      ),
    );

    // Their own notification preferences, not the doctor's.
    final prefs = await assistant.clinicAdmin.notificationPrefs();
    expect(prefs.toJson(), {
      'chat': true,
      'reminders': true,
      'showPreview': false,
      'bookings': false,
    });

    // A new patient (no revenueView or clinicalView: those fields are hidden).
    expect(
      (await assistant.patients.lookupPhone(assistantPatientPhone)).status,
      PhoneLookupStatus.isNew,
    );
    final added = await assistant.patients.createPatient(
      PatientDraft(
        fullName: 'كريم سامي',
        gender: Gender.male,
        phone: assistantPatientPhone,
        ageYears: 30,
      ),
    );
    expect(added.linked, isFalse);
    expect(added.temporaryPassword, hasLength(8));
    assistantPatientId = added.patient.patientId;
    expect(added.patient.fileNumber, 2);
    expect(added.patient.gender, Gender.male);
    expect(added.patient.ageYears, 30);
    expect(added.patient.dateOfBirthEstimated, isTrue);
    expect(added.patient.totalPaidPiasters, isNull);
    expect(added.patient.hasAllergies, isNull);

    // An examination in their branch, at the branch's price.
    final info = await assistant.sessions.newSessionInfo(
      patientId: assistantPatientId,
      branchId: dokkiId,
    );
    expect(info.isFirstVisit, isTrue);
    expect(info.examination.visitPricePiasters, 40000);
    expect(info.examination.priceSource, 'branch');
    expect(info.consultation.visitPricePiasters, 17500);
    expect(info.consultation.priceSource, 'doctor');
    await expectLater(
      assistant.sessions.newSessionInfo(
        patientId: assistantPatientId,
        branchId: maadiId,
      ),
      throwsA(_apiError(403, ApiCodes.branchNotAllowed)),
    );
    await expectLater(
      assistant.sessions.createSession(
        NewSessionDraft(
          patientId: assistantPatientId,
          branchId: dokkiId,
          type: SessionType.examination,
          diagnosis: 'لا',
        ),
      ),
      throwsA(
        _apiError(403, ApiCodes.permissionDenied)
            .having((e) => e.details['permission'], 'permission', 'doctorOnly')
            .having((e) => e.details['fields'], 'fields', ['diagnosis']),
      ),
    );
    final recorded = await assistant.sessions.createSession(
      NewSessionDraft(
        patientId: assistantPatientId,
        branchId: dokkiId,
        type: SessionType.examination,
        chiefComplaint: 'ألم',
        vitals: const Vitals(pulse: 80),
        amountChargedPiasters: 30000,
        paymentMethod: PaymentMethod.instapay,
      ),
    );
    expect(recorded.type, SessionType.examination);
    expect(recorded.branch.id, dokkiId);
    expect(recorded.platformFeePiasters, examinationFee);
    expect(recorded.amountChargedPiasters, 30000);
    expect(recorded.listPricePiasters, 40000);
    expect(recorded.paymentMethod, PaymentMethod.instapay);
    expect(recorded.recordedBy.userId, assistantUserId);
    expect(recorded.recordedBy.name, 'سارة محمود');
    expect(recorded.recordedBy.isAssistant, isTrue);
    expect(recorded.awaitingDoctor, isTrue);
    expect(recorded.clinical, isNull);
    expect(recorded.hasPrivateNote, isNull);
    expect(recorded.can.editClinical, isFalse);
    expect(recorded.can.editAmount, isTrue);
    expect(recorded.can.delete, isFalse);
    expect(recorded.can.privateNote, isFalse);

    await expectLater(
      assistant.sessions.privateNote(recorded.sessionId),
      throwsA(
        _apiError(
          403,
          ApiCodes.permissionDenied,
        ).having((e) => e.details['permission'], 'permission', 'doctorOnly'),
      ),
    );
    await expectLater(
      assistant.sessions.feeSummary(),
      throwsA(
        _apiError(
          403,
          ApiCodes.permissionDenied,
        ).having((e) => e.details['permission'], 'permission', 'billingView'),
      ),
    );

    // Today in their branch only, without the clinic's revenue.
    final day = await assistant.sessions.day();
    expect([for (final row in day.items) row.sessionId], [recorded.sessionId]);
    expect(
      day.items.single.amountChargedPiasters,
      30000,
      reason: 'they recorded it',
    );
    expect(day.items.single.chiefComplaint, isNull, reason: 'clinicalView');
    expect(day.items.single.awaitingDoctor, isTrue);
    expect(day.totals.examinationCount, 1);
    expect(day.amountChargedTotalPiasters, isNull);

    // The register is clinic-wide.
    final register = await assistant.patients.register(
      const RegisterQuery(sort: RegisterSort.fileNumber),
    );
    expect([for (final row in register.items) row.fileNumber], [1, 2]);
    expect(register.items.first.totalPaidPiasters, isNull);
    expect(register.items.first.hasAllergies, isNull);
    expect(register.items.first.chronicDiseases, isNull);
  }, skip: skip);

  test(
    'the doctor reads the activity log, changes the assistant, then disables and removes them',
    () async {
      final activity = await doctor.clinicAdmin.activity(
        const ActivityFilter(),
        pageSize: 100,
      );
      final rows = activity.page.items;
      expect(activity.page.totalCount, rows.length);
      for (final action in [
        'branchCreated',
        'branchHoursUpdated',
        'pricesUpdated',
        'patientCreated',
        'patientMedicalProfileUpdated',
        'sessionCreated',
        'sessionClinicalUpdated',
        'sessionPrivateNoteUpdated',
        'sessionAmountChanged',
        'sessionDeleted',
        'assistantCreated',
      ]) {
        expect(activity.actions, contains(action));
        expect(rows.map((r) => r.action), contains(action));
      }
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i - 1].at.isBefore(rows[i].at),
          isFalse,
          reason: 'newest first',
        );
      }

      final byAssistant = rows.singleWhere(
        (r) => r.action == 'patientCreated' && r.actor.role == 'assistant',
      );
      expect(byAssistant.actor.userId, assistantUserId);
      expect(byAssistant.actor.name, 'سارة محمود');
      expect(byAssistant.targetType, 'patient');
      expect(byAssistant.targetId, assistantPatientId);
      expect(byAssistant.patient!.id, assistantPatientId);
      expect(byAssistant.patient!.name, 'كريم سامي');
      expect(byAssistant.patient!.fileNumber, 2);
      expect(byAssistant.details['fileNumber'], 2);

      final hours = rows.singleWhere((r) => r.action == 'branchHoursUpdated');
      expect(hours.actor.userId, doctorUserId);
      expect(hours.actor.role, 'doctor');
      expect(hours.targetType, 'branch');
      expect(hours.targetId, dokkiId);
      expect(hours.patient, isNull);
      expect(hours.details['periods'], 4);

      final deleted = rows.singleWhere((r) => r.action == 'sessionDeleted');
      expect(deleted.targetType, 'session');
      expect(deleted.patient!.id, patientId);
      expect(deleted.patient!.fileNumber, 1);

      expect(activity.people.first.userId, doctorUserId);
      expect(activity.people.first.role, 'doctor');
      expect(activity.people.first.name, 'سامي عبد الله');
      expect(activity.people.first.status, isNull);
      final person = activity.people.singleWhere(
        (p) => p.userId == assistantUserId,
      );
      expect(person.role, 'assistant');
      expect(person.name, 'سارة محمود');
      expect(person.status, AssistantStatuses.active);

      final theirs = await doctor.clinicAdmin.activity(
        ActivityFilter(actorUserId: assistantUserId),
        pageSize: 100,
      );
      expect(theirs.page.items, isNotEmpty);
      expect(
        theirs.page.items.every((r) => r.actor.userId == assistantUserId),
        isTrue,
      );
      final forPatient = await doctor.clinicAdmin.activity(
        ActivityFilter(
          patientId: patientId,
          action: 'sessionCreated',
          from: _day(today),
          to: _day(today),
        ),
      );
      expect(forPatient.page.totalCount, maxConsultations + 1);

      // Every branch and the fee totals: applies on the assistant's next request.
      final permissions = {
        ...AssistantPreset.permissions[AssistantPreset.reception]!,
        ClinicPermission.billingView,
      };
      final changed = await doctor.clinicAdmin.updateAssistant(
        assistantUserId,
        fullName: 'سارة محمود علي',
        allBranches: true,
        permissions: permissions,
      );
      expect(changed.fullName, 'سارة محمود علي');
      expect(changed.allBranches, isTrue);
      expect(changed.branchIds, isEmpty);
      expect(changed.branches, isEmpty);
      expect(changed.permissions, permissions);
      expect(changed.preset, AssistantPreset.custom);
      expect(changed.mustChangePassword, isFalse);
      expect(changed.lastActiveAt, isNotNull);

      final context = await assistant.clinic.me();
      expect(context.assistant!.fullName, 'سارة محمود علي');
      expect(context.assistant!.allBranches, isTrue);
      expect(context.assistant!.preset, AssistantPreset.custom);
      expect(context.can(ClinicPermission.billingView), isTrue);
      expect(context.branch(maadiId)!.assigned, isTrue);
      final fees = await assistant.sessions.feeSummary();
      expect(fees.today.examinationCount, 2);

      // A8 for an assistant (BR-AS11): a new temporary password signs them out.
      final reset = await doctor.clinicAdmin.resetAssistantPassword(
        assistantUserId,
      );
      expect(reset.temporaryPassword, hasLength(8));
      expect(reset.assistant.userId, assistantUserId);
      expect(reset.assistant.mustChangePassword, isTrue);
      await expectLater(
        assistant.clinic.me(),
        throwsA(_apiError(401, ApiCodes.sessionRevoked)),
      );
      final again = await assistant.auth.login(
        identifier: e164(assistantPhone),
        password: reset.temporaryPassword,
        device: device('assistant'),
      );
      expect((again as SignedIn).session.mustChangePassword, isTrue);
      assistant.token = again.session.accessToken;
      assistant.token = (await assistant.auth.setNewPassword(
        newPassword: assistantPassword,
        device: device('assistant'),
      )).accessToken;
      expect((await assistant.clinic.me()).assistant!.userId, assistantUserId);

      final disabled = await doctor.clinicAdmin.setAssistantStatus(
        assistantUserId,
        AssistantStatuses.disabled,
      );
      expect(disabled.status, AssistantStatuses.disabled);
      expect(disabled.isActive, isFalse);
      await expectLater(
        assistant.clinic.me(),
        throwsA(_apiError(403, ApiCodes.accountDisabled)),
      );
      await expectLater(
        assistant.auth.login(
          identifier: e164(assistantPhone),
          password: assistantPassword,
          device: device('assistant'),
        ),
        throwsA(_apiError(403, ApiCodes.accountDisabled)),
      );
      final team = await doctor.clinicAdmin.assistants();
      expect(team.count, 1, reason: 'a disabled assistant still counts');
      expect(team.items.single.status, AssistantStatuses.disabled);

      // Remove is final (BR-AS8): out of the list and the limit, kept in the log.
      final removed = await doctor.clinicAdmin.setAssistantStatus(
        assistantUserId,
        AssistantStatuses.removed,
      );
      expect(removed.isRemoved, isTrue);
      expect(removed.removedAt, isNotNull);
      final remaining = await doctor.clinicAdmin.assistants();
      expect(remaining.items, isEmpty);
      expect(remaining.count, 0);
      expect(remaining.canAdd, isTrue);
      final everyone = await doctor.clinicAdmin.assistants(
        includeRemoved: true,
      );
      expect(everyone.items.single.userId, assistantUserId);
      expect(everyone.items.single.status, AssistantStatuses.removed);
      await expectLater(
        doctor.clinicAdmin.setAssistantStatus(
          assistantUserId,
          AssistantStatuses.active,
        ),
        throwsA(_apiError(409, ClinicAdminCodes.assistantRemoved)),
      );
      await expectLater(
        assistant.auth.login(
          identifier: e164(assistantPhone),
          password: assistantPassword,
          device: device('assistant'),
        ),
        throwsA(_apiError(401, ApiCodes.invalidCredentials)),
      );

      final later = await doctor.clinicAdmin.activity(
        ActivityFilter(actorUserId: doctorUserId),
        pageSize: 100,
      );
      for (final action in [
        'assistantUpdated',
        'assistantPermissionsChanged',
        'assistantPasswordReset',
        'assistantDisabled',
        'assistantRemoved',
        'branchUpdated',
        'branchStatusChanged',
        'defaultBranchChanged',
        'patientUpdated',
        'patientPhoneChanged',
        'patientPasswordReset',
        'patientArchived',
        'patientUnarchived',
      ]) {
        expect(later.page.items.map((r) => r.action), contains(action));
      }
      final permissionRow = later.page.items.firstWhere(
        (r) => r.action == 'assistantPermissionsChanged',
      );
      expect(permissionRow.targetType, 'assistant');
      expect(permissionRow.targetId, assistantUserId);
      expect(permissionRow.details['added'], [ClinicPermission.billingView]);
      final closure = later.page.items.lastWhere(
        (r) => r.action == 'branchStatusChanged',
      );
      expect(closure.details['after'], BranchStatuses.temporarilyClosed);
      expect(closure.details['before'], BranchStatuses.active);
      expect(
        later.page.items
            .firstWhere((r) => r.action == 'branchUpdated')
            .details['groups'],
        ['info'],
      );
      final people = later.people;
      expect(people.first.userId, doctorUserId);
      expect(
        people.singleWhere((p) => p.userId == assistantUserId).status,
        AssistantStatuses.removed,
      );
      expect(
        people.singleWhere((p) => p.userId == assistantUserId).name,
        'سارة محمود علي',
      );
    },
    skip: skip,
  );

  return clinicDay;
}

const _apiError = apiError;

DateTime _day(String key) => parseDay(key);

int _age(String today, int year, int month, int day) {
  final now = _day(today);
  final birthdayPassed =
      now.month > month || (now.month == month && now.day >= day);
  return now.year - year - (birthdayPassed ? 0 : 1);
}
