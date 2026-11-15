import 'package:el3yada/core/network/api_error_text.dart';
import 'package:el3yada/core/network/api_exception.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/clinic/domain/clinic_context.dart';
import 'package:el3yada/features/clinic/domain/clinic_permissions.dart';
import 'package:el3yada/features/patients/data/fake_clinic_records.dart';
import 'package:el3yada/features/patients/domain/patient_models.dart';
import 'package:el3yada/features/patients/presentation/patients_register_screen.dart' show availableSorts;
import 'package:el3yada/features/sessions/domain/session_models.dart';
import 'package:el3yada/features/sessions/domain/session_rules.dart';
import 'package:el3yada/l10n/gen/app_localizations_ar.dart';
import 'package:el3yada/l10n/gen/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clinic_test.dart' show clinicJson;

/// The examples of backend/docs/api-phase-2-patients.md.
Map<String, dynamic> patientJson({bool revenue = true, bool clinical = true, bool owns = true}) => {
      'patientId': 'p1', 'fileNumber': 1,
      'fullName': 'منى حسن', 'phone': '+201012345678', 'gender': 'female',
      'dateOfBirth': '1990-05-01', 'dateOfBirthEstimated': false, 'ageYears': 36,
      'nationalId': owns ? '29005010123456' : null, 'address': null, 'bloodType': owns ? 'A+' : null,
      'emergencyContactName': null, 'emergencyContactPhone': null,
      'ownsDetails': owns,
      'accountStatus': 'active',
      'archived': false, 'archivedAt': null,
      'linkedAt': '2026-11-15T20:37:09.593Z',
      'visits': {
        'firstVisitAt': '2026-11-03T08:12:00.000Z',
        'lastVisit': {
          'sessionId': 's3', 'at': '2026-11-15T09:30:00.000Z', 'day': '2026-11-15', 'daysAgo': 0,
          'type': 'consultation', 'branchId': 'b1', 'branchNameAr': 'فرع المعادي', 'branchNameEn': null,
        },
        'total': 3, 'examinations': 1, 'consultations': 2, 'consultationsSinceExam': 2,
      },
      'totalPaidPiasters': revenue ? 60000 : null,
      'hasAllergies': clinical ? false : null,
      'files': {'prescription': 0, 'lab': 0, 'radiology': 0, 'other': 0, 'total': 0},
      'prescriptionCount': 0,
      'nextBooking': null,
      'noShowCount': 0,
    };

Map<String, dynamic> infoJson({
  bool firstVisit = false,
  int since = 1,
  int max = 2,
  String? blocked,
  int? examPrice = 30000,
  int? consultPrice = 15000,
}) =>
    {
      'patientId': 'p1', 'branchId': 'b1',
      'isFirstVisit': firstVisit,
      'lastSession': firstVisit
          ? null
          : {'sessionId': 's1', 'at': '2026-11-03T08:00:00Z', 'day': '2026-11-03', 'daysAgo': 12, 'type': 'examination', 'branchId': 'b1', 'branchNameAr': 'فرع المعادي', 'branchNameEn': null},
      'consultationsSinceExam': since,
      'maxConsecutiveConsultations': max,
      'consultationAllowed': blocked == null,
      'consultationBlockedReason': blocked,
      'examination': {'allowed': true, 'platformFeePiasters': 3000, 'visitPricePiasters': examPrice, 'priceSource': 'doctor'},
      'consultation': {'allowed': blocked == null, 'platformFeePiasters': 1500, 'visitPricePiasters': consultPrice, 'priceSource': 'branch'},
    };

Map<String, dynamic> sessionJson({bool assistant = false}) => {
      'sessionId': 's1', 'patientId': 'p1', 'fileNumber': 1, 'patientName': 'منى حسن',
      'type': assistant ? 'consultation' : 'examination', 'at': '2026-11-15T20:37:10.149Z', 'day': '2026-11-15',
      'branch': {'id': 'b1', 'nameAr': 'فرع المعادي', 'nameEn': null},
      'platformFeePiasters': assistant ? 1500 : 3000,
      'amountChargedPiasters': assistant ? 10000 : 30000, 'listPricePiasters': assistant ? 15000 : 30000,
      'paymentMethod': assistant ? null : 'cash',
      'recordedBy': {'userId': 'u1', 'name': assistant ? 'سارة محمود' : 'أحمد علي', 'role': assistant ? 'assistant' : 'doctor'},
      'awaitingDoctor': assistant,
      'clinical': assistant
          ? null
          : {
              'chiefComplaint': 'صداع', 'findings': 'سليم',
              'vitals': {'bpSys': 120, 'bpDia': 80, 'pulse': 75, 'tempC': 37.2, 'weightKg': null, 'heightCm': null, 'glucose': null},
              'diagnosis': 'صداع نصفي', 'patientNotes': 'راحة', 'followUpDate': null,
            },
      'hasPrivateNote': assistant ? null : true,
      'can': {'editClinical': !assistant, 'editAmount': true, 'delete': !assistant, 'deleteBlockedReason': null, 'privateNote': !assistant},
      'updatedAt': '2026-11-15T20:37:10.149Z',
    };

