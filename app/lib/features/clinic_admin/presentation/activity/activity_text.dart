import 'package:flutter/material.dart';

import '../../../../core/format/app_format.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../patients/clinic_paths.dart';
import '../../../records/domain/record_models.dart';
import '../../../records/presentation/record_text.dart';
import '../../clinic_admin_routes.dart';
import '../../domain/activity_models.dart';
import '../assistants/assistant_text.dart';
import '../branches/branch_text.dart';

/// Names the activity text needs but the row doesn't carry: branches by
/// ID (from `clinic/me`) and people by user ID (the log's `people`).
class ActivityNames {
  const ActivityNames({this.branches = const {}, this.people = const {}});

  final Map<String, String> branches;
  final Map<String, String> people;
}

/// Human text for D27 rows, like AD15's `AuditText`: a sentence per action
/// (without the actor, who shows under it), names for the action filter,
/// and an icon. To add an action, add one line to each switch and its ARB
/// keys. Unknown actions read «إجراء آخر: something new».
extension ActivityText on AppLocalizations {
  String activitySentence(ActivityEntry entry, ActivityNames names) {
    final d = entry.details;
    final target = entry.targetId;
    String branch([Object? id]) =>
        names.branches[id ?? target] ?? (d['nameAr'] as String?) ?? activitySomeBranch;
    String person() => names.people[target] ?? activitySomeAssistant;
    String status(Object? value) => branchStatusName('$value');
    return switch (entry.action) {
      'branchCreated' => activityBranchCreated(branch()),
      'branchUpdated' => activityBranchUpdated(branch()),
      'branchHoursUpdated' => activityBranchHoursUpdated(branch()),
      'branchStatusChanged' => activityBranchStatusChanged(branch(), status(d['before']), status(d['after'])),
      'defaultBranchChanged' => activityDefaultBranchChanged(branch()),
      'pricesUpdated' => d['branchId'] == null ? activityDoctorPricesUpdated : activityBranchPricesUpdated(branch(d['branchId'])),
      'doctorProfileUpdated' => activityProfileUpdated,
      'doctorSpecialtyChanged' => activitySpecialtyChanged,
      'assistantCreated' => activityAssistantCreated(person(), assistantPresetName('${d['preset']}')),
      'assistantUpdated' => activityAssistantUpdated(person()),
      'assistantPermissionsChanged' => activityAssistantPermissionsChanged(person()),
      'assistantPasswordReset' => activityAssistantPasswordReset(person()),
      'assistantDisabled' => activityAssistantDisabled(person()),
      'assistantEnabled' => activityAssistantEnabled(person()),
      'assistantRemoved' => activityAssistantRemoved(person()),
      'passwordChanged' => activityPasswordChanged,
      'passwordSet' => activityPasswordSet,
      'passwordResetRequested' => activityPasswordResetRequested(names.people[target] ?? activitySomeAssistant),
      'doctorRegistrationSubmitted' || 'doctorRegistrationResubmitted' => activityRegistrationSent,
      'emailVerified' => activityEmailVerified,
      // Patients and sessions (api-phase-2-patients.md, "Audit actions"). The patient shows under the sentence.
      'patientCreated' => activityPatientCreated,
      'patientLinked' => activityPatientLinked,
      'patientUpdated' => activityPatientUpdated,
      'patientPhoneChanged' => activityPatientPhoneChanged,
      'patientPasswordReset' => activityPatientPasswordReset,
      'patientArchived' => activityPatientArchived,
      'patientUnarchived' => activityPatientUnarchived,
      'patientMedicalProfileUpdated' => activityPatientMedicalProfileUpdated,
      'sessionCreated' => d['type'] == 'consultation' ? activitySessionCreatedConsultation : activitySessionCreatedExamination,
      'sessionClinicalUpdated' => activitySessionClinicalUpdated,
      'sessionPrivateNoteUpdated' => activitySessionPrivateNoteUpdated,
      'sessionAmountChanged' => activitySessionAmountChanged,
      'sessionDeleted' => activitySessionDeleted,
      // Medical files (api-phase-3-files.md). The patient shows under the sentence.
      'medicalRecordCreated' => activityRecordCreated,
      'medicalRecordUpdated' => activityRecordUpdated,
      'medicalRecordDeleted' => activityRecordDeleted,
      // Prescriptions and print settings (api-phase-3-prescriptions.md).
      'prescriptionDraftCreated' => d['copyFromId'] != null
          ? activityPrescriptionCopied(_rxKind(d['kind']))
          : activityPrescriptionDraftCreated(_rxKind(d['kind'])),
      'prescriptionDraftUpdated' => activityPrescriptionDraftUpdated(_rxKind(d['kind'])),
      'prescriptionDraftDeleted' => activityPrescriptionDraftDeleted(_rxKind(d['kind'])),
      'prescriptionSubmittedForReview' => activityPrescriptionSubmitted(_rxKind(d['kind'])),
      'prescriptionSent' => activityPrescriptionSent(_rxKind(d['kind'])),
      'prescriptionCancelled' => activityPrescriptionCancelled(_rxKind(d['kind'])),
      'rxSettingsUpdated' => activityRxSettingsUpdated,
      'rxBrandingUpdated' => d['image'] == 'signature'
          ? (d['removed'] == true ? activityRxSignatureRemoved : activityRxSignatureUpdated)
          : (d['removed'] == true ? activityRxLogoRemoved : activityRxLogoUpdated),
      _ => activityOther(humanizeAction(entry.action)),
    };
  }

