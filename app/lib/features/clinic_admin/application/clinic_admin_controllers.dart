import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged.dart';
import '../../../core/data/paged_controller.dart';
import '../../clinic/application/clinic_providers.dart';
import '../data/clinic_admin_repository.dart';
import '../domain/account_models.dart';
import '../domain/activity_models.dart';
import '../domain/assistant_models.dart';
import '../domain/branch_models.dart';
import '../domain/price_models.dart';

// Controllers for the clinic's own admin screens. The write methods throw
// `ApiException` and keep what the server answers.

/// Branches, defaults and statuses show in the top bar's branch picker
/// (`clinic/me`), so every branch write reads the clinic again.
void _clinicChanged(Ref ref) => ref.read(clinicContextProvider.notifier).reload().ignore();

// -----------------------------------------------------------------------------
// D28, D29

/// D28: every branch with today's periods and the "2 of 5" limit.
final branchesProvider =
    AsyncNotifierProvider.autoDispose<BranchesController, BranchList>(BranchesController.new, retry: noRetry);

class BranchesController extends AsyncNotifier<BranchList> {
  @override
  Future<BranchList> build() => ref.read(clinicAdminRepositoryProvider).branches();

  Future<void> reload() async {
    state = const AsyncLoading<BranchList>();
    state = await AsyncValue.guard(ref.read(clinicAdminRepositoryProvider).branches);
  }

  /// Keeps the cards on screen while they load again (after a write).
  Future<void> refresh() async {
    final next = await AsyncValue.guard(ref.read(clinicAdminRepositoryProvider).branches);
    if (!ref.mounted) return;
    if (next.hasError && state.hasValue) return;
    state = next;
  }

  /// D29 "new": the Info, Address and Contact groups (and the checklists).
  Future<BranchDetails> create({
    required BranchInfo info,
    required BranchAddress address,
    required BranchContact contact,
    BranchChecklistInput? clinicInfo,
  }) async {
    final created = await ref
        .read(clinicAdminRepositoryProvider)
        .createBranch(info: info, address: address, contact: contact, clinicInfo: clinicInfo);
    if (ref.mounted) refresh().ignore();
    _clinicChanged(ref);
    return created;
  }
}

/// D29: one branch. Each tab saves its own group.
final branchDetailProvider = AsyncNotifierProvider.autoDispose
    .family<BranchDetailController, BranchDetails, String>(BranchDetailController.new, retry: noRetry);

class BranchDetailController extends AsyncNotifier<BranchDetails> {
  BranchDetailController(this.branchId);

  final String branchId;

  ClinicAdminRepository get _repository => ref.read(clinicAdminRepositoryProvider);

  @override
  Future<BranchDetails> build() => _repository.branch(branchId);

  Future<void> reload() async {
    state = const AsyncLoading<BranchDetails>();
    state = await AsyncValue.guard(() => _repository.branch(branchId));
  }

  Future<BranchDetails> _keep(Future<BranchDetails> write, {bool clinic = false}) async {
    final details = await write;
    if (ref.mounted) state = AsyncData(details);
    ref.invalidate(branchesProvider);
    if (clinic) _clinicChanged(ref);
    return details;
  }

  Future<BranchDetails> saveInfo(BranchInfo info) => _keep(_repository.updateBranch(branchId, info: info), clinic: true);

  Future<BranchDetails> saveAddress(BranchAddress address) =>
      _keep(_repository.updateBranch(branchId, address: address), clinic: true);

  Future<BranchDetails> saveContact(BranchContact contact) => _keep(_repository.updateBranch(branchId, contact: contact));

  Future<BranchDetails> saveChecklists(BranchChecklistInput clinicInfo) =>
      _keep(_repository.updateBranch(branchId, clinicInfo: clinicInfo));

  Future<BranchDetails> saveHours(List<BranchPeriod> periods) => _keep(_repository.updateBranchHours(branchId, periods));

  /// Throws `BranchHasBookingsException` when bookings stand in the way (BR-BR9).
  Future<BranchDetails> setStatus(String status, {String? closedMessage, DateTime? reopenDate}) => _keep(
        _repository.setBranchStatus(branchId, status, closedMessage: closedMessage, reopenDate: reopenDate),
        clinic: true,
      );

