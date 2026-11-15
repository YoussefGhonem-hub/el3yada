import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/user_role.dart';
import '../data/clinic_repository.dart';
import '../domain/clinic_context.dart';

/// The signed-in doctor's or assistant's clinic (`GET /api/clinic/me`), or
/// null for other roles and before the user may open the clinic (A6, A7, A9).
///
/// Loaded once per sign-in and kept while it reloads. Reload it on resume
/// and after `PERMISSION_DENIED` or `DOCTOR_SUSPENDED` (the API client does
/// that), because the doctor can change an assistant's permissions at any
/// time (BR-AS4).
final clinicContextProvider = AsyncNotifierProvider<ClinicContextController, ClinicContext?>(ClinicContextController.new);

class ClinicContextController extends AsyncNotifier<ClinicContext?> {
  @override
  Future<ClinicContext?> build() async {
    // Only what decides whether there is a clinic: a token refresh must not reload it.
    final key = ref.watch(authControllerProvider.select((auth) => _clinicKey(auth.value)));
    if (key == null) return null;
    return ref.read(clinicRepositoryProvider).me();
  }

  /// Reads it again, keeping the current one on screen meanwhile.
  Future<void> reload() async {
    if (_clinicKey(ref.read(authControllerProvider).value) == null) return;
    final next = await AsyncValue.guard(() => ref.read(clinicRepositoryProvider).me());
    if (!ref.mounted) return;
    // Offline: keep what we had rather than hiding the clinic.
    if (next.hasError && state.hasValue && state.value != null) return;
    state = next;
  }
}

/// The parts of the session that decide whether the clinic can load, or null
/// when it can't (the API would refuse `clinic/me`).
({String userId, UserRole role, DoctorStatus? status})? _clinicKey(AuthSession? session) {
  if (session == null || session.mustChangePassword) return null;
  if (session.role != UserRole.doctor && session.role != UserRole.assistant) return null;
  final status = session.doctorStatus;
  if (session.role == UserRole.doctor && status != DoctorStatus.active && status != DoctorStatus.suspended) return null;
  return (userId: session.userId, role: session.role, status: status);
}

/// The current branch (BR-BR3): new sessions, walk-ins and today's lists use
/// it. One of [ClinicContext.workBranches]; remembered per user on this
/// device. Null when there is no clinic.
final currentBranchProvider = NotifierProvider<CurrentBranchController, ClinicBranch?>(CurrentBranchController.new);

class CurrentBranchController extends Notifier<ClinicBranch?> {
  @override
  ClinicBranch? build() {
    final clinic = ref.watch(clinicContextProvider).value;
    if (clinic == null) return null;
    final saved = ref.read(sharedPreferencesProvider).getString(_key(clinic));
    return pick(clinic, saved);
  }

  /// The saved branch while it's still a work branch, else the default, else the first.
  static ClinicBranch? pick(ClinicContext clinic, String? savedId) {
    final work = clinic.workBranches;
    if (work.isEmpty) return null;
    for (final id in [savedId, clinic.defaultBranchId]) {
      for (final branch in work) {
        if (branch.id == id) return branch;
      }
    }
    return work.first;
  }

  void select(String branchId) {
    final clinic = ref.read(clinicContextProvider).value;
    if (clinic == null) return;
    final branch = pick(clinic, branchId);
    if (branch == null || branch.id != branchId) return;
    ref.read(sharedPreferencesProvider).setString(_key(clinic), branchId).ignore();
    state = branch;
  }

  static String _key(ClinicContext clinic) => 'clinic.currentBranch.${clinic.assistant?.userId ?? clinic.doctor.id}';
}