  /// The action's name in the filter menu.
  String activityActionName(String action) => switch (action) {
        'branchCreated' => activityActionBranchCreated,
        'branchUpdated' => activityActionBranchUpdated,
        'branchHoursUpdated' => activityActionBranchHoursUpdated,
        'branchStatusChanged' => activityActionBranchStatusChanged,
        'defaultBranchChanged' => activityActionDefaultBranchChanged,
        'pricesUpdated' => activityActionPricesUpdated,
        'doctorProfileUpdated' => activityActionProfileUpdated,
        'doctorSpecialtyChanged' => activityActionSpecialtyChanged,
        'assistantCreated' => activityActionAssistantCreated,
        'assistantUpdated' => activityActionAssistantUpdated,
        'assistantPermissionsChanged' => activityActionPermissionsChanged,
        'assistantPasswordReset' => activityActionAssistantPasswordReset,
        'assistantDisabled' => activityActionAssistantDisabled,
        'assistantEnabled' => activityActionAssistantEnabled,
        'assistantRemoved' => activityActionAssistantRemoved,
        'passwordChanged' => activityActionPasswordChanged,
        'passwordSet' => activityActionPasswordSet,
        'passwordResetRequested' => activityActionPasswordResetRequested,
        'doctorRegistrationSubmitted' || 'doctorRegistrationResubmitted' => activityActionRegistrationSent,
        'emailVerified' => activityActionEmailVerified,
        'patientCreated' => activityActionPatientCreated,
        'patientLinked' => activityActionPatientLinked,
        'patientUpdated' => activityActionPatientUpdated,
        'patientPhoneChanged' => activityActionPatientPhoneChanged,
        'patientPasswordReset' => activityActionPatientPasswordReset,
        'patientArchived' => activityActionPatientArchived,
        'patientUnarchived' => activityActionPatientUnarchived,
        'patientMedicalProfileUpdated' => activityActionPatientMedicalProfileUpdated,
        'sessionCreated' => activityActionSessionCreated,
        'sessionClinicalUpdated' => activityActionSessionClinicalUpdated,
        'sessionPrivateNoteUpdated' => activityActionSessionPrivateNoteUpdated,
        'sessionAmountChanged' => activityActionSessionAmountChanged,
        'sessionDeleted' => activityActionSessionDeleted,
        'medicalRecordCreated' => activityActionRecordCreated,
        'medicalRecordUpdated' => activityActionRecordUpdated,
        'medicalRecordDeleted' => activityActionRecordDeleted,
        'prescriptionDraftCreated' => activityActionPrescriptionDraftCreated,
        'prescriptionDraftUpdated' => activityActionPrescriptionDraftUpdated,
        'prescriptionDraftDeleted' => activityActionPrescriptionDraftDeleted,
        'prescriptionSubmittedForReview' => activityActionPrescriptionSubmitted,
        'prescriptionSent' => activityActionPrescriptionSent,
        'prescriptionCancelled' => activityActionPrescriptionCancelled,
        'rxSettingsUpdated' => activityActionRxSettingsUpdated,
        'rxBrandingUpdated' => activityActionRxBrandingUpdated,
        _ => humanizeAction(action),
      };

