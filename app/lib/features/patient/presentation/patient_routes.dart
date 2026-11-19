import 'package:go_router/go_router.dart';

import 'doctor_info_screen.dart';
import 'medical_file_screen.dart';
import 'medical_profile_screen.dart';
import 'my_doctors_screen.dart';
import 'patient_account_screen.dart';
import 'patient_home_screen.dart';
import 'pdf_view_screen.dart';
import 'prescription_detail_screen.dart';
import 'record_viewer_screen.dart';
import 'visit_detail_screen.dart';

enum MedicalFileTab { visits, prescriptions, files }

/// Paths of the patient area (spec 7.4). Tabs live inside the role shell; details are
/// pushed full screen with their own back button.
abstract final class PatientRoutes {
  static const home = '/patient/home';
  static const fileBase = '/patient/file';
  static const account = '/patient/account';
  static const doctors = '/patient/doctors';
  static const medicalProfile = '/patient/profile';

  static String file({MedicalFileTab tab = MedicalFileTab.visits}) => '$fileBase?tab=${tab.name}';
  static String doctor(String id) => '/patient/doctors/$id';
  static String visit(String id) => '/patient/visits/$id';
  static String prescription(String id) => '/patient/prescriptions/$id';
  static String prescriptionPdf(String id) => '/patient/prescriptions/$id/pdf';
  static String record(String id, {int attachment = 0}) => '/patient/records/$id?attachment=$attachment';

  /// Pages shown inside the patient shell (bottom bar or side menu stays visible).
  static final Map<String, GoRouterWidgetBuilder> shellPages = {
    home: (context, state) => const PatientHomeScreen(),
    fileBase: (context, state) => MedicalFileScreen(
          initialTab: MedicalFileTab.values.asNameMap()[state.uri.queryParameters['tab']] ?? MedicalFileTab.visits,
        ),
    account: (context, state) => const PatientAccountScreen(),
  };

  /// Full-screen detail pages.
  static final List<GoRoute> detailRoutes = [
    GoRoute(path: doctors, builder: (context, state) => const MyDoctorsScreen()),
    GoRoute(path: '/patient/doctors/:id', builder: (context, state) => DoctorInfoScreen(doctorId: state.pathParameters['id']!)),
    GoRoute(path: medicalProfile, builder: (context, state) => const MedicalProfileScreen()),
    GoRoute(path: '/patient/visits/:id', builder: (context, state) => VisitDetailScreen(visitId: state.pathParameters['id']!)),
    GoRoute(
      path: '/patient/prescriptions/:id',
      builder: (context, state) => PrescriptionDetailScreen(prescriptionId: state.pathParameters['id']!),
      routes: [
        GoRoute(path: 'pdf', builder: (context, state) => PdfViewScreen(prescriptionId: state.pathParameters['id']!)),
      ],
    ),
    GoRoute(
      path: '/patient/records/:id',
      builder: (context, state) => RecordViewerScreen(
        recordId: state.pathParameters['id']!,
        initialAttachment: int.tryParse(state.uri.queryParameters['attachment'] ?? '') ?? 0,
      ),
    ),
  ];
}
