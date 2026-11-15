import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/paged_controller.dart';
import '../data/sessions_repository.dart';
import '../domain/session_models.dart';

/// D8 step 1 for a patient in a branch. Read again after
/// `CONSULTATION_REQUIRES_EXAM` (someone saved first, AC-2).
final newSessionInfoProvider = FutureProvider.autoDispose.family<NewSessionInfo, ({String patientId, String branchId})>(
  (ref, key) => ref.watch(sessionsRepositoryProvider).newSessionInfo(patientId: key.patientId, branchId: key.branchId),
  retry: noRetry,
);

/// D9.
final sessionProvider = FutureProvider.autoDispose.family<SessionView, String>(
  (ref, sessionId) => ref.watch(sessionsRepositoryProvider).session(sessionId),
  retry: noRetry,
);

/// D9's private note (doctor only).
final privateNoteProvider = FutureProvider.autoDispose.family<PrivateNote, String>(
  (ref, sessionId) => ref.watch(sessionsRepositoryProvider).privateNote(sessionId),
  retry: noRetry,
);

/// What D2 and the homes ask `day` for. A null [day] is today (Cairo).
typedef DayQuery = ({DateTime? day, String? branchId, SessionType? type, String? recordedBy});

/// D2, AS1 and the doctor's home: one day's sessions with totals.
final daySessionsProvider = FutureProvider.autoDispose.family<DaySessions, DayQuery>(
  (ref, query) => ref.watch(sessionsRepositoryProvider).day(
        day: query.day,
        branchId: query.branchId,
        type: query.type,
        recordedBy: query.recordedBy,
      ),
  retry: noRetry,
);

/// D1 fee cards (`billingView`).
final feeSummaryProvider = FutureProvider.autoDispose<FeeSummary>(
  (ref) => ref.watch(sessionsRepositoryProvider).feeSummary(),
  retry: noRetry,
);

/// What D3 asks `month` for. A null [month] is this month.
typedef MonthQuery = ({DateTime? month, String? branchId});

/// D3 (`billingView`).
final monthFeesProvider = FutureProvider.autoDispose.family<MonthFees, MonthQuery>(
  (ref, query) => ref.watch(sessionsRepositoryProvider).month(month: query.month, branchId: query.branchId),
  retry: noRetry,
);

/// Every fee total and day list loads again (after a session was saved,
/// changed or deleted), keeping what is on screen meanwhile.
void refreshFees(WidgetRef ref) {
  ref.invalidate(daySessionsProvider);
  ref.invalidate(feeSummaryProvider);
  ref.invalidate(monthFeesProvider);
  ref.invalidate(newSessionInfoProvider);
}
