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

  /// No description provided for @regErrorInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Enter at least a first and a last name, in letters only.'**
  String get regErrorInvalidName;

  /// No description provided for @regErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in, or use another email.'**
  String get regErrorEmailTaken;

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

  /// No description provided for @regErrorInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid value.'**
  String get regErrorInvalidValue;

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
