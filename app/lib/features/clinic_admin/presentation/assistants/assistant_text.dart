import 'package:material_ui/material_ui.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../../clinic/domain/clinic_permissions.dart';
import '../../domain/assistant_models.dart';
import '../widgets/clinic_admin_widgets.dart';

/// The D26 checklist in groups, in the order of the spec 6.10 table.
const permissionGroups = <(String, List<String>)>[
  ('patients', [ClinicPermission.patientsManage, ClinicPermission.patientsResetPassword]),
  ('sessions', [ClinicPermission.sessionsCreate, ClinicPermission.sessionsDelete]),
  ('clinical', [ClinicPermission.clinicalView, ClinicPermission.clinicalEditProfile]),
  ('files', [ClinicPermission.filesManage, ClinicPermission.prescriptionsPrint, ClinicPermission.prescriptionsDraft]),
  ('chat', [ClinicPermission.chat]),
  ('billing', [ClinicPermission.billingView, ClinicPermission.billingPay]),
  ('appointments', [ClinicPermission.appointmentsView, ClinicPermission.appointmentsManage, ClinicPermission.scheduleManage]),
  ('money', [ClinicPermission.revenueView, ClinicPermission.pricesManage]),
];

IconData permissionGroupIcon(String group) => switch (group) {
      'patients' => Icons.people_alt_outlined,
      'sessions' => Icons.medical_services_outlined,
      'clinical' => Icons.favorite_outline,
      'files' => Icons.folder_outlined,
      'chat' => Icons.chat_bubble_outline,
      'billing' => Icons.receipt_long_outlined,
      'appointments' => Icons.event_note_outlined,
      _ => Icons.payments_outlined,
    };

/// Names and one-line explanations for presets and permissions (spec 6.10),
/// shared by D25, D26 and AS12 "My permissions".
extension AssistantText on AppLocalizations {
  String assistantPresetName(String preset) => switch (preset) {
        AssistantPreset.reception => assistantPresetReception,
        AssistantPreset.clinical => assistantPresetClinical,
        AssistantPreset.officeManager => assistantPresetOfficeManager,
        _ => assistantPresetCustom,
      };

  String assistantPresetBody(String preset) => switch (preset) {
        AssistantPreset.reception => assistantPresetReceptionBody,
        AssistantPreset.clinical => assistantPresetClinicalBody,
        AssistantPreset.officeManager => assistantPresetOfficeManagerBody,
        _ => assistantPresetCustomBody,
      };

  String permissionGroupName(String group) => switch (group) {
        'patients' => assistantGroupPatients,
        'sessions' => assistantGroupSessions,
        'clinical' => assistantGroupClinical,
        'files' => assistantGroupFiles,
        'chat' => assistantGroupChat,
        'billing' => assistantGroupBilling,
        'appointments' => assistantGroupAppointments,
        _ => assistantGroupMoney,
      };

  String permissionName(String key) => switch (key) {
        ClinicPermission.patientsManage => assistantPermPatientsManage,
        ClinicPermission.patientsResetPassword => assistantPermPatientsResetPassword,
        ClinicPermission.sessionsCreate => assistantPermSessionsCreate,
        ClinicPermission.sessionsDelete => assistantPermSessionsDelete,
        ClinicPermission.clinicalView => assistantPermClinicalView,
        ClinicPermission.clinicalEditProfile => assistantPermClinicalEditProfile,
        ClinicPermission.filesManage => assistantPermFilesManage,
        ClinicPermission.prescriptionsPrint => assistantPermPrescriptionsPrint,
        ClinicPermission.prescriptionsDraft => assistantPermPrescriptionsDraft,
        ClinicPermission.chat => assistantPermChat,
        ClinicPermission.billingView => assistantPermBillingView,
        ClinicPermission.billingPay => assistantPermBillingPay,
        ClinicPermission.appointmentsView => assistantPermAppointmentsView,
        ClinicPermission.appointmentsManage => assistantPermAppointmentsManage,
        ClinicPermission.scheduleManage => assistantPermScheduleManage,
        ClinicPermission.revenueView => assistantPermRevenueView,
        ClinicPermission.pricesManage => assistantPermPricesManage,
        _ => key,
      };

  String permissionHelp(String key) => switch (key) {
        ClinicPermission.patientsManage => assistantPermPatientsManageHelp,
        ClinicPermission.patientsResetPassword => assistantPermPatientsResetPasswordHelp,
        ClinicPermission.sessionsCreate => assistantPermSessionsCreateHelp,
        ClinicPermission.sessionsDelete => assistantPermSessionsDeleteHelp,
        ClinicPermission.clinicalView => assistantPermClinicalViewHelp,
        ClinicPermission.clinicalEditProfile => assistantPermClinicalEditProfileHelp,
        ClinicPermission.filesManage => assistantPermFilesManageHelp,
        ClinicPermission.prescriptionsPrint => assistantPermPrescriptionsPrintHelp,
        ClinicPermission.prescriptionsDraft => assistantPermPrescriptionsDraftHelp,
        ClinicPermission.chat => assistantPermChatHelp,
        ClinicPermission.billingView => assistantPermBillingViewHelp,
        ClinicPermission.billingPay => assistantPermBillingPayHelp,
        ClinicPermission.appointmentsView => assistantPermAppointmentsViewHelp,
        ClinicPermission.appointmentsManage => assistantPermAppointmentsManageHelp,
        ClinicPermission.scheduleManage => assistantPermScheduleManageHelp,
        ClinicPermission.revenueView => assistantPermRevenueViewHelp,
        ClinicPermission.pricesManage => assistantPermPricesManageHelp,
        _ => '',
      };

  /// «إدارة المرضى، الملفات» for the keys in checklist order.
  String permissionList(Iterable<String> keys) => [
        for (final key in ClinicPermission.all)
          if (keys.contains(key)) permissionName(key),
      ].join(adminListSeparator);

  String assistantStatusName(String status) => switch (status) {
        AssistantStatuses.disabled => adminStatusDisabled,
        AssistantStatuses.removed => assistantStatusRemoved,
        _ => adminStatusActive,
      };
}

/// The status as a pill: active, disabled (red) or removed.
class AssistantStatusPill extends StatelessWidget {
  const AssistantStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: AppLocalizations.of(context).assistantStatusName(status),
        tone: switch (status) {
          AssistantStatuses.active => PillTone.positive,
          AssistantStatuses.disabled => PillTone.danger,
          _ => PillTone.neutral,
        },
      );
}

/// The preset as a pill; custom is neutral.
class PresetPill extends StatelessWidget {
  const PresetPill({super.key, required this.preset});

  final String preset;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: AppLocalizations.of(context).assistantPresetName(preset),
        tone: preset == AssistantPreset.custom ? PillTone.neutral : PillTone.positive,
        icon: switch (preset) {
          AssistantPreset.reception => Icons.support_agent_outlined,
          AssistantPreset.clinical => Icons.medical_services_outlined,
          AssistantPreset.officeManager => Icons.business_center_outlined,
          _ => Icons.tune,
        },
      );
}
