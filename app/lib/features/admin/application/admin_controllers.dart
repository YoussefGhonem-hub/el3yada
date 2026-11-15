import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_repository.dart';
import '../domain/admin_models.dart';
import '../../../core/data/paged_controller.dart';

// -----------------------------------------------------------------------------
// AD2, AD3

/// AD2 order: newest first (the default here), or the API's queue order.
enum SignupSort { newest, oldest }

/// AD2: sign-up requests waiting for approval, with search and sort.
final signupsControllerProvider =
    NotifierProvider.autoDispose<SignupsController, PagedState<RegistrationSummary>>(SignupsController.new);

class SignupsController extends PagedController<RegistrationSummary> {
  String _search = '';
  SignupSort _sort = SignupSort.newest;

  String get search => _search;
  SignupSort get sort => _sort;

  @override
  Future<Paged<RegistrationSummary>> fetch(int page, int pageSize) => ref
      .read(adminRepositoryProvider)
      .doctorRegistrations(search: _search, sort: _sort.name, page: page, pageSize: pageSize);

  @override
  Object keyOf(RegistrationSummary item) => item.doctorId;

  void setSearch(String value) {
    if (value.trim() == _search) return;
    _search = value.trim();
    reload();
  }

  void setSort(SignupSort value) {
    if (value == _sort) return;
    _sort = value;
    reload();
  }

  /// After a review: the request leaves the list.
  void reviewed(String doctorId) => removeWhere((item) => item.doctorId == doctorId);
}

/// AD3: one registration with its earlier reviews.
final registrationDetailProvider = FutureProvider.autoDispose.family<RegistrationDetail, String>(
  (ref, doctorId) => ref.watch(adminRepositoryProvider).doctorRegistration(doctorId),
  retry: noRetry,
);

/// AD3 license file. Each load writes a `doctorLicenseViewed` audit row, so
/// it stays cached while the review is open.
final licenseFileProvider = FutureProvider.autoDispose.family<LicenseFile, String>(
  (ref, doctorId) => ref.watch(adminRepositoryProvider).doctorLicense(doctorId),
  retry: noRetry,
);

// -----------------------------------------------------------------------------
// AD13

/// AD13: the platform settings. [AdminSettingsController.save] sends a
/// partial update and keeps what the server answers.
final adminSettingsProvider =
    AsyncNotifierProvider.autoDispose<AdminSettingsController, PlatformSettings>(AdminSettingsController.new,
        retry: noRetry);

class AdminSettingsController extends AsyncNotifier<PlatformSettings> {
  @override
  Future<PlatformSettings> build() => ref.read(adminRepositoryProvider).settings();

  /// Throws `ApiException` (field errors in `fieldCodes`); nothing is saved then.
  Future<PlatformSettings> save(Map<String, Object?> changes) async {
    final updated = await ref.read(adminRepositoryProvider).updateSettings(changes);
    if (ref.mounted) state = AsyncData(updated);
    return updated;
  }

  Future<void> reload() async {
    state = const AsyncLoading<PlatformSettings>();
    state = await AsyncValue.guard(ref.read(adminRepositoryProvider).settings);
  }
}

/// One setting's change history (or every setting's, with an empty name).
final settingsHistoryProvider =
    NotifierProvider.autoDispose.family<SettingsHistoryController, PagedState<SettingsHistoryEntry>, String>(
  SettingsHistoryController.new,
);

class SettingsHistoryController extends PagedController<SettingsHistoryEntry> {
  SettingsHistoryController(this.field);

  /// A setting name, or '' for all.
  final String field;

  @override
  Future<Paged<SettingsHistoryEntry>> fetch(int page, int pageSize) => ref
      .read(adminRepositoryProvider)
      .settingsHistory(field: field.isEmpty ? null : field, page: page, pageSize: pageSize);

  @override
  Object keyOf(SettingsHistoryEntry item) => item.id;
}

// -----------------------------------------------------------------------------
// AD14

/// AD14: every admin (super admins only). The write methods throw
/// `ApiException` and update the list with the server's answer.
final adminUsersProvider =
    AsyncNotifierProvider.autoDispose<AdminUsersController, List<AdminUser>>(AdminUsersController.new, retry: noRetry);

class AdminUsersController extends AsyncNotifier<List<AdminUser>> {
  AdminRepository get _repository => ref.read(adminRepositoryProvider);

  @override
  Future<List<AdminUser>> build() => _repository.admins();

  Future<void> reload() async {
    state = const AsyncLoading<List<AdminUser>>();
    state = await AsyncValue.guard(_repository.admins);
  }

  Future<CreatedAdmin> create({required String email, required String displayName, required AdminRole role}) async {
    final created = await _repository.createAdmin(email: email, displayName: displayName, role: role);
    _put(created.admin);
    return created;
  }

  Future<AdminUser> setRole(AdminUser admin, AdminRole role) async => _put(await _repository.setAdminRole(admin.userId, role));

  Future<AdminUser> setActive(AdminUser admin, {required bool active}) async =>
      _put(await _repository.setAdminStatus(admin.userId, active: active));

  AdminUser _put(AdminUser admin) {
    final list = state.value;
    if (list != null && ref.mounted) {
      final index = list.indexWhere((a) => a.userId == admin.userId);
      final updated = [...list];
      if (index < 0) {
        updated.add(admin);
      } else {
        updated[index] = admin;
      }
      state = AsyncData(updated);
    }
    return admin;
  }
}

// -----------------------------------------------------------------------------
// AD15

/// AD15: the audit log, newest first, with filters.
final auditLogControllerProvider =
    NotifierProvider.autoDispose<AuditLogController, PagedState<AuditEntry>>(AuditLogController.new);

class AuditLogController extends PagedController<AuditEntry> {
  AuditFilter _filter = const AuditFilter();

  AuditFilter get filter => _filter;

  @override
  Future<Paged<AuditEntry>> fetch(int page, int pageSize) =>
      ref.read(adminRepositoryProvider).auditLogs(_filter, page: page, pageSize: pageSize);

  @override
  Object keyOf(AuditEntry item) => item.id;

  void setFilter(AuditFilter filter) {
    _filter = filter;
    reload();
  }
}

// -----------------------------------------------------------------------------
// AD18

/// AD18: the signed-in admin's profile.
final adminProfileProvider =
    AsyncNotifierProvider.autoDispose<AdminProfileController, AdminProfile>(AdminProfileController.new, retry: noRetry);

class AdminProfileController extends AsyncNotifier<AdminProfile> {
  @override
  Future<AdminProfile> build() => ref.read(adminRepositoryProvider).profile();

  Future<void> reload() async {
    state = const AsyncLoading<AdminProfile>();
    state = await AsyncValue.guard(ref.read(adminRepositoryProvider).profile);
  }

  /// Throws `ApiException` (`displayName`: `INVALID_NAME`).
  Future<void> rename(String displayName) async {
    final profile = await ref.read(adminRepositoryProvider).updateAdminProfile(displayName);
    if (ref.mounted) state = AsyncData(profile);
  }
}
