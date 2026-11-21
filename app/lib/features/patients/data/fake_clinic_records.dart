import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/validation/egyptian_phone.dart';
import '../../../core/validation/validators.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/user_role.dart';
import '../../clinic/application/clinic_providers.dart';
import '../../clinic/data/clinic_repository.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../doctor_registration/domain/registration_rules.dart';
import '../../sessions/data/sessions_repository.dart';
import '../../sessions/domain/session_models.dart';
import '../domain/patient_models.dart';
import 'patients_repository.dart';

/// Who is calling the offline clinic, from the signed-in account and its
/// clinic (`FakeClinicRepository`).
class FakeCaller {
  const FakeCaller({
    required this.isDoctor,
    required this.userId,
    required this.name,
    required this.permissions,
    this.branchIds,
    this.suspended = false,
    this.freeTrial = false,
    this.trialEnded = false,
  });

  /// The doctor or assistant of [clinic]. Every offline doctor works on the
  /// same records, under [FakeClinicRecords.doctorUserId].
  factory FakeCaller.of(ClinicContext clinic, {required String userId}) => FakeCaller(
        isDoctor: clinic.isDoctor,
        userId: clinic.isDoctor ? FakeClinicRecords.doctorUserId : userId,
        name: clinic.isDoctor ? clinic.doctor.fullName : clinic.assistant?.fullName ?? '',
        permissions: clinic.permissions,
        branchIds: clinic.isDoctor ? null : {for (final b in clinic.workBranches) b.id},
        suspended: clinic.isSuspended,
        freeTrial: clinic.freeTrial,
        trialEnded: clinic.trial?.ended ?? false,
      );

  final bool isDoctor;
  final String userId;
  final String name;
  final Set<String> permissions;

  /// The assistant's branches (BR-AS13); null for the doctor (every branch).
  final Set<String>? branchIds;
  final bool suspended;

  /// The clinic's free trial is running: sessions carry no fee (BR-T3).
  final bool freeTrial;

  /// The trial ended: every clinic call answers TRIAL_ENDED (BR-T4).
  final bool trialEnded;

  bool can(String permission) => isDoctor || permissions.contains(permission);

  bool worksIn(String branchId) => branchIds == null || branchIds!.contains(branchId);
}

class _Account {
  _Account({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.gender,
    required this.dateOfBirth,
    this.estimated = false,
    this.nationalId,
    this.address,
    this.bloodType,
    this.emergencyName,
    this.emergencyPhone,
    this.ownedByUs = true,
  });

  final String id;
  String phone;
  String fullName;
  Gender gender;
  DateTime dateOfBirth;
  bool estimated;
  String? nationalId;
  String? address;
  String? bloodType;
  String? emergencyName;
  String? emergencyPhone;

  /// This clinic created the account (`ownsDetails`, BR-P3).
  final bool ownedByUs;

  /// `active`, `pendingDeletion` (D6's banner) or `deleted` (spec 6.17).
  String accountStatus = 'active';
}

class _Link {
  _Link({required this.patientId, required this.fileNumber, required this.linkedAt});

  final String patientId;
  final int fileNumber;
  final DateTime linkedAt;
  bool archived = false;
  DateTime? archivedAt;
  final lists = <ProfileList, List<ProfileItem>>{for (final l in ProfileList.values) l: []};
  String? familyHistory;
  String? notes;
}

class _Session {
  _Session({
    required this.id,
    required this.patientId,
    required this.type,
    required this.at,
    required this.branchId,
    required this.feePiasters,
    required this.recordedBy,
    this.listPricePiasters,
    this.amountPiasters,
    this.paymentMethod,
    this.awaitingDoctor = false,
  }) : updatedAt = at;

  final String id;
  final String patientId;
  final SessionType type;
  final DateTime at;
  final String branchId;
  final int feePiasters;
  final RecordedBy recordedBy;
  final int? listPricePiasters;
  int? amountPiasters;
  PaymentMethod? paymentMethod;
  bool awaitingDoctor;
  String? chiefComplaint;
  String? findings;
  Vitals vitals = const Vitals();
  String? diagnosis;
  String? patientNotes;
  DateTime? followUpDate;
  String? privateNote;
  DateTime? privateNoteAt;
  DateTime updatedAt;
  bool deleted = false;
}

/// The offline clinic records for `config/dev-offline.json` and tests: the
/// patients of the offline doctor (`doctor@el3yada.dev`, also seen by
/// `suspended@el3yada.dev` and the offline assistants), their medical
/// profiles and sessions, and accounts of other clinics to link (BR-P3).
///
/// It answers like the API (backend/docs/api-phase-2-patients.md): the
/// permission checks, the consultation rule (BR-S2, BR-S3), BR-S7, the
/// branch scope of assistants (BR-AS13) and the fields hidden by
/// permission, so widget tests through it mean something. Answers are built
/// as the API's JSON and read with the models' `fromJson`.
class FakeClinicRecords implements PatientsRepository, SessionsRepository {
  FakeClinicRecords({
    required this.caller,
    this.delay = const Duration(milliseconds: 250),
    DateTime Function()? now,
    this.maxConsecutiveConsultations = 2,
    this.examinationFeePiasters = 3000,
    this.consultationFeePiasters = 1500,
    Map<SessionType, int?>? doctorPrices,
    Map<String, Map<SessionType, int?>>? branchPrices,
    bool seed = true,
  })  : _now = now ?? DateTime.now,
        doctorPrices = doctorPrices ?? {SessionType.examination: 30000, SessionType.consultation: 15000},
        branchPrices = branchPrices ??
            {
              FakeClinicRepository.nasrCityBranchId: {SessionType.examination: 35000},
            } {
    if (seed) _seed();
  }

  /// The signed-in doctor or assistant, or null (the API answers 403).
  final FakeCaller? Function() caller;
  final Duration delay;
  final DateTime Function() _now;

  /// BR-S3 (admin setting).
  int maxConsecutiveConsultations;
  int examinationFeePiasters;
  int consultationFeePiasters;

  /// The doctor's visit prices (D37); a missing type has no price.
  final Map<SessionType, int?> doctorPrices;

  /// A branch's own prices; a type it doesn't set uses the doctor's.
  final Map<String, Map<SessionType, int?>> branchPrices;

  /// Unread chat messages per patient, the same for every caller with `chat` (D4's badge).
  final Map<String, int> unreadChats = {};

  /// The offline doctor's user ID on recorded sessions.
  static const doctorUserId = 'dev-doctor-user';
  static const doctorName = 'تجريبي';

  /// Numbers that already have a patient account in another clinic, to try
  /// the BR-P3 link: `01122223333` and the offline patient `01000000002`.
  static const elsewherePhones = ['+201122223333', '+201000000002'];

  final _accounts = <String, _Account>{};
  final _links = <String, _Link>{};
  final _sessions = <_Session>[];
  final _random = Random(7);
  int _nextId = 1;

  /// Every temporary password handed out, newest last (tests read it).
  final temporaryPasswords = <String>[];

  static const _branchNames = {
    FakeClinicRepository.maadiBranchId: ('فرع المعادي', 'Maadi'),
    FakeClinicRepository.nasrCityBranchId: ('فرع مدينة نصر', 'Nasr City'),
  };

  // ---------------------------------------------------------------------------
  // Patients

  @override
  Future<PhoneLookup> lookupPhone(String phone) async {
    await _wait();
    _require(ClinicPermission.patientsManage);
    final number = _mobile(phone);
    final account = _accountByPhone(number);
    if (account == null) return PhoneLookup.fromJson({'status': 'new'});
    final link = _links[account.id];
    if (link == null) return PhoneLookup.fromJson({'status': 'existsElsewhere'});
    return PhoneLookup.fromJson({
      'status': 'linkedToYou',
      'patientId': account.id,
      'fileNumber': link.fileNumber,
      'fullName': account.fullName,
      'archived': link.archived,
    });
  }

  @override
  Future<CreatedPatient> createPatient(PatientDraft draft) async {
    await _wait();
    final who = _require(ClinicPermission.patientsManage);
    _blockWhileSuspended(who);
    final number = _mobile(draft.phone ?? '');
    final existing = _accountByPhone(number);
    if (existing != null) {
      final link = _links[existing.id];
      if (link != null) {
        throw ApiException(
          kind: ApiErrorKind.http,
          status: 409,
          code: ApiCodes.patientAlreadyLinked,
          details: {'patientId': existing.id, 'fileNumber': link.fileNumber},
        );
      }
      _link(existing.id, _now());
      return CreatedPatient.fromJson({'linked': true, 'temporaryPassword': null, 'patient': _patientJson(existing.id, who)});
    }

    final identity = _identity(draft);
    final id = 'dev-patient-${_nextId++}';
    _accounts[id] = _Account(
      id: id,
      phone: number,
      fullName: identity.name,
      gender: draft.gender,
      dateOfBirth: identity.dateOfBirth,
      estimated: identity.estimated,
      nationalId: identity.nationalId,
      address: _clean(draft.address),
      bloodType: draft.bloodType,
      emergencyName: _clean(draft.emergencyContactName),
      emergencyPhone: identity.emergencyPhone,
    );
    _link(id, _now());
    final password = _password();
    return CreatedPatient.fromJson({'linked': false, 'temporaryPassword': password, 'patient': _patientJson(id, who)});
  }