  Future<BranchDetails> makeDefault() => _keep(_repository.setDefaultBranch(branchId), clinic: true);

  /// The branch's own prices from the Clinic info tab (`updatePrices`).
  Future<void> savePrices({int? examination, int? consultation}) async {
    await _repository.updatePrices(
      branchId: branchId,
      examinationPricePiasters: examination,
      consultationPricePiasters: consultation,
    );
    ref.invalidate(pricesProvider);
    final details = await _repository.branch(branchId);
    if (ref.mounted) state = AsyncData(details);
  }
}

// -----------------------------------------------------------------------------
// D37, AS19

/// D37: the doctor's prices and each branch's.
final pricesProvider =
    AsyncNotifierProvider.autoDispose<PricesController, PricesOverview>(PricesController.new, retry: noRetry);

class PricesController extends AsyncNotifier<PricesOverview> {
  @override
  Future<PricesOverview> build() => ref.read(clinicAdminRepositoryProvider).prices(pageSize: 1);

  Future<void> reload() async {
    state = const AsyncLoading<PricesOverview>();
    state = await AsyncValue.guard(() => ref.read(clinicAdminRepositoryProvider).prices(pageSize: 1));
  }

  /// [branchId] null for the doctor's prices. Throws `ApiException`.
  Future<PricesOverview> save({String? branchId, int? examination, int? consultation}) async {
    final updated = await ref.read(clinicAdminRepositoryProvider).updatePrices(
          branchId: branchId,
          examinationPricePiasters: examination,
          consultationPricePiasters: consultation,
        );
    if (ref.mounted) state = AsyncData(updated);
    ref.invalidate(priceHistoryProvider);
    if (branchId != null) ref.invalidate(branchDetailProvider(branchId));
    return updated;
  }
}

/// D37 history (BR-PR5): newest first, page by page.
final priceHistoryProvider =
    NotifierProvider.autoDispose<PriceHistoryController, PagedState<PriceHistoryEntry>>(PriceHistoryController.new);

class PriceHistoryController extends PagedController<PriceHistoryEntry> {
  @override
  Future<Paged<PriceHistoryEntry>> fetch(int page, int pageSize) async =>
      (await ref.read(clinicAdminRepositoryProvider).prices(page: page, pageSize: pageSize)).history;

  @override
  Object keyOf(PriceHistoryEntry item) => item.id;
}

// -----------------------------------------------------------------------------
// D22, D24, AS12

/// D22: the doctor's personal and professional details.
final doctorProfileProvider =
    AsyncNotifierProvider.autoDispose<DoctorProfileController, DoctorProfile>(DoctorProfileController.new, retry: noRetry);

class DoctorProfileController extends AsyncNotifier<DoctorProfile> {
  @override
  Future<DoctorProfile> build() => ref.read(clinicAdminRepositoryProvider).doctorProfile();

  Future<void> reload() async {
    state = const AsyncLoading<DoctorProfile>();
    state = await AsyncValue.guard(ref.read(clinicAdminRepositoryProvider).doctorProfile);
  }

  /// Throws `ApiException` (field errors in `fieldCodes`).
  Future<DoctorProfile> save(DoctorProfileUpdate update) async {
    final profile = await ref.read(clinicAdminRepositoryProvider).updateDoctorProfile(update);
    if (ref.mounted) state = AsyncData(profile);
    // The name and specialty show in the clinic (clinic/me).
    _clinicChanged(ref);
    return profile;
  }
}

/// D24, AS12: the signed-in user's notification preferences. A switch
/// changes at once and goes back if the save fails.
final notificationPrefsProvider =
    AsyncNotifierProvider.autoDispose<NotificationPrefsController, NotificationPrefs>(NotificationPrefsController.new,
        retry: noRetry);

class NotificationPrefsController extends AsyncNotifier<NotificationPrefs> {
  @override
  Future<NotificationPrefs> build() => ref.read(clinicAdminRepositoryProvider).notificationPrefs();

  Future<void> reload() async {
    state = const AsyncLoading<NotificationPrefs>();
    state = await AsyncValue.guard(ref.read(clinicAdminRepositoryProvider).notificationPrefs);
  }

