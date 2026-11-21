import 'dart:math';

import '../../../core/data/paged.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/validation/egyptian_phone.dart';
import '../../../core/validation/map_links.dart';
import '../../../core/validation/validators.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';
import '../../clinic/data/clinic_repository.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../doctor_registration/data/registration_repository.dart';
import '../../doctor_registration/domain/registration_rules.dart';
import '../../doctor_registration/domain/specialty.dart';
import '../domain/account_models.dart';
import '../domain/activity_models.dart';
import '../domain/assistant_models.dart';
import '../domain/branch_models.dart';
import '../domain/price_models.dart';
import '../domain/weekly_hours.dart';
import 'clinic_admin_repository.dart';
import '../../appointments/data/appointments_repository.dart' show OfflineBranchHours;
import '../../appointments/domain/appointment_models.dart' show WeeklyPeriod;

/// The offline clinic for `config/dev-offline.json` and tests. It answers
/// like the API (backend/docs/api-phase-2-clinic.md), with the same
/// refusals, so every D22–D29, D37 and AS12/AS19 state can be reached
/// without a server.
///
/// Branches match `FakeClinicRepository` (Maadi, the default, and Nasr
/// City), plus an archived Dokki branch. Nasr City has two bookings, so
/// archiving or closing it shows the BR-BR9 refusal. Assistants match the
/// offline accounts: `+201000000001` reception in Maadi, `+201000000005`
/// office manager in every branch, and a disabled custom assistant.
/// Every write adds an activity row (D27).
class FakeClinicAdminRepository implements ClinicAdminRepository, OfflineBranchHours {
  FakeClinicAdminRepository({this.currentSession, this.delay = const Duration(milliseconds: 300), DateTime? now})
      : _seededAt = (now ?? DateTime.now()).toUtc() {
    _seed();
  }

  /// The signed-in account; null acts as the doctor.
  final AuthSession? Function()? currentSession;
  final Duration delay;
  final DateTime _seededAt;

  static const maadiBranchId = FakeClinicRepository.maadiBranchId;
  static const nasrCityBranchId = FakeClinicRepository.nasrCityBranchId;
  static const dokkiBranchId = 'dev-branch-dokki';

  /// The doctor in activity rows and `people`, whichever doctor account is signed in.
  static const doctorUserId = 'dev-doctor-user';

  static final receptionUserId = _userIdOf('+201000000001');
  static final officeManagerUserId = _userIdOf('+201000000005');
  static const disabledAssistantId = 'dev-assistant-mona';
  static const removedAssistantId = 'dev-assistant-heba';

  static String _userIdOf(String phone) => FakeAuthRepository.accounts[phone]!.session(phone).userId;

  /// How many times each method was called (for tests).
  final calls = <String, int>{};

  /// The temporary password the last create or reset returned (for tests).
  String? lastTemporaryPassword;

  int branchLimit = 5;
  int assistantLimit = 5;

  final _failures = <String, ApiException>{};

  /// Makes the next call to [method] (for example `'updatePrices'`) throw [error].
  void failNext(String method, ApiException error) => _failures[method] = error;

  /// Open bookings per branch (BR-BR9), earliest first.
  final bookings = <String, List<BranchBooking>>{};

  final _branches = <_Branch>[];
  final _assistants = <_Assistant>[];
  final _activity = <ActivityEntry>[];
  final _history = <PriceHistoryEntry>[];
  final _prefs = <String, NotificationPrefs>{};
  PricePair _doctorPrices = const PricePair(examinationPricePiasters: 30000, consultationPricePiasters: 15000);
  late DoctorProfile _profile;
  int _activityId = 900;
  int _historyId = 10;
  final _random = Random(7);

  /// The assistant record of the offline account [userId], for tests that
  /// change an assistant's branches or permissions.
  void setAssistantBranches(String userId, {required bool allBranches, Set<String> branchIds = const {}}) {
    final assistant = _assistants.firstWhere((a) => a.userId == userId);
    assistant
      ..allBranches = allBranches
      ..branchIds = allBranches ? <String>{} : {...branchIds};
  }

  // ---------------------------------------------------------------------------
  // Who is calling

  AuthSession? get _session => currentSession?.call();

  bool get _isAssistant => _session?.role == UserRole.assistant;

  _Assistant? get _callerAssistant {
    final session = _session;
    if (session == null || session.role != UserRole.assistant) return null;
    for (final a in _assistants) {
      if (a.userId == session.userId) return a;
    }
    return null;
  }

  Set<String> get _callerPermissions {
    final session = _session;
    if (session == null || session.role != UserRole.assistant) return ClinicPermission.all.toSet();
    return _callerAssistant?.permissions ?? FakeClinicRepository.contextFor(session).permissions;
  }

  bool _callerCanUse(String branchId) {
    if (!_isAssistant) return true;
    final assistant = _callerAssistant;
    if (assistant == null) return FakeClinicRepository.contextFor(_session!).branch(branchId)?.assigned ?? false;
    return assistant.allBranches || assistant.branchIds.contains(branchId);
  }

  ActivityActor get _actor {
    final session = _session;
    if (session != null && session.role == UserRole.assistant) {
      return ActivityActor(userId: session.userId, name: _callerAssistant?.fullName ?? session.displayName, role: 'assistant');
    }
    return ActivityActor(userId: doctorUserId, name: _profile.fullName, role: 'doctor');
  }

  Future<void> _enter(String method, {bool doctorOnly = false, String? permission}) async {
    calls.update(method, (n) => n + 1, ifAbsent: () => 1);
    await Future<void>.delayed(delay);
    final failure = _failures.remove(method);
    if (failure != null) throw failure;
    if (doctorOnly && _isAssistant) throw _error(403, ApiCodes.permissionDenied);
    if (permission != null && !_callerPermissions.contains(permission)) throw _error(403, ApiCodes.permissionDenied);
  }

  static ApiException _error(int status, String code) => ApiException(kind: ApiErrorKind.http, status: status, code: code);

  static ApiException _fields(Map<String, String> fields) =>
      ApiException(kind: ApiErrorKind.http, status: 400, code: ApiCodes.validationFailed, fieldCodes: fields);

  DateTime get _now => DateTime.now().toUtc();

