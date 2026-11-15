// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'el3yada';

  @override
  String get appTagline => 'Your clinic, organised.';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get identifierLabel => 'Mobile number or email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get registerAsDoctor => 'Register as a doctor';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get errorRequired => 'This field is required';

  @override
  String get errorInvalidIdentifier =>
      'Enter a valid Egyptian mobile number or email';

  @override
  String get errorInvalidCredentials => 'Wrong mobile number/email or password';

  @override
  String get errorTooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get errorNoInternet => 'No internet connection';

  @override
  String get errorUnknown => 'Something went wrong. Please try again.';

  @override
  String get patientDesktopTitle => 'Patient accounts use the mobile app';

  @override
  String get patientDesktopBody =>
      'The desktop app is for doctors, assistants and admins. Install el3yada on your phone to see your medical file and your bookings.';

  @override
  String get ok => 'OK';

  @override
  String get underConstructionTitle => 'This screen is not built yet';

  @override
  String underConstructionBody(String screenId) {
    return 'Screen $screenId in spec.md';
  }

  @override
  String get switchLanguage => 'Switch language';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get logout => 'Log out';

  @override
  String get loading => 'Loading…';

  @override
  String get devAccountsTitle => 'Test accounts (dev only)';

  @override
  String get devAccountsBody =>
      'Tap an account to fill it in. Any password works except \"wrong\".';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleDoctor => 'Doctor';

  @override
  String get roleAssistant => 'Assistant';

  @override
  String get rolePatient => 'Patient';

  @override
  String get navLive => 'Live board';

  @override
  String get navLiveShort => 'Live';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navRevenue => 'Revenue';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get navPatients => 'Patients';

  @override
  String get navChats => 'Chats';

  @override
  String get navBilling => 'Billing';

  @override
  String get navBranches => 'Branches';

  @override
  String get navAssistants => 'Assistants';

  @override
  String get navSettings => 'Settings';

  @override
  String get navMore => 'More';

  @override
  String get navHome => 'Home';

  @override
  String get navMedicalFile => 'Medical file';

  @override
  String get navAccount => 'Account';

  @override
  String get navDoctors => 'Doctors';

  @override
  String get navPayments => 'Payments';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navSignups => 'Sign-up requests';

  @override
  String get navAccounts => 'Accounts';

  @override
  String get navCatalogs => 'Catalogs';

  @override
  String get navSpecialties => 'Specialties';

  @override
  String get navAdmins => 'Admins';

  @override
  String get navAuditLog => 'Audit log';

  @override
  String get done => 'Done';

  @override
  String get navBadgeNew => 'New';

  @override
  String navBadgeUnread(int count) {
    return '$count unread';
  }

  @override
  String navItemWithBadge(String label, String badge) {
    return '$label, $badge';
  }

  @override
  String get splashSlow => 'Connecting…';

  @override
  String get languageTitle => 'Choose your language';

  @override
  String get languageBody => 'You can change it later in Settings.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get continueButton => 'Continue';

  @override
  String get chooseAccountTitle => 'Log in as';

  @override
  String get chooseAccountBody => 'This number has two accounts. Choose one.';

  @override
  String assistantAtClinic(String doctorName) {
    return 'Assistant at $doctorName\'s clinic';
  }

  @override
  String get errorSignInAgain => 'Your sign-in timed out. Sign in again.';

  @override
  String get errorServer =>
      'Something went wrong on our side. Try again in a moment.';

  @override
  String get errorInvalidEmail => 'Enter a valid email address.';

  @override
  String get errorInvalidMobile => 'Enter a valid Egyptian mobile number.';

  @override
  String get errorTooLong => 'This is too long.';

  @override
  String errorRetryInMinutes(int minutes) {
    return 'Too many attempts. Try again in $minutes min.';
  }

  @override
  String get forgotTitle => 'Forgot password';

  @override
  String get forgotBody => 'Enter the email or mobile number you sign in with.';

  @override
  String get forgotSubmit => 'Send';

  @override
  String get forgotEmailSentTitle => 'Check your email';

  @override
  String get forgotEmailSentBody =>
      'If this email belongs to an account, a link to set a new password is on its way. Check your spam folder too.';

  @override
  String get forgotPhoneSentTitle => 'Request sent';

  @override
  String get forgotPhoneSentBody =>
      'A request will be sent to your doctor to reset your password. They will give you a temporary password.';

  @override
  String get backToLogin => 'Back to sign in';

  @override
  String get setPasswordTitle => 'Set a new password';

  @override
  String get setPasswordBody =>
      'Choose a password only you know. You\'ll use it from now on.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordRulesTitle => 'Your password needs';

  @override
  String get passwordRuleLength => 'At least 8 characters';

  @override
  String get passwordRuleLetter => 'A letter';

  @override
  String get passwordRuleNumber => 'A number';

  @override
  String passwordRuleMet(String rule) {
    return 'Done: $rule';
  }

  @override
  String passwordRuleNotMet(String rule) {
    return 'Not yet: $rule';
  }

  @override
  String get acceptTermsLabel =>
      'I accept the Terms of use and the Privacy Policy';

  @override
  String get savePasswordButton => 'Save password';

  @override
  String get errorPasswordsDontMatch => 'The passwords don\'t match.';

  @override
  String get errorWeakPassword =>
      'Use at least 8 characters with a letter and a number.';

  @override
  String get errorPasswordSameAsOld =>
      'Choose a password you haven\'t used here.';

  @override
  String get errorCurrentPasswordIncorrect => 'The current password is wrong.';

  @override
  String get errorTermsNotAccepted =>
      'Accept the Terms and the Privacy Policy to continue.';

  @override
  String get termsTitle => 'Terms of use';

  @override
  String get privacyTitle => 'Privacy Policy';

  @override
  String get legalEmpty => 'This text isn\'t available yet.';

  @override
  String legalUpdated(String date) {
    return 'Last updated $date';
  }

  @override
  String get accountDisabledTitle => 'Account disabled';

  @override
  String get accountDisabledBody =>
      'Your account has been disabled. Contact support.';

  @override
  String get clinicNotActiveTitle => 'Clinic account not active';

  @override
  String get clinicNotActiveBody =>
      'The clinic account is not active. Contact the doctor.';

  @override
  String get supportTitle => 'Contact support';

  @override
  String get supportWhatsapp => 'WhatsApp';

  @override
  String get supportCall => 'Call';

  @override
  String get supportEmail => 'Email';

  @override
  String get updateTitle => 'Update required';

  @override
  String get updateBody =>
      'This version of el3yada is no longer supported. Update the app to keep using it.';

  @override
  String get updateButton => 'Update';

  @override
  String get updateNoLink =>
      'Get the latest version from where you installed the app.';

  @override
  String appVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get maintenanceTitle => 'We\'ll be right back';

  @override
  String get maintenanceBody =>
      'el3yada is under maintenance. Try again in a little while.';

  @override
  String get retryButton => 'Try again';

  @override
  String get adminSignIn => 'Admin sign in';

  @override
  String get forgotHaveCode => 'I have a code';

  @override
  String get resetCodeBody =>
      'Enter the code from the email and choose a new password.';

  @override
  String get resetCodeLabel => 'Code from the email';

  @override
  String get resetDoneTitle => 'Password changed';

  @override
  String get resetDoneBody =>
      'Sign in with your new password. Other devices were signed out.';

  @override
  String get errorEmailTokenInvalid =>
      'This code isn\'t valid. Check it and try again.';

  @override
  String get errorEmailTokenExpired =>
      'This code has expired. Ask for a new email.';

  @override
  String get errorEmailTokenUsed =>
      'This code was already used. Ask for a new email.';

  @override
  String get adminMyProfile => 'My profile';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminClose => 'Close';

  @override
  String get adminSave => 'Save';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminRefreshFailed => 'Couldn\'t refresh. Showing the last list.';

  @override
  String get adminListSeparator => ', ';

  @override
  String get adminNotProvided => 'Not provided';

  @override
  String get adminSystem => 'System';

  @override
  String get adminUnknownUser => 'Unknown user';

  @override
  String get adminNew => 'New';

  @override
  String adminDoctorName(String name) {
    return 'Dr. $name';
  }

  @override
  String get adminJustNow => 'Just now';

  @override
  String adminMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String adminHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String adminDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String adminMoneyEgp(String amount) {
    return 'EGP $amount';
  }

  @override
  String get adminCurrency => 'EGP';

  @override
  String get adminUnitDays => 'days';

  @override
  String get adminUnitMb => 'MB';

  @override
  String get adminStatusPending => 'Waiting for review';

  @override
  String get adminStatusActive => 'Active';

  @override
  String get adminStatusRejected => 'Rejected';

  @override
  String get adminStatusSuspended => 'Suspended';

  @override
  String get adminStatusDisabled => 'Disabled';

  @override
  String get adminRoleAdmin => 'Admin';

  @override
  String get adminRoleSuperAdmin => 'Super admin';

  @override
  String get adminEmptyValue => '(empty)';

  @override
  String get adminOn => 'On';

  @override
  String get adminOff => 'Off';

  @override
  String get adminErrorOutOfRange => 'This value is out of the allowed range.';

  @override
  String get adminErrorInvalidValue => 'This value isn\'t valid.';

  @override
  String get adminErrorInvalidVersion => 'Write the version like 1.2.3.';

  @override
  String get adminErrorUnknownSetting =>
      'This setting doesn\'t exist any more. Update the app.';

  @override
  String get adminErrorInvalidName =>
      'Write at least a first and a last name, in letters only.';

  @override
  String get adminErrorReasonRequired =>
      'Write the reason (at least 3 characters).';

  @override
  String get adminErrorRegistrationNotPending =>
      'This request was already reviewed, maybe by another admin.';

  @override
  String get adminErrorEmailTaken =>
      'An account with this email already exists.';

  @override
  String get adminErrorLicenseMissing =>
      'The syndicate card file is missing on the server. Ask the doctor to upload it again.';

  @override
  String get adminErrorOwnRole => 'You can\'t change your own role.';

  @override
  String get adminErrorDisableSelf => 'You can\'t disable your own account.';

  @override
  String get adminErrorLastSuperAdmin =>
      'There must always be at least one active super admin.';

  @override
  String get adminErrorNotFound => 'This item doesn\'t exist any more.';

  @override
  String get adminErrorForbidden => 'You don\'t have permission to do this.';

  @override
  String get adminErrorAmount =>
      'Enter an amount in EGP, with at most 2 decimals.';

  @override
  String get adminErrorWholeNumber => 'Enter a whole number.';

  @override
  String adminErrorRange(String min, String max) {
    return 'Enter a value from $min to $max.';
  }

  @override
  String adminErrorMaxLength(String max) {
    return 'Use at most $max characters.';
  }

  @override
  String get adminErrorInvalidPhone =>
      'Enter a valid mobile, landline or hotline number.';

  @override
  String get adminErrorInvalidWhatsapp =>
      'Enter a valid mobile number (international numbers start with +).';

  @override
  String get adminFixErrors => 'Fix the highlighted fields, then save.';

  @override
  String adminSignupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests waiting',
      one: '1 request waiting',
      zero: 'No requests waiting',
    );
    return '$_temp0';
  }

  @override
  String get adminSignupsSearchHint => 'Name, email, mobile or number';

  @override
  String get adminClearSearch => 'Clear search';

  @override
  String get adminSort => 'Sort';

  @override
  String get adminSortNewest => 'Newest first';

  @override
  String get adminSortOldest => 'Oldest first (queue order)';

  @override
  String get adminSignupsEmptyTitle => 'No sign-up requests waiting';

  @override
  String get adminSignupsEmptyBody =>
      'New doctors\' requests show up here as soon as they register.';

  @override
  String get adminSignupsNoMatchTitle => 'No requests match your search';

  @override
  String get adminSignupsNoMatchBody =>
      'Check the spelling, or search by mobile or syndicate number.';

  @override
  String get adminSelectRequest => 'Choose a request to review it';

  @override
  String adminSubmittedShort(String time) {
    return 'sent $time';
  }

  @override
  String get adminReviewTitle => 'Sign-up request';

  @override
  String adminSubmittedAt(String relative, String date) {
    return 'Sent $relative · $date';
  }

  @override
  String get adminResubmitted => 'Sent again';

  @override
  String get adminEmailNotVerified => 'Email not confirmed';

  @override
  String get adminEmailVerified => 'Confirmed';

  @override
  String get adminPreviousRejection => 'Rejected before because';

  @override
  String get adminSectionAccount => 'Account';

  @override
  String get adminSectionProfessional => 'Professional details';

  @override
  String get adminSectionBranch => 'Clinic (first branch)';

  @override
  String get adminSectionPrices => 'Visit prices';

  @override
  String get adminSectionReviews => 'Earlier reviews';

  @override
  String get adminFieldFullName => 'Full name';

  @override
  String get adminFieldFullNameEn => 'Name in English';

  @override
  String get adminFieldEmail => 'Email';

  @override
  String get adminFieldMobile => 'Mobile';

  @override
  String get adminFieldLanguage => 'Language';

  @override
  String get adminFieldTitle => 'Title';

  @override
  String get adminFieldTitleEn => 'Title in English';

  @override
  String get adminFieldSpecialty => 'Specialty';

  @override
  String get adminFieldExtraSpecialties => 'Other specialties';

  @override
  String get adminFieldLicenseNumber => 'Syndicate number';

  @override
  String get adminFieldDegreesAr => 'Degrees (Arabic)';

  @override
  String get adminFieldDegreesEn => 'Degrees (English)';

  @override
  String get adminFieldBranchName => 'Branch name';

  @override
  String get adminFieldBranchNameEn => 'Branch name in English';

  @override
  String get adminFieldAddress => 'Address';

  @override
  String get adminFieldLandmark => 'Landmark';

  @override
  String get adminFieldBranchEmail => 'Clinic email';

  @override
  String get adminFieldPhones => 'Phone numbers';

  @override
  String get adminFieldExamPrice => 'Examination';

  @override
  String get adminFieldConsultPrice => 'Consultation';

  @override
  String adminAddressBuilding(String value) {
    return 'Building $value';
  }

  @override
  String adminAddressFloor(String value) {
    return 'Floor $value';
  }

  @override
  String adminAddressApartment(String value) {
    return 'Apartment $value';
  }

  @override
  String get adminPhoneMobile => 'Mobile';

  @override
  String get adminPhoneLandline => 'Landline';

  @override
  String get adminPhoneReception => 'Reception';

  @override
  String get adminOpenMap => 'Open the location on the map';

  @override
  String adminReviewApprovedBy(String name) {
    return 'Approved by $name';
  }

  @override
  String adminReviewRejectedBy(String name) {
    return 'Rejected by $name';
  }

  @override
  String get adminApprove => 'Approve';

  @override
  String get adminReject => 'Reject';

  @override
  String get adminReviewHint =>
      'Check the syndicate card against the name and number before you decide.';

  @override
  String adminApproveTitle(String name) {
    return 'Approve Dr. $name?';
  }

  @override
  String get adminApproveBody =>
      'The account becomes active and the doctor is notified. They can start using el3yada right away.';

  @override
  String adminApprovedMessage(String name) {
    return 'Dr. $name is approved and can now use el3yada.';
  }

  @override
  String adminRejectTitle(String name) {
    return 'Reject Dr. $name\'s sign-up?';
  }

  @override
  String get adminRejectBody =>
      'The doctor sees this reason, can correct their details and send the request again.';

  @override
  String get adminRejectReasonLabel => 'Reason';

  @override
  String get adminRejectPresets => 'Common reasons';

  @override
  String get adminRejectPresetLicense =>
      'The syndicate card photo isn\'t clear. Upload a clearer photo.';

  @override
  String get adminRejectPresetNumber =>
      'The syndicate number doesn\'t match the card.';

  @override
  String get adminRejectPresetBranch =>
      'The clinic address or phone number is incomplete.';

  @override
  String adminRejectedMessage(String name) {
    return 'Dr. $name\'s sign-up was rejected. They\'ll see your reason.';
  }

  @override
  String get adminLicenseTitle => 'Syndicate card';

  @override
  String get adminLicenseSubtitle =>
      'Compare the name and number with the details below.';

  @override
  String get adminLicenseImageLabel => 'Syndicate card photo. Open it to zoom.';

  @override
  String adminLicenseImageOf(String name) {
    return 'Syndicate card of Dr. $name';
  }

  @override
  String get adminLicenseZoom => 'Zoom';

  @override
  String get adminLicensePdf => 'Syndicate card (PDF)';

  @override
  String get adminLicenseFile => 'File';

  @override
  String get adminLicenseFileName => 'license';

  @override
  String get adminLicenseOpen => 'Open';

  @override
  String get adminLicenseCantOpen =>
      'This device can\'t open the file here. Open it from the computer app.';

  @override
  String adminFileSizeKb(int kb) {
    return '$kb KB';
  }

  @override
  String get adminZoomIn => 'Zoom in';

  @override
  String get adminZoomOut => 'Zoom out';

  @override
  String get adminZoomReset => 'Fit to screen';

  @override
  String adminSettingsLastChange(String name, String time) {
    return 'Last changed by $name · $time';
  }

  @override
  String get adminGroupBilling => 'Billing';

  @override
  String get adminGroupBillingBody =>
      'Platform fees for each visit, and the payment rules.';

  @override
  String get adminGroupPayment => 'Payment';

  @override
  String get adminGroupPaymentBody =>
      'Where doctors send their payments. Shown on the billing screen.';

  @override
  String get adminGroupFiles => 'Files';

  @override
  String get adminGroupFilesBody => 'Upload limit for medical files.';

  @override
  String get adminGroupClinics => 'Clinics';

  @override
  String get adminGroupClinicsBody => 'Limits for each doctor\'s clinic.';

  @override
  String get adminGroupVersions => 'Minimum app versions';

  @override
  String get adminGroupVersionsBody =>
      'Older apps must be updated before they open.';

  @override
  String get adminGroupMaintenance => 'Maintenance';

  @override
  String get adminGroupMaintenanceBody =>
      'Close the app for everyone except admins, with your message.';

  @override
  String get adminGroupSupport => 'Support contact';

  @override
  String get adminGroupSupportBody =>
      'Shown on the disabled, pending and maintenance screens.';

  @override
  String get adminGroupLegal => 'Terms and Privacy';

  @override
  String get adminGroupLegalBody =>
      'Patients accept these at their first sign-in. If one language is empty, the other one shows.';

  @override
  String get adminSettingExamFee => 'Examination fee';

  @override
  String get adminSettingConsultationFee => 'Consultation fee';

  @override
  String get adminSettingGracePeriod => 'Grace period';

  @override
  String get adminSettingMaxConsultations => 'Consultations in a row (maximum)';

  @override
  String get adminSettingInstapayAddress => 'InstaPay address';

  @override
  String get adminSettingInstapayName => 'InstaPay account name';

  @override
  String get adminSettingInstapayInstructionsAr =>
      'Payment instructions (Arabic)';

  @override
  String get adminSettingInstapayInstructionsEn =>
      'Payment instructions (English)';

  @override
  String get adminSettingMaxUpload => 'Maximum file size';

  @override
  String get adminSettingMaxAssistants => 'Assistants per doctor (maximum)';

  @override
  String get adminSettingMaxBranches => 'Branches per doctor (maximum)';

  @override
  String get adminSettingVersionAndroid => 'Minimum Android version';

  @override
  String get adminSettingVersionIos => 'Minimum iOS version';

  @override
  String get adminSettingVersionWindows => 'Minimum Windows version';

  @override
  String get adminSettingVersionMacos => 'Minimum macOS version';

  @override
  String get adminSettingMaintenance => 'Maintenance mode';

  @override
  String get adminSettingMaintenanceMessageAr => 'Maintenance message (Arabic)';

  @override
  String get adminSettingMaintenanceMessageEn =>
      'Maintenance message (English)';

  @override
  String get adminSettingSupportPhone => 'Support phone';

  @override
  String get adminSettingSupportWhatsapp => 'Support WhatsApp';

  @override
  String get adminSettingSupportEmail => 'Support email';

  @override
  String get adminSettingTermsAr => 'Terms of use (Arabic)';

  @override
  String get adminSettingTermsEn => 'Terms of use (English)';

  @override
  String get adminSettingPrivacyAr => 'Privacy Policy (Arabic)';

  @override
  String get adminSettingPrivacyEn => 'Privacy Policy (English)';

  @override
  String adminRangeHint(String min, String max) {
    return 'From $min to $max';
  }

  @override
  String get adminVersionHint => 'Like 1.2.0';

  @override
  String get adminPhoneHint => 'Mobile, landline or hotline';

  @override
  String get adminWhatsappHint =>
      'Egyptian number, or international starting with +';

  @override
  String get adminAppliesToNewSessions => 'Applies to new sessions only';

  @override
  String get adminAppliesToNewInvoices => 'Applies to new invoices only';

  @override
  String adminWasValue(String value) {
    return 'Saved value: $value';
  }

  @override
  String adminCharacterCount(String count, String max) {
    return '$count / $max';
  }

  @override
  String adminFieldHistory(String field) {
    return 'Change history: $field';
  }

  @override
  String get adminMaintenanceOn =>
      'On: everyone except admins sees the maintenance screen.';

  @override
  String get adminMaintenanceOff => 'Off: the app is open for everyone.';

  @override
  String get adminMaintenanceWillStart =>
      'Maintenance starts as soon as you save.';

  @override
  String get adminMaintenanceWillEnd =>
      'The app opens for everyone as soon as you save.';

  @override
  String adminUnsavedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes not saved',
      one: '1 change not saved',
    );
    return '$_temp0';
  }

  @override
  String get adminAllSaved => 'All changes saved';

  @override
  String get adminDiscard => 'Discard';

  @override
  String get adminDiscardTitle => 'Discard your changes?';

  @override
  String adminDiscardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your $count changes haven\'t been saved and will be lost.',
      one: 'Your change hasn\'t been saved and will be lost.',
    );
    return '$_temp0';
  }

  @override
  String adminSettingsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settings saved',
      one: '1 setting saved',
    );
    return '$_temp0';
  }

  @override
  String get adminHistoryTitle => 'Change history';

  @override
  String get adminHistoryAll => 'All settings';

  @override
  String get adminHistoryEmptyTitle => 'No changes yet';

  @override
  String get adminHistoryEmptyBody =>
      'Every saved change shows here, with who made it.';

  @override
  String adminHistoryChangedBy(String name, String time) {
    return '$name · $time';
  }

  @override
  String get adminHistoryChangedTo => 'changed to';

  @override
  String get adminHistoryBefore => 'Before';

  @override
  String get adminHistoryAfter => 'After';

  @override
  String get adminHistoryShowFull => 'Show the full text';

  @override
  String adminAdminsCount(int count, int superAdmins) {
    return 'Admins: $count · Active super admins: $superAdmins';
  }

  @override
  String get adminAdminsRestricted => 'Only super admins can manage admins.';

  @override
  String get adminAddAdmin => 'Add admin';

  @override
  String get adminAddAdminBody =>
      'They get a temporary password and choose their own at their first sign-in.';

  @override
  String get adminRoleAdminBody => 'Everything except managing admins.';

  @override
  String get adminRoleSuperAdminBody =>
      'Everything, including adding admins and changing their roles.';

  @override
  String get adminColumnName => 'Name';

  @override
  String get adminColumnRole => 'Role';

  @override
  String get adminColumnStatus => 'Status';

  @override
  String get adminColumnLastSignIn => 'Last sign-in';

  @override
  String get adminPasswordNotSet => 'Hasn\'t set a password';

  @override
  String get adminNeverSignedIn => 'Never';

  @override
  String adminLastSignIn(String time) {
    return 'Last sign-in: $time';
  }

  @override
  String adminYouSuffix(String name) {
    return '$name (you)';
  }

  @override
  String get adminThatsYou =>
      'That\'s you. Another super admin can change your account.';

  @override
  String adminActionsFor(String name) {
    return 'Actions for $name';
  }

  @override
  String get adminMakeSuper => 'Make super admin';

  @override
  String get adminMakeAdmin => 'Make admin';

  @override
  String adminMakeSuperTitle(String name) {
    return 'Make $name a super admin?';
  }

  @override
  String get adminMakeSuperBody =>
      'They\'ll be able to add admins, change roles and disable admins.';

  @override
  String adminMakeAdminTitle(String name) {
    return 'Make $name an admin?';
  }

  @override
  String get adminMakeAdminBody =>
      'They\'ll no longer manage admins. The change takes effect right away.';

  @override
  String adminRoleChanged(String name) {
    return '$name\'s role was changed.';
  }

  @override
  String get adminDisable => 'Disable';

  @override
  String get adminEnable => 'Enable';

  @override
  String adminDisableTitle(String name) {
    return 'Disable $name?';
  }

  @override
  String get adminDisableBody =>
      'They\'re signed out everywhere at once and can\'t sign in until you enable them again.';

  @override
  String adminEnableTitle(String name) {
    return 'Enable $name?';
  }

  @override
  String get adminEnableBody => 'They can sign in again with their password.';

  @override
  String adminDisabledMessage(String name) {
    return '$name was disabled.';
  }

  @override
  String adminEnabledMessage(String name) {
    return '$name was enabled.';
  }

  @override
  String get adminNotAllowedTitle => 'Not allowed';

  @override
  String adminCreatedTitle(String name) {
    return '$name was added';
  }

  @override
  String get adminPasswordOnceWarning =>
      'Copy this temporary password now. It\'s shown only once and can\'t be shown again. Share it with them privately.';

  @override
  String get adminTemporaryPassword => 'Temporary password';

  @override
  String get adminCopyPassword => 'Copy password';

  @override
  String get adminCopied => 'Copied';

  @override
  String adminPasswordNextStep(String email) {
    return 'They sign in with $email and this password, then choose their own password.';
  }

  @override
  String adminAuditCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'No entries',
    );
    return '$_temp0';
  }

  @override
  String get adminAuditEmptyTitle => 'Nothing recorded yet';

  @override
  String get adminAuditNoMatchTitle => 'No entries match these filters';

  @override
  String get adminAuditNoMatchBody =>
      'Try a longer date range or clear some filters.';

  @override
  String get adminAuditEnd => 'That\'s everything.';

  @override
  String get adminClearFilters => 'Clear filters';

  @override
  String get adminClearFilter => 'Clear';

  @override
  String get adminFilterAction => 'Action';

  @override
  String get adminFilterAllActions => 'All actions';

  @override
  String get adminFilterWho => 'Who';

  @override
  String get adminFilterEveryone => 'Everyone';

  @override
  String get adminFilterTarget => 'Target';

  @override
  String get adminFilterAllTargets => 'All targets';

  @override
  String get adminFilterDates => 'Any date';

  @override
  String adminFilterBy(String name) {
    return 'By $name';
  }

  @override
  String adminDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get adminColumnWhen => 'When';

  @override
  String get adminColumnWho => 'Who';

  @override
  String get adminColumnWhat => 'What';

  @override
  String get adminColumnTarget => 'Target';

  @override
  String get adminTargetDoctor => 'Doctor';

  @override
  String get adminTargetUser => 'Account';

  @override
  String get adminTargetSettings => 'Settings';

  @override
  String get adminDetailFields => 'Settings changed';

  @override
  String get adminDetailChannel => 'How';

  @override
  String get adminChannelEmail => 'Email link';

  @override
  String get adminChannelDoctor => 'Through the doctor';

  @override
  String get adminEntryNumber => 'Entry';

  @override
  String get adminOnlyThisPerson => 'Only this person';

  @override
  String get adminOnlyThisRecord => 'Only this target';

  @override
  String get adminOpenRegistration => 'Open the sign-up request';

  @override
  String get adminCopyDetails => 'Copy details';

  @override
  String get adminCopiedDetails => 'Details copied';

  @override
  String get adminAuditRegistrationSubmitted => 'Sent a sign-up request';

  @override
  String get adminAuditRegistrationResubmitted =>
      'Sent the sign-up request again after a rejection';

  @override
  String get adminAuditRegistrationApproved => 'Approved a doctor\'s sign-up';

  @override
  String get adminAuditRegistrationRejected => 'Rejected a doctor\'s sign-up';

  @override
  String get adminAuditLicenseViewed => 'Viewed a doctor\'s syndicate card';

  @override
  String get adminAuditAdminSeeded => 'Created the first super admin';

  @override
  String adminAuditAdminCreated(String role) {
    return 'Added an admin ($role)';
  }

  @override
  String adminAuditAdminRoleChanged(String before, String after) {
    return 'Changed an admin\'s role from $before to $after';
  }

  @override
  String get adminAuditAdminDisabled => 'Disabled an admin';

  @override
  String get adminAuditAdminEnabled => 'Enabled an admin';

  @override
  String get adminAuditProfileUpdated => 'Updated their profile';

  @override
  String adminAuditSettingsUpdated(String fields) {
    return 'Changed settings: $fields';
  }

  @override
  String get adminAuditPasswordSet => 'Set a new password';

  @override
  String get adminAuditPasswordChanged => 'Changed their password';

  @override
  String get adminAuditResetRequestedEmail =>
      'Asked for a password reset by email';

  @override
  String get adminAuditResetRequestedDoctor =>
      'Asked their doctor for a password reset';

  @override
  String get adminAuditPasswordReset => 'Reset a password with the email link';

  @override
  String get adminAuditLockedOut =>
      'Locked an account for 15 minutes after wrong passwords';

  @override
  String get adminAuditTokenReuse =>
      'Ended a session: a sign-in token was used twice';

  @override
  String get adminAuditEmailVerified => 'Confirmed their email';

  @override
  String get adminActionRegistrationSubmitted => 'Sign-up sent';

  @override
  String get adminActionRegistrationResubmitted => 'Sign-up sent again';

  @override
  String get adminActionRegistrationApproved => 'Sign-up approved';

  @override
  String get adminActionRegistrationRejected => 'Sign-up rejected';

  @override
  String get adminActionLicenseViewed => 'Syndicate card viewed';

  @override
  String get adminActionAdminSeeded => 'First super admin created';

  @override
  String get adminActionAdminCreated => 'Admin added';

  @override
  String get adminActionAdminRoleChanged => 'Admin role changed';

  @override
  String get adminActionAdminDisabled => 'Admin disabled';

  @override
  String get adminActionAdminEnabled => 'Admin enabled';

  @override
  String get adminActionProfileUpdated => 'Profile updated';

  @override
  String get adminActionSettingsUpdated => 'Settings changed';

  @override
  String get adminActionPasswordSet => 'Password set';

  @override
  String get adminActionPasswordChanged => 'Password changed';

  @override
  String get adminActionResetRequested => 'Password reset requested';

  @override
  String get adminActionPasswordReset => 'Password reset';

  @override
  String get adminActionLockedOut => 'Account locked';

  @override
  String get adminActionTokenReuse => 'Sign-in token reused';

  @override
  String get adminActionEmailVerified => 'Email confirmed';

  @override
  String get adminProfileSubtitle =>
      'Your account, language and appearance, and password.';

  @override
  String get adminProfileAccount => 'Account';

  @override
  String get adminEditName => 'Edit name';

  @override
  String get adminMemberSince => 'Admin since';

  @override
  String get adminNameSaved => 'Name saved';

  @override
  String get adminPreferences => 'Language and appearance';

  @override
  String get adminPreferencesBody =>
      'Saved on this device and on your account.';

  @override
  String get adminLanguage => 'Language';

  @override
  String get adminChangePassword => 'Change password';

  @override
  String get adminChangePasswordBody =>
      'Your other devices are signed out when you change it.';

  @override
  String get adminCurrentPassword => 'Current password';

  @override
  String get adminPasswordChanged =>
      'Password changed. Your other devices were signed out.';

  @override
  String get adminLogoutBody => 'Sign out of el3yada on this device.';
}