  /// Throws `ApiException` after putting the old value back.
  Future<void> set({bool? chat, bool? reminders, bool? showPreview, bool? bookings}) async {
    final before = state.value;
    if (before == null) return;
    state = AsyncData(before.copyWith(chat: chat, reminders: reminders, showPreview: showPreview, bookings: bookings));
    try {
      final saved = await ref
          .read(clinicAdminRepositoryProvider)
          .updateNotificationPrefs(chat: chat, reminders: reminders, showPreview: showPreview, bookings: bookings);
      if (ref.mounted) state = AsyncData(saved);
    } catch (_) {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

// -----------------------------------------------------------------------------
// D25, D26

/// D25: the clinic's assistants (removed ones left out) and the limit.
final assistantsProvider =
    AsyncNotifierProvider.autoDispose<AssistantsController, AssistantList>(AssistantsController.new, retry: noRetry);

class AssistantsController extends AsyncNotifier<AssistantList> {
  ClinicAdminRepository get _repository => ref.read(clinicAdminRepositoryProvider);

  @override
  Future<AssistantList> build() => _repository.assistants();

  Future<void> reload() async {
    state = const AsyncLoading<AssistantList>();
    state = await AsyncValue.guard(_repository.assistants);
  }

  Future<AssistantWithPassword> create(AssistantDraft draft) async {
    final created = await _repository.createAssistant(draft);
    _put(created.assistant);
    return created;
  }

  Future<Assistant> save(
    String assistantId, {
    String? fullName,
    String? phone,
    bool? allBranches,
    Set<String>? branchIds,
    Set<String>? permissions,
  }) async =>
      _put(await _repository.updateAssistant(
        assistantId,
        fullName: fullName,
        phone: phone,
        allBranches: allBranches,
        branchIds: branchIds,
        permissions: permissions,
      ));

  Future<AssistantWithPassword> resetPassword(String assistantId) async {
    final reset = await _repository.resetAssistantPassword(assistantId);
    _put(reset.assistant);
    return reset;
  }

  Future<Assistant> setStatus(String assistantId, String status) async =>
      _put(await _repository.setAssistantStatus(assistantId, status));

  /// Puts the server's answer in the list; a removed assistant leaves it and
  /// stops counting toward the limit.
  Assistant _put(Assistant assistant) {
    ref.invalidate(assistantDetailProvider(assistant.userId));
    final list = state.value;
    if (list == null || !ref.mounted) return assistant;
    final items = [...list.items];
    final index = items.indexWhere((a) => a.userId == assistant.userId);
    if (assistant.isRemoved) {
      if (index >= 0) items.removeAt(index);
    } else if (index < 0) {
      items.add(assistant);
    } else {
      items[index] = assistant;
    }
    final count = items.length;
    state = AsyncData(list.copyWith(items: items, count: count, canAdd: count < list.limit));
    return assistant;
  }
}

/// D26 opened by its address: one assistant.
final assistantDetailProvider = FutureProvider.autoDispose.family<Assistant, String>(
  (ref, assistantId) => ref.watch(clinicAdminRepositoryProvider).assistant(assistantId),
  retry: noRetry,
);

// -----------------------------------------------------------------------------
// D27

/// D27: the clinic's activity, newest first, with filters.
final activityLogProvider =
    NotifierProvider.autoDispose<ActivityLogController, PagedState<ActivityEntry>>(ActivityLogController.new);

class ActivityLogController extends PagedController<ActivityEntry> {
  ActivityFilter _filter = const ActivityFilter();
  List<ActivityPerson> _people = const [];
  List<String> _actions = const [];

  ActivityFilter get filter => _filter;

  /// For the person filter: from the last page loaded.
  List<ActivityPerson> get people => _people;

  /// For the action filter.
  List<String> get actions => _actions;

  @override
  Future<Paged<ActivityEntry>> fetch(int page, int pageSize) async {
    final result = await ref.read(clinicAdminRepositoryProvider).activity(_filter, page: page, pageSize: pageSize);
    _people = result.people;
    _actions = result.actions;
    return result.page;
  }

  @override
  Object keyOf(ActivityEntry item) => item.id;

  void setFilter(ActivityFilter filter) {
    _filter = filter;
    reload();
  }
}