void main() {
  group('models read the contract', () {
    test('patient view, with fields hidden by permission', () {
      final patient = PatientView.fromJson(patientJson());
      expect(patient.fullName, 'منى حسن');
      expect(patient.gender, Gender.female);
      expect(patient.dateOfBirth, DateTime.utc(1990, 5, 1));
      expect(patient.ownsDetails, isTrue);
      expect(patient.bloodType, 'A+');
      expect(patient.visits.lastVisit!.type, SessionType.consultation);
      expect(patient.visits.lastVisit!.day, DateTime.utc(2026, 11, 15));
      expect(patient.visits.consultationsSinceExam, 2);
      expect(patient.totalPaidPiasters, 60000);
      expect(patient.hasAllergies, isFalse);

      // null means "not for you", never zero (spec 7.6).
      final hidden = PatientView.fromJson(patientJson(revenue: false, clinical: false, owns: false));
      expect(hidden.totalPaidPiasters, isNull);
      expect(hidden.hasAllergies, isNull);
      expect(hidden.ownsDetails, isFalse);
      expect(hidden.hasDetails, isFalse);
    });

    test('register rows, lookups and the created patient', () {
      final row = PatientRegisterRow.fromJson({
        ...patientJson(),
        'filesCount': 0,
        'hasAllergies': true,
        'chronicDiseases': ['سكر'],
      });
      expect(row.chronicDiseases, ['سكر']);
      expect(row.hasAllergies, isTrue);

      expect(PhoneLookup.fromJson({'status': 'new'}).status, PhoneLookupStatus.isNew);
      expect(PhoneLookup.fromJson({'status': 'existsElsewhere'}).status, PhoneLookupStatus.existsElsewhere);
      final ours = PhoneLookup.fromJson({'status': 'linkedToYou', 'patientId': 'p1', 'fileNumber': 12, 'fullName': 'منى حسن', 'archived': false});
      expect(ours.fileNumber, 12);

      final created = CreatedPatient.fromJson({'linked': false, 'temporaryPassword': 'MHCQt9VN', 'patient': patientJson()});
      expect(created.temporaryPassword, 'MHCQt9VN');
      expect(created.linked, isFalse);
    });

    test('newSessionInfo, the session view and the day', () {
      final info = NewSessionInfo.fromJson(infoJson());
      expect(info.lastSession!.type, SessionType.examination);
      expect(info.option(SessionType.consultation).visitPricePiasters, 15000);
      expect(info.consultationBlockedReason, isNull);

      final doctor = SessionView.fromJson(sessionJson());
      expect(doctor.clinical!.vitals.tempC, 37.2);
      expect(doctor.hasPrivateNote, isTrue);
      expect(doctor.can.delete, isTrue);
      expect(doctor.paymentMethod, PaymentMethod.cash);

      final assistant = SessionView.fromJson(sessionJson(assistant: true));
      expect(assistant.clinical, isNull);
      expect(assistant.hasPrivateNote, isNull);
      expect(assistant.awaitingDoctor, isTrue);
      expect(assistant.recordedBy.isAssistant, isTrue);

      final day = DaySessions.fromJson({
        'day': '2026-11-15',
        'items': [
          {...sessionJson(), 'chiefComplaint': null, 'diagnosis': null},
        ],
        'totals': {'examinationCount': 1, 'consultationCount': 2, 'examinationFeePiasters': 3000, 'consultationFeePiasters': 3000, 'totalPiasters': 6000},
        'amountChargedTotalPiasters': null,
      });
      expect(day.items.single.type, SessionType.examination);
      expect(day.totals.totalPiasters, 6000);
      expect(day.amountChargedTotalPiasters, isNull);
    });

    test('the month keeps its days and branches', () {
      const totals = {'examinationCount': 1, 'consultationCount': 0, 'examinationFeePiasters': 3000, 'consultationFeePiasters': 0, 'totalPiasters': 3000};
      final month = MonthFees.fromJson({
        'month': '2026-11',
        'branchId': null,
        'totals': totals,
        'branches': [
          {'branchId': 'b1', 'nameAr': 'فرع المعادي', 'nameEn': null, 'totals': totals},
        ],
        'days': [
          {'day': '2026-11-01', 'totals': totals},
        ],
      });
      expect(month.month, DateTime.utc(2026, 11));
      expect(month.branches.single.name('en'), 'فرع المعادي');
      expect(month.days.single.day, DateTime.utc(2026, 11, 1));
    });

    test('drafts send what the API expects', () {
      final draft = const NewSessionDraft(
        patientId: 'p1',
        branchId: 'b1',
        type: SessionType.consultation,
        chiefComplaint: '  ',
        vitals: Vitals(tempC: 38.2),
        amountChargedPiasters: 0,
        paymentMethod: PaymentMethod.instapay,
      ).toJson();
      expect(draft, {
        'patientId': 'p1',
        'branchId': 'b1',
        'type': 'consultation',
        'vitals': {'tempC': 38.2},
        'amountChargedPiasters': 0,
        'paymentMethod': 'instapay',
      });

      final byAge = PatientDraft(fullName: 'سارة علي', gender: Gender.female, phone: '01012345678', ageYears: 29).toJson();
      expect(byAge['ageYears'], 29);
      expect(byAge['dateOfBirth'], isNull);
      final byDate =
          PatientDraft(fullName: 'سارة علي', gender: Gender.female, dateOfBirth: DateTime.utc(1997, 1, 2), ageYears: 29).toJson();
      expect(byDate['dateOfBirth'], '1997-01-02');
      expect(byDate['ageYears'], isNull, reason: 'never both');
      // BR-P3: linking sends the phone alone.
      expect(const PatientDraft.link('01122223333').toJson(), {'phone': '01122223333'});
    });
  });

  group('the consultation rule on the type cards (BR-S2, BR-S3, BR-S4)', () {
    test('a first visit offers only Examination', () {
      final rule = ConsultationRuleView.from(NewSessionInfo.fromJson(infoJson(firstVisit: true, since: 0, blocked: 'firstVisit')));
      expect(rule.offerConsultation, isFalse);
      expect(rule.allowedTypes, {SessionType.examination});
      expect(rule.showCount, isFalse);
    });

    test('after an examination and one consultation, both are allowed', () {
      final rule = ConsultationRuleView.from(NewSessionInfo.fromJson(infoJson(since: 1)));
      expect(rule.offerConsultation, isTrue);
      expect(rule.consultationEnabled, isTrue);
      expect(rule.allowedTypes, {SessionType.examination, SessionType.consultation});
      expect((rule.count, rule.max), (1, 2));
    });

    test('at the limit, Consultation is shown but closed', () {
      final rule = ConsultationRuleView.from(NewSessionInfo.fromJson(infoJson(since: 2, blocked: 'limitReached')));
      expect(rule.offerConsultation, isTrue);
      expect(rule.consultationEnabled, isFalse);
      expect(rule.block, ConsultationBlock.limitReached);
      expect(rule.allowedTypes, {SessionType.examination});
    });

    test('the BR-S4 message follows the setting', () {
      final ar = AppLocalizationsAr();
      final en = AppLocalizationsEn();
      expect(ar.sessionConsultationLimit(2), 'لا يمكن تسجيل أكثر من استشارتين متتاليتين. يجب تسجيل كشف أولاً.');
      expect(en.sessionConsultationLimit(2), 'This patient has had 2 consultations in a row. Record an examination first.');
      expect(en.sessionConsultationLimit(3), contains('3 consultations'));
      expect(ar.sessionConsultationLimit(1), contains('استشارة واحدة'));
      expect(ar.sessionConsultationCount(1, 2), 'استشارة 1 من 2 منذ آخر كشف');

      // And so does the error (the limit comes with it).
      const error = ApiException(
        kind: ApiErrorKind.http,
        status: 409,
        code: ApiCodes.consultationRequiresExam,
        details: {'reason': 'limitReached', 'consultationsSinceExam': 3, 'maxConsecutiveConsultations': 3},
      );
      expect(en.apiError(error), contains('3 consultations'));
    });
  });

  group('the amount charged (BR-S10)', () {
    final info = NewSessionInfo.fromJson(infoJson(consultPrice: null));

    test('defaults to the visit price, and is required without one', () {
      expect(AmountRules.defaultFor(info, SessionType.examination), 30000);
      expect(AmountRules.requiredFor(info, SessionType.examination), isFalse);
      expect(AmountRules.defaultFor(info, SessionType.consultation), isNull);
      expect(AmountRules.requiredFor(info, SessionType.consultation), isTrue);
      expect(AmountRules.text(30000), '300');
      expect(AmountRules.text(15050), '150.50');
      expect(AmountRules.text(null), '');
    });

    test('reads EGP as typed, Arabic digits too', () {
      expect(AmountRules.parse('250', required: false).piasters, 25000);
      expect(AmountRules.parse('150.5', required: false).piasters, 15050);
      expect(AmountRules.parse('٣٠٠', required: false).piasters, 30000);
      expect(AmountRules.parse('0', required: true).piasters, 0, reason: 'a free visit');
      expect(AmountRules.parse('', required: false), (piasters: null, problem: null));
      expect(AmountRules.parse('', required: true).problem, AmountProblem.required);
      expect(AmountRules.parse('12.345', required: false).problem, AmountProblem.invalid);
      expect(AmountRules.parse('100001', required: false).problem, AmountProblem.outOfRange);
    });
  });

  group('vitals', () {
    test('unusual values warn, impossible ones refuse', () {
      expect(VitalField.tempC.check(37), isNull);
      expect(VitalField.tempC.check(43.5), VitalProblem.unusual);
      expect(VitalField.tempC.check(46), VitalProblem.outOfRange);
      expect(VitalField.bpSys.check(270), VitalProblem.unusual);
      expect(VitalField.pulse.check(72.5), VitalProblem.invalid);

      final warned = readVitals({VitalField.bpSys: '270', VitalField.bpDia: '120', VitalField.tempC: '٣٧٫٤'});
      expect(warned.vitals, isNotNull);
      expect(warned.vitals!.tempC, 37.4);
      expect(warned.problems[VitalField.bpSys], VitalProblem.unusual);

      expect(readVitals({VitalField.tempC: '50'}).vitals, isNull);
    });

    test('blood pressure needs both values', () {
      final half = readVitals({VitalField.bpSys: '120'});
      expect(half.bpIncomplete, isTrue);
      expect(half.vitals, isNull);
      expect(readVitals(const {}).vitals!.isEmpty, isTrue);
    });
  });

  group('register query (D4)', () {
    test('sends only what is set, and the direction when it differs', () {
      expect(const RegisterQuery().toQuery(), isEmpty);
      final query = const RegisterQuery(
        search: ' منى ',
        lastVisit: LastVisitFilter.notSeen3m,
        branchId: 'b1',
        minVisits: 2,
        maxVisits: 4,
        newThisMonth: true,
        archived: true,
        hasChronicDisease: true,
        sort: RegisterSort.name,
      );
      expect(query.toQuery(), {
        'search': 'منى',
        'lastVisit': 'notSeen3m',
        'branchId': 'b1',
        'minVisits': 2,
        'maxVisits': 4,
        'newThisMonth': 'true',
        'archived': 'true',
        'hasChronicDisease': 'true',
        'sort': 'name',
      });
      expect(query.filterCount, 6);
      expect(const RegisterQuery(sort: RegisterSort.name, descending: true).toQuery()['direction'], 'desc');
      expect(const RegisterQuery(descending: true).toQuery().containsKey('direction'), isFalse);
      expect(query.withoutFilters().filterCount, 0);
      expect(query.withoutFilters().search, ' منى ');
    });

    test('the sorts follow the permissions', () {
      final reception = ClinicContext.fromJson(clinicJson());
      expect(availableSorts(reception), isNot(contains(RegisterSort.totalPaid)));
      expect(availableSorts(reception), isNot(contains(RegisterSort.allergies)));
      final doctor = ClinicContext.fromJson(clinicJson(assistant: false));
      expect(availableSorts(doctor), containsAll([RegisterSort.totalPaid, RegisterSort.allergies]));
    });
  });

  group('the offline clinic answers like the API', () {
    late FakeCaller caller;
    late FakeClinicRecords records;

    FakeCaller callerFor(String preset, {bool doctor = false, Set<String>? branches, bool suspended = false}) => FakeCaller(
          isDoctor: doctor,
          userId: doctor ? FakeClinicRecords.doctorUserId : 'assistant-$preset',
          name: 'سارة',
          permissions: doctor ? ClinicPermission.all.toSet() : AssistantPreset.permissions[preset]!,
          branchIds: doctor ? null : branches,
          suspended: suspended,
        );

    setUp(() {
      caller = callerFor('', doctor: true);
      records = FakeClinicRecords(caller: () => caller, delay: Duration.zero);
    });

    String id(String name) => records.patientIdByName(name);

    Future<Object?> failure(Future<Object?> Function() call) async {
      try {
        await call();
      } on ApiException catch (error) {
        return error;
      }
      return null;
    }

    test("today's fees: 2 examinations + 3 consultations = 105 EGP (AC-4)", () async {
      final summary = await records.feeSummary();
      expect(summary.today.examinationCount, 2);
      expect(summary.today.consultationCount, 3);
      expect(summary.today.totalPiasters, 10500);
      final day = await records.day();
      expect(day.items, hasLength(5));
      expect(day.items.where((s) => s.awaitingDoctor), hasLength(2));
    });

    test('the consultation rule: first visit, limit, and a reset after an examination (AC-1)', () async {
      final mona = id('منى حسن إبراهيم');
      const branch = FakeClinicRepository.maadiBranchId;
      final info = await records.newSessionInfo(patientId: mona, branchId: branch);
      expect(info.consultationBlockedReason, ConsultationBlock.limitReached);
      final error = await failure(
        () => records.createSession(NewSessionDraft(patientId: mona, branchId: branch, type: SessionType.consultation)),
      );
      expect((error! as ApiException).code, ApiCodes.consultationRequiresExam);
      expect((error as ApiException).details['reason'], 'limitReached');

      await records.createSession(NewSessionDraft(patientId: mona, branchId: branch, type: SessionType.examination));
      expect((await records.newSessionInfo(patientId: mona, branchId: branch)).consultationsSinceExam, 0);

      final sara = id('سارة علي مصطفى');
      final first = await failure(
        () => records.createSession(NewSessionDraft(patientId: sara, branchId: branch, type: SessionType.consultation)),
      );
      expect((first! as ApiException).details['reason'], 'firstVisit');

      // A lower limit applies to the next session (AC-1).
      records.maxConsecutiveConsultations = 1;
      final laila = await records.newSessionInfo(patientId: id('ليلى مصطفى كامل'), branchId: branch);
      expect(laila.consultationBlockedReason, ConsultationBlock.limitReached);
    });

    test('a reception assistant: amounts, allergies and clinical content are hidden', () async {
      caller = callerFor(AssistantPreset.reception, branches: {FakeClinicRepository.maadiBranchId});
      final register = await records.register(const RegisterQuery());
      expect(register.items.every((r) => r.totalPaidPiasters == null && r.hasAllergies == null && r.chronicDiseases == null), isTrue);

      final mona = id('منى حسن إبراهيم');
      final sessions = await records.patientSessions(mona);
      expect(sessions.items.every((s) => s.diagnosis == null && s.amountChargedPiasters == null), isTrue);
      final view = await records.session(sessions.items.last.sessionId);
      expect(view.clinical, isNull);
      expect(view.hasPrivateNote, isNull);
      expect(view.can.privateNote, isFalse);

      expect((await failure(() => records.medicalProfile(mona)))! as ApiException, isA<ApiException>());
      expect(((await failure(() => records.privateNote(view.sessionId)))! as ApiException).details['permission'], 'doctorOnly');

      // BR-AS5: no doctor-only field, even in createSession.
      final denied = await failure(() => records.createSession(NewSessionDraft(
            patientId: id('ليلى مصطفى كامل'),
            branchId: FakeClinicRepository.maadiBranchId,
            type: SessionType.examination,
            diagnosis: 'x',
          )));
      expect((denied! as ApiException).details['fields'], ['diagnosis']);

      // BR-AS13: only their branches.
      final day = await records.day();
      expect(day.items.every((s) => s.branch.id == FakeClinicRepository.maadiBranchId), isTrue);
      final otherBranch = await failure(() => records.newSessionInfo(patientId: mona, branchId: FakeClinicRepository.nasrCityBranchId));
      expect((otherBranch! as ApiException).code, ApiCodes.branchNotAllowed);
    });

    test("an assistant's session waits for the doctor until a clinical field is saved (BR-AS7)", () async {
      caller = callerFor(AssistantPreset.reception, branches: {FakeClinicRepository.maadiBranchId});
      final saved = await records.createSession(NewSessionDraft(
        patientId: id('ليلى مصطفى كامل'),
        branchId: FakeClinicRepository.maadiBranchId,
        type: SessionType.examination,
        chiefComplaint: 'صداع',
      ));
      expect(saved.awaitingDoctor, isTrue);
      expect(saved.amountChargedPiasters, 30000, reason: 'the recorder sees the amount');

      caller = callerFor('', doctor: true);
      final updated = await records.updateClinical(saved.sessionId, const ClinicalDraft(diagnosis: 'صداع توتري'));
      expect(updated.awaitingDoctor, isFalse);
    });

    test('BR-S7: only the latest session of today can be deleted, with a reason', () async {
      final mona = id('منى حسن إبراهيم');
      final ids = records.sessionIdsOf(mona);
      expect((await records.session(ids.first)).can.delete, isTrue);
      final older = await records.session(ids.last);
      expect(older.can.delete, isFalse);
      expect(older.can.deleteBlockedReason, DeleteBlock.notLatest);

      final noReason = await failure(() => records.deleteSession(ids.first, ' '));
      expect((noReason! as ApiException).fieldCodes['reason'], 'REASON_REQUIRED');
      final notLatest = await failure(() => records.deleteSession(ids.last, 'خطأ'));
      expect((notLatest! as ApiException).details['reason'], 'notLatest');

      await records.deleteSession(ids.first, 'سجلت للمريض الخطأ');
      expect((await records.feeSummary()).today.totalPiasters, 10500 - 1500);
      // The count is rebuilt: a consultation is allowed again.
      final info = await records.newSessionInfo(patientId: mona, branchId: FakeClinicRepository.maadiBranchId);
      expect(info.consultationAllowed, isTrue);
    });

    test('BR-P3: an existing number is linked, identity only', () async {
      final lookup = await records.lookupPhone('01122223333');
      expect(lookup.status, PhoneLookupStatus.existsElsewhere);
      final created = await records.createPatient(PatientDraft(fullName: 'x', gender: Gender.male, phone: '01122223333'));
      expect(created.linked, isTrue);
      expect(created.temporaryPassword, isNull);
      expect(created.patient.ownsDetails, isFalse);
      expect(created.patient.nationalId, isNull);

      final again = await failure(() => records.createPatient(PatientDraft(fullName: 'x', gender: Gender.male, phone: '+201122223333')));
      expect((again! as ApiException).code, ApiCodes.patientAlreadyLinked);
      expect((again as ApiException).details['patientId'], created.patient.patientId);
    });

    test('a suspended doctor can read but not add patients or sessions (BR-G5)', () async {
      caller = callerFor('', doctor: true, suspended: true);
      expect((await records.register(const RegisterQuery())).items, isNotEmpty);
      final add = await failure(
        () => records.createPatient(PatientDraft(fullName: 'سارة علي', gender: Gender.female, phone: '01011112222', ageYears: 3)),
      );
      expect((add! as ApiException).code, ApiCodes.doctorSuspended);
      final session = await failure(() => records.createSession(NewSessionDraft(
            patientId: id('ليلى مصطفى كامل'),
            branchId: FakeClinicRepository.maadiBranchId,
            type: SessionType.examination,
          )));
      expect((session! as ApiException).code, ApiCodes.doctorSuspended);
    });

    test('the register searches Arabic letter variants and filters', () async {
      // «احمد» finds «أحمد» (spec A.6).
      final ahmed = await records.register(const RegisterQuery(search: 'احمد'));
      expect(ahmed.items.map((r) => r.fullName), unorderedEquals(['أحمد محمود عبد الرحمن', 'فاطمة الزهراء أحمد']));
      expect((await records.register(const RegisterQuery(search: 'احمد محمود'))).items.single.fullName, 'أحمد محمود عبد الرحمن');
      expect((await records.register(const RegisterQuery(search: '01012345678'))).items.single.fullName, 'منى حسن إبراهيم');
      final never = await records.register(const RegisterQuery(lastVisit: LastVisitFilter.never));
      expect(never.items.map((r) => r.fullName), containsAll(['سارة علي مصطفى', 'خالد منصور عطية']));
      final archived = await records.register(const RegisterQuery(archived: true));
      expect(archived.items.single.fullName, 'عمرو شريف نبيل');
      final chronic = await records.register(const RegisterQuery(hasChronicDisease: true));
      expect(chronic.items, everyElement(predicate<PatientRegisterRow>((r) => r.chronicDiseases!.isNotEmpty)));
    });
  });
}