  /// A second line for actions whose details say what changed, or null.
  String? activityDetail(BuildContext context, ActivityEntry entry) {
    final d = entry.details;
    switch (entry.action) {
      case 'pricesUpdated':
        final before = d['before'];
        final after = d['after'];
        if (before is! Map || after is! Map) return null;
        String money(Object? piasters) => piasters is int ? AppFormat.egp(context, piasters) : pricesNotSet;
        return [
          if (before['examinationPricePiasters'] != after['examinationPricePiasters'])
            pricesChange(regExaminationPrice, money(before['examinationPricePiasters']), money(after['examinationPricePiasters'])),
          if (before['consultationPricePiasters'] != after['consultationPricePiasters'])
            pricesChange(regConsultationPrice, money(before['consultationPricePiasters']), money(after['consultationPricePiasters'])),
        ].join(adminListSeparator);
      case 'assistantPermissionsChanged':
        final added = [for (final key in (d['added'] as List?) ?? const []) '$key'];
        final removed = [for (final key in (d['removed'] as List?) ?? const []) '$key'];
        return [
          if (added.isNotEmpty) activityPermissionsAdded(permissionList(added)),
          if (removed.isNotEmpty) activityPermissionsRemoved(permissionList(removed)),
        ].join(' ');
      case 'branchUpdated':
        final groups = [for (final g in (d['groups'] as List?) ?? const []) _groupName('$g')];
        return groups.isEmpty ? null : groups.join(adminListSeparator);
      case 'branchHoursUpdated':
        final periods = d['periods'];
        return periods is int ? activityPeriods(periods) : null;
      case 'sessionAmountChanged':
        final before = d['before'];
        final after = d['after'];
        return before is int && after is int
            ? activityFromTo(AppFormat.egp(context, before), AppFormat.egp(context, after))
            : null;
      case 'sessionDeleted':
        final reason = d['reason'];
        return reason is String && reason.isNotEmpty ? activityReason(reason) : null;
      case 'medicalRecordCreated':
        final category = d['category'];
        final files = d['attachments'];
        return [
          if (category is String) recordCategoryName(RecordCategory.fromWire(category)),
          if (files is int) recordFilesCount(files),
          if (d['sizeBytes'] case final int size) fileSize(size),
        ].join(adminListSeparator);
      case 'medicalRecordUpdated' || 'medicalRecordDeleted':
        final category = d['category'];
        return category is String ? recordCategoryName(RecordCategory.fromWire(category)) : null;
      case 'prescriptionSent' || 'prescriptionDraftUpdated':
        final items = d['items'];
        return items is int ? activityRxItems(items) : null;
      default:
        return null;
    }
  }

  String _groupName(String group) => switch (group) {
        'info' => branchTabInfo,
        'address' => branchTabAddress,
        'contact' => branchTabContact,
        'clinicInfo' => branchTabClinic,
        _ => group,
      };

  /// «روشتة علاج» or «روشتة تحاليل وأشعة» from an audit row's `kind`.
  String _rxKind(Object? kind) => kind == 'investigations' ? rxKindInvestigations : rxKindMedication;

  String activityRole(String role) => switch (role) {
        'doctor' => roleDoctor,
        'assistant' => roleAssistant,
        _ => adminSystem,
      };
}

