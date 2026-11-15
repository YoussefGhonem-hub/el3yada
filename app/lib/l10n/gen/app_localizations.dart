import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'el3yada'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your clinic, organised.'**
  String get appTagline;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @identifierLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number or email'**
  String get identifierLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @signInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @registerAsDoctor.
  ///
  /// In en, this message translates to:
  /// **'Register as a doctor'**
  String get registerAsDoctor;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @errorRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get errorRequired;

  /// No description provided for @errorInvalidIdentifier.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Egyptian mobile number or email'**
  String get errorInvalidIdentifier;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong mobile number/email or password'**
  String get errorInvalidCredentials;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNoInternet;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnknown;

  /// No description provided for @patientDesktopTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient accounts use the mobile app'**
  String get patientDesktopTitle;

  /// No description provided for @patientDesktopBody.
  ///
  /// In en, this message translates to:
  /// **'The desktop app is for doctors, assistants and admins. Install el3yada on your phone to see your medical file and your bookings.'**
  String get patientDesktopBody;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @underConstructionTitle.
  ///
  /// In en, this message translates to:
  /// **'This screen is not built yet'**
  String get underConstructionTitle;

  /// Shown on placeholder screens. screenId is the screen ID from spec.md, for example D34.
  ///
  /// In en, this message translates to:
  /// **'Screen {screenId} in spec.md'**
  String underConstructionBody(String screenId);

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch language'**
  String get switchLanguage;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @devAccountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Test accounts (dev only)'**
  String get devAccountsTitle;

  /// No description provided for @devAccountsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap an account to fill it in. Any password works except \"wrong\".'**
  String get devAccountsBody;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get roleDoctor;

  /// No description provided for @roleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get roleAssistant;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rolePatient;

  /// No description provided for @navLive.
  ///
  /// In en, this message translates to:
  /// **'Live board'**
  String get navLive;

  /// Short name of the live board for the phone bottom bar, where the full name does not fit.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get navLiveShort;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get navRevenue;

  /// No description provided for @navAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get navAppointments;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get navBilling;

  /// No description provided for @navBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get navBranches;

  /// No description provided for @navAssistants.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get navAssistants;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMedicalFile.
  ///
  /// In en, this message translates to:
  /// **'Medical file'**
  String get navMedicalFile;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navDoctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get navDoctors;

  /// No description provided for @navPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get navPayments;

  /// No description provided for @navInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get navInvoices;

  /// No description provided for @navSignups.
  ///
  /// In en, this message translates to:
  /// **'Sign-up requests'**
  String get navSignups;

  /// No description provided for @navAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get navAccounts;

  /// No description provided for @navCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Catalogs'**
  String get navCatalogs;

  /// No description provided for @navSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Specialties'**
  String get navSpecialties;

  /// No description provided for @navAdmins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get navAdmins;

  /// No description provided for @navAuditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit log'**
  String get navAuditLog;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @navBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get navBadgeNew;

  /// Unread count on a navigation item, read by screen readers. count is a whole number.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String navBadgeUnread(int count);

  /// Screen-reader label of a navigation item that has a badge, e.g. "Chats, 3 unread".
  ///
  /// In en, this message translates to:
  /// **'{label}, {badge}'**
  String navItemWithBadge(String label, String badge);

  /// A1: shown under the logo when start-up takes more than a few seconds.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get splashSlow;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageTitle;

  /// No description provided for @languageBody.
  ///
  /// In en, this message translates to:
  /// **'You can change it later in Settings.'**
  String get languageBody;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @chooseAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in as'**
  String get chooseAccountTitle;

  /// No description provided for @chooseAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This number has two accounts. Choose one.'**
  String get chooseAccountBody;

  /// No description provided for @assistantAtClinic.
  ///
  /// In en, this message translates to:
  /// **'Assistant at {doctorName}\'s clinic'**
  String assistantAtClinic(String doctorName);

  /// No description provided for @errorSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Your sign-in timed out. Sign in again.'**
  String get errorSignInAgain;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Try again in a moment.'**
  String get errorServer;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get errorInvalidEmail;

  /// No description provided for @errorInvalidMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Egyptian mobile number.'**
  String get errorInvalidMobile;

  /// No description provided for @errorTooLong.
  ///
  /// In en, this message translates to:
  /// **'This is too long.'**
  String get errorTooLong;

  /// No description provided for @errorRetryInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {minutes} min.'**
  String errorRetryInMinutes(int minutes);

  /// No description provided for @forgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotTitle;

  /// No description provided for @forgotBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the email or mobile number you sign in with.'**
  String get forgotBody;

  /// No description provided for @forgotSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get forgotSubmit;

  /// No description provided for @forgotEmailSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get forgotEmailSentTitle;

  /// No description provided for @forgotEmailSentBody.
  ///
  /// In en, this message translates to:
  /// **'If this email belongs to an account, a link to set a new password is on its way. Check your spam folder too.'**
  String get forgotEmailSentBody;

  /// No description provided for @forgotPhoneSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get forgotPhoneSentTitle;

  /// No description provided for @forgotPhoneSentBody.
  ///
  /// In en, this message translates to:
  /// **'A request will be sent to your doctor to reset your password. They will give you a temporary password.'**
  String get forgotPhoneSentBody;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToLogin;

  /// No description provided for @setPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get setPasswordTitle;

  /// No description provided for @setPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a password only you know. You\'ll use it from now on.'**
  String get setPasswordBody;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordRulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your password needs'**
  String get passwordRulesTitle;

  /// No description provided for @passwordRuleLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordRuleLength;

  /// No description provided for @passwordRuleLetter.
  ///
  /// In en, this message translates to:
  /// **'A letter'**
  String get passwordRuleLetter;

  /// No description provided for @passwordRuleNumber.
  ///
  /// In en, this message translates to:
  /// **'A number'**
  String get passwordRuleNumber;

  /// Screen reader text for a met password rule.
  ///
  /// In en, this message translates to:
  /// **'Done: {rule}'**
  String passwordRuleMet(String rule);

  /// No description provided for @passwordRuleNotMet.
  ///
  /// In en, this message translates to:
  /// **'Not yet: {rule}'**
  String passwordRuleNotMet(String rule);

  /// No description provided for @acceptTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms of use and the Privacy Policy'**
  String get acceptTermsLabel;

  /// No description provided for @savePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Save password'**
  String get savePasswordButton;

  /// No description provided for @errorPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get errorPasswordsDontMatch;

  /// No description provided for @errorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters with a letter and a number.'**
  String get errorWeakPassword;

  /// No description provided for @errorPasswordSameAsOld.
  ///
  /// In en, this message translates to:
  /// **'Choose a password you haven\'t used here.'**
  String get errorPasswordSameAsOld;

  /// No description provided for @errorCurrentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'The current password is wrong.'**
  String get errorCurrentPasswordIncorrect;

  /// No description provided for @errorTermsNotAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accept the Terms and the Privacy Policy to continue.'**
  String get errorTermsNotAccepted;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyTitle;

  /// No description provided for @legalEmpty.
  ///
  /// In en, this message translates to:
  /// **'This text isn\'t available yet.'**
  String get legalEmpty;

  /// No description provided for @legalUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {date}'**
  String legalUpdated(String date);

  /// No description provided for @accountDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Account disabled'**
  String get accountDisabledTitle;

  /// No description provided for @accountDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Your account has been disabled. Contact support.'**
  String get accountDisabledBody;

  /// No description provided for @clinicNotActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinic account not active'**
  String get clinicNotActiveTitle;

  /// No description provided for @clinicNotActiveBody.
  ///
  /// In en, this message translates to:
  /// **'The clinic account is not active. Contact the doctor.'**
  String get clinicNotActiveBody;

  /// No description provided for @supportTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get supportTitle;

  /// No description provided for @supportWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get supportWhatsapp;

  /// No description provided for @supportCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get supportCall;

  /// No description provided for @supportEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get supportEmail;

  /// No description provided for @updateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateTitle;

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'This version of el3yada is no longer supported. Update the app to keep using it.'**
  String get updateBody;

  /// No description provided for @updateButton.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateButton;

  /// No description provided for @updateNoLink.
  ///
  /// In en, this message translates to:
  /// **'Get the latest version from where you installed the app.'**
  String get updateNoLink;

  /// No description provided for @appVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersionLabel(String version);

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be right back'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'el3yada is under maintenance. Try again in a little while.'**
  String get maintenanceBody;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retryButton;

  /// No description provided for @adminSignIn.
  ///
  /// In en, this message translates to:
  /// **'Admin sign in'**
  String get adminSignIn;

  /// No description provided for @forgotHaveCode.
  ///
  /// In en, this message translates to:
  /// **'I have a code'**
  String get forgotHaveCode;

  /// No description provided for @resetCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from the email and choose a new password.'**
  String get resetCodeBody;

  /// No description provided for @resetCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code from the email'**
  String get resetCodeLabel;

  /// No description provided for @resetDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get resetDoneTitle;

  /// No description provided for @resetDoneBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your new password. Other devices were signed out.'**
  String get resetDoneBody;

  /// No description provided for @errorEmailTokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'This code isn\'t valid. Check it and try again.'**
  String get errorEmailTokenInvalid;

  /// No description provided for @errorEmailTokenExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Ask for a new email.'**
  String get errorEmailTokenExpired;

  /// No description provided for @errorEmailTokenUsed.
  ///
  /// In en, this message translates to:
  /// **'This code was already used. Ask for a new email.'**
  String get errorEmailTokenUsed;

  /// A4 app bar. Keys starting with reg belong to the doctor registration screens A4–A7.
  ///
  /// In en, this message translates to:
  /// **'Doctor registration'**
  String get regTitle;

  /// No description provided for @regResubmitTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit registration'**
  String get regResubmitTitle;

  /// No description provided for @regStepAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get regStepAccount;

  /// No description provided for @regStepProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional details'**
  String get regStepProfessional;

  /// No description provided for @regStepBranch.
  ///
  /// In en, this message translates to:
  /// **'First branch'**
  String get regStepBranch;

  /// No description provided for @regStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review and send'**
  String get regStepReview;

  /// No description provided for @regStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {count}'**
  String regStepOf(int step, int count);

  /// Screen reader label of the A4 progress bar.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {count}: {name}'**
  String regStepSemantics(int step, int count, String name);

  /// No description provided for @regNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get regNext;

  /// No description provided for @regBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get regBack;

  /// No description provided for @regSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get regSubmit;

  /// No description provided for @regResubmit.
  ///
  /// In en, this message translates to:
  /// **'Send again for review'**
  String get regResubmit;

  /// No description provided for @regFixErrors.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields.'**
  String get regFixErrors;

  /// No description provided for @regAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get regAccountSection;

  /// No description provided for @regAccountIntro.
  ///
  /// In en, this message translates to:
  /// **'You\'ll sign in with this email or mobile number.'**
  String get regAccountIntro;

  /// No description provided for @regPasswordSection.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get regPasswordSection;

  /// No description provided for @regFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get regFullNameLabel;

  /// No description provided for @regFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'As on your syndicate card, at least two names'**
  String get regFullNameHint;

  /// No description provided for @regEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get regEmailLabel;

  /// No description provided for @regMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get regMobileLabel;

  /// No description provided for @regProfessionalSection.
  ///
  /// In en, this message translates to:
  /// **'Your practice'**
  String get regProfessionalSection;

  /// No description provided for @regTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get regTitleLabel;

  /// No description provided for @regTitleOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get regTitleOther;

  /// No description provided for @regTitleOtherLabel.
  ///
  /// In en, this message translates to:
  /// **'Your title'**
  String get regTitleOtherLabel;

  /// No description provided for @regSpecialtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary specialty'**
  String get regSpecialtyLabel;

  /// No description provided for @regSpecialtyChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose your specialty'**
  String get regSpecialtyChoose;

  /// No description provided for @regSpecialtyHint.
  ///
  /// In en, this message translates to:
  /// **'Your specialty\'s medicines and tests will appear first when you search.'**
  String get regSpecialtyHint;

  /// No description provided for @regSpecialtiesError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the specialties.'**
  String get regSpecialtiesError;

  /// No description provided for @regExtraSpecialtiesLabel.
  ///
  /// In en, this message translates to:
  /// **'Other specialties (optional, up to 2)'**
  String get regExtraSpecialtiesLabel;

  /// No description provided for @regExtraSpecialtiesShort.
  ///
  /// In en, this message translates to:
  /// **'Other specialties'**
  String get regExtraSpecialtiesShort;

  /// No description provided for @regAddSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Add a specialty'**
  String get regAddSpecialty;

  /// No description provided for @regRemoveSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String regRemoveSpecialty(String name);

  /// No description provided for @regSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get regSearchHint;

  /// No description provided for @regClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get regClearSearch;

  /// No description provided for @regNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search.'**
  String get regNoResults;

  /// No description provided for @regSyndicateSection.
  ///
  /// In en, this message translates to:
  /// **'Medical syndicate'**
  String get regSyndicateSection;

  /// No description provided for @regLicenseNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Syndicate number'**
  String get regLicenseNumberLabel;

  /// No description provided for @regLicenseFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Syndicate card or license'**
  String get regLicenseFileLabel;

  /// No description provided for @regLicenseFileShort.
  ///
  /// In en, this message translates to:
  /// **'Syndicate card'**
  String get regLicenseFileShort;

  /// No description provided for @regLicenseFileHint.
  ///
  /// In en, this message translates to:
  /// **'A clear photo or a PDF, up to 10 MB'**
  String get regLicenseFileHint;

  /// No description provided for @regLicenseReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get regLicenseReplace;

  /// No description provided for @regLicenseUndo.
  ///
  /// In en, this message translates to:
  /// **'Keep the current file'**
  String get regLicenseUndo;

  /// No description provided for @regLicenseCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current file'**
  String get regLicenseCurrent;

  /// No description provided for @regLicenseKept.
  ///
  /// In en, this message translates to:
  /// **'kept unless you replace it'**
  String get regLicenseKept;

  /// No description provided for @regLicenseImage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get regLicenseImage;

  /// No description provided for @regLicensePdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get regLicensePdf;

  /// No description provided for @regLicenseOpen.
  ///
  /// In en, this message translates to:
  /// **'Open the photo of the syndicate card'**
  String get regLicenseOpen;

  /// No description provided for @regSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get regSourceCamera;

  /// No description provided for @regSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from your photos'**
  String get regSourceGallery;

  /// No description provided for @regSourceFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose a file (photo or PDF)'**
  String get regSourceFiles;

  /// No description provided for @regFileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{size} KB'**
  String regFileSizeKb(int size);

  /// No description provided for @regFileSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{size} MB'**
  String regFileSizeMb(String size);

  /// No description provided for @regBranchSection.
  ///
  /// In en, this message translates to:
  /// **'Branch details'**
  String get regBranchSection;

  /// No description provided for @regBranchIntro.
  ///
  /// In en, this message translates to:
  /// **'Patients will see this branch. You can add more branches after approval.'**
  String get regBranchIntro;

  /// No description provided for @regBranchNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Branch name'**
  String get regBranchNameLabel;

  /// No description provided for @regBranchNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Maadi branch'**
  String get regBranchNameHint;

  /// No description provided for @regGovernorateLabel.
  ///
  /// In en, this message translates to:
  /// **'Governorate'**
  String get regGovernorateLabel;

  /// No description provided for @regGovernorateChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose the governorate'**
  String get regGovernorateChoose;

  /// No description provided for @regCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City or area'**
  String get regCityLabel;

  /// No description provided for @regStreetLabel.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get regStreetLabel;

  /// No description provided for @regBuildingLabel.
  ///
  /// In en, this message translates to:
  /// **'Building'**
  String get regBuildingLabel;

  /// No description provided for @regFloorLabel.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get regFloorLabel;

  /// No description provided for @regApartmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get regApartmentLabel;

  /// No description provided for @regLandmarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get regLandmarkLabel;

  /// No description provided for @regLandmarkHint.
  ///
  /// In en, this message translates to:
  /// **'For example: next to the metro station'**
  String get regLandmarkHint;

  /// No description provided for @regPhonesSection.
  ///
  /// In en, this message translates to:
  /// **'Clinic phone numbers'**
  String get regPhonesSection;

  /// No description provided for @regPhonesHint.
  ///
  /// In en, this message translates to:
  /// **'1 to 5 numbers: mobile, landline or hotline.'**
  String get regPhonesHint;

  /// No description provided for @regPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Number {index}'**
  String regPhoneLabel(int index);

  /// No description provided for @regPhoneType.
  ///
  /// In en, this message translates to:
  /// **'Number type'**
  String get regPhoneType;

  /// No description provided for @regPhoneTypeReception.
  ///
  /// In en, this message translates to:
  /// **'Reception'**
  String get regPhoneTypeReception;

  /// No description provided for @regPhoneTypeMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get regPhoneTypeMobile;

  /// No description provided for @regPhoneTypeLandline.
  ///
  /// In en, this message translates to:
  /// **'Landline'**
  String get regPhoneTypeLandline;

  /// No description provided for @regPhoneWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get regPhoneWhatsapp;

  /// No description provided for @regAddPhone.
  ///
  /// In en, this message translates to:
  /// **'Add a number'**
  String get regAddPhone;

  /// No description provided for @regRemovePhone.
  ///
  /// In en, this message translates to:
  /// **'Remove this number'**
  String get regRemovePhone;

  /// No description provided for @regPricesSection.
  ///
  /// In en, this message translates to:
  /// **'Visit prices (optional)'**
  String get regPricesSection;

  /// No description provided for @regPricesHint.
  ///
  /// In en, this message translates to:
  /// **'Patients see these prices. You can change them later in Settings.'**
  String get regPricesHint;

  /// No description provided for @regExaminationPrice.
  ///
  /// In en, this message translates to:
  /// **'Examination'**
  String get regExaminationPrice;

  /// No description provided for @regConsultationPrice.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get regConsultationPrice;

  /// No description provided for @regCurrency.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get regCurrency;

  /// A price. amount has Western digits in both languages.
  ///
  /// In en, this message translates to:
  /// **'EGP {amount}'**
  String regPriceValue(String amount);

  /// No description provided for @regReviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Check your details, then send them for review.'**
  String get regReviewIntro;

  /// No description provided for @regReviewIntroResubmit.
  ///
  /// In en, this message translates to:
  /// **'Check your changes, then send them for review again.'**
  String get regReviewIntroResubmit;

  /// No description provided for @regEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get regEdit;

  /// No description provided for @regEditSection.
  ///
  /// In en, this message translates to:
  /// **'Edit {section}'**
  String regEditSection(String section);

  /// No description provided for @regNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get regNotSet;

  /// No description provided for @regAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get regAddressLabel;

  /// No description provided for @regLandmarkShort.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get regLandmarkShort;

  /// No description provided for @regPhonesLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone numbers'**
  String get regPhonesLabel;

  /// No description provided for @regBuildingValue.
  ///
  /// In en, this message translates to:
  /// **'Building {value}'**
  String regBuildingValue(String value);

  /// No description provided for @regFloorValue.
  ///
  /// In en, this message translates to:
  /// **'Floor {value}'**
  String regFloorValue(String value);

  /// No description provided for @regApartmentValue.
  ///
  /// In en, this message translates to:
  /// **'Apartment {value}'**
  String regApartmentValue(String value);

  /// No description provided for @regListSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get regListSeparator;

  /// No description provided for @regErrorTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose your title, or type it.'**
  String get regErrorTitleRequired;

  /// No description provided for @regErrorSpecialtyRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose your specialty.'**
  String get regErrorSpecialtyRequired;

  /// No description provided for @regErrorInvalidSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Choose a specialty from the list.'**
  String get regErrorInvalidSpecialty;

  /// No description provided for @regErrorLicenseNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'The syndicate number is required.'**
  String get regErrorLicenseNumberRequired;

  /// No description provided for @regErrorInvalidLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter the syndicate number: 3 to 20 letters or digits.'**
  String get regErrorInvalidLicenseNumber;

  /// No description provided for @regErrorLicenseRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of your syndicate card or license.'**
  String get regErrorLicenseRequired;

  /// No description provided for @regErrorFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than 10 MB. Choose a smaller one.'**
  String get regErrorFileTooLarge;

  /// No description provided for @regErrorFileType.
  ///
  /// In en, this message translates to:
  /// **'Use a photo (JPEG, PNG or WebP) or a PDF.'**
  String get regErrorFileType;

  /// No description provided for @regErrorFileContent.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be read. Try another one.'**
  String get regErrorFileContent;

  /// No description provided for @regErrorPickFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open it. Check the app\'s permissions and try again.'**
  String get regErrorPickFailed;

  /// No description provided for @regErrorGovernorateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the governorate.'**
  String get regErrorGovernorateRequired;

  /// No description provided for @regErrorBranchName.
  ///
  /// In en, this message translates to:
  /// **'Use 2 to 60 characters.'**
  String get regErrorBranchName;

  /// No description provided for @regErrorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Egyptian number: mobile, landline or hotline.'**
  String get regErrorInvalidPhone;

  /// No description provided for @regErrorPhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one phone number.'**
  String get regErrorPhoneRequired;

  /// No description provided for @regErrorPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount from 0 to 100,000, with at most 2 decimals.'**
  String get regErrorPrice;

  /// No description provided for @regErrorNotEditable.
  ///
  /// In en, this message translates to:
  /// **'This registration can\'t be edited now.'**
  String get regErrorNotEditable;

  /// No description provided for @regErrorResendCooldown.
  ///
  /// In en, this message translates to:
  /// **'Wait a minute before sending another email.'**
  String get regErrorResendCooldown;

  /// No description provided for @regPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account is being reviewed'**
  String get regPendingTitle;

  /// No description provided for @regPendingBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll get a notification once it\'s approved.'**
  String get regPendingBody;

  /// No description provided for @regRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get regRefresh;

  /// No description provided for @regStillPending.
  ///
  /// In en, this message translates to:
  /// **'Still under review. We\'ll notify you once it\'s approved.'**
  String get regStillPending;

  /// No description provided for @regSubmittedData.
  ///
  /// In en, this message translates to:
  /// **'What you sent'**
  String get regSubmittedData;

  /// No description provided for @regSubmittedOn.
  ///
  /// In en, this message translates to:
  /// **'Sent on {date}'**
  String regSubmittedOn(String date);

  /// No description provided for @regDataError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your details.'**
  String get regDataError;

  /// No description provided for @regVerifyCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get regVerifyCardTitle;

  /// No description provided for @regVerifyCardBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a link to {email}.'**
  String regVerifyCardBody(String email);

  /// No description provided for @regRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your registration wasn\'t approved'**
  String get regRejectedTitle;

  /// No description provided for @regRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Fix what the review team asked for, then send your registration again.'**
  String get regRejectedBody;

  /// No description provided for @regRejectedReason.
  ///
  /// In en, this message translates to:
  /// **'Reason from the review team'**
  String get regRejectedReason;

  /// No description provided for @regRejectedNoReason.
  ///
  /// In en, this message translates to:
  /// **'No reason was given. Contact support to find out more.'**
  String get regRejectedNoReason;

  /// No description provided for @regEditAndResubmit.
  ///
  /// In en, this message translates to:
  /// **'Edit and resubmit'**
  String get regEditAndResubmit;

  /// No description provided for @regVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get regVerifyTitle;

  /// No description provided for @regVerifySentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to'**
  String get regVerifySentTo;

  /// No description provided for @regVerifyBody.
  ///
  /// In en, this message translates to:
  /// **'Open the link in the email. If it opens in a browser instead of the app, copy the code from the email and paste it here.'**
  String get regVerifyBody;

  /// No description provided for @regVerifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get regVerifyButton;

  /// No description provided for @regVerifiedCheck.
  ///
  /// In en, this message translates to:
  /// **'I\'ve verified'**
  String get regVerifiedCheck;

  /// No description provided for @regResend.
  ///
  /// In en, this message translates to:
  /// **'Resend the email'**
  String get regResend;

  /// No description provided for @regResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} s'**
  String regResendIn(int seconds);

  /// No description provided for @regResent.
  ///
  /// In en, this message translates to:
  /// **'Sent. Check your inbox and your spam folder.'**
  String get regResent;

  /// No description provided for @regNotVerifiedYet.
  ///
  /// In en, this message translates to:
  /// **'Not verified yet. Open the link in the email, then try again.'**
  String get regNotVerifiedYet;

  /// No description provided for @regVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get regVerifiedTitle;

  /// No description provided for @regVerifiedBody.
  ///
  /// In en, this message translates to:
  /// **'Thank you. Your email address is confirmed.'**
  String get regVerifiedBody;

  /// Admin top-bar button and AD18 title.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get adminMyProfile;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get adminClose;

  /// No description provided for @adminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminSave;

  /// No description provided for @adminRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get adminRefresh;

  /// No description provided for @adminRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Showing the last list.'**
  String get adminRefreshFailed;

  /// Between items of a list in a sentence.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get adminListSeparator;

  /// No description provided for @adminNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get adminNotProvided;

  /// No description provided for @adminSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get adminSystem;

  /// No description provided for @adminUnknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get adminUnknownUser;

  /// Coral mark on a sign-up request sent in the last day.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get adminNew;

  /// No description provided for @adminDoctorName.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name}'**
  String adminDoctorName(String name);

  /// No description provided for @adminJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get adminJustNow;

  /// No description provided for @adminMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String adminMinutesAgo(int count);

  /// No description provided for @adminHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String adminHoursAgo(int count);

  /// No description provided for @adminDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String adminDaysAgo(int count);

  /// No description provided for @adminMoneyEgp.
  ///
  /// In en, this message translates to:
  /// **'EGP {amount}'**
  String adminMoneyEgp(String amount);

  /// No description provided for @adminCurrency.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get adminCurrency;

  /// No description provided for @adminUnitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get adminUnitDays;

  /// No description provided for @adminUnitMb.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get adminUnitMb;

  /// No description provided for @adminStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get adminStatusPending;

  /// No description provided for @adminStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminStatusActive;

  /// No description provided for @adminStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adminStatusRejected;

  /// No description provided for @adminStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get adminStatusSuspended;

  /// No description provided for @adminStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get adminStatusDisabled;

  /// No description provided for @adminRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRoleAdmin;

  /// No description provided for @adminRoleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super admin'**
  String get adminRoleSuperAdmin;

  /// No description provided for @adminEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'(empty)'**
  String get adminEmptyValue;

  /// No description provided for @adminOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get adminOn;

  /// No description provided for @adminOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get adminOff;

  /// No description provided for @adminErrorOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'This value is out of the allowed range.'**
  String get adminErrorOutOfRange;

  /// No description provided for @adminErrorInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'This value isn\'t valid.'**
  String get adminErrorInvalidValue;

  /// No description provided for @adminErrorInvalidVersion.
  ///
  /// In en, this message translates to:
  /// **'Write the version like 1.2.3.'**
  String get adminErrorInvalidVersion;

  /// No description provided for @adminErrorUnknownSetting.
  ///
  /// In en, this message translates to:
  /// **'This setting doesn\'t exist any more. Update the app.'**
  String get adminErrorUnknownSetting;

  /// No description provided for @adminErrorInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Write at least a first and a last name, in letters only.'**
  String get adminErrorInvalidName;

  /// No description provided for @adminErrorReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Write the reason (at least 3 characters).'**
  String get adminErrorReasonRequired;

  /// No description provided for @adminErrorRegistrationNotPending.
  ///
  /// In en, this message translates to:
  /// **'This request was already reviewed, maybe by another admin.'**
  String get adminErrorRegistrationNotPending;

  /// No description provided for @adminErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists.'**
  String get adminErrorEmailTaken;

  /// No description provided for @adminErrorLicenseMissing.
  ///
  /// In en, this message translates to:
  /// **'The syndicate card file is missing on the server. Ask the doctor to upload it again.'**
  String get adminErrorLicenseMissing;

  /// No description provided for @adminErrorOwnRole.
  ///
  /// In en, this message translates to:
  /// **'You can\'t change your own role.'**
  String get adminErrorOwnRole;

  /// No description provided for @adminErrorDisableSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t disable your own account.'**
  String get adminErrorDisableSelf;

  /// No description provided for @adminErrorLastSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'There must always be at least one active super admin.'**
  String get adminErrorLastSuperAdmin;

  /// No description provided for @adminErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item doesn\'t exist any more.'**
  String get adminErrorNotFound;

  /// No description provided for @adminErrorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get adminErrorForbidden;

  /// No description provided for @adminErrorAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount in EGP, with at most 2 decimals.'**
  String get adminErrorAmount;

  /// No description provided for @adminErrorWholeNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number.'**
  String get adminErrorWholeNumber;

  /// No description provided for @adminErrorRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {min} to {max}.'**
  String adminErrorRange(String min, String max);

  /// No description provided for @adminErrorMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Use at most {max} characters.'**
  String adminErrorMaxLength(String max);

  /// No description provided for @adminErrorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile, landline or hotline number.'**
  String get adminErrorInvalidPhone;

  /// No description provided for @adminErrorInvalidWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid mobile number (international numbers start with +).'**
  String get adminErrorInvalidWhatsapp;

  /// No description provided for @adminFixErrors.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted fields, then save.'**
  String get adminFixErrors;

  /// No description provided for @adminSignupsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No requests waiting} =1{1 request waiting} other{{count} requests waiting}}'**
  String adminSignupsCount(int count);

  /// No description provided for @adminSignupsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, email, mobile or number'**
  String get adminSignupsSearchHint;

  /// No description provided for @adminClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get adminClearSearch;

  /// No description provided for @adminSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get adminSort;

  /// No description provided for @adminSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get adminSortNewest;

  /// No description provided for @adminSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first (queue order)'**
  String get adminSortOldest;

  /// No description provided for @adminSignupsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sign-up requests waiting'**
  String get adminSignupsEmptyTitle;

  /// No description provided for @adminSignupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New doctors\' requests show up here as soon as they register.'**
  String get adminSignupsEmptyBody;

  /// No description provided for @adminSignupsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No requests match your search'**
  String get adminSignupsNoMatchTitle;

  /// No description provided for @adminSignupsNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or search by mobile or syndicate number.'**
  String get adminSignupsNoMatchBody;

  /// No description provided for @adminSelectRequest.
  ///
  /// In en, this message translates to:
  /// **'Choose a request to review it'**
  String get adminSelectRequest;

  /// No description provided for @adminSubmittedShort.
  ///
  /// In en, this message translates to:
  /// **'sent {time}'**
  String adminSubmittedShort(String time);

  /// No description provided for @adminReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-up request'**
  String get adminReviewTitle;

  /// No description provided for @adminSubmittedAt.
  ///
  /// In en, this message translates to:
  /// **'Sent {relative} · {date}'**
  String adminSubmittedAt(String relative, String date);

  /// No description provided for @adminResubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sent again'**
  String get adminResubmitted;

  /// No description provided for @adminEmailNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed'**
  String get adminEmailNotVerified;

  /// No description provided for @adminEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get adminEmailVerified;

  /// No description provided for @adminPreviousRejection.
  ///
  /// In en, this message translates to:
  /// **'Rejected before because'**
  String get adminPreviousRejection;

  /// No description provided for @adminSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminSectionAccount;

  /// No description provided for @adminSectionProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional details'**
  String get adminSectionProfessional;

  /// No description provided for @adminSectionBranch.
  ///
  /// In en, this message translates to:
  /// **'Clinic (first branch)'**
  String get adminSectionBranch;

  /// No description provided for @adminSectionPrices.
  ///
  /// In en, this message translates to:
  /// **'Visit prices'**
  String get adminSectionPrices;

  /// No description provided for @adminSectionReviews.
  ///
  /// In en, this message translates to:
  /// **'Earlier reviews'**
  String get adminSectionReviews;

  /// No description provided for @adminFieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get adminFieldFullName;

  /// No description provided for @adminFieldFullNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name in English'**
  String get adminFieldFullNameEn;

  /// No description provided for @adminFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get adminFieldEmail;

  /// No description provided for @adminFieldMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get adminFieldMobile;

  /// No description provided for @adminFieldLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get adminFieldLanguage;

  /// No description provided for @adminFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminFieldTitle;

  /// No description provided for @adminFieldTitleEn.
  ///
  /// In en, this message translates to:
  /// **'Title in English'**
  String get adminFieldTitleEn;

  /// No description provided for @adminFieldSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get adminFieldSpecialty;

  /// No description provided for @adminFieldExtraSpecialties.
  ///
  /// In en, this message translates to:
  /// **'Other specialties'**
  String get adminFieldExtraSpecialties;

  /// No description provided for @adminFieldLicenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Syndicate number'**
  String get adminFieldLicenseNumber;

  /// No description provided for @adminFieldDegreesAr.
  ///
  /// In en, this message translates to:
  /// **'Degrees (Arabic)'**
  String get adminFieldDegreesAr;

  /// No description provided for @adminFieldDegreesEn.
  ///
  /// In en, this message translates to:
  /// **'Degrees (English)'**
  String get adminFieldDegreesEn;

  /// No description provided for @adminFieldBranchName.
  ///
  /// In en, this message translates to:
  /// **'Branch name'**
  String get adminFieldBranchName;

  /// No description provided for @adminFieldBranchNameEn.
  ///
  /// In en, this message translates to:
  /// **'Branch name in English'**
  String get adminFieldBranchNameEn;

  /// No description provided for @adminFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get adminFieldAddress;

  /// No description provided for @adminFieldLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get adminFieldLandmark;

  /// No description provided for @adminFieldBranchEmail.
  ///
  /// In en, this message translates to:
  /// **'Clinic email'**
  String get adminFieldBranchEmail;

  /// No description provided for @adminFieldPhones.
  ///
  /// In en, this message translates to:
  /// **'Phone numbers'**
  String get adminFieldPhones;

  /// No description provided for @adminFieldExamPrice.
  ///
  /// In en, this message translates to:
  /// **'Examination'**
  String get adminFieldExamPrice;

  /// No description provided for @adminFieldConsultPrice.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get adminFieldConsultPrice;

  /// No description provided for @adminAddressBuilding.
  ///
  /// In en, this message translates to:
  /// **'Building {value}'**
  String adminAddressBuilding(String value);

  /// No description provided for @adminAddressFloor.
  ///
  /// In en, this message translates to:
  /// **'Floor {value}'**
  String adminAddressFloor(String value);

  /// No description provided for @adminAddressApartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment {value}'**
  String adminAddressApartment(String value);

  /// No description provided for @adminPhoneMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get adminPhoneMobile;

  /// No description provided for @adminPhoneLandline.
  ///
  /// In en, this message translates to:
  /// **'Landline'**
  String get adminPhoneLandline;

  /// No description provided for @adminPhoneReception.
  ///
  /// In en, this message translates to:
  /// **'Reception'**
  String get adminPhoneReception;

  /// No description provided for @adminOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open the location on the map'**
  String get adminOpenMap;

  /// No description provided for @adminReviewApprovedBy.
  ///
  /// In en, this message translates to:
  /// **'Approved by {name}'**
  String adminReviewApprovedBy(String name);

  /// No description provided for @adminReviewRejectedBy.
  ///
  /// In en, this message translates to:
  /// **'Rejected by {name}'**
  String adminReviewRejectedBy(String name);

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Check the syndicate card against the name and number before you decide.'**
  String get adminReviewHint;

  /// No description provided for @adminApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Dr. {name}?'**
  String adminApproveTitle(String name);

  /// No description provided for @adminApproveBody.
  ///
  /// In en, this message translates to:
  /// **'The account becomes active and the doctor is notified. They can start using el3yada right away.'**
  String get adminApproveBody;

  /// No description provided for @adminApprovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name} is approved and can now use el3yada.'**
  String adminApprovedMessage(String name);

  /// No description provided for @adminRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Dr. {name}\'s sign-up?'**
  String adminRejectTitle(String name);

  /// No description provided for @adminRejectBody.
  ///
  /// In en, this message translates to:
  /// **'The doctor sees this reason, can correct their details and send the request again.'**
  String get adminRejectBody;

  /// No description provided for @adminRejectReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adminRejectReasonLabel;

  /// No description provided for @adminRejectPresets.
  ///
  /// In en, this message translates to:
  /// **'Common reasons'**
  String get adminRejectPresets;

  /// No description provided for @adminRejectPresetLicense.
  ///
  /// In en, this message translates to:
  /// **'The syndicate card photo isn\'t clear. Upload a clearer photo.'**
  String get adminRejectPresetLicense;

  /// No description provided for @adminRejectPresetNumber.
  ///
  /// In en, this message translates to:
  /// **'The syndicate number doesn\'t match the card.'**
  String get adminRejectPresetNumber;

  /// No description provided for @adminRejectPresetBranch.
  ///
  /// In en, this message translates to:
  /// **'The clinic address or phone number is incomplete.'**
  String get adminRejectPresetBranch;

  /// No description provided for @adminRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name}\'s sign-up was rejected. They\'ll see your reason.'**
  String adminRejectedMessage(String name);

  /// No description provided for @adminLicenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Syndicate card'**
  String get adminLicenseTitle;

  /// No description provided for @adminLicenseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Compare the name and number with the details below.'**
  String get adminLicenseSubtitle;

  /// No description provided for @adminLicenseImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Syndicate card photo. Open it to zoom.'**
  String get adminLicenseImageLabel;

  /// No description provided for @adminLicenseImageOf.
  ///
  /// In en, this message translates to:
  /// **'Syndicate card of Dr. {name}'**
  String adminLicenseImageOf(String name);

  /// No description provided for @adminLicenseZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get adminLicenseZoom;

  /// No description provided for @adminLicensePdf.
  ///
  /// In en, this message translates to:
  /// **'Syndicate card (PDF)'**
  String get adminLicensePdf;

  /// No description provided for @adminLicenseFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get adminLicenseFile;

  /// Start of the temporary file name of a downloaded license.
  ///
  /// In en, this message translates to:
  /// **'license'**
  String get adminLicenseFileName;

  /// No description provided for @adminLicenseOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminLicenseOpen;

  /// No description provided for @adminLicenseCantOpen.
  ///
  /// In en, this message translates to:
  /// **'This device can\'t open the file here. Open it from the computer app.'**
  String get adminLicenseCantOpen;

  /// No description provided for @adminFileSizeKb.
  ///
  /// In en, this message translates to:
  /// **'{kb} KB'**
  String adminFileSizeKb(int kb);

  /// No description provided for @adminZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get adminZoomIn;

  /// No description provided for @adminZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get adminZoomOut;

  /// No description provided for @adminZoomReset.
  ///
  /// In en, this message translates to:
  /// **'Fit to screen'**
  String get adminZoomReset;

  /// No description provided for @adminSettingsLastChange.
  ///
  /// In en, this message translates to:
  /// **'Last changed by {name} · {time}'**
  String adminSettingsLastChange(String name, String time);

  /// No description provided for @adminGroupBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get adminGroupBilling;

  /// No description provided for @adminGroupBillingBody.
  ///
  /// In en, this message translates to:
  /// **'Platform fees for each visit, and the payment rules.'**
  String get adminGroupBillingBody;

  /// No description provided for @adminGroupPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get adminGroupPayment;

  /// No description provided for @adminGroupPaymentBody.
  ///
  /// In en, this message translates to:
  /// **'Where doctors send their payments. Shown on the billing screen.'**
  String get adminGroupPaymentBody;

  /// No description provided for @adminGroupFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get adminGroupFiles;

  /// No description provided for @adminGroupFilesBody.
  ///
  /// In en, this message translates to:
  /// **'Upload limit for medical files.'**
  String get adminGroupFilesBody;

  /// No description provided for @adminGroupClinics.
  ///
  /// In en, this message translates to:
  /// **'Clinics'**
  String get adminGroupClinics;

  /// No description provided for @adminGroupClinicsBody.
  ///
  /// In en, this message translates to:
  /// **'Limits for each doctor\'s clinic.'**
  String get adminGroupClinicsBody;

  /// No description provided for @adminGroupVersions.
  ///
  /// In en, this message translates to:
  /// **'Minimum app versions'**
  String get adminGroupVersions;

  /// No description provided for @adminGroupVersionsBody.
  ///
  /// In en, this message translates to:
  /// **'Older apps must be updated before they open.'**
  String get adminGroupVersionsBody;

  /// No description provided for @adminGroupMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get adminGroupMaintenance;

  /// No description provided for @adminGroupMaintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'Close the app for everyone except admins, with your message.'**
  String get adminGroupMaintenanceBody;

  /// No description provided for @adminGroupSupport.
  ///
  /// In en, this message translates to:
  /// **'Support contact'**
  String get adminGroupSupport;

  /// No description provided for @adminGroupSupportBody.
  ///
  /// In en, this message translates to:
  /// **'Shown on the disabled, pending and maintenance screens.'**
  String get adminGroupSupportBody;

  /// No description provided for @adminGroupLegal.
  ///
  /// In en, this message translates to:
  /// **'Terms and Privacy'**
  String get adminGroupLegal;

  /// No description provided for @adminGroupLegalBody.
  ///
  /// In en, this message translates to:
  /// **'Patients accept these at their first sign-in. If one language is empty, the other one shows.'**
  String get adminGroupLegalBody;

  /// No description provided for @adminSettingExamFee.
  ///
  /// In en, this message translates to:
  /// **'Examination fee'**
  String get adminSettingExamFee;

  /// No description provided for @adminSettingConsultationFee.
  ///
  /// In en, this message translates to:
  /// **'Consultation fee'**
  String get adminSettingConsultationFee;

  /// No description provided for @adminSettingGracePeriod.
  ///
  /// In en, this message translates to:
  /// **'Grace period'**
  String get adminSettingGracePeriod;

  /// No description provided for @adminSettingMaxConsultations.
  ///
  /// In en, this message translates to:
  /// **'Consultations in a row (maximum)'**
  String get adminSettingMaxConsultations;

  /// No description provided for @adminSettingInstapayAddress.
  ///
  /// In en, this message translates to:
  /// **'InstaPay address'**
  String get adminSettingInstapayAddress;

  /// No description provided for @adminSettingInstapayName.
  ///
  /// In en, this message translates to:
  /// **'InstaPay account name'**
  String get adminSettingInstapayName;

  /// No description provided for @adminSettingInstapayInstructionsAr.
  ///
  /// In en, this message translates to:
  /// **'Payment instructions (Arabic)'**
  String get adminSettingInstapayInstructionsAr;

  /// No description provided for @adminSettingInstapayInstructionsEn.
  ///
  /// In en, this message translates to:
  /// **'Payment instructions (English)'**
  String get adminSettingInstapayInstructionsEn;

  /// No description provided for @adminSettingMaxUpload.
  ///
  /// In en, this message translates to:
  /// **'Maximum file size'**
  String get adminSettingMaxUpload;

  /// No description provided for @adminSettingMaxAssistants.
  ///
  /// In en, this message translates to:
  /// **'Assistants per doctor (maximum)'**
  String get adminSettingMaxAssistants;

  /// No description provided for @adminSettingMaxBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches per doctor (maximum)'**
  String get adminSettingMaxBranches;

  /// No description provided for @adminSettingVersionAndroid.
  ///
  /// In en, this message translates to:
  /// **'Minimum Android version'**
  String get adminSettingVersionAndroid;

  /// No description provided for @adminSettingVersionIos.
  ///
  /// In en, this message translates to:
  /// **'Minimum iOS version'**
  String get adminSettingVersionIos;

  /// No description provided for @adminSettingVersionWindows.
  ///
  /// In en, this message translates to:
  /// **'Minimum Windows version'**
  String get adminSettingVersionWindows;

  /// No description provided for @adminSettingVersionMacos.
  ///
  /// In en, this message translates to:
  /// **'Minimum macOS version'**
  String get adminSettingVersionMacos;

  /// No description provided for @adminSettingMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance mode'**
  String get adminSettingMaintenance;

  /// No description provided for @adminSettingMaintenanceMessageAr.
  ///
  /// In en, this message translates to:
  /// **'Maintenance message (Arabic)'**
  String get adminSettingMaintenanceMessageAr;

  /// No description provided for @adminSettingMaintenanceMessageEn.
  ///
  /// In en, this message translates to:
  /// **'Maintenance message (English)'**
  String get adminSettingMaintenanceMessageEn;

  /// No description provided for @adminSettingSupportPhone.
  ///
  /// In en, this message translates to:
  /// **'Support phone'**
  String get adminSettingSupportPhone;

  /// No description provided for @adminSettingSupportWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Support WhatsApp'**
  String get adminSettingSupportWhatsapp;

  /// No description provided for @adminSettingSupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Support email'**
  String get adminSettingSupportEmail;

  /// No description provided for @adminSettingTermsAr.
  ///
  /// In en, this message translates to:
  /// **'Terms of use (Arabic)'**
  String get adminSettingTermsAr;

  /// No description provided for @adminSettingTermsEn.
  ///
  /// In en, this message translates to:
  /// **'Terms of use (English)'**
  String get adminSettingTermsEn;

  /// No description provided for @adminSettingPrivacyAr.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy (Arabic)'**
  String get adminSettingPrivacyAr;

  /// No description provided for @adminSettingPrivacyEn.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy (English)'**
  String get adminSettingPrivacyEn;

  /// No description provided for @adminRangeHint.
  ///
  /// In en, this message translates to:
  /// **'From {min} to {max}'**
  String adminRangeHint(String min, String max);

  /// No description provided for @adminVersionHint.
  ///
  /// In en, this message translates to:
  /// **'Like 1.2.0'**
  String get adminVersionHint;

  /// No description provided for @adminPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Mobile, landline or hotline'**
  String get adminPhoneHint;

  /// No description provided for @adminWhatsappHint.
  ///
  /// In en, this message translates to:
  /// **'Egyptian number, or international starting with +'**
  String get adminWhatsappHint;

  /// No description provided for @adminAppliesToNewSessions.
  ///
  /// In en, this message translates to:
  /// **'Applies to new sessions only'**
  String get adminAppliesToNewSessions;

  /// No description provided for @adminAppliesToNewInvoices.
  ///
  /// In en, this message translates to:
  /// **'Applies to new invoices only'**
  String get adminAppliesToNewInvoices;

  /// No description provided for @adminWasValue.
  ///
  /// In en, this message translates to:
  /// **'Saved value: {value}'**
  String adminWasValue(String value);

  /// No description provided for @adminCharacterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max}'**
  String adminCharacterCount(String count, String max);

  /// No description provided for @adminFieldHistory.
  ///
  /// In en, this message translates to:
  /// **'Change history: {field}'**
  String adminFieldHistory(String field);

  /// No description provided for @adminMaintenanceOn.
  ///
  /// In en, this message translates to:
  /// **'On: everyone except admins sees the maintenance screen.'**
  String get adminMaintenanceOn;

  /// No description provided for @adminMaintenanceOff.
  ///
  /// In en, this message translates to:
  /// **'Off: the app is open for everyone.'**
  String get adminMaintenanceOff;

  /// No description provided for @adminMaintenanceWillStart.
  ///
  /// In en, this message translates to:
  /// **'Maintenance starts as soon as you save.'**
  String get adminMaintenanceWillStart;

  /// No description provided for @adminMaintenanceWillEnd.
  ///
  /// In en, this message translates to:
  /// **'The app opens for everyone as soon as you save.'**
  String get adminMaintenanceWillEnd;

  /// No description provided for @adminUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change not saved} other{{count} changes not saved}}'**
  String adminUnsavedChanges(int count);

  /// No description provided for @adminAllSaved.
  ///
  /// In en, this message translates to:
  /// **'All changes saved'**
  String get adminAllSaved;

  /// No description provided for @adminDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get adminDiscard;

  /// No description provided for @adminDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get adminDiscardTitle;

  /// No description provided for @adminDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your change hasn\'t been saved and will be lost.} other{Your {count} changes haven\'t been saved and will be lost.}}'**
  String adminDiscardBody(int count);

  /// No description provided for @adminSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 setting saved} other{{count} settings saved}}'**
  String adminSettingsSaved(int count);

  /// No description provided for @adminHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Change history'**
  String get adminHistoryTitle;

  /// No description provided for @adminHistoryAll.
  ///
  /// In en, this message translates to:
  /// **'All settings'**
  String get adminHistoryAll;

  /// No description provided for @adminHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No changes yet'**
  String get adminHistoryEmptyTitle;

  /// No description provided for @adminHistoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every saved change shows here, with who made it.'**
  String get adminHistoryEmptyBody;

  /// No description provided for @adminHistoryChangedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} · {time}'**
  String adminHistoryChangedBy(String name, String time);

  /// No description provided for @adminHistoryChangedTo.
  ///
  /// In en, this message translates to:
  /// **'changed to'**
  String get adminHistoryChangedTo;

  /// No description provided for @adminHistoryBefore.
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get adminHistoryBefore;

  /// No description provided for @adminHistoryAfter.
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get adminHistoryAfter;

  /// No description provided for @adminHistoryShowFull.
  ///
  /// In en, this message translates to:
  /// **'Show the full text'**
  String get adminHistoryShowFull;

  /// No description provided for @adminAdminsCount.
  ///
  /// In en, this message translates to:
  /// **'Admins: {count} · Active super admins: {superAdmins}'**
  String adminAdminsCount(int count, int superAdmins);

  /// No description provided for @adminAdminsRestricted.
  ///
  /// In en, this message translates to:
  /// **'Only super admins can manage admins.'**
  String get adminAdminsRestricted;

  /// No description provided for @adminAddAdmin.
  ///
  /// In en, this message translates to:
  /// **'Add admin'**
  String get adminAddAdmin;

  /// No description provided for @adminAddAdminBody.
  ///
  /// In en, this message translates to:
  /// **'They get a temporary password and choose their own at their first sign-in.'**
  String get adminAddAdminBody;

  /// No description provided for @adminRoleAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Everything except managing admins.'**
  String get adminRoleAdminBody;

  /// No description provided for @adminRoleSuperAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Everything, including adding admins and changing their roles.'**
  String get adminRoleSuperAdminBody;

  /// No description provided for @adminColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminColumnName;

  /// No description provided for @adminColumnRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get adminColumnRole;

  /// No description provided for @adminColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminColumnStatus;

  /// No description provided for @adminColumnLastSignIn.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in'**
  String get adminColumnLastSignIn;

  /// No description provided for @adminPasswordNotSet.
  ///
  /// In en, this message translates to:
  /// **'Hasn\'t set a password'**
  String get adminPasswordNotSet;

  /// No description provided for @adminNeverSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get adminNeverSignedIn;

  /// No description provided for @adminLastSignIn.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in: {time}'**
  String adminLastSignIn(String time);

  /// No description provided for @adminYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String adminYouSuffix(String name);

  /// No description provided for @adminThatsYou.
  ///
  /// In en, this message translates to:
  /// **'That\'s you. Another super admin can change your account.'**
  String get adminThatsYou;

  /// No description provided for @adminActionsFor.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String adminActionsFor(String name);

  /// No description provided for @adminMakeSuper.
  ///
  /// In en, this message translates to:
  /// **'Make super admin'**
  String get adminMakeSuper;

  /// No description provided for @adminMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get adminMakeAdmin;

  /// No description provided for @adminMakeSuperTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {name} a super admin?'**
  String adminMakeSuperTitle(String name);

  /// No description provided for @adminMakeSuperBody.
  ///
  /// In en, this message translates to:
  /// **'They\'ll be able to add admins, change roles and disable admins.'**
  String get adminMakeSuperBody;

  /// No description provided for @adminMakeAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {name} an admin?'**
  String adminMakeAdminTitle(String name);

  /// No description provided for @adminMakeAdminBody.
  ///
  /// In en, this message translates to:
  /// **'They\'ll no longer manage admins. The change takes effect right away.'**
  String get adminMakeAdminBody;

  /// No description provided for @adminRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s role was changed.'**
  String adminRoleChanged(String name);

  /// No description provided for @adminDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get adminDisable;

  /// No description provided for @adminEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get adminEnable;

  /// No description provided for @adminDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable {name}?'**
  String adminDisableTitle(String name);

  /// No description provided for @adminDisableBody.
  ///
  /// In en, this message translates to:
  /// **'They\'re signed out everywhere at once and can\'t sign in until you enable them again.'**
  String get adminDisableBody;

  /// No description provided for @adminEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable {name}?'**
  String adminEnableTitle(String name);

  /// No description provided for @adminEnableBody.
  ///
  /// In en, this message translates to:
  /// **'They can sign in again with their password.'**
  String get adminEnableBody;

  /// No description provided for @adminDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} was disabled.'**
  String adminDisabledMessage(String name);

  /// No description provided for @adminEnabledMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} was enabled.'**
  String adminEnabledMessage(String name);

  /// No description provided for @adminNotAllowedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not allowed'**
  String get adminNotAllowedTitle;

  /// No description provided for @adminCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} was added'**
  String adminCreatedTitle(String name);

  /// No description provided for @adminPasswordOnceWarning.
  ///
  /// In en, this message translates to:
  /// **'Copy this temporary password now. It\'s shown only once and can\'t be shown again. Share it with them privately.'**
  String get adminPasswordOnceWarning;

  /// No description provided for @adminTemporaryPassword.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get adminTemporaryPassword;

  /// No description provided for @adminCopyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get adminCopyPassword;

  /// No description provided for @adminCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get adminCopied;

  /// No description provided for @adminPasswordNextStep.
  ///
  /// In en, this message translates to:
  /// **'They sign in with {email} and this password, then choose their own password.'**
  String adminPasswordNextStep(String email);

  /// No description provided for @adminAuditCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No entries} =1{1 entry} other{{count} entries}}'**
  String adminAuditCount(int count);

  /// No description provided for @adminAuditEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get adminAuditEmptyTitle;

  /// No description provided for @adminAuditNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No entries match these filters'**
  String get adminAuditNoMatchTitle;

  /// No description provided for @adminAuditNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try a longer date range or clear some filters.'**
  String get adminAuditNoMatchBody;

  /// No description provided for @adminAuditEnd.
  ///
  /// In en, this message translates to:
  /// **'That\'s everything.'**
  String get adminAuditEnd;

  /// No description provided for @adminClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get adminClearFilters;

  /// No description provided for @adminClearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adminClearFilter;

  /// No description provided for @adminFilterAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get adminFilterAction;

  /// No description provided for @adminFilterAllActions.
  ///
  /// In en, this message translates to:
  /// **'All actions'**
  String get adminFilterAllActions;

  /// No description provided for @adminFilterWho.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get adminFilterWho;

  /// No description provided for @adminFilterEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get adminFilterEveryone;

  /// No description provided for @adminFilterTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get adminFilterTarget;

  /// No description provided for @adminFilterAllTargets.
  ///
  /// In en, this message translates to:
  /// **'All targets'**
  String get adminFilterAllTargets;

  /// No description provided for @adminFilterDates.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get adminFilterDates;

  /// No description provided for @adminFilterBy.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String adminFilterBy(String name);

  /// No description provided for @adminDateRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String adminDateRange(String from, String to);

  /// No description provided for @adminColumnWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get adminColumnWhen;

  /// No description provided for @adminColumnWho.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get adminColumnWho;

  /// No description provided for @adminColumnWhat.
  ///
  /// In en, this message translates to:
  /// **'What'**
  String get adminColumnWhat;

  /// No description provided for @adminColumnTarget.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get adminColumnTarget;

  /// No description provided for @adminTargetDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get adminTargetDoctor;

  /// No description provided for @adminTargetUser.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminTargetUser;

  /// No description provided for @adminTargetSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get adminTargetSettings;

  /// No description provided for @adminDetailFields.
  ///
  /// In en, this message translates to:
  /// **'Settings changed'**
  String get adminDetailFields;

  /// No description provided for @adminDetailChannel.
  ///
  /// In en, this message translates to:
  /// **'How'**
  String get adminDetailChannel;

  /// No description provided for @adminChannelEmail.
  ///
  /// In en, this message translates to:
  /// **'Email link'**
  String get adminChannelEmail;

  /// No description provided for @adminChannelDoctor.
  ///
  /// In en, this message translates to:
  /// **'Through the doctor'**
  String get adminChannelDoctor;

  /// No description provided for @adminEntryNumber.
  ///
  /// In en, this message translates to:
  /// **'Entry'**
  String get adminEntryNumber;

  /// No description provided for @adminOnlyThisPerson.
  ///
  /// In en, this message translates to:
  /// **'Only this person'**
  String get adminOnlyThisPerson;

  /// No description provided for @adminOnlyThisRecord.
  ///
  /// In en, this message translates to:
  /// **'Only this target'**
  String get adminOnlyThisRecord;

  /// No description provided for @adminOpenRegistration.
  ///
  /// In en, this message translates to:
  /// **'Open the sign-up request'**
  String get adminOpenRegistration;

  /// No description provided for @adminCopyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get adminCopyDetails;

  /// No description provided for @adminCopiedDetails.
  ///
  /// In en, this message translates to:
  /// **'Details copied'**
  String get adminCopiedDetails;

  /// No description provided for @adminAuditRegistrationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sent a sign-up request'**
  String get adminAuditRegistrationSubmitted;

  /// No description provided for @adminAuditRegistrationResubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sent the sign-up request again after a rejection'**
  String get adminAuditRegistrationResubmitted;

  /// No description provided for @adminAuditRegistrationApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved a doctor\'s sign-up'**
  String get adminAuditRegistrationApproved;

  /// No description provided for @adminAuditRegistrationRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected a doctor\'s sign-up'**
  String get adminAuditRegistrationRejected;

  /// No description provided for @adminAuditLicenseViewed.
  ///
  /// In en, this message translates to:
  /// **'Viewed a doctor\'s syndicate card'**
  String get adminAuditLicenseViewed;

  /// No description provided for @adminAuditAdminSeeded.
  ///
  /// In en, this message translates to:
  /// **'Created the first super admin'**
  String get adminAuditAdminSeeded;

  /// No description provided for @adminAuditAdminCreated.
  ///
  /// In en, this message translates to:
  /// **'Added an admin ({role})'**
  String adminAuditAdminCreated(String role);

  /// No description provided for @adminAuditAdminRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed an admin\'s role from {before} to {after}'**
  String adminAuditAdminRoleChanged(String before, String after);

  /// No description provided for @adminAuditAdminDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled an admin'**
  String get adminAuditAdminDisabled;

  /// No description provided for @adminAuditAdminEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled an admin'**
  String get adminAuditAdminEnabled;

  /// No description provided for @adminAuditProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated their profile'**
  String get adminAuditProfileUpdated;

  /// No description provided for @adminAuditSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed settings: {fields}'**
  String adminAuditSettingsUpdated(String fields);

  /// No description provided for @adminAuditPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get adminAuditPasswordSet;

  /// No description provided for @adminAuditPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed their password'**
  String get adminAuditPasswordChanged;

  /// No description provided for @adminAuditResetRequestedEmail.
  ///
  /// In en, this message translates to:
  /// **'Asked for a password reset by email'**
  String get adminAuditResetRequestedEmail;

  /// No description provided for @adminAuditResetRequestedDoctor.
  ///
  /// In en, this message translates to:
  /// **'Asked their doctor for a password reset'**
  String get adminAuditResetRequestedDoctor;

  /// No description provided for @adminAuditPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Reset a password with the email link'**
  String get adminAuditPasswordReset;

  /// No description provided for @adminAuditLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Locked an account for 15 minutes after wrong passwords'**
  String get adminAuditLockedOut;

  /// No description provided for @adminAuditTokenReuse.
  ///
  /// In en, this message translates to:
  /// **'Ended a session: a sign-in token was used twice'**
  String get adminAuditTokenReuse;

  /// No description provided for @adminAuditEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Confirmed their email'**
  String get adminAuditEmailVerified;

  /// No description provided for @adminActionRegistrationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sign-up sent'**
  String get adminActionRegistrationSubmitted;

  /// No description provided for @adminActionRegistrationResubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sign-up sent again'**
  String get adminActionRegistrationResubmitted;

  /// No description provided for @adminActionRegistrationApproved.
  ///
  /// In en, this message translates to:
  /// **'Sign-up approved'**
  String get adminActionRegistrationApproved;

  /// No description provided for @adminActionRegistrationRejected.
  ///
  /// In en, this message translates to:
  /// **'Sign-up rejected'**
  String get adminActionRegistrationRejected;

  /// No description provided for @adminActionLicenseViewed.
  ///
  /// In en, this message translates to:
  /// **'Syndicate card viewed'**
  String get adminActionLicenseViewed;

  /// No description provided for @adminActionAdminSeeded.
  ///
  /// In en, this message translates to:
  /// **'First super admin created'**
  String get adminActionAdminSeeded;

  /// No description provided for @adminActionAdminCreated.
  ///
  /// In en, this message translates to:
  /// **'Admin added'**
  String get adminActionAdminCreated;

  /// No description provided for @adminActionAdminRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'Admin role changed'**
  String get adminActionAdminRoleChanged;

  /// No description provided for @adminActionAdminDisabled.
  ///
  /// In en, this message translates to:
  /// **'Admin disabled'**
  String get adminActionAdminDisabled;

  /// No description provided for @adminActionAdminEnabled.
  ///
  /// In en, this message translates to:
  /// **'Admin enabled'**
  String get adminActionAdminEnabled;

  /// No description provided for @adminActionProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get adminActionProfileUpdated;

  /// No description provided for @adminActionSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Settings changed'**
  String get adminActionSettingsUpdated;

  /// No description provided for @adminActionPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Password set'**
  String get adminActionPasswordSet;

  /// No description provided for @adminActionPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get adminActionPasswordChanged;

  /// No description provided for @adminActionResetRequested.
  ///
  /// In en, this message translates to:
  /// **'Password reset requested'**
  String get adminActionResetRequested;

  /// No description provided for @adminActionPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Password reset'**
  String get adminActionPasswordReset;

  /// No description provided for @adminActionLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Account locked'**
  String get adminActionLockedOut;

  /// No description provided for @adminActionTokenReuse.
  ///
  /// In en, this message translates to:
  /// **'Sign-in token reused'**
  String get adminActionTokenReuse;

  /// No description provided for @adminActionEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed'**
  String get adminActionEmailVerified;

  /// No description provided for @adminProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your account, language and appearance, and password.'**
  String get adminProfileSubtitle;

  /// No description provided for @adminProfileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get adminProfileAccount;

  /// No description provided for @adminEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get adminEditName;

  /// No description provided for @adminMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Admin since'**
  String get adminMemberSince;

  /// No description provided for @adminNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved'**
  String get adminNameSaved;

  /// No description provided for @adminPreferences.
  ///
  /// In en, this message translates to:
  /// **'Language and appearance'**
  String get adminPreferences;

  /// No description provided for @adminPreferencesBody.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device and on your account.'**
  String get adminPreferencesBody;

  /// No description provided for @adminLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get adminLanguage;

  /// No description provided for @adminChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get adminChangePassword;

  /// No description provided for @adminChangePasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Your other devices are signed out when you change it.'**
  String get adminChangePasswordBody;

  /// No description provided for @adminCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get adminCurrentPassword;

  /// No description provided for @adminPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Your other devices were signed out.'**
  String get adminPasswordChanged;

  /// No description provided for @adminLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'Sign out of el3yada on this device.'**
  String get adminLogoutBody;

  /// No description provided for @navActivityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get navActivityLog;

  /// Top bar title for assistants (spec 7.6).
  ///
  /// In en, this message translates to:
  /// **'Dr {name}\'s clinic'**
  String clinicOfDoctor(String name);

  /// No description provided for @clinicCurrentBranch.
  ///
  /// In en, this message translates to:
  /// **'Current branch'**
  String get clinicCurrentBranch;

  /// No description provided for @clinicBranchTemporarilyClosed.
  ///
  /// In en, this message translates to:
  /// **'Temporarily closed'**
  String get clinicBranchTemporarilyClosed;

  /// No description provided for @clinicSuspendedBanner.
  ///
  /// In en, this message translates to:
  /// **'Service is suspended because an invoice is unpaid. Pay it to reactivate.'**
  String get clinicSuspendedBanner;

  /// No description provided for @clinicPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get clinicPayNow;

  /// No description provided for @clinicLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the clinic details.'**
  String get clinicLoadFailed;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this. Ask the doctor.'**
  String get errorPermissionDenied;

  /// No description provided for @errorDoctorSuspended.
  ///
  /// In en, this message translates to:
  /// **'Not available while the service is suspended.'**
  String get errorDoctorSuspended;

  /// No description provided for @errorBranchNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This branch isn\'t one of yours.'**
  String get errorBranchNotAllowed;

  /// No description provided for @tempPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get tempPasswordTitle;

  /// Temporary password dialog (BR-P4, BR-AS2).
  ///
  /// In en, this message translates to:
  /// **'Give it to {name}. It\'s shown only this once, and they\'ll choose their own password when they sign in.'**
  String tempPasswordBody(String name);

  /// No description provided for @tempPasswordCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get tempPasswordCopy;

  /// No description provided for @tempPasswordCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get tempPasswordCopied;

  /// No description provided for @tempPasswordShareWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get tempPasswordShareWhatsApp;

  /// No description provided for @tempPasswordShareSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get tempPasswordShareSms;

  /// The text shared by WhatsApp or SMS.
  ///
  /// In en, this message translates to:
  /// **'Your el3yada account: {phone}\nTemporary password: {password}\nYou\'ll choose a new password when you sign in.'**
  String tempPasswordMessage(String phone, String password);

  /// No description provided for @tempPasswordMessageCopied.
  ///
  /// In en, this message translates to:
  /// **'No messaging app found. The message is copied; paste it where you like.'**
  String get tempPasswordMessageCopied;

  /// No description provided for @sessionToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sessionToday;

  /// No description provided for @sessionYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get sessionYesterday;

  /// "x days ago" for a last visit (D4, D6).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String sessionDaysAgo(int count);

  /// No description provided for @sessionTypeExamination.
  ///
  /// In en, this message translates to:
  /// **'Examination'**
  String get sessionTypeExamination;

  /// No description provided for @sessionTypeConsultation.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get sessionTypeConsultation;

  /// No description provided for @sessionPaymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get sessionPaymentCash;

  /// No description provided for @sessionPaymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get sessionPaymentCard;

  /// No description provided for @sessionPaymentInstapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get sessionPaymentInstapay;

  /// No description provided for @sessionPaymentWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile wallet'**
  String get sessionPaymentWallet;

  /// No description provided for @sessionAwaitingDoctor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the doctor'**
  String get sessionAwaitingDoctor;

  /// No description provided for @patientHasAllergies.
  ///
  /// In en, this message translates to:
  /// **'Has allergies'**
  String get patientHasAllergies;

  /// No description provided for @patientAllergyFlag.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get patientAllergyFlag;

  /// The per-doctor file number (BR-P6).
  ///
  /// In en, this message translates to:
  /// **'File {number}'**
  String patientFileNumber(String number);

  /// The fee card line (BR-B2, AC-4): «2 كشف + 3 استشارة = 105 ج.م».
  ///
  /// In en, this message translates to:
  /// **'{examinations} + {consultations} = {total}'**
  String feesEquation(String examinations, String consultations, String total);

  /// Part of feesEquation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 examination} other{{count} examinations}}'**
  String feesExaminationCount(int count);

  /// Part of feesEquation.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 consultation} other{{count} consultations}}'**
  String feesConsultationCount(int count);

  /// No description provided for @patientAdd.
  ///
  /// In en, this message translates to:
  /// **'Add patient'**
  String get patientAdd;

  /// D4 header.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No patients} =1{1 patient} other{{count} patients}}'**
  String patientRegisterCount(int count);

  /// No description provided for @patientSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, mobile or file number'**
  String get patientSearchHint;

  /// No description provided for @patientNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No patients match'**
  String get patientNoMatchTitle;

  /// No description provided for @patientNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Try another name, number or filter.'**
  String get patientNoMatchBody;

  /// No description provided for @patientFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get patientFilterClear;

  /// No description provided for @patientEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No patients yet'**
  String get patientEmptyTitle;

  /// No description provided for @patientEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first patient to open their file.'**
  String get patientEmptyBody;

  /// No description provided for @patientFilterLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get patientFilterLastVisit;

  /// No description provided for @patientFilterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get patientFilterAny;

  /// No description provided for @patientFilterBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get patientFilterBranch;

  /// No description provided for @patientFilterAllBranches.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get patientFilterAllBranches;

  /// No description provided for @patientFilterVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get patientFilterVisits;

  /// No description provided for @patientFilterNewThisMonth.
  ///
  /// In en, this message translates to:
  /// **'New this month'**
  String get patientFilterNewThisMonth;

  /// No description provided for @patientFilterChronic.
  ///
  /// In en, this message translates to:
  /// **'Chronic disease'**
  String get patientFilterChronic;

  /// No description provided for @patientFilterArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get patientFilterArchived;

  /// No description provided for @patientVisitsOne.
  ///
  /// In en, this message translates to:
  /// **'1 visit'**
  String get patientVisitsOne;

  /// No description provided for @patientVisitsFew.
  ///
  /// In en, this message translates to:
  /// **'2 to 4 visits'**
  String get patientVisitsFew;

  /// No description provided for @patientVisitsMany.
  ///
  /// In en, this message translates to:
  /// **'5 visits or more'**
  String get patientVisitsMany;

  /// No description provided for @patientLastVisitThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get patientLastVisitThisWeek;

  /// No description provided for @patientLastVisitThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get patientLastVisitThisMonth;

  /// No description provided for @patientLastVisitNotSeen3m.
  ///
  /// In en, this message translates to:
  /// **'Not seen for 3 months'**
  String get patientLastVisitNotSeen3m;

  /// No description provided for @patientLastVisitNotSeen6m.
  ///
  /// In en, this message translates to:
  /// **'Not seen for 6 months'**
  String get patientLastVisitNotSeen6m;

  /// No description provided for @patientLastVisitNotSeen12m.
  ///
  /// In en, this message translates to:
  /// **'Not seen for a year'**
  String get patientLastVisitNotSeen12m;

  /// No description provided for @patientLastVisitNever.
  ///
  /// In en, this message translates to:
  /// **'Never visited'**
  String get patientLastVisitNever;

  /// No description provided for @patientArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get patientArchived;

  /// No description provided for @patientNoVisits.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get patientNoVisits;

  /// No description provided for @patientColumnFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get patientColumnFile;

  /// No description provided for @patientColumnName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get patientColumnName;

  /// No description provided for @patientColumnPhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get patientColumnPhone;

  /// No description provided for @patientColumnAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get patientColumnAge;

  /// No description provided for @patientColumnFirstVisit.
  ///
  /// In en, this message translates to:
  /// **'First visit'**
  String get patientColumnFirstVisit;

  /// No description provided for @patientColumnLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get patientColumnLastVisit;

  /// No description provided for @patientColumnVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get patientColumnVisits;

  /// No description provided for @patientColumnPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get patientColumnPaid;

  /// No description provided for @patientColumnAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get patientColumnAllergies;

  /// Visits column: examinations and consultations.
  ///
  /// In en, this message translates to:
  /// **'{examinations} exam., {consultations} consult.'**
  String patientVisitsSplit(int examinations, int consultations);

  /// No description provided for @patientGenderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get patientGenderMale;

  /// No description provided for @patientGenderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get patientGenderFemale;

  /// A patient's age.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =0{Under 1 year} =1{1 year} other{{years} years}}'**
  String patientAgeYears(int years);

  /// Age and gender under a name.
  ///
  /// In en, this message translates to:
  /// **'{age}, {gender}'**
  String patientAgeGender(String age, String gender);

  /// Number of visits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No visits} =1{1 visit} other{{count} visits}}'**
  String patientVisitsCount(int count);

  /// "3 visits: 1 examination, 2 consultations".
  ///
  /// In en, this message translates to:
  /// **'{visits}: {examinations}, {consultations}'**
  String patientVisitsSummary(
    String visits,
    String examinations,
    String consultations,
  );

  /// No description provided for @patientSortFileNumber.
  ///
  /// In en, this message translates to:
  /// **'File number'**
  String get patientSortFileNumber;

  /// No description provided for @patientSortGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get patientSortGender;

  /// No description provided for @patientSortExaminations.
  ///
  /// In en, this message translates to:
  /// **'Examinations'**
  String get patientSortExaminations;

  /// No description provided for @patientSortConsultations.
  ///
  /// In en, this message translates to:
  /// **'Consultations'**
  String get patientSortConsultations;

  /// No description provided for @patientSortFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get patientSortFiles;

  /// No description provided for @patientSortLinkedAt.
  ///
  /// In en, this message translates to:
  /// **'Date added'**
  String get patientSortLinkedAt;

  /// No description provided for @patientTotalPaid.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get patientTotalPaid;

  /// Screen reader text for a register row.
  ///
  /// In en, this message translates to:
  /// **'Last visit: {type}, {date}, {ago}'**
  String patientLastVisitSemantics(String type, String date, String ago);

  /// No description provided for @patientResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset the password?'**
  String get patientResetPasswordTitle;

  /// BR-P5 confirmation.
  ///
  /// In en, this message translates to:
  /// **'{name} gets a new temporary password and is signed out on every device. They choose their own at the next sign-in.'**
  String patientResetPasswordBody(String name);

  /// No description provided for @patientResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get patientResetPassword;

  /// No description provided for @patientNewTemporaryPassword.
  ///
  /// In en, this message translates to:
  /// **'New temporary password'**
  String get patientNewTemporaryPassword;

  /// No description provided for @patientArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this patient?'**
  String get patientArchiveTitle;

  /// No description provided for @patientUnarchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Bring this patient back?'**
  String get patientUnarchiveTitle;

  /// No description provided for @patientArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'They leave the patients list. Nothing is deleted, and a new session brings them back.'**
  String get patientArchiveBody;

  /// No description provided for @patientUnarchiveBody.
  ///
  /// In en, this message translates to:
  /// **'They appear in the patients list again.'**
  String get patientUnarchiveBody;

  /// No description provided for @patientArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get patientArchive;

  /// No description provided for @patientUnarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get patientUnarchive;

  /// No description provided for @patientArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Patient archived'**
  String get patientArchivedDone;

  /// No description provided for @patientUnarchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Patient back in the list'**
  String get patientUnarchivedDone;

  /// No description provided for @patientMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get patientMoreActions;

  /// No description provided for @sessionNew.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get sessionNew;

  /// No description provided for @patientEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get patientEdit;

  /// No description provided for @patientLinkedNote.
  ///
  /// In en, this message translates to:
  /// **'This patient\'s account was created by another clinic. You see their name, mobile, gender and date of birth, and only the records your clinic adds.'**
  String get patientLinkedNote;

  /// No description provided for @patientDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get patientDetails;

  /// No description provided for @patientBloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood type'**
  String get patientBloodType;

  /// No description provided for @patientNationalId.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get patientNationalId;

  /// No description provided for @patientAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get patientAddress;

  /// No description provided for @patientEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get patientEmergencyContact;

  /// No description provided for @patientNoTabs.
  ///
  /// In en, this message translates to:
  /// **'Your permissions don\'t include this patient\'s medical file.'**
  String get patientNoTabs;

  /// No description provided for @patientTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get patientTabOverview;

  /// No description provided for @patientTabSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get patientTabSessions;

  /// No description provided for @patientCantOpenApp.
  ///
  /// In en, this message translates to:
  /// **'No app on this device can open it.'**
  String get patientCantOpenApp;

  /// No description provided for @patientCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get patientCall;

  /// No description provided for @patientWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get patientWhatsApp;

  /// No description provided for @patientFileSummary.
  ///
  /// In en, this message translates to:
  /// **'File summary'**
  String get patientFileSummary;

  /// No description provided for @patientConsultationsSinceExam.
  ///
  /// In en, this message translates to:
  /// **'Consultations since the last examination'**
  String get patientConsultationsSinceExam;

  /// BR-S4 count: «استشارة 1 من 2 منذ آخر كشف».
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No consultations since the last examination (up to {max})} other{Consultation {count} of {max} since the last examination}}'**
  String sessionConsultationCount(int count, int max);

  /// No description provided for @patientProfileEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No medical profile yet'**
  String get patientProfileEmptyTitle;

  /// No description provided for @patientProfileEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Record allergies, chronic diseases and current medications.'**
  String get patientProfileEmptyBody;

  /// No description provided for @patientEditMedicalProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit medical profile'**
  String get patientEditMedicalProfile;

  /// No description provided for @patientAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get patientAllergies;

  /// No description provided for @patientChronicDiseases.
  ///
  /// In en, this message translates to:
  /// **'Chronic diseases'**
  String get patientChronicDiseases;

  /// No description provided for @patientCurrentMedications.
  ///
  /// In en, this message translates to:
  /// **'Current medications'**
  String get patientCurrentMedications;

  /// No description provided for @patientSurgeries.
  ///
  /// In en, this message translates to:
  /// **'Past surgeries'**
  String get patientSurgeries;

  /// No description provided for @patientFamilyHistory.
  ///
  /// In en, this message translates to:
  /// **'Family history'**
  String get patientFamilyHistory;

  /// No description provided for @patientGeneralNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get patientGeneralNotes;

  /// No description provided for @patientNoAllergies.
  ///
  /// In en, this message translates to:
  /// **'No known allergies'**
  String get patientNoAllergies;

  /// No description provided for @patientNothingRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded'**
  String get patientNothingRecorded;

  /// No description provided for @patientSessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get patientSessionsEmptyTitle;

  /// No description provided for @patientSessionsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'A first visit is always an examination.'**
  String get patientSessionsEmptyBody;

  /// No description provided for @patientLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get patientLoadMore;

  /// The platform fee on a session row.
  ///
  /// In en, this message translates to:
  /// **'Fee {amount}'**
  String sessionPlatformFeeShort(String amount);

  /// BR-AS6, shown to the doctor.
  ///
  /// In en, this message translates to:
  /// **'Recorded by {name}'**
  String sessionRecordedBy(String name);

  /// No description provided for @patientCheckFields.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields.'**
  String get patientCheckFields;

  /// No description provided for @patientAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The patient gets an account and a file number. Their temporary password is shown once.'**
  String get patientAddSubtitle;

  /// No description provided for @patientMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get patientMobile;

  /// No description provided for @patientMobileHint.
  ///
  /// In en, this message translates to:
  /// **'The patient signs in with it.'**
  String get patientMobileHint;

  /// No description provided for @patientMobileLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get patientMobileLabel;

  /// No description provided for @patientPhoneChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the number…'**
  String get patientPhoneChecking;

  /// No description provided for @patientPhoneNew.
  ///
  /// In en, this message translates to:
  /// **'New number. Fill in the patient’s details.'**
  String get patientPhoneNew;

  /// No description provided for @patientPhoneOurs.
  ///
  /// In en, this message translates to:
  /// **'This number is already one of your patients'**
  String get patientPhoneOurs;

  /// No description provided for @patientPhoneElsewhere.
  ///
  /// In en, this message translates to:
  /// **'This number already has an el3yada account'**
  String get patientPhoneElsewhere;

  /// No description provided for @patientPhoneElsewhereBody.
  ///
  /// In en, this message translates to:
  /// **'Link the patient to add them to your list. No new account is created.'**
  String get patientPhoneElsewhereBody;

  /// No description provided for @patientLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'This patient already has an account'**
  String get patientLinkTitle;

  /// BR-P3 dialog.
  ///
  /// In en, this message translates to:
  /// **'The number {phone} belongs to a patient of another clinic. Linking adds them to your list with a new file number.'**
  String patientLinkBody(String phone);

  /// No description provided for @patientLinkPrivacy.
  ///
  /// In en, this message translates to:
  /// **'You will see their name, mobile, gender and date of birth, and only the records your clinic creates.'**
  String get patientLinkPrivacy;

  /// No description provided for @patientLinkConfirm.
  ///
  /// In en, this message translates to:
  /// **'Link patient'**
  String get patientLinkConfirm;

  /// No description provided for @patientLinkedTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient added'**
  String get patientLinkedTitle;

  /// No description provided for @patientLinkedBody.
  ///
  /// In en, this message translates to:
  /// **'This patient already has an account and has been added to your list.'**
  String get patientLinkedBody;

  /// No description provided for @patientOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get patientOpenFile;

  /// No description provided for @patientErrorName.
  ///
  /// In en, this message translates to:
  /// **'Write at least two names, in letters only.'**
  String get patientErrorName;

  /// No description provided for @patientErrorAge.
  ///
  /// In en, this message translates to:
  /// **'Enter an age from 0 to 120.'**
  String get patientErrorAge;

  /// No description provided for @patientErrorDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'The date of birth isn’t valid.'**
  String get patientErrorDateOfBirth;

  /// No description provided for @patientErrorNationalId.
  ///
  /// In en, this message translates to:
  /// **'The national ID must be 14 digits.'**
  String get patientErrorNationalId;

  /// No description provided for @patientIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get patientIdentity;

  /// No description provided for @patientFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get patientFullName;

  /// No description provided for @patientFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'At least two names'**
  String get patientFullNameHint;

  /// No description provided for @patientGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get patientGender;

  /// No description provided for @patientDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth or age'**
  String get patientDateOfBirth;

  /// No description provided for @patientUseDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get patientUseDate;

  /// No description provided for @patientUseAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get patientUseAge;

  /// No description provided for @patientAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Age in years'**
  String get patientAgeLabel;

  /// No description provided for @patientYearsSuffix.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get patientYearsSuffix;

  /// No description provided for @patientDateOfBirthLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get patientDateOfBirthLabel;

  /// No description provided for @patientMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More details'**
  String get patientMoreDetails;

  /// No description provided for @patientOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get patientOptional;

  /// No description provided for @patientNationalIdHint.
  ///
  /// In en, this message translates to:
  /// **'14 digits'**
  String get patientNationalIdHint;

  /// No description provided for @patientNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get patientNotSet;

  /// No description provided for @patientEmergencyName.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact name'**
  String get patientEmergencyName;

  /// No description provided for @patientEmergencyPhone.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact number'**
  String get patientEmergencyPhone;

  /// No description provided for @patientEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit patient'**
  String get patientEditTitle;

  /// No description provided for @patientMedicalProfile.
  ///
  /// In en, this message translates to:
  /// **'Medical profile'**
  String get patientMedicalProfile;

  /// No description provided for @patientDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'Your changes haven’t been saved and will be lost.'**
  String get patientDiscardBody;

  /// No description provided for @patientSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get patientSaved;

  /// No description provided for @patientNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get patientNoChanges;

  /// No description provided for @patientUnsaved.
  ///
  /// In en, this message translates to:
  /// **'Changes not saved'**
  String get patientUnsaved;

  /// No description provided for @patientPhoneChangeHint.
  ///
  /// In en, this message translates to:
  /// **'The patient’s login. It changes on its own, with a confirmation.'**
  String get patientPhoneChangeHint;

  /// No description provided for @patientChangePhone.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get patientChangePhone;

  /// Phone change dialog.
  ///
  /// In en, this message translates to:
  /// **'{name} will sign in with the new number. Devices already signed in stay signed in.'**
  String patientChangePhoneBody(String name);

  /// No description provided for @patientNewMobile.
  ///
  /// In en, this message translates to:
  /// **'New mobile number'**
  String get patientNewMobile;

  /// No description provided for @patientChangePhoneConfirm.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get patientChangePhoneConfirm;

  /// No description provided for @patientPhoneSame.
  ///
  /// In en, this message translates to:
  /// **'This is the current number.'**
  String get patientPhoneSame;

  /// No description provided for @patientPhoneChanged.
  ///
  /// In en, this message translates to:
  /// **'Mobile number changed. The patient signs in with the new one.'**
  String get patientPhoneChanged;

  /// No description provided for @patientFamilyHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'For example: father, diabetes'**
  String get patientFamilyHistoryHint;

  /// Items in a medical profile list.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 item} other{{count} items}}'**
  String patientListCount(int count);

  /// No description provided for @patientListFull.
  ///
  /// In en, this message translates to:
  /// **'A list holds 50 items at most.'**
  String get patientListFull;

  /// No description provided for @patientListDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Already in the list.'**
  String get patientListDuplicate;

  /// No description provided for @patientMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get patientMoveUp;

  /// No description provided for @patientMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get patientMoveDown;

  /// Remove a medical profile item.
  ///
  /// In en, this message translates to:
  /// **'Remove {item}'**
  String patientRemoveItem(String item);

  /// No description provided for @patientAddItemHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item'**
  String get patientAddItemHint;

  /// No description provided for @patientAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get patientAddItem;

  /// BR-S4. The number follows maxConsecutiveConsultations.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{This patient has had 1 consultation in a row. Record an examination first.} other{This patient has had {max} consultations in a row. Record an examination first.}}'**
  String sessionConsultationLimit(int max);

  /// No description provided for @sessionRuleFirstVisit.
  ///
  /// In en, this message translates to:
  /// **'This is the patient\'s first visit with you, so it must be an examination.'**
  String get sessionRuleFirstVisit;

  /// AC-2: someone saved first.
  ///
  /// In en, this message translates to:
  /// **'A session was just recorded for this patient on another device. {message}'**
  String sessionRuleChanged(String message);

  /// No description provided for @sessionStepType.
  ///
  /// In en, this message translates to:
  /// **'Visit type'**
  String get sessionStepType;

  /// No description provided for @sessionStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Details and amount'**
  String get sessionStepDetails;

  /// No description provided for @sessionPickType.
  ///
  /// In en, this message translates to:
  /// **'Choose the visit type.'**
  String get sessionPickType;

  /// D8 step 1 footer.
  ///
  /// In en, this message translates to:
  /// **'{type} selected'**
  String sessionPicked(String type);

  /// No description provided for @sessionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get sessionNext;

  /// No description provided for @sessionSave.
  ///
  /// In en, this message translates to:
  /// **'Save session'**
  String get sessionSave;

  /// No description provided for @sessionAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount charged.'**
  String get sessionAmountRequired;

  /// No description provided for @sessionClinical.
  ///
  /// In en, this message translates to:
  /// **'Clinical notes'**
  String get sessionClinical;

  /// No description provided for @sessionChiefComplaint.
  ///
  /// In en, this message translates to:
  /// **'Chief complaint'**
  String get sessionChiefComplaint;

  /// No description provided for @sessionFindings.
  ///
  /// In en, this message translates to:
  /// **'Examination findings'**
  String get sessionFindings;

  /// No description provided for @sessionDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get sessionDiagnosis;

  /// No description provided for @sessionPatientNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes for the patient'**
  String get sessionPatientNotes;

  /// No description provided for @sessionPatientNotesHint.
  ///
  /// In en, this message translates to:
  /// **'The patient sees these in their app.'**
  String get sessionPatientNotesHint;

  /// No description provided for @sessionAmountCharged.
  ///
  /// In en, this message translates to:
  /// **'Amount charged'**
  String get sessionAmountCharged;

  /// No description provided for @sessionNoPrice.
  ///
  /// In en, this message translates to:
  /// **'No visit price is set for this branch. Enter what the patient paid.'**
  String get sessionNoPrice;

  /// The clinic visit price (6.15).
  ///
  /// In en, this message translates to:
  /// **'Visit price {amount}'**
  String sessionVisitPrice(String amount);

  /// No description provided for @sessionFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get sessionFree;

  /// No description provided for @sessionAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get sessionAmountLabel;

  /// No description provided for @sessionCurrency.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get sessionCurrency;

  /// No description provided for @sessionAmountHint.
  ///
  /// In en, this message translates to:
  /// **'Lower it for a discount. It never changes the platform fee.'**
  String get sessionAmountHint;

  /// No description provided for @sessionFreeVisit.
  ///
  /// In en, this message translates to:
  /// **'Free visit'**
  String get sessionFreeVisit;

  /// No description provided for @sessionPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method (optional)'**
  String get sessionPaymentMethod;

  /// D8 branch chip.
  ///
  /// In en, this message translates to:
  /// **'Branch: {name}'**
  String sessionBranch(String name);

  /// No description provided for @sessionChangeBranch.
  ///
  /// In en, this message translates to:
  /// **'Change branch'**
  String get sessionChangeBranch;

  /// No description provided for @sessionFirstVisit.
  ///
  /// In en, this message translates to:
  /// **'First visit with you: examination only'**
  String get sessionFirstVisit;

  /// "Last session: Examination, 3 Nov".
  ///
  /// In en, this message translates to:
  /// **'Last session: {type}, {date}'**
  String sessionLastSession(String type, String date);

  /// No description provided for @sessionNoPriceShort.
  ///
  /// In en, this message translates to:
  /// **'No price set'**
  String get sessionNoPriceShort;

  /// No description provided for @sessionNoPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Type the amount in the next step'**
  String get sessionNoPriceHint;

  /// No description provided for @sessionVisitPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit price'**
  String get sessionVisitPriceLabel;

  /// BR-S5 fee on a type card.
  ///
  /// In en, this message translates to:
  /// **'Platform fee {amount}'**
  String sessionPlatformFee(String amount);

  /// No description provided for @sessionPrivateNote.
  ///
  /// In en, this message translates to:
  /// **'Private note'**
  String get sessionPrivateNote;

  /// No description provided for @sessionPrivateNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Not visible to the patient'**
  String get sessionPrivateNoteHint;

  /// No description provided for @sessionPrivateNotePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Only you can read this.'**
  String get sessionPrivateNotePlaceholder;

  /// No description provided for @sessionFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up date'**
  String get sessionFollowUp;

  /// No description provided for @sessionClearFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Clear the follow-up date'**
  String get sessionClearFollowUp;

  /// BR-S6. The type is shown in bold.
  ///
  /// In en, this message translates to:
  /// **'Save as {type}?'**
  String sessionConfirmTitle(String type);

  /// BR-S6.
  ///
  /// In en, this message translates to:
  /// **'A fee of {amount} will be added.'**
  String sessionConfirmFee(String amount);

  /// No description provided for @sessionConfirmPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get sessionConfirmPatient;

  /// No description provided for @sessionConfirmBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get sessionConfirmBranch;

  /// No description provided for @sessionConfirmLocked.
  ///
  /// In en, this message translates to:
  /// **'The type and time can\'t be changed after saving.'**
  String get sessionConfirmLocked;

  /// No description provided for @sessionConfirmSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sessionConfirmSave;

  /// No description provided for @sessionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get sessionLater;

  /// No description provided for @sessionSaved.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get sessionSaved;

  /// After-save sheet.
  ///
  /// In en, this message translates to:
  /// **'{type} for {patient}. A fee of {fee} was added.'**
  String sessionSavedBody(String type, String patient, String fee);

  /// No description provided for @sessionWritePrescription.
  ///
  /// In en, this message translates to:
  /// **'Write prescription'**
  String get sessionWritePrescription;

  /// No description provided for @sessionLabRequest.
  ///
  /// In en, this message translates to:
  /// **'Lab or radiology request'**
  String get sessionLabRequest;

  /// No description provided for @sessionAttachFiles.
  ///
  /// In en, this message translates to:
  /// **'Attach files'**
  String get sessionAttachFiles;

  /// No description provided for @sessionView.
  ///
  /// In en, this message translates to:
  /// **'View session'**
  String get sessionView;

  /// No description provided for @sessionPickPatient.
  ///
  /// In en, this message translates to:
  /// **'Choose the patient'**
  String get sessionPickPatient;

  /// No description provided for @sessionRecentPatients.
  ///
  /// In en, this message translates to:
  /// **'Recent patients'**
  String get sessionRecentPatients;

  /// No description provided for @sessionSearchResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get sessionSearchResults;

  /// No description provided for @sessionVitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get sessionVitals;

  /// No description provided for @sessionVitalsHint.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure, pulse, temperature, weight, height, blood sugar'**
  String get sessionVitalsHint;

  /// No description provided for @sessionVitalBp.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get sessionVitalBp;

  /// No description provided for @sessionVitalBpSys.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get sessionVitalBpSys;

  /// No description provided for @sessionVitalBpDia.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get sessionVitalBpDia;

  /// No description provided for @sessionVitalPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get sessionVitalPulse;

  /// No description provided for @sessionVitalTemp.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get sessionVitalTemp;

  /// No description provided for @sessionVitalWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get sessionVitalWeight;

  /// No description provided for @sessionVitalHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get sessionVitalHeight;

  /// No description provided for @sessionVitalGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood sugar'**
  String get sessionVitalGlucose;

  /// No description provided for @sessionVitalBpPair.
  ///
  /// In en, this message translates to:
  /// **'Enter both blood pressure values.'**
  String get sessionVitalBpPair;

  /// No description provided for @sessionVitalUnusual.
  ///
  /// In en, this message translates to:
  /// **'Unusual value, check it.'**
  String get sessionVitalUnusual;

  /// No description provided for @sessionNoVitals.
  ///
  /// In en, this message translates to:
  /// **'No vitals recorded'**
  String get sessionNoVitals;

  /// No description provided for @sessionRecordedByDoctor.
  ///
  /// In en, this message translates to:
  /// **'The doctor'**
  String get sessionRecordedByDoctor;

  /// Fee card part.
  ///
  /// In en, this message translates to:
  /// **'Examinations {amount}'**
  String feesExaminationsFee(String amount);

  /// Fee card part.
  ///
  /// In en, this message translates to:
  /// **'Consultations {amount}'**
  String feesConsultationsFee(String amount);

  /// No description provided for @sessionDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Session details'**
  String get sessionDetailsTitle;

  /// No description provided for @sessionLocked.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be changed after saving'**
  String get sessionLocked;

  /// No description provided for @sessionSummary.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionSummary;

  /// No description provided for @sessionTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sessionTime;

  /// No description provided for @sessionType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sessionType;

  /// No description provided for @sessionBranchLabel.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get sessionBranchLabel;

  /// No description provided for @sessionPlatformFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform fee'**
  String get sessionPlatformFeeLabel;

  /// No description provided for @sessionRecordedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Recorded by'**
  String get sessionRecordedByLabel;

  /// BR-AS6.
  ///
  /// In en, this message translates to:
  /// **'{name} (assistant)'**
  String sessionRecordedByAssistant(String name);

  /// No description provided for @sessionEditAmount.
  ///
  /// In en, this message translates to:
  /// **'Change the amount'**
  String get sessionEditAmount;

  /// No description provided for @sessionAmountSaved.
  ///
  /// In en, this message translates to:
  /// **'Amount saved'**
  String get sessionAmountSaved;

  /// No description provided for @sessionAmountLogged.
  ///
  /// In en, this message translates to:
  /// **'Every change is recorded in the activity log.'**
  String get sessionAmountLogged;

  /// No description provided for @sessionNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get sessionNotRecorded;

  /// No description provided for @sessionAwaitingHint.
  ///
  /// In en, this message translates to:
  /// **'Recorded by an assistant. Add the clinical notes to clear «Waiting for the doctor».'**
  String get sessionAwaitingHint;

  /// No description provided for @sessionNoPrivateNote.
  ///
  /// In en, this message translates to:
  /// **'No private note'**
  String get sessionNoPrivateNote;

  /// No description provided for @sessionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get sessionDelete;

  /// No description provided for @sessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session deleted'**
  String get sessionDeleted;

  /// No description provided for @sessionNotDeletableLatest.
  ///
  /// In en, this message translates to:
  /// **'Only the patient\'s latest session can be deleted.'**
  String get sessionNotDeletableLatest;

  /// No description provided for @sessionNotDeletableDay.
  ///
  /// In en, this message translates to:
  /// **'A session can be deleted only on the day it was recorded.'**
  String get sessionNotDeletableDay;

  /// No description provided for @sessionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get sessionDeleteTitle;

  /// No description provided for @sessionDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its fee comes off today’s and this month’s totals, and the deletion is recorded with your reason.'**
  String get sessionDeleteBody;

  /// No description provided for @sessionDeleteReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get sessionDeleteReason;

  /// No description provided for @sessionDeleteReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Write the reason (3 characters or more).'**
  String get sessionDeleteReasonRequired;

  /// No description provided for @sessionDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sessionDeleteConfirm;

  /// No description provided for @sessionTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sessions'**
  String get sessionTodayTitle;

  /// No description provided for @sessionDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionDayTitle;

  /// No description provided for @sessionRecordedByAll.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get sessionRecordedByAll;

  /// No description provided for @sessionDayNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No sessions match'**
  String get sessionDayNoMatch;

  /// No description provided for @sessionDayEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions on this day'**
  String get sessionDayEmptyTitle;

  /// No description provided for @sessionDayEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Sessions you record appear here with their fees.'**
  String get sessionDayEmptyBody;

  /// No description provided for @sessionPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get sessionPreviousDay;

  /// No description provided for @sessionNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get sessionNextDay;

  /// No description provided for @sessionBackToToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get sessionBackToToday;

  /// No description provided for @feesPlatformFees.
  ///
  /// In en, this message translates to:
  /// **'Platform fees'**
  String get feesPlatformFees;

  /// No description provided for @feesCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get feesCollected;

  /// No description provided for @feesMonthTitle.
  ///
  /// In en, this message translates to:
  /// **'Monthly summary'**
  String get feesMonthTitle;

  /// No description provided for @feesMonthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Platform fees, examinations and consultations'**
  String get feesMonthSubtitle;

  /// No description provided for @feesPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get feesPreviousMonth;

  /// No description provided for @feesNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get feesNextMonth;

  /// No description provided for @feesMonthTotals.
  ///
  /// In en, this message translates to:
  /// **'Month to date'**
  String get feesMonthTotals;

  /// No description provided for @feesPerBranch.
  ///
  /// In en, this message translates to:
  /// **'Per branch'**
  String get feesPerBranch;

  /// No description provided for @feesMonthNoDays.
  ///
  /// In en, this message translates to:
  /// **'This month has no days yet.'**
  String get feesMonthNoDays;

  /// No description provided for @feesColumnDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get feesColumnDay;

  /// No description provided for @feesColumnExaminations.
  ///
  /// In en, this message translates to:
  /// **'Exam.'**
  String get feesColumnExaminations;

  /// No description provided for @feesColumnConsultations.
  ///
  /// In en, this message translates to:
  /// **'Consult.'**
  String get feesColumnConsultations;

  /// No description provided for @feesColumnAmount.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get feesColumnAmount;

  /// No description provided for @feesToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get feesToday;

  /// No description provided for @feesThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get feesThisMonth;

  /// No description provided for @homeAnalyticsLaterTitle.
  ///
  /// In en, this message translates to:
  /// **'Charts and insights are coming'**
  String get homeAnalyticsLaterTitle;

  /// No description provided for @homeAnalyticsLaterBody.
  ///
  /// In en, this message translates to:
  /// **'Revenue, visits and booking trends arrive in a later update.'**
  String get homeAnalyticsLaterBody;

  /// No description provided for @homeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeToday;

  /// No description provided for @homeSearchPatient.
  ///
  /// In en, this message translates to:
  /// **'Search patient'**
  String get homeSearchPatient;

  /// No description provided for @homeTodaySessions.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sessions'**
  String get homeTodaySessions;

  /// Home list title (current branch).
  ///
  /// In en, this message translates to:
  /// **'Today\'s sessions in {branch}'**
  String homeTodaySessionsIn(String branch);

  /// No description provided for @homeNoSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet today'**
  String get homeNoSessionsTitle;

  /// No description provided for @homeNoSessionsBody.
  ///
  /// In en, this message translates to:
  /// **'Record the first visit of the day.'**
  String get homeNoSessionsBody;

  /// No description provided for @sessionErrorNotLinked.
  ///
  /// In en, this message translates to:
  /// **'This patient isn\'t on your list.'**
  String get sessionErrorNotLinked;

  /// No description provided for @patientErrorAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'This number is already one of your patients.'**
  String get patientErrorAlreadyLinked;

  /// No description provided for @patientErrorPhoneTaken.
  ///
  /// In en, this message translates to:
  /// **'Another patient account uses this number.'**
  String get patientErrorPhoneTaken;

  /// No description provided for @sessionErrorBranchArchived.
  ///
  /// In en, this message translates to:
  /// **'This branch is archived. Choose another branch.'**
  String get sessionErrorBranchArchived;

  /// No description provided for @sessionErrorAmountNotEditable.
  ///
  /// In en, this message translates to:
  /// **'The amount can be changed only on the day of the session.'**
  String get sessionErrorAmountNotEditable;

  /// No description provided for @sessionNoClinical.
  ///
  /// In en, this message translates to:
  /// **'No clinical notes yet.'**
  String get sessionNoClinical;

  /// Consultations since the last examination, D6 summary.
  ///
  /// In en, this message translates to:
  /// **'{count} of {max}'**
  String sessionConsultationShort(int count, int max);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
