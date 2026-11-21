import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/admin_models.dart';
import '../settings/setting_labels.dart';
import '../widgets/admin_widgets.dart';

/// Human text for AD15 rows: a sentence per action, names for the filters,
/// and readable details.
extension AuditText on AppLocalizations {
  /// What happened, as a sentence without the actor («وافق على طلب تسجيل طبيب»).
  String auditSentence(AuditEntry entry) {
    final details = entry.details ?? const {};
    String role(Object? value) => adminRoleLabel(this, AdminRole.fromJson(value as String?));
    return switch (entry.action) {
      'doctorRegistrationSubmitted' => adminAuditRegistrationSubmitted,
      'doctorRegistrationResubmitted' => adminAuditRegistrationResubmitted,
      'doctorRegistrationApproved' => adminAuditRegistrationApproved,
      'doctorRegistrationRejected' => adminAuditRegistrationRejected,
      'doctorLicenseViewed' => adminAuditLicenseViewed,
      'doctorServiceActivated' => adminAuditServiceActivated,
      'doctorTrialExtended' => adminAuditTrialExtended((details['days'] as num?)?.toInt() ?? 0),
      'doctorCreated' => adminAuditDoctorCreated,
      'broadcastSent' => adminAuditBroadcastSent,
      'adminSeeded' => adminAuditAdminSeeded,
      'adminCreated' => adminAuditAdminCreated(role(details['adminRole'])),
      'adminRoleChanged' => adminAuditAdminRoleChanged(role(details['before']), role(details['after'])),
      'adminDisabled' => adminAuditAdminDisabled,
      'adminEnabled' => adminAuditAdminEnabled,
      'adminProfileUpdated' => adminAuditProfileUpdated,
      'settingsUpdated' => adminAuditSettingsUpdated(_fields(details['fields'])),
      'passwordSet' => adminAuditPasswordSet,
      'passwordChanged' => adminAuditPasswordChanged,
      'passwordResetRequested' =>
        details['channel'] == 'doctor' ? adminAuditResetRequestedDoctor : adminAuditResetRequestedEmail,
      'passwordReset' => adminAuditPasswordReset,
      'accountLockedOut' => adminAuditLockedOut,
      'refreshTokenReuseDetected' => adminAuditTokenReuse,
      'emailVerified' => adminAuditEmailVerified,
      _ => entry.action,
    };
  }

  /// The action's name in the filter menu.
  String auditActionName(String action) => switch (action) {
        'doctorRegistrationSubmitted' => adminActionRegistrationSubmitted,
        'doctorRegistrationResubmitted' => adminActionRegistrationResubmitted,
        'doctorRegistrationApproved' => adminActionRegistrationApproved,
        'doctorRegistrationRejected' => adminActionRegistrationRejected,
        'doctorLicenseViewed' => adminActionLicenseViewed,
        'doctorServiceActivated' => adminActionServiceActivated,
        'doctorTrialExtended' => adminActionTrialExtended,
        'doctorCreated' => adminActionDoctorCreated,
        'broadcastSent' => adminActionBroadcastSent,
        'adminSeeded' => adminActionAdminSeeded,
        'adminCreated' => adminActionAdminCreated,
        'adminRoleChanged' => adminActionAdminRoleChanged,
        'adminDisabled' => adminActionAdminDisabled,
        'adminEnabled' => adminActionAdminEnabled,
        'adminProfileUpdated' => adminActionProfileUpdated,
        'settingsUpdated' => adminActionSettingsUpdated,
        'passwordSet' => adminActionPasswordSet,
        'passwordChanged' => adminActionPasswordChanged,
        'passwordResetRequested' => adminActionResetRequested,
        'passwordReset' => adminActionPasswordReset,
        'accountLockedOut' => adminActionLockedOut,
        'refreshTokenReuseDetected' => adminActionTokenReuse,
        'emailVerified' => adminActionEmailVerified,
        _ => action,
      };

  String auditActorRole(String role) => switch (role) {
        'admin' => roleAdmin,
        'doctor' => roleDoctor,
        'assistant' => roleAssistant,
        'patient' => rolePatient,
        _ => adminSystem,
      };

  String auditTargetType(String type) => switch (type) {
        'doctor' => adminTargetDoctor,
        'user' => adminTargetUser,
        'settings' => adminTargetSettings,
        'broadcast' => adminTargetBroadcast,
        _ => type,
      };

  /// Who did it: the name, or «النظام» for the system.
  String auditActor(AuditEntry entry) => entry.actorName ?? (entry.actorRole == 'system' ? adminSystem : adminUnknownUser);

  /// One detail's label.
  String auditDetailLabel(String key) => switch (key) {
        'reason' => adminRejectReasonLabel,
        'adminRole' => adminColumnRole,
        'before' => adminHistoryBefore,
        'after' => adminHistoryAfter,
        'fields' => adminDetailFields,
        'channel' => adminDetailChannel,
        _ => key,
      };

  /// One detail's value, readable.
  String auditDetailValue(String key, Object? value) => switch ((key, value)) {
        ('adminRole' || 'before' || 'after', final String role) => adminRoleLabel(this, AdminRole.fromJson(role)),
        ('fields', final List<dynamic> fields) => _fields(fields),
        ('channel', 'email') => adminChannelEmail,
        ('channel', 'doctor') => adminChannelDoctor,
        (_, null) => adminEmptyValue,
        (_, final String text) => text,
        _ => '$value',
      };

  String _fields(Object? fields) => fields is List
      ? fields.map((field) => settingLabel('$field')).join(adminListSeparator)
      : '';
}
