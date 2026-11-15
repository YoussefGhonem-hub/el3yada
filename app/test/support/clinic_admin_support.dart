import 'package:el3yada/features/auth/application/auth_controller.dart';
import 'package:el3yada/features/clinic_admin/data/clinic_admin_repository.dart';
import 'package:el3yada/features/clinic_admin/data/fake_clinic_admin_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'admin_support.dart';

/// The offline clinic (branches, prices, profile, assistants, activity) with
/// no delay, aware of who is signed in, like the app's own provider in dev
/// builds. [configure] changes the sample data before the test starts.
Override fakeClinicAdminOverride({void Function(FakeClinicAdminRepository fake)? configure}) =>
    clinicAdminRepositoryProvider.overrideWith((ref) {
      final fake = FakeClinicAdminRepository(
        delay: Duration.zero,
        currentSession: () => ref.read(authControllerProvider).value,
      );
      configure?.call(fake);
      return fake;
    });

/// The fake behind the running app.
FakeClinicAdminRepository clinicAdminFake(WidgetTester tester) =>
    appContainer(tester).read(clinicAdminRepositoryProvider) as FakeClinicAdminRepository;
