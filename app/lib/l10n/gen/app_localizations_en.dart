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
  String get loginWelcome => 'Welcome back';

  @override
  String get loginWelcomeBody => 'Sign in to continue.';

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
  String get regTitle => 'Doctor registration';

  @override
  String get regResubmitTitle => 'Edit registration';

  @override
  String get regStepAccount => 'Account';

  @override
  String get regStepProfessional => 'Professional details';

  @override
  String get regStepBranch => 'First branch';

  @override
  String get regStepReview => 'Review and send';

  @override
  String regStepOf(int step, int count) {
    return 'Step $step of $count';
  }

  @override
  String regStepSemantics(int step, int count, String name) {
    return 'Step $step of $count: $name';
  }

  @override
  String get regNext => 'Next';

  @override
  String get regBack => 'Back';

  @override
  String get regSubmit => 'Send for review';

  @override
  String get regResubmit => 'Send again for review';

  @override
  String get regFixErrors => 'Check the highlighted fields.';

  @override
  String get regAccountSection => 'Your account';

  @override
  String get regAccountIntro =>
      'You\'ll sign in with this email or mobile number.';

  @override
  String get regPasswordSection => 'Choose a password';

  @override
  String get regFullNameLabel => 'Full name';

  @override
  String get regFullNameHint => 'As on your syndicate card, at least two names';

  @override
  String get regEmailLabel => 'Email';

  @override
  String get regMobileLabel => 'Mobile number';

  @override
  String get regProfessionalSection => 'Your practice';

  @override
  String get regTitleLabel => 'Title';

  @override
  String get regTitleOther => 'Other';

  @override
  String get regTitleOtherLabel => 'Your title';

  @override
  String get regSpecialtyLabel => 'Primary specialty';

  @override
  String get regSpecialtyChoose => 'Choose your specialty';

  @override
  String get regSpecialtyHint =>
      'Your specialty\'s medicines and tests will appear first when you search.';

  @override
  String get regSpecialtiesError => 'Couldn\'t load the specialties.';

  @override
  String get regExtraSpecialtiesLabel =>
      'Other specialties (optional, up to 2)';

  @override
  String get regExtraSpecialtiesShort => 'Other specialties';

  @override
  String get regAddSpecialty => 'Add a specialty';

  @override
  String regRemoveSpecialty(String name) {
    return 'Remove $name';
  }

  @override
  String get regSearchHint => 'Search';

  @override
  String get regClearSearch => 'Clear search';

  @override
  String get regNoResults => 'Nothing matches your search.';

  @override
  String get regSyndicateSection => 'Medical syndicate';

  @override
  String get regLicenseNumberLabel => 'Syndicate number';

  @override
  String get regLicenseFileLabel => 'Syndicate card or license';

  @override
  String get regLicenseFileShort => 'Syndicate card';

  @override
  String get regLicenseFileHint => 'A clear photo or a PDF, up to 10 MB';

  @override
  String get regLicenseReplace => 'Replace';

  @override
  String get regLicenseUndo => 'Keep the current file';

  @override
  String get regLicenseCurrent => 'Current file';

  @override
  String get regLicenseKept => 'kept unless you replace it';

  @override
  String get regLicenseImage => 'Photo';

  @override
  String get regLicensePdf => 'PDF';

  @override
  String get regLicenseOpen => 'Open the photo of the syndicate card';

  @override
  String get regSourceCamera => 'Take a photo';

  @override
  String get regSourceGallery => 'Choose from your photos';

  @override
  String get regSourceFiles => 'Choose a file (photo or PDF)';

  @override
  String regFileSizeKb(int size) {
    return '$size KB';
  }

  @override
  String regFileSizeMb(String size) {
    return '$size MB';
  }

  @override
  String get regBranchSection => 'Branch details';

  @override
  String get regBranchIntro =>
      'Patients will see this branch. You can add more branches after approval.';

  @override
  String get regBranchNameLabel => 'Branch name';

  @override
  String get regBranchNameHint => 'For example: Maadi branch';

  @override
  String get regGovernorateLabel => 'Governorate';

  @override
  String get regGovernorateChoose => 'Choose the governorate';

  @override
  String get regCityLabel => 'City or area';

  @override
  String get addressDetailsLabel => 'Detailed address';

  @override
  String get addressDetailsHint =>
      'For example: 12 Street 9, Al Nour building, 3rd floor, apartment 5';

  @override
  String get mapLinkLabel => 'Google Maps link (optional)';

  @override
  String get mapLinkHelp =>
      'In Google Maps, open the clinic\'s place, tap Share, then Copy link, and paste it here.';

  @override
  String get mapLinkShort => 'Google Maps';

  @override
  String get mapLinkOpen => 'Open in Google Maps';

  @override
  String get mapLinkClear => 'Remove the link';

  @override
  String get mapLinkInvalid => 'That\'s not a Google Maps link.';

  @override
  String get mapLinkOpenFailed => 'Couldn\'t open Google Maps on this device.';

  @override
  String get regLandmarkLabel => 'Landmark (optional)';

  @override
  String get regLandmarkHint => 'For example: next to the metro station';

  @override
  String get regPhonesSection => 'Clinic phone numbers';

  @override
  String get regPhonesHint => '1 to 5 numbers: mobile, landline or hotline.';

  @override
  String regPhoneLabel(int index) {
    return 'Number $index';
  }

  @override
  String get regPhoneType => 'Number type';

  @override
  String get regPhoneTypeReception => 'Reception';

  @override
  String get regPhoneTypeMobile => 'Mobile';

  @override
  String get regPhoneTypeLandline => 'Landline';

  @override
  String get regPhoneWhatsapp => 'WhatsApp';

  @override
  String get regAddPhone => 'Add a number';

  @override
  String get regRemovePhone => 'Remove this number';

  @override
  String get regPricesSection => 'Visit prices (optional)';

  @override
  String get regPricesHint =>
      'Patients see these prices. You can change them later in Settings.';

  @override
  String get regExaminationPrice => 'Examination';

  @override
  String get regConsultationPrice => 'Consultation';

  @override
  String get regCurrency => 'EGP';

  @override
  String regPriceValue(String amount) {
    return 'EGP $amount';
  }

  @override
  String get regReviewIntro => 'Check your details, then send them for review.';

  @override
  String get regReviewIntroResubmit =>
      'Check your changes, then send them for review again.';

  @override
  String get regEdit => 'Edit';

  @override
  String regEditSection(String section) {
    return 'Edit $section';
  }

  @override
  String get regNotSet => 'Not set';

  @override
  String get regAddressLabel => 'Address';

  @override
  String get regLandmarkShort => 'Landmark';

  @override
  String get regPhonesLabel => 'Phone numbers';

  @override
  String get regListSeparator => ', ';

  @override
  String get regErrorTitleRequired => 'Choose your title, or type it.';

  @override
  String get regErrorSpecialtyRequired => 'Choose your specialty.';

  @override
  String get regErrorInvalidSpecialty => 'Choose a specialty from the list.';

  @override
  String get regErrorLicenseNumberRequired =>
      'The syndicate number is required.';

  @override
  String get regErrorInvalidLicenseNumber =>
      'Enter the syndicate number: 3 to 20 letters or digits.';

  @override
  String get regErrorLicenseRequired =>
      'Add a photo of your syndicate card or license.';

  @override
  String get regErrorFileTooLarge =>
      'The file is larger than 10 MB. Choose a smaller one.';

  @override
  String get regErrorFileType => 'Use a photo (JPEG, PNG or WebP) or a PDF.';

  @override
  String get regErrorFileContent =>
      'This file can\'t be read. Try another one.';

  @override
  String get regErrorPickFailed =>
      'Couldn\'t open it. Check the app\'s permissions and try again.';

  @override
  String get regErrorGovernorateRequired => 'Choose the governorate.';

  @override
  String get regErrorBranchName => 'Use 2 to 60 characters.';

  @override
  String get regErrorInvalidPhone =>
      'Enter a valid Egyptian number: mobile, landline or hotline.';

  @override
  String get regErrorPhoneRequired => 'Add at least one phone number.';

  @override
  String get regErrorPrice =>
      'Enter an amount from 0 to 100,000, with at most 2 decimals.';

  @override
  String get regErrorNotEditable => 'This registration can\'t be edited now.';

  @override
  String get regErrorResendCooldown =>
      'Wait a minute before sending another email.';

  @override
  String get regPendingTitle => 'Your account is being reviewed';

  @override
  String get regPendingBody =>
      'You\'ll get a notification once it\'s approved.';

  @override
  String get regRefresh => 'Refresh';

  @override
  String get regStillPending =>
      'Still under review. We\'ll notify you once it\'s approved.';

  @override
  String get regSubmittedData => 'What you sent';

  @override
  String regSubmittedOn(String date) {
    return 'Sent on $date';
  }

  @override
  String get regDataError => 'Couldn\'t load your details.';

  @override
  String get regVerifyCardTitle => 'Verify your email';

  @override
  String regVerifyCardBody(String email) {
    return 'We sent a link to $email.';
  }

  @override
  String get regRejectedTitle => 'Your registration wasn\'t approved';

  @override
  String get regRejectedBody =>
      'Fix what the review team asked for, then send your registration again.';

  @override
  String get regRejectedReason => 'Reason from the review team';

  @override
  String get regRejectedNoReason =>
      'No reason was given. Contact support to find out more.';

  @override
  String get regEditAndResubmit => 'Edit and resubmit';

  @override
  String get regVerifyTitle => 'Verify your email';

  @override
  String get regVerifySentTo => 'We sent a verification link to';

  @override
  String get regVerifyBody =>
      'Open the link in the email. If it opens in a browser instead of the app, copy the code from the email and paste it here.';

  @override
  String get regVerifyButton => 'Verify';

  @override
  String get regVerifiedCheck => 'I\'ve verified';

  @override
  String get regResend => 'Resend the email';

  @override
  String regResendIn(int seconds) {
    return 'Resend in $seconds s';
  }

  @override
  String get regResent => 'Sent. Check your inbox and your spam folder.';

  @override
  String get regNotVerifiedYet =>
      'Not verified yet. Open the link in the email, then try again.';

  @override
  String get regVerifiedTitle => 'Email verified';

  @override
  String get regVerifiedBody => 'Thank you. Your email address is confirmed.';

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
  String get adminPhoneMobile => 'Mobile';

  @override
  String get adminPhoneLandline => 'Landline';

  @override
  String get adminPhoneReception => 'Reception';

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

  @override
  String get navActivityLog => 'Activity log';

  @override
  String clinicOfDoctor(String name) {
    return 'Dr $name\'s clinic';
  }

  @override
  String get clinicCurrentBranch => 'Current branch';

  @override
  String get clinicBranchTemporarilyClosed => 'Temporarily closed';

  @override
  String get clinicSuspendedBanner =>
      'Service is suspended because an invoice is unpaid. Pay it to reactivate.';

  @override
  String get clinicPayNow => 'Pay now';

  @override
  String get clinicLoadFailed => 'Couldn\'t load the clinic details.';

  @override
  String get errorPermissionDenied =>
      'You don\'t have permission to do this. Ask the doctor.';

  @override
  String get errorDoctorSuspended =>
      'Not available while the service is suspended.';

  @override
  String get errorBranchNotAllowed => 'This branch isn\'t one of yours.';

  @override
  String get tempPasswordTitle => 'Temporary password';

  @override
  String tempPasswordBody(String name) {
    return 'Give it to $name. It\'s shown only this once, and they\'ll choose their own password when they sign in.';
  }

  @override
  String get tempPasswordCopy => 'Copy';

  @override
  String get tempPasswordCopied => 'Copied';

  @override
  String get tempPasswordShareWhatsApp => 'WhatsApp';

  @override
  String get tempPasswordShareSms => 'SMS';

  @override
  String tempPasswordMessage(String phone, String password) {
    return 'Your el3yada account: $phone\nTemporary password: $password\nYou\'ll choose a new password when you sign in.';
  }

  @override
  String get tempPasswordMessageCopied =>
      'No messaging app found. The message is copied; paste it where you like.';

  @override
  String get branchErrorLimitReached =>
      'You\'ve reached the most branches you can have. Archive one to add another.';

  @override
  String get branchErrorArchiveDefault =>
      'The default branch can\'t be archived. Make another branch the default first.';

  @override
  String get branchErrorLastActive =>
      'The clinic needs at least one open branch, so this one can\'t be closed or archived.';

  @override
  String get branchErrorHasBookings =>
      'This branch has upcoming bookings. Move or cancel them first.';

  @override
  String get branchErrorNotActive => 'Only an open branch can be the default.';

  @override
  String get branchErrorInvalidBranch =>
      'Choose one of the clinic\'s open branches.';

  @override
  String get branchErrorPeriodEndBeforeStart =>
      'Ends before it starts. Turn on «Ends the next day» if it runs past midnight.';

  @override
  String get branchErrorPeriodLength =>
      'A period lasts from 15 minutes to 16 hours.';

  @override
  String get branchErrorPeriodsOverlap => 'The periods overlap.';

  @override
  String get assistantErrorLimitReached =>
      'You\'ve reached the most assistants you can have.';

  @override
  String get assistantErrorPhoneTaken =>
      'This number is already an assistant, in this clinic or another.';

  @override
  String get assistantErrorRemoved =>
      'This assistant was removed. Add them again as a new assistant.';

  @override
  String get profileTopBarTooltip => 'My profile';

  @override
  String get settingsSubtitleDoctor =>
      'Your profile, prices, language, notifications and password.';

  @override
  String get settingsSubtitleAssistant =>
      'Your language, notifications and password, and what you can do in the clinic.';

  @override
  String get settingsProfileHint => 'Name, title, degrees and specialties';

  @override
  String settingsPermissionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: '1 permission',
      zero: 'No permissions',
    );
    return '$_temp0';
  }

  @override
  String settingsBranchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count branches',
      one: '1 branch',
      zero: 'No branches',
    );
    return '$_temp0';
  }

  @override
  String get settingsClinicGroup => 'Clinic';

  @override
  String get settingsPricesHint =>
      'Examination and consultation, for the doctor and each branch';

  @override
  String get settingsMyPermissions => 'My permissions';

  @override
  String get settingsMyPermissionsFooter =>
      'Only the doctor can change these. Changes apply at once.';

  @override
  String get settingsNoPermissions => 'No permissions yet. Ask the doctor.';

  @override
  String get settingsMyBranches => 'My branches';

  @override
  String get settingsAllBranchesFooter =>
      'You work in every branch, including ones the doctor adds later.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotifyChat => 'Chat messages';

  @override
  String get settingsNotifyChatHint => 'New messages from patients';

  @override
  String get settingsNotifyReminders => 'Reminders';

  @override
  String get settingsNotifyRemindersHint => 'Invoices and appointments';

  @override
  String get settingsNotifyBookings => 'Bookings';

  @override
  String get settingsNotifyBookingsHint =>
      'New, changed and cancelled bookings';

  @override
  String get settingsShowPreview => 'Show message text in notifications';

  @override
  String get settingsShowPreviewHint =>
      'Off: notifications only say that a message arrived.';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAbout => 'About';

  @override
  String get profileTitle => 'Profile';

  @override
  String get pricesTitle => 'Visit prices';

  @override
  String get assistantPresetReception => 'Reception';

  @override
  String get assistantPresetClinical => 'Clinical assistant';

  @override
  String get assistantPresetOfficeManager => 'Office manager';

  @override
  String get assistantPresetCustom => 'Custom';

  @override
  String get assistantPresetReceptionBody =>
      'Patients, visits, files and bookings.';

  @override
  String get assistantPresetClinicalBody =>
      'Reception, plus the medical file, drafts and chat.';

  @override
  String get assistantPresetOfficeManagerBody =>
      'Reception, plus billing, the schedule, prices and chat.';

  @override
  String get assistantPresetCustomBody => 'The boxes you tick below.';

  @override
  String get assistantGroupPatients => 'Patients';

  @override
  String get assistantGroupSessions => 'Visits';

  @override
  String get assistantGroupClinical => 'Medical file';

  @override
  String get assistantGroupFiles => 'Files and prescriptions';

  @override
  String get assistantGroupChat => 'Chat';

  @override
  String get assistantGroupBilling => 'Billing';

  @override
  String get assistantGroupAppointments => 'Appointments';

  @override
  String get assistantGroupMoney => 'Revenue and prices';

  @override
  String get assistantPermPatientsManage => 'Manage patients';

  @override
  String get assistantPermPatientsManageHelp =>
      'Add and link patients, edit their details, archive.';

  @override
  String get assistantPermPatientsResetPassword => 'Reset patient passwords';

  @override
  String get assistantPermPatientsResetPasswordHelp =>
      'Give a patient a new temporary password, and get their reset requests.';

  @override
  String get assistantPermSessionsCreate => 'Record visits';

  @override
  String get assistantPermSessionsCreateHelp =>
      'Visit type, chief complaint and vitals, and the visit list.';

  @override
  String get assistantPermSessionsDelete => 'Delete visits';

  @override
  String get assistantPermSessionsDeleteHelp =>
      'Under the same conditions as the doctor. Off by default.';

  @override
  String get assistantPermClinicalView => 'View the medical file';

  @override
  String get assistantPermClinicalViewHelp =>
      'Medical profile, findings, diagnosis, notes and prescriptions.';

  @override
  String get assistantPermClinicalEditProfile => 'Edit the medical profile';

  @override
  String get assistantPermClinicalEditProfileHelp =>
      'Allergies, chronic diseases, medications, surgeries, family history.';

  @override
  String get assistantPermFilesManage => 'Files';

  @override
  String get assistantPermFilesManageHelp =>
      'Scan, upload and view files, and save chat attachments.';

  @override
  String get assistantPermPrescriptionsPrint => 'Print prescriptions';

  @override
  String get assistantPermPrescriptionsPrintHelp =>
      'Open, print and share prescriptions the doctor sent.';

  @override
  String get assistantPermPrescriptionsDraft => 'Prepare prescription drafts';

  @override
  String get assistantPermPrescriptionsDraftHelp =>
      'Write drafts and send them to the doctor for review.';

  @override
  String get assistantPermChat => 'Chat';

  @override
  String get assistantPermChatHelp =>
      'Read and reply to patients on the doctor\'s behalf.';

  @override
  String get assistantPermBillingView => 'View billing';

  @override
  String get assistantPermBillingViewHelp =>
      'Fee cards, daily and monthly totals, invoices.';

  @override
  String get assistantPermBillingPay => 'Pay invoices';

  @override
  String get assistantPermBillingPayHelp => 'Send the payment for an invoice.';

  @override
  String get assistantPermAppointmentsView => 'View appointments';

  @override
  String get assistantPermAppointmentsViewHelp =>
      'Calendar, today\'s board and search, in their branches.';

  @override
  String get assistantPermAppointmentsManage => 'Manage appointments';

  @override
  String get assistantPermAppointmentsManageHelp =>
      'Book, confirm, move, cancel, check in, call the next patient.';

  @override
  String get assistantPermScheduleManage => 'Manage the schedule';

  @override
  String get assistantPermScheduleManageHelp =>
      'Working hours, special dates and booking settings of their branches.';

  @override
  String get assistantPermRevenueView => 'View revenue';

  @override
  String get assistantPermRevenueViewHelp =>
      'Clinic revenue, net income and the amounts patients paid.';

  @override
  String get assistantPermPricesManage => 'Manage visit prices';

  @override
  String get assistantPermPricesManageHelp =>
      'The doctor\'s prices, and their branches\' prices.';

  @override
  String get assistantStatusRemoved => 'Removed';

  @override
  String get branchStatusActive => 'Open';

  @override
  String get branchStatusArchived => 'Archived';

  @override
  String get branchDefault => 'Default';

  @override
  String get branchPayCash => 'Cash';

  @override
  String get branchPayCard => 'Card';

  @override
  String get branchPayInstapay => 'InstaPay';

  @override
  String get branchPayWallet => 'Mobile wallet';

  @override
  String get branchAmenityElevator => 'Elevator';

  @override
  String get branchAmenityParking => 'Parking';

  @override
  String get branchAmenityWheelchair => 'Wheelchair access';

  @override
  String get branchAmenityKidsArea => 'Children\'s waiting area';

  @override
  String branchEndsNextDayShort(String range) {
    return '$range (next day)';
  }

  @override
  String get profileSubtitle =>
      'Your personal and professional details, as patients and the admin team see them.';

  @override
  String profileLastSaved(String time) {
    return 'Last saved $time';
  }

  @override
  String get profilePersonal => 'Personal details';

  @override
  String get profileFullNameAr => 'Full name in Arabic';

  @override
  String get profileReadOnlyNote =>
      'These identify your account and license. To change them, contact support.';

  @override
  String get profileProfessional => 'Professional details';

  @override
  String get profileDegreesHint =>
      'For example: MSc in internal medicine, Cairo University';

  @override
  String get profileSpecialtyNote =>
      'A specialty change applies at once, and the admin team is told.';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileSavedSpecialty =>
      'Profile saved. Your new specialty applies now, and the admin team was told.';

  @override
  String get profilePrescriptionHeader => 'Prescription header';

  @override
  String get profilePrescriptionHeaderTitle =>
      'Logo, signature, colour and print settings';

  @override
  String get profilePrescriptionHeaderLater =>
      'You\'ll set how your prescriptions look when prescriptions arrive in the app.';

  @override
  String get settingsLaterPhase => 'Later phase';

  @override
  String get pricesSubtitle =>
      'What patients pay at the clinic, for the doctor and for each branch.';

  @override
  String get pricesFutureOnly => 'New prices apply to future visits only.';

  @override
  String get pricesDoctorTitle => 'Doctor\'s prices';

  @override
  String get pricesDoctorBody =>
      'Every branch without its own prices uses these.';

  @override
  String get pricesBranchesTitle => 'Branch prices';

  @override
  String get pricesUseDoctor => 'Use the doctor\'s prices';

  @override
  String pricesUseDoctorOn(String examination, String consultation) {
    return 'Examination: $examination, consultation: $consultation';
  }

  @override
  String get pricesUseDoctorOff =>
      'This branch\'s own prices. An empty one uses the doctor\'s.';

  @override
  String get pricesEmptyAskClinic =>
      'Empty: patients see «Ask the clinic», and the amount is typed at each visit.';

  @override
  String pricesEmptyUsesDoctor(String price) {
    return 'Empty: the doctor\'s price ($price) applies.';
  }

  @override
  String get pricesAskClinic => 'Ask the clinic';

  @override
  String get pricesSaved => 'Prices saved. They apply to visits from now on.';

  @override
  String get pricesNotYourBranch =>
      'Only the doctor or this branch\'s assistants can change these prices.';

  @override
  String get pricesHistoryTitle => 'Change history';

  @override
  String get pricesHistoryEmptyTitle => 'No price changes yet';

  @override
  String get pricesHistoryEmptyBody =>
      'Every change shows here, with who made it and when.';

  @override
  String get pricesNotSet => 'not set';

  @override
  String pricesChange(String type, String before, String after) {
    return '$type: $before → $after';
  }

  @override
  String pricesChangedBy(String name, String role, String time) {
    return '$name ($role), $time';
  }

  @override
  String get branchesSubtitle =>
      'Where you see patients. Tap a branch to change its details, hours or status.';

  @override
  String get branchesEmptyTitle => 'No branches yet';

  @override
  String get branchAdd => 'Add branch';

  @override
  String branchCountOf(int count, int limit) {
    return '$count of $limit branches';
  }

  @override
  String get branchArchivedHint =>
      'Archived: hidden from patients and bookings';

  @override
  String get branchClosedToday => 'Closed today';

  @override
  String branchUpcomingBookings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count upcoming bookings',
      one: '1 upcoming booking',
      zero: 'No upcoming bookings',
    );
    return '$_temp0';
  }

  @override
  String branchReopensOn(String date) {
    return 'Reopens on $date';
  }

  @override
  String get branchSaved => 'Saved';

  @override
  String get branchTabInfo => 'Info';

  @override
  String get branchTabAddress => 'Address and map';

  @override
  String get branchTabContact => 'Contact';

  @override
  String get branchTabHours => 'Working hours';

  @override
  String get branchTabClinic => 'Clinic info for patients';

  @override
  String branchTabUnsaved(String tab) {
    return '$tab, not saved';
  }

  @override
  String get branchDescription => 'Short description (optional)';

  @override
  String get branchDescriptionHint =>
      'For example: second floor, next to the pharmacy';

  @override
  String get branchAreaLabel => 'Area (optional)';

  @override
  String get branchEmailLabel => 'Clinic email (optional)';

  @override
  String get branchPaymentMethods => 'Payment at the clinic';

  @override
  String get branchAmenities => 'Amenities';

  @override
  String get branchForPatients => 'What patients see';

  @override
  String get branchForPatientsBody =>
      'Shown on the branch card when patients book.';

  @override
  String get branchPricesTitle => 'This branch\'s prices';

  @override
  String branchHoursQueueNote(int count) {
    return 'Bookings here go by queue number. Each period takes $count patients unless you set its own number.';
  }

  @override
  String get branchHoursTimedNote => 'Bookings here go by appointment time.';

  @override
  String get branchCopySaturday => 'Copy Saturday to all days';

  @override
  String get branchCopySaturdayTitle => 'Copy Saturday to every day?';

  @override
  String get branchCopySaturdayBody =>
      'The other days\' periods are replaced by Saturday\'s. Nothing is saved until you tap Save.';

  @override
  String get branchDayClosed => 'Closed';

  @override
  String get branchAddPeriod => 'Add period';

  @override
  String get branchRemovePeriod => 'Remove this period';

  @override
  String get branchPeriodFrom => 'From';

  @override
  String get branchPeriodTo => 'To';

  @override
  String get branchEndsNextDay => 'Ends the next day';

  @override
  String get branchPeriodMorning => 'Morning';

  @override
  String get branchPeriodEvening => 'Evening';

  @override
  String get branchCapacity => 'Patients';

  @override
  String get branchErrorTooManyPeriods => 'At most 10 periods a day.';

  @override
  String get branchStatusTitle => 'Branch status';

  @override
  String get branchStatusActiveBody => 'Open: patients see it and can book.';

  @override
  String get branchStatusDefaultBody =>
      'Open, and the default: new visits use it unless you pick another branch.';

  @override
  String get branchStatusClosedBody =>
      'Patients see your message on the branch card and can\'t book here.';

  @override
  String get branchStatusArchivedBody =>
      'Hidden from patients and bookings. Its history stays, and you can bring it back.';

  @override
  String get branchPatientsSee => 'Patients see';

  @override
  String get branchMakeDefault => 'Make default';

  @override
  String branchMakeDefaultTitle(String name) {
    return 'Make $name the default?';
  }

  @override
  String get branchMakeDefaultBody =>
      'New visits and walk-ins use the default branch unless another one is picked.';

  @override
  String branchDefaultMessage(String name) {
    return '$name is now the default branch.';
  }

  @override
  String get branchCloseTemporarily => 'Close temporarily';

  @override
  String get branchCloseBody =>
      'Patients see this message on the branch card and can\'t book here until you reopen it.';

  @override
  String get branchClosedMessageLabel => 'Message for patients';

  @override
  String get branchClosedMessageHint => 'For example: closed for renovation';

  @override
  String get branchReopenDateAdd => 'Expected reopening date (optional)';

  @override
  String get branchCloseConfirm => 'Close the branch';

  @override
  String get branchClosedMessage => 'The branch is closed for now.';

  @override
  String get branchEditClosure => 'Edit the message';

  @override
  String get branchReopen => 'Reopen';

  @override
  String get branchReopenedMessage => 'The branch is open again.';

  @override
  String get branchArchive => 'Archive';

  @override
  String branchArchiveTitle(String name) {
    return 'Archive $name?';
  }

  @override
  String get branchArchiveBody =>
      'It disappears for patients and can\'t take bookings. Its visits and history stay, and you can bring it back later.';

  @override
  String get branchArchivedMessage => 'The branch is archived.';

  @override
  String get branchRestore => 'Bring back';

  @override
  String get branchRestoredMessage => 'The branch is back and open.';

  @override
  String get branchRefusedTitle => 'Not possible yet';

  @override
  String branchBookingsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count upcoming bookings',
      one: '1 upcoming booking',
    );
    return '$_temp0';
  }

  @override
  String branchBookingsMore(int count) {
    return 'And $count more.';
  }

  @override
  String get branchBookingsHint =>
      'Move them to another branch or cancel them from the appointments calendar, then try again. Cancelled patients are told, with a link to book again.';

  @override
  String branchBookingGuest(String name) {
    return '$name (guest)';
  }

  @override
  String get branchLaterTabs => 'Coming later';

  @override
  String get branchLaterTabsTitle => 'Booking settings and special dates';

  @override
  String get branchLaterTabsBody => 'They arrive with appointments.';

  @override
  String get branchAddedMessage => 'Branch added. Now set its working hours.';

  @override
  String get branchNewNextSteps =>
      'Working hours and prices come next, after you add the branch.';

  @override
  String get assistantsSubtitle =>
      'People who work with you, and what each one can do.';

  @override
  String get assistantAdd => 'Add assistant';

  @override
  String assistantCountOf(int count, int limit) {
    return '$count of $limit assistants';
  }

  @override
  String get assistantsEmptyTitle => 'No assistants yet';

  @override
  String get assistantsEmptyBody =>
      'Add someone from reception to record visits and bookings for you.';

  @override
  String get assistantChoose => 'Choose an assistant to see their details';

  @override
  String get assistantAddBody =>
      'They get a temporary password and choose their own when they first sign in.';

  @override
  String get assistantNeverActive => 'Hasn\'t used the clinic yet';

  @override
  String assistantLastActive(String time) {
    return 'Last active $time';
  }

  @override
  String assistantAddedOn(String date) {
    return 'Added on $date';
  }

  @override
  String get assistantDetails => 'Details';

  @override
  String get assistantPhoneHint => 'They sign in with this number.';

  @override
  String get assistantBranches => 'Branches';

  @override
  String get assistantBranchesHint =>
      'Bookings, today\'s board and visit lists show only these branches.';

  @override
  String get assistantAllBranches => 'All branches';

  @override
  String get assistantSomeBranches => 'Some branches';

  @override
  String get assistantAllBranchesBody => 'Including branches you add later.';

  @override
  String get assistantErrorBranchRequired => 'Choose at least one branch.';

  @override
  String get assistantPermissions => 'Permissions';

  @override
  String get assistantPermissionsHint =>
      'Pick a preset, then adjust the boxes. Some need another, which is ticked for you.';

  @override
  String assistantAlsoOn(String permissions) {
    return 'Also turned on: $permissions';
  }

  @override
  String assistantAlsoOff(String permissions) {
    return 'Also turned off: $permissions';
  }

  @override
  String assistantSaved(String name) {
    return '$name\'s changes are saved. They apply on their next action.';
  }

  @override
  String get assistantAccountActions => 'Account';

  @override
  String get assistantResetPassword => 'Reset password';

  @override
  String get assistantResetPasswordHint =>
      'A new temporary password, when they forget theirs.';

  @override
  String assistantResetTitle(String name) {
    return 'Reset $name\'s password?';
  }

  @override
  String get assistantResetBody =>
      'They\'re signed out on every device and sign in again with the new temporary password.';

  @override
  String get assistantNewPasswordTitle => 'New temporary password';

  @override
  String get assistantDisableHint =>
      'Stops them signing in, at once. You can enable them again.';

  @override
  String get assistantEnableHint => 'They can sign in again.';

  @override
  String assistantDisableTitle(String name) {
    return 'Disable $name?';
  }

  @override
  String get assistantDisableBody =>
      'They\'re signed out at once and can\'t sign in until you enable them again.';

  @override
  String assistantEnableTitle(String name) {
    return 'Enable $name?';
  }

  @override
  String get assistantEnableBody =>
      'They can sign in again with their password.';

  @override
  String get assistantRemove => 'Remove';

  @override
  String get assistantRemoveHint =>
      'Final. Their history stays in the activity log.';

  @override
  String assistantRemoveTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get assistantRemoveBody =>
      'They\'re signed out at once and can\'t come back. Their history stays in the activity log, and their number can be added again as a new assistant.';

  @override
  String assistantRemovedMessage(String name) {
    return '$name was removed.';
  }

  @override
  String assistantRemovedTitle(String name) {
    return '$name was removed';
  }

  @override
  String activityCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'Nothing recorded yet',
    );
    return '$_temp0';
  }

  @override
  String get activityEmptyTitle => 'Nothing recorded yet';

  @override
  String get activityEmptyBody =>
      'What you and your assistants do in the clinic shows here.';

  @override
  String get activityToday => 'Today';

  @override
  String get activityYesterday => 'Yesterday';

  @override
  String activityWhoWhen(String who, String time) {
    return '$who, $time';
  }

  @override
  String activityRemovedPerson(String name) {
    return '$name (removed)';
  }

  @override
  String activityPatientFile(String name, int number) {
    return '$name, file $number';
  }

  @override
  String get activityPatientUnlinked => 'A patient no longer in the clinic';

  @override
  String get activityOnlyThisPatient => 'Only this patient';

  @override
  String get activitySomeBranch => 'a branch';

  @override
  String get activitySomeAssistant => 'an assistant';

  @override
  String activityBranchCreated(String branch) {
    return 'Added the branch $branch';
  }

  @override
  String activityBranchUpdated(String branch) {
    return 'Edited $branch';
  }

  @override
  String activityBranchHoursUpdated(String branch) {
    return 'Changed the working hours of $branch';
  }

  @override
  String activityBranchStatusChanged(
    String branch,
    String before,
    String after,
  ) {
    return '$branch: $before → $after';
  }

  @override
  String activityDefaultBranchChanged(String branch) {
    return 'Made $branch the default branch';
  }

  @override
  String get activityDoctorPricesUpdated =>
      'Changed the doctor\'s visit prices';

  @override
  String activityBranchPricesUpdated(String branch) {
    return 'Changed the prices of $branch';
  }

  @override
  String get activityProfileUpdated => 'Edited the profile';

  @override
  String get activitySpecialtyChanged => 'Changed the specialty';

  @override
  String activityAssistantCreated(String name, String preset) {
    return 'Added the assistant $name ($preset)';
  }

  @override
  String activityAssistantUpdated(String name) {
    return 'Edited $name\'s details';
  }

  @override
  String activityAssistantPermissionsChanged(String name) {
    return 'Changed $name\'s permissions';
  }

  @override
  String activityAssistantPasswordReset(String name) {
    return 'Reset $name\'s password';
  }

  @override
  String activityAssistantDisabled(String name) {
    return 'Disabled $name';
  }

  @override
  String activityAssistantEnabled(String name) {
    return 'Enabled $name';
  }

  @override
  String activityAssistantRemoved(String name) {
    return 'Removed $name';
  }

  @override
  String get activityPasswordChanged => 'Changed their password';

  @override
  String get activityPasswordSet => 'Set their password';

  @override
  String activityPasswordResetRequested(String name) {
    return '$name asked for a new password';
  }

  @override
  String get activityRegistrationSent => 'Sent the sign-up request';

  @override
  String get activityEmailVerified => 'Confirmed the email';

  @override
  String activityOther(String action) {
    return 'Other action: $action';
  }

  @override
  String activityPermissionsAdded(String permissions) {
    return 'Added: $permissions.';
  }

  @override
  String activityPermissionsRemoved(String permissions) {
    return 'Removed: $permissions.';
  }

  @override
  String activityPeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periods a week',
      one: '1 period a week',
      zero: 'Closed every day',
    );
    return '$_temp0';
  }

  @override
  String get activityActionBranchCreated => 'Branch added';

  @override
  String get activityActionBranchUpdated => 'Branch edited';

  @override
  String get activityActionBranchHoursUpdated => 'Working hours changed';

  @override
  String get activityActionBranchStatusChanged => 'Branch status changed';

  @override
  String get activityActionDefaultBranchChanged => 'Default branch changed';

  @override
  String get activityActionPricesUpdated => 'Prices changed';

  @override
  String get activityActionProfileUpdated => 'Profile edited';

  @override
  String get activityActionSpecialtyChanged => 'Specialty changed';

  @override
  String get activityActionAssistantCreated => 'Assistant added';

  @override
  String get activityActionAssistantUpdated => 'Assistant edited';

  @override
  String get activityActionPermissionsChanged => 'Permissions changed';

  @override
  String get activityActionAssistantPasswordReset => 'Assistant password reset';

  @override
  String get activityActionAssistantDisabled => 'Assistant disabled';

  @override
  String get activityActionAssistantEnabled => 'Assistant enabled';

  @override
  String get activityActionAssistantRemoved => 'Assistant removed';

  @override
  String get activityActionPasswordChanged => 'Password changed';

  @override
  String get activityActionPasswordSet => 'Password chosen';

  @override
  String get activityActionPasswordResetRequested => 'New password requested';

  @override
  String get activityActionRegistrationSent => 'Sign-up sent';

  @override
  String get activityActionEmailVerified => 'Email confirmed';

  @override
  String get assistantNotAddedYet => 'Not added yet';

  @override
  String get assistantNameHint => 'A first and a last name, at least';

  @override
  String get activityPatientCreated => 'Added a new patient';

  @override
  String get activityPatientLinked =>
      'Added a patient who already has an account';

  @override
  String get activityPatientUpdated => 'Edited the patient\'s details';

  @override
  String get activityPatientPhoneChanged =>
      'Changed the patient\'s mobile number';

  @override
  String get activityPatientPasswordReset => 'Reset the patient\'s password';

  @override
  String get activityPatientArchived => 'Archived the patient\'s file';

  @override
  String get activityPatientUnarchived =>
      'Brought the patient\'s file back from the archive';

  @override
  String get activityPatientMedicalProfileUpdated =>
      'Edited the medical profile';

  @override
  String get activitySessionCreatedExamination => 'Recorded an examination';

  @override
  String get activitySessionCreatedConsultation => 'Recorded a consultation';

  @override
  String get activitySessionClinicalUpdated =>
      'Edited a visit\'s medical notes';

  @override
  String get activitySessionPrivateNoteUpdated =>
      'Edited a visit\'s private note';

  @override
  String get activitySessionAmountChanged =>
      'Changed the amount charged for a visit';

  @override
  String get activitySessionDeleted => 'Deleted a visit';

  @override
  String activityFromTo(String before, String after) {
    return 'From $before to $after';
  }

  @override
  String activityReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get activityActionPatientCreated => 'Patient added';

  @override
  String get activityActionPatientLinked => 'Patient linked';

  @override
  String get activityActionPatientUpdated => 'Patient edited';

  @override
  String get activityActionPatientPhoneChanged => 'Patient mobile changed';

  @override
  String get activityActionPatientPasswordReset => 'Patient password reset';

  @override
  String get activityActionPatientArchived => 'Patient archived';

  @override
  String get activityActionPatientUnarchived => 'Patient unarchived';

  @override
  String get activityActionPatientMedicalProfileUpdated =>
      'Medical profile edited';

  @override
  String get activityActionSessionCreated => 'Visit recorded';

  @override
  String get activityActionSessionClinicalUpdated => 'Visit notes edited';

  @override
  String get activityActionSessionPrivateNoteUpdated => 'Private note edited';

  @override
  String get activityActionSessionAmountChanged => 'Amount charged changed';

  @override
  String get activityActionSessionDeleted => 'Visit deleted';

  @override
  String get sessionToday => 'Today';

  @override
  String get sessionYesterday => 'Yesterday';

  @override
  String sessionDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get sessionTypeExamination => 'Examination';

  @override
  String get sessionTypeConsultation => 'Consultation';

  @override
  String get sessionPaymentCash => 'Cash';

  @override
  String get sessionPaymentCard => 'Card';

  @override
  String get sessionPaymentInstapay => 'InstaPay';

  @override
  String get sessionPaymentWallet => 'Mobile wallet';

  @override
  String get sessionAwaitingDoctor => 'Waiting for the doctor';

  @override
  String get patientHasAllergies => 'Has allergies';

  @override
  String get patientAllergyFlag => 'Allergies';

  @override
  String patientFileNumber(String number) {
    return 'File $number';
  }

  @override
  String feesEquation(String examinations, String consultations, String total) {
    return '$examinations + $consultations = $total';
  }

  @override
  String feesExaminationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count examinations',
      one: '1 examination',
    );
    return '$_temp0';
  }

  @override
  String feesConsultationCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count consultations',
      one: '1 consultation',
    );
    return '$_temp0';
  }

  @override
  String get patientAdd => 'Add patient';

  @override
  String patientRegisterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients',
      one: '1 patient',
      zero: 'No patients',
    );
    return '$_temp0';
  }

  @override
  String get patientSearchHint => 'Search by name, mobile or file number';

  @override
  String get patientNoMatchTitle => 'No patients match';

  @override
  String get patientNoMatchBody => 'Try another name, number or filter.';

  @override
  String get patientFilterClear => 'Clear filters';

  @override
  String get patientEmptyTitle => 'No patients yet';

  @override
  String get patientEmptyBody => 'Add your first patient to open their file.';

  @override
  String get patientFilterLastVisit => 'Last visit';

  @override
  String get patientFilterAny => 'Any';

  @override
  String get patientFilterBranch => 'Branch';

  @override
  String get patientFilterAllBranches => 'All branches';

  @override
  String get patientFilterVisits => 'Visits';

  @override
  String get patientFilterNewThisMonth => 'New this month';

  @override
  String get patientFilterChronic => 'Chronic disease';

  @override
  String get patientFilterArchived => 'Archived';

  @override
  String get patientVisitsOne => '1 visit';

  @override
  String get patientVisitsFew => '2 to 4 visits';

  @override
  String get patientVisitsMany => '5 visits or more';

  @override
  String get patientLastVisitThisWeek => 'This week';

  @override
  String get patientLastVisitThisMonth => 'This month';

  @override
  String get patientLastVisitNotSeen3m => 'Not seen for 3 months';

  @override
  String get patientLastVisitNotSeen6m => 'Not seen for 6 months';

  @override
  String get patientLastVisitNotSeen12m => 'Not seen for a year';

  @override
  String get patientLastVisitNever => 'Never visited';

  @override
  String get patientArchived => 'Archived';

  @override
  String get patientNoVisits => 'No visits yet';

  @override
  String get patientColumnFile => 'File';

  @override
  String get patientColumnName => 'Name';

  @override
  String get patientColumnPhone => 'Mobile';

  @override
  String get patientColumnAge => 'Age';

  @override
  String get patientColumnFirstVisit => 'First visit';

  @override
  String get patientColumnLastVisit => 'Last visit';

  @override
  String get patientColumnVisits => 'Visits';

  @override
  String get patientColumnPaid => 'Paid';

  @override
  String get patientColumnAllergies => 'Allergies';

  @override
  String patientVisitsSplit(int examinations, int consultations) {
    return '$examinations exam., $consultations consult.';
  }

  @override
  String get patientGenderMale => 'Male';

  @override
  String get patientGenderFemale => 'Female';

  @override
  String patientAgeYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years',
      one: '1 year',
      zero: 'Under 1 year',
    );
    return '$_temp0';
  }

  @override
  String patientAgeGender(String age, String gender) {
    return '$age, $gender';
  }

  @override
  String patientVisitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
      zero: 'No visits',
    );
    return '$_temp0';
  }

  @override
  String patientVisitsSummary(
    String visits,
    String examinations,
    String consultations,
  ) {
    return '$visits: $examinations, $consultations';
  }

  @override
  String get patientSortFileNumber => 'File number';

  @override
  String get patientSortGender => 'Gender';

  @override
  String get patientSortExaminations => 'Examinations';

  @override
  String get patientSortConsultations => 'Consultations';

  @override
  String get patientSortFiles => 'Files';

  @override
  String get patientSortLinkedAt => 'Date added';

  @override
  String get patientTotalPaid => 'Total paid';

  @override
  String patientLastVisitSemantics(String type, String date, String ago) {
    return 'Last visit: $type, $date, $ago';
  }

  @override
  String get patientResetPasswordTitle => 'Reset the password?';

  @override
  String patientResetPasswordBody(String name) {
    return '$name gets a new temporary password and is signed out on every device. They choose their own at the next sign-in.';
  }

  @override
  String get patientResetPassword => 'Reset password';

  @override
  String get patientNewTemporaryPassword => 'New temporary password';

  @override
  String get patientArchiveTitle => 'Archive this patient?';

  @override
  String get patientUnarchiveTitle => 'Bring this patient back?';

  @override
  String get patientArchiveBody =>
      'They leave the patients list. Nothing is deleted, and a new session brings them back.';

  @override
  String get patientUnarchiveBody => 'They appear in the patients list again.';

  @override
  String get patientArchive => 'Archive';

  @override
  String get patientUnarchive => 'Unarchive';

  @override
  String get patientArchivedDone => 'Patient archived';

  @override
  String get patientUnarchivedDone => 'Patient back in the list';

  @override
  String get patientMoreActions => 'More actions';

  @override
  String get sessionNew => 'New session';

  @override
  String get patientEdit => 'Edit';

  @override
  String get patientLinkedNote =>
      'This patient\'s account was created by another clinic. You see their name, mobile, gender and date of birth, and only the records your clinic adds.';

  @override
  String get patientDetails => 'Personal details';

  @override
  String get patientBloodType => 'Blood type';

  @override
  String get patientNationalId => 'National ID';

  @override
  String get patientAddress => 'Address';

  @override
  String get patientEmergencyContact => 'Emergency contact';

  @override
  String get patientNoTabs =>
      'Your permissions don\'t include this patient\'s medical file.';

  @override
  String get patientTabOverview => 'Overview';

  @override
  String get patientTabSessions => 'Sessions';

  @override
  String get patientCantOpenApp => 'No app on this device can open it.';

  @override
  String get patientCall => 'Call';

  @override
  String get patientWhatsApp => 'WhatsApp';

  @override
  String get patientFileSummary => 'File summary';

  @override
  String get patientConsultationsSinceExam =>
      'Consultations since the last examination';

  @override
  String sessionConsultationCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Consultation $count of $max since the last examination',
      zero: 'No consultations since the last examination (up to $max)',
    );
    return '$_temp0';
  }

  @override
  String get patientProfileEmptyTitle => 'No medical profile yet';

  @override
  String get patientProfileEmptyBody =>
      'Record allergies, chronic diseases and current medications.';

  @override
  String get patientEditMedicalProfile => 'Edit medical profile';

  @override
  String get patientAllergies => 'Allergies';

  @override
  String get patientChronicDiseases => 'Chronic diseases';

  @override
  String get patientCurrentMedications => 'Current medications';

  @override
  String get patientSurgeries => 'Past surgeries';

  @override
  String get patientFamilyHistory => 'Family history';

  @override
  String get patientGeneralNotes => 'Notes';

  @override
  String get patientNoAllergies => 'No known allergies';

  @override
  String get patientNothingRecorded => 'Nothing recorded';

  @override
  String get patientSessionsEmptyTitle => 'No sessions yet';

  @override
  String get patientSessionsEmptyBody =>
      'A first visit is always an examination.';

  @override
  String get patientLoadMore => 'Show more';

  @override
  String sessionPlatformFeeShort(String amount) {
    return 'Fee $amount';
  }

  @override
  String sessionRecordedBy(String name) {
    return 'Recorded by $name';
  }

  @override
  String get patientCheckFields => 'Check the highlighted fields.';

  @override
  String get patientAddSubtitle =>
      'The patient gets an account and a file number. Their temporary password is shown once.';

  @override
  String get patientMobile => 'Mobile number';

  @override
  String get patientMobileHint => 'The patient signs in with it.';

  @override
  String get patientMobileLabel => 'Mobile';

  @override
  String get patientPhoneChecking => 'Checking the number…';

  @override
  String get patientPhoneNew => 'New number. Fill in the patient’s details.';

  @override
  String get patientPhoneOurs => 'This number is already one of your patients';

  @override
  String get patientPhoneElsewhere =>
      'This number already has an el3yada account';

  @override
  String get patientPhoneElsewhereBody =>
      'Link the patient to add them to your list. No new account is created.';

  @override
  String get patientLinkTitle => 'This patient already has an account';

  @override
  String patientLinkBody(String phone) {
    return 'The number $phone belongs to a patient of another clinic. Linking adds them to your list with a new file number.';
  }

  @override
  String get patientLinkPrivacy =>
      'You will see their name, mobile, gender and date of birth, and only the records your clinic creates.';

  @override
  String get patientLinkConfirm => 'Link patient';

  @override
  String get patientLinkedTitle => 'Patient added';

  @override
  String get patientLinkedBody =>
      'This patient already has an account and has been added to your list.';

  @override
  String get patientOpenFile => 'Open file';

  @override
  String get patientErrorName => 'Write at least two names, in letters only.';

  @override
  String get patientErrorAge => 'Enter an age from 0 to 120.';

  @override
  String get patientErrorDateOfBirth => 'The date of birth isn’t valid.';

  @override
  String get patientErrorNationalId => 'The national ID must be 14 digits.';

  @override
  String get patientIdentity => 'Identity';

  @override
  String get patientFullName => 'Full name';

  @override
  String get patientFullNameHint => 'At least two names';

  @override
  String get patientGender => 'Gender';

  @override
  String get patientDateOfBirth => 'Date of birth or age';

  @override
  String get patientUseDate => 'Date';

  @override
  String get patientUseAge => 'Age';

  @override
  String get patientAgeLabel => 'Age in years';

  @override
  String get patientYearsSuffix => 'years';

  @override
  String get patientDateOfBirthLabel => 'Date of birth';

  @override
  String get patientMoreDetails => 'More details';

  @override
  String get patientOptional => 'Optional';

  @override
  String get patientNationalIdHint => '14 digits';

  @override
  String get patientNotSet => 'Not set';

  @override
  String get patientEmergencyName => 'Emergency contact name';

  @override
  String get patientEmergencyPhone => 'Emergency contact number';

  @override
  String get patientEditTitle => 'Edit patient';

  @override
  String get patientMedicalProfile => 'Medical profile';

  @override
  String get patientDiscardBody =>
      'Your changes haven’t been saved and will be lost.';

  @override
  String get patientSaved => 'Saved';

  @override
  String get patientNoChanges => 'No changes';

  @override
  String get patientUnsaved => 'Changes not saved';

  @override
  String get patientPhoneChangeHint =>
      'The patient’s login. It changes on its own, with a confirmation.';

  @override
  String get patientChangePhone => 'Change number';

  @override
  String patientChangePhoneBody(String name) {
    return '$name will sign in with the new number. Devices already signed in stay signed in.';
  }

  @override
  String get patientNewMobile => 'New mobile number';

  @override
  String get patientChangePhoneConfirm => 'Change number';

  @override
  String get patientPhoneSame => 'This is the current number.';

  @override
  String get patientPhoneChanged =>
      'Mobile number changed. The patient signs in with the new one.';

  @override
  String get patientFamilyHistoryHint => 'For example: father, diabetes';

  @override
  String patientListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String get patientListFull => 'A list holds 50 items at most.';

  @override
  String get patientListDuplicate => 'Already in the list.';

  @override
  String get patientMoveUp => 'Move up';

  @override
  String get patientMoveDown => 'Move down';

  @override
  String patientRemoveItem(String item) {
    return 'Remove $item';
  }

  @override
  String get patientAddItemHint => 'Add an item';

  @override
  String get patientAddItem => 'Add';

  @override
  String sessionConsultationLimit(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other:
          'This patient has had $max consultations in a row. Record an examination first.',
      one:
          'This patient has had 1 consultation in a row. Record an examination first.',
    );
    return '$_temp0';
  }

  @override
  String get sessionRuleFirstVisit =>
      'This is the patient\'s first visit with you, so it must be an examination.';

  @override
  String sessionRuleChanged(String message) {
    return 'A session was just recorded for this patient on another device. $message';
  }

  @override
  String get sessionStepType => 'Visit type';

  @override
  String get sessionStepDetails => 'Details and amount';

  @override
  String get sessionPickType => 'Choose the visit type.';

  @override
  String sessionPicked(String type) {
    return '$type selected';
  }

  @override
  String get sessionNext => 'Next';

  @override
  String get sessionSave => 'Save session';

  @override
  String get sessionAmountRequired => 'Enter the amount charged.';

  @override
  String get sessionClinical => 'Clinical notes';

  @override
  String get sessionChiefComplaint => 'Chief complaint';

  @override
  String get sessionFindings => 'Examination findings';

  @override
  String get sessionDiagnosis => 'Diagnosis';

  @override
  String get sessionPatientNotes => 'Notes for the patient';

  @override
  String get sessionPatientNotesHint => 'The patient sees these in their app.';

  @override
  String get sessionAmountCharged => 'Amount charged';

  @override
  String get sessionNoPrice =>
      'No visit price is set for this branch. Enter what the patient paid.';

  @override
  String sessionVisitPrice(String amount) {
    return 'Visit price $amount';
  }

  @override
  String get sessionFree => 'Free';

  @override
  String get sessionAmountLabel => 'Amount';

  @override
  String get sessionCurrency => 'EGP';

  @override
  String get sessionAmountHint =>
      'Lower it for a discount. It never changes the platform fee.';

  @override
  String get sessionFreeVisit => 'Free visit';

  @override
  String get sessionPaymentMethod => 'Payment method (optional)';

  @override
  String sessionBranch(String name) {
    return 'Branch: $name';
  }

  @override
  String get sessionChangeBranch => 'Change branch';

  @override
  String get sessionFirstVisit => 'First visit with you: examination only';

  @override
  String sessionLastSession(String type, String date) {
    return 'Last session: $type, $date';
  }

  @override
  String get sessionNoPriceShort => 'No price set';

  @override
  String get sessionNoPriceHint => 'Type the amount in the next step';

  @override
  String get sessionVisitPriceLabel => 'Visit price';

  @override
  String sessionPlatformFee(String amount) {
    return 'Platform fee $amount';
  }

  @override
  String get sessionPrivateNote => 'Private note';

  @override
  String get sessionPrivateNoteHint => 'Not visible to the patient';

  @override
  String get sessionPrivateNotePlaceholder => 'Only you can read this.';

  @override
  String get sessionFollowUp => 'Follow-up date';

  @override
  String get sessionClearFollowUp => 'Clear the follow-up date';

  @override
  String sessionConfirmTitle(String type) {
    return 'Save as $type?';
  }

  @override
  String sessionConfirmFee(String amount) {
    return 'A fee of $amount will be added.';
  }

  @override
  String get sessionConfirmPatient => 'Patient';

  @override
  String get sessionConfirmBranch => 'Branch';

  @override
  String get sessionConfirmLocked =>
      'The type and time can\'t be changed after saving.';

  @override
  String get sessionConfirmSave => 'Save';

  @override
  String get sessionLater => 'Later';

  @override
  String get sessionSaved => 'Session saved';

  @override
  String sessionSavedBody(String type, String patient, String fee) {
    return '$type for $patient. A fee of $fee was added.';
  }

  @override
  String get sessionWritePrescription => 'Write prescription';

  @override
  String get sessionLabRequest => 'Lab or radiology request';

  @override
  String get sessionAttachFiles => 'Attach files';

  @override
  String get sessionView => 'View session';

  @override
  String get sessionPickPatient => 'Choose the patient';

  @override
  String get sessionRecentPatients => 'Recent patients';

  @override
  String get sessionSearchResults => 'Results';

  @override
  String get sessionVitals => 'Vitals';

  @override
  String get sessionVitalsHint =>
      'Blood pressure, pulse, temperature, weight, height, blood sugar';

  @override
  String get sessionVitalBp => 'Blood pressure';

  @override
  String get sessionVitalBpSys => 'Systolic';

  @override
  String get sessionVitalBpDia => 'Diastolic';

  @override
  String get sessionVitalPulse => 'Pulse';

  @override
  String get sessionVitalTemp => 'Temperature';

  @override
  String get sessionVitalWeight => 'Weight';

  @override
  String get sessionVitalHeight => 'Height';

  @override
  String get sessionVitalGlucose => 'Blood sugar';

  @override
  String get sessionVitalBpPair => 'Enter both blood pressure values.';

  @override
  String get sessionVitalUnusual => 'Unusual value, check it.';

  @override
  String get sessionNoVitals => 'No vitals recorded';

  @override
  String get sessionRecordedByDoctor => 'The doctor';

  @override
  String feesExaminationsFee(String amount) {
    return 'Examinations $amount';
  }

  @override
  String feesConsultationsFee(String amount) {
    return 'Consultations $amount';
  }

  @override
  String get sessionDetailsTitle => 'Session details';

  @override
  String get sessionLocked => 'Can\'t be changed after saving';

  @override
  String get sessionSummary => 'Session';

  @override
  String get sessionTime => 'Time';

  @override
  String get sessionType => 'Type';

  @override
  String get sessionBranchLabel => 'Branch';

  @override
  String get sessionPlatformFeeLabel => 'Platform fee';

  @override
  String get sessionRecordedByLabel => 'Recorded by';

  @override
  String sessionRecordedByAssistant(String name) {
    return '$name (assistant)';
  }

  @override
  String get sessionEditAmount => 'Change the amount';

  @override
  String get sessionAmountSaved => 'Amount saved';

  @override
  String get sessionAmountLogged =>
      'Every change is recorded in the activity log.';

  @override
  String get sessionNotRecorded => 'Not recorded';

  @override
  String get sessionAwaitingHint =>
      'Recorded by an assistant. Add the clinical notes to clear «Waiting for the doctor».';

  @override
  String get sessionNoPrivateNote => 'No private note';

  @override
  String get sessionDelete => 'Delete session';

  @override
  String get sessionDeleted => 'Session deleted';

  @override
  String get sessionNotDeletableLatest =>
      'Only the patient\'s latest session can be deleted.';

  @override
  String get sessionNotDeletableDay =>
      'A session can be deleted only on the day it was recorded.';

  @override
  String get sessionDeleteTitle => 'Delete this session?';

  @override
  String get sessionDeleteBody =>
      'Its fee comes off today’s and this month’s totals, and the deletion is recorded with your reason.';

  @override
  String get sessionDeleteReason => 'Reason';

  @override
  String get sessionDeleteReasonRequired =>
      'Write the reason (3 characters or more).';

  @override
  String get sessionDeleteConfirm => 'Delete';

  @override
  String get sessionTodayTitle => 'Today\'s sessions';

  @override
  String get sessionDayTitle => 'Sessions';

  @override
  String get sessionRecordedByAll => 'Everyone';

  @override
  String get sessionDayNoMatch => 'No sessions match';

  @override
  String get sessionDayEmptyTitle => 'No sessions on this day';

  @override
  String get sessionDayEmptyBody =>
      'Sessions you record appear here with their fees.';

  @override
  String get sessionPreviousDay => 'Previous day';

  @override
  String get sessionNextDay => 'Next day';

  @override
  String get sessionBackToToday => 'Today';

  @override
  String get feesPlatformFees => 'Platform fees';

  @override
  String get feesCollected => 'Collected';

  @override
  String get feesMonthTitle => 'Monthly summary';

  @override
  String get feesMonthSubtitle =>
      'Platform fees, examinations and consultations';

  @override
  String get feesPreviousMonth => 'Previous month';

  @override
  String get feesNextMonth => 'Next month';

  @override
  String get feesMonthTotals => 'Month to date';

  @override
  String get feesPerBranch => 'Per branch';

  @override
  String get feesMonthNoDays => 'This month has no days yet.';

  @override
  String get feesColumnDay => 'Day';

  @override
  String get feesColumnExaminations => 'Exam.';

  @override
  String get feesColumnConsultations => 'Consult.';

  @override
  String get feesColumnAmount => 'Fees';

  @override
  String get feesToday => 'Today';

  @override
  String get feesThisMonth => 'This month';

  @override
  String get homeAnalyticsLaterTitle => 'Charts and insights are coming';

  @override
  String get homeAnalyticsLaterBody =>
      'Revenue, visits and booking trends arrive in a later update.';

  @override
  String get homeToday => 'Today';

  @override
  String get homeSearchPatient => 'Search patient';

  @override
  String get homeTodaySessions => 'Today\'s sessions';

  @override
  String homeTodaySessionsIn(String branch) {
    return 'Today\'s sessions in $branch';
  }

  @override
  String get homeNoSessionsTitle => 'No sessions yet today';

  @override
  String get homeNoSessionsBody => 'Record the first visit of the day.';

  @override
  String get sessionErrorNotLinked => 'This patient isn\'t on your list.';

  @override
  String get patientErrorAlreadyLinked =>
      'This number is already one of your patients.';

  @override
  String get patientErrorPhoneTaken =>
      'Another patient account uses this number.';

  @override
  String get sessionErrorBranchArchived =>
      'This branch is archived. Choose another branch.';

  @override
  String get sessionErrorAmountNotEditable =>
      'The amount can be changed only on the day of the session.';

  @override
  String get sessionNoClinical => 'No clinical notes yet.';

  @override
  String sessionConsultationShort(int count, int max) {
    return '$count of $max';
  }
}