  /// Spec 6.17, as the API answers it: the patient named [fullName] is in
  /// their deletion grace period (`pendingDeletion`, D6's banner) or erased
  /// (`deleted`, «مريض محذوف» without a number). For tests and demos.
  void setAccountStatus(String fullName, String status) {
    final account = _accounts[patientIdOf(fullName)]!;
    account.accountStatus = status;
    if (status == 'deleted') {
      account
        ..fullName = 'مريض محذوف'
        ..phone = '';
    }
  }

  /// The ID of the seeded patient named [fullName].
  String patientIdOf(String fullName) => _accounts.values.firstWhere((a) => a.fullName == fullName).id;

  @override
  Future<PatientView> patient(String patientId) async {
    await _wait();
    final who = _caller();
    _linkOf(patientId);
    return PatientView.fromJson(_patientJson(patientId, who));
  }

  @override
  Future<PatientView> updatePatient(String patientId, PatientDraft draft) async {
    await _wait();
    final who = _require(ClinicPermission.patientsManage);
    _linkOf(patientId);
    final account = _accounts[patientId]!;
    final identity = _identity(draft, keepEstimated: account);
    account
      ..fullName = identity.name
      ..gender = draft.gender
      ..dateOfBirth = identity.dateOfBirth
      ..estimated = identity.estimated;
    if (account.ownedByUs) {
      account
        ..nationalId = identity.nationalId
        ..address = _clean(draft.address)
        ..bloodType = draft.bloodType
        ..emergencyName = _clean(draft.emergencyContactName)
        ..emergencyPhone = identity.emergencyPhone;
    }
    return PatientView.fromJson(_patientJson(patientId, who));
  }

