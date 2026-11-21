import 'package:el3yada/features/patients/data/fake_clinic_records.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'admin_support.dart' show appContainer;

/// The offline clinic records with no delay, for the signed-in account (like
/// the app's own provider in dev builds). [configure] can change them first,
/// for example the visit prices or the consultation limit.
Override fakeRecordsOverride({
  void Function(FakeClinicRecords records)? configure,
}) => fakeClinicRecordsProvider.overrideWith((ref) {
  final records = FakeClinicRecords(
    caller: () => fakeCallerOf(ref),
    delay: Duration.zero,
  );
  configure?.call(records);
  return records;
});

/// The records behind the running app.
FakeClinicRecords recordsOf(WidgetTester tester) =>
    appContainer(tester).read(fakeClinicRecordsProvider);

/// The seeded patients used by the tests (see `FakeClinicRecords._seed`).
abstract final class SeedPatients {
  /// Exam, then two consultations (today): Consultation is closed (AC-1).
  static const mona = 'منى حسن إبراهيم';

  /// Never seen: a first visit offers only Examination (BR-S2).
  static const sara = 'سارة علي مصطفى';

  /// One consultation since the last examination.
  static const laila = 'ليلى مصطفى كامل';

  /// Linked from another clinic (BR-P3): no optional details.
  static const noura = 'نورا إبراهيم سليم';

  /// Today's examination recorded at reception (BR-AS7).
  static const youssef = 'يوسف خالد سمير';
}
