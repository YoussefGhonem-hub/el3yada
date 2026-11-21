import 'package:go_router/go_router.dart';

import 'live_board_screen.dart';
import 'patient_appointment_screens.dart';
import 'schedule_editor_screen.dart';
import 'staff_appointment_screens.dart';
import 'waiting_room_screen.dart';

/// Phase 6 pages: the live board, calendar, booking, search, schedule, the waiting-room screen D36 (staff)
/// and P15–P17 (patient).
abstract final class AppointmentsRoutes {
  static final Map<String, GoRouterWidgetBuilder> shellPages = {
    '/doctor/live': (context, state) => const LiveBoardScreen(basePath: '/doctor'),
    '/assistant/live': (context, state) => const LiveBoardScreen(basePath: '/assistant'),
    '/doctor/appointments': (context, state) => const AppointmentsCalendarScreen(basePath: '/doctor'),
    '/assistant/appointments': (context, state) => const AppointmentsCalendarScreen(basePath: '/assistant'),
    '/doctor/schedule': (context, state) => const ScheduleEditorScreen(),
    '/assistant/schedule': (context, state) => const ScheduleEditorScreen(),
    '/patient/appointments': (context, state) => const MyAppointmentsScreen(),
  };

  static final List<GoRoute> detailRoutes = [
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