  @override
  Future<PatientView> updatePatientPhone(String patientId, String phone) async {
    await _wait();
    final who = _require(ClinicPermission.patientsManage);
    _linkOf(patientId);
    final number = _mobile(phone);
    final other = _accountByPhone(number);
    if (other != null && other.id != patientId) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: ApiCodes.patientPhoneTaken);
    }
    _accounts[patientId]!.phone = number;
    return PatientView.fromJson(_patientJson(patientId, who));
  }

  @override
  Future<String> resetPatientPassword(String patientId) async {
    await _wait();
    _require(ClinicPermission.patientsResetPassword);
    _linkOf(patientId);
    return _password();
  }

  @override
  Future<PatientView> setArchived(String patientId, {required bool archived}) async {
    await _wait();
    final who = _require(ClinicPermission.patientsManage);
    final link = _linkOf(patientId);
    link
      ..archived = archived
      ..archivedAt = archived ? _now().toUtc() : null;
    return PatientView.fromJson(_patientJson(patientId, who));
  }

  @override
  Future<MedicalProfile> medicalProfile(String patientId) async {
    await _wait();
    _require(ClinicPermission.clinicalView);
    return MedicalProfile.fromJson(_profileJson(_linkOf(patientId)));
  }

  @override
  Future<MedicalProfile> updateMedicalProfile(String patientId, MedicalProfileDraft draft) async {
    await _wait();
    final who = _require(ClinicPermission.clinicalView);
    if (!who.can(ClinicPermission.clinicalEditProfile)) _denied(ClinicPermission.clinicalEditProfile);
    final link = _linkOf(patientId);
    final errors = <String, String>{};
    final cleaned = <ProfileList, List<String>>{};
    for (final list in ProfileList.values) {
      final items = draft.list(list);
      if (items.length > 50) errors[list.name] = 'OUT_OF_RANGE';
      final seen = <String>{};
      final kept = <String>[];
      for (final (i, raw) in items.indexed) {
        final text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (text.isEmpty) {
          errors['${list.name}[$i]'] = 'REQUIRED';
        } else if (text.length > 200) {
          errors['${list.name}[$i]'] = 'TOO_LONG';
        } else if (seen.add(text.toLowerCase())) {
          kept.add(text);
        }
      }
      cleaned[list] = kept;
    }
    if ((draft.familyHistory?.length ?? 0) > 2000) errors['familyHistory'] = 'TOO_LONG';
    if ((draft.notes?.length ?? 0) > 2000) errors['notes'] = 'TOO_LONG';
    if (errors.isNotEmpty) _invalid(errors);

    for (final list in ProfileList.values) {
      final old = {for (final item in link.lists[list]!) item.text.toLowerCase(): item};
      link.lists[list] = [
        for (final text in cleaned[list]!) old[text.toLowerCase()] ?? ProfileItem(id: 'dev-item-${_nextId++}', text: text),
      ];
    }
    link
      ..familyHistory = _clean(draft.familyHistory)
      ..notes = _clean(draft.notes);
    return MedicalProfile.fromJson(_profileJson(link));
  }

  @override
  Future<Paged<PatientRegisterRow>> register(RegisterQuery query, {int page = 1, int pageSize = 25}) async {
    await _wait();
    final who = _caller();
    if ((query.hasChronicDisease || query.sort == RegisterSort.allergies) && !who.can(ClinicPermission.clinicalView)) {
      _denied(ClinicPermission.clinicalView);
    }
    if (query.sort == RegisterSort.totalPaid && !who.can(ClinicPermission.revenueView)) {
      _denied(ClinicPermission.revenueView);
    }
    if (query.sort == RegisterSort.unreadChat && !who.can(ClinicPermission.chat)) {
      _denied(ClinicPermission.chat);
    }
    if (query.search.length > 60) _invalid({'search': 'TOO_LONG'});

    final today = _today();
    final words = searchWords(query.search);
    final rows = <({_Account account, _Link link, _Visits visits})>[];
    for (final link in _links.values) {
      if (link.archived != query.archived) continue;
      final account = _accounts[link.patientId]!;
      final visits = _visits(link.patientId);
      if (!_matches(words, account, link)) continue;
      final last = visits.last;
      final lastDay = last == null ? null : _cairoDay(last.at);
      switch (query.lastVisit) {
        case null:
          break;
        case LastVisitFilter.thisWeek:
          final saturday = today.subtract(Duration(days: (today.weekday - DateTime.saturday) % 7));
          if (lastDay == null || lastDay.isBefore(saturday)) continue;
        case LastVisitFilter.thisMonth:
          if (lastDay == null || lastDay.year != today.year || lastDay.month != today.month) continue;
        case LastVisitFilter.notSeen3m || LastVisitFilter.notSeen6m || LastVisitFilter.notSeen12m:
          final months = switch (query.lastVisit!) { LastVisitFilter.notSeen3m => 3, LastVisitFilter.notSeen6m => 6, _ => 12 };
          final limit = DateTime.utc(today.year, today.month - months, today.day);
          if (lastDay == null || !lastDay.isBefore(limit)) continue;
        case LastVisitFilter.never:
          if (lastDay != null) continue;
      }
      if (query.branchId != null && !visits.sessions.any((s) => s.branchId == query.branchId)) continue;
      if (query.minVisits != null && visits.sessions.length < query.minVisits!) continue;
      if (query.maxVisits != null && visits.sessions.length > query.maxVisits!) continue;
      if (query.newThisMonth) {
        final linked = _cairoDay(link.linkedAt);
        if (linked.year != today.year || linked.month != today.month) continue;
      }
      if (query.hasChronicDisease && link.lists[ProfileList.chronicDiseases]!.isEmpty) continue;
      rows.add((account: account, link: link, visits: visits));
    }

    int compare(({_Account account, _Link link, _Visits visits}) a, ({_Account account, _Link link, _Visits visits}) b) =>
        switch (query.sort) {
          RegisterSort.lastVisit => a.visits.last!.at.compareTo(b.visits.last!.at),
          RegisterSort.fileNumber => a.link.fileNumber.compareTo(b.link.fileNumber),
          RegisterSort.name =>
            normalizeForSearch(a.account.fullName).compareTo(normalizeForSearch(b.account.fullName)),
          RegisterSort.phone => a.account.phone.compareTo(b.account.phone),
          RegisterSort.age => _age(a.account.dateOfBirth).compareTo(_age(b.account.dateOfBirth)),
          RegisterSort.gender => a.account.gender.name.compareTo(b.account.gender.name),
          RegisterSort.firstVisit => a.visits.first!.at.compareTo(b.visits.first!.at),
          RegisterSort.visits => a.visits.sessions.length.compareTo(b.visits.sessions.length),
          RegisterSort.examinations => a.visits.examinations.compareTo(b.visits.examinations),
          RegisterSort.consultations => a.visits.consultations.compareTo(b.visits.consultations),
          RegisterSort.files || RegisterSort.nextBooking || RegisterSort.noShows => 0,
          RegisterSort.linkedAt => a.link.linkedAt.compareTo(b.link.linkedAt),
          RegisterSort.totalPaid => a.visits.paid.compareTo(b.visits.paid),
          RegisterSort.allergies =>
            a.link.lists[ProfileList.allergies]!.length.compareTo(b.link.lists[ProfileList.allergies]!.length),
          RegisterSort.unreadChat => (unreadChats[a.account.id] ?? 0).compareTo(unreadChats[b.account.id] ?? 0),
        };

    final byVisit = query.sort == RegisterSort.lastVisit || query.sort == RegisterSort.firstVisit;
    rows.sort((a, b) {
      // Never-visited patients come last whichever way a visit sort goes.
      if (byVisit && (a.visits.last == null || b.visits.last == null)) {
        if (a.visits.last == null && b.visits.last == null) return a.link.fileNumber.compareTo(b.link.fileNumber);
        return a.visits.last == null ? 1 : -1;
      }
      var result = compare(a, b);
      if (query.isDescending) result = -result;
      return result != 0 ? result : a.link.fileNumber.compareTo(b.link.fileNumber);
    });

    final start = (page - 1) * pageSize;
    final pageRows = rows.skip(start).take(pageSize).toList();
    return Paged.fromJson({
      'items': [
        for (final row in pageRows)
          {
            'patientId': row.account.id,
            'fileNumber': row.link.fileNumber,
            'fullName': row.account.fullName,
            'phone': row.account.phone,
            'gender': row.account.gender.wire,
            'dateOfBirth': dayKey(row.account.dateOfBirth),
            'dateOfBirthEstimated': row.account.estimated,
            'ageYears': _age(row.account.dateOfBirth),
            'visits': _visitsJson(row.visits),
            'totalPaidPiasters': who.can(ClinicPermission.revenueView) ? row.visits.paid : null,
            'nextBooking': null,
            'noShowCount': 0,
            'filesCount': 0,
            'unreadChatCount': who.can(ClinicPermission.chat) ? unreadChats[row.account.id] ?? 0 : null,
            'hasAllergies': who.can(ClinicPermission.clinicalView) ? row.link.lists[ProfileList.allergies]!.isNotEmpty : null,
            'chronicDiseases': who.can(ClinicPermission.clinicalView)
                ? [for (final item in row.link.lists[ProfileList.chronicDiseases]!) item.text]
                : null,
            'archived': row.link.archived,
            'linkedAt': row.link.linkedAt.toUtc().toIso8601String(),
          },
      ],
      'page': page,
      'pageSize': pageSize,
      'totalCount': rows.length,
      'totalPages': (rows.length / pageSize).ceil(),
    }, PatientRegisterRow.fromJson);
  }

  /// The same file as the API (PatientsRegisterCsv): UTF-8 with a BOM, CRLF rows, money and clinical
  /// columns by permission. Doctor only.
  @override
  Future<Uint8List> exportRegister(RegisterQuery query, {required String language}) async {
    final who = _caller();
    if (!who.isDoctor) _denied('doctorOnly');
    final rows = (await register(query, pageSize: 100000)).items;
    final ar = language != 'en';
    String t(String arabic, String english) => ar ? arabic : english;
    String day(DateTime d) => dayKey(d);
    String cell(String value) {
      var v = value;
      if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
      return v.contains(RegExp('[,"\r\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
    }

    final revenue = who.can(ClinicPermission.revenueView);
    final clinical = who.can(ClinicPermission.clinicalView);
    final lines = <List<String>>[
      [
        t('رقم الملف', 'File number'), t('الاسم', 'Name'), t('الموبايل', 'Mobile'), t('النوع', 'Gender'), t('السن', 'Age'),
        t('أول زيارة', 'First visit'), t('آخر زيارة', 'Last visit'), t('نوع آخر زيارة', 'Last visit type'),
        t('فرع آخر زيارة', 'Last visit branch'), t('الزيارات', 'Visits'), t('كشف', 'Examinations'), t('استشارة', 'Consultations'),
        t('الحجز القادم', 'Next booking'), t('مرات الغياب', 'No-shows'), t('الملفات', 'Files'),
        if (revenue) t('إجمالي المدفوع (ج.م)', 'Total paid (EGP)'),
        if (clinical) ...[t('حساسية', 'Allergies'), t('أمراض مزمنة', 'Chronic diseases')],
        t('تاريخ الإضافة', 'Added on'),
      ],
      for (final r in rows)
        [
          '${r.fileNumber}',
          r.fullName,
          AppFormat.phone(r.phone),
          r.gender == Gender.female ? t('أنثى', 'Female') : t('ذكر', 'Male'),
          '${r.ageYears}',
          r.visits.firstVisitAt == null ? '' : day(_cairoDay(r.visits.firstVisitAt!)),
          r.visits.lastVisit == null ? '' : day(r.visits.lastVisit!.day),
          switch (r.visits.lastVisit?.type) {
            null => '',
            SessionType.consultation => t('استشارة', 'Consultation'),
            _ => t('كشف', 'Examination'),
          },
          r.visits.lastVisit?.branchName(ar ? 'ar' : 'en') ?? '',
          '${r.visits.total}',
          '${r.visits.examinations}',
          '${r.visits.consultations}',
          r.nextBooking == null ? '' : day(r.nextBooking!.date),
          '${r.noShowCount}',
          '${r.filesCount}',
          if (revenue) ((r.totalPaidPiasters ?? 0) / 100).toStringAsFixed(2),
          if (clinical) ...[
            (r.hasAllergies ?? false) ? t('نعم', 'Yes') : t('لا', 'No'),
            (r.chronicDiseases ?? const []).join(ar ? '، ' : '; '),
          ],
          day(_cairoDay(r.linkedAt)),
        ],
    ];
    final text = lines.map((line) => line.map(cell).join(',')).join('\r\n');
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$text\r\n')]);
  }

  // ---------------------------------------------------------------------------
  // Sessions

  @override
  Future<Paged<SessionListItem>> patientSessions(String patientId, {int page = 1, int pageSize = 25}) async {
    await _wait();
    final who = _caller();
    if (!who.can(ClinicPermission.sessionsCreate) && !who.can(ClinicPermission.clinicalView)) {
      _denied(ClinicPermission.sessionsCreate);
    }
    _linkOf(patientId);
    final sessions = _live().where((s) => s.patientId == patientId).toList()..sort((a, b) => b.at.compareTo(a.at));
    return Paged.fromJson({
      'items': [for (final s in sessions.skip((page - 1) * pageSize).take(pageSize)) _rowJson(s, who)],
      'page': page,
      'pageSize': pageSize,
      'totalCount': sessions.length,
      'totalPages': (sessions.length / pageSize).ceil(),
    }, SessionListItem.fromJson);
  }

  @override
  Future<NewSessionInfo> newSessionInfo({required String patientId, required String branchId}) async {
    await _wait();
    final who = _require(ClinicPermission.sessionsCreate);
    _checkBranch(who, branchId);
    _linkOf(patientId);
    final rule = _rule(patientId);
    final last = _visits(patientId).last;
    TypeOption option(SessionType type, {required bool allowed}) => TypeOption(
          allowed: allowed,
          platformFeePiasters: _fee(type, who),
          visitPricePiasters: _price(branchId, type),
          priceSource: branchPrices[branchId]?[type] != null ? 'branch' : (doctorPrices[type] != null ? 'doctor' : null),
        );
    final exam = option(SessionType.examination, allowed: true);
    final consult = option(SessionType.consultation, allowed: rule.reason == null);
    return NewSessionInfo.fromJson({
      'patientId': patientId,
      'branchId': branchId,
      'isFirstVisit': rule.firstVisit,
      'lastSession': last == null ? null : _lastVisitJson(last),
      'consultationsSinceExam': rule.count,
      'maxConsecutiveConsultations': maxConsecutiveConsultations,
      'consultationAllowed': rule.reason == null,
      'consultationBlockedReason': rule.reason,
      'examination': _optionJson(exam),
      'consultation': _optionJson(consult),
    });
  }

  @override
  Future<SessionView> createSession(NewSessionDraft draft) async {
    await _wait();
    final who = _require(ClinicPermission.sessionsCreate);
    _blockWhileSuspended(who);
    _checkSessionFields(draft);
    if (!who.isDoctor) {
      final fields = [
        if (_clean(draft.findings) != null) 'findings',
        if (_clean(draft.diagnosis) != null) 'diagnosis',
        if (_clean(draft.patientNotes) != null) 'patientNotes',
        if (_clean(draft.privateNote) != null) 'privateNote',
        if (draft.followUpDate != null) 'followUpDate',
      ];
      if (fields.isNotEmpty) {
        throw ApiException(
          kind: ApiErrorKind.http,
          status: 403,
          code: ApiCodes.permissionDenied,
          details: {'permission': 'doctorOnly', 'fields': fields},
        );
      }
    }
    _checkBranch(who, draft.branchId);
    if (!_links.containsKey(draft.patientId)) {
      throw const ApiException(kind: ApiErrorKind.http, status: 404, code: ApiCodes.notLinked);
    }
    if (draft.type == SessionType.consultation) {
      final rule = _rule(draft.patientId);
      if (rule.reason != null) {
        throw ApiException(
          kind: ApiErrorKind.http,
          status: 409,
          code: ApiCodes.consultationRequiresExam,
          details: {
            'reason': rule.reason,
            'consultationsSinceExam': rule.count,
            'maxConsecutiveConsultations': maxConsecutiveConsultations,
          },
        );
      }
    }
    final price = _price(draft.branchId, draft.type);
    final amount = draft.amountChargedPiasters ?? price;
    if (amount == null) _invalid({'amountChargedPiasters': 'AMOUNT_REQUIRED'});

    final session = _Session(
      id: 'dev-session-${_nextId++}',
      patientId: draft.patientId,
      type: draft.type,
      at: _now().toUtc(),
      branchId: draft.branchId,
      feePiasters: _fee(draft.type, who),
      listPricePiasters: price,
      amountPiasters: amount,
      paymentMethod: draft.paymentMethod,
      recordedBy: RecordedBy(userId: who.userId, name: who.name, isAssistant: !who.isDoctor),
      awaitingDoctor: !who.isDoctor,
    )
      ..chiefComplaint = _clean(draft.chiefComplaint)
      ..vitals = draft.vitals
      ..findings = _clean(draft.findings)
      ..diagnosis = _clean(draft.diagnosis)
      ..patientNotes = _clean(draft.patientNotes)
      ..followUpDate = draft.followUpDate
      ..privateNote = _clean(draft.privateNote);
    if (session.privateNote != null) session.privateNoteAt = session.at;
    _sessions.add(session);
    // Recording a session for an archived patient unarchives them.
    _links[draft.patientId]!
      ..archived = false
      ..archivedAt = null;
    return SessionView.fromJson(_sessionJson(session, who));
  }

  @override
  Future<SessionView> session(String sessionId) async {
    await _wait();
    final who = _caller();
    _requireSessionView(who);
    return SessionView.fromJson(_sessionJson(_sessionOf(sessionId), who));
  }

  @override
  Future<PrivateNote> privateNote(String sessionId) async {
    await _wait();
    final who = _caller();
    if (!who.isDoctor) _denied('doctorOnly');
    final session = _sessionOf(sessionId);
    return PrivateNote.fromJson(_noteJson(session));
  }

  @override
  Future<PrivateNote> setPrivateNote(String sessionId, String? text) async {
    await _wait();
    final who = _caller();
    if (!who.isDoctor) _denied('doctorOnly');
    if ((text?.length ?? 0) > 10000) _invalid({'text': 'TOO_LONG'});
    final session = _sessionOf(sessionId);
    session
      ..privateNote = _clean(text)
      ..privateNoteAt = _clean(text) == null ? null : _now().toUtc();
    return PrivateNote.fromJson(_noteJson(session));
  }

  @override
  Future<SessionView> updateClinical(String sessionId, ClinicalDraft draft) async {
    await _wait();
    final who = _caller();
    if (!who.isDoctor) _denied('doctorOnly');
    final session = _sessionOf(sessionId);
    if (draft.followUpDate != null) {
      final from = _cairoDay(session.at);
      if (draft.followUpDate!.isBefore(from) || draft.followUpDate!.isAfter(DateTime.utc(from.year + 2, from.month, from.day))) {
        _invalid({'followUpDate': 'OUT_OF_RANGE'});
      }
    }
    session
      ..chiefComplaint = _clean(draft.chiefComplaint)
      ..findings = _clean(draft.findings)
      ..vitals = draft.vitals
      ..diagnosis = _clean(draft.diagnosis)
      ..patientNotes = _clean(draft.patientNotes)
      ..followUpDate = draft.followUpDate
      ..updatedAt = _now().toUtc();
    if (!draft.isEmpty) session.awaitingDoctor = false;
    return SessionView.fromJson(_sessionJson(session, who));
  }

  @override
  Future<SessionView> updateAmountCharged(String sessionId, {required int amountChargedPiasters, PaymentMethod? paymentMethod}) async {
    await _wait();
    final who = _caller();
    final session = _sessionOf(sessionId);
    if (!who.isDoctor) {
      if (!who.can(ClinicPermission.sessionsCreate)) _denied(ClinicPermission.sessionsCreate);
      if (session.recordedBy.userId != who.userId) _denied('doctorOnly');
    }
    if (amountChargedPiasters < 0 || amountChargedPiasters > 10000000) _invalid({'amountChargedPiasters': 'OUT_OF_RANGE'});
    if (_cairoDay(session.at) != _today()) {
      throw const ApiException(kind: ApiErrorKind.http, status: 409, code: ApiCodes.amountNotEditable);
    }
    session
      ..amountPiasters = amountChargedPiasters
      ..paymentMethod = paymentMethod
      ..updatedAt = _now().toUtc();
    return SessionView.fromJson(_sessionJson(session, who));
  }

  @override
  Future<void> deleteSession(String sessionId, String reason) async {
    await _wait();
    final who = _require(ClinicPermission.sessionsDelete);
    final text = reason.trim();
    if (text.length < 3) _invalid({'reason': 'REASON_REQUIRED'});
    if (text.length > 500) _invalid({'reason': 'TOO_LONG'});
    final session = _sessionOf(sessionId);
    _checkBranch(who, session.branchId);
    final block = _deleteBlock(session);
    if (block != null) {
      throw ApiException(
        kind: ApiErrorKind.http,
        status: 409,
        code: ApiCodes.sessionNotDeletable,
        details: {'reason': block},
      );
    }
    session.deleted = true;
  }

  @override
  Future<DaySessions> day({DateTime? day, String? branchId, SessionType? type, String? recordedBy}) async {
    await _wait();
    final who = _caller();
    if (!who.can(ClinicPermission.sessionsCreate) && !who.can(ClinicPermission.billingView)) {
      _denied(ClinicPermission.sessionsCreate);
    }
    if (branchId != null) _checkBranch(who, branchId);
    final target = day ?? _today();
    final rows = _live()
        .where((s) =>
            _cairoDay(s.at) == target &&
            who.worksIn(s.branchId) &&
            (branchId == null || s.branchId == branchId) &&
            (type == null || s.type == type) &&
            (recordedBy == null || s.recordedBy.userId == recordedBy))
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    var totals = FeeTotals.zero;
    var amount = 0;
    for (final s in rows) {
      totals = totals.add(s.type, s.feePiasters);
      amount += s.amountPiasters ?? 0;
    }
    return DaySessions.fromJson({
      'day': dayKey(target),
      'items': [for (final s in rows) _rowJson(s, who)],
      'totals': totals.toJson(),
      'amountChargedTotalPiasters': who.can(ClinicPermission.revenueView) ? amount : null,
    });
  }

  @override
  Future<FeeSummary> feeSummary() async {
    await _wait();
    _require(ClinicPermission.billingView);
    final today = _today();
    var day = FeeTotals.zero;
    var month = FeeTotals.zero;
    for (final s in _live()) {
      final d = _cairoDay(s.at);
      if (d.year == today.year && d.month == today.month) month = month.add(s.type, s.feePiasters);
      if (d == today) day = day.add(s.type, s.feePiasters);
    }
    return FeeSummary.fromJson({
      'day': dayKey(today),
      'month': monthKey(today),
      'today': day.toJson(),
      'thisMonth': month.toJson(),
    });
  }

  @override
  Future<MonthFees> month({DateTime? month, String? branchId}) async {
    await _wait();
    _require(ClinicPermission.billingView);
    if (branchId != null && !_branchNames.containsKey(branchId)) _notFound();
    final today = _today();
    final first = month == null ? DateTime.utc(today.year, today.month) : DateTime.utc(month.year, month.month);
    final next = DateTime.utc(first.year, first.month + 1);
    final inMonth = _live().where((s) {
      final d = _cairoDay(s.at);
      return !d.isBefore(first) && d.isBefore(next);
    }).toList();
    var totals = FeeTotals.zero;
    final perBranch = <String, FeeTotals>{};
    final perDay = <DateTime, FeeTotals>{};
    for (final s in inMonth) {
      perBranch[s.branchId] = (perBranch[s.branchId] ?? FeeTotals.zero).add(s.type, s.feePiasters);
      if (branchId != null && s.branchId != branchId) continue;
      totals = totals.add(s.type, s.feePiasters);
      final d = _cairoDay(s.at);
      perDay[d] = (perDay[d] ?? FeeTotals.zero).add(s.type, s.feePiasters);
    }
    final lastDay = first.isAfter(today) ? null : (next.isAfter(today) ? today : next.subtract(const Duration(days: 1)));
    final days = <Map<String, Object?>>[];
    if (lastDay != null) {
      for (var d = first; !d.isAfter(lastDay); d = d.add(const Duration(days: 1))) {
        days.add({'day': dayKey(d), 'totals': (perDay[d] ?? FeeTotals.zero).toJson()});
      }
    }
    final branchIds = perBranch.keys.toList()
      ..sort((a, b) => a == FakeClinicRepository.maadiBranchId ? -1 : (b == FakeClinicRepository.maadiBranchId ? 1 : a.compareTo(b)));
    return MonthFees.fromJson({
      'month': monthKey(first),
      'branchId': branchId,
      'totals': totals.toJson(),
      'branches': [
        for (final id in branchIds)
          if (branchId == null || id == branchId)
            {'branchId': id, 'nameAr': _branchNames[id]!.$1, 'nameEn': _branchNames[id]!.$2, 'totals': perBranch[id]!.toJson()},
      ],
      'days': days,
    });
  }

  // ---------------------------------------------------------------------------
  // Test helpers

  /// Records a session as [recorder] without the checks (tests and seeding).
  /// [daysAgo] 0 is today.
  String addSession(
    String patientId,
    SessionType type, {
    int daysAgo = 0,
    String branchId = FakeClinicRepository.maadiBranchId,
    RecordedBy? recorder,
  }) {
    final session = _Session(
      id: 'dev-session-${_nextId++}',
      patientId: patientId,
      type: type,
      at: _timeOn(daysAgo, _sessions.length),
      branchId: branchId,
      feePiasters: _fee(type),
      listPricePiasters: _price(branchId, type),
      amountPiasters: _price(branchId, type),
      recordedBy: recorder ?? const RecordedBy(userId: doctorUserId, name: doctorName, isAssistant: false),
      awaitingDoctor: recorder?.isAssistant ?? false,
    );
    _sessions.add(session);
    return session.id;
  }

  /// A patient by name (tests).
  String patientIdByName(String fullName) => _accounts.values.firstWhere((a) => a.fullName == fullName).id;

  /// Whether [patientId] is one of this clinic's patients (the offline
  /// medical files check it, like the API's link check).
  bool hasPatient(String patientId) => _links.containsKey(patientId);

  /// Whether [sessionId] is one of [patientId]'s live sessions.
  bool hasSession(String patientId, String sessionId) =>
      _live().any((s) => s.id == sessionId && s.patientId == patientId);

  /// A live session's type and time, for a record's visit link.
  ({SessionType type, DateTime at})? sessionInfo(String sessionId) {
    for (final s in _live()) {
      if (s.id == sessionId) return (type: s.type, at: s.at);
    }
    return null;
  }

  /// A live session's patient, Cairo day, type, branch, diagnosis and
  /// follow-up, for the offline prescriptions (BR-RX1), or null.
  ({String patientId, DateTime day, SessionType type, String branchId, String? diagnosis, DateTime? followUpDate})?
      sessionBasics(String sessionId) {
    for (final s in _live()) {
      if (s.id == sessionId) {
        return (
          patientId: s.patientId,
          day: _cairoDay(s.at),
          type: s.type,
          branchId: s.branchId,
          diagnosis: s.diagnosis,
          followUpDate: s.followUpDate,
        );
      }
    }
    return null;
  }

  /// A patient's live sessions, newest first (tests).
  List<String> sessionIdsOf(String patientId) {
    final sessions = _live().where((s) => s.patientId == patientId).toList()..sort((a, b) => b.at.compareTo(a.at));
    return [for (final s in sessions) s.id];
  }

  /// The offline reception assistant (`+201000000001`) as a recorder.
  static RecordedBy get receptionAssistant {
    final session = FakeAuthRepository.accounts['+201000000001']!.session('+201000000001');
    return RecordedBy(userId: session.userId, name: session.displayName, isAssistant: true);
  }

  // ---------------------------------------------------------------------------
  // Rules

  /// BR-S2, BR-S3: the consultations in a row since the last examination,
  /// and why a consultation is refused now (null when allowed).
  ({bool firstVisit, int count, String? reason}) _rule(String patientId) {
    final sessions = _live().where((s) => s.patientId == patientId).toList()..sort((a, b) => a.at.compareTo(b.at));
    final hasExam = sessions.any((s) => s.type == SessionType.examination);
    var count = 0;
    for (final s in sessions.reversed) {
      if (s.type == SessionType.examination) break;
      count++;
    }
    final reason = !hasExam ? 'firstVisit' : (count >= maxConsecutiveConsultations ? 'limitReached' : null);
    return (firstVisit: !hasExam, count: count, reason: reason);
  }

  /// BR-S7: why [session] can't be deleted, or null.
  String? _deleteBlock(_Session session) {
    final latest = _live().where((s) => s.patientId == session.patientId).reduce((a, b) => a.at.isAfter(b.at) ? a : b);
    if (latest.id != session.id) return 'notLatest';
    if (_cairoDay(session.at) != _today()) return 'notSameDay';
    return null;
  }

  int _fee(SessionType type, [FakeCaller? who]) => who?.freeTrial ?? false
      ? 0
      : type == SessionType.examination
          ? examinationFeePiasters
          : consultationFeePiasters;

  int? _price(String branchId, SessionType type) => branchPrices[branchId]?[type] ?? doctorPrices[type];

  // ---------------------------------------------------------------------------
  // Checks

  FakeCaller _caller() {
    final who = caller();
    if (who == null) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.forbidden);
    if (who.trialEnded) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.trialEnded);
    return who;
  }

  FakeCaller _require(String permission) {
    final who = _caller();
    if (!who.can(permission)) _denied(permission);
    return who;
  }

  void _requireSessionView(FakeCaller who) {
    if (!who.can(ClinicPermission.sessionsCreate) &&
        !who.can(ClinicPermission.clinicalView) &&
        !who.can(ClinicPermission.billingView)) {
      _denied(ClinicPermission.sessionsCreate);
    }
  }

  void _blockWhileSuspended(FakeCaller who) {
    if (who.suspended) throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.doctorSuspended);
  }

  void _checkBranch(FakeCaller who, String branchId) {
    if (!_branchNames.containsKey(branchId)) _notFound();
    if (!who.worksIn(branchId)) {
      throw const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.branchNotAllowed);
    }
  }

  Never _denied(String permission) => throw ApiException(
        kind: ApiErrorKind.http,
        status: 403,
        code: ApiCodes.permissionDenied,
        details: {'permission': permission},
      );

  Never _notFound() => throw const ApiException(kind: ApiErrorKind.http, status: 404, code: ApiCodes.notFound);

  Never _invalid(Map<String, String> fields) =>
      throw ApiException(kind: ApiErrorKind.http, status: 400, code: ApiCodes.validationFailed, fieldCodes: fields);

  _Link _linkOf(String patientId) => _links[patientId] ?? _notFound();

  _Session _sessionOf(String sessionId) {
    for (final s in _sessions) {
      if (s.id == sessionId && !s.deleted) return s;
    }
    _notFound();
  }

  String _mobile(String phone) {
    if (phone.trim().isEmpty) _invalid({'phone': 'REQUIRED'});
    return Validators.normalizeEgyptianMobile(phone) ?? _invalid({'phone': 'INVALID_MOBILE'});
  }

  ({String name, DateTime dateOfBirth, bool estimated, String? nationalId, String? emergencyPhone}) _identity(
    PatientDraft draft, {
    _Account? keepEstimated,
  }) {
    final errors = <String, String>{};
    final name = RegistrationRules.collapseSpaces(draft.fullName);
    if (name.isEmpty) {
      errors['fullName'] = 'REQUIRED';
    } else if (!RegistrationRules.isFullName(name)) {
      errors['fullName'] = 'INVALID_NAME';
    }
    final today = _today();
    DateTime? dateOfBirth;
    var estimated = false;
    if (draft.dateOfBirth != null) {
      dateOfBirth = draft.dateOfBirth;
      if (dateOfBirth!.isAfter(today) || dateOfBirth.isBefore(DateTime.utc(today.year - 120, today.month, today.day))) {
        errors['dateOfBirth'] = 'INVALID_DATE_OF_BIRTH';
      }
    } else if (draft.ageYears != null) {
      if (draft.ageYears! < 0 || draft.ageYears! > 120) {
        errors['ageYears'] = 'OUT_OF_RANGE';
      } else if (keepEstimated != null && keepEstimated.estimated && _age(keepEstimated.dateOfBirth) == draft.ageYears) {
        dateOfBirth = keepEstimated.dateOfBirth;
        estimated = true;
      } else {
        dateOfBirth = DateTime.utc(today.year - draft.ageYears!, today.month, today.day);
        estimated = true;
      }
    } else {
      errors['dateOfBirth'] = 'REQUIRED';
    }
    String? nationalId;
    final idText = draft.nationalId?.replaceAll(' ', '');
    if (idText != null && idText.isNotEmpty) {
      nationalId = Validators.normalizeDigits(idText);
      if (!RegExp(r'^\d{14}$').hasMatch(nationalId)) errors['nationalId'] = 'INVALID_NATIONAL_ID';
    }
    String? emergencyPhone;
    final emergency = draft.emergencyContactPhone?.trim();
    if (emergency != null && emergency.isNotEmpty) {
      emergencyPhone = EgyptianPhone.normalize(emergency);
      if (emergencyPhone == null) errors['emergencyContactPhone'] = 'INVALID_PHONE';
    }
    if ((draft.address?.length ?? 0) > 300) errors['address'] = 'TOO_LONG';
    if ((draft.emergencyContactName?.length ?? 0) > 60) errors['emergencyContactName'] = 'TOO_LONG';
    if (errors.isNotEmpty) _invalid(errors);
    return (name: name, dateOfBirth: dateOfBirth!, estimated: estimated, nationalId: nationalId, emergencyPhone: emergencyPhone);
  }

  void _checkSessionFields(NewSessionDraft draft) {
    final errors = <String, String>{};
    if ((draft.chiefComplaint?.length ?? 0) > 1000) errors['chiefComplaint'] = 'TOO_LONG';
    if ((draft.diagnosis?.length ?? 0) > 1000) errors['diagnosis'] = 'TOO_LONG';
    if ((draft.findings?.length ?? 0) > 10000) errors['findings'] = 'TOO_LONG';
    if ((draft.patientNotes?.length ?? 0) > 10000) errors['patientNotes'] = 'TOO_LONG';
    if ((draft.privateNote?.length ?? 0) > 10000) errors['privateNote'] = 'TOO_LONG';
    final amount = draft.amountChargedPiasters;
    if (amount != null && (amount < 0 || amount > 10000000)) errors['amountChargedPiasters'] = 'OUT_OF_RANGE';
    if (draft.followUpDate != null) {
      final today = _today();
      if (draft.followUpDate!.isBefore(today) || draft.followUpDate!.isAfter(DateTime.utc(today.year + 2, today.month, today.day))) {
        errors['followUpDate'] = 'OUT_OF_RANGE';
      }
    }
    if ((draft.vitals.bpSys == null) != (draft.vitals.bpDia == null)) errors['vitals.bpDia'] = 'INVALID_VALUE';
    if (errors.isNotEmpty) _invalid(errors);
  }

  // ---------------------------------------------------------------------------
  // Views

  Map<String, Object?> _patientJson(String patientId, FakeCaller who) {
    final account = _accounts[patientId]!;
    final link = _links[patientId]!;
    final visits = _visits(patientId);
    final details = account.ownedByUs;
    return {
      'patientId': patientId,
      'fileNumber': link.fileNumber,
      'fullName': account.fullName,
      'phone': account.phone,
      'gender': account.gender.wire,
      'dateOfBirth': dayKey(account.dateOfBirth),
      'dateOfBirthEstimated': account.estimated,
      'ageYears': _age(account.dateOfBirth),
      'nationalId': details ? account.nationalId : null,
      'address': details ? account.address : null,
      'bloodType': details ? account.bloodType : null,
      'emergencyContactName': details ? account.emergencyName : null,
      'emergencyContactPhone': details ? account.emergencyPhone : null,
      'ownsDetails': details,
      'accountStatus': account.accountStatus,
      'archived': link.archived,
      'archivedAt': link.archivedAt?.toIso8601String(),
      'linkedAt': link.linkedAt.toUtc().toIso8601String(),
      'visits': _visitsJson(visits),
      'totalPaidPiasters': who.can(ClinicPermission.revenueView) ? visits.paid : null,
      'hasAllergies': who.can(ClinicPermission.clinicalView) ? link.lists[ProfileList.allergies]!.isNotEmpty : null,
      'files': {'prescription': 0, 'lab': 0, 'radiology': 0, 'other': 0, 'total': 0},
      'prescriptionCount': 0,
      'nextBooking': null,
      'noShowCount': 0,
    };
  }

  Map<String, Object?> _profileJson(_Link link) => {
        'patientId': link.patientId,
        'hasAllergies': link.lists[ProfileList.allergies]!.isNotEmpty,
        for (final list in ProfileList.values)
          list.name: [for (final item in link.lists[list]!) {'id': item.id, 'text': item.text}],
        'familyHistory': link.familyHistory,
        'notes': link.notes,
      };

  Map<String, Object?> _visitsJson(_Visits visits) => {
        'firstVisitAt': visits.first?.at.toIso8601String(),
        'lastVisit': visits.last == null ? null : _lastVisitJson(visits.last!),
        'total': visits.sessions.length,
        'examinations': visits.examinations,
        'consultations': visits.consultations,
        'consultationsSinceExam': _rule(visits.patientId).count,
      };

  Map<String, Object?> _lastVisitJson(_Session s) => {
        'sessionId': s.id,
        'at': s.at.toIso8601String(),
        'day': dayKey(_cairoDay(s.at)),
        'daysAgo': _today().difference(_cairoDay(s.at)).inDays,
        'type': s.type.wire,
        'branchId': s.branchId,
        'branchNameAr': _branchNames[s.branchId]!.$1,
        'branchNameEn': _branchNames[s.branchId]!.$2,
      };

  Map<String, Object?> _optionJson(TypeOption option) => {
        'allowed': option.allowed,
        'platformFeePiasters': option.platformFeePiasters,
        'visitPricePiasters': option.visitPricePiasters,
        'priceSource': option.priceSource,
      };

  Map<String, Object?> _branchJson(String id) =>
      {'id': id, 'nameAr': _branchNames[id]!.$1, 'nameEn': _branchNames[id]!.$2};

  bool _seesAmount(_Session s, FakeCaller who) => who.can(ClinicPermission.revenueView) || s.recordedBy.userId == who.userId;

  Map<String, Object?> _rowJson(_Session s, FakeCaller who) {
    final account = _accounts[s.patientId]!;
    final clinical = who.can(ClinicPermission.clinicalView);
    return {
      'sessionId': s.id,
      'at': s.at.toIso8601String(),
      'day': dayKey(_cairoDay(s.at)),
      'type': s.type.wire,
      'patientId': s.patientId,
      'fileNumber': _links[s.patientId]!.fileNumber,
      'patientName': account.fullName,
      'branch': _branchJson(s.branchId),
      'platformFeePiasters': s.feePiasters,
      'amountChargedPiasters': _seesAmount(s, who) ? s.amountPiasters : null,
      'paymentMethod': _seesAmount(s, who) ? s.paymentMethod?.wire : null,
      'recordedBy': s.recordedBy.toJson(),
      'awaitingDoctor': s.awaitingDoctor,
      'chiefComplaint': clinical ? s.chiefComplaint : null,
      'diagnosis': clinical ? s.diagnosis : null,
    };
  }

  Map<String, Object?> _sessionJson(_Session s, FakeCaller who) {
    final sameDay = _cairoDay(s.at) == _today();
    final block = _deleteBlock(s);
    final amount = _seesAmount(s, who);
    return {
      'sessionId': s.id,
      'patientId': s.patientId,
      'fileNumber': _links[s.patientId]!.fileNumber,
      'patientName': _accounts[s.patientId]!.fullName,
      'type': s.type.wire,
      'at': s.at.toIso8601String(),
      'day': dayKey(_cairoDay(s.at)),
      'branch': _branchJson(s.branchId),
      'platformFeePiasters': s.feePiasters,
      'amountChargedPiasters': amount ? s.amountPiasters : null,
      'listPricePiasters': amount ? s.listPricePiasters : null,
      'paymentMethod': amount ? s.paymentMethod?.wire : null,
      'recordedBy': s.recordedBy.toJson(),
      'awaitingDoctor': s.awaitingDoctor,
      'clinical': who.can(ClinicPermission.clinicalView)
          ? {
              'chiefComplaint': s.chiefComplaint,
              'findings': s.findings,
              'vitals': {
                'bpSys': s.vitals.bpSys,
                'bpDia': s.vitals.bpDia,
                'pulse': s.vitals.pulse,
                'tempC': s.vitals.tempC,
                'weightKg': s.vitals.weightKg,
                'heightCm': s.vitals.heightCm,
                'glucose': s.vitals.glucose,
              },
              'diagnosis': s.diagnosis,
              'patientNotes': s.patientNotes,
              'followUpDate': s.followUpDate == null ? null : dayKey(s.followUpDate!),
            }
          : null,
      'hasPrivateNote': who.isDoctor ? s.privateNote != null : null,
      'can': {
        'editClinical': who.isDoctor,
        'editAmount': sameDay && (who.isDoctor || (s.recordedBy.userId == who.userId && who.can(ClinicPermission.sessionsCreate))),
        'delete': who.can(ClinicPermission.sessionsDelete) && who.worksIn(s.branchId) && block == null,
        'deleteBlockedReason': block,
        'privateNote': who.isDoctor,
      },
      'updatedAt': s.updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> _noteJson(_Session s) =>
      {'sessionId': s.id, 'text': s.privateNote, 'updatedAt': s.privateNoteAt?.toIso8601String()};

  // ---------------------------------------------------------------------------
  // Helpers

  Iterable<_Session> _live() => _sessions.where((s) => !s.deleted);

  _Visits _visits(String patientId) {
    final sessions = _live().where((s) => s.patientId == patientId).toList()..sort((a, b) => a.at.compareTo(b.at));
    return _Visits(patientId, sessions);
  }

  bool _matches(List<String> words, _Account account, _Link link) {
    if (words.isEmpty) return true;
    final name = normalizeForSearch(account.fullName);
    final phone = account.phone.replaceAll('+20', '0');
    for (final word in words) {
      final digits = RegExp(r'^\d+$').hasMatch(word);
      final ok = digits
          ? phone.contains(word) || account.phone.contains(word) || '${link.fileNumber}' == word
          : name.split(' ').any((part) => part.startsWith(word)) || name.contains(word);
      if (!ok) return false;
    }
    return true;
  }

  _Account? _accountByPhone(String phone) {
    for (final account in _accounts.values) {
      if (account.phone == phone) return account;
    }
    return null;
  }

  void _link(String patientId, DateTime at) {
    final next = _links.values.fold(0, (max, l) => l.fileNumber > max ? l.fileNumber : max) + 1;
    _links[patientId] = _Link(patientId: patientId, fileNumber: next, linkedAt: at.toUtc());
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _password() {
    const letters = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final password = String.fromCharCodes([for (var i = 0; i < 8; i++) letters.codeUnitAt(_random.nextInt(letters.length))]);
    temporaryPasswords.add(password);
    return password;
  }

  Future<void> _wait() => Future<void>.delayed(delay);

  DateTime _cairoDay(DateTime utc) {
    final cairo = AppFormat.cairo(utc);
    return DateTime.utc(cairo.year, cairo.month, cairo.day);
  }

  DateTime _today() => _cairoDay(_now());

  int _age(DateTime dateOfBirth) {
    final today = _today();
    var years = today.year - dateOfBirth.year;
    if (DateTime.utc(dateOfBirth.year + years, dateOfBirth.month, dateOfBirth.day).isAfter(today)) years--;
    return years;
  }

  /// A time on the Cairo day [daysAgo] days back. Today's sessions spread
  /// over the part of the day that has passed, so they are never in the future.
  DateTime _timeOn(int daysAgo, int index) {
    final now = _now().toUtc();
    final day = _today().subtract(Duration(days: daysAgo));
    final start = AppFormat.cairoDayStartUtc(day);
    if (daysAgo == 0) {
      final elapsed = now.difference(start);
      final fraction = 0.35 + (index % 9) * 0.07;
      return start.add(elapsed * fraction);
    }
    return start.add(Duration(hours: 10, minutes: (index * 37) % 600));
  }

  // ---------------------------------------------------------------------------
  // Seed: realistic patients of an internal-medicine clinic in two branches.

  void _seed() {
    const maadi = FakeClinicRepository.maadiBranchId;
    const nasr = FakeClinicRepository.nasrCityBranchId;
    final reception = receptionAssistant;
    final today = _today();

    String patient(
      String name,
      String phone,
      Gender gender,
      DateTime dateOfBirth, {
      required int linkedDaysAgo,
      bool estimated = false,
      bool ownedByUs = true,
      String? nationalId,
      String? address,
      String? bloodType,
      (String, String)? emergency,
      List<String> allergies = const [],
      List<String> chronic = const [],
      List<String> medications = const [],
      List<String> surgeries = const [],
      String? familyHistory,
      bool archived = false,
    }) {
      final id = 'dev-patient-${_nextId++}';
      _accounts[id] = _Account(
        id: id,
        phone: phone,
        fullName: name,
        gender: gender,
        dateOfBirth: dateOfBirth,
        estimated: estimated,
        nationalId: nationalId,
        address: address,
        bloodType: bloodType,
        emergencyName: emergency?.$1,
        emergencyPhone: emergency?.$2,
        ownedByUs: ownedByUs,
      );
      _link(id, AppFormat.cairoDayStartUtc(today.subtract(Duration(days: linkedDaysAgo))).add(const Duration(hours: 9)));
      final link = _links[id]!
        ..archived = archived
        ..familyHistory = familyHistory;
      if (archived) link.archivedAt = _now().toUtc().subtract(const Duration(days: 30));
      for (final (list, texts) in [
        (ProfileList.allergies, allergies),
        (ProfileList.chronicDiseases, chronic),
        (ProfileList.currentMedications, medications),
        (ProfileList.surgeries, surgeries),
      ]) {
        link.lists[list] = [for (final text in texts) ProfileItem(id: 'dev-item-${_nextId++}', text: text)];
      }
      return id;
    }

    void visit(
      String patientId,
      int daysAgo,
      SessionType type, {
      String branch = maadi,
      RecordedBy? by,
      String? complaint,
      String? diagnosis,
      String? findings,
      String? notes,
      Vitals vitals = const Vitals(),
      String? privateNote,
      int? amount,
      PaymentMethod? method = PaymentMethod.cash,
    }) {
      final rule = _rule(patientId);
      assert(type == SessionType.examination || rule.reason == null, 'Seed breaks the consultation rule');
      final id = addSession(patientId, type, daysAgo: daysAgo, branchId: branch, recorder: by);
      final session = _sessions.firstWhere((s) => s.id == id);
      session
        ..chiefComplaint = complaint
        ..findings = by?.isAssistant ?? false ? null : findings
        ..diagnosis = by?.isAssistant ?? false ? null : diagnosis
        ..patientNotes = by?.isAssistant ?? false ? null : notes
        ..vitals = vitals
        ..paymentMethod = method;
      if (amount != null) session.amountPiasters = amount;
      if (privateNote != null) {
        session
          ..privateNote = privateNote
          ..privateNoteAt = session.at;
      }
    }

    DateTime born(int year, int month, int day) => DateTime.utc(year, month, day);

    // 1. Exam, then two consultations (the last one today): the next one must be an examination (AC-1).
    final mona = patient('منى حسن إبراهيم', '+201012345678', Gender.female, born(1990, 5, 1),
        linkedDaysAgo: 120,
        nationalId: '29005010123456',
        address: 'المعادي، شارع 9، عمارة 12',
        bloodType: 'A+',
        emergency: ('حسن إبراهيم', '+201001234567'),
        allergies: ['بنسلين'],
        surgeries: ['استئصال الزائدة الدودية (2015)'],
        familyHistory: 'الأم: ضغط مرتفع');
    visit(mona, 12, SessionType.examination,
        complaint: 'صداع متكرر منذ أسبوعين',
        findings: 'الفحص العصبي سليم',
        diagnosis: 'صداع نصفي',
        notes: 'راحة وتقليل الكافيين، ومتابعة بعد أسبوع',
        vitals: const Vitals(bpSys: 125, bpDia: 80, pulse: 78, tempC: 36.9, weightKg: 64),
        privateNote: 'تتابع مع طبيب نفسي، راجع التاريخ المرضي في الزيارة القادمة');
    visit(mona, 5, SessionType.consultation, complaint: 'متابعة الصداع', diagnosis: 'تحسن ملحوظ');
    visit(mona, 0, SessionType.consultation, complaint: 'متابعة', diagnosis: 'صداع نصفي، تحت السيطرة', amount: 10000);

    // 2. Diabetes and blood pressure; an examination today in Nasr City.
    final ahmed = patient('أحمد محمود عبد الرحمن', '+201112345670', Gender.male, born(1978, 2, 14),
        linkedDaysAgo: 90,
        bloodType: 'O+',
        address: 'مدينة نصر، الحي السابع',
        chronic: ['سكر من النوع الثاني', 'ضغط مرتفع'],
        medications: ['Metformin 500 mg', 'Concor 5 mg']);
    visit(ahmed, 40, SessionType.examination,
        branch: nasr,
        complaint: 'عطش وكثرة التبول',
        diagnosis: 'سكر من النوع الثاني',
        vitals: const Vitals(bpSys: 150, bpDia: 95, glucose: 240, weightKg: 92));
    visit(ahmed, 20, SessionType.consultation, branch: nasr, complaint: 'متابعة السكر', diagnosis: 'السكر أفضل');
    visit(ahmed, 0, SessionType.examination,
        branch: nasr,
        complaint: 'ارتفاع الضغط صباحاً',
        diagnosis: 'ضغط غير منتظم',
        vitals: const Vitals(bpSys: 160, bpDia: 100, pulse: 88),
        method: PaymentMethod.instapay);

    // 3. A child, first visit today, recorded at reception (awaiting the doctor, BR-AS7).
    final youssef = patient('يوسف خالد سمير', '+201223456781', Gender.male, born(2018, 9, 10),
        linkedDaysAgo: 0, emergency: ('خالد سمير', '+201223456780'), allergies: ['الفول السوداني']);
    visit(youssef, 0, SessionType.examination,
        by: reception, complaint: 'كحة وسخونية منذ يومين', vitals: const Vitals(tempC: 38.4, weightKg: 24));

    // 4. Blood pressure; a consultation today recorded at reception.
    final hoda = patient('هدى عبد الله محمد', '+201098765432', Gender.female, born(1965, 7, 3),
        linkedDaysAgo: 200, chronic: ['ضغط مرتفع'], medications: ['Amlodipine 5 mg']);
    visit(hoda, 9, SessionType.examination,
        complaint: 'دوخة', diagnosis: 'ارتفاع ضغط الدم', vitals: const Vitals(bpSys: 165, bpDia: 98));
    visit(hoda, 0, SessionType.consultation, by: reception, complaint: 'متابعة الضغط', vitals: const Vitals(bpSys: 140, bpDia: 88));

    // 5. A consultation today in Nasr City.
    final karim = patient('كريم سامي فؤاد', '+201556677889', Gender.male, born(1995, 1, 30), linkedDaysAgo: 35);
    visit(karim, 30, SessionType.examination, branch: nasr, complaint: 'آلام بالمعدة', diagnosis: 'التهاب بالمعدة');
    visit(karim, 0, SessionType.consultation, branch: nasr, complaint: 'متابعة', diagnosis: 'تحسن', method: PaymentMethod.card);

    // 6. New, never seen: the first visit offers only Examination (BR-S2).
    patient('سارة علي مصطفى', '+201234567890', Gender.female, born(today.year - 29, today.month, today.day),
        linkedDaysAgo: 1, estimated: true);

    // 7. Linked from another clinic: only the identity is ours to see (BR-P3).
    final noura = patient('نورا إبراهيم سليم', '+201066554433', Gender.female, born(1987, 12, 12),
        linkedDaysAgo: 70, ownedByUs: false, nationalId: '28712120123456', address: 'الزمالك', bloodType: 'B+');
    visit(noura, 60, SessionType.examination, complaint: 'إرهاق عام', diagnosis: 'أنيميا');

    // 8. Not seen for three months.
    final mohamed = patient('محمد عادل شاكر', '+201277788899', Gender.male, born(1985, 7, 20),
        linkedDaysAgo: 110, chronic: ['ربو'], medications: ['Ventolin بخاخ']);
    visit(mohamed, 100, SessionType.examination, branch: nasr, complaint: 'ضيق تنفس', diagnosis: 'أزمة ربو');
    visit(mohamed, 95, SessionType.consultation, branch: nasr, complaint: 'متابعة', diagnosis: 'مستقر');

    // 9. Two examinations, months ago.
    final fatma = patient('فاطمة الزهراء أحمد', '+201011223344', Gender.female, born(1972, 3, 3),
        linkedDaysAgo: 210, chronic: ['سكر'], familyHistory: 'الأب والأم: سكر');
    visit(fatma, 200, SessionType.examination, complaint: 'متابعة السكر', diagnosis: 'سكر غير منتظم');
    visit(fatma, 150, SessionType.examination, complaint: 'تنميل بالقدمين', diagnosis: 'اعتلال أعصاب طرفية');

    // 10. One consultation since the last examination.
    final laila = patient('ليلى مصطفى كامل', '+201145678912', Gender.female, born(2001, 11, 11), linkedDaysAgo: 26);
    visit(laila, 25, SessionType.examination, complaint: 'التهاب الحلق', diagnosis: 'التهاب لوزتين');
    visit(laila, 18, SessionType.examination, complaint: 'عودة الالتهاب', diagnosis: 'التهاب لوزتين متكرر');
    visit(laila, 10, SessionType.consultation, complaint: 'متابعة', diagnosis: 'تحسن');

    // 11. Allergic to aspirin, heart disease.
    final ibrahim = patient('إبراهيم السيد حسن', '+201009988776', Gender.male, born(1958, 4, 22),
        linkedDaysAgo: 8,
        allergies: ['الأسبرين', 'السلفا'],
        chronic: ['ضغط مرتفع', 'قصور بالشريان التاجي'],
        medications: ['Plavix 75 mg', 'Concor 2.5 mg']);
    visit(ibrahim, 7, SessionType.examination,
        branch: nasr, complaint: 'ألم بالصدر عند المجهود', diagnosis: 'ذبحة صدرية مستقرة', vitals: const Vitals(bpSys: 145, bpDia: 90, pulse: 92));
    visit(ibrahim, 3, SessionType.consultation, branch: nasr, complaint: 'متابعة', diagnosis: 'مستقر');

    // 12. A child seen this month.
    final rahma = patient('رحمة عادل فهمي', '+201288899900', Gender.female, born(2020, 4, 4), linkedDaysAgo: 16);
    visit(rahma, 15, SessionType.examination,
        complaint: 'إسهال', diagnosis: 'نزلة معوية', vitals: const Vitals(tempC: 37.8, weightKg: 16.5));

    // 13. Linked, never visited.
    patient('خالد منصور عطية', '+201001112223', Gender.male, born(1988, 8, 8), linkedDaysAgo: 40);

    // 14. The rule restarts after a new examination.
    final mariam = patient('مريم يوسف عبد السلام', '+201156565656', Gender.female, born(1993, 6, 18), linkedDaysAgo: 50);
    visit(mariam, 45, SessionType.examination, complaint: 'آلام المفاصل', diagnosis: 'التهاب مفاصل');
    visit(mariam, 33, SessionType.consultation, complaint: 'متابعة');
    visit(mariam, 20, SessionType.consultation, complaint: 'متابعة');
    visit(mariam, 2, SessionType.examination, complaint: 'آلام الركبة', diagnosis: 'خشونة بالركبة');

    // 15. Archived (BR-P7).
    final amr = patient('عمرو شريف نبيل', '+201267676767', Gender.male, born(1999, 2, 2), linkedDaysAgo: 420, archived: true);
    visit(amr, 400, SessionType.examination, complaint: 'حساسية جلدية', diagnosis: 'إكزيما');

    // Messages the clinic hasn't read yet (D4's unread badge).
    unreadChats[mona] = 2;
    unreadChats[karim] = 1;

    // Accounts of other clinics, to link (BR-P3).
    for (final (i, phone) in elsewherePhones.indexed) {
      final id = 'dev-elsewhere-${i + 1}';
      _accounts[id] = _Account(
        id: id,
        phone: phone,
        fullName: i == 0 ? 'ريم فتحي عبد العزيز' : 'مريض تجريبي',
        gender: i == 0 ? Gender.female : Gender.male,
        dateOfBirth: born(1992, 10, 1),
        nationalId: '29210010123456',
        address: 'الإسكندرية',
        ownedByUs: false,
      );
    }
  }
}

class _Visits {
  _Visits(this.patientId, this.sessions);

  final String patientId;

  /// Oldest first.
  final List<_Session> sessions;

  _Session? get first => sessions.isEmpty ? null : sessions.first;
  _Session? get last => sessions.isEmpty ? null : sessions.last;
  int get examinations => sessions.where((s) => s.type == SessionType.examination).length;
  int get consultations => sessions.length - examinations;
  int get paid => sessions.fold(0, (sum, s) => sum + (s.amountPiasters ?? 0));
}

/// The offline records, shared by the patients and sessions repositories for
/// the whole app run, so what one screen saves the others see.
final fakeClinicRecordsProvider = Provider<FakeClinicRecords>((ref) => FakeClinicRecords(caller: () => fakeCallerOf(ref)));

/// The signed-in doctor or assistant as the offline clinic sees them.
FakeCaller? fakeCallerOf(Ref ref) {
  final session = ref.read(authControllerProvider).value;
  if (session == null || session.role != UserRole.doctor && session.role != UserRole.assistant) return null;
  final clinic = ref.read(clinicContextProvider).value ?? FakeClinicRepository.contextFor(session);
  return FakeCaller.of(clinic, userId: session.userId);
}
