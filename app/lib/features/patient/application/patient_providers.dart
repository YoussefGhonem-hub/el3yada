import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/patient_repository.dart';
import '../domain/patient_models.dart';

// ---- Doctor selector (P1): null = all doctors ------------------------------------------------

final selectedDoctorProvider = NotifierProvider<SelectedDoctorController, String?>(SelectedDoctorController.new);

class SelectedDoctorController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? doctorId) => state = doctorId;
}

// ---- Simple reads -----------------------------------------------------------------------------

final myDoctorsProvider = FutureProvider.autoDispose<List<MyDoctor>>(
  (ref) => ref.watch(patientRepositoryProvider).myDoctors(),
);

final patientHomeProvider = FutureProvider.autoDispose.family<PatientHome, String?>(
  (ref, doctorId) => ref.watch(patientRepositoryProvider).home(doctorId: doctorId),
);

final doctorInfoProvider = FutureProvider.autoDispose.family<DoctorInfo, String>(
  (ref, doctorId) => ref.watch(patientRepositoryProvider).doctor(doctorId),
);

final recordCountsProvider = FutureProvider.autoDispose.family<RecordCounts, String?>(
  (ref, doctorId) => ref.watch(patientRepositoryProvider).recordCounts(doctorId: doctorId),
);

final medicalProfileProvider = FutureProvider.autoDispose<MedicalProfile>(
  (ref) => ref.watch(patientRepositoryProvider).medicalProfile(),
);

// Details mark their item as seen once loaded ("New" badges).

final visitDetailProvider = FutureProvider.autoDispose.family<VisitDetail, String>((ref, id) async {
  final visit = await ref.watch(patientRepositoryProvider).visit(id);
  if (visit.isNew) ref.read(seenItemsProvider.notifier).markVisit(id);
  return visit;
});

final prescriptionDetailProvider = FutureProvider.autoDispose.family<PrescriptionDetail, String>((ref, id) async {
  final rx = await ref.watch(patientRepositoryProvider).prescription(id);
  if (rx.isNew) ref.read(seenItemsProvider.notifier).markPrescription(id);
  return rx;
});

final recordDetailProvider = FutureProvider.autoDispose.family<RecordDetail, String>((ref, id) async {
  final record = await ref.watch(patientRepositoryProvider).record(id);
  if (record.isNew) ref.read(seenItemsProvider.notifier).markFile(id);
  return record;
});

// ---- Files (authenticated downloads) ----------------------------------------------------------

/// One stored file. Thumbnails are shown in lists, the full file in the viewer.
class FileRef {
  const FileRef.attachment(this.recordId, this.attachmentId, {this.thumbnail = false}) : prescriptionId = null;
  const FileRef.prescriptionPdf(String this.prescriptionId)
      : recordId = null,
        attachmentId = null,
        thumbnail = false;

  final String? recordId;
  final String? attachmentId;
  final String? prescriptionId;
  final bool thumbnail;

  @override
  bool operator ==(Object other) =>
      other is FileRef &&
      other.recordId == recordId &&
      other.attachmentId == attachmentId &&
      other.prescriptionId == prescriptionId &&
      other.thumbnail == thumbnail;

  @override
  int get hashCode => Object.hash(recordId, attachmentId, prescriptionId, thumbnail);
}

/// File bytes, kept in memory for a few minutes after the last screen stops using them.
final fileBytesProvider = FutureProvider.autoDispose.family<Uint8List, FileRef>((ref, file) async {
  final repository = ref.watch(patientRepositoryProvider);
  final bytes = file.prescriptionId != null
      ? await repository.prescriptionPdf(file.prescriptionId!)
      : await repository.attachment(file.recordId!, file.attachmentId!, thumbnail: file.thumbnail);

  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() => timer = Timer(const Duration(minutes: 5), link.close));
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
  return bytes;
});

// ---- "New" badges -----------------------------------------------------------------------------

/// Items opened in this app session. Lists hide the "New" badge for them straight away,
/// and the API is told in one batched call.
class SeenItems {
  const SeenItems({this.visits = const {}, this.prescriptions = const {}, this.files = const {}});

  final Set<String> visits;
  final Set<String> prescriptions;
  final Set<String> files;
}

final seenItemsProvider = NotifierProvider<SeenItemsController, SeenItems>(SeenItemsController.new);

class SeenItemsController extends Notifier<SeenItems> {
  final _pendingVisits = <String>{};
  final _pendingPrescriptions = <String>{};
  final _pendingFiles = <String>{};
  Timer? _flush;

  @override
  SeenItems build() {
    ref.onDispose(() => _flush?.cancel());
    return const SeenItems();
  }

  void markVisit(String id) {
    _pendingVisits.add(id);
    state = SeenItems(visits: {...state.visits, id}, prescriptions: state.prescriptions, files: state.files);
    _schedule();
  }

  void markPrescription(String id) {
    _pendingPrescriptions.add(id);
    state = SeenItems(visits: state.visits, prescriptions: {...state.prescriptions, id}, files: state.files);
    _schedule();
  }

