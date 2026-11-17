import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../home/presentation/clinic_home_screen.dart';
import '../home/presentation/dashboard_screen.dart';
import '../prescriptions/presentation/prescription_view.dart';
import '../sessions/domain/session_models.dart';
import '../sessions/presentation/monthly_summary_screen.dart';
import '../sessions/presentation/new_session_screen.dart';
import '../sessions/presentation/session_details_screen.dart';
import '../sessions/presentation/today_sessions_screen.dart';
import 'clinic_paths.dart';
import 'presentation/add_patient_screen.dart';
import 'presentation/edit_patient_screen.dart';
import 'presentation/patient_profile_screen.dart';
import 'presentation/patients_register_screen.dart';

/// The patient, session and fee screens behind the doctor's and the
/// assistant's menu items (app/destination_pages.dart spreads these in).
final Map<String, WidgetBuilder> clinicDestinationScreens = {
  for (final paths in ClinicPaths.all) ...{
    // D34 / AS1: Phase 6 puts the live board here.
    paths.home: (_) => const ClinicHomeScreen(),
    paths.patients: (_) => const PatientsRegisterScreen(),
    paths.dashboard: (_) => const DashboardScreen(),
  },
};

/// Detail routes under those items, relative to them.
final Map<String, List<RouteBase>> clinicDestinationRoutes = {
  for (final paths in ClinicPaths.all) ...{
    paths.home: [
      GoRoute(path: 'sessions/new', builder: (context, state) => const NewSessionScreen(origin: SessionOrigin.home)),
      GoRoute(
        path: 'sessions/:sessionId',
        builder: (context, state) => SessionDetailsPage(sessionId: state.pathParameters['sessionId']!),
      ),
    ],
    paths.patients: [
      GoRoute(path: 'new', builder: (context, state) => const AddPatientScreen()),
      GoRoute(
        path: ':patientId',
        builder: (context, state) => PatientProfilePage(patientId: state.pathParameters['patientId']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => EditPatientScreen(
              patientId: state.pathParameters['patientId']!,
              medicalFirst: state.uri.queryParameters['part'] == 'medical',
            ),
          ),
          GoRoute(
            path: 'sessions/new',
            builder: (context, state) => NewSessionScreen(patientId: state.pathParameters['patientId']!),
          ),
          GoRoute(
            path: 'sessions/:sessionId',
            builder: (context, state) =>
                SessionDetailsPage(sessionId: state.pathParameters['sessionId']!, showPatientLink: false),
          ),
          // D13–D15, AS7, AS8.
          GoRoute(
            path: 'prescriptions/:prescriptionId',
            builder: (context, state) => PrescriptionPage(prescriptionId: state.pathParameters['prescriptionId']!),
            routes: [
              GoRoute(
                path: 'preview',
                builder: (context, state) =>
                    PrescriptionPage(prescriptionId: state.pathParameters['prescriptionId']!, preview: true),
              ),
            ],
          ),
        ],
      ),
    ],
    paths.dashboard: [
      GoRoute(
        path: 'today',
        builder: (context, state) => TodaySessionsScreen(day: _day(state.uri.queryParameters['day'])),
      ),
      GoRoute(
        path: 'month',
        builder: (context, state) => MonthlySummaryScreen(month: _month(state.uri.queryParameters['month'])),
      ),
      GoRoute(path: 'sessions/new', builder: (context, state) => const NewSessionScreen(origin: SessionOrigin.dashboard)),
      GoRoute(
        path: 'sessions/:sessionId',
        builder: (context, state) => SessionDetailsPage(sessionId: state.pathParameters['sessionId']!),
      ),
    ],
  },
};

DateTime? _day(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  return parseDay(value);
}

DateTime? _month(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) return null;
  return parseMonth(value);
}
