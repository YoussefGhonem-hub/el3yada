import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/registration_repository.dart';
import '../domain/doctor_registration.dart';
import '../domain/license_file.dart';
import '../domain/specialty.dart';

/// The active specialties (A4 step 2). Kept for the app's lifetime once
/// loaded; `ref.invalidate` retries after an error.
final specialtiesProvider = FutureProvider<List<Specialty>>(
  (ref) => ref.watch(registrationRepositoryProvider).specialties(),
);

/// The signed-in doctor's registration (A6 read-only, A7 pre-fill). Loaded
/// again for each visit and whenever the account changes.
final myRegistrationProvider = FutureProvider.autoDispose<DoctorRegistration>((ref) {
  ref.watch(authControllerProvider.select((session) => session.value?.userId));
  return ref.watch(registrationRepositoryProvider).myRegistration();
});

/// The license file the doctor uploaded (thumbnail on A6 and on A7's form),
/// or null when the server has none.
final myLicenseProvider = FutureProvider.autoDispose<LicenseFile?>((ref) {
  ref.watch(authControllerProvider.select((session) => session.value?.userId));
  return ref.watch(registrationRepositoryProvider).myLicense();
});
