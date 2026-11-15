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
}
