import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../data/prescriptions_repository.dart';
import '../domain/prescription_models.dart';

/// One prescription (D13–D15).
final prescriptionProvider = FutureProvider.autoDispose.family<Prescription, String>(
  (ref, prescriptionId) => ref.watch(prescriptionsRepositoryProvider).prescription(prescriptionId),
  retry: noRetry,
);

/// D9 and Print all: the session's documents, oldest first.
final sessionPrescriptionsProvider = FutureProvider.autoDispose.family<List<Prescription>, String>(
  (ref, sessionId) => ref.watch(prescriptionsRepositoryProvider).sessionPrescriptions(sessionId),
  retry: noRetry,
);

/// D6 Prescriptions tab, newest first.
final patientPrescriptionsProvider =
    NotifierProvider.autoDispose.family<PatientPrescriptionsController, PagedState<Prescription>, String>(
  PatientPrescriptionsController.new,
);

class PatientPrescriptionsController extends PagedController<Prescription> {
  PatientPrescriptionsController(this.patientId);

  final String patientId;

  @override
  Future<Paged<Prescription>> fetch(int page, int pageSize) =>
      ref.read(prescriptionsRepositoryProvider).patientPrescriptions(patientId, page: page, pageSize: pageSize);

  @override
  Object keyOf(Prescription item) => item.prescriptionId;
}

/// "Used before" (BR-CAT4 group 1). Kept for the signed-in user, so the
/// editors' search doesn't ask again on every key; it loads again after a
/// send and when another user signs in.
final itemHistoryProvider = FutureProvider<List<ItemHistoryEntry>>((ref) {
  ref.watch(authControllerProvider.select((auth) => auth.value?.userId));
  return ref.watch(prescriptionsRepositoryProvider).itemHistory();
}, retry: noRetry);

/// D23 and «من قالب»: every template, or one kind's.
final templatesProvider = FutureProvider.autoDispose.family<List<PrescriptionTemplate>, PrescriptionKind?>(
  (ref, kind) => ref.watch(prescriptionsRepositoryProvider).templates(kind: kind),
  retry: noRetry,
);

/// D22 prescription header and print settings.
final rxSettingsProvider = FutureProvider.autoDispose<RxSettings>(
  (ref) => ref.watch(prescriptionsRepositoryProvider).rxSettings(),
  retry: noRetry,
);

/// The logo or the signature (a PNG), or null.
final rxImageProvider = FutureProvider.autoDispose.family<Uint8List?, RxImageKind>(
  (ref, kind) => ref.watch(prescriptionsRepositoryProvider).rxImage(kind),
  retry: noRetry,
);

/// After a document was created, edited, sent, cancelled or deleted: the
/// screens that list it load again.
void prescriptionsChanged(WidgetRef ref, {required String patientId, required String sessionId, String? prescriptionId}) {
  if (prescriptionId != null) ref.invalidate(prescriptionProvider(prescriptionId));
  ref.invalidate(sessionPrescriptionsProvider(sessionId));
  if (ref.read(patientPrescriptionsProvider(patientId).exists)) {
    ref.read(patientPrescriptionsProvider(patientId).notifier).refresh();
  }
}

/// After a send: the history counts changed (BR-CAT4).
void itemHistoryChanged(WidgetRef ref) => ref.invalidate(itemHistoryProvider);

/// After the D22 settings or images changed.
void rxSettingsChanged(WidgetRef ref) {
  ref.invalidate(rxSettingsProvider);
  for (final kind in RxImageKind.values) {
    ref.invalidate(rxImageProvider(kind));
  }
}
