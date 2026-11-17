import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../core/format/app_format.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/setting_fields.dart';

/// Names, hints and value display for AD13 settings.
extension SettingLabels on AppLocalizations {
  String settingLabel(String field) => switch (field) {
        'examFeePiasters' => adminSettingExamFee,
        'consultationFeePiasters' => adminSettingConsultationFee,
        'gracePeriodDays' => adminSettingGracePeriod,
        'maxConsecutiveConsultations' => adminSettingMaxConsultations,
        'trialDays' => adminSettingTrialDays,
        'instapayAddress' => adminSettingInstapayAddress,
        'instapayAccountName' => adminSettingInstapayName,
        'instapayInstructionsAr' => adminSettingInstapayInstructionsAr,
        'instapayInstructionsEn' => adminSettingInstapayInstructionsEn,
        'maxUploadMb' => adminSettingMaxUpload,
        'maxAssistantsPerDoctor' => adminSettingMaxAssistants,
        'maxBranchesPerDoctor' => adminSettingMaxBranches,
        'minVersionAndroid' => adminSettingVersionAndroid,
        'minVersionIos' => adminSettingVersionIos,
        'minVersionWindows' => adminSettingVersionWindows,
        'minVersionMacos' => adminSettingVersionMacos,
        'maintenanceEnabled' => adminSettingMaintenance,
        'maintenanceMessageAr' => adminSettingMaintenanceMessageAr,
        'maintenanceMessageEn' => adminSettingMaintenanceMessageEn,
        'supportPhone' => adminSettingSupportPhone,
        'supportWhatsapp' => adminSettingSupportWhatsapp,
        'supportEmail' => adminSettingSupportEmail,
        'termsAr' => adminSettingTermsAr,
        'termsEn' => adminSettingTermsEn,
        'privacyAr' => adminSettingPrivacyAr,
        'privacyEn' => adminSettingPrivacyEn,
        _ => field,
      };

  String settingGroupTitle(SettingGroup group) => switch (group) {
        SettingGroup.billing => adminGroupBilling,
        SettingGroup.payment => adminGroupPayment,
        SettingGroup.files => adminGroupFiles,
        SettingGroup.clinics => adminGroupClinics,
        SettingGroup.appVersions => adminGroupVersions,
        SettingGroup.maintenance => adminGroupMaintenance,
        SettingGroup.support => adminGroupSupport,
        SettingGroup.legal => adminGroupLegal,
      };

  String settingGroupDescription(SettingGroup group) => switch (group) {
        SettingGroup.billing => adminGroupBillingBody,
        SettingGroup.payment => adminGroupPaymentBody,
        SettingGroup.files => adminGroupFilesBody,
        SettingGroup.clinics => adminGroupClinicsBody,
        SettingGroup.appVersions => adminGroupVersionsBody,
        SettingGroup.maintenance => adminGroupMaintenanceBody,
        SettingGroup.support => adminGroupSupportBody,
        SettingGroup.legal => adminGroupLegalBody,
      };

  /// The unit after the number, if any.
  String? settingUnit(SettingFieldSpec field) => switch (field.name) {
        'examFeePiasters' || 'consultationFeePiasters' => adminCurrency,
        'gracePeriodDays' || 'trialDays' => adminUnitDays,
        'maxUploadMb' => adminUnitMb,
        _ => null,
      };

  /// The allowed range and the "new sessions only" note.
  String? settingHint(SettingFieldSpec field) {
    final range = switch (field.kind) {
      SettingKind.money => adminRangeHint(AppFormat.egpNumber(field.min), AppFormat.egpNumber(field.max)),
      SettingKind.integer => adminRangeHint('${field.min}', '${field.max}'),
      SettingKind.version => adminVersionHint,
      SettingKind.phone => adminPhoneHint,
      SettingKind.whatsapp => adminWhatsappHint,
      _ => null,
    };
    final note = !field.appliesToNewOnly
        ? null
        : switch (field.name) {
            'gracePeriodDays' => adminAppliesToNewInvoices,
            'trialDays' => adminAppliesToNewDoctors,
            _ => adminAppliesToNewSessions,
          };
    return [?range, ?note].join(' · ').ifEmpty;
  }

  /// The message for a value the screen refuses before sending it.
  String settingProblem(SettingFieldSpec field, SettingProblem problem) => switch (problem) {
        SettingProblem.required => errorRequired,
        SettingProblem.notNumber => field.kind == SettingKind.money ? adminErrorAmount : adminErrorWholeNumber,
        SettingProblem.outOfRange => field.kind == SettingKind.money
            ? adminErrorRange(AppFormat.egpNumber(field.min), AppFormat.egpNumber(field.max))
            : adminErrorRange('${field.min}', '${field.max}'),
        SettingProblem.tooLong => adminErrorMaxLength(NumberFormat('#,##0', 'en').format(field.maxLength)),
        SettingProblem.invalidEmail => errorInvalidEmail,
        SettingProblem.invalidPhone => field.kind == SettingKind.whatsapp ? adminErrorInvalidWhatsapp : adminErrorInvalidPhone,
        SettingProblem.invalidVersion => adminErrorInvalidVersion,
      };
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}

/// A stored value (as the history keeps it: piasters, `true`/`false`,
/// plain text) as people read it.
String settingValueText(BuildContext context, String field, String? raw) {
  final l10n = AppLocalizations.of(context);
  if (raw == null || raw.isEmpty) return l10n.adminEmptyValue;
  final spec = SettingFields.byName[field];
  return switch (spec?.kind) {
    SettingKind.money => int.tryParse(raw) == null ? raw : AppFormat.egp(context, int.parse(raw)),
    SettingKind.boolean => raw == 'true' ? l10n.adminOn : l10n.adminOff,
    SettingKind.phone || SettingKind.whatsapp => AppFormat.phone(raw),
    _ => raw,
  };
}

/// Whether a field's text is mostly numbers, emails or codes that read left
/// to right.
bool settingIsLtr(SettingFieldSpec field) => switch (field.kind) {
      SettingKind.money ||
      SettingKind.integer ||
      SettingKind.email ||
      SettingKind.phone ||
      SettingKind.whatsapp ||
      SettingKind.version =>
        true,
      _ => field.rtl == false,
    };

IconData settingGroupIcon(SettingGroup group) => switch (group) {
      SettingGroup.billing => Icons.receipt_long_outlined,
      SettingGroup.payment => Icons.account_balance_wallet_outlined,
      SettingGroup.files => Icons.cloud_upload_outlined,
      SettingGroup.clinics => Icons.storefront_outlined,
      SettingGroup.appVersions => Icons.system_update_outlined,
      SettingGroup.maintenance => Icons.construction_outlined,
      SettingGroup.support => Icons.support_agent_outlined,
      SettingGroup.legal => Icons.gavel_outlined,
    };
