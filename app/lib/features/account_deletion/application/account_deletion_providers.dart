import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../data/account_deletion_repository.dart';
import '../domain/account_deletion_models.dart';

/// `getAccountDeletion` for the signed-in account: the settings flow and A16.
final accountDeletionStateProvider = FutureProvider.autoDispose<AccountDeletionState>(
  (ref) => ref.watch(accountDeletionRepositoryProvider).state(),
  retry: noRetry,
);

/// AD12's role and status filters.
final accountDeletionFilterProvider = NotifierProvider<AccountDeletionFilterController, AccountDeletionFilter>(
  AccountDeletionFilterController.new,
);

class AccountDeletionFilterController extends Notifier<AccountDeletionFilter> {
  @override
  AccountDeletionFilter build() => const AccountDeletionFilter();

  void set(AccountDeletionFilter value) => state = value;
}

/// AD12: every deletion, newest first, with the filters.
final accountDeletionsProvider = FutureProvider.autoDispose<AccountDeletionPage>(
  (ref) => ref.watch(accountDeletionRepositoryProvider).list(filter: ref.watch(accountDeletionFilterProvider)),
  retry: noRetry,
);

/// AD5 and AD11: one account's latest deletion, or null.
final userAccountDeletionProvider = FutureProvider.autoDispose.family<AccountDeletionItem?, String>(
  (ref, userId) async =>
      (await ref.watch(accountDeletionRepositoryProvider).list(userId: userId)).items.firstOrNull,
  retry: noRetry,
);

/// What the screens do. Each method throws [ApiException].
extension AccountDeletionActions on WidgetRef {
  /// Starts the signed-in account's deletion. The API signs every device
  /// out; the caller shows the date, then signs out here too.
  Future<AccountDeletionStarted> requestAccountDeletion({required String currentPassword, String? reason}) =>
      read(accountDeletionRepositoryProvider).request(currentPassword: currentPassword, reason: reason);

  /// A16 "Restore": the account is active again and the router leaves A16.
  Future<void> restoreAccount() async {
    await read(accountDeletionRepositoryProvider).restore();
    await read(authControllerProvider.notifier).reloadAccount();
  }

  /// AD5, AD11: an admin starts the deletion of [userId], with a reason.
  Future<AccountDeletionItem> scheduleAccountDeletion(String userId, String reason) async {
    final item = await read(accountDeletionRepositoryProvider).schedule(userId: userId, reason: reason);
    invalidate(accountDeletionsProvider);
    invalidate(userAccountDeletionProvider(userId));
    return item;
  }

  /// AD12, AD5, AD11 "Cancel and restore", with a reason.
  Future<AccountDeletionItem> cancelAccountDeletion(AccountDeletionItem item, String reason) async {
    final restored = await read(accountDeletionRepositoryProvider).cancel(item.id, reason: reason);
    invalidate(accountDeletionsProvider);
    invalidate(userAccountDeletionProvider(item.userId));
    return restored;
  }
}
