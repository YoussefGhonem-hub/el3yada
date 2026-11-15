import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../../sessions/application/sessions_providers.dart';
import '../../sessions/data/sessions_repository.dart';
import '../../sessions/domain/session_models.dart';
import '../data/patients_repository.dart';
import '../domain/patient_models.dart';

// -----------------------------------------------------------------------------
// D4, AS2

/// What the register shows: search, filters, sort. Kept apart from the list
/// so a refresh keeps them.
final registerQueryProvider = NotifierProvider<RegisterQueryController, RegisterQuery>(RegisterQueryController.new);

class RegisterQueryController extends Notifier<RegisterQuery> {
  @override
  RegisterQuery build() => const RegisterQuery();

  void set(RegisterQuery query) => state = query;
}

/// D4: the register page by page (25 per page).
final registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, PagedState<PatientRegisterRow>>(RegisterController.new);

class RegisterController extends PagedController<PatientRegisterRow> {
  late RegisterQuery _query;

  @override
  PagedState<PatientRegisterRow> build() {
    _query = ref.watch(registerQueryProvider);
    return super.build();
  }

  @override
  Future<Paged<PatientRegisterRow>> fetch(int page, int pageSize) =>
      ref.read(patientsRepositoryProvider).register(_query, page: page, pageSize: pageSize);

  @override
  Object keyOf(PatientRegisterRow item) => item.patientId;
}

// -----------------------------------------------------------------------------
// D6, D7

/// D6 header and file summary.
final patientProvider = FutureProvider.autoDispose.family<PatientView, String>(
  (ref, patientId) => ref.watch(patientsRepositoryProvider).patient(patientId),
  retry: noRetry,
);

/// D6 Overview and D7 (`clinicalView`).
final medicalProfileProvider = FutureProvider.autoDispose.family<MedicalProfile, String>(
  (ref, patientId) => ref.watch(patientsRepositoryProvider).medicalProfile(patientId),
  retry: noRetry,
);

/// D6 Sessions tab, newest first.
final patientSessionsProvider =
    NotifierProvider.autoDispose.family<PatientSessionsController, PagedState<SessionListItem>, String>(
  PatientSessionsController.new,
);

class PatientSessionsController extends PagedController<SessionListItem> {
  PatientSessionsController(this.patientId);

  final String patientId;

  @override
  Future<Paged<SessionListItem>> fetch(int page, int pageSize) =>
      ref.read(sessionsRepositoryProvider).patientSessions(patientId, page: page, pageSize: pageSize);

  @override
  Object keyOf(SessionListItem item) => item.sessionId;
}

/// After a patient changed (added, edited, archived): the screens that show
/// them load again, keeping what they show meanwhile.
void patientChanged(WidgetRef ref, String patientId) {
  ref.invalidate(patientProvider(patientId));
  ref.invalidate(medicalProfileProvider(patientId));
  if (ref.read(registerControllerProvider.exists)) ref.read(registerControllerProvider.notifier).refresh();
}

/// After a session was saved, edited or deleted: the patient, their
/// sessions, the register and every fee total.
void sessionsChanged(WidgetRef ref, {required String patientId}) {
  patientChanged(ref, patientId);
  if (ref.read(patientSessionsProvider(patientId).exists)) ref.read(patientSessionsProvider(patientId).notifier).refresh();
  refreshFees(ref);
}

/// The home's "Search patient": the register focuses its search box as
/// soon as it shows (it may not be built yet when the home asks).
final registerSearchRequestProvider = NotifierProvider<RegisterSearchRequest, bool>(RegisterSearchRequest.new);

class RegisterSearchRequest extends Notifier<bool> {
  @override
  bool build() => false;

  void request() => state = true;

  /// True once per request.
  bool take() {
    if (!state) return false;
    state = false;
    return true;
  }
}