  void _log(String action, String targetType, String? targetId, {Map<String, dynamic> details = const {}, ActivityPatient? patient}) {
    _activity.insert(
      0,
      ActivityEntry(
        id: ++_activityId,
        at: _now,
        actor: _actor,
        action: action,
        targetType: targetType,
        targetId: targetId,
        patient: patient,
        details: details,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Branches

  _Branch _branch(String id) {
    for (final b in _branches) {
      if (b.id == id) return b;
    }
    throw _error(404, ApiCodes.notFound);
  }

  int get _branchCount => _branches.where((b) => b.status != BranchStatuses.archived).length;

  /// Default first, then oldest first, archived last (like the API).
  List<_Branch> get _ordered => [..._branches]..sort((a, b) {
        int rank(_Branch x) => x.isDefault ? 0 : (x.status == BranchStatuses.archived ? 2 : 1);
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.createdAt.compareTo(b.createdAt);
      });

  /// Today in Cairo, as the cards' "today" (good enough offline: UTC+2).
  DateTime get _today {
    final cairo = _now.add(const Duration(hours: 2));
    return DateTime(cairo.year, cairo.month, cairo.day);
  }

  VisitPrices _pricesOf(_Branch b) => VisitPrices(
        examinationPricePiasters: b.examination,
        consultationPricePiasters: b.consultation,
        usesDoctorPrices: b.examination == null && b.consultation == null,
        effectiveExaminationPricePiasters: b.examination ?? _doctorPrices.examinationPricePiasters,
        effectiveConsultationPricePiasters: b.consultation ?? _doctorPrices.consultationPricePiasters,
      );

  BranchDetails _details(_Branch b) => BranchDetails(
        id: b.id,
        isDefault: b.isDefault,
        status: b.status,
        closedMessage: b.closedMessage,
        reopenDate: b.reopenDate,
        assigned: _callerCanUse(b.id),
        info: b.info,
        address: b.address,
        contact: b.contact,
        workingHours: BranchWorkingHours(bookingMode: 'queue', defaultCapacity: 30, periods: _sortedPeriods(b.periods)),
        clinicInfo: BranchClinicInfo(prices: _pricesOf(b), paymentMethods: b.paymentMethods, amenities: b.amenities),
        createdAt: b.createdAt,
        updatedAt: b.updatedAt,
      );

  static List<BranchPeriod> _sortedPeriods(List<BranchPeriod> periods) => [...periods]
    ..sort((a, b) {
      final byDay = a.weekday.compareTo(b.weekday);
      return byDay != 0 ? byDay : (WeeklyHours.parse(a.startLocal) ?? 0).compareTo(WeeklyHours.parse(b.startLocal) ?? 0);
    });

  @override
  Future<BranchList> branches() async {
    await _enter('branches');
    final weekday = _today.weekday;
    return BranchList(
      items: [
        for (final b in _ordered)
          BranchCard(
            id: b.id,
            nameAr: b.info.nameAr,
            nameEn: b.info.nameEn,
            governorate: b.address.governorate,
            city: b.address.city,
            area: b.address.area,
            status: b.status,
            closedMessage: b.closedMessage,
            reopenDate: b.reopenDate,
            isDefault: b.isDefault,
            assigned: _callerCanUse(b.id),
            todayPeriods: WeeklyHours.ofDay(b.periods, weekday),
            upcomingBookings: bookings[b.id]?.length ?? 0,
          ),
      ],
      count: _branchCount,
      limit: branchLimit,
      canAdd: _branchCount < branchLimit,
      today: _today,
      todayWeekday: weekday,
    );
  }

  @override
  Future<BranchDetails> branch(String branchId) async {
    await _enter('branch');
    return _details(_branch(branchId));
  }

  Map<String, String> _checkInfo(BranchInfo info) => {
        if (info.nameAr.trim().isEmpty)
          'info.nameAr': 'REQUIRED'
        else if (info.nameAr.trim().length < 2 || info.nameAr.trim().length > 60)
          'info.nameAr': 'INVALID_VALUE',
        if ((info.nameEn ?? '').length > 60) 'info.nameEn': 'TOO_LONG',
        if ((info.description ?? '').length > 500) 'info.description': 'TOO_LONG',
      };

  Map<String, String> _checkAddress(BranchAddress address) => {
        if (address.governorate.trim().isEmpty) 'address.governorate': 'REQUIRED',
        if (address.city.trim().isEmpty) 'address.city': 'REQUIRED',
        if (address.details.trim().isEmpty)
          'address.details': 'REQUIRED'
        else if (address.details.trim().length > 300)
          'address.details': 'TOO_LONG',
        if ((address.mapUrl ?? '').trim().length > MapLinks.maxLength)
          'address.mapUrl': 'TOO_LONG'
        else if ((address.mapUrl ?? '').trim().isNotEmpty && !MapLinks.isGoogleMaps(address.mapUrl!))
          'address.mapUrl': 'INVALID_MAP_LINK',
      };

  Map<String, String> _checkContact(BranchContact contact) => {
        if (contact.phones.isEmpty) 'contact.phones': 'PHONE_REQUIRED',
        if (contact.phones.length > 5) 'contact.phones': 'INVALID_VALUE',
        for (final (i, phone) in contact.phones.indexed)
          if (phone.number.trim().isEmpty)
            'contact.phones[$i].number': 'REQUIRED'
          else if (EgyptianPhone.normalize(phone.number) == null)
            'contact.phones[$i].number': 'INVALID_PHONE',
        if (contact.email != null && contact.email!.trim().isNotEmpty && !Validators.isEmail(contact.email!))
          'contact.email': 'INVALID_EMAIL',
      };

  static BranchInfo _cleanInfo(BranchInfo info) => BranchInfo(
        nameAr: info.nameAr.trim(),
        nameEn: _trim(info.nameEn),
        description: _trim(info.description),
      );

  static BranchAddress _cleanAddress(BranchAddress a) => BranchAddress(
        governorate: a.governorate.trim(),
        city: a.city.trim(),
        area: _trim(a.area),
        details: a.details.trim(),
        landmark: _trim(a.landmark),
        mapUrl: _trim(a.mapUrl),
      );

  static BranchContact _cleanContact(BranchContact c) => BranchContact(
        phones: [
          for (final p in c.phones) BranchContactPhone(number: EgyptianPhone.normalize(p.number)!, label: p.label, isWhatsapp: p.isWhatsapp),
        ],
        email: _trim(c.email)?.toLowerCase(),
      );

  static String? _trim(String? value) => value == null || value.trim().isEmpty ? null : value.trim();

  @override
  Future<BranchDetails> createBranch({
    required BranchInfo info,
    required BranchAddress address,
    required BranchContact contact,
    BranchChecklistInput? clinicInfo,
  }) async {
    await _enter('createBranch', doctorOnly: true);
    final problems = {..._checkInfo(info), ..._checkAddress(address), ..._checkContact(contact)};
    if (problems.isNotEmpty) throw _fields(problems);
    if (_branchCount >= branchLimit) throw _error(409, ClinicAdminCodes.branchLimitReached);
    final now = _now;
    final branch = _Branch(
      id: 'dev-branch-${now.microsecondsSinceEpoch}',
      info: _cleanInfo(info),
      address: _cleanAddress(address),
      contact: _cleanContact(contact),
      createdAt: now,
    );
    if (clinicInfo != null) {
      branch
        ..paymentMethods = clinicInfo.orderedPaymentMethods
        ..amenities = clinicInfo.orderedAmenities;
    }
    _branches.add(branch);
    _log('branchCreated', 'branch', branch.id, details: {'nameAr': branch.info.nameAr});
    return _details(branch);
  }

  @override
  Future<BranchDetails> updateBranch(
    String branchId, {
    BranchInfo? info,
    BranchAddress? address,
    BranchContact? contact,
    BranchChecklistInput? clinicInfo,
  }) async {
    await _enter('updateBranch', doctorOnly: true);
    final problems = {
      if (info != null) ..._checkInfo(info),
      if (address != null) ..._checkAddress(address),
      if (contact != null) ..._checkContact(contact),
    };
    if (problems.isNotEmpty) throw _fields(problems);
    final branch = _branch(branchId);
    if (info != null) branch.info = _cleanInfo(info);
    if (address != null) branch.address = _cleanAddress(address);
    if (contact != null) branch.contact = _cleanContact(contact);
    if (clinicInfo != null) {
      branch
        ..paymentMethods = clinicInfo.orderedPaymentMethods
        ..amenities = clinicInfo.orderedAmenities;
    }
    branch.updatedAt = _now;
    _log('branchUpdated', 'branch', branch.id, details: {
      'groups': [if (info != null) 'info', if (address != null) 'address', if (contact != null) 'contact', if (clinicInfo != null) 'clinicInfo'],
    });
    return _details(branch);
  }

  // ---------------------------------------------------------------------------
  // The week, for the offline schedule (FakeAppointmentsRepository): working
  // hours change only through `updateBranchSchedule`, which checks bookings
  // first (BR-AP12). D28's cards and D29 read the week from here.

  @override
  List<WeeklyPeriod>? weeklyOf(String branchId) {
    final branch = _branches.where((b) => b.id == branchId).firstOrNull;
    if (branch == null) return null;
    return [
      for (final p in [for (final day in WeeklyHours.weekOrder) ...WeeklyHours.ofDay(branch.periods, day)])
        WeeklyPeriod(weekday: p.weekday, start: p.startLocal, end: p.endLocal, endsNextDay: p.endsNextDay, label: p.label, capacity: p.capacity),
    ];
  }

  @override
  void saveWeekly(String branchId, List<WeeklyPeriod> weekly) {
    final branch = _branch(branchId);
    branch
      ..periods = [
        for (final p in weekly)
          BranchPeriod(
            weekday: p.weekday,
            startLocal: WeeklyHours.format(WeeklyHours.parse(p.start)!),
            endLocal: WeeklyHours.format(WeeklyHours.parse(p.end)!),
            endsNextDay: p.endsNextDay,
            label: _trim(p.label),
            capacity: p.capacity,
          ),
      ]
      ..updatedAt = _now;
    _log('branchScheduleUpdated', 'branch', branchId, details: {'periods': weekly.length});
  }

  /// What `updateBranchSchedule` refuses for the signed-in caller: an
  /// assistant without `scheduleManage`, or not in this branch.
  @override
  ApiException? scheduleRefusal(String branchId) {
    if (!_callerPermissions.contains(ClinicPermission.scheduleManage)) return _error(403, ApiCodes.permissionDenied);
    if (!_callerCanUse(branchId)) return _error(403, ApiCodes.permissionDenied);
    return null;
  }

  @override
  Future<BranchDetails> setBranchStatus(String branchId, String status, {String? closedMessage, DateTime? reopenDate}) async {
    await _enter('setBranchStatus', doctorOnly: true);
    if (status == BranchStatuses.temporarilyClosed) {
      final message = closedMessage?.trim() ?? '';
      final problems = {
        if (message.isEmpty) 'closedMessage': 'REQUIRED' else if (message.length > 300) 'closedMessage': 'TOO_LONG',
        if (reopenDate != null && reopenDate.isBefore(_today)) 'reopenDate': 'OUT_OF_RANGE',
      };
      if (problems.isNotEmpty) throw _fields(problems);
    }
    final branch = _branch(branchId);
    final before = branch.status;
    if (status != BranchStatuses.active) {
      if (status == BranchStatuses.archived && branch.isDefault) {
        throw _error(409, ClinicAdminCodes.cannotArchiveDefaultBranch);
      }
      final otherActive = _branches.any((b) => b.id != branchId && b.status == BranchStatuses.active);
      if (before == BranchStatuses.active && !otherActive) throw _error(409, ClinicAdminCodes.lastActiveBranch);
      final open = [
        for (final booking in bookings[branchId] ?? const <BranchBooking>[])
          if (status != BranchStatuses.temporarilyClosed || reopenDate == null || booking.localDate.isBefore(reopenDate)) booking,
      ];
      if (open.isNotEmpty) throw BranchHasBookingsException(bookings: open, totalCount: open.length);
    } else if (before == BranchStatuses.archived && _branchCount >= branchLimit) {
      throw _error(409, ClinicAdminCodes.branchLimitReached);
    }
    branch
      ..status = status
      ..closedMessage = status == BranchStatuses.temporarilyClosed ? closedMessage!.trim() : null
      ..reopenDate = status == BranchStatuses.temporarilyClosed ? reopenDate : null
      ..updatedAt = _now;
    if (before != status || status == BranchStatuses.temporarilyClosed) {
      _log('branchStatusChanged', 'branch', branchId, details: {
        'before': before,
        'after': status,
        'reopenDate': reopenDate == null ? null : '${reopenDate.year}-${reopenDate.month.toString().padLeft(2, '0')}-${reopenDate.day.toString().padLeft(2, '0')}',
      });
    }
    return _details(branch);
  }

  @override
  Future<BranchDetails> setDefaultBranch(String branchId) async {
    await _enter('setDefaultBranch', doctorOnly: true);
    final branch = _branch(branchId);
    if (branch.isDefault) return _details(branch);
    if (branch.status != BranchStatuses.active) throw _error(409, ClinicAdminCodes.branchNotActive);
    final previous = _branches.firstWhere((b) => b.isDefault);
    previous.isDefault = false;
    branch
      ..isDefault = true
      ..updatedAt = _now;
    _log('defaultBranchChanged', 'branch', branchId, details: {'before': previous.id, 'after': branchId});
    return _details(branch);
  }

  // ---------------------------------------------------------------------------
  // Prices

  PricesOverview _overview({int page = 1, int pageSize = 25}) {
    final start = (page - 1) * pageSize;
    final items = _history.skip(start).take(pageSize).toList();
    return PricesOverview(
      doctor: _doctorPrices,
      branches: [
        for (final b in _ordered)
          BranchPriceRow(
            branchId: b.id,
            nameAr: b.info.nameAr,
            nameEn: b.info.nameEn,
            status: b.status,
            isDefault: b.isDefault,
            assigned: _callerCanUse(b.id),
            prices: _pricesOf(b),
          ),
      ],
      history: Paged(
        items: items,
        page: page,
        pageSize: pageSize,
        totalCount: _history.length,
        totalPages: (_history.length / pageSize).ceil(),
      ),
    );
  }

  @override
  Future<PricesOverview> prices({int page = 1, int pageSize = 25}) async {
    await _enter('prices', permission: ClinicPermission.pricesManage);
    return _overview(page: page, pageSize: pageSize);
  }

  @override
  Future<PricesOverview> updatePrices({String? branchId, int? examinationPricePiasters, int? consultationPricePiasters}) async {
    await _enter('updatePrices', permission: ClinicPermission.pricesManage);
    final problems = {
      if (examinationPricePiasters != null && (examinationPricePiasters < 0 || examinationPricePiasters > PriceRules.maxPiasters))
        'examinationPricePiasters': 'OUT_OF_RANGE',
      if (consultationPricePiasters != null && (consultationPricePiasters < 0 || consultationPricePiasters > PriceRules.maxPiasters))
        'consultationPricePiasters': 'OUT_OF_RANGE',
    };
    if (problems.isNotEmpty) throw _fields(problems);
    if (branchId != null && !_callerCanUse(branchId)) throw _error(403, ApiCodes.branchNotAllowed);
    final after = PricePair(examinationPricePiasters: examinationPricePiasters, consultationPricePiasters: consultationPricePiasters);
    final PricePair before;
    _Branch? branch;
    if (branchId == null) {
      before = _doctorPrices;
      _doctorPrices = after;
    } else {
      branch = _branch(branchId);
      before = PricePair(examinationPricePiasters: branch.examination, consultationPricePiasters: branch.consultation);
      branch
        ..examination = examinationPricePiasters
        ..consultation = consultationPricePiasters;
    }
    if (before != after) {
      final actor = _actor;
      _history.insert(
        0,
        PriceHistoryEntry(
          id: 'dev-price-${++_historyId}',
          changedAt: _now,
          changedBy: PriceChangedBy(userId: actor.userId, name: actor.name, role: actor.role),
          branchId: branch?.id,
          branchNameAr: branch?.info.nameAr,
          branchNameEn: branch?.info.nameEn,
          before: before,
          after: after,
        ),
      );
      _log('pricesUpdated', branchId == null ? 'doctor' : 'branch', branchId ?? doctorUserId, details: {
        'branchId': branchId,
        'before': {'examinationPricePiasters': before.examinationPricePiasters, 'consultationPricePiasters': before.consultationPricePiasters},
        'after': {'examinationPricePiasters': after.examinationPricePiasters, 'consultationPricePiasters': after.consultationPricePiasters},
      });
    }
    return _overview();
  }

  // ---------------------------------------------------------------------------
  // Profile and notification preferences

  @override
  Future<DoctorProfile> doctorProfile() async {
    await _enter('doctorProfile', doctorOnly: true);
    return _profile;
  }

  @override
  Future<DoctorProfile> updateDoctorProfile(DoctorProfileUpdate update) async {
    await _enter('updateDoctorProfile', doctorOnly: true);
    final specialties = {for (final s in FakeRegistrationRepository.specialtyList) s.id: s};
    final extras = update.extraSpecialtyIds;
    final problems = {
      if (update.fullName.trim().isEmpty)
        'fullName': 'REQUIRED'
      else if (!RegistrationRules.isFullName(update.fullName))
        'fullName': 'INVALID_NAME',
      if (update.title.trim().isEmpty) 'title': 'REQUIRED' else if (update.title.length > 40) 'title': 'TOO_LONG',
      if ((update.fullNameEn ?? '').length > 60) 'fullNameEn': 'TOO_LONG',
      if ((update.titleEn ?? '').length > 40) 'titleEn': 'TOO_LONG',
      if ((update.degreesAr ?? '').length > 300) 'degreesAr': 'TOO_LONG',
      if ((update.degreesEn ?? '').length > 300) 'degreesEn': 'TOO_LONG',
      if (!specialties.containsKey(update.specialtyId)) 'specialtyId': 'INVALID_SPECIALTY',
      if (extras.length > 2 || extras.toSet().length != extras.length || extras.contains(update.specialtyId))
        'extraSpecialtyIds': 'INVALID_VALUE'
      else if (extras.any((id) => !specialties.containsKey(id)))
        'extraSpecialtyIds': 'INVALID_SPECIALTY',
    };
    if (problems.isNotEmpty) throw _fields(problems);
    final before = _profile;
    _profile = DoctorProfile(
      doctorId: before.doctorId,
      fullName: RegistrationRules.collapseSpaces(update.fullName),
      fullNameEn: _trim(update.fullNameEn),
      title: update.title.trim(),
      titleEn: _trim(update.titleEn),
      degreesAr: _trim(update.degreesAr),
      degreesEn: _trim(update.degreesEn),
      specialty: specialties[update.specialtyId],
      specialtyId: update.specialtyId,
      extraSpecialties: [for (final id in extras) specialties[id]!],
      email: before.email,
      emailVerified: before.emailVerified,
      phone: before.phone,
      licenseNumber: before.licenseNumber,
      status: before.status,
      updatedAt: _now,
    );
    final fields = [
      if (before.fullName != _profile.fullName) 'fullName',
      if (before.fullNameEn != _profile.fullNameEn) 'fullNameEn',
      if (before.title != _profile.title) 'title',
      if (before.titleEn != _profile.titleEn) 'titleEn',
      if (before.degreesAr != _profile.degreesAr) 'degreesAr',
      if (before.degreesEn != _profile.degreesEn) 'degreesEn',
    ];
    if (fields.isNotEmpty) _log('doctorProfileUpdated', 'doctor', doctorUserId, details: {'fields': fields});
    final specialtyChanged =
        before.specialtyId != _profile.specialtyId || before.extraSpecialtyIds.join(',') != _profile.extraSpecialtyIds.join(',');
    if (specialtyChanged) {
      _log('doctorSpecialtyChanged', 'doctor', doctorUserId, details: {
        'before': {'specialtyId': before.specialtyId, 'extraSpecialtyIds': before.extraSpecialtyIds},
        'after': {'specialtyId': _profile.specialtyId, 'extraSpecialtyIds': _profile.extraSpecialtyIds},
      });
    }
    return _profile;
  }

  String get _prefsKey => _session?.userId ?? doctorUserId;

  @override
  Future<NotificationPrefs> notificationPrefs() async {
    await _enter('notificationPrefs');
    return _prefs[_prefsKey] ?? const NotificationPrefs();
  }

  @override
  Future<NotificationPrefs> updateNotificationPrefs({bool? chat, bool? reminders, bool? showPreview, bool? bookings}) async {
    await _enter('updateNotificationPrefs');
    final next = (_prefs[_prefsKey] ?? const NotificationPrefs())
        .copyWith(chat: chat, reminders: reminders, showPreview: showPreview, bookings: bookings);
    _prefs[_prefsKey] = next;
    return next;
  }

  // ---------------------------------------------------------------------------
  // Assistants

  int get _assistantCount => _assistants.where((a) => a.status != AssistantStatuses.removed).length;

  _Assistant _assistantRecord(String id) {
    for (final a in _assistants) {
      if (a.userId == id) return a;
    }
    throw _error(404, ApiCodes.notFound);
  }

  Assistant _view(_Assistant a) {
    final branches = a.allBranches
        ? const <AssistantBranch>[]
        : [
            for (final b in _ordered)
              if (a.branchIds.contains(b.id)) AssistantBranch(id: b.id, nameAr: b.info.nameAr, nameEn: b.info.nameEn, status: b.status),
          ];
    return Assistant(
      userId: a.userId,
      fullName: a.fullName,
      phone: a.phone,
      preset: AssistantPreset.match(a.permissions),
      status: a.status,
      allBranches: a.allBranches,
      branches: branches,
      branchIds: [for (final b in branches) b.id],
      permissions: a.permissions,
      mustChangePassword: a.mustChangePassword,
      lastActiveAt: a.lastActiveAt,
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
      removedAt: a.removedAt,
    );
  }

  AssistantList _assistantList({bool includeRemoved = false}) {
    final ordered = [..._assistants]..sort((a, b) {
        final removed = (a.status == AssistantStatuses.removed ? 1 : 0).compareTo(b.status == AssistantStatuses.removed ? 1 : 0);
        return removed != 0 ? removed : a.createdAt.compareTo(b.createdAt);
      });
    return AssistantList(
      items: [
        for (final a in ordered)
          if (includeRemoved || a.status != AssistantStatuses.removed) _view(a),
      ],
      count: _assistantCount,
      limit: assistantLimit,
      canAdd: _assistantCount < assistantLimit,
    );
  }

  @override
  Future<AssistantList> assistants({bool includeRemoved = false}) async {
    await _enter('assistants', doctorOnly: true);
    return _assistantList(includeRemoved: includeRemoved);
  }

  @override
  Future<Assistant> assistant(String assistantId) async {
    await _enter('assistant', doctorOnly: true);
    return _view(_assistantRecord(assistantId));
  }

  /// Dependencies switched on, as the server does.
  static Set<String> _withDependencies(Set<String> keys) {
    var result = <String>{};
    for (final key in keys) {
      result = ClinicPermission.toggle(result, key, on: true);
    }
    return result;
  }

  Map<String, String> _checkBranchIds(bool allBranches, Set<String> branchIds) {
    if (allBranches) return const {};
    if (branchIds.isEmpty) return const {'branchIds': 'REQUIRED'};
    final usable = {for (final b in _branches) if (b.status != BranchStatuses.archived) b.id};
    return branchIds.every(usable.contains) ? const {} : const {'branchIds': 'INVALID_BRANCH'};
  }

  bool _phoneTaken(String e164, {String? except}) => _assistants
      .any((a) => a.userId != except && a.status != AssistantStatuses.removed && a.phone == e164);

  String _newPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  @override
  Future<AssistantWithPassword> createAssistant(AssistantDraft draft) async {
    await _enter('createAssistant', doctorOnly: true);
    final phone = Validators.normalizeEgyptianMobile(draft.phone);
    final problems = {
      if (draft.fullName.trim().isEmpty)
        'fullName': 'REQUIRED'
      else if (!RegistrationRules.isFullName(draft.fullName))
        'fullName': 'INVALID_NAME',
      if (draft.phone.trim().isEmpty) 'phone': 'REQUIRED' else if (phone == null) 'phone': 'INVALID_MOBILE',
      ..._checkBranchIds(draft.allBranches, draft.branchIds),
    };
    if (problems.isNotEmpty) throw _fields(problems);
    if (_assistantCount >= assistantLimit) throw _error(409, ClinicAdminCodes.assistantLimitReached);
    if (_phoneTaken(phone!)) throw _error(409, ClinicAdminCodes.assistantPhoneTaken);
    final now = _now;
    final record = _Assistant(
      userId: 'dev-assistant-${now.microsecondsSinceEpoch}',
      fullName: RegistrationRules.collapseSpaces(draft.fullName),
      phone: phone,
      allBranches: draft.allBranches,
      branchIds: draft.allBranches ? <String>{} : {...draft.branchIds},
      permissions: _withDependencies(draft.permissions),
      mustChangePassword: true,
      createdAt: now,
    );
    _assistants.add(record);
    final password = lastTemporaryPassword = _newPassword();
    _log('assistantCreated', 'assistant', record.userId, details: {
      'preset': AssistantPreset.match(record.permissions),
      'allBranches': record.allBranches,
      'branchIds': record.branchIds.toList(),
      'permissions': [for (final key in ClinicPermission.all) if (record.permissions.contains(key)) key],
    });
    return AssistantWithPassword(assistant: _view(record), temporaryPassword: password);
  }

  @override
  Future<Assistant> updateAssistant(
    String assistantId, {
    String? fullName,
    String? phone,
    bool? allBranches,
    Set<String>? branchIds,
    Set<String>? permissions,
  }) async {
    await _enter('updateAssistant', doctorOnly: true);
    final e164 = phone == null ? null : Validators.normalizeEgyptianMobile(phone);
    final all = allBranches ?? (branchIds == null ? null : false);
    final problems = {
      if (fullName != null && !RegistrationRules.isFullName(fullName)) 'fullName': 'INVALID_NAME',
      if (phone != null && e164 == null) 'phone': 'INVALID_MOBILE',
      if (all != null) ..._checkBranchIds(all, branchIds ?? const {}),
    };
    if (problems.isNotEmpty) throw _fields(problems);
    final record = _assistantRecord(assistantId);
    if (record.status == AssistantStatuses.removed) throw _error(409, ClinicAdminCodes.assistantRemoved);
    if (e164 != null && _phoneTaken(e164, except: assistantId)) throw _error(409, ClinicAdminCodes.assistantPhoneTaken);
    final fields = <String>[];
    if (fullName != null && RegistrationRules.collapseSpaces(fullName) != record.fullName) {
      record.fullName = RegistrationRules.collapseSpaces(fullName);
      fields.add('fullName');
    }
    if (e164 != null && e164 != record.phone) {
      record.phone = e164;
      fields.add('phone');
    }
    if (all != null) {
      final ids = all ? <String>{} : {...?branchIds};
      if (all != record.allBranches || ids.length != record.branchIds.length || !ids.containsAll(record.branchIds)) {
        record
          ..allBranches = all
          ..branchIds = ids;
        fields.add('branches');
      }
    }
    if (fields.isNotEmpty) _log('assistantUpdated', 'assistant', assistantId, details: {'fields': fields});
    if (permissions != null) {
      final next = _withDependencies(permissions);
      final added = [for (final key in ClinicPermission.all) if (next.contains(key) && !record.permissions.contains(key)) key];
      final removed = [for (final key in ClinicPermission.all) if (!next.contains(key) && record.permissions.contains(key)) key];
      if (added.isNotEmpty || removed.isNotEmpty) {
        final presetBefore = AssistantPreset.match(record.permissions);
        record.permissions = next;
        _log('assistantPermissionsChanged', 'assistant', assistantId, details: {
          'added': added,
          'removed': removed,
          'presetBefore': presetBefore,
          'presetAfter': AssistantPreset.match(next),
        });
      }
    }
    record.updatedAt = _now;
    return _view(record);
  }

  @override
  Future<AssistantWithPassword> resetAssistantPassword(String assistantId) async {
    await _enter('resetAssistantPassword', doctorOnly: true);
    final record = _assistantRecord(assistantId);
    if (record.status == AssistantStatuses.removed) throw _error(409, ClinicAdminCodes.assistantRemoved);
    record
      ..mustChangePassword = true
      ..updatedAt = _now;
    final password = lastTemporaryPassword = _newPassword();
    _log('assistantPasswordReset', 'assistant', assistantId);
    return AssistantWithPassword(assistant: _view(record), temporaryPassword: password);
  }

  @override
  Future<Assistant> setAssistantStatus(String assistantId, String status) async {
    await _enter('setAssistantStatus', doctorOnly: true);
    final record = _assistantRecord(assistantId);
    if (record.status == AssistantStatuses.removed) throw _error(409, ClinicAdminCodes.assistantRemoved);
    if (record.status == status) return _view(record);
    record
      ..status = status
      ..updatedAt = _now
      ..removedAt = status == AssistantStatuses.removed ? _now : null;
    _log(
      switch (status) {
        AssistantStatuses.disabled => 'assistantDisabled',
        AssistantStatuses.removed => 'assistantRemoved',
        _ => 'assistantEnabled',
      },
      'assistant',
      assistantId,
    );
    return _view(record);
  }

  // ---------------------------------------------------------------------------
  // Activity log

  @override
  Future<ActivityPage> activity(ActivityFilter filter, {int page = 1, int pageSize = 25}) async {
    await _enter('activity', doctorOnly: true);
    final from = filter.from;
    final to = filter.to;
    bool inRange(DateTime at) {
      final cairo = at.add(const Duration(hours: 2));
      final day = DateTime(cairo.year, cairo.month, cairo.day);
      return (from == null || !day.isBefore(from)) && (to == null || !day.isAfter(to));
    }

    final rows = [
      for (final entry in _activity)
        if ((filter.actorUserId == null || entry.actor.userId == filter.actorUserId) &&
            (filter.action == null || entry.action == filter.action) &&
            (filter.patientId == null || entry.patient?.id == filter.patientId) &&
            inRange(entry.at))
          entry,
    ];
    final start = (page - 1) * pageSize;
    final people = [
      ActivityPerson(userId: doctorUserId, name: _profile.fullName, role: 'doctor'),
      for (final a in [..._assistants]..sort((a, b) {
          final removed = (a.status == AssistantStatuses.removed ? 1 : 0).compareTo(b.status == AssistantStatuses.removed ? 1 : 0);
          return removed != 0 ? removed : a.fullName.compareTo(b.fullName);
        }))
        ActivityPerson(userId: a.userId, name: a.fullName, role: 'assistant', status: a.status),
    ];
    return ActivityPage(
      page: Paged(
        items: rows.skip(start).take(pageSize).toList(),
        page: page,
        pageSize: pageSize,
        totalCount: rows.length,
        totalPages: (rows.length / pageSize).ceil(),
      ),
      people: people,
      actions: ({for (final entry in _activity) entry.action}.toList()..sort()),
    );
  }

  // ---------------------------------------------------------------------------
  // Sample data

  void _seed() {
    final now = _seededAt;
    DateTime ago({int days = 0, int hours = 0, int minutes = 0}) => now.subtract(Duration(days: days, hours: hours, minutes: minutes));

    // The doctor's name follows the signed-in doctor, like FakeClinicRepository.
    final session = currentSession?.call();
    final name = session != null && session.role == UserRole.doctor ? session.displayName.replaceFirst('د. ', '') : 'تجريبي';
    const internal = Specialty(id: 'sp-internal', nameAr: 'باطنة', nameEn: 'Internal Medicine');
    _profile = DoctorProfile(
      doctorId: doctorUserId,
      fullName: name,
      title: 'أخصائي',
      titleEn: 'Specialist',
      degreesAr: 'ماجستير الباطنة العامة، جامعة القاهرة',
      specialty: internal,
      specialtyId: internal.id,
      email: session?.email ?? 'doctor@el3yada.dev',
      phone: '+201001234567',
      licenseNumber: '45678',
      status: session?.doctorStatus == DoctorStatus.suspended ? 'suspended' : 'active',
      updatedAt: ago(days: 4),
    );

    List<BranchPeriod> week(List<int> days, List<BranchPeriod> Function(int day) periods) => [for (final d in days) ...periods(d)];

    _branches.addAll([
      _Branch(
        id: maadiBranchId,
        isDefault: true,
        info: const BranchInfo(nameAr: 'فرع المعادي', nameEn: 'Maadi', description: 'العيادة بالدور الثالث، المصعد بجوار الصيدلية.'),
        address: const BranchAddress(
          governorate: 'القاهرة',
          city: 'المعادي',
          area: 'دجلة',
          details: 'شارع 9، عمارة 15، الدور 3، شقة 7',
          landmark: 'بجوار محطة مترو المعادي',
          mapUrl: 'https://www.google.com/maps/search/?api=1&query=29.960306,31.257092',
        ),
        contact: const BranchContact(
          phones: [
            BranchContactPhone(number: '+20225251234', label: PhoneLabels.landline),
            BranchContactPhone(number: '+201012345678', label: PhoneLabels.mobile, isWhatsapp: true),
          ],
          email: 'maadi@clinic.example',
        ),
        periods: week(
          [DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday],
          (d) => [
            BranchPeriod(weekday: d, startLocal: '10:00', endLocal: '14:00', label: 'صباحي', capacity: 25),
            BranchPeriod(weekday: d, startLocal: '18:00', endLocal: '22:00', label: 'مسائي'),
          ],
        ),
        paymentMethods: const ['cash', 'instapay'],
        amenities: const ['elevator'],
        createdAt: ago(days: 120),
      ),
      _Branch(
        id: nasrCityBranchId,
        info: const BranchInfo(nameAr: 'فرع مدينة نصر', nameEn: 'Nasr City'),
        address: const BranchAddress(
          governorate: 'القاهرة',
          city: 'مدينة نصر',
          area: 'الحي السابع',
          details: '42 شارع عباس العقاد، الدور الأول\nالمدخل من الشارع الجانبي',
          landmark: 'أمام سيتي ستارز',
          mapUrl: 'https://maps.google.com/?q=30.0729,31.3456',
        ),
        contact: const BranchContact(phones: [BranchContactPhone(number: '+201112223344', label: PhoneLabels.reception, isWhatsapp: true)]),
        periods: [
          ...week([DateTime.saturday, DateTime.monday, DateTime.wednesday],
              (d) => [BranchPeriod(weekday: d, startLocal: '17:00', endLocal: '23:00', label: 'مسائي')]),
          const BranchPeriod(weekday: DateTime.thursday, startLocal: '20:00', endLocal: '01:00', endsNextDay: true, label: 'مسائي'),
        ],
        paymentMethods: const ['cash', 'card', 'wallet'],
        amenities: const ['parking', 'wheelchair'],
        examination: 40000,
        createdAt: ago(days: 60),
      ),
      _Branch(
        id: dokkiBranchId,
        status: BranchStatuses.archived,
        info: const BranchInfo(nameAr: 'فرع الدقي', nameEn: 'Dokki'),
        address: const BranchAddress(governorate: 'الجيزة', city: 'الدقي', area: 'ميدان المساحة', details: 'شارع التحرير، عمارة 12'),
        contact: const BranchContact(phones: [BranchContactPhone(number: '+20233351234', label: PhoneLabels.landline)]),
        paymentMethods: const ['cash'],
        createdAt: ago(days: 300),
      ),
    ]);

    final today = DateTime(now.year, now.month, now.day);
    bookings[nasrCityBranchId] = [
      BranchBooking(
        id: 'dev-booking-1',
        localDate: today.add(const Duration(days: 2)),
        periodStartLocal: '17:00',
        status: 'confirmed',
        visitType: 'examination',
        name: 'ضيف: كريم عادل',
        isGuest: true,
      ),
      BranchBooking(
        id: 'dev-booking-2',
        localDate: today.add(const Duration(days: 5)),
        periodStartLocal: '17:00',
        status: 'pending',
        visitType: 'consultation',
        patientId: 'dev-patient-mona',
        name: 'منى حسن',
      ),
    ];

    _assistants.addAll([
      _Assistant(
        userId: receptionUserId,
        fullName: 'مساعد تجريبي',
        phone: '+201000000001',
        branchIds: {maadiBranchId},
        permissions: {...AssistantPreset.permissions[AssistantPreset.reception]!},
        lastActiveAt: ago(minutes: 12),
        createdAt: ago(days: 40),
      ),
      _Assistant(
        userId: officeManagerUserId,
        fullName: 'مدير العيادة',
        phone: '+201000000005',
        allBranches: true,
        permissions: {...AssistantPreset.permissions[AssistantPreset.officeManager]!},
        lastActiveAt: ago(hours: 5),
        createdAt: ago(days: 30),
      ),
      _Assistant(
        userId: disabledAssistantId,
        fullName: 'منى سمير',
        phone: '+201223334445',
        branchIds: {nasrCityBranchId},
        permissions: {...AssistantPreset.permissions[AssistantPreset.reception]!, ClinicPermission.chat},
        status: AssistantStatuses.disabled,
        lastActiveAt: ago(days: 9),
        createdAt: ago(days: 20),
      ),
      _Assistant(
        userId: removedAssistantId,
        fullName: 'هبة علي',
        phone: '+201554443332',
        branchIds: {maadiBranchId},
        permissions: {...AssistantPreset.permissions[AssistantPreset.reception]!},
        status: AssistantStatuses.removed,
        removedAt: ago(days: 15),
        createdAt: ago(days: 90),
      ),
    ]);

    final doctor = ActivityActor(userId: doctorUserId, name: _profile.fullName, role: 'doctor');
    final reception = ActivityActor(userId: receptionUserId, name: 'مساعد تجريبي', role: 'assistant');
    final manager = ActivityActor(userId: officeManagerUserId, name: 'مدير العيادة', role: 'assistant');
    final heba = ActivityActor(userId: removedAssistantId, name: 'هبة علي', role: 'assistant');
    const mona = ActivityPatient(id: 'dev-patient-mona', name: 'منى حسن', fileNumber: 17);
    const karim = ActivityPatient(id: 'dev-patient-karim', name: 'كريم عادل', fileNumber: 18);
    var id = 800;
    ActivityEntry row(DateTime at, ActivityActor actor, String action, String target, String? targetId,
            {Map<String, dynamic> details = const {}, ActivityPatient? patient}) =>
        ActivityEntry(
            id: ++id, at: at, actor: actor, action: action, targetType: target, targetId: targetId, patient: patient, details: details);

    _activity.addAll([
      row(ago(minutes: 15), reception, 'patientCreated', 'patient', karim.id, patient: karim, details: {'fileNumber': 18}),
      row(ago(minutes: 40), reception, 'sessionCreated', 'session', 'dev-session-1', patient: mona, details: {'type': 'examination'}),
      row(ago(hours: 2), doctor, 'branchHoursUpdated', 'branch', maadiBranchId, details: {'periods': 12}),
      row(ago(hours: 5), manager, 'pricesUpdated', 'branch', nasrCityBranchId, details: {
        'branchId': nasrCityBranchId,
        'before': {'examinationPricePiasters': null, 'consultationPricePiasters': null},
        'after': {'examinationPricePiasters': 40000, 'consultationPricePiasters': null},
      }),
      row(ago(days: 1, hours: 2), doctor, 'assistantPermissionsChanged', 'assistant', disabledAssistantId, details: {
        'added': ['chat'],
        'removed': <String>[],
        'presetBefore': 'reception',
        'presetAfter': 'custom',
      }),
      row(ago(days: 2), doctor, 'pricesUpdated', 'doctor', doctorUserId, details: {
        'branchId': null,
        'before': {'examinationPricePiasters': 25000, 'consultationPricePiasters': 15000},
        'after': {'examinationPricePiasters': 30000, 'consultationPricePiasters': 15000},
      }),
      row(ago(days: 3), doctor, 'branchStatusChanged', 'branch', dokkiBranchId, details: {'before': 'active', 'after': 'archived'}),
      row(ago(days: 3, hours: 4), const ActivityActor(role: 'system'), 'passwordResetRequested', 'assistant', receptionUserId,
          details: {'channel': 'doctor'}),
      row(ago(days: 4), doctor, 'doctorProfileUpdated', 'doctor', doctorUserId, details: {'fields': ['degreesAr']}),
      row(ago(days: 16), heba, 'patientCreated', 'patient', mona.id, patient: mona, details: {'fileNumber': 17}),
      row(ago(days: 20), doctor, 'assistantCreated', 'assistant', disabledAssistantId, details: {'preset': 'reception'}),
      row(ago(days: 30), doctor, 'assistantCreated', 'assistant', officeManagerUserId, details: {'preset': 'officeManager'}),
    ]);

    _history.addAll([
      PriceHistoryEntry(
        id: 'dev-price-2',
        changedAt: ago(hours: 5),
        changedBy: PriceChangedBy(userId: officeManagerUserId, name: 'مدير العيادة', role: 'assistant'),
        branchId: nasrCityBranchId,
        branchNameAr: 'فرع مدينة نصر',
        branchNameEn: 'Nasr City',
        before: const PricePair(),
        after: const PricePair(examinationPricePiasters: 40000),
      ),
      PriceHistoryEntry(
        id: 'dev-price-1',
        changedAt: ago(days: 2),
        changedBy: PriceChangedBy(userId: doctorUserId, name: _profile.fullName, role: 'doctor'),
        before: const PricePair(examinationPricePiasters: 25000, consultationPricePiasters: 15000),
        after: const PricePair(examinationPricePiasters: 30000, consultationPricePiasters: 15000),
      ),
    ]);
  }
}

class _Branch {
  _Branch({
    required this.id,
    required this.info,
    required this.address,
    required this.contact,
    required this.createdAt,
    this.isDefault = false,
    this.status = BranchStatuses.active,
    this.periods = const [],
    this.paymentMethods = const ['cash'],
    this.amenities = const [],
    this.examination,
  }) : updatedAt = createdAt;

  final String id;
  bool isDefault;
  String status;
  String? closedMessage;
  DateTime? reopenDate;
  BranchInfo info;
  BranchAddress address;
  BranchContact contact;
  List<BranchPeriod> periods;
  List<String> paymentMethods;
  List<String> amenities;
  int? examination;
  int? consultation;
  final DateTime createdAt;
  DateTime updatedAt;
}

class _Assistant {
  _Assistant({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.permissions,
    required this.createdAt,
    this.allBranches = false,
    this.branchIds = const {},
    this.status = AssistantStatuses.active,
    this.mustChangePassword = false,
    this.lastActiveAt,
    this.removedAt,
  }) : updatedAt = createdAt;

  final String userId;
  String fullName;
  String phone;
  bool allBranches;
  Set<String> branchIds;
  Set<String> permissions;
  String status;
  bool mustChangePassword;
  DateTime? lastActiveAt;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? removedAt;
}
