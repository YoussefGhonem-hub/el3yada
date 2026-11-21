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
  String get navSignups => 'Doctors';

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
  String get regSubmit => 'Create my account';

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
  String get regReviewIntro => 'Check your details, then create your account.';

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
  String get adminSignupsEmptyTitle => 'No doctors yet';

  @override
  String get adminSignupsEmptyBody =>
      'Doctors show up here as soon as they sign up.';

  @override
  String get adminSignupsNoMatchTitle => 'No doctors match your search';

  @override
  String get adminSignupsNoMatchBody =>
      'Check the spelling, or search by mobile or syndicate number.';

  @override
  String get adminSelectRequest => 'Choose a doctor to see their account';

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
  String clinicSuspendedBannerMonth(String month) {
    return 'Service is suspended because the $month invoice is unpaid. Pay it to reactivate.';
  }

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

  @override
  String backToSection(String section) {
    return 'Back to $section';
  }

  @override
  String get trialEndedTitle => 'Your free trial has ended';

  @override
  String get trialEndedBody =>
      'Contact us to activate the service and keep using el3yada. Your patients and records are kept safe.';

  @override
  String get trialEndedTitleAssistant => 'The clinic\'s free trial has ended';

  @override
  String get trialEndedBodyAssistant =>
      'Ask the doctor to contact us to activate the service. Then you can carry on as usual.';

  @override
  String get trialCheckAgain => 'Check again';

  @override
  String get trialStillEnded => 'The service isn\'t active yet.';

  @override
  String trialBanner(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left in your free trial',
      one: '1 day left in your free trial',
      zero: 'Your free trial ends today',
    );
    return '$_temp0';
  }

  @override
  String get trialContactUs => 'Contact us';

  @override
  String get errorTrialEnded =>
      'The free trial has ended. Contact us to activate the service.';

  @override
  String get sessionFeeFreeTrial => 'Free (trial)';

  @override
  String get sessionPlatformFeeFree => 'No platform fee (free trial)';

  @override
  String get sessionConfirmFeeFree =>
      'No fee: the clinic is in its free trial.';

  @override
  String sessionSavedBodyFree(String type, String patient) {
    return '$type for $patient. No fee (free trial).';
  }

  @override
  String get adminErrorServiceAlreadyActive =>
      'This doctor\'s service is already active, so there\'s no trial to extend.';

  @override
  String get adminErrorDoctorStatusNotChangeable =>
      'This can\'t be done for a doctor who is pending, rejected or disabled.';

  @override
  String get adminSettingTrialDays => 'Free trial';

  @override
  String get adminAppliesToNewDoctors =>
      'Applies to doctors approved after the change';

  @override
  String get adminDoctorsFilterAll => 'All doctors';

  @override
  String get adminSignupsFilterTrialRunning => 'In free trial';

  @override
  String get adminSignupsFilterTrialEnded => 'Trial ended';

  @override
  String adminDoctorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors',
      one: '1 doctor',
      zero: 'No doctors',
    );
    return '$_temp0';
  }

  @override
  String get adminTrialListEmpty => 'No doctors here';

  @override
  String get adminTrialListEmptyBody =>
      'Doctors show up here by the state of their free trial.';

  @override
  String get adminServiceActive => 'Service active';

  @override
  String get adminTrialEnded => 'Trial ended';

  @override
  String adminTrialDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Trial: $days days left',
      one: 'Trial: 1 day left',
      zero: 'Trial: ends today',
    );
    return '$_temp0';
  }

  @override
  String get adminSectionTrial => 'Free trial';

  @override
  String get adminServiceActiveBody =>
      'The service is active. Sessions carry the platform fees.';

  @override
  String adminTrialRunningBody(String date) {
    return 'The free trial ends on $date. Sessions until then carry no fee.';
  }

  @override
  String adminTrialEndedBody(String date) {
    return 'The free trial ended on $date. The doctor and their assistants can\'t use the clinic until you activate the service or extend the trial.';
  }

  @override
  String get adminActivateService => 'Activate service';

  @override
  String adminActivateServiceTitle(String name) {
    return 'Activate the service for Dr. $name?';
  }

  @override
  String get adminActivateServiceBody =>
      'The free trial ends now, and platform fees apply to every session from now on.';

  @override
  String adminServiceActivatedMessage(String name) {
    return 'Service activated for Dr. $name.';
  }

  @override
  String get adminExtendTrial => 'Extend trial';

  @override
  String adminExtendTrialTitle(String name) {
    return 'Extend Dr. $name\'s free trial';
  }

  @override
  String get adminExtendTrialBody =>
      'The days are added to the end of the trial, or to today if it has ended.';

  @override
  String get adminExtendTrialDays => 'Days';

  @override
  String adminTrialExtendedMessage(String name, String date) {
    return 'Dr. $name\'s free trial now ends on $date.';
  }

  @override
  String get adminAuditServiceActivated => 'Activated a doctor\'s service';

  @override
  String adminAuditTrialExtended(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Extended a doctor\'s free trial by $days days',
      one: 'Extended a doctor\'s free trial by 1 day',
    );
    return '$_temp0';
  }

  @override
  String get adminActionServiceActivated => 'Service activated';

  @override
  String get adminActionTrialExtended => 'Trial extended';

  @override
  String get catalogSetupTitle => 'Getting the medicines and tests guide ready';

  @override
  String get catalogSetupBody =>
      'We\'re downloading the Egyptian medicines, lab tests and radiology guide to your device, so search is instant and works offline.';

  @override
  String get catalogSetupMeanwhile =>
      'You can keep working. Until it finishes, search suggests what you\'ve written before and you can type any name.';

  @override
  String get catalogSetupWifi => 'Wi-Fi recommended';

  @override
  String catalogSetupProgress(String received, String total) {
    return '$received of $total';
  }

  @override
  String catalogVersionLine(String version, String size) {
    return 'Version $version · $size';
  }

  @override
  String catalogVersionTitle(String version) {
    return 'Version $version';
  }

  @override
  String get catalogContinue => 'Keep using the app';

  @override
  String get catalogPhaseChecking => 'Checking for the latest version…';

  @override
  String catalogPhaseDownloading(String percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get catalogPhaseVerifying => 'Checking and preparing the file…';

  @override
  String get catalogPhaseReady => 'The guide is ready on your device';

  @override
  String get catalogPhaseNotPublished =>
      'No guide is published yet. Until it is, type names yourself; they\'re saved to your list.';

  @override
  String get catalogPhaseUnavailable =>
      'The guide isn\'t available on this device. Search covers what you\'ve written before.';

  @override
  String get catalogFailureNetwork =>
      'No internet connection. Try again picks up where it stopped.';

  @override
  String get catalogFailureServer =>
      'The server had a problem. Try again in a little while.';

  @override
  String get catalogFailureChecksum =>
      'The downloaded file was damaged and has been deleted. Try again.';

  @override
  String get catalogFailureCorrupt =>
      'The file isn\'t a valid guide and has been deleted. Try again.';

  @override
  String get catalogFailureSchema =>
      'The new version needs a newer app. Update the app to use it.';

  @override
  String get catalogFailureStorage =>
      'There isn\'t enough space on this device.';

  @override
  String catalogStatusReady(String version) {
    return 'Version $version · ready';
  }

  @override
  String get catalogStatusFailed => 'Download stopped. Open it to try again.';

  @override
  String get catalogStatusNotPublished => 'No version published yet';

  @override
  String get catalogStatusUnavailable => 'Not on this device';

  @override
  String get catalogSettingsTile => 'Medicines and tests guide';

  @override
  String get catalogNotPublished => 'No catalog version is published yet';

  @override
  String get catalogMayBeUnavailable => 'May not be available';

  @override
  String get catalogCustomTag => 'Added';

  @override
  String get catalogTypeDrug => 'Medicine';

  @override
  String get catalogTypeLab => 'Lab test';

  @override
  String get catalogTypeRadiology => 'Radiology';

  @override
  String get catalogTypeDrugs => 'Medicines';

  @override
  String get catalogTypeLabs => 'Lab tests';

  @override
  String get catalogTypeRadiologyPlural => 'Radiology';

  @override
  String get catalogReportMissing => 'Missing item';

  @override
  String get catalogReportWrong => 'Wrong details';

  @override
  String get catalogReportOther => 'Other';

  @override
  String get catalogRouteOralSolid => 'Oral (tablets, capsules)';

  @override
  String get catalogRouteOralLiquid => 'Oral liquids (syrups, drops)';

  @override
  String get catalogRouteInjection => 'Injection';

  @override
  String get catalogRouteTopical => 'Topical (creams, ointments)';

  @override
  String get catalogRouteEffervescent => 'Effervescent';

  @override
  String get catalogRouteRectal => 'Rectal (suppositories)';

  @override
  String get catalogRouteEye => 'Eye';

  @override
  String get catalogRouteEar => 'Ear';

  @override
  String get catalogRouteSpray => 'Spray';

  @override
  String get catalogRouteVaginal => 'Vaginal';

  @override
  String get catalogRouteMouth => 'Mouth and teeth';

  @override
  String get catalogRouteSoap => 'Soap and wash';

  @override
  String get catalogRouteUnknown => 'Not stated';

  @override
  String get catalogErrorShaMismatch =>
      'The file doesn\'t match its manifest (sha256). Choose the pair the builder made together.';

  @override
  String get catalogErrorManifest =>
      'The manifest has no valid sha256. Choose the .json the builder wrote with this file.';

  @override
  String get catalogErrorFileInvalid =>
      'This isn\'t a catalog made by the catalog builder.';

  @override
  String catalogErrorSchema(String actual, String expected) {
    return 'This file\'s format is version $actual; the apps read version $expected. Build it with the matching catalog builder.';
  }

  @override
  String get catalogErrorTooLarge => 'The file is larger than 150 MB.';

  @override
  String get catalogSourcesTitle => 'Data sources and licences';

  @override
  String get catalogSourcesIntro =>
      'The app\'s medicines, lab tests and radiology guide is built from these sources. LOINC names are shown exactly as published.';

  @override
  String get catalogSourceDrugsTitle => 'Medicines';

  @override
  String get catalogSourceDrugsBody =>
      'The Egyptian Drug Database by karem505, in the public domain (CC0). Prices aren\'t shown because they go out of date.';

  @override
  String catalogSourceDrugsDate(String date) {
    return 'Data as of $date';
  }

  @override
  String get catalogSourceLoincTitle => 'Lab tests and radiology (LOINC)';

  @override
  String get catalogSourceLoincBody =>
      'Lab test names and codes come from LOINC, kept exactly as published. The required copyright notice:';

  @override
  String catalogSourceLoincRelease(String release) {
    return 'LOINC release on this device: $release';
  }

  @override
  String get catalogSourceRadlexTitle =>
      'Radiology (LOINC/RSNA Radiology Playbook)';

  @override
  String get catalogSourceRadlexBody =>
      'Radiology procedures, modalities and body regions come from the LOINC/RSNA Radiology Playbook, which includes RadLex content:';

  @override
  String get catalogSourceOursTitle => 'Arabic names and short names';

  @override
  String get catalogSourceOursBody =>
      'Arabic names and short names such as «صورة دم كاملة» and CBC are written by the el3yada team and kept separate from LOINC content.';

  @override
  String get adminCatalogSubtitle =>
      'Medicines, lab tests and radiology on doctors\' devices';

  @override
  String get adminCatalogPublish => 'Publish new version';

  @override
  String get adminCatalogTabVersions => 'Versions';

  @override
  String get adminCatalogTabCustom => 'Custom items';

  @override
  String get adminCatalogTabReports => 'Doctor reports';

  @override
  String get adminCatalogCurrent => 'Current version';

  @override
  String get adminCatalogCurrentPill => 'Current';

  @override
  String get adminCatalogAllVersions => 'All versions';

  @override
  String adminCatalogPublishedOn(String date) {
    return 'Published $date';
  }

  @override
  String adminCatalogCounts(String drugs, String labs, String radiology) {
    return '$drugs medicines · $labs lab tests · $radiology radiology';
  }

  @override
  String adminCatalogDrugSource(String date) {
    return 'Drug data of $date';
  }

  @override
  String adminCatalogLoincRelease(String release) {
    return 'LOINC $release';
  }

  @override
  String get adminCatalogNothingPublishedBody =>
      'Until a version is published, doctors\' search covers only what they\'ve written before.';

  @override
  String get adminCatalogThisDevice => 'On this device';

  @override
  String get adminCatalogOpenSetup => 'Details';

  @override
  String get adminCatalogPublishTitle => 'Publish a new catalog version';

  @override
  String get adminCatalogPublishBody =>
      'Upload the file the catalog builder made (catalog-v<n>.sqlite.gz) with its manifest. The server checks it, then devices download it in the background.';

  @override
  String get adminCatalogNoFile => 'No file chosen yet';

  @override
  String get adminCatalogNoManifest => 'No manifest (.json) yet';

  @override
  String get adminCatalogPickFile => 'Choose file';

  @override
  String get adminCatalogPickManifest => 'Choose manifest';

  @override
  String get adminCatalogChecking => 'Checking the file\'s sha256…';

  @override
  String get adminCatalogShaMatches => 'The file matches its manifest (sha256)';

  @override
  String adminCatalogUploading(String sent, String total) {
    return 'Uploading… $sent of $total';
  }

  @override
  String get adminCatalogServerChecking => 'The server is checking the file…';

  @override
  String get adminCatalogDropTitle =>
      'This version has far fewer items than the current one:';

  @override
  String adminCatalogDropRow(String table, String previous, String current) {
    return '$table: $previous → $current';
  }

  @override
  String get adminCatalogDropBody =>
      'Publish anyway only if that\'s intended, for example a cleaned-up medicines list.';

  @override
  String get adminCatalogPublishAnyway => 'Publish anyway';

  @override
  String adminCatalogPublished(String version) {
    return 'Version $version published';
  }

  @override
  String get adminCatalogPublishedBody =>
      'Doctors\' devices download it in the background and switch to it when it\'s complete.';

  @override
  String get adminCatalogAllTypes => 'All';

  @override
  String get adminCatalogShowDisabled => 'Show disabled';

  @override
  String get adminCatalogSearchItems => 'Search items';

  @override
  String get adminCatalogAddItem => 'Add item';

  @override
  String get adminCatalogEditItem => 'Edit item';

  @override
  String get adminCatalogEdit => 'Edit';

  @override
  String adminCatalogItemActions(String name) {
    return 'Actions for $name';
  }

  @override
  String get adminCatalogItemBody =>
      'Every doctor sees it in search within a minute, without a new catalog version.';

  @override
  String get adminCatalogNoItems =>
      'No items here yet. Add the medicines or tests the catalog is missing.';

  @override
  String adminCatalogItemDisabled(String name) {
    return '$name is off. Doctors stop seeing it within a minute.';
  }

  @override
  String adminCatalogItemEnabled(String name) {
    return '$name is back on. Doctors see it within a minute.';
  }

  @override
  String adminCatalogUpdated(String when) {
    return 'Changed $when';
  }

  @override
  String get adminCatalogFieldTradeName => 'Trade name';

  @override
  String get adminCatalogFieldTradeNameHint =>
      'As on the box, e.g. NEWCILLIN 500 MG 12 CAPS.';

  @override
  String get adminCatalogFieldTestName => 'Name';

  @override
  String get adminCatalogFieldNameAr => 'Arabic name (optional)';

  @override
  String get adminCatalogFieldIngredient => 'Active ingredient';

  @override
  String get adminCatalogFieldGroup => 'Medicine group';

  @override
  String get adminCatalogFieldRoute => 'Route';

  @override
  String get adminCatalogFieldCode => 'LOINC code (optional)';

  @override
  String get adminCatalogFieldCodeHint => 'e.g. 2093-3';

  @override
  String get adminCatalogFieldAliases => 'Short names';

  @override
  String get adminCatalogFieldAliasesHint =>
      'Separated by commas, e.g. CBC, Blood count';

  @override
  String get adminCatalogAliasesTooMany =>
      'Up to 10 short names, each up to 100 characters';

  @override
  String get adminCatalogItemActive => 'Shown to doctors';

  @override
  String get adminCatalogItemActiveHint =>
      'Turn off to hide it from every doctor\'s search.';

  @override
  String get adminCatalogSave => 'Save';

  @override
  String get adminCatalogReportsOpen => 'Open';

  @override
  String get adminCatalogReportsDone => 'Done';

  @override
  String get adminCatalogMarkDone => 'Mark as done';

  @override
  String get adminCatalogReportHandled => 'Marked as done';

  @override
  String adminCatalogHandledOn(String date) {
    return 'Handled $date';
  }

  @override
  String get adminCatalogNoReports => 'No reports here.';

  @override
  String get specialtyProfilesSubtitle =>
      'What each specialty sees first when searching medicines and tests';

  @override
  String specialtyDoctorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors',
      one: '1 doctor',
      zero: 'No doctors',
    );
    return '$_temp0';
  }

  @override
  String specialtyItemsSummary(int groups, int labs, int radiology) {
    return '$groups medicine groups · $labs lab tests · $radiology radiology';
  }

  @override
  String get specialtyGeneralBadge => 'Added to every specialty';

  @override
  String get specialtyWithGeneral => 'With General';

  @override
  String get specialtyGeneralBody =>
      'Added to every specialty that includes it';

  @override
  String get specialtyGeneralExplained =>
      'This is the General profile: the common medicines and tests (painkillers, antibiotics, CBC …) that come first in every specialty that includes it.';

  @override
  String specialtyUpdated(String when) {
    return 'Changed $when';
  }

  @override
  String get specialtyCatalogNotReady =>
      'The catalog is still downloading on this device; counts, names and search show up when it\'s done.';

  @override
  String get specialtyIncludeGeneral => 'Include the General profile';

  @override
  String get specialtyIncludeGeneralHint =>
      'Painkillers, antibiotics, stomach protection, CBC and the other common items come first too.';

  @override
  String get specialtyGroupsTitle => 'Medicine groups';

  @override
  String get specialtyGroupsHint =>
      'Medicines in these groups appear under «Your specialty». The number is how many products each group has.';

  @override
  String get specialtyGroupsFilter => 'Filter groups';

  @override
  String specialtySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chosen',
      one: '1 chosen',
      zero: 'None chosen',
    );
    return '$_temp0';
  }

  @override
  String get specialtyRoutesTitle => 'Preferred routes';

  @override
  String get specialtyRoutesHint =>
      'Shown first inside each section, for example syrups and suppositories for children';

  @override
  String get specialtyLabsTitle => 'Recommended lab tests';

  @override
  String get specialtyNoLabs => 'No recommended lab tests yet.';

  @override
  String get specialtyAddLab => 'Search the catalog to add a lab test';

  @override
  String get specialtyRadiologyTitle => 'Radiology';

  @override
  String get specialtyRadiologyHint =>
      'Procedures of these body regions or modalities appear under «Your specialty»';

  @override
  String get specialtyRegions => 'Body regions';

  @override
  String get specialtyModalities => 'Modalities';

  @override
  String get specialtyProcedures => 'Recommended procedures';

  @override
  String get specialtyNoProcedures => 'No recommended procedures yet.';

  @override
  String get specialtyAddProcedure => 'Search the catalog to add a procedure';

  @override
  String specialtyShowAll(int count) {
    return 'Show all ($count)';
  }

  @override
  String get specialtyShowFewer => 'Show fewer';

  @override
  String get specialtyRemove => 'Remove';

  @override
  String get specialtyCopyTitle => 'Copy from another specialty';

  @override
  String specialtyCopyConfirmTitle(String name) {
    return 'Copy the $name profile?';
  }

  @override
  String get specialtyCopyConfirmBody =>
      'Its medicine groups, routes, tests and radiology replace this profile\'s. You can still change them afterwards.';

  @override
  String get specialtyCopy => 'Copy';

  @override
  String specialtyCopied(String name) {
    return 'Copied from $name';
  }

  @override
  String get specialtyPreviewTitle => 'Search preview';

  @override
  String get specialtyPreviewHint =>
      'What a doctor of this specialty sees first, with your unsaved changes';

  @override
  String get specialtyPreviewTests => 'Tests';

  @override
  String get specialtyPreviewDrugsSample => 'Try: ator, omep, panadol';

  @override
  String get specialtyPreviewTestsSample => 'Try: CBC, echo, X-ray';

  @override
  String get specialtyPreviewNothing => 'Nothing matches.';

  @override
  String get regWelcomeTitle => 'Welcome to el3yada';

  @override
  String regWelcomeTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'You have a free trial for $days days.',
      one: 'You have a free trial for 1 day.',
    );
    return '$_temp0';
  }

  @override
  String get regWelcomeBody =>
      'Add your patients and record sessions with no platform fees during the trial.';

  @override
  String get regWelcomeStart => 'Get started';

  @override
  String get adminDoctorTitle => 'Doctor account';

  @override
  String get emailBannerDismiss => 'Hide for now';

  @override
  String get settingsVerifyEmail => 'Verify your email address';

  @override
  String get patientTabFiles => 'Files';

  @override
  String get recordCategoryAll => 'All';

  @override
  String get recordCategoryRadiology => 'Radiology';

  @override
  String get recordCategoryLab => 'Lab tests';

  @override
  String get recordCategoryPrescription => 'Prescriptions';

  @override
  String get recordCategoryOther => 'Other';

  @override
  String recordChip(String name, int count) {
    return '$name $count';
  }

  @override
  String get recordOtherReport => 'Medical report';

  @override
  String get recordOtherReferral => 'Referral';

  @override
  String get recordOtherSickLeave => 'Sick leave';

  @override
  String get recordOtherEcg => 'ECG';

  @override
  String get recordOtherEegEmg => 'EEG / EMG';

  @override
  String get recordOtherEndoscopy => 'Endoscopy';

  @override
  String get recordOtherConsent => 'Consent form';

  @override
  String get recordOtherCustom => 'Another type (type it)';

  @override
  String get recordOtherNone => 'No type';

  @override
  String get recordsEmptyTitle => 'No files yet';

  @override
  String get recordsEmptyBody =>
      'Scan or upload lab results, X-rays and other papers. The patient sees them in their app.';

  @override
  String get recordsEmptyCategory => 'No files in this category';

  @override
  String get recordAddFiles => 'Upload files';

  @override
  String get recordScan => 'Scan';

  @override
  String get recordDropHint => 'Drop the files to upload them';

  @override
  String recordFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String recordPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String sizeBytes(String value) {
    return '$value B';
  }

  @override
  String sizeKb(String value) {
    return '$value KB';
  }

  @override
  String sizeMb(String value) {
    return '$value MB';
  }

  @override
  String get recordUploadTitle => 'Upload files';

  @override
  String get recordScanTitle => 'Scan a document';

  @override
  String get recordEditTitle => 'Edit file details';

  @override
  String get recordFieldCategory => 'Category';

  @override
  String get recordFieldOtherType => 'Document type (optional)';

  @override
  String get recordFieldOtherTypeText => 'Type';

  @override
  String get recordFieldTitle => 'Title (optional)';

  @override
  String recordTitleHint(String title) {
    return 'If left empty: $title';
  }

  @override
  String get recordFieldDate => 'Document date';

  @override
  String get recordFieldNotes => 'Notes (optional)';

  @override
  String get recordFieldSession => 'Link to a visit';

  @override
  String get recordNoSession => 'No visit';

  @override
  String recordSessionOption(String type, String date) {
    return '$type · $date';
  }

  @override
  String get recordCategoryRequired => 'Choose a category';

  @override
  String get recordFilesHeading => 'Files';

  @override
  String get recordDetailsHeading => 'Details';

  @override
  String get recordAddMore => 'Add files';

  @override
  String get recordFromFiles => 'Choose files';

  @override
  String get recordFromCamera => 'Camera';

  @override
  String get recordFromGallery => 'Photos';

  @override
  String get recordSave => 'Save to the patient\'s file';

  @override
  String get recordSaved => 'Saved to the patient\'s file';

  @override
  String get recordUpdated => 'File details saved';

  @override
  String get recordPreparing => 'Making it smaller…';

  @override
  String recordUploading(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String get recordUploaded => 'Uploaded';

  @override
  String get recordUploadFailed => 'Upload failed';

  @override
  String get recordRemoveFile => 'Remove';

  @override
  String recordTooLarge(int mb) {
    return 'File larger than allowed ($mb MB)';
  }

  @override
  String recordSavedSpace(String from, String to) {
    return 'Reduced from $from to $to';
  }

  @override
  String get recordWaitForUploads =>
      'Wait for every file to upload, or remove the ones that failed.';

  @override
  String get recordNeedFiles => 'Add at least one file';

  @override
  String get recordUploadExpired =>
      'This file is no longer waiting. Upload it again.';

  @override
  String get recordErrorInvalidSession =>
      'Choose one of this patient\'s visits';

  @override
  String get recordErrorInvalidDate =>
      'The document date can\'t be in the future';

  @override
  String get recordErrorTooMany => 'One file can hold at most 20 attachments';

  @override
  String get recordNoFilesYet => 'No files added yet';

  @override
  String get recordScanReviewTitle => 'Check the pages';

  @override
  String get recordScanAddPages => 'Scan more pages';

  @override
  String recordScanPage(int number) {
    return 'Page $number';
  }

  @override
  String get recordScanMoveEarlier => 'Move earlier';

  @override
  String get recordScanMoveLater => 'Move later';

  @override
  String get recordScanDeletePage => 'Delete page';

  @override
  String get recordScanMakePdf => 'Make one PDF';

  @override
  String get recordScanBuilding => 'Making the PDF…';

  @override
  String get recordScanUnavailable =>
      'The scanner isn\'t available on this device.';

  @override
  String get recordScanDenied => 'Allow camera access in the settings to scan.';

  @override
  String get recordScanFailed => 'The scan didn\'t work. Try again.';

  @override
  String get recordDetails => 'Details';

  @override
  String get recordOpenWith => 'Open with…';

  @override
  String get recordDownload => 'Download';

  @override
  String get recordShare => 'Share';

  @override
  String get recordEdit => 'Edit details';

  @override
  String get recordDelete => 'Delete';

  @override
  String get recordDeleteTitle => 'Delete this file?';

  @override
  String get recordDeleteBody =>
      'It disappears from the patient\'s file, for you and for the patient.';

  @override
  String get recordDeleted => 'File deleted';

  @override
  String get recordDownloaded => 'File saved';

  @override
  String get recordCantOpen => 'No app on this device opens this type of file.';

  @override
  String get recordNoPreview => 'This type of file opens in another app.';

  @override
  String get recordPdfFailed =>
      'This PDF couldn\'t be shown here. Open it with another app.';

  @override
  String recordAttachmentOf(int index, int count) {
    return '$index of $count';
  }

  @override
  String recordAdded(String date) {
    return 'Added $date';
  }

  @override
  String get recordSize => 'Size';

  @override
  String get recordSourceScan => 'Scanned';

  @override
  String get recordSourceUpload => 'Uploaded';

  @override
  String get recordSourceChat => 'From the chat';

  @override
  String get recordVisit => 'Visit';

  @override
  String get recordPrevious => 'Previous file';

  @override
  String get recordNext => 'Next file';

  @override
  String get recordLoadingFile => 'Opening the file…';

  @override
  String get activityRecordCreated => 'Added a file to the patient\'s record';

  @override
  String get activityRecordUpdated => 'Edited a file\'s details';

  @override
  String get activityRecordDeleted => 'Deleted a file';

  @override
  String get activityActionRecordCreated => 'File added';

  @override
  String get activityActionRecordUpdated => 'File edited';

  @override
  String get activityActionRecordDeleted => 'File deleted';

  @override
  String get patientTabPrescriptions => 'Prescriptions';

  @override
  String get rxKindMedication => 'Medication prescription';

  @override
  String get rxKindInvestigations => 'Investigations request';

  @override
  String get rxKindMedicationHint => 'Medicines with dose, timing and duration';

  @override
  String get rxKindInvestigationsHint => 'Lab tests and radiology';

  @override
  String get rxNewTitle => 'New prescription';

  @override
  String get rxNewMedication => 'New prescription';

  @override
  String get rxNewInvestigations => 'New request';

  @override
  String get rxStatusDraft => 'Draft';

  @override
  String get rxStatusReadyForReview => 'Ready for review';

  @override
  String get rxStatusSent => 'Sent';

  @override
  String get rxStatusCancelled => 'Cancelled';

  @override
  String get rxNoItems => 'No items yet';

  @override
  String rxItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String rxPreparedBy(String name) {
    return 'Prepared by $name';
  }

  @override
  String get rxListSeparator => ', ';

  @override
  String get rxSessionCardTitle => 'Prescriptions and requests';

  @override
  String get rxSessionEmpty => 'No prescription for this visit yet.';

  @override
  String get rxEmptyTitle => 'No prescriptions yet';

  @override
  String get rxEmptyBody =>
      'Write a medication prescription or a lab and radiology request from one of today’s visits.';

  @override
  String get rxPickSession => 'Which visit is this for?';

  @override
  String get rxNoSessionTodayTitle => 'No visit today';

  @override
  String get rxNoSessionTodayBody =>
      'A prescription belongs to a visit. Record today’s visit first, then write the prescription from it.';

  @override
  String get rxDiagnosis => 'Diagnosis';

  @override
  String get rxMedicines => 'Medicines';

  @override
  String get rxTests => 'Tests';

  @override
  String get rxNoMedicinesYet => 'Add the first medicine.';

  @override
  String get rxNoTestsYet => 'Add the first test.';

  @override
  String get rxAddMedicine => 'Add medicine';

  @override
  String get rxEditMedicine => 'Edit medicine';

  @override
  String get rxAddTest => 'Add test';

  @override
  String get rxEditTest => 'Edit test';

  @override
  String get rxAddToPrescription => 'Add';

  @override
  String get rxAdvice => 'General advice';

  @override
  String get rxRequestNotes => 'Notes';

  @override
  String get rxFollowUp => 'Follow-up date';

  @override
  String get rxResultsOn => 'Bring the results on';

  @override
  String get rxClearDate => 'Clear the date';

  @override
  String get rxSaveDraft => 'Save draft';

  @override
  String get rxDraftSaved => 'Saved';

  @override
  String get rxPreview => 'Preview';

  @override
  String get rxSubmitForReview => 'Send to the doctor for review';

  @override
  String get rxSubmittedForReview => 'Sent to the doctor for review.';

  @override
  String get rxMore => 'More';

  @override
  String get rxSaveAsTemplate => 'Save as template';

  @override
  String get rxDeleteDraft => 'Delete draft';

  @override
  String get rxDeleteDraftTitle => 'Delete this draft?';

  @override
  String get rxDeleteDraftBody =>
      'The patient never saw it. This can’t be undone.';

  @override
  String get rxDraftDeleted => 'Draft deleted.';

  @override
  String get rxItemRemoved => 'Item removed.';

  @override
  String get rxUndo => 'Undo';

  @override
  String get rxRemoveItem => 'Remove';

  @override
  String get rxDragToReorder => 'Drag to reorder';

  @override
  String get rxFromTemplate => 'From template';

  @override
  String get rxNoTemplates => 'No templates yet';

  @override
  String get rxNoTemplatesBody =>
      'Save a prescription as a template from its “More” menu to reuse it.';

  @override
  String get rxTemplateName => 'Template name';

  @override
  String get rxTemplateSaved => 'Template saved.';

  @override
  String get rxErrorEmpty => 'Add at least one item.';

  @override
  String get rxErrorNotEditable =>
      'This prescription was already sent or cancelled, so it can’t be changed.';

  @override
  String get rxErrorNotSent => 'Only a sent prescription can be cancelled.';

  @override
  String get rxErrorInvalidCopySource =>
      'A new copy can only be made from a sent or cancelled prescription of the same patient.';

  @override
  String get rxErrorInvalidSession => 'Pick one of this patient’s visits.';

  @override
  String get rxErrorInvalidDate => 'Pick a valid date.';

  @override
  String get rxErrorTooMany => 'Too many items.';

  @override
  String get rxSearchMedicine =>
      'Search medicines (trade name or active ingredient)';

  @override
  String get rxSearchLab => 'Search lab tests';

  @override
  String get rxSearchRadiology => 'Search radiology';

  @override
  String get rxMySpecialtyOnly => 'My specialty only';

  @override
  String get rxSectionUsedBefore => 'Used before';

  @override
  String get rxSectionMySpecialty => 'Your specialty';

  @override
  String get rxSectionOthers => 'From other specialties';

  @override
  String get rxCatalogNotReady =>
      'The catalog is still downloading: only your own history is searched. You can type any name.';

  @override
  String rxUseTyped(String text) {
    return 'Use “$text”';
  }

  @override
  String get rxNoMatches => 'Nothing matches in the catalog.';

  @override
  String get rxDrugName => 'Medicine name';

  @override
  String get rxActiveIngredient => 'Active ingredient';

  @override
  String get rxStrength => 'Strength';

  @override
  String get rxForm => 'Form';

  @override
  String get rxFormOtherText => 'Form (type it)';

  @override
  String get rxDose => 'Dose';

  @override
  String get rxDoseHint => '1 tablet';

  @override
  String get rxFrequency => 'How often';

  @override
  String get rxFrequencyHint => 'Every 8 hours';

  @override
  String get rxTiming => 'Timing';

  @override
  String get rxTimingBeforeFood => 'Before food';

  @override
  String get rxTimingAfterFood => 'After food';

  @override
  String get rxTimingWithFood => 'With food';

  @override
  String get rxTimingUnspecified => 'Not specified';

  @override
  String get rxDuration => 'Duration';

  @override
  String get rxDurationCount => 'Number';

  @override
  String get rxDurationUnitDays => 'Days';

  @override
  String get rxDurationUnitWeeks => 'Weeks';

  @override
  String get rxDurationContinuous => 'Continuous';

  @override
  String rxDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String rxDurationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String get rxInstructions => 'Instructions';

  @override
  String get rxFormTablet => 'Tablet';

  @override
  String get rxFormCapsule => 'Capsule';

  @override
  String get rxFormSyrup => 'Syrup';

  @override
  String get rxFormInjection => 'Injection';

  @override
  String get rxFormCream => 'Cream / ointment';

  @override
  String get rxFormDrops => 'Drops';

  @override
  String get rxFormInhaler => 'Inhaler';

  @override
  String get rxFormSuppository => 'Suppository';

  @override
  String get rxFormSachet => 'Sachet';

  @override
  String get rxFormOther => 'Other';

  @override
  String get rxCategoryLab => 'Lab test';

  @override
  String get rxCategoryRadiology => 'Radiology';

  @override
  String get rxTestName => 'Test name';

  @override
  String get rxTestNotes => 'Notes';

  @override
  String get rxTestNotesHint => 'Fasting 12 hours';

  @override
  String get rxEdit => 'Edit';

  @override
  String get rxSend => 'Send to patient';

  @override
  String get rxSendTitle => 'Send to the patient?';

  @override
  String get rxSendBody =>
      'The patient gets it in the app at once. A sent prescription can’t be changed: to correct it, cancel it and issue a new copy.';

  @override
  String get rxSendAndPrint => 'Send and print';

  @override
  String get rxSendAndPrintTitle => 'Send and print?';

  @override
  String get rxSendAndPrintBody =>
      'Printing sends it to the patient at the same moment, so the paper and the app always match.';

  @override
  String get rxSent => 'Sent to the patient.';

  @override
  String get rxPrint => 'Print';

  @override
  String get rxPrintAll => 'Print all';

  @override
  String get rxShare => 'Share PDF';

  @override
  String get rxPrintFailed => 'Printing didn’t work. Try again.';

  @override
  String get rxCancelAction => 'Cancel prescription';

  @override
  String get rxCancelTitle => 'Cancel this prescription?';

  @override
  String get rxCancelBody =>
      'The patient sees it struck through, with your reason. You can then issue a new copy.';

  @override
  String get rxCancelReason => 'Reason';

  @override
  String get rxCancelConfirm => 'Cancel prescription';

  @override
  String get rxCancelled => 'Prescription cancelled.';

  @override
  String get rxCancelledNotice => 'Cancelled. It can’t be printed.';

  @override
  String rxCancelledReason(String reason) {
    return 'Cancelled: $reason';
  }

  @override
  String get rxNewCopy => 'Issue new copy';

  @override
  String get rxPreviewFailed => 'The preview couldn’t be built.';

  @override
  String get rxSettingsTitle => 'Prescription header and printing';

  @override
  String get rxSettingsSubtitle =>
      'How your prescriptions look on paper and in the patient’s app.';

  @override
  String get rxSettingsTileHint =>
      'Logo, signature, colour, language and paper';

  @override
  String get rxSettingsHeaderGroup => 'Header';

  @override
  String get rxSettingsNamesHint =>
      'Your names, titles and degrees come from your profile; the branches in the footer come from Branches.';

  @override
  String get rxLogo => 'Clinic logo';

  @override
  String get rxSignature => 'Signature';

  @override
  String get rxUploadImage => 'Upload';

  @override
  String get rxReplaceImage => 'Replace';

  @override
  String get rxRemoveImage => 'Remove';

  @override
  String get rxImagesGroup => 'Images';

  @override
  String get rxSettingsColor => 'Clinic colour';

  @override
  String get rxSettingsHex => 'Colour code';

  @override
  String get rxSettingsFooter => 'Footer text';

  @override
  String get rxSettingsFooterHint => 'Optional, for example your working days.';

  @override
  String get rxSettingsPrintGroup => 'Language and paper';

  @override
  String get rxSettingsLanguage => 'Prescription language';

  @override
  String get rxSettingsArabic => 'العربية';

  @override
  String get rxSettingsEnglish => 'English';

  @override
  String get rxSettingsPaper => 'Paper';

  @override
  String get rxPaperA5 => 'A5';

  @override
  String get rxPaperA4 => 'A4';

  @override
  String get rxPaperCustom => 'Custom';

  @override
  String get rxPaperWidth => 'Width';

  @override
  String get rxPaperHeight => 'Height';

  @override
  String get rxMm => 'mm';

  @override
  String get rxPreprinted => 'Pre-printed paper';

  @override
  String get rxPreprintedHint =>
      'For your own letterhead: the header and footer aren’t printed, and the text starts at the top margin.';

  @override
  String get rxMarginTop => 'Top margin';

  @override
  String get rxMarginBottom => 'Bottom margin';

  @override
  String get rxSettingsPreview => 'Live preview';

  @override
  String get rxTestPrint => 'Test print';

  @override
  String get rxSettingsSaved => 'Print settings saved.';

  @override
  String get rxSamplePatient => 'Sample patient';

  @override
  String get rxSampleDiagnosis => 'Acute tonsillitis';

  @override
  String get rxSampleAdvice => 'Rest and warm fluids.';

  @override
  String get rxSampleDose => '1 tablet';

  @override
  String get rxSampleFrequency => 'Every 12 hours';

  @override
  String get rxSampleWhenNeeded => 'When needed';

  @override
  String get rxTemplatesTitle => 'Templates and favourites';

  @override
  String get rxTemplatesSubtitle => 'Reuse prescriptions you write often.';

  @override
  String get rxTemplatesTileHint =>
      'Saved prescriptions and frequently used items';

  @override
  String get rxTemplatesGroup => 'Templates';

  @override
  String get rxRenameTemplate => 'Rename';

  @override
  String get rxDeleteTemplate => 'Delete template';

  @override
  String get rxDeleteTemplateTitle => 'Delete this template?';

  @override
  String rxDeleteTemplateBody(String name) {
    return '“$name” will be removed. Prescriptions made from it stay as they are.';
  }

  @override
  String get rxTemplateDeleted => 'Template deleted.';

  @override
  String get rxFrequentGroup => 'Frequently used';

  @override
  String get rxFrequentHint =>
      'They come first when you search. Remove one to stop suggesting it.';

  @override
  String get rxNoHistory => 'Items you prescribe will appear here.';

  @override
  String rxUsedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used $count times',
      one: 'Used once',
    );
    return '$_temp0';
  }

  @override
  String get rxRemoveFromHistory => 'Remove from suggestions';

  @override
  String rxHistoryItemRemoved(String name) {
    return '“$name” removed from suggestions.';
  }

  @override
  String rxPdfTitle(String kind) {
    return 'el3yada $kind';
  }

  @override
  String get rxPdfDiagnosis => 'Diagnosis:';

  @override
  String get rxPdfInstructions => 'Instructions:';

  @override
  String get rxPdfNotes => 'Notes:';

  @override
  String rxPdfFollowUp(String date) {
    return 'Follow-up: $date';
  }

  @override
  String rxPdfResultsOn(String date) {
    return 'Bring the results on: $date';
  }

  @override
  String get rxPdfTestsIntro => 'Please do the following tests:';

  @override
  String get rxPdfLabGroup => 'Lab tests';

  @override
  String get rxPdfRadiologyGroup => 'Radiology';

  @override
  String get rxPdfPatient => 'Patient';

  @override
  String get rxPdfDate => 'Date';

  @override
  String get rxPdfAge => 'Age';

  @override
  String rxPdfAgeValue(int years) {
    return '$years y';
  }

  @override
  String get rxPdfFile => 'File no.';

  @override
  String get rxPdfVisit => 'Visit';

  @override
  String get rxPdfExamination => 'Examination';

  @override
  String get rxPdfConsultation => 'Consultation';

  @override
  String get rxPdfSignature => 'Signature';

  @override
  String get rxPdfScan => 'Scan the code';

  @override
  String rxPdfPage(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get rxPdfTel => 'Tel';

  @override
  String get rxPdfWhatsapp => 'WhatsApp';

  @override
  String activityPrescriptionDraftCreated(String kind) {
    return 'started a draft: $kind';
  }

  @override
  String activityPrescriptionCopied(String kind) {
    return 'issued a new copy: $kind';
  }

  @override
  String activityPrescriptionDraftUpdated(String kind) {
    return 'edited a draft: $kind';
  }

  @override
  String activityPrescriptionDraftDeleted(String kind) {
    return 'deleted a draft: $kind';
  }

  @override
  String activityPrescriptionSubmitted(String kind) {
    return 'sent a draft for review: $kind';
  }

  @override
  String activityPrescriptionSent(String kind) {
    return 'sent to the patient: $kind';
  }

  @override
  String activityPrescriptionCancelled(String kind) {
    return 'cancelled: $kind';
  }

  @override
  String activityRxItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get activityRxSettingsUpdated => 'changed the print settings';

  @override
  String get activityRxLogoUpdated => 'changed the prescription logo';

  @override
  String get activityRxLogoRemoved => 'removed the prescription logo';

  @override
  String get activityRxSignatureUpdated => 'changed the signature';

  @override
  String get activityRxSignatureRemoved => 'removed the signature';

  @override
  String get activityActionPrescriptionDraftCreated => 'Draft started';

  @override
  String get activityActionPrescriptionDraftUpdated => 'Draft edited';

  @override
  String get activityActionPrescriptionDraftDeleted => 'Draft deleted';

  @override
  String get activityActionPrescriptionSubmitted => 'Sent for review';

  @override
  String get activityActionPrescriptionSent => 'Prescription sent';

  @override
  String get activityActionPrescriptionCancelled => 'Prescription cancelled';

  @override
  String get activityActionRxSettingsUpdated => 'Print settings';

  @override
  String get activityActionRxBrandingUpdated => 'Logo or signature';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get seeAll => 'See all';

  @override
  String get errorNotFound => 'This item is not available.';

  @override
  String get errorForbidden => 'You don\'t have access to this.';

  @override
  String get errorDeletionAlreadyRequested =>
      'You already have a deletion request under review.';

  @override
  String get couldNotOpen => 'Couldn\'t open it on this device';

  @override
  String get newBadge => 'New';

  @override
  String get allDoctors => 'All';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String homeNewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new items in your file',
      one: '1 new item in your file',
    );
    return '$_temp0';
  }

  @override
  String get homeLatestVisit => 'Latest visit';

  @override
  String get homeLatestPrescription => 'Latest prescription';

  @override
  String get homeNextFollowUp => 'Next follow-up';

  @override
  String followUpWith(String date, String doctor) {
    return '$date with $doctor';
  }

  @override
  String get homeRecentFiles => 'Recent files';

  @override
  String get homeEmpty =>
      'Your medical file is empty for now. Visits, prescriptions and files your doctor adds will appear here.';

  @override
  String get myDoctorsTitle => 'My doctors';

  @override
  String get myDoctorTitle => 'My doctor';

  @override
  String get noDoctors => 'You are not linked to a doctor yet.';

  @override
  String get medicalProfileTitle => 'Medical profile';

  @override
  String fileNumber(int number) {
    return 'File no. $number';
  }

  @override
  String get thisDoctorsRecords => 'This doctor\'s records';

  @override
  String get branchesTitle => 'Branches';

  @override
  String get noBranches => 'No branch details yet. Contact the clinic.';

  @override
  String get mainBranch => 'Main';

  @override
  String get branchTemporarilyClosed => 'Temporarily closed';

  @override
  String reopensOn(String date) {
    return 'Reopens on $date';
  }

  @override
  String get openInMaps => 'Open in maps';

  @override
  String get call => 'Call';

  @override
  String get whatsApp => 'WhatsApp';

  @override
  String get phoneReception => 'Reception';

  @override
  String get phoneMobile => 'Mobile';

  @override
  String get phoneLandline => 'Landline';

  @override
  String get workingHours => 'Working hours';

  @override
  String get workingHoursNotSet => 'Ask the clinic for its hours.';

  @override
  String get closedDay => 'Closed';

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get visitPrices => 'Visit prices';

  @override
  String get priceAskClinic => 'Ask the clinic';

  @override
  String moneyEgp(String amount) {
    return '$amount EGP';
  }

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentInstapay => 'InstaPay';

  @override
  String get paymentWallet => 'Mobile wallet';

  @override
  String get amenityElevator => 'Elevator';

  @override
  String get amenityParking => 'Parking';

  @override
  String get amenityWheelchair => 'Wheelchair access';

  @override
  String get amenityKidsArea => 'Kids\' area';

  @override
  String get tabVisits => 'Visits';

  @override
  String get tabPrescriptions => 'Prescriptions';

  @override
  String get tabFiles => 'Files';

  @override
  String get noVisits => 'No visits yet.';

  @override
  String get noPrescriptions => 'No prescriptions yet.';

  @override
  String get noFiles => 'No files in this category.';

  @override
  String get visitTypeExamination => 'Examination';

  @override
  String get visitTypeConsultation => 'Consultation';

  @override
  String get visitDetailsTitle => 'Visit details';

  @override
  String get diagnosis => 'Diagnosis';

  @override
  String get chiefComplaint => 'Chief complaint';

  @override
  String get findings => 'Examination findings';

  @override
  String get vitals => 'Vitals';

  @override
  String get vitalBloodPressure => 'Blood pressure';

  @override
  String get vitalPulse => 'Pulse';

  @override
  String get vitalTemperature => 'Temperature';

  @override
  String get vitalWeight => 'Weight';

  @override
  String get vitalHeight => 'Height';

  @override
  String get vitalGlucose => 'Blood sugar';

  @override
  String get doctorNotesForYou => 'Your doctor\'s notes';

  @override
  String get followUpDate => 'Follow-up date';

  @override
  String get rxTabMedications => 'Medications';

  @override
  String get rxTabInvestigations => 'Lab & Radiology';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get rxCancelledTitle => 'This prescription was cancelled';

  @override
  String reasonValue(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get rxOpenNewCopy => 'Open the new copy';

  @override
  String rxSentOn(String date) {
    return 'Sent on $date';
  }

  @override
  String get viewPdf => 'View PDF';

  @override
  String get shareOrSave => 'Share or save';

  @override
  String doseAmountForm(String dose, String form) {
    return '$dose $form';
  }

  @override
  String get formTablet => 'tablet';

  @override
  String get formCapsule => 'capsule';

  @override
  String get formSyrup => 'syrup';

  @override
  String get formInjection => 'injection';

  @override
  String get formCream => 'cream / ointment';

  @override
  String get formDrops => 'drops';

  @override
  String get formInhaler => 'inhaler';

  @override
  String get formSuppository => 'suppository';

  @override
  String get formSachet => 'sachet';

  @override
  String get formOther => 'other';

  @override
  String get timingBeforeFood => 'Before food';

  @override
  String get timingAfterFood => 'After food';

  @override
  String get timingWithFood => 'With food';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'for $count days',
      one: 'for 1 day',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'for $count weeks',
      one: 'for 1 week',
    );
    return '$_temp0';
  }

  @override
  String get durationContinuous => 'Continuous';

  @override
  String get investigationLab => 'Lab test';

  @override
  String get investigationRadiology => 'Radiology';

  @override
  String get fileCategoryPrescription => 'Prescriptions';

  @override
  String get fileCategoryLab => 'Lab tests';

  @override
  String get fileCategoryRadiology => 'Radiology';

  @override
  String get fileCategoryOther => 'Other';

  @override
  String get otherTypeReport => 'Medical report';

  @override
  String get otherTypeReferral => 'Referral';

  @override
  String get otherTypeSickLeave => 'Sick leave';

  @override
  String get otherTypeEcg => 'ECG';

  @override
  String get otherTypeEegEmg => 'EEG / EMG';

  @override
  String get otherTypeEndoscopy => 'Endoscopy';

  @override
  String get otherTypeConsent => 'Consent form';

  @override
  String get fileDetails => 'File details';

  @override
  String get fileTitle => 'Title';

  @override
  String get fileCategory => 'Category';

  @override
  String get documentDate => 'Document date';

  @override
  String get doctor => 'Doctor';

  @override
  String get notes => 'Notes';

  @override
  String get noAttachments => 'This file has no attachments.';

  @override
  String cannotPreview(String fileName) {
    return '$fileName can\'t be previewed here. Use Share to open it with another app.';
  }

  @override
  String pageOf(int current, int total) {
    return '$current of $total';
  }

  @override
  String get personalInfo => 'Personal information';

  @override
  String get fullName => 'Full name';

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get gender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get age => 'Age';

  @override
  String ageYears(int years) {
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
  String get bloodType => 'Blood type';

  @override
  String get allergies => 'Allergies';

  @override
  String get chronicDiseases => 'Chronic diseases';

  @override
  String get currentMedications => 'Current medications';

  @override
  String get surgeries => 'Past surgeries';

  @override
  String get familyHistory => 'Family history';

  @override
  String get medicalProfileEmpty => 'Nothing recorded yet.';

  @override
  String get medicalProfileReadOnly =>
      'To update this information, contact your doctor.';

  @override
  String get settingsGeneral => 'General';

  @override
  String get language => 'Language';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notifyChat => 'Chat messages';

  @override
  String get notifyReminders => 'Appointment reminders';

  @override
  String get notifyShowPreview => 'Show message text in notifications';

  @override
  String get notifyShowPreviewHint =>
      'Off keeps your messages private on the lock screen.';

  @override
  String get accountTitle => 'Account';

  @override
  String get requestAccountDeletion => 'Request account deletion';

  @override
  String get deletionConfirmBody =>
      'We\'ll send your request to the el3yada team. Once it is approved you won\'t be able to sign in. Your doctors keep the medical records they are required to keep.';

  @override
  String get deletionReasonLabel => 'Reason (optional)';

  @override
  String get deletionConfirmButton => 'Send request';

  @override
  String get deletionRequestSent =>
      'Your request was sent. We\'ll review it soon.';

  @override
  String get deletionPendingTitle => 'Deletion request under review';

  @override
  String deletionPendingBody(String date) {
    return 'Sent on $date';
  }

  @override
  String deletionRejected(String note) {
    return 'Your last request was declined: $note';
  }

  @override
  String get termsGateTitle => 'Before you start';

  @override
  String get termsGateBody =>
      'el3yada keeps your medical file safe and shares it only with your doctors. Please read and accept the Terms of Use and Privacy Policy to continue.';

  @override
  String get termsGateCheckbox =>
      'I have read and accept the Terms of Use and Privacy Policy';

  @override
  String get termsGateContinue => 'Continue';

  @override
  String get navDeletionRequests => 'Deletion requests';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get noDeletionRequests => 'No requests here.';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get approveDeletionTitle => 'Approve deletion?';

  @override
  String get approveDeletionBody =>
      'The patient will be signed out everywhere and can\'t sign in again. Medical records stay with their doctors.';

  @override
  String get rejectDeletionTitle => 'Reject the request';

  @override
  String get reasonRequiredLabel => 'Reason (the patient sees it)';

  @override
  String get errorInvalidPhone => 'Invalid mobile number';

  @override
  String get search => 'Search';

  @override
  String get accountsSupportHint =>
      'Search by mobile number only. Patient and assistant accounts are shown, never medical data.';

  @override
  String get noAccountsFound => 'No account uses this number.';

  @override
  String get accountDeleted => 'Account deleted at the patient\'s request';

  @override
  String linkedDoctors(String names) {
    return 'Doctors: $names';
  }

  @override
  String createdOn(String date) {
    return 'Created on $date';
  }

  @override
  String assistantOf(String doctor) {
    return 'Assistant of $doctor';
  }

  @override
  String lastActive(String time) {
    return 'Last active $time';
  }

  @override
  String get loginEnabled => 'Login enabled';

  @override
  String get loginDisabled => 'Login disabled';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get searchChats => 'Search by name or phone';

  @override
  String get noChats => 'No conversations yet.';

  @override
  String get chatImage => 'Photo';

  @override
  String get chatFile => 'File';

  @override
  String get chatNoMessages => 'No messages yet';

  @override
  String get chatDoctorUnavailable => 'The doctor isn\'t available right now.';

  @override
  String get chatSuspended =>
      'Sending is paused while the service is suspended.';

  @override
  String get fileTooLarge => 'The file is larger than allowed.';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatGallery => 'Gallery';

  @override
  String get chatFileOption => 'File';

  @override
  String get saveToPatientFile => 'Save to patient file';

  @override
  String get savedToPatientFile => 'Saved to the patient\'s file';

  @override
  String get chatStart => 'Start the conversation.';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatTypeMessage => 'Type a message';

  @override
  String get chatSend => 'Send';

  @override
  String clinicAssistant(String name) {
    return 'Clinic assistant — $name';
  }

  @override
  String get chatRead => 'Read';

  @override
  String get chatDelivered => 'Delivered';

  @override
  String get chooseCategory => 'Choose the category';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get apStatusPending => 'Waiting to confirm';

  @override
  String get apStatusConfirmed => 'Confirmed';

  @override
  String get apStatusCheckedIn => 'Checked in';

  @override
  String get apStatusWithDoctor => 'With the doctor';

  @override
  String get apStatusCompleted => 'Completed';

  @override
  String get apStatusCancelled => 'Cancelled';

  @override
  String get apStatusNoShow => 'No-show';

  @override
  String get apStatusRejected => 'Rejected';

  @override
  String get stageExpected => 'Expected';

  @override
  String get stageWaiting => 'Waiting';

  @override
  String get stageWithDoctor => 'With the doctor';

  @override
  String get stageDone => 'Done';

  @override
  String get stageMissed => 'Missed';

  @override
  String queueNumber(int number) {
    return 'No. $number';
  }

  @override
  String get errSlotTaken => 'This time was just booked. Choose another one.';

  @override
  String get errPeriodFull => 'This period is fully booked.';

  @override
  String get errOutsideHours => 'This time is outside working hours.';

  @override
  String get errBranchClosed => 'The branch is closed at this time.';

  @override
  String get errTooFarAhead =>
      'Booking is open only for the coming days set by the clinic.';

  @override
  String get errTooSoon => 'This time is too soon to book.';

  @override
  String get errSameDayOff =>
      'Same-day booking isn\'t available. Please call the clinic.';

  @override
  String get errUpcomingLimit =>
      'You already have an upcoming booking with this doctor.';

  @override
  String get errSelfBookingBlocked => 'Please call the clinic to book.';

  @override
  String get errConsultationRequiresExam =>
      'A consultation isn\'t possible now. Book an examination.';

  @override
  String get errCancelWindowPassed =>
      'It\'s too late to change this booking. Please call the clinic.';

  @override
  String get errMaxReschedules =>
      'You\'ve reached the maximum number of changes for this booking.';

  @override
  String get errBookingUnavailable =>
      'Online booking isn\'t available right now. Please call the clinic.';

  @override
  String get errAlreadyHandled =>
      'Someone else already updated this booking. The board was refreshed.';

  @override
  String get errGuestNeedsAccount =>
      'Create the patient\'s account first, then link the booking.';

  @override
  String get boardOffline => 'Offline: the data may be out of date';

  @override
  String get book => 'Book';

  @override
  String get walkIn => 'Walk-in';

  @override
  String get more => 'More';

  @override
  String get doctorDelayed => 'Doctor delayed';

  @override
  String minutesCount(int minutes) {
    return '$minutes minutes';
  }

  @override
  String patientsNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients notified',
      one: '1 patient notified',
    );
    return '$_temp0';
  }

  @override
  String get cancelRestOfDay => 'Cancel the rest of today';

  @override
  String get cancelRestOfDayBody =>
      'Every booking that hasn\'t arrived yet at this branch today will be cancelled, and patients will be told to book again.';

  @override
  String get confirm => 'Confirm';

  @override
  String bookingsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings cancelled',
      one: '1 booking cancelled',
    );
    return '$_temp0';
  }

  @override
  String get nowServing => 'Now serving';

  @override
  String countBooked(int count) {
    return 'Booked: $count';
  }

  @override
  String countArrived(int count) {
    return 'Arrived: $count';
  }

  @override
  String delayedBy(int minutes) {
    return 'Delayed $minutes min';
  }

  @override
  String get boardEmptyStage => 'Nobody here';

  @override
  String get confirmBooking => 'Confirm';

  @override
  String get checkIn => 'Check in';

  @override
  String get callIn => 'Call in';

  @override
  String get undoNoShow => 'Undo no-show';

  @override
  String get newPatient => 'New patient';

  @override
  String lastVisitOn(String date, String type) {
    return 'Last visit: $date — $type';
  }

  @override
  String get priority => 'Priority';

  @override
  String get late => 'Late';

  @override
  String get consultationNotAllowed => 'Consultation not allowed';

  @override
  String get guest => 'Guest';

  @override
  String waitedMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get markNoShow => 'Mark no-show';

  @override
  String get leftWithoutSeen => 'Left without being seen';

  @override
  String get sendBack => 'Back to waiting';

  @override
  String get visitsCount => 'Visits';

  @override
  String get lastVisit => 'Last visit';

  @override
  String get recentAmounts => 'Recent amounts';

  @override
  String get upcomingAndNoShows => 'Upcoming bookings · no-shows';

  @override
  String get bookingReason => 'Reason for booking';

  @override
  String get staffNotes => 'Staff notes';

  @override
  String get openBooking => 'Open booking';

  @override
  String get searchPatient => 'Name, phone or file number';

  @override
  String get hasUpcoming => 'Has an upcoming booking';

  @override
  String get chooseVisitType => 'Choose the visit type';

  @override
  String get guestNameAndPhone =>
      'Enter the name (two words at least) and the mobile number';

  @override
  String get existingPatient => 'Existing patient';

  @override
  String get visitType => 'Visit type';

  @override
  String get firstVisitIsExam => 'The first visit is always an examination.';

  @override
  String consultationCount(int count, int max) {
    return 'Consultation $count of $max since the last examination';
  }

  @override
  String get noOpenDays => 'No open days in this range.';

  @override
  String placesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places left',
      one: '1 place left',
      zero: 'Full',
    );
    return '$_temp0';
  }

  @override
  String estimatedTime(String time) {
    return 'About $time';
  }

  @override
  String get tabUpcoming => 'Upcoming';

  @override
  String get tabPast => 'Past';

  @override
  String get tabCancelled => 'Cancelled';

  @override
  String get noAppointments => 'No bookings here.';

  @override
  String get cancelBooking => 'Cancel booking';

  @override
  String get back => 'Back';

  @override
  String get bookingCancelled => 'Your booking was cancelled.';

  @override
  String get appointmentDetails => 'Booking details';

  @override
  String nowServingYourNumber(int now, int mine) {
    return 'Now serving $now — your number $mine';
  }

  @override
  String get waitingForClinic => 'Waiting for the clinic to confirm';

  @override
  String get reschedule => 'Change time';

  @override
  String get callClinic => 'Call the clinic';

  @override
  String get openVisit => 'Open the visit';

  @override
  String get history => 'History';

  @override
  String get byYou => 'by you';

  @override
  String get bySystem => 'automatically';

  @override
  String get byClinic => 'by the clinic';

  @override
  String get historyCreated => 'Booked';

  @override
  String get historyRescheduled => 'Rescheduled';

  @override
  String get historyExpired => 'Not confirmed in time';

  @override
  String get bookAppointment => 'Book an appointment';

  @override
  String get chooseDoctor => 'Choose the doctor';

  @override
  String get chooseBranch => 'Choose the branch';

  @override
  String get chooseDateAndTime => 'Choose the day and time';

  @override
  String get bookingReasonOptional => 'Reason (optional)';

  @override
  String cancelPolicy(int hours) {
    return 'You can cancel or change up to $hours hours before the appointment.';
  }

  @override
  String get confirmBookingButton => 'Confirm booking';

  @override
  String get bookingConfirmed => 'Booking confirmed';

  @override
  String get bookingMoved => 'Your booking was moved';

  @override
  String get previousDay => 'Previous day';

  @override
  String get nextDay => 'Next day';

  @override
  String get searchBookings => 'Search bookings';

  @override
  String get reasonLabel => 'Reason';

  @override
  String get whenLabel => 'When';

  @override
  String get bookedBy => 'Booked by';

  @override
  String get overbooked => 'Overbooked';

  @override
  String get checkedInNoSession => 'Checked in, but no session was recorded';

  @override
  String get sourceApp => 'patient app';

  @override
  String get sourceStaff => 'clinic';

  @override
  String get quickGuest => 'Quick guest';

  @override
  String get overbookTitle => 'This place is full';

  @override
  String get overbookBody =>
      'The period or time is already full. Book anyway as an extra?';

  @override
  String get upcomingWarningBody =>
      'This patient already has an upcoming booking. You can change that one instead, or book another.';

  @override
  String get bookAnyway => 'Book anyway';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get next7Days => 'Next 7 days';

  @override
  String get guestsOnly => 'Guests only';

  @override
  String get scheduleConflictsLeft => 'Some bookings still need a decision.';

  @override
  String get scheduleSaved => 'Schedule saved';

  @override
  String get save => 'Save';

  @override
  String get specialDates => 'Special dates';

  @override
  String get bookingSettings => 'Booking settings';

  @override
  String get copySaturdayToAll => 'Copy Saturday to all days';

  @override
  String get addPeriod => 'Add period';

  @override
  String get closeADay => 'Close a day';

  @override
  String get remove => 'Remove';

  @override
  String get closures => 'Closures and vacations';

  @override
  String get addClosure => 'Add closure';

  @override
  String get closureScope => 'Close which branches?';

  @override
  String get thisBranch => 'This branch';

  @override
  String get allBranches => 'All branches';

  @override
  String get bookingMode => 'Booking mode';

  @override
  String get modeQueue => 'Queue numbers';

  @override
  String get modeTimed => 'Timed slots';

  @override
  String get slotMinutes => 'Slot length (minutes)';

  @override
  String get defaultCapacity => 'Places per period';

  @override
  String get avgVisitMinutes => 'Average visit (minutes)';

  @override
  String get selfBooking => 'Patients can book from the app';

  @override
  String get autoConfirm => 'Confirm app bookings automatically';

  @override
  String get sameDayBooking => 'Same-day booking';

  @override
  String get staffOverbooking => 'Staff can overbook after a warning';

  @override
  String get windowDays => 'Booking window (days)';

  @override
  String get minNoticeMinutes => 'Minimum notice (minutes)';

  @override
  String get freeCancelMinutes => 'Free cancel until (minutes before)';

  @override
  String get maxReschedules => 'Changes per booking';

  @override
  String get maxUpcoming => 'Upcoming bookings per patient';

  @override
  String get nextDayShort => '(+1 day)';

  @override
  String get capacity => 'Places';

  @override
  String affectedBookings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings are affected',
      one: '1 booking is affected',
    );
    return '$_temp0';
  }

  @override
  String get keepAll => 'Keep all';

  @override
  String get cancelAll => 'Cancel all';

  @override
  String get keep => 'Keep';

  @override
  String get applyChanges => 'Apply changes';

  @override
  String get billTitle => 'Billing';

  @override
  String get billSubtitle => 'Your platform invoices and payments';

  @override
  String get billInvoices => 'Invoices';

  @override
  String get billEmptyTitle => 'No invoices yet';

  @override
  String get billEmptyBody =>
      'Your first invoice appears on the 1st of next month.';

  @override
  String get billAllSettledTitle => 'All settled';

  @override
  String get billAllSettledBody => 'You have nothing to pay right now.';

  @override
  String get billRunningMonth => 'This month so far';

  @override
  String get billRunningMonthHint => 'The running total, day by day';

  @override
  String billInvoiceOfMonth(String month) {
    return 'Invoice for $month';
  }

  @override
  String billUnderReviewTitle(String month) {
    return 'Payment for $month is under review';
  }

  @override
  String get billUnderReviewBody =>
      'The platform team is checking your transfer. You will be notified.';

  @override
  String get billPay => 'Pay';

  @override
  String get billPayTitle => 'Submit a payment';

  @override
  String get billStatusUnpaid => 'Unpaid';

  @override
  String get billStatusPendingReview => 'Pending review';

  @override
  String get billStatusPaid => 'Paid';

  @override
  String get billStatusRejected => 'Rejected';

  @override
  String get billStatusOverdue => 'Overdue';

  @override
  String get billStatusWaived => 'Waived';

  @override
  String get billStatusNoCharge => 'No charge';

  @override
  String get billDueToday => 'Due today';

  @override
  String get billDueTomorrow => 'Due tomorrow';

  @override
  String billDueInDays(int days) {
    return 'Due in $days days';
  }

  @override
  String billDueLate(int days) {
    return '$days days late';
  }

  @override
  String billDueOn(String date) {
    return 'Due $date';
  }

  @override
  String billCounts(int examinations, int consultations) {
    return '$examinations exam + $consultations consult';
  }

  @override
  String get billInvoiceTitle => 'Invoice';

  @override
  String get billInvoiceSubtitle => 'Counts, amounts and payments';

  @override
  String get billInvoiceTotals => 'Totals';

  @override
  String billExaminationsLine(int count) {
    return '$count examinations';
  }

  @override
  String billConsultationsLine(int count) {
    return '$count consultations';
  }

  @override
  String billAdjustmentLine(String reason) {
    return 'Adjustment: $reason';
  }

  @override
  String get billTotalDue => 'Total due';

  @override
  String billPeriodLine(String month) {
    return 'Period: $month';
  }

  @override
  String billPaidOn(String date, String method) {
    return 'Paid on $date $method';
  }

  @override
  String get billByBranch => 'By branch';

  @override
  String get billPayments => 'Payments';

  @override
  String get billTimeline => 'Status history';

  @override
  String get billPaymentPending => 'Under review';

  @override
  String get billPaymentApproved => 'Approved';

  @override
  String get billPaymentRejected => 'Rejected';

  @override
  String billTransferOn(String date) {
    return 'Transferred $date';
  }

  @override
  String billReference(String reference) {
    return 'Ref $reference';
  }

  @override
  String billRejectionReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get billRejectedTitle => 'Your payment was rejected';

  @override
  String billRejectedBody(String reason) {
    return '$reason. Submit the payment again with a clear screenshot.';
  }

  @override
  String billScreenshotN(int number) {
    return 'Screenshot $number';
  }

  @override
  String get billMethodInstapay => 'InstaPay';

  @override
  String get billMethodCash => 'Cash';

  @override
  String get billMethodBank => 'Bank transfer';

  @override
  String get billMethodOther => 'Other';

  @override
  String get billInstapayTitle => 'Where to send the money';

  @override
  String get billInstapayAddress => 'InstaPay address';

  @override
  String get billInstapayAccount => 'Account name';

  @override
  String get billInstapayAmount => 'Exact amount';

  @override
  String get billCopy => 'Copy';

  @override
  String get billCopied => 'Copied';

  @override
  String get billPaymentDetails => 'Payment details';

  @override
  String get billScreenshots => 'Screenshots of the transfer';

  @override
  String get billScreenshotsHint => '1 to 3 images, up to 10 MB each';

  @override
  String get billAddScreenshot => 'Add a screenshot';

  @override
  String get billRemoveScreenshot => 'Remove this screenshot';

  @override
  String get billErrorScreenshotRequired =>
      'Add at least one screenshot of the transfer';

  @override
  String get billAmountTransferred => 'Amount transferred';

  @override
  String get billEgpUnit => 'EGP';

  @override
  String get billErrorAmount => 'Enter the amount you transferred';

  @override
  String get billTransferDate => 'Transfer date';

  @override
  String get billReferenceOptional => 'InstaPay reference (optional)';

  @override
  String get billSenderOptional => 'Sender name (optional)';

  @override
  String get billNoteOptional => 'Note (optional)';

  @override
  String get billSubmitPayment => 'Send for review';

  @override
  String get billSubmittedSnack => 'Your payment is under review';

  @override
  String get billErrorNotPayable =>
      'This invoice can\'t be paid right now. It may already be paid or under review.';

  @override
  String get anaPeriod => 'Period';

  @override
  String get anaPresetToday => 'Today';

  @override
  String get anaPresetYesterday => 'Yesterday';

  @override
  String get anaPresetThisWeek => 'This week';

  @override
  String get anaPresetLastWeek => 'Last week';

  @override
  String get anaPresetThisMonth => 'This month';

  @override
  String get anaPresetLastMonth => 'Last month';

  @override
  String get anaPresetLast3Months => 'Last 3 months';

  @override
  String get anaPresetLast6Months => 'Last 6 months';

  @override
  String get anaPresetThisYear => 'This year';

  @override
  String get anaPresetLastYear => 'Last year';

  @override
  String get anaPresetCustom => 'Custom range';

  @override
  String get anaAllTypes => 'All visits';

  @override
  String get anaCompare => 'Compare';

  @override
  String get anaInsights => 'Insights';

  @override
  String get anaTileRevenue => 'Clinic revenue';

  @override
  String get anaTileNet => 'Net income';

  @override
  String get anaTileFees => 'Platform fees';

  @override
  String get anaTileVisits => 'Visits';

  @override
  String anaTileVisitsSplit(int examinations, int consultations) {
    return '$examinations exams · $consultations consults';
  }

  @override
  String get anaTilePatients => 'Patients';

  @override
  String get anaTileNewPatients => 'New patients';

  @override
  String get anaTileWeeklyAverage => 'Patients per week';

  @override
  String get anaTileAveragePerVisit => 'Revenue per visit';

  @override
  String get anaTileNoShow => 'No-show rate';

  @override
  String get anaTileAppShare => 'Booked from the app';

  @override
  String get anaTileWait => 'Average wait';

  @override
  String anaPercent(String value) {
    return '$value%';
  }

  @override
  String anaMinutes(String value) {
    return '$value min';
  }

  @override
  String get anaNoChange => 'No change';

  @override
  String get anaUp => 'up';

  @override
  String get anaDown => 'down';

  @override
  String anaChangeSemantics(String percent, String direction) {
    return '$direction $percent percent versus the previous period';
  }

  @override
  String anaInvoiceCardTitle(String month) {
    return 'Invoice for $month';
  }

  @override
  String get anaPreviousPeriod => 'Previous period';

  @override
  String get anaNoData => 'No data for this period';

  @override
  String get anaC1Title => 'Revenue over time';

  @override
  String get anaC1Subtitle => 'Examinations and consultations';

  @override
  String anaC1Summary(String total) {
    return 'Revenue chart. Total $total';
  }

  @override
  String get anaC2Title => 'Visits over time';

  @override
  String anaC2Summary(int total) {
    return 'Visits chart. $total visits';
  }

  @override
  String get anaC3Title => 'Patients per week';

  @override
  String anaC3Summary(String average) {
    return 'Patients per week chart. Average $average';
  }

  @override
  String get anaPatientsPerWeek => 'Patients';

  @override
  String anaWeeklyAverageLine(String average) {
    return 'Average $average';
  }

  @override
  String anaWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String anaPatientsCount(int count) {
    return '$count patients';
  }

  @override
  String get anaC4Title => 'Busy and quiet months';

  @override
  String get anaC4Subtitle => 'Visits per month, last 12 months';

  @override
  String get anaC4Summary =>
      'Visits per month chart with the busiest and quietest months highlighted';

  @override
  String get anaBusiest => 'Busiest';

  @override
  String get anaQuietest => 'Quietest';

  @override
  String get anaThisYear => 'This year';

  @override
  String get anaLastYear => 'Last year';

  @override
  String anaVisitsCount(int count) {
    return '$count visits';
  }

  @override
  String get anaC5Title => 'Busiest days and hours';

  @override
  String get anaC5Subtitle => 'Visits by weekday and hour';

  @override
  String get anaC5Summary => 'Heatmap of visits by weekday and hour';

  @override
  String anaHeatCell(String day, int hour, int count) {
    return '$day, $hour:00: $count visits';
  }

  @override
  String get anaSat => 'Sat';

  @override
  String get anaSun => 'Sun';

  @override
  String get anaMon => 'Mon';

  @override
  String get anaTue => 'Tue';

  @override
  String get anaWed => 'Wed';

  @override
  String get anaThu => 'Thu';

  @override
  String get anaFri => 'Fri';

  @override
  String get anaC6Title => 'New and returning patients';

  @override
  String get anaC6Summary => 'New and returning patients per month';

  @override
  String get anaNewPatients => 'New';

  @override
  String get anaReturningPatients => 'Returning';

  @override
  String get anaC7Title => 'Examinations and consultations';

  @override
  String anaC7Summary(int examinations, int consultations) {
    return '$examinations examinations and $consultations consultations';
  }

  @override
  String get anaByCount => 'By number of visits';

  @override
  String get anaByRevenue => 'By revenue';

  @override
  String get anaC8Title => 'Branches';

  @override
  String get anaC8Summary => 'Visits and revenue per branch';

  @override
  String get anaC9Title => 'Bookings funnel';

  @override
  String anaC9Summary(int booked, int arrived, int seen) {
    return '$booked booked, $arrived arrived, $seen seen';
  }

  @override
  String get anaFunnelBooked => 'Booked';

  @override
  String get anaFunnelArrived => 'Arrived';

  @override
  String get anaFunnelSeen => 'Seen';

  @override
  String get anaNoShows => 'No-shows';

  @override
  String get anaCancellations => 'Cancellations';

  @override
  String get anaC10Title => 'Booking sources';

  @override
  String get anaC10Summary => 'Bookings per month by source';

  @override
  String get anaSourceApp => 'App';

  @override
  String get anaSourceStaff => 'Staff';

  @override
  String get anaSourceWalkIn => 'Walk-in';

  @override
  String get anaC11Title => 'Patients not seen recently';

  @override
  String get anaC11Subtitle => 'Tap a bar to open the list';

  @override
  String get anaC11Summary =>
      'Patients whose last visit was 3, 6 or 12 or more months ago';

  @override
  String anaNotSeenMonths(int months) {
    return 'More than $months months';
  }

  @override
  String get anaNotSeen12 => '12 months or more';

  @override
  String get anaC12Title => 'Waiting time';

  @override
  String get anaC12Summary => 'Average wait per day';

  @override
  String get revTitle => 'Revenue';

  @override
  String get revSubtitle => 'Month by month, with fees and net income';

  @override
  String get revTabMonth => 'By month';

  @override
  String get revTabBranch => 'By branch';

  @override
  String get revTabType => 'By visit type';

  @override
  String get revTabPayment => 'By payment method';

  @override
  String get revEmptyTitle => 'No visits in this period';

  @override
  String get revEmptyBody => 'Change the year or the filters to see more.';

  @override
  String get revColMonth => 'Month';

  @override
  String get revColExaminations => 'Examinations';

  @override
  String get revColConsultations => 'Consultations';

  @override
  String get revColRevenue => 'Revenue';

  @override
  String get revColFees => 'Platform fees';

  @override
  String get revColNet => 'Net income';

  @override
  String get revColPatients => 'Patients';

  @override
  String get revColNewPatients => 'New';

  @override
  String get revColVisits => 'Visits';

  @override
  String get revColFreeDiscounted => 'Free / discounted';

  @override
  String get revColChange => 'Change';

  @override
  String get revColInvoice => 'Invoice';

  @override
  String get revOpenInvoice => 'Open invoice';

  @override
  String get revTotals => 'Totals';

  @override
  String get revBestMonth => 'Best month';

  @override
  String get revWorstMonth => 'Lowest month';

  @override
  String get revMonthSubtitle => 'Day by day. Tap a day for its sessions.';

  @override
  String get revDaySubtitle => 'Every session of the day';

  @override
  String revNetShort(String amount) {
    return 'Net $amount';
  }

  @override
  String revRecordedBy(String name) {
    return 'By $name';
  }

  @override
  String get revVisitPrice => 'Visit price';

  @override
  String get revAmountCharged => 'Charged';

  @override
  String get revDiscount => 'Discount';

  @override
  String get revMethodUnspecified => 'Not specified';

  @override
  String get abDashboardTitle => 'Dashboard';

  @override
  String get abDashboardSubtitle => 'The platform at a glance';

  @override
  String get abTileDoctors => 'Doctors';

  @override
  String abTileDoctorsCaption(int active, int pending, int suspended) {
    return '$active active · $pending pending · $suspended suspended';
  }

  @override
  String get abTilePatients => 'Patients';

  @override
  String get abTileSessionsToday => 'Sessions today';

  @override
  String get abTileSessionsMonth => 'Sessions this month';

  @override
  String get abTileBookingsToday => 'Bookings today';

  @override
  String get abTileNoShow => 'No-show rate';

  @override
  String get abLast30Days => 'Last 30 days';

  @override
  String get abTileExpectedFees => 'Expected fees this month';

  @override
  String get abLiveThisMonth => 'Live, from the sessions saved';

  @override
  String get abTileLastMonth => 'Last month collected';

  @override
  String abCollectedOfInvoiced(String invoiced) {
    return 'of $invoiced invoiced';
  }

  @override
  String get abTileOutstanding => 'Outstanding';

  @override
  String get abTileOverdue => 'Overdue doctors';

  @override
  String get abTilePaymentsToReview => 'Payments to review';

  @override
  String get abTileSignups => 'Sign-ups to approve';

  @override
  String get abChartSessions => 'Sessions, last 30 days';

  @override
  String get abChartInvoiced => 'Invoiced and collected, last 12 months';

  @override
  String get abInvoiced => 'Invoiced';

  @override
  String get abCollected => 'Collected';

  @override
  String get abListPayments => 'Payments to review';

  @override
  String get abListPaymentsEmpty => 'Nothing is waiting for review.';

  @override
  String get abListSignups => 'Latest sign-ups';

  @override
  String get abListSignupsEmpty => 'No sign-ups yet.';

  @override
  String get abListDueSoon => 'Invoices due in 3 days';

  @override
  String get abListDueSoonEmpty => 'No invoice is due soon.';

  @override
  String get abSeeAll => 'See all';

  @override
  String get abPaymentsTitle => 'Payments to review';

  @override
  String abPaymentsSubtitle(int count) {
    return '$count waiting, oldest first';
  }

  @override
  String get abPaymentsEmptyTitle => 'Nothing to review';

  @override
  String get abPaymentsEmptyBody => 'New payments from doctors appear here.';

  @override
  String abInvoiceOf(String month) {
    return 'Invoice for $month';
  }

  @override
  String get abAmountMismatch => 'Amount differs';

  @override
  String abInvoiceTotalShort(String total) {
    return 'of $total';
  }

  @override
  String get abReviewTitle => 'Review payment';

  @override
  String get abScreenshots => 'Screenshots';

  @override
  String get abNoScreenshots => 'No screenshots';

  @override
  String get abInvoiceSummary => 'Invoice';

  @override
  String get abDoctor => 'Doctor';

  @override
  String get abMonth => 'Month';

  @override
  String get abDueDate => 'Due date';

  @override
  String get abDoctorEntries => 'What the doctor entered';

  @override
  String abMismatchBanner(String total) {
    return 'The invoice total is $total';
  }

  @override
  String get abSubmitted => 'Submitted';

  @override
  String get abEarlierAttempts => 'Earlier attempts on this invoice';

  @override
  String get abAlreadyApproved => 'Already approved';

  @override
  String abAlreadyRejected(String reason) {
    return 'Already rejected: $reason';
  }

  @override
  String get abApprove => 'Approve';

  @override
  String get abApproveTitle => 'Approve this payment?';

  @override
  String abApproveBody(String amount, String doctor) {
    return '$amount from $doctor will mark the invoice as paid.';
  }

  @override
  String get abApprovedSnack => 'Payment approved';

  @override
  String get abReject => 'Reject';

  @override
  String get abRejectTitle => 'Reject this payment';

  @override
  String get abRejectBody => 'The doctor sees the reason and can submit again.';

  @override
  String get abRejectAmount => 'Amount does not match';

  @override
  String get abRejectUnclear => 'Screenshot unclear';

  @override
  String get abRejectNotReceived => 'Transfer not received';

  @override
  String get abRejectedSnack => 'Payment rejected';

  @override
  String get abReasonLabel => 'Reason';

  @override
  String get abReasonRequired => 'Write at least 3 characters';

  @override
  String get abNoteLabel => 'Note';

  @override
  String get abSave => 'Save';

  @override
  String get abSend => 'Send';

  @override
  String get abInvoicesTitle => 'Invoices';

  @override
  String get abInvoicesSubtitle => 'Every doctor\'s monthly invoice';

  @override
  String get abInvoicesEmptyTitle => 'No invoices match';

  @override
  String get abInvoicesEmptyBody => 'Change the month or the status.';

  @override
  String get abFilterMonth => 'Month';

  @override
  String get abAllMonths => 'All months';

  @override
  String get abAllStatuses => 'All';

  @override
  String get abTotalsInvoices => 'Invoices';

  @override
  String get abTotalsExaminations => 'Examinations';

  @override
  String get abTotalsConsultations => 'Consultations';

  @override
  String get abTotalsAmount => 'Total';

  @override
  String get abInvoiceTitle => 'Invoice';

  @override
  String get abMarkPaid => 'Mark paid';

  @override
  String get abMarkPaidTitle => 'Mark this invoice as paid';

  @override
  String get abMarkPaidBody => 'Choose how the money arrived and add a note.';

  @override
  String get abMarkedPaidSnack => 'Invoice marked as paid';

  @override
  String get abWaive => 'Waive';

  @override
  String get abWaiveTitle => 'Waive this invoice';

  @override
  String get abWaiveBody =>
      'The doctor owes nothing for this month. A reason is required.';

  @override
  String get abWaivedSnack => 'Invoice waived';

  @override
  String get abAdjust => 'Adjust amount';

  @override
  String get abAdjustTitle => 'Adjust the amount';

  @override
  String get abAdjustBody =>
      'A discount lowers the total, a charge raises it. The total must stay above zero.';

  @override
  String get abAdjustDiscount => 'Discount';

  @override
  String get abAdjustCharge => 'Charge';

  @override
  String get abAdjustAmount => 'Amount';

  @override
  String get abAdjustedSnack => 'Invoice adjusted';

  @override
  String get abExtend => 'Extend due date';

  @override
  String get abExtendTitle => 'New due date';

  @override
  String get abExtendedSnack => 'Due date extended';

  @override
  String get abPendingHint => 'A payment is waiting for review.';

  @override
  String get abOpenQueue => 'Open the queue';

  @override
  String get abDoctorsTitle => 'Doctors';

  @override
  String abDoctorsSubtitle(int count) {
    return '$count doctors';
  }

  @override
  String get abDoctorsSearchHint => 'Search by name, phone, email or clinic';

  @override
  String get abDoctorsEmptyTitle => 'No doctors found';

  @override
  String get abDoctorsEmptyBody => 'Try a different search or filter.';

  @override
  String get abSort => 'Sort';

  @override
  String get abSortName => 'Name';

  @override
  String get abSortNewest => 'Newest';

  @override
  String get abSortSessions => 'Most sessions';

  @override
  String get abSortOutstanding => 'Most owed';

  @override
  String abSessionsThisMonth(int count) {
    return '$count sessions this month';
  }

  @override
  String get abOutstanding => 'Owes';

  @override
  String get abDoctorActive => 'Active';

  @override
  String get abDoctorPending => 'Pending approval';

  @override
  String get abDoctorSuspended => 'Suspended';

  @override
  String get abDoctorDisabled => 'Disabled';

  @override
  String get abDoctorRejected => 'Rejected';

  @override
  String get abDoctorTitle => 'Doctor';

  @override
  String get abTabProfile => 'Profile';

  @override
  String get abTabActivity => 'Activity';

  @override
  String get abTabInvoices => 'Invoices';

  @override
  String get abTabPayments => 'Payments';

  @override
  String get abTabAudit => 'Audit';

  @override
  String get abTabBranches => 'Branches';

  @override
  String get abTabAppointments => 'Appointments';

  @override
  String get abTabAssistants => 'Assistants';

  @override
  String get abProfile => 'Profile';

  @override
  String get abFullName => 'Name';

  @override
  String get abSpecialty => 'Specialty';

  @override
  String get abEmail => 'Email';

  @override
  String get abPhone => 'Mobile';

  @override
  String get abLicense => 'License number';

  @override
  String get abJoined => 'Joined';

  @override
  String get abStatusReason => 'Status reason';

  @override
  String abReasonBilling(String month) {
    return 'Unpaid invoice for $month';
  }

  @override
  String get abActions => 'Actions';

  @override
  String get abSuspend => 'Suspend';

  @override
  String get abSuspendTitle => 'Suspend this doctor';

  @override
  String get abSuspendBody =>
      'The doctor and the assistants can read but not add. A reason is required.';

  @override
  String get abSuspendedSnack => 'Doctor suspended';

  @override
  String get abReactivate => 'Reactivate';

  @override
  String get abReactivateTitle => 'Reactivate this doctor';

  @override
  String get abReactivateBody =>
      'The clinic works normally again. A reason is required.';

  @override
  String get abReactivatedSnack => 'Doctor reactivated';

  @override
  String get abDisable => 'Disable account';

  @override
  String get abDisableTitle => 'Disable this account';

  @override
  String get abDisableBody =>
      'The doctor and the assistants can\'t sign in, and the bookings from today on are cancelled and the patients told.';

  @override
  String get abDisabledSnack => 'Account disabled';

  @override
  String get abSendReset => 'Send password reset email';

  @override
  String get abResetTitle => 'Send a password reset email?';

  @override
  String get abResetBody =>
      'The doctor gets an email with a link to set a new password.';

  @override
  String get abResetSent => 'Email sent';

  @override
  String get abAddNote => 'Add note';

  @override
  String get abNotes => 'Internal notes';

  @override
  String get abNotesEmpty => 'No notes yet. Only admins see them.';

  @override
  String get abNoteAdded => 'Note added';

  @override
  String get abSessionsPerMonth => 'Sessions per month';

  @override
  String abSessionsOfMonth(String month) {
    return 'Sessions in $month';
  }

  @override
  String get abMaskedHint => 'Patient names are masked';

  @override
  String get abNoSessions => 'No sessions this month';

  @override
  String get abStatusChanges => 'Status changes';

  @override
  String get abDeletedSessions => 'Deleted sessions';

  @override
  String abDeleteReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get abNothingHere => 'Nothing here';

  @override
  String get abAuditSuspended => 'Suspended';

  @override
  String get abAuditReactivated => 'Reactivated';

  @override
  String get abAuditDisabled => 'Account disabled';

  @override
  String get abAuditServiceActivated => 'Service activated';

  @override
  String get abAuditTrialExtended => 'Trial extended';

  @override
  String get abAuditInvoiceOverdue => 'Invoice became overdue';

  @override
  String get abBranchDefault => 'Default';

  @override
  String get abAppointmentsCounts => 'Bookings per month';

  @override
  String get abCountsOnly => 'Counts only, no names';

  @override
  String abAppointmentsLine(
    int bookings,
    int noShows,
    int cancellations,
    int rate,
    int unseen,
  ) {
    return '$bookings bookings · $noShows no-shows ($rate%) · $cancellations cancelled · $unseen not seen';
  }

  @override
  String get abNoAssistants => 'No assistants';

  @override
  String get billErrorTooManyScreenshots =>
      'You can attach at most 3 screenshots';

  @override
  String get abErrorInvoiceStatus =>
      'This invoice\'s status doesn\'t allow this action. Refresh and check.';

  @override
  String get abErrorAlreadyReviewed => 'This payment was already reviewed.';

  @override
  String get abErrorAdjustment =>
      'The total due must stay above zero. Waive the invoice instead.';

  @override
  String get abErrorDueDate => 'Choose a later due date, within a year.';

  @override
  String get patientFilterUpcoming => 'Has a booking';

  @override
  String get patientFilterNoShows => 'Has no-shows';

  @override
  String get patientColumnNextBooking => 'Next booking';

  @override
  String get patientColumnNoShows => 'No-shows';

  @override
  String get adminAddDoctor => 'Add doctor';

  @override
  String get adminAddDoctorSubtitle =>
      'The account is active at once, with no free trial. The doctor gets an email to choose a password.';

  @override
  String get adminAddDoctorAccountIntro =>
      'The doctor signs in with this email. We\'ll send a link to it for choosing a password.';

  @override
  String get adminAddDoctorLanguage =>
      'Language of the doctor\'s emails and notifications';

  @override
  String get adminAddDoctorReviewIntro =>
      'Check the details, then add the doctor. Their clinic opens right away.';

  @override
  String adminAddDoctorDoneTitle(String name) {
    return 'Dr. $name is added';
  }

  @override
  String adminAddDoctorDoneBody(String email) {
    return 'We emailed $email a link to choose a password. It works for 3 days; if it runs out, send a new one from the doctor\'s page.';
  }

  @override
  String get adminAddDoctorOpen => 'Open the doctor\'s page';

  @override
  String adminBadgeWaitingReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waiting for review',
      one: '1 waiting for review',
    );
    return '$_temp0';
  }

  @override
  String get adminFilterSpecialty => 'Specialty';

  @override
  String get adminFilterGovernorate => 'Governorate';

  @override
  String get adminFilterSignupDate => 'Sign-up date';

  @override
  String adminFilterSignedUp(String dates) {
    return 'Signed up $dates';
  }

  @override
  String get adminDoctorFiltersNoMatchBody =>
      'No doctor matches these filters. Clear one to see more.';

  @override
  String get adminAuditDoctorCreated =>
      'added a doctor (active, no free trial)';

  @override
  String get adminActionDoctorCreated => 'Doctor added';

  @override
  String get adminFilters => 'Filters';

  @override
  String adminFiltersSet(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Filters, $count set',
      one: 'Filters, 1 set',
    );
    return '$_temp0';
  }

  @override
  String get adminFilterAny => 'Any';

  @override
  String get adminFiltersDone => 'Done';

  @override
  String get navBroadcast => 'Broadcast';

  @override
  String get broadcastSubtitle =>
      'A notification in the app and a push to doctors\' phones, in each doctor\'s language.';

  @override
  String get broadcastAudienceTitle => 'Who gets it';

  @override
  String get broadcastAudienceAll => 'All doctors';

  @override
  String get broadcastAudienceSelected => 'Chosen doctors';

  @override
  String get broadcastAudienceAllHint =>
      'Every doctor whose clinic is active or suspended. Doctors still waiting for review, rejected or disabled don\'t get it.';

  @override
  String get broadcastChooseDoctors => 'Choose doctors';

  @override
  String broadcastChosenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors chosen',
      one: '1 doctor chosen',
    );
    return '$_temp0';
  }

  @override
  String get broadcastErrorNoDoctors => 'Choose at least one doctor.';

  @override
  String get broadcastMessageTitle => 'Message';

  @override
  String get broadcastMessageHint =>
      'Write it in both languages, or in one: doctors who use the other language see the same text.';

  @override
  String get broadcastTitleAr => 'Title (Arabic)';

  @override
  String get broadcastBodyAr => 'Text (Arabic)';

  @override
  String get broadcastTitleEn => 'Title (English)';

  @override
  String get broadcastBodyEn => 'Text (English)';

  @override
  String get broadcastErrorEmpty =>
      'Write the message in Arabic, English or both.';

  @override
  String get broadcastErrorTitle => 'Write the title too.';

  @override
  String get broadcastErrorBody => 'Write the text too.';

  @override
  String get broadcastPreview => 'Preview';

  @override
  String get broadcastPreviewEmpty =>
      'Your message shows here as doctors will see it.';

  @override
  String get broadcastPreviewNow => 'now';

  @override
  String get broadcastSend => 'Send';

  @override
  String get broadcastConfirmTitle => 'Send this broadcast?';

  @override
  String get broadcastConfirmAll =>
      'Every doctor gets it at once, in the app and as a push. It can\'t be taken back.';

  @override
  String broadcastConfirmSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The $count chosen doctors get it at once, in the app and as a push. It can\'t be taken back.',
      one:
          'The chosen doctor gets it at once, in the app and as a push. It can\'t be taken back.',
    );
    return '$_temp0';
  }

  @override
  String broadcastSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sent to $count doctors',
      one: 'Sent to 1 doctor',
    );
    return '$_temp0';
  }

  @override
  String get broadcastErrorNoRecipients =>
      'None of these doctors can get it now: they\'re waiting for review, rejected or disabled.';

  @override
  String get broadcastHistoryTitle => 'Sent';

  @override
  String get broadcastHistoryEmpty => 'Nothing sent yet';

  @override
  String get broadcastHistoryEmptyBody =>
      'What you send shows here, with who got it.';

  @override
  String get broadcastHistoryMore => 'Show more';

  @override
  String broadcastRecipients(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors',
      one: '1 doctor',
    );
    return '$_temp0';
  }

  @override
  String broadcastSentBy(String name) {
    return 'by $name';
  }

  @override
  String get broadcastPickerSearch => 'Search by name';

  @override
  String get broadcastPickerEmpty => 'No doctors found';

  @override
  String broadcastPickerDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Done ($count)',
      zero: 'Done',
    );
    return '$_temp0';
  }

  @override
  String get adminAuditBroadcastSent => 'sent a broadcast to doctors';

  @override
  String get adminActionBroadcastSent => 'Broadcast sent';

  @override
  String get adminTargetBroadcast => 'Broadcast';

  @override
  String get catalogReportAction => 'Report a missing or wrong item';

  @override
  String get catalogReportItemAction =>
      'Something wrong with this item? Report it';

  @override
  String get catalogReportTitle => 'Report to the admin';

  @override
  String get catalogReportIntro =>
      'The admins check it and fix the catalog for every doctor.';

  @override
  String get catalogReportType => 'What\'s the problem?';

  @override
  String get catalogReportText => 'Details';

  @override
  String get catalogReportTextHint =>
      'For example the name as it\'s written on the box, or what\'s wrong.';

  @override
  String catalogReportAbout(String name) {
    return 'About: $name';
  }

  @override
  String get catalogReportSend => 'Send report';

  @override
  String get catalogReportSent => 'Sent to the admin. Thank you!';

  @override
  String get catalogReportErrorText => 'Write what\'s missing or wrong.';

  @override
  String get queueByArrival => 'Turns go in order of arrival at the clinic';

  @override
  String get queueCheckInOnArrival => 'Check in at reception when you arrive';

  @override
  String get queueByArrivalCheckIn =>
      'Turns go in order of arrival: check in at reception when you arrive';

  @override
  String get queueYourNumber => 'Your number';

  @override
  String queuePatientsAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients ahead of you',
      one: '1 patient ahead of you',
      zero: 'You\'re next',
    );
    return '$_temp0';
  }

  @override
  String queueWaitAbout(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Estimated wait about $minutes minutes',
      one: 'Estimated wait about 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get queueWithDoctorNow => 'You\'re with the doctor now';

  @override
  String periodMorningFrom(String time) {
    return 'Morning period from $time';
  }

  @override
  String periodEveningFrom(String time) {
    return 'Evening period from $time';
  }

  @override
  String get homeNextAppointment => 'Next appointment';

  @override
  String get homeNoUpcomingAppointment => 'No upcoming appointment';

  @override
  String get boardBooked => 'Booked';

  @override
  String get boardNextPatient => 'Next patient';

  @override
  String get boardNoOneWaiting => 'No one is waiting';

  @override
  String get boardStartSession => 'Start session';

  @override
  String get boardFinish => 'Finish';

  @override
  String get boardDragHint => 'Drag to the next or previous column';

  @override
  String boardPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count waiting for confirmation',
      one: '1 waiting for confirmation',
    );
    return '$_temp0';
  }

  @override
  String boardNoSessionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checked in, no session',
      one: '1 checked in, no session',
    );
    return '$_temp0';
  }

  @override
  String boardAwaitingDoctorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions waiting for you',
      one: '1 session waiting for you',
    );
    return '$_temp0';
  }

  @override
  String boardUnreadChatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread chats',
      one: '1 unread chat',
    );
    return '$_temp0';
  }

  @override
  String get boardNoSessionTitle => 'Checked in, no session';

  @override
  String get boardNoSessionBody =>
      'Record the session, or mark the patient as left without being seen.';

  @override
  String get waitingRoomScreen => 'Waiting-room screen';

  @override
  String get waitingRoomNext => 'Next';

  @override
  String get waitingRoomExit => 'Exit full screen';

  @override
  String catalogSetupSpace(String size) {
    return 'Needs $size of free space';
  }

  @override
  String get adminLicenseOpenOtherApp => 'Open in another app';

  @override
  String trayOpen(String app) {
    return 'Open $app';
  }

  @override
  String get trayStartWithWindows => 'Start with Windows';

  @override
  String get trayQuit => 'Quit';

  @override
  String trayTooltipUnread(String app, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$app · $_temp0';
  }

  @override
  String trayStillRunningTitle(String app) {
    return '$app is still running';
  }

  @override
  String get trayStillRunningBody =>
      'New messages and bookings keep coming here. To close it completely, choose Quit from its icon by the clock.';

  @override
  String get visitsFilterBranch => 'Branch';

  @override
  String get visitsNoneInBranch => 'No visits in this branch.';

  @override
  String get filesAnyDate => 'Any date';

  @override
  String get filesDateRange => 'Filter by date';

  @override
  String get filesClearDates => 'Clear dates';

  @override
  String get filesNoneInRange => 'No files in these dates.';

  @override
  String get chatButton => 'Chat';

  @override
  String get patientExportCsv => 'Export CSV';

  @override
  String get patientExportDone => 'The patient list is exported.';

  @override
  String get patientExportTooLarge =>
      'Too many patients for one file. Narrow the filters and try again.';

  @override
  String get patientColumnUnread => 'Unread';

  @override
  String patientUnreadSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String patientCardNextBooking(String date) {
    return 'Next booking $date';
  }

  @override
  String patientCardNoShows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count no-shows',
      one: '1 no-show',
    );
    return '$_temp0';
  }

  @override
  String patientCardFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get patientTabAppointments => 'Appointments';

  @override
  String get patientAppointmentsEmptyTitle => 'No bookings yet';

  @override
  String get patientAppointmentsEmptyBody =>
      'Book a visit for this patient from here.';

  @override
  String get patientAppointmentsUpcoming => 'Upcoming';

  @override
  String get patientAppointmentsPast => 'Past';

  @override
  String activityPatientsExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exported the patient list ($count patients)',
      one: 'Exported the patient list (1 patient)',
    );
    return '$_temp0';
  }

  @override
  String get activityActionPatientsExported => 'Patient list exported';

  @override
  String get scheduleSpecialHoursTitle => 'Special hours';

  @override
  String get scheduleSpecialHoursBody =>
      'Hours for one date replace that weekday\'s hours. A date with no hours is closed.';

  @override
  String get scheduleAddSpecialDay => 'Add a date';

  @override
  String get scheduleNoSpecialDays => 'No special dates coming up.';

  @override
  String get scheduleDayClosed => 'Closed all day';

  @override
  String get scheduleDayClosedToggle => 'Closed that day';

  @override
  String get scheduleDayHours => 'Hours that day';

  @override
  String get scheduleClosuresBody =>
      'Close a day, a few days or part of a day, for this branch or for every branch (a vacation).';

  @override
  String get scheduleNoClosures => 'No closures coming up.';

  @override
  String get scheduleClosureWholeDays => 'Whole days';

  @override
  String get scheduleClosurePartDay => 'Part of a day';

  @override
  String get schedulePickDates => 'Choose the days';

  @override
  String get schedulePickDate => 'Choose the day';

  @override
  String get scheduleClosureEndBeforeStart => 'It ends before it starts.';

  @override
  String get scheduleClosureReason => 'Reason (optional)';

  @override
  String get scheduleClosureReasonHint => 'For example: vacation, a conference';

  @override
  String get scheduleNothingSaved => 'Nothing was saved.';

  @override
  String get scheduleMoveFull =>
      'That place is full. Choose another one for the booking.';

  @override
  String scheduleMovedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings moved',
      one: '1 booking moved',
    );
    return '$_temp0';
  }

  @override
  String scheduleCancelledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bookings cancelled',
      one: '1 booking cancelled',
    );
    return '$_temp0';
  }

  @override
  String get conflictsBody =>
      'These bookings don\'t fit the new schedule. Choose what happens to each one. Nothing is saved until you apply.';

  @override
  String get conflictsForAll => 'For all';

  @override
  String get moveAll => 'Move all';

  @override
  String get conflictMove => 'Move';

  @override
  String conflictMoveTo(String place) {
    return 'Moves to $place';
  }

  @override
  String get conflictChangePlace => 'Change';

  @override
  String get conflictPickPlace => 'Choose a place';

  @override
  String get conflictPickNote =>
      'Free places from the schedule as it is saved now. The new hours are checked when you apply.';

  @override
  String get conflictKeepNote => 'Stays at its time, as an exception';

  @override
  String get conflictKeepNoPlace =>
      'No free place in the next two weeks. Keep it, cancel it, or choose a place.';

  @override
  String get conflictCancelNote =>
      'The patient is told, with a link to book again';

  @override
  String get bookingModeQueueBody =>
      'Patients book a place in a period. Turns go by arrival at the clinic.';

  @override
  String get bookingModeTimedBody => 'Each patient books an exact time.';

  @override
  String get bookingModeChangeNote =>
      'Changing the mode affects every upcoming booking here. When you save, you choose what happens to each one.';

  @override
  String get bookingCapacityBody =>
      'Each period can set its own number in Working hours.';

  @override
  String get bookingAvgVisitBody =>
      'Used for the waiting time patients see after check-in.';

  @override
  String get bookingExamSlots => 'Slots for an examination';

  @override
  String get bookingConsultationSlots => 'Slots for a consultation';

  @override
  String get bookingGroupApp => 'Booking from the app';

  @override
  String get bookingAutoConfirmOffBody =>
      'App bookings wait for the clinic to confirm them.';

  @override
  String get bookingGroupNoShows => 'No-shows and reminders';

  @override
  String get bookingNoShowCount => 'No-shows that stop app booking';

  @override
  String get bookingNoShowDays => 'Counted over';

  @override
  String bookingNoShowBody(int count, int days) {
    return '$count no-shows in $days days turn off app booking for that patient';
  }

  @override
  String get bookingReminderDayBefore => 'Reminder a day before';

  @override
  String get bookingReminderSameDay => 'Reminder 2 hours before, on the day';

  @override
  String get bookingGroupClinic => 'Clinic bookings';

  @override
  String get bookingNone => 'None';

  @override
  String bookingMinutes(int count) {
    return '$count min';
  }

  @override
  String bookingHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String bookingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get branchDoctorOnlyNote => 'Only the doctor can change this.';

  @override
  String activityBranchScheduleUpdated(String branch) {
    return 'Changed the schedule of $branch';
  }

  @override
  String get activityActionBranchScheduleUpdated => 'Schedule changed';

  @override
  String get branchNoWorkBranch => 'No branch yet';

  @override
  String get branchNoWorkBranchBody =>
      'You are not assigned to a branch. Ask the doctor to add you to one.';

  @override
  String get conflictsDismiss => 'Back to editing';

  @override
  String get branchPhotosTitle => 'Photos';

  @override
  String branchPhotosBody(int count) {
    return 'Up to $count. Patients see them on the branch card; the first is the cover.';
  }

  @override
  String branchPhotosCount(int count, int max) {
    return '$count of $max';
  }

  @override
  String get branchPhotosNone => 'No photos.';

  @override
  String get branchPhotosAdd => 'Add photos';

  @override
  String branchPhotosAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos added',
      one: 'Photo added',
    );
    return '$_temp0';
  }

  @override
  String branchPhotosLimit(int max) {
    return 'A branch has at most $max photos. Remove one first.';
  }

  @override
  String get branchPhotosNotImage => 'Use a JPEG, PNG or WebP photo.';

  @override
  String get branchPhotosTooLarge => 'The photo is larger than 10 MB.';

  @override
  String get branchPhotosDeleteTitle => 'Remove this photo?';

  @override
  String get branchPhotosDeleteBody => 'Patients won\'t see it any more.';

  @override
  String get branchPhotoLabel => 'Branch photo';

  @override
  String get branchPhotoCover => 'Cover';

  @override
  String get branchPhotoEarlier => 'Move earlier';

  @override
  String get branchPhotoLater => 'Move later';

  @override
  String activityBranchPhotosUpdated(String branch) {
    return 'Changed the photos of $branch';
  }

  @override
  String get activityActionBranchPhotosUpdated => 'Photos changed';

  @override
  String get holidaysTitle => 'Public holidays';

  @override
  String get holidaysBody =>
      'Suggested by el3yada. Close the branch on the ones you take off; nothing closes by itself.';

  @override
  String get holidayCloseDay => 'Close this day';

  @override
  String get holidayClosed => 'Closed';

  @override
  String get holidaysAdminBody =>
      'Clinics see the coming ones as suggestions in their special dates. No branch closes by itself.';

  @override
  String get holidayAdd => 'Add holiday';

  @override
  String get holidayAdded => 'Holiday added';

  @override
  String get holidayDate => 'Choose the date';

  @override
  String get holidayNameAr => 'Name in Arabic';

  @override
  String get holidayNameEn => 'Name in English';

  @override
  String get holidaysEmpty => 'No public holidays yet';

  @override
  String get holidaysEmptyBody =>
      'Add the year\'s holidays so clinics can plan around them.';

  @override
  String holidayDeleteTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get holidayDeleteBody =>
      'Clinics stop seeing it. Closures they already added stay.';

  @override
  String get holidayExists => 'That date is already on the list.';
}
