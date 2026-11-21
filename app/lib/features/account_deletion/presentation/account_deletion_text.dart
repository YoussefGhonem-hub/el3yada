import 'package:flutter/widgets.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../auth/domain/user_role.dart';
import '../domain/account_deletion_models.dart';

/// Labels for account deletion (spec 6.17), and the «… محذوف» names in the
/// user's language.
extension AccountDeletionText on AppLocalizations {
  String deletionStatusLabel(DeletionStatus status) => switch (status) {
        DeletionStatus.scheduled => deletionStatusScheduled,
        DeletionStatus.waitingPayment => deletionStatusWaitingPayment,
        DeletionStatus.restored => deletionStatusRestored,
        DeletionStatus.completed => deletionStatusCompleted,
      };

  /// The role in AD12's filters and rows.
  String deletionRoleLabel(UserRole role) => switch (role) {
        UserRole.patient => rolePatient,
        UserRole.doctor => roleDoctor,
        UserRole.assistant => roleAssistant,
        UserRole.admin => roleAdmin,
      };

  /// What deleting the account does, for [role] (the settings flow).
  List<String> deletionEffects(UserRole role) => [
        accountDeletionStepClosed,
        ...switch (role) {
          UserRole.patient => [accountDeletionPatientBookings, accountDeletionPatientRecords],
          UserRole.doctor => [accountDeletionDoctorClinic, accountDeletionDoctorRecords, accountDeletionDoctorBilling],
          UserRole.assistant => [accountDeletionAssistant],
          UserRole.admin => [accountDeletionAdmin],
        },
        accountDeletionStepErase,
      ];

  /// [name] as shown: an erased account's «… محذوف» becomes the label in the
  /// current language; any other name is unchanged.
  String personName(String name) => switch (DeletedNames.roleOf(name)) {
        UserRole.patient => deletedPatient,
        UserRole.doctor => deletedDoctor,
        UserRole.assistant => deletedAssistant,
        UserRole.admin => deletedAdmin,
        null => name,
      };
}

/// [AccountDeletionText.personName] from a [BuildContext].
String personName(BuildContext context, String name) => AppLocalizations.of(context).personName(name);
