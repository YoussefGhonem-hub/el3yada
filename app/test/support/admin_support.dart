import 'package:el3yada/app/app.dart';
import 'package:el3yada/app/router.dart';
import 'package:el3yada/features/admin/data/admin_repository.dart';
import 'package:el3yada/features/admin/data/fake_admin_repository.dart';
import 'package:el3yada/features/auth/application/auth_controller.dart';
import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/auth/domain/auth_session.dart';
import 'package:el3yada/features/auth/domain/login_result.dart';
import 'package:el3yada/features/auth/domain/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// The offline admin data with no delay, aware of who is signed in (like
/// the app's own provider in dev builds).
Override fakeAdminOverride({void Function(FakeAdminRepository fake)? configure}) =>
    adminRepositoryProvider.overrideWith((ref) {
      final fake = FakeAdminRepository(
        delay: Duration.zero,
        currentAdmin: () {
          final session = ref.read(authControllerProvider).value;
          return session == null ? null : (session.userId, session.displayName, session.email, session.isSuperAdmin);
        },
      );
      configure?.call(fake);
      return fake;
    });

ProviderContainer appContainer(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(El3yadaApp)));

/// The fake behind the running app.
FakeAdminRepository adminFake(WidgetTester tester) =>
    appContainer(tester).read(adminRepositoryProvider) as FakeAdminRepository;

/// Opens [path] as a link would.
void goTo(WidgetTester tester, String path) => appContainer(tester).read(routerProvider).go(path);

/// The offline accounts, where `admin@el3yada.dev` is a plain admin (not a
/// super admin), for AD14's restricted state.
class PlainAdminAuthRepository extends FakeAuthRepository {
  PlainAdminAuthRepository() : super(delay: Duration.zero);

  @override
  Future<LoginResult> login({required String identifier, required String password, Map<String, dynamic>? device}) async {
    if (identifier != 'admin@el3yada.dev') return super.login(identifier: identifier, password: password, device: device);
    final AuthSession session = const FakeAccount(UserRole.admin, 'مصطفى كامل', adminRole: 'admin').session(identifier);
    return SignedIn(session);
  }
}
