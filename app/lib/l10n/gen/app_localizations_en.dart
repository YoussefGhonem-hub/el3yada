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
  String get regStreetLabel => 'Street address';

  @override
  String get regBuildingLabel => 'Building';

  @override
  String get regFloorLabel => 'Floor';

  @override
  String get regApartmentLabel => 'Apartment';

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
  String regBuildingValue(String value) {
    return 'Building $value';
  }

  @override
  String regFloorValue(String value) {
    return 'Floor $value';
  }

  @override
  String regApartmentValue(String value) {
    return 'Apartment $value';
  }

  @override
  String get regListSeparator => ', ';

  @override
  String get regErrorInvalidName =>
      'Enter at least a first and a last name, in letters only.';

  @override
  String get regErrorEmailTaken =>
      'An account with this email already exists. Sign in, or use another email.';

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
  String get regErrorInvalidValue => 'Enter a valid value.';

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
}
