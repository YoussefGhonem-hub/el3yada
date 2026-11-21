import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../clinic/application/clinic_providers.dart' as clinic;
import '../../clinic_admin/clinic_admin_routes.dart';
import '../../clinic_admin/presentation/branches/assistant_schedule_screen.dart';
import '../../clinic_admin/presentation/branches/branch_editor_screen.dart';
import 'live_board_screen.dart';
import 'patient_appointment_screens.dart';
import 'staff_appointment_screens.dart';
import 'waiting_room_screen.dart';

/// Phase 6 pages: the live board, calendar, booking, search, the waiting-room screen D36 (staff) and
/// P15–P17 (patient). A branch's hours, special dates and booking settings are edited in one place,
/// D29's schedule tabs: AS17 is the assistant's view of it, and `/doctor/schedule` (the old Schedule
/// page) leads there.
abstract final class AppointmentsRoutes {
  static final Map<String, GoRouterWidgetBuilder> shellPages = {
    '/doctor/live': (context, state) => const LiveBoardScreen(basePath: '/doctor'),
    '/assistant/live': (context, state) => const LiveBoardScreen(basePath: '/assistant'),
    '/doctor/appointments': (context, state) => const AppointmentsCalendarScreen(basePath: '/doctor'),
    '/assistant/appointments': (context, state) => const AppointmentsCalendarScreen(basePath: '/assistant'),
    // AS17: D29 of the current branch, on a schedule tab (`?tab=dates` …).
    '/assistant/schedule': (context, state) =>
        AssistantScheduleScreen(initialTab: BranchEditorScreen.tabNamed(state.uri.queryParameters['tab'])),
    '/patient/appointments': (context, state) => const MyAppointmentsScreen(),
  };

  static final List<GoRoute> detailRoutes = [
    // The doctor's old Schedule page: D29 of the current branch, on the tab asked for (Working hours by default).
    GoRoute(
      path: '/doctor/schedule',
      redirect: (context, state) {
        final branch = ProviderScope.containerOf(context, listen: false).read(clinic.currentBranchProvider);
        final tab = BranchEditorScreen.tabNamed(state.uri.queryParameters['tab']) ?? BranchTab.hours;
        return branch == null ? ClinicAdminRoutes.branches : ClinicAdminRoutes.branch(branch.id, tab: tab.name);
      },
    ),
    // Fixed paths before the `:id` ones.
    GoRoute(
      path: '/patient/appointments/book',
      builder: (context, state) => BookAppointmentScreen(
        rescheduleId: state.uri.queryParameters['reschedule'],
        doctorId: state.uri.queryParameters['doctor'],
      ),
    ),
    GoRoute(path: '/patient/appointments/:id', builder: (context, state) => MyAppointmentDetailScreen(appointmentId: state.pathParameters['id']!)),
    for (final base in ['/doctor', '/assistant']) ...[
      GoRoute(
        path: '$base/appointments/book',
        builder: (context, state) => StaffBookScreen(basePath: base, rescheduleId: state.uri.queryParameters['reschedule']),
      ),
      GoRoute(path: '$base/appointments/search', builder: (context, state) => AppointmentsSearchScreen(basePath: base)),
      // D36 [C]: full screen, over the shell. `?branch=` is the board's branch.
      GoRoute(
        path: '$base/waiting-room',
        builder: (context, state) => WaitingRoomScreen(branchId: state.uri.queryParameters['branch'] ?? '', basePath: base),
      ),
      GoRoute(
        path: '$base/appointments/:id',
        builder: (context, state) => StaffAppointmentDetailScreen(appointmentId: state.pathParameters['id']!, basePath: base),
      ),
    ],
  ];
}