/// `patientCreated` → "patient created", for actions this app doesn't know yet.
String humanizeAction(String action) =>
    action.replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}').toLowerCase();

/// The icon on a row.
IconData activityIcon(String action) => switch (action) {
      'branchCreated' => Icons.add_business_outlined,
      'branchUpdated' || 'defaultBranchChanged' => Icons.store_mall_directory_outlined,
      'branchHoursUpdated' => Icons.schedule_outlined,
      'branchStatusChanged' => Icons.toggle_on_outlined,
      'pricesUpdated' => Icons.sell_outlined,
      'doctorProfileUpdated' || 'doctorSpecialtyChanged' => Icons.badge_outlined,
      'assistantCreated' => Icons.person_add_alt_1_outlined,
      'assistantPermissionsChanged' => Icons.verified_user_outlined,
      'assistantDisabled' || 'assistantRemoved' => Icons.person_off_outlined,
      'assistantEnabled' || 'assistantUpdated' => Icons.person_outline,
      'assistantPasswordReset' || 'passwordChanged' || 'passwordSet' || 'passwordResetRequested' || 'patientPasswordReset' =>
        Icons.key_outlined,
      'patientCreated' || 'patientLinked' => Icons.person_add_alt_outlined,
      'patientUpdated' || 'patientPhoneChanged' => Icons.edit_outlined,
      'patientArchived' || 'patientUnarchived' => Icons.inventory_2_outlined,
      'patientMedicalProfileUpdated' => Icons.medical_information_outlined,
      'sessionCreated' => Icons.event_available_outlined,
      'sessionClinicalUpdated' || 'sessionPrivateNoteUpdated' => Icons.edit_note_outlined,
      'sessionAmountChanged' => Icons.payments_outlined,
      'sessionDeleted' || 'medicalRecordDeleted' => Icons.delete_outline,
      'medicalRecordCreated' => Icons.note_add_outlined,
      'medicalRecordUpdated' => Icons.edit_document,
      'prescriptionDraftCreated' || 'prescriptionDraftUpdated' || 'prescriptionSubmittedForReview' => Icons.edit_note_outlined,
      'prescriptionDraftDeleted' => Icons.delete_outline,
      'prescriptionSent' => Icons.send_outlined,
      'prescriptionCancelled' => Icons.block,
      'rxSettingsUpdated' || 'rxBrandingUpdated' => Icons.print_outlined,
      _ => Icons.history,
    };

/// Where a row opens (spec D27 "tap opens the related item"), or null.
/// D27 is the doctor's, so patients and visits open under `/doctor`. A
/// deleted visit opens its patient.
String? activityTargetPath(ActivityEntry entry) {
  final id = entry.targetId;
  final patientId = entry.patient?.id;
  return switch ((entry.targetType, entry.action)) {
    ('patient', _) when id != null => ClinicPaths.doctor.patient(id),
    ('session', 'sessionDeleted') when patientId != null => ClinicPaths.doctor.patient(patientId),
    ('session', _) when id != null && patientId != null => ClinicPaths.doctor.patientSession(patientId, id),
    ('medicalRecord', 'medicalRecordDeleted') when patientId != null => ClinicPaths.doctor.patient(patientId),
    ('medicalRecord', _) when id != null && patientId != null => ClinicPaths.doctor.record(patientId, id),
    // A deleted draft opens its patient.
    ('prescription', 'prescriptionDraftDeleted') when patientId != null => ClinicPaths.doctor.patient(patientId),
    ('prescription', _) when id != null && patientId != null => ClinicPaths.doctor.prescription(patientId, id),
    ('doctor', 'rxSettingsUpdated' || 'rxBrandingUpdated') => ClinicAdminRoutes.doctorRxSettings,
    ('branch', _) when id != null => ClinicAdminRoutes.branch(id),
    ('assistant', _) when id != null => ClinicAdminRoutes.assistant(id),
    ('doctor', 'pricesUpdated') => ClinicAdminRoutes.doctorPrices,
    ('doctor', _) => ClinicAdminRoutes.doctorProfile,
    _ => null,
  };
}
