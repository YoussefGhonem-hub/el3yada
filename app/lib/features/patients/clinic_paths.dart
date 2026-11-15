import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/application/auth_controller.dart';
import '../auth/domain/user_role.dart';

/// Paths of the patient, session and fee screens, under the doctor's or the
/// assistant's area (the menu items are in role_shells.dart; the routes in
/// clinic_routes.dart). Screens import this file, not the routes.
class ClinicPaths {
  const ClinicPaths._(this.base);

  static const doctor = ClinicPaths._('/doctor');
  static const assistant = ClinicPaths._('/assistant');

  static const all = [doctor, assistant];

  final String base;

  /// The home: D34 / AS1 (today's sessions and quick actions until the live
  /// board arrives in Phase 6).
  String get home => '$base/live';

  /// D4, AS2.
  String get patients => '$base/patients';

  /// D5, AS3.
  String get addPatient => '$patients/new';

  /// D6, AS4.
  String patient(String patientId) => '$patients/$patientId';

  /// D7. [medical] opens it on the medical profile.
  String editPatient(String patientId, {bool medical = false}) =>
      '${patient(patientId)}/edit${medical ? '?part=medical' : ''}';

  /// D8, AS5 for a patient.
  String newSession(String patientId) => '${patient(patientId)}/sessions/new';

  /// D9 from the patient's Sessions tab.
  String patientSession(String patientId, String sessionId) => '${patient(patientId)}/sessions/$sessionId';

  /// D8 from the home, with a patient search first.
  String get homeNewSession => '$home/sessions/new';

  /// D9 from the home's list.
  String homeSession(String sessionId) => '$home/sessions/$sessionId';

  /// D1 / AS18.
  String get dashboard => '$base/dashboard';

  /// D2: one Cairo day (today by default).
  String today({String? day}) => '$dashboard/today${day == null ? '' : '?day=$day'}';

  /// D3: a month (this month by default).
  String month({String? month}) => '$dashboard/month${month == null ? '' : '?month=$month'}';

  /// D9 from D2.
  String dashboardSession(String sessionId) => '$dashboard/sessions/$sessionId';

  /// D8 from D2, with a patient search first.
  String get dashboardNewSession => '$dashboard/sessions/new';
}

/// The signed-in doctor's or assistant's paths.
final clinicPathsProvider = Provider<ClinicPaths>((ref) {
  final role = ref.watch(authControllerProvider.select((auth) => auth.value?.role));
  return role == UserRole.assistant ? ClinicPaths.assistant : ClinicPaths.doctor;
});
