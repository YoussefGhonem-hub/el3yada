import 'dart:math';
import 'dart:typed_data';

import '../../../core/network/api_exception.dart';
import '../../../core/validation/validators.dart';
import '../domain/admin_models.dart';
import '../domain/setting_fields.dart';
import 'admin_repository.dart';
import 'sample_license.dart';

/// Who is signed in, for the fake: `(userId, displayName, email, isSuperAdmin)`.
typedef FakeCurrentAdmin = (String, String, String?, bool)? Function();

/// Offline admin data for dev builds and tests (`USE_FAKE_AUTH`), with the
/// same rules and error codes as the API: pending sign-ups with image and
/// PDF licenses, settings with history, admins and audit rows. Every write
/// changes the data, so the screens behave as they will against the API.
///
/// Tests can make the next call of a method fail with [failNext].
class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository({
    this.delay = const Duration(milliseconds: 400),
    this.currentAdmin,
    DateTime? now,
  }) : _seededAt = (now ?? DateTime.now()).toUtc() {
    _seed();
  }

  final Duration delay;

  /// The signed-in admin; null makes a super admin called "Admin".
  final FakeCurrentAdmin? currentAdmin;
  final DateTime _seededAt;
  final _failures = <String, ApiException>{};

  /// The password the last [createAdmin] returned (for tests).
  String? lastTemporaryPassword;

  /// How many times each method was called (for tests).
  final calls = <String, int>{};

  /// The changes sent by the last [updateSettings] (for tests).
  Map<String, Object?>? lastSettingsUpdate;

  /// Makes the next call to [method] (for example `'setAdminRole'`) throw [error].
  void failNext(String method, ApiException error) => _failures[method] = error;

  final _registrations = <String, _FakeRegistration>{};
  final _admins = <AdminUser>[];
  final _audit = <AuditEntry>[];
  final _history = <SettingsHistoryEntry>[];
  late Map<String, Object?> _settings;
  DateTime? _settingsUpdatedAt;
  String? _settingsUpdatedBy;
  int _nextId = 1000;

  DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      _seededAt.subtract(Duration(days: days, hours: hours, minutes: minutes));

  DateTime get _now => DateTime.now().toUtc();

  Future<void> _step(String method) async {
    calls[method] = (calls[method] ?? 0) + 1;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = _failures.remove(method);
    if (failure != null) throw failure;
  }

  static ApiException _error(int status, String code, [Map<String, String> fields = const {}]) =>
      ApiException(kind: ApiErrorKind.http, status: status, code: code, fieldCodes: fields);

  static ApiException _invalid(Map<String, String> fields) => _error(400, ApiCodes.validationFailed, fields);

  // ---------------------------------------------------------------------------
  // Signed-in admin

  AdminUser get _me {
    final current = currentAdmin?.call();
    final id = current?.$1 ?? 'admin-me';
    final existing = _admins.where((a) => a.userId == id).firstOrNull;
    if (existing != null) return existing;
    final me = AdminUser(
      userId: id,
      displayName: current?.$2 ?? 'Admin',
      email: current?.$3 ?? 'admin@el3yada.dev',
      adminRole: current == null || current.$4 ? AdminRole.superAdmin : AdminRole.admin,
      status: 'active',
      createdAt: _ago(days: 120),
      lastLoginAt: _ago(minutes: 2),
    );
    _admins.insert(0, me);
    return me;
  }

  void _addAudit(
    String action,
    String targetType, {
    String? targetId,
    Map<String, dynamic>? details,
    String? doctorId,
    DateTime? at,
    AdminUser? actor,
    String? actorRole,
    String? actorId,
    String? actorName,
  }) {
    final who = actor ?? (actorRole == null ? _me : null);
    _audit.add(AuditEntry(
      id: _nextId++,
      at: at ?? _now,
      actorUserId: who?.userId ?? actorId,
      actorRole: who == null ? actorRole! : 'admin',
      actorName: who?.displayName ?? actorName,
      action: action,
      targetType: targetType,
      targetId: targetId,
      doctorId: doctorId,
      details: details,
    ));
  }

  // ---------------------------------------------------------------------------
  // AD2, AD3

  @override
  Future<Paged<RegistrationSummary>> doctorRegistrations({
    String? search,
    String sort = 'newest',
    int page = 1,
    int pageSize = 25,
  }) async {
    await _step('doctorRegistrations');
    final query = Validators.normalizeDigits(search?.trim() ?? '').toLowerCase();
    final mobile = Validators.normalizeEgyptianMobile(query);
    final rows = _registrations.values.where((r) {
      final reg = r.registration;
      if (!reg.isPending) return false;
      if (query.isEmpty) return true;
      return reg.fullName.contains(query) ||
          (reg.fullNameEn?.toLowerCase().contains(query) ?? false) ||
          (reg.email?.contains(query) ?? false) ||
          reg.licenseNumber.contains(query) ||
          (mobile != null && reg.phone == mobile);
    }).toList()
      ..sort((a, b) => sort == 'oldest'
          ? a.registration.submittedAt.compareTo(b.registration.submittedAt)
          : b.registration.submittedAt.compareTo(a.registration.submittedAt));
    return _page(
      [
        for (final r in rows)
          RegistrationSummary(
            doctorId: r.registration.doctorId,
            fullName: r.registration.fullName,
            title: r.registration.title,
            specialty: r.registration.specialty,
            governorate: r.registration.branch?.governorate,
            city: r.registration.branch?.city,
            status: r.registration.status,
            submittedAt: r.registration.submittedAt,
            createdAt: r.createdAt,
            emailVerified: r.registration.emailVerified,
          ),
      ],
      page,
      pageSize,
    );
  }

  @override
  Future<RegistrationDetail> doctorRegistration(String doctorId) async {
    await _step('doctorRegistration');
    final r = _registrations[doctorId] ?? (throw _error(404, 'NOT_FOUND'));
    return RegistrationDetail(registration: r.registration, reviews: List.of(r.reviews.reversed));
  }

  @override
  Future<LicenseFile> doctorLicense(String doctorId) async {
    await _step('doctorLicense');
    final r = _registrations[doctorId] ?? (throw _error(404, 'NOT_FOUND'));
    final reg = r.registration;
    if (r.licenseMissing) throw _error(404, 'LICENSE_FILE_MISSING');
    _addAudit('doctorLicenseViewed', 'doctor', targetId: doctorId, doctorId: doctorId);
    return LicenseFile(
      contentType: reg.licenseContentType,
      bytes: r.license ??= reg.licenseContentType == 'application/pdf'
          ? SampleLicense.pdf(name: reg.fullNameEn ?? 'Doctor', number: reg.licenseNumber)
          : SampleLicense.png(seed: reg.licenseNumber.hashCode),
    );
  }

  @override
  Future<DoctorRegistration> reviewDoctorRegistration({
    required String doctorId,
    required ReviewDecision decision,
    String? reason,
  }) async {
    await _step('reviewDoctorRegistration');
    final r = _registrations[doctorId] ?? (throw _error(404, 'NOT_FOUND'));
    final text = reason?.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (decision == ReviewDecision.reject && (text == null || text.length < 3)) {
      throw _invalid({'reason': 'REASON_REQUIRED'});
    }
    if (text != null && text.length > 500) throw _invalid({'reason': 'TOO_LONG'});
    if (!r.registration.isPending) throw _error(409, 'REGISTRATION_NOT_PENDING');

    final approve = decision == ReviewDecision.approve;
    r.registration = r.registration.withStatus(
      approve ? DoctorStatuses.active : DoctorStatuses.rejected,
      statusReason: approve ? null : text,
    );
    r.reviews.add(RegistrationReview(decision: decision, reason: approve ? null : text, reviewedByName: _me.displayName, at: _now));
    _addAudit(
      approve ? 'doctorRegistrationApproved' : 'doctorRegistrationRejected',
      'doctor',
      targetId: doctorId,
      doctorId: doctorId,
      details: approve ? null : {'reason': text},
    );
    return r.registration;
  }

  // ---------------------------------------------------------------------------
  // BR-G4 (AD5 comes in Phase 7)

  @override
  Future<DoctorStatusView> setDoctorStatus(String doctorId, {required bool suspended, required String reason}) async {
    await _step('setDoctorStatus');
    final r = _registrations[doctorId] ?? (throw _error(404, 'NOT_FOUND'));
    final text = reason.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.length < 3) throw _invalid({'reason': 'REASON_REQUIRED'});
    if (text.length > 500) throw _invalid({'reason': 'TOO_LONG'});
    final current = r.registration.status;
    final target = suspended ? DoctorStatuses.suspended : DoctorStatuses.active;
    if (current != target) {
      if (current != DoctorStatuses.active && current != DoctorStatuses.suspended) {
        throw ApiException(
          kind: ApiErrorKind.http,
          status: 409,
          code: 'DOCTOR_STATUS_NOT_CHANGEABLE',
          details: {'code': 'DOCTOR_STATUS_NOT_CHANGEABLE', 'status': current},
        );
      }
      r.registration = r.registration.withStatus(target, statusReason: suspended ? text : null);
      r.statusChangedAt = _now;
      _addAudit(
        suspended ? 'doctorSuspended' : 'doctorReactivated',
        'doctor',
        targetId: doctorId,
        doctorId: doctorId,
        details: {'before': current, 'after': target, 'reason': text},
      );
    }
    final reg = r.registration;
    return DoctorStatusView(
      doctorId: doctorId,
      fullName: reg.fullName,
      status: reg.status,
      statusReason: reg.statusReason,
      statusChangedAt: r.statusChangedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // AD14

  void _requireSuperAdmin() {
    if (!_me.isSuperAdmin) throw _error(403, 'FORBIDDEN');
  }

  int _indexOf(String userId) {
    final index = _admins.indexWhere((a) => a.userId == userId);
    if (index < 0) throw _error(404, 'NOT_FOUND');
    return index;
  }

  bool _isOnlyActiveSuperAdmin(AdminUser admin) =>
      admin.isSuperAdmin &&
      admin.isActive &&
      !_admins.any((a) => a.userId != admin.userId && a.isSuperAdmin && a.isActive);

  @override
  Future<List<AdminUser>> admins() async {
    await _step('admins');
    _requireSuperAdmin();
    return List.of(_admins)..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<CreatedAdmin> createAdmin({required String email, required String displayName, required AdminRole role}) async {
    await _step('createAdmin');
    _requireSuperAdmin();
    final address = email.trim().toLowerCase();
    final name = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final errors = {
      if (!Validators.isEmail(address)) 'email': 'INVALID_EMAIL',
      if (!_isFullName(name)) 'displayName': 'INVALID_NAME',
    };
    if (errors.isNotEmpty) throw _invalid(errors);
    if (_admins.any((a) => a.email == address) || address.endsWith('@el3yada.dev') && address.startsWith('doctor')) {
      throw _error(409, 'EMAIL_ALREADY_REGISTERED');
    }
    final admin = AdminUser(
      userId: 'admin-${_nextId++}',
      displayName: name,
      email: address,
      adminRole: role,
      status: 'active',
      mustChangePassword: true,
      createdAt: _now,
    );
    _admins.add(admin);
    _addAudit('adminCreated', 'user', targetId: admin.userId, details: {'adminRole': role.name});
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final random = Random.secure();
    String pick() => alphabet[random.nextInt(alphabet.length)];
    // At least one letter and one digit, like the API's temporary passwords.
    final password = '${List.generate(10, (_) => pick()).join()}${alphabet[random.nextInt(24)]}${random.nextInt(8) + 2}';
    lastTemporaryPassword = password;
    return CreatedAdmin(admin: admin, temporaryPassword: password);
  }

  @override
  Future<AdminUser> setAdminRole(String userId, AdminRole role) async {
    await _step('setAdminRole');
    _requireSuperAdmin();
    if (userId == _me.userId) throw _error(409, 'CANNOT_CHANGE_OWN_ROLE');
    final index = _indexOf(userId);
    final admin = _admins[index];
    if (admin.adminRole == role) return admin;
    if (_isOnlyActiveSuperAdmin(admin)) throw _error(409, 'LAST_SUPER_ADMIN');
    _admins[index] = admin.copyWith(adminRole: role);
    _addAudit('adminRoleChanged', 'user', targetId: userId, details: {'before': admin.adminRole.name, 'after': role.name});
    return _admins[index];
  }

  @override
  Future<AdminUser> setAdminStatus(String userId, {required bool active}) async {
    await _step('setAdminStatus');
    _requireSuperAdmin();
    if (userId == _me.userId) throw _error(409, 'CANNOT_DISABLE_SELF');
    final index = _indexOf(userId);
    final admin = _admins[index];
    if (admin.isActive == active) return admin;
    if (!active && _isOnlyActiveSuperAdmin(admin)) throw _error(409, 'LAST_SUPER_ADMIN');
    _admins[index] = admin.copyWith(status: active ? 'active' : 'disabled');
    _addAudit(active ? 'adminEnabled' : 'adminDisabled', 'user', targetId: userId);
    return _admins[index];
  }

  // ---------------------------------------------------------------------------
  // AD18

  @override
  Future<AdminProfile> profile() async {
    await _step('profile');
    return AdminProfile(admin: _me);
  }

  @override
  Future<AdminProfile> updateAdminProfile(String displayName) async {
    await _step('updateAdminProfile');
    final name = displayName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) throw _invalid({'displayName': 'REQUIRED'});
    if (!_isFullName(name)) throw _invalid({'displayName': 'INVALID_NAME'});
    final index = _indexOf(_me.userId);
    _admins[index] = _admins[index].copyWith(displayName: name);
    _addAudit('adminProfileUpdated', 'user', targetId: _me.userId);
    return AdminProfile(admin: _admins[index]);
  }

  static bool _isFullName(String name) =>
      name.length >= 2 && name.length <= 60 && RegExp(r'^[\p{L}\p{M}]+( [\p{L}\p{M}]+)+$', unicode: true).hasMatch(name);

  // ---------------------------------------------------------------------------
  // AD15

  @override
  Future<Paged<AuditEntry>> auditLogs(AuditFilter filter, {int page = 1, int pageSize = 25}) async {
    await _step('auditLogs');
    final rows = _audit.where((row) {
      if (filter.action != null && row.action != filter.action) return false;
      if (filter.actorRole != null && row.actorRole != filter.actorRole) return false;
      if (filter.actorUserId != null && row.actorUserId != filter.actorUserId) return false;
      if (filter.targetType != null && row.targetType != filter.targetType) return false;
      if (filter.targetId != null && row.targetId != filter.targetId) return false;
      if (filter.from != null && row.at.isBefore(filter.from!)) return false;
      if (filter.to != null && !row.at.isBefore(filter.to!)) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final byTime = b.at.compareTo(a.at);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    return _page(rows, page, pageSize);
  }

  // ---------------------------------------------------------------------------
  // AD13

  PlatformSettings _settingsView() => PlatformSettings(
        values: Map.of(_settings),
        updatedAt: _settingsUpdatedAt,
        updatedByName: _settingsUpdatedBy,
      );

  @override
  Future<PlatformSettings> settings() async {
    await _step('settings');
    return _settingsView();
  }

  @override
  Future<PlatformSettings> updateSettings(Map<String, Object?> changes) async {
    lastSettingsUpdate = Map.of(changes);
    await _step('updateSettings');
    if (changes.isEmpty) throw _invalid({'body': 'REQUIRED'});
    final errors = <String, String>{};
    for (final MapEntry(key: name, :value) in changes.entries) {
      final field = SettingFields.byName[name];
      if (field == null) {
        errors[name] = 'UNKNOWN_SETTING';
        continue;
      }
      final problem = switch (field.kind) {
        SettingKind.boolean => value is bool ? null : SettingProblem.notNumber,
        SettingKind.money || SettingKind.integer =>
          value is int ? (value < field.min || value > field.max ? SettingProblem.outOfRange : null) : SettingProblem.notNumber,
        _ => value == null || value is String ? field.check('${value ?? ''}') : SettingProblem.notNumber,
      };
      if (problem != null) {
        errors[name] = switch (problem) {
          SettingProblem.required => 'REQUIRED',
          SettingProblem.outOfRange => 'OUT_OF_RANGE',
          SettingProblem.tooLong => 'TOO_LONG',
          SettingProblem.invalidEmail => 'INVALID_EMAIL',
          SettingProblem.invalidPhone => 'INVALID_PHONE',
          SettingProblem.invalidVersion => 'INVALID_VERSION',
          SettingProblem.notNumber => 'INVALID_VALUE',
        };
      }
    }
    if (errors.isNotEmpty) throw _invalid(errors);

    final changed = <String>[];
    for (final MapEntry(key: name, :value) in changes.entries) {
      final stored = value is String && value.trim().isEmpty ? null : (value is String ? value.trim() : value);
      final before = _settings[name];
      if (before == stored) continue;
      _settings[name] = stored;
      _history.add(SettingsHistoryEntry(
        id: 'history-${_nextId++}',
        field: name,
        before: before?.toString(),
        after: stored?.toString(),
        changedByName: _me.displayName,
        changedAt: _now,
      ));
      changed.add(name);
    }
    if (changed.isNotEmpty) {
      _settingsUpdatedAt = _now;
      _settingsUpdatedBy = _me.displayName;
      _addAudit('settingsUpdated', 'settings', targetId: '1', details: {'fields': changed});
    }
    return _settingsView();
  }

  @override
  Future<Paged<SettingsHistoryEntry>> settingsHistory({String? field, int page = 1, int pageSize = 25}) async {
    await _step('settingsHistory');
    if (field != null && !SettingFields.byName.containsKey(field)) throw _invalid({'field': 'UNKNOWN_SETTING'});
    String? cut(String? value) => value != null && value.length > 300 ? '${value.substring(0, 300)}…' : value;
    final rows = [
      for (final entry in _history.reversed)
        if (field == null || entry.field == field)
          SettingsHistoryEntry(
            id: entry.id,
            field: entry.field,
            before: cut(entry.before),
            after: cut(entry.after),
            truncated: (entry.before?.length ?? 0) > 300 || (entry.after?.length ?? 0) > 300,
            changedByName: entry.changedByName,
            changedAt: entry.changedAt,
          ),
    ];
    return _page(rows, page, pageSize);
  }

  @override
  Future<SettingsHistoryEntry> settingsHistoryEntry(String id) async {
    await _step('settingsHistoryEntry');
    return _history.where((e) => e.id == id).firstOrNull ?? (throw _error(404, 'NOT_FOUND'));
  }

  static Paged<T> _page<T>(List<T> rows, int page, int pageSize) {
    final start = min((page - 1) * pageSize, rows.length);
    return Paged(
      items: rows.sublist(start, min(start + pageSize, rows.length)),
      page: page,
      pageSize: pageSize,
      totalCount: rows.length,
      totalPages: rows.isEmpty ? 0 : (rows.length / pageSize).ceil(),
    );
  }

  // ---------------------------------------------------------------------------
  // Sample data

  void _seed() {
    const internal = SpecialtyRef(id: 'sp-internal', nameAr: 'باطنة', nameEn: 'Internal Medicine');
    const pediatrics = SpecialtyRef(id: 'sp-pediatrics', nameAr: 'أطفال وحديثي الولادة', nameEn: 'Pediatrics');
    const obgyn = SpecialtyRef(id: 'sp-obgyn', nameAr: 'نساء وتوليد', nameEn: 'Obstetrics and Gynecology');
    const ortho = SpecialtyRef(id: 'sp-ortho', nameAr: 'عظام', nameEn: 'Orthopedics');
    const derma = SpecialtyRef(id: 'sp-derma', nameAr: 'جلدية', nameEn: 'Dermatology');
    const cardio = SpecialtyRef(id: 'sp-cardio', nameAr: 'قلب وأوعية دموية', nameEn: 'Cardiology');
    const dentistry = SpecialtyRef(id: 'sp-dentistry', nameAr: 'أسنان', nameEn: 'Dentistry');
    const diabetes = SpecialtyRef(id: 'sp-diabetes', nameAr: 'غدد صماء وسكر', nameEn: 'Endocrinology and Diabetes');

    void add(DoctorRegistration registration, {List<RegistrationReview> reviews = const [], DateTime? createdAt}) {
      _registrations[registration.doctorId] = _FakeRegistration(
        registration,
        createdAt ?? registration.submittedAt,
        reviews: List.of(reviews),
      );
    }

    add(DoctorRegistration(
      doctorId: 'doc-sami',
      status: DoctorStatuses.pendingApproval,
      submittedAt: _ago(hours: 2, minutes: 5),
      fullName: 'سامي عبد الله منصور',
      fullNameEn: 'Sami Abdallah Mansour',
      email: 'sami.mansour@example.com',
      emailVerified: false,
      phone: '+201012345678',
      title: 'استشاري',
      titleEn: 'Consultant',
      specialty: internal,
      extraSpecialties: const [diabetes],
      licenseNumber: '45678',
      licenseContentType: 'image/png',
      degreesAr: 'ماجستير الباطنة العامة — جامعة القاهرة\nزمالة الكلية الملكية للأطباء (لندن)',
      degreesEn: 'MSc Internal Medicine, Cairo University; MRCP (London)',
      examinationPricePiasters: 30000,
      consultationPricePiasters: 15000,
      branch: const RegistrationBranch(
        nameAr: 'فرع المعادي',
        nameEn: 'Maadi branch',
        governorate: 'القاهرة',
        city: 'المعادي',
        area: 'دجلة',
        street: 'شارع 9',
        building: '14',
        floor: '3',
        apartment: '7',
        landmark: 'بجوار محطة مترو المعادي',
        lat: 29.9602,
        lng: 31.2569,
        email: 'maadi.clinic@example.com',
        phones: [
          BranchPhone(number: '+20223581234', label: 'landline'),
          BranchPhone(number: '+201012345678', label: 'mobile', isWhatsapp: true),
        ],
      ),
    ));
    add(DoctorRegistration(
      doctorId: 'doc-mona',
      status: DoctorStatuses.pendingApproval,
      submittedAt: _ago(minutes: 35),
      fullName: 'منى حسن الشريف',
      email: 'mona.elsherif@example.com',
      phone: '+201112223344',
      title: 'أخصائي',
      specialty: pediatrics,
      licenseNumber: '78-2201',
      licenseContentType: 'application/pdf',
      examinationPricePiasters: 25000,
      branch: const RegistrationBranch(
        nameAr: 'عيادة الدقي',
        governorate: 'الجيزة',
        city: 'الدقي',
        street: 'شارع التحرير',
        building: '102',
        floor: '5',
        phones: [BranchPhone(number: '+201112223344', label: 'reception', isWhatsapp: true)],
      ),
    ));
    add(
      DoctorRegistration(
        doctorId: 'doc-karim',
        status: DoctorStatuses.pendingApproval,
        submittedAt: _ago(days: 1, hours: 3),
        fullName: 'كريم مصطفى عبد الحميد',
        fullNameEn: 'Karim Mostafa',
        email: 'karim.derma@example.com',
        phone: '+201222334455',
        title: 'أستاذ',
        titleEn: 'Professor',
        specialty: derma,
        licenseNumber: '31207',
        licenseContentType: 'image/png',
        degreesAr: 'دكتوراه الأمراض الجلدية — جامعة الإسكندرية',
        examinationPricePiasters: 50000,
        consultationPricePiasters: 25000,
        branch: const RegistrationBranch(
          nameAr: 'مركز سموحة للجلدية',
          governorate: 'الإسكندرية',
          city: 'سموحة',
          street: 'شارع فوزي معاذ',
          landmark: 'أمام نادي سموحة',
          phones: [
            BranchPhone(number: '+2034251234', label: 'landline'),
            BranchPhone(number: '19567', label: 'reception'),
          ],
        ),
      ),
      createdAt: _ago(days: 4),
      reviews: [
        RegistrationReview(
          decision: ReviewDecision.reject,
          reason: 'صورة كارنيه النقابة غير واضحة، برجاء رفع صورة أوضح.',
          reviewedByName: 'نور عادل',
          at: _ago(days: 3, hours: 2),
        ),
      ],
    );
    add(DoctorRegistration(
      doctorId: 'doc-reem',
      status: DoctorStatuses.pendingApproval,
      submittedAt: _ago(days: 3, hours: 6),
      fullName: 'ريم السيد إبراهيم',
      email: 'reem.dent@example.com',
      phone: '+201033344455',
      title: 'أخصائي',
      specialty: dentistry,
      licenseNumber: '11902',
      licenseContentType: 'application/pdf',
      examinationPricePiasters: 20000,
      consultationPricePiasters: 10000,
      branch: const RegistrationBranch(
        nameAr: 'عيادة ابتسامة',
        governorate: 'الدقهلية',
        city: 'المنصورة',
        street: 'شارع الجمهورية',
        phones: [BranchPhone(number: '+20502241234', label: 'landline')],
      ),
    ));
    add(DoctorRegistration(
      doctorId: 'doc-ahmed',
      status: DoctorStatuses.pendingApproval,
      submittedAt: _ago(days: 6, hours: 1),
      fullName: 'أحمد فؤاد سليمان',
      email: 'ahmed.fouad@example.com',
      phone: '+201555667788',
      title: 'استشاري',
      specialty: ortho,
      licenseNumber: '55120',
      licenseContentType: 'image/png',
      branch: const RegistrationBranch(
        nameAr: 'عيادة بنها',
        governorate: 'القليوبية',
        city: 'بنها',
        street: 'شارع فريد ندا',
        phones: [BranchPhone(number: '+201555667788', label: 'mobile', isWhatsapp: true)],
      ),
    ));
    add(DoctorRegistration(
      doctorId: 'doc-heba',
      status: DoctorStatuses.pendingApproval,
      submittedAt: _ago(days: 12),
      fullName: 'هبة عادل رشدي',
      fullNameEn: 'Heba Adel Roshdy',
      email: 'heba.roshdy@example.com',
      phone: '+201066778899',
      title: 'أخصائي',
      titleEn: 'Specialist',
      specialty: obgyn,
      licenseNumber: '60213',
      licenseContentType: 'image/png',
      examinationPricePiasters: 35000,
      consultationPricePiasters: 20000,
      branch: const RegistrationBranch(
        nameAr: 'عيادة أسيوط',
        governorate: 'أسيوط',
        city: 'أسيوط',
        street: 'شارع الجمهورية',
        phones: [BranchPhone(number: '+20882331234', label: 'landline')],
      ),
    ));
    add(DoctorRegistration(
      doctorId: 'doc-tarek',
      status: DoctorStatuses.active,
      submittedAt: _ago(days: 9),
      fullName: 'طارق محمود جلال',
      email: 'tarek.cardio@example.com',
      phone: '+201099887766',
      title: 'استشاري',
      specialty: cardio,
      licenseNumber: '40110',
      licenseContentType: 'image/png',
    ));

    final nour = AdminUser(
      userId: 'admin-nour',
      displayName: 'نور عادل',
      email: 'nour@el3yada.dev',
      adminRole: AdminRole.superAdmin,
      status: 'active',
      createdAt: _ago(days: 90),
      lastLoginAt: _ago(hours: 5),
    );
    final mostafa = AdminUser(
      userId: 'admin-mostafa',
      displayName: 'مصطفى كامل',
      email: 'mostafa@el3yada.dev',
      adminRole: AdminRole.admin,
      status: 'active',
      createdAt: _ago(days: 60),
      lastLoginAt: _ago(days: 1, hours: 4),
    );
    _admins.addAll([
      nour,
      mostafa,
      AdminUser(
        userId: 'admin-salma',
        displayName: 'سلمى إبراهيم',
        email: 'salma@el3yada.dev',
        adminRole: AdminRole.admin,
        status: 'disabled',
        createdAt: _ago(days: 45),
        lastLoginAt: _ago(days: 20),
      ),
      AdminUser(
        userId: 'admin-yasser',
        displayName: 'ياسر محمود',
        email: 'yasser@el3yada.dev',
        adminRole: AdminRole.admin,
        status: 'active',
        mustChangePassword: true,
        createdAt: _ago(days: 2),
      ),
    ]);

    _settings = {
      'examFeePiasters': 3000,
      'consultationFeePiasters': 1500,
      'gracePeriodDays': 7,
      'maxConsecutiveConsultations': 2,
      'instapayAddress': 'el3yada@instapay',
      'instapayAccountName': 'El3yada Health Tech',
      'instapayInstructionsAr': 'حوّل قيمة الفاتورة على عنوان إنستاباي ثم ارفع صورة التحويل من شاشة الفواتير.',
      'instapayInstructionsEn': 'Send the invoice total to the InstaPay address, then upload the receipt from Billing.',
      'maxUploadMb': 50,
      'maxAssistantsPerDoctor': 5,
      'maxBranchesPerDoctor': 5,
      'supportPhone': '+20223581234',
      'supportWhatsapp': '+201000000000',
      'supportEmail': 'help@el3yada.app',
      'minVersionAndroid': '1.0.0',
      'minVersionIos': '1.0.0',
      'minVersionWindows': '1.0.0',
      'minVersionMacos': '0.0.0',
      'maintenanceEnabled': false,
      'maintenanceMessageAr': 'التطبيق تحت الصيانة، حاول مرة أخرى بعد قليل.',
      'maintenanceMessageEn': 'The app is under maintenance. Please try again shortly.',
      'termsAr': 'باستخدامك تطبيق «العيادة» فإنك توافق على هذه الشروط.\n\n1. الحساب شخصي ولا يجوز مشاركته.\n'
          '2. يلتزم الطبيب بصحة البيانات التي يسجلها.\n3. تُحسب رسوم المنصة على كل كشف أو استشارة.',
      'termsEn': 'By using el3yada you agree to these terms.\n\n1. Your account is personal.\n'
          '2. Doctors are responsible for the data they record.\n3. Platform fees apply to every visit.',
      'privacyAr': 'نحمي بياناتك الطبية ولا نشاركها مع أي طرف ثالث إلا بموافقتك أو بأمر قانوني.',
      'privacyEn': null,
    };
    _settingsUpdatedAt = _ago(days: 2, hours: 3);
    _settingsUpdatedBy = nour.displayName;

    void history(String field, String? before, String? after, int daysAgo, AdminUser by) => _history.add(
          SettingsHistoryEntry(
            id: 'history-${_nextId++}',
            field: field,
            before: before,
            after: after,
            changedByName: by.displayName,
            changedAt: _ago(days: daysAgo, hours: 3),
          ),
        );
    history('examFeePiasters', '2500', '3000', 30, nour);
    history('consultationFeePiasters', '1000', '1500', 30, nour);
    history('gracePeriodDays', '5', '7', 21, mostafa);
    history('maintenanceEnabled', 'false', 'true', 9, nour);
    history('maintenanceEnabled', 'true', 'false', 8, nour);
    history('minVersionAndroid', '0.9.0', '1.0.0', 5, mostafa);
    history('supportEmail', null, 'help@el3yada.app', 2, nour);

    // Audit rows, oldest first; the list sorts them newest first.
    _addAudit('adminSeeded', 'user', targetId: nour.userId, details: {'adminRole': 'superAdmin'},
        at: _ago(days: 90), actorRole: 'system');
    _addAudit('adminCreated', 'user', targetId: mostafa.userId, details: {'adminRole': 'admin'},
        at: _ago(days: 60), actor: nour);
    _addAudit('adminCreated', 'user', targetId: 'admin-salma', details: {'adminRole': 'admin'},
        at: _ago(days: 45), actor: nour);
    _addAudit('settingsUpdated', 'settings', targetId: '1', details: {'fields': ['examFeePiasters', 'consultationFeePiasters']},
        at: _ago(days: 30, hours: 3), actor: nour);
    _addAudit('adminDisabled', 'user', targetId: 'admin-salma', at: _ago(days: 19), actor: nour);
    final doctors = ['doc-tarek', 'doc-heba', 'doc-ahmed', 'doc-reem', 'doc-karim', 'doc-sami', 'doc-mona'];
    final names = {for (final r in _registrations.values) r.registration.doctorId: r.registration.fullName};
    for (var day = 18; day >= 1; day--) {
      final doctor = doctors[day % doctors.length];
      final admin = day.isEven ? nour : mostafa;
      _addAudit('passwordResetRequested', 'user', targetId: 'user-$day', details: {'channel': day % 3 == 0 ? 'doctor' : 'email'},
          at: _ago(days: day, hours: 9), actorRole: 'system');
      _addAudit('doctorLicenseViewed', 'doctor', targetId: doctor, doctorId: doctor, at: _ago(days: day, hours: 6), actor: admin);
      _addAudit('passwordChanged', 'user', targetId: 'user-$day', at: _ago(days: day, hours: 4),
          actorRole: 'doctor', actorId: doctor, actorName: names[doctor]);
      if (day % 4 == 0) {
        _addAudit('accountLockedOut', 'user', targetId: 'user-$day', at: _ago(days: day, hours: 2), actorRole: 'system');
      }
    }
    _addAudit('doctorRegistrationSubmitted', 'doctor', targetId: 'doc-tarek', doctorId: 'doc-tarek',
        at: _ago(days: 10), actorRole: 'doctor', actorId: 'doc-tarek', actorName: names['doc-tarek']);
    _addAudit('doctorRegistrationApproved', 'doctor', targetId: 'doc-tarek', doctorId: 'doc-tarek', at: _ago(days: 9), actor: nour);
    _addAudit('settingsUpdated', 'settings', targetId: '1', details: {'fields': ['gracePeriodDays']},
        at: _ago(days: 21, hours: 3), actor: mostafa);
    _addAudit('doctorRegistrationSubmitted', 'doctor', targetId: 'doc-karim', doctorId: 'doc-karim',
        at: _ago(days: 4), actorRole: 'doctor', actorId: 'doc-karim', actorName: names['doc-karim']);
    _addAudit('doctorRegistrationRejected', 'doctor', targetId: 'doc-karim', doctorId: 'doc-karim',
        details: {'reason': 'صورة كارنيه النقابة غير واضحة، برجاء رفع صورة أوضح.'}, at: _ago(days: 3, hours: 2), actor: nour);
    _addAudit('doctorRegistrationResubmitted', 'doctor', targetId: 'doc-karim', doctorId: 'doc-karim',
        at: _ago(days: 1, hours: 3), actorRole: 'doctor', actorId: 'doc-karim', actorName: names['doc-karim']);
    _addAudit('adminRoleChanged', 'user', targetId: mostafa.userId, details: {'before': 'superAdmin', 'after': 'admin'},
        at: _ago(days: 12), actor: nour);
    _addAudit('adminCreated', 'user', targetId: 'admin-yasser', details: {'adminRole': 'admin'}, at: _ago(days: 2), actor: nour);
    _addAudit('settingsUpdated', 'settings', targetId: '1', details: {'fields': ['supportEmail']},
        at: _ago(days: 2, hours: 3), actor: nour);
    for (final id in ['doc-heba', 'doc-ahmed', 'doc-reem', 'doc-sami', 'doc-mona']) {
      final reg = _registrations[id]!.registration;
      _addAudit('doctorRegistrationSubmitted', 'doctor', targetId: id, doctorId: id,
          at: reg.submittedAt, actorRole: 'doctor', actorId: id, actorName: reg.fullName);
    }
    _addAudit('emailVerified', 'user', targetId: 'doc-mona', at: _ago(minutes: 20),
        actorRole: 'doctor', actorId: 'doc-mona', actorName: names['doc-mona']);
  }
}

class _FakeRegistration {
  _FakeRegistration(this.registration, this.createdAt, {required this.reviews});

  DoctorRegistration registration;
  final DateTime createdAt;
  final List<RegistrationReview> reviews;
  Uint8List? license;
  bool licenseMissing = false;

  /// The last suspension or reactivation.
  DateTime? statusChangedAt;
}
