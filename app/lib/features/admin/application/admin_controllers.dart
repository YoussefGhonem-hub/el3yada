import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/widgets/navigation/nav_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/user_role.dart';
import '../admin_routes.dart';
import '../data/admin_repository.dart';
import '../domain/admin_models.dart';

// -----------------------------------------------------------------------------
// AD2, AD3

/// AD2 order: newest first (the default here), or the API's queue order.
enum SignupSort { newest, oldest }

/// AD2: the doctors, with search, sort and the free-trial filter.
final signupsControllerProvider =
    NotifierProvider.autoDispose<SignupsController, PagedState<RegistrationSummary>>(SignupsController.new);

class SignupsController extends PagedController<RegistrationSummary> {
  String _search = '';
  SignupSort _sort = SignupSort.newest;
  TrialFilter? _trial;
  DoctorListFilter _filter = const DoctorListFilter();

  String get search => _search;
  SignupSort get sort => _sort;

  /// Null: every doctor. Otherwise those whose free trial is running or has
  /// ended (spec 6.16).
  TrialFilter? get trial => _trial;

  /// Specialty, governorate and sign-up dates (spec AD4's filters; the API
  /// has them on AD2's list too).
  DoctorListFilter get filter => _filter;

  @override
  Future<Paged<RegistrationSummary>> fetch(int page, int pageSize) => ref.read(adminRepositoryProvider).doctorRegistrations(
        search: _search,
        sort: _sort.name,
        trial: _trial,
        specialtyId: _filter.specialty?.id,
        governorate: _filter.governorate,
        from: _filter.from,
        to: _filter.to,
        page: page,
        pageSize: pageSize,
      );

  void setTrial(TrialFilter? value) {
    if (value == _trial) return;
    _trial = value;
    reload();
  }

  void setFilter(DoctorListFilter value) {
    if (value == _filter) return;
    _filter = value;
    reload();
  }

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

  /// After a legacy sign-up's review: the doctor stays, with the new status.
  void reviewed(String doctorId) {
    ref.invalidate(pendingSignupsProvider);
    refresh().ignore();
  }
}

/// Notification types that mean a sign-up waits for review again.
const _signupNotificationTypes = {'doctorRegistrationReceived', 'doctorRegistrationResubmitted'};

/// The AD2 menu badge: legacy sign-ups still waiting for review. Since the
/// free trial (spec 6.16 BR-T1) new doctors are active at once and the
/// admin does nothing, so these are the only doctors AD2 asks the admin to
/// act on (approve or reject in AD3). Read again when a sign-up
/// notification arrives, after a review, and every few minutes.
final pendingSignupsProvider = FutureProvider.autoDispose<int>((ref) async {
  final role = ref.watch(authControllerProvider.select((session) => session.value?.role));
  if (role != UserRole.admin) return 0;
  final events = ref
      .watch(realtimeServiceProvider)
      .events
      .where((e) => e.name == RealtimeEvents.notification && _signupNotificationTypes.contains(e.data['type']))
      .listen((_) => ref.invalidateSelf());
  final timer = Timer(const Duration(minutes: 5), ref.invalidateSelf);
  ref.onDispose(() {
    events.cancel();
    timer.cancel();
  });
  return ref.watch(adminRepositoryProvider).pendingSignupsCount();
}, retry: noRetry);

/// The menu badge of an admin destination ([navBadgeProvider] in the shell).
NavBadge? adminNavBadge(Ref ref, String path) {
  if (path != AdminRoutes.signups) return null;
  final pending = ref.watch(pendingSignupsProvider).value ?? 0;
  return pending > 0 ? NavBadge.count(pending, label: _waitingLabel) : null;
}

String _waitingLabel(AppLocalizations l10n, int count) => l10n.adminBadgeWaitingReview(count);

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