  void markFile(String id) {
    _pendingFiles.add(id);
    state = SeenItems(visits: state.visits, prescriptions: state.prescriptions, files: {...state.files, id});
    _schedule();
  }

  void _schedule() {
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 500), flush);
  }

  /// Sends the pending ids. Failures are dropped: the badge comes back next time, which is harmless.
  Future<void> flush() async {
    if (_pendingVisits.isEmpty && _pendingPrescriptions.isEmpty && _pendingFiles.isEmpty) return;
    final visits = _pendingVisits.toList();
    final prescriptions = _pendingPrescriptions.toList();
    final files = _pendingFiles.toList();
    _pendingVisits.clear();
    _pendingPrescriptions.clear();
    _pendingFiles.clear();
    try {
      await ref.read(patientRepositoryProvider).markSeen(visits: visits, prescriptions: prescriptions, files: files);
      // The counters on the home cards come from the server.
      ref.invalidate(patientHomeProvider);
      ref.invalidate(myDoctorsProvider);
    } catch (_) {}
  }
}

// ---- Paged lists (infinite scroll) ------------------------------------------------------------

class PagedState<T> {
  const PagedState({required this.items, required this.hasMore, this.page = 1, this.loadingMore = false, this.loadMoreError});

  final List<T> items;
  final bool hasMore;
  final int page;
  final bool loadingMore;
  final Object? loadMoreError;

  PagedState<T> copyWith({List<T>? items, bool? hasMore, int? page, bool? loadingMore, Object? loadMoreError}) => PagedState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreError: loadMoreError,
      );
}

abstract class PagedController<T> extends AsyncNotifier<PagedState<T>> {
  PagedController(this.filter);

  final PatientListFilter filter;

  Future<Paged<T>> fetch(PatientRepository repository, int page);

  @override
  Future<PagedState<T>> build() async {
    final first = await fetch(ref.watch(patientRepositoryProvider), 1);
    return PagedState(items: first.items, hasMore: first.hasMore);
  }

  /// Loads the next page. Safe to call repeatedly while scrolling.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await fetch(ref.read(patientRepositoryProvider), current.page + 1);
      state = AsyncData(current.copyWith(
        items: [...current.items, ...next.items],
        hasMore: next.hasMore,
        page: current.page + 1,
        loadingMore: false,
      ));
    } catch (error) {
      state = AsyncData(current.copyWith(loadingMore: false, loadMoreError: error));
    }
  }
}

class VisitsController extends PagedController<VisitListItem> {
  VisitsController(super.filter);

  @override
  Future<Paged<VisitListItem>> fetch(PatientRepository repository, int page) => repository.visits(filter, page: page);
}

class PrescriptionsController extends PagedController<PrescriptionListItem> {
  PrescriptionsController(super.filter);

  @override
  Future<Paged<PrescriptionListItem>> fetch(PatientRepository repository, int page) =>
      repository.prescriptions(filter, page: page);
}

class RecordsController extends PagedController<RecordListItem> {
  RecordsController(super.filter);

  @override
  Future<Paged<RecordListItem>> fetch(PatientRepository repository, int page) => repository.records(filter, page: page);
}

final visitsProvider =
    AsyncNotifierProvider.autoDispose.family<VisitsController, PagedState<VisitListItem>, PatientListFilter>(
  VisitsController.new,
);

final prescriptionsProvider = AsyncNotifierProvider.autoDispose
    .family<PrescriptionsController, PagedState<PrescriptionListItem>, PatientListFilter>(
  PrescriptionsController.new,
);

final recordsProvider =
    AsyncNotifierProvider.autoDispose.family<RecordsController, PagedState<RecordListItem>, PatientListFilter>(
  RecordsController.new,
);

// ---- P14 account ------------------------------------------------------------------------------

final patientAccountProvider =
    AsyncNotifierProvider.autoDispose<PatientAccountController, PatientAccount>(PatientAccountController.new);

class PatientAccountController extends AsyncNotifier<PatientAccount> {
  PatientRepository get _repository => ref.read(patientRepositoryProvider);

  @override
  Future<PatientAccount> build() => ref.watch(patientRepositoryProvider).account();

  /// Optimistic: the switch moves at once and goes back if saving fails (then rethrows).
  Future<void> setNotificationPrefs(NotificationPrefs prefs) async {
    final previous = state.value;
    if (previous == null) return;
    state = AsyncData(previous.copyWith(notifications: prefs));
    try {
      await _repository.updateNotificationPrefs(prefs);
    } catch (_) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> acceptTerms() async {
    await _repository.acceptTerms();
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(acceptedTermsAt: DateTime.now()));
  }

  Future<void> requestDeletion(String? reason) async {
    final trimmed = reason?.trim();
    final request = await _repository.requestAccountDeletion(trimmed == null || trimmed.isEmpty ? null : trimmed);
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(deletionRequest: request));
  }
}
