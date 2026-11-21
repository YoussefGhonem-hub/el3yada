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

  /// A3: the heading on the sign-in sheet, above the fields.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcome;

  /// A3: the line under the heading. Every role signs in here.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue.'**
  String get loginWelcomeBody;

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
  /// **'Doctors'**
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
  /// **'Create my account'**
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

  /// No description provided for @addressDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Detailed address'**
  String get addressDetailsLabel;

  /// No description provided for @addressDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'For example: 12 Street 9, Al Nour building, 3rd floor, apartment 5'**
  String get addressDetailsHint;

  /// No description provided for @mapLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Google Maps link (optional)'**
  String get mapLinkLabel;

  /// No description provided for @mapLinkHelp.
  ///
  /// In en, this message translates to:
  /// **'In Google Maps, open the clinic\'s place, tap Share, then Copy link, and paste it here.'**
  String get mapLinkHelp;

  /// No description provided for @mapLinkShort.
  ///
  /// In en, this message translates to:
  /// **'Google Maps'**
  String get mapLinkShort;

  /// No description provided for @mapLinkOpen.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get mapLinkOpen;

  /// No description provided for @mapLinkClear.
  ///
  /// In en, this message translates to:
  /// **'Remove the link'**
  String get mapLinkClear;

  /// No description provided for @mapLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'That\'s not a Google Maps link.'**
  String get mapLinkInvalid;

  /// No description provided for @mapLinkOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open Google Maps on this device.'**
  String get mapLinkOpenFailed;

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
  /// **'Check your details, then create your account.'**
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
  /// **'No doctors yet'**
  String get adminSignupsEmptyTitle;

  /// No description provided for @adminSignupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Doctors show up here as soon as they sign up.'**
  String get adminSignupsEmptyBody;

  /// No description provided for @adminSignupsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No doctors match your search'**
  String get adminSignupsNoMatchTitle;

  /// No description provided for @adminSignupsNoMatchBody.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or search by mobile or syndicate number.'**
  String get adminSignupsNoMatchBody;

  /// No description provided for @adminSelectRequest.
  ///
  /// In en, this message translates to:
  /// **'Choose a doctor to see their account'**
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

  /// No description provided for @clinicSuspendedBannerMonth.
  ///
  /// In en, this message translates to:
  /// **'Service is suspended because the {month} invoice is unpaid. Pay it to reactivate.'**
  String clinicSuspendedBannerMonth(String month);

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

  /// BRANCH_LIMIT_REACHED (api-phase-2-clinic.md).
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the most branches you can have. Archive one to add another.'**
  String get branchErrorLimitReached;

  /// No description provided for @branchErrorArchiveDefault.
  ///
  /// In en, this message translates to:
  /// **'The default branch can\'t be archived. Make another branch the default first.'**
  String get branchErrorArchiveDefault;

  /// No description provided for @branchErrorLastActive.
  ///
  /// In en, this message translates to:
  /// **'The clinic needs at least one open branch, so this one can\'t be closed or archived.'**
  String get branchErrorLastActive;

  /// No description provided for @branchErrorHasBookings.
  ///
  /// In en, this message translates to:
  /// **'This branch has upcoming bookings. Move or cancel them first.'**
  String get branchErrorHasBookings;

  /// No description provided for @branchErrorNotActive.
  ///
  /// In en, this message translates to:
  /// **'Only an open branch can be the default.'**
  String get branchErrorNotActive;

  /// No description provided for @branchErrorInvalidBranch.
  ///
  /// In en, this message translates to:
  /// **'Choose one of the clinic\'s open branches.'**
  String get branchErrorInvalidBranch;

  /// No description provided for @branchErrorPeriodEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'Ends before it starts. Turn on «Ends the next day» if it runs past midnight.'**
  String get branchErrorPeriodEndBeforeStart;

  /// No description provided for @branchErrorPeriodLength.
  ///
  /// In en, this message translates to:
  /// **'A period lasts from 15 minutes to 16 hours.'**
  String get branchErrorPeriodLength;

  /// No description provided for @branchErrorPeriodsOverlap.
  ///
  /// In en, this message translates to:
  /// **'The periods overlap.'**
  String get branchErrorPeriodsOverlap;

  /// No description provided for @assistantErrorLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the most assistants you can have.'**
  String get assistantErrorLimitReached;

  /// No description provided for @assistantErrorPhoneTaken.
  ///
  /// In en, this message translates to:
  /// **'This number is already an assistant, in this clinic or another.'**
  String get assistantErrorPhoneTaken;

  /// No description provided for @assistantErrorRemoved.
  ///
  /// In en, this message translates to:
  /// **'This assistant was removed. Add them again as a new assistant.'**
  String get assistantErrorRemoved;

  /// The account button in the top bar (admins: AD18, doctors: D22).
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get profileTopBarTooltip;

  /// No description provided for @settingsSubtitleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Your profile, prices, language, notifications and password.'**
  String get settingsSubtitleDoctor;

  /// No description provided for @settingsSubtitleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Your language, notifications and password, and what you can do in the clinic.'**
  String get settingsSubtitleAssistant;

  /// No description provided for @settingsProfileHint.
  ///
  /// In en, this message translates to:
  /// **'Name, title, degrees and specialties'**
  String get settingsProfileHint;

  /// No description provided for @settingsPermissionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No permissions} =1{1 permission} other{{count} permissions}}'**
  String settingsPermissionCount(int count);

  /// No description provided for @settingsBranchCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No branches} =1{1 branch} other{{count} branches}}'**
  String settingsBranchCount(int count);

  /// No description provided for @settingsClinicGroup.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get settingsClinicGroup;

  /// No description provided for @settingsPricesHint.
  ///
  /// In en, this message translates to:
  /// **'Examination and consultation, for the doctor and each branch'**
  String get settingsPricesHint;

  /// No description provided for @settingsMyPermissions.
  ///
  /// In en, this message translates to:
  /// **'My permissions'**
  String get settingsMyPermissions;

  /// No description provided for @settingsMyPermissionsFooter.
  ///
  /// In en, this message translates to:
  /// **'Only the doctor can change these. Changes apply at once.'**
  String get settingsMyPermissionsFooter;

  /// No description provided for @settingsNoPermissions.
  ///
  /// In en, this message translates to:
  /// **'No permissions yet. Ask the doctor.'**
  String get settingsNoPermissions;

  /// No description provided for @settingsMyBranches.
  ///
  /// In en, this message translates to:
  /// **'My branches'**
  String get settingsMyBranches;

  /// No description provided for @settingsAllBranchesFooter.
  ///
  /// In en, this message translates to:
  /// **'You work in every branch, including ones the doctor adds later.'**
  String get settingsAllBranchesFooter;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotifyChat.
  ///
  /// In en, this message translates to:
  /// **'Chat messages'**
  String get settingsNotifyChat;

  /// No description provided for @settingsNotifyChatHint.
  ///
  /// In en, this message translates to:
  /// **'New messages from patients'**
  String get settingsNotifyChatHint;

  /// No description provided for @settingsNotifyReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsNotifyReminders;

  /// No description provided for @settingsNotifyRemindersHint.
  ///
  /// In en, this message translates to:
  /// **'Invoices and appointments'**
  String get settingsNotifyRemindersHint;

  /// No description provided for @settingsNotifyBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get settingsNotifyBookings;

  /// No description provided for @settingsNotifyBookingsHint.
  ///
  /// In en, this message translates to:
  /// **'New, changed and cancelled bookings'**
  String get settingsNotifyBookingsHint;

  /// No description provided for @settingsShowPreview.
  ///
  /// In en, this message translates to:
  /// **'Show message text in notifications'**
  String get settingsShowPreview;

  /// No description provided for @settingsShowPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Off: notifications only say that a message arrived.'**
  String get settingsShowPreviewHint;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @pricesTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit prices'**
  String get pricesTitle;

  /// No description provided for @assistantPresetReception.
  ///
  /// In en, this message translates to:
  /// **'Reception'**
  String get assistantPresetReception;

  /// No description provided for @assistantPresetClinical.
  ///
  /// In en, this message translates to:
  /// **'Clinical assistant'**
  String get assistantPresetClinical;

  /// No description provided for @assistantPresetOfficeManager.
  ///
  /// In en, this message translates to:
  /// **'Office manager'**
  String get assistantPresetOfficeManager;

  /// No description provided for @assistantPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get assistantPresetCustom;

  /// No description provided for @assistantPresetReceptionBody.
  ///
  /// In en, this message translates to:
  /// **'Patients, visits, files and bookings.'**
  String get assistantPresetReceptionBody;

  /// No description provided for @assistantPresetClinicalBody.
  ///
  /// In en, this message translates to:
  /// **'Reception, plus the medical file, drafts and chat.'**
  String get assistantPresetClinicalBody;

  /// No description provided for @assistantPresetOfficeManagerBody.
  ///
  /// In en, this message translates to:
  /// **'Reception, plus billing, the schedule, prices and chat.'**
  String get assistantPresetOfficeManagerBody;

  /// No description provided for @assistantPresetCustomBody.
  ///
  /// In en, this message translates to:
  /// **'The boxes you tick below.'**
  String get assistantPresetCustomBody;

  /// No description provided for @assistantGroupPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get assistantGroupPatients;

  /// No description provided for @assistantGroupSessions.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get assistantGroupSessions;

  /// No description provided for @assistantGroupClinical.
  ///
  /// In en, this message translates to:
  /// **'Medical file'**
  String get assistantGroupClinical;

  /// No description provided for @assistantGroupFiles.
  ///
  /// In en, this message translates to:
  /// **'Files and prescriptions'**
  String get assistantGroupFiles;

  /// No description provided for @assistantGroupChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get assistantGroupChat;

  /// No description provided for @assistantGroupBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get assistantGroupBilling;

  /// No description provided for @assistantGroupAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get assistantGroupAppointments;

  /// No description provided for @assistantGroupMoney.
  ///
  /// In en, this message translates to:
  /// **'Revenue and prices'**
  String get assistantGroupMoney;

  /// No description provided for @assistantPermPatientsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage patients'**
  String get assistantPermPatientsManage;

  /// No description provided for @assistantPermPatientsManageHelp.
  ///
  /// In en, this message translates to:
  /// **'Add and link patients, edit their details, archive.'**
  String get assistantPermPatientsManageHelp;

  /// No description provided for @assistantPermPatientsResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset patient passwords'**
  String get assistantPermPatientsResetPassword;

  /// No description provided for @assistantPermPatientsResetPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Give a patient a new temporary password, and get their reset requests.'**
  String get assistantPermPatientsResetPasswordHelp;

  /// No description provided for @assistantPermSessionsCreate.
  ///
  /// In en, this message translates to:
  /// **'Record visits'**
  String get assistantPermSessionsCreate;

  /// No description provided for @assistantPermSessionsCreateHelp.
  ///
  /// In en, this message translates to:
  /// **'Visit type, chief complaint and vitals, and the visit list.'**
  String get assistantPermSessionsCreateHelp;

  /// No description provided for @assistantPermSessionsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete visits'**
  String get assistantPermSessionsDelete;

  /// No description provided for @assistantPermSessionsDeleteHelp.
  ///
  /// In en, this message translates to:
  /// **'Under the same conditions as the doctor. Off by default.'**
  String get assistantPermSessionsDeleteHelp;

  /// No description provided for @assistantPermClinicalView.
  ///
  /// In en, this message translates to:
  /// **'View the medical file'**
  String get assistantPermClinicalView;

  /// No description provided for @assistantPermClinicalViewHelp.
  ///
  /// In en, this message translates to:
  /// **'Medical profile, findings, diagnosis, notes and prescriptions.'**
  String get assistantPermClinicalViewHelp;

  /// No description provided for @assistantPermClinicalEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit the medical profile'**
  String get assistantPermClinicalEditProfile;

  /// No description provided for @assistantPermClinicalEditProfileHelp.
  ///
  /// In en, this message translates to:
  /// **'Allergies, chronic diseases, medications, surgeries, family history.'**
  String get assistantPermClinicalEditProfileHelp;

  /// No description provided for @assistantPermFilesManage.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get assistantPermFilesManage;

  /// No description provided for @assistantPermFilesManageHelp.
  ///
  /// In en, this message translates to:
  /// **'Scan, upload and view files, and save chat attachments.'**
  String get assistantPermFilesManageHelp;

  /// No description provided for @assistantPermPrescriptionsPrint.
  ///
  /// In en, this message translates to:
  /// **'Print prescriptions'**
  String get assistantPermPrescriptionsPrint;

  /// No description provided for @assistantPermPrescriptionsPrintHelp.
  ///
  /// In en, this message translates to:
  /// **'Open, print and share prescriptions the doctor sent.'**
  String get assistantPermPrescriptionsPrintHelp;

  /// No description provided for @assistantPermPrescriptionsDraft.
  ///
  /// In en, this message translates to:
  /// **'Prepare prescription drafts'**
  String get assistantPermPrescriptionsDraft;

  /// No description provided for @assistantPermPrescriptionsDraftHelp.
  ///
  /// In en, this message translates to:
  /// **'Write drafts and send them to the doctor for review.'**
  String get assistantPermPrescriptionsDraftHelp;

  /// No description provided for @assistantPermChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get assistantPermChat;

  /// No description provided for @assistantPermChatHelp.
  ///
  /// In en, this message translates to:
  /// **'Read and reply to patients on the doctor\'s behalf.'**
  String get assistantPermChatHelp;

  /// No description provided for @assistantPermBillingView.
  ///
  /// In en, this message translates to:
  /// **'View billing'**
  String get assistantPermBillingView;

  /// No description provided for @assistantPermBillingViewHelp.
  ///
  /// In en, this message translates to:
  /// **'Fee cards, daily and monthly totals, invoices.'**
  String get assistantPermBillingViewHelp;

  /// No description provided for @assistantPermBillingPay.
  ///
  /// In en, this message translates to:
  /// **'Pay invoices'**
  String get assistantPermBillingPay;

  /// No description provided for @assistantPermBillingPayHelp.
  ///
  /// In en, this message translates to:
  /// **'Send the payment for an invoice.'**
  String get assistantPermBillingPayHelp;

  /// No description provided for @assistantPermAppointmentsView.
  ///
  /// In en, this message translates to:
  /// **'View appointments'**
  String get assistantPermAppointmentsView;

  /// No description provided for @assistantPermAppointmentsViewHelp.
  ///
  /// In en, this message translates to:
  /// **'Calendar, today\'s board and search, in their branches.'**
  String get assistantPermAppointmentsViewHelp;

  /// No description provided for @assistantPermAppointmentsManage.
  ///
  /// In en, this message translates to:
  /// **'Manage appointments'**
  String get assistantPermAppointmentsManage;

  /// No description provided for @assistantPermAppointmentsManageHelp.
  ///
  /// In en, this message translates to:
  /// **'Book, confirm, move, cancel, check in, call the next patient.'**
  String get assistantPermAppointmentsManageHelp;

  /// No description provided for @assistantPermScheduleManage.
  ///
  /// In en, this message translates to:
  /// **'Manage the schedule'**
  String get assistantPermScheduleManage;

  /// No description provided for @assistantPermScheduleManageHelp.
  ///
  /// In en, this message translates to:
  /// **'Working hours, special dates and booking settings of their branches.'**
  String get assistantPermScheduleManageHelp;

  /// No description provided for @assistantPermRevenueView.
  ///
  /// In en, this message translates to:
  /// **'View revenue'**
  String get assistantPermRevenueView;

  /// No description provided for @assistantPermRevenueViewHelp.
  ///
  /// In en, this message translates to:
  /// **'Clinic revenue, net income and the amounts patients paid.'**
  String get assistantPermRevenueViewHelp;

  /// No description provided for @assistantPermPricesManage.
  ///
  /// In en, this message translates to:
  /// **'Manage visit prices'**
  String get assistantPermPricesManage;

  /// No description provided for @assistantPermPricesManageHelp.
  ///
  /// In en, this message translates to:
  /// **'The doctor\'s prices, and their branches\' prices.'**
  String get assistantPermPricesManageHelp;

  /// No description provided for @assistantStatusRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get assistantStatusRemoved;

  /// No description provided for @branchStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get branchStatusActive;

  /// No description provided for @branchStatusArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get branchStatusArchived;

  /// No description provided for @branchDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get branchDefault;

  /// No description provided for @branchPayCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get branchPayCash;

  /// No description provided for @branchPayCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get branchPayCard;

  /// No description provided for @branchPayInstapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get branchPayInstapay;

  /// No description provided for @branchPayWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile wallet'**
  String get branchPayWallet;

  /// No description provided for @branchAmenityElevator.
  ///
  /// In en, this message translates to:
  /// **'Elevator'**
  String get branchAmenityElevator;

  /// No description provided for @branchAmenityParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get branchAmenityParking;

  /// No description provided for @branchAmenityWheelchair.
  ///
  /// In en, this message translates to:
  /// **'Wheelchair access'**
  String get branchAmenityWheelchair;

  /// No description provided for @branchAmenityKidsArea.
  ///
  /// In en, this message translates to:
  /// **'Children\'s waiting area'**
  String get branchAmenityKidsArea;

  /// No description provided for @branchEndsNextDayShort.
  ///
  /// In en, this message translates to:
  /// **'{range} (next day)'**
  String branchEndsNextDayShort(String range);

  /// No description provided for @profileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your personal and professional details, as patients and the admin team see them.'**
  String get profileSubtitle;

  /// No description provided for @profileLastSaved.
  ///
  /// In en, this message translates to:
  /// **'Last saved {time}'**
  String profileLastSaved(String time);

  /// No description provided for @profilePersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get profilePersonal;

  /// No description provided for @profileFullNameAr.
  ///
  /// In en, this message translates to:
  /// **'Full name in Arabic'**
  String get profileFullNameAr;

  /// No description provided for @profileReadOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'These identify your account and license. To change them, contact support.'**
  String get profileReadOnlyNote;

  /// No description provided for @profileProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional details'**
  String get profileProfessional;

  /// No description provided for @profileDegreesHint.
  ///
  /// In en, this message translates to:
  /// **'For example: MSc in internal medicine, Cairo University'**
  String get profileDegreesHint;

  /// No description provided for @profileSpecialtyNote.
  ///
  /// In en, this message translates to:
  /// **'A specialty change applies at once, and the admin team is told.'**
  String get profileSpecialtyNote;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @profileSavedSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Profile saved. Your new specialty applies now, and the admin team was told.'**
  String get profileSavedSpecialty;

  /// No description provided for @profilePrescriptionHeader.
  ///
  /// In en, this message translates to:
  /// **'Prescription header'**
  String get profilePrescriptionHeader;

  /// No description provided for @profilePrescriptionHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Logo, signature, colour and print settings'**
  String get profilePrescriptionHeaderTitle;

  /// No description provided for @profilePrescriptionHeaderLater.
  ///
  /// In en, this message translates to:
  /// **'You\'ll set how your prescriptions look when prescriptions arrive in the app.'**
  String get profilePrescriptionHeaderLater;

  /// No description provided for @settingsLaterPhase.
  ///
  /// In en, this message translates to:
  /// **'Later phase'**
  String get settingsLaterPhase;

  /// No description provided for @pricesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What patients pay at the clinic, for the doctor and for each branch.'**
  String get pricesSubtitle;

  /// No description provided for @pricesFutureOnly.
  ///
  /// In en, this message translates to:
  /// **'New prices apply to future visits only.'**
  String get pricesFutureOnly;

  /// No description provided for @pricesDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s prices'**
  String get pricesDoctorTitle;

  /// No description provided for @pricesDoctorBody.
  ///
  /// In en, this message translates to:
  /// **'Every branch without its own prices uses these.'**
  String get pricesDoctorBody;

  /// No description provided for @pricesBranchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Branch prices'**
  String get pricesBranchesTitle;

  /// No description provided for @pricesUseDoctor.
  ///
  /// In en, this message translates to:
  /// **'Use the doctor\'s prices'**
  String get pricesUseDoctor;

  /// No description provided for @pricesUseDoctorOn.
  ///
  /// In en, this message translates to:
  /// **'Examination: {examination}, consultation: {consultation}'**
  String pricesUseDoctorOn(String examination, String consultation);

  /// No description provided for @pricesUseDoctorOff.
  ///
  /// In en, this message translates to:
  /// **'This branch\'s own prices. An empty one uses the doctor\'s.'**
  String get pricesUseDoctorOff;

  /// No description provided for @pricesEmptyAskClinic.
  ///
  /// In en, this message translates to:
  /// **'Empty: patients see «Ask the clinic», and the amount is typed at each visit.'**
  String get pricesEmptyAskClinic;

  /// No description provided for @pricesEmptyUsesDoctor.
  ///
  /// In en, this message translates to:
  /// **'Empty: the doctor\'s price ({price}) applies.'**
  String pricesEmptyUsesDoctor(String price);

  /// No description provided for @pricesAskClinic.
  ///
  /// In en, this message translates to:
  /// **'Ask the clinic'**
  String get pricesAskClinic;

  /// No description provided for @pricesSaved.
  ///
  /// In en, this message translates to:
  /// **'Prices saved. They apply to visits from now on.'**
  String get pricesSaved;

  /// No description provided for @pricesNotYourBranch.
  ///
  /// In en, this message translates to:
  /// **'Only the doctor or this branch\'s assistants can change these prices.'**
  String get pricesNotYourBranch;

  /// No description provided for @pricesHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Change history'**
  String get pricesHistoryTitle;

  /// No description provided for @pricesHistoryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No price changes yet'**
  String get pricesHistoryEmptyTitle;

  /// No description provided for @pricesHistoryEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every change shows here, with who made it and when.'**
  String get pricesHistoryEmptyBody;

  /// No description provided for @pricesNotSet.
  ///
  /// In en, this message translates to:
  /// **'not set'**
  String get pricesNotSet;

  /// No description provided for @pricesChange.
  ///
  /// In en, this message translates to:
  /// **'{type}: {before} → {after}'**
  String pricesChange(String type, String before, String after);

  /// No description provided for @pricesChangedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} ({role}), {time}'**
  String pricesChangedBy(String name, String role, String time);

  /// No description provided for @branchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where you see patients. Tap a branch to change its details, hours or status.'**
  String get branchesSubtitle;

  /// No description provided for @branchesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No branches yet'**
  String get branchesEmptyTitle;

  /// No description provided for @branchAdd.
  ///
  /// In en, this message translates to:
  /// **'Add branch'**
  String get branchAdd;

  /// D28 «2 من 5». Archived branches don't count.
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} branches'**
  String branchCountOf(int count, int limit);

  /// No description provided for @branchArchivedHint.
  ///
  /// In en, this message translates to:
  /// **'Archived: hidden from patients and bookings'**
  String get branchArchivedHint;

  /// No description provided for @branchClosedToday.
  ///
  /// In en, this message translates to:
  /// **'Closed today'**
  String get branchClosedToday;

  /// No description provided for @branchUpcomingBookings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No upcoming bookings} =1{1 upcoming booking} other{{count} upcoming bookings}}'**
  String branchUpcomingBookings(int count);

  /// No description provided for @branchReopensOn.
  ///
  /// In en, this message translates to:
  /// **'Reopens on {date}'**
  String branchReopensOn(String date);

  /// No description provided for @branchSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get branchSaved;

  /// No description provided for @branchTabInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get branchTabInfo;

  /// No description provided for @branchTabAddress.
  ///
  /// In en, this message translates to:
  /// **'Address and map'**
  String get branchTabAddress;

  /// No description provided for @branchTabContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get branchTabContact;

  /// No description provided for @branchTabHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get branchTabHours;

  /// No description provided for @branchTabClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic info for patients'**
  String get branchTabClinic;

  /// No description provided for @branchTabUnsaved.
  ///
  /// In en, this message translates to:
  /// **'{tab}, not saved'**
  String branchTabUnsaved(String tab);

  /// No description provided for @branchDescription.
  ///
  /// In en, this message translates to:
  /// **'Short description (optional)'**
  String get branchDescription;

  /// No description provided for @branchDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'For example: second floor, next to the pharmacy'**
  String get branchDescriptionHint;

  /// No description provided for @branchAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Area (optional)'**
  String get branchAreaLabel;

  /// No description provided for @branchEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Clinic email (optional)'**
  String get branchEmailLabel;

  /// No description provided for @branchPaymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment at the clinic'**
  String get branchPaymentMethods;

  /// No description provided for @branchAmenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get branchAmenities;

  /// No description provided for @branchForPatients.
  ///
  /// In en, this message translates to:
  /// **'What patients see'**
  String get branchForPatients;

  /// No description provided for @branchForPatientsBody.
  ///
  /// In en, this message translates to:
  /// **'Shown on the branch card when patients book.'**
  String get branchForPatientsBody;

  /// No description provided for @branchPricesTitle.
  ///
  /// In en, this message translates to:
  /// **'This branch\'s prices'**
  String get branchPricesTitle;

  /// No description provided for @branchHoursQueueNote.
  ///
  /// In en, this message translates to:
  /// **'Bookings here go by queue number. Each period takes {count} patients unless you set its own number.'**
  String branchHoursQueueNote(int count);

  /// No description provided for @branchHoursTimedNote.
  ///
  /// In en, this message translates to:
  /// **'Bookings here go by appointment time.'**
  String get branchHoursTimedNote;

  /// No description provided for @branchCopySaturday.
  ///
  /// In en, this message translates to:
  /// **'Copy Saturday to all days'**
  String get branchCopySaturday;

  /// No description provided for @branchCopySaturdayTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy Saturday to every day?'**
  String get branchCopySaturdayTitle;

  /// No description provided for @branchCopySaturdayBody.
  ///
  /// In en, this message translates to:
  /// **'The other days\' periods are replaced by Saturday\'s. Nothing is saved until you tap Save.'**
  String get branchCopySaturdayBody;

  /// No description provided for @branchDayClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get branchDayClosed;

  /// No description provided for @branchAddPeriod.
  ///
  /// In en, this message translates to:
  /// **'Add period'**
  String get branchAddPeriod;

  /// No description provided for @branchRemovePeriod.
  ///
  /// In en, this message translates to:
  /// **'Remove this period'**
  String get branchRemovePeriod;

  /// No description provided for @branchPeriodFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get branchPeriodFrom;

  /// No description provided for @branchPeriodTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get branchPeriodTo;

  /// No description provided for @branchEndsNextDay.
  ///
  /// In en, this message translates to:
  /// **'Ends the next day'**
  String get branchEndsNextDay;

  /// No description provided for @branchPeriodMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get branchPeriodMorning;

  /// No description provided for @branchPeriodEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get branchPeriodEvening;

  /// No description provided for @branchCapacity.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get branchCapacity;

  /// No description provided for @branchErrorTooManyPeriods.
  ///
  /// In en, this message translates to:
  /// **'At most 10 periods a day.'**
  String get branchErrorTooManyPeriods;

  /// No description provided for @branchStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Branch status'**
  String get branchStatusTitle;

  /// No description provided for @branchStatusActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Open: patients see it and can book.'**
  String get branchStatusActiveBody;

  /// No description provided for @branchStatusDefaultBody.
  ///
  /// In en, this message translates to:
  /// **'Open, and the default: new visits use it unless you pick another branch.'**
  String get branchStatusDefaultBody;

  /// No description provided for @branchStatusClosedBody.
  ///
  /// In en, this message translates to:
  /// **'Patients see your message on the branch card and can\'t book here.'**
  String get branchStatusClosedBody;

  /// No description provided for @branchStatusArchivedBody.
  ///
  /// In en, this message translates to:
  /// **'Hidden from patients and bookings. Its history stays, and you can bring it back.'**
  String get branchStatusArchivedBody;

  /// No description provided for @branchPatientsSee.
  ///
  /// In en, this message translates to:
  /// **'Patients see'**
  String get branchPatientsSee;

  /// No description provided for @branchMakeDefault.
  ///
  /// In en, this message translates to:
  /// **'Make default'**
  String get branchMakeDefault;

  /// No description provided for @branchMakeDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the default?'**
  String branchMakeDefaultTitle(String name);

  /// No description provided for @branchMakeDefaultBody.
  ///
  /// In en, this message translates to:
  /// **'New visits and walk-ins use the default branch unless another one is picked.'**
  String get branchMakeDefaultBody;

  /// No description provided for @branchDefaultMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} is now the default branch.'**
  String branchDefaultMessage(String name);

  /// No description provided for @branchCloseTemporarily.
  ///
  /// In en, this message translates to:
  /// **'Close temporarily'**
  String get branchCloseTemporarily;

  /// No description provided for @branchCloseBody.
  ///
  /// In en, this message translates to:
  /// **'Patients see this message on the branch card and can\'t book here until you reopen it.'**
  String get branchCloseBody;

  /// No description provided for @branchClosedMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message for patients'**
  String get branchClosedMessageLabel;

  /// No description provided for @branchClosedMessageHint.
  ///
  /// In en, this message translates to:
  /// **'For example: closed for renovation'**
  String get branchClosedMessageHint;

  /// No description provided for @branchReopenDateAdd.
  ///
  /// In en, this message translates to:
  /// **'Expected reopening date (optional)'**
  String get branchReopenDateAdd;

  /// No description provided for @branchCloseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close the branch'**
  String get branchCloseConfirm;

  /// No description provided for @branchClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'The branch is closed for now.'**
  String get branchClosedMessage;

  /// No description provided for @branchEditClosure.
  ///
  /// In en, this message translates to:
  /// **'Edit the message'**
  String get branchEditClosure;

  /// No description provided for @branchReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get branchReopen;

  /// No description provided for @branchReopenedMessage.
  ///
  /// In en, this message translates to:
  /// **'The branch is open again.'**
  String get branchReopenedMessage;

  /// No description provided for @branchArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get branchArchive;

  /// No description provided for @branchArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}?'**
  String branchArchiveTitle(String name);

  /// No description provided for @branchArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears for patients and can\'t take bookings. Its visits and history stay, and you can bring it back later.'**
  String get branchArchiveBody;

  /// No description provided for @branchArchivedMessage.
  ///
  /// In en, this message translates to:
  /// **'The branch is archived.'**
  String get branchArchivedMessage;

  /// No description provided for @branchRestore.
  ///
  /// In en, this message translates to:
  /// **'Bring back'**
  String get branchRestore;

  /// No description provided for @branchRestoredMessage.
  ///
  /// In en, this message translates to:
  /// **'The branch is back and open.'**
  String get branchRestoredMessage;

  /// No description provided for @branchRefusedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not possible yet'**
  String get branchRefusedTitle;

  /// No description provided for @branchBookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 upcoming booking} other{{count} upcoming bookings}}'**
  String branchBookingsTitle(int count);

  /// No description provided for @branchBookingsMore.
  ///
  /// In en, this message translates to:
  /// **'And {count} more.'**
  String branchBookingsMore(int count);

  /// No description provided for @branchBookingsHint.
  ///
  /// In en, this message translates to:
  /// **'Move them to another branch or cancel them from the appointments calendar, then try again. Cancelled patients are told, with a link to book again.'**
  String get branchBookingsHint;

  /// No description provided for @branchBookingGuest.
  ///
  /// In en, this message translates to:
  /// **'{name} (guest)'**
  String branchBookingGuest(String name);

  /// No description provided for @branchLaterTabs.
  ///
  /// In en, this message translates to:
  /// **'Coming later'**
  String get branchLaterTabs;

  /// No description provided for @branchLaterTabsTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking settings and special dates'**
  String get branchLaterTabsTitle;

  /// No description provided for @branchLaterTabsBody.
  ///
  /// In en, this message translates to:
  /// **'They arrive with appointments.'**
  String get branchLaterTabsBody;

  /// No description provided for @branchAddedMessage.
  ///
  /// In en, this message translates to:
  /// **'Branch added. Now set its working hours.'**
  String get branchAddedMessage;

  /// No description provided for @branchNewNextSteps.
  ///
  /// In en, this message translates to:
  /// **'Working hours and prices come next, after you add the branch.'**
  String get branchNewNextSteps;

  /// No description provided for @assistantsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'People who work with you, and what each one can do.'**
  String get assistantsSubtitle;

  /// No description provided for @assistantAdd.
  ///
  /// In en, this message translates to:
  /// **'Add assistant'**
  String get assistantAdd;

  /// D25 «2 من 5». Removed assistants don't count.
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} assistants'**
  String assistantCountOf(int count, int limit);

  /// No description provided for @assistantsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No assistants yet'**
  String get assistantsEmptyTitle;

  /// No description provided for @assistantsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add someone from reception to record visits and bookings for you.'**
  String get assistantsEmptyBody;

  /// No description provided for @assistantChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose an assistant to see their details'**
  String get assistantChoose;

  /// No description provided for @assistantAddBody.
  ///
  /// In en, this message translates to:
  /// **'They get a temporary password and choose their own when they first sign in.'**
  String get assistantAddBody;

  /// No description provided for @assistantNeverActive.
  ///
  /// In en, this message translates to:
  /// **'Hasn\'t used the clinic yet'**
  String get assistantNeverActive;

  /// No description provided for @assistantLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {time}'**
  String assistantLastActive(String time);

  /// No description provided for @assistantAddedOn.
  ///
  /// In en, this message translates to:
  /// **'Added on {date}'**
  String assistantAddedOn(String date);

  /// No description provided for @assistantDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get assistantDetails;

  /// No description provided for @assistantPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'They sign in with this number.'**
  String get assistantPhoneHint;

  /// No description provided for @assistantBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get assistantBranches;

  /// No description provided for @assistantBranchesHint.
  ///
  /// In en, this message translates to:
  /// **'Bookings, today\'s board and visit lists show only these branches.'**
  String get assistantBranchesHint;

  /// No description provided for @assistantAllBranches.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get assistantAllBranches;

  /// No description provided for @assistantSomeBranches.
  ///
  /// In en, this message translates to:
  /// **'Some branches'**
  String get assistantSomeBranches;

  /// No description provided for @assistantAllBranchesBody.
  ///
  /// In en, this message translates to:
  /// **'Including branches you add later.'**
  String get assistantAllBranchesBody;

  /// No description provided for @assistantErrorBranchRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one branch.'**
  String get assistantErrorBranchRequired;

  /// No description provided for @assistantPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get assistantPermissions;

  /// No description provided for @assistantPermissionsHint.
  ///
  /// In en, this message translates to:
  /// **'Pick a preset, then adjust the boxes. Some need another, which is ticked for you.'**
  String get assistantPermissionsHint;

  /// No description provided for @assistantAlsoOn.
  ///
  /// In en, this message translates to:
  /// **'Also turned on: {permissions}'**
  String assistantAlsoOn(String permissions);

  /// No description provided for @assistantAlsoOff.
  ///
  /// In en, this message translates to:
  /// **'Also turned off: {permissions}'**
  String assistantAlsoOff(String permissions);

  /// No description provided for @assistantSaved.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s changes are saved. They apply on their next action.'**
  String assistantSaved(String name);

  /// No description provided for @assistantAccountActions.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get assistantAccountActions;

  /// No description provided for @assistantResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get assistantResetPassword;

  /// No description provided for @assistantResetPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'A new temporary password, when they forget theirs.'**
  String get assistantResetPasswordHint;

  /// No description provided for @assistantResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset {name}\'s password?'**
  String assistantResetTitle(String name);

  /// No description provided for @assistantResetBody.
  ///
  /// In en, this message translates to:
  /// **'They\'re signed out on every device and sign in again with the new temporary password.'**
  String get assistantResetBody;

  /// No description provided for @assistantNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'New temporary password'**
  String get assistantNewPasswordTitle;

  /// No description provided for @assistantDisableHint.
  ///
  /// In en, this message translates to:
  /// **'Stops them signing in, at once. You can enable them again.'**
  String get assistantDisableHint;

  /// No description provided for @assistantEnableHint.
  ///
  /// In en, this message translates to:
  /// **'They can sign in again.'**
  String get assistantEnableHint;

  /// No description provided for @assistantDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable {name}?'**
  String assistantDisableTitle(String name);

  /// No description provided for @assistantDisableBody.
  ///
  /// In en, this message translates to:
  /// **'They\'re signed out at once and can\'t sign in until you enable them again.'**
  String get assistantDisableBody;

  /// No description provided for @assistantEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable {name}?'**
  String assistantEnableTitle(String name);

  /// No description provided for @assistantEnableBody.
  ///
  /// In en, this message translates to:
  /// **'They can sign in again with their password.'**
  String get assistantEnableBody;

  /// No description provided for @assistantRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get assistantRemove;

  /// No description provided for @assistantRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Final. Their history stays in the activity log.'**
  String get assistantRemoveHint;

  /// No description provided for @assistantRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String assistantRemoveTitle(String name);

  /// No description provided for @assistantRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'They\'re signed out at once and can\'t come back. Their history stays in the activity log, and their number can be added again as a new assistant.'**
  String get assistantRemoveBody;

  /// No description provided for @assistantRemovedMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed.'**
  String assistantRemovedMessage(String name);

  /// No description provided for @assistantRemovedTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} was removed'**
  String assistantRemovedTitle(String name);

  /// No description provided for @activityCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing recorded yet} =1{1 entry} other{{count} entries}}'**
  String activityCount(int count);

  /// No description provided for @activityEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet'**
  String get activityEmptyTitle;

  /// No description provided for @activityEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'What you and your assistants do in the clinic shows here.'**
  String get activityEmptyBody;

  /// No description provided for @activityToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get activityToday;

  /// No description provided for @activityYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get activityYesterday;

  /// No description provided for @activityWhoWhen.
  ///
  /// In en, this message translates to:
  /// **'{who}, {time}'**
  String activityWhoWhen(String who, String time);

  /// No description provided for @activityRemovedPerson.
  ///
  /// In en, this message translates to:
  /// **'{name} (removed)'**
  String activityRemovedPerson(String name);

  /// No description provided for @activityPatientFile.
  ///
  /// In en, this message translates to:
  /// **'{name}, file {number}'**
  String activityPatientFile(String name, int number);

  /// No description provided for @activityPatientUnlinked.
  ///
  /// In en, this message translates to:
  /// **'A patient no longer in the clinic'**
  String get activityPatientUnlinked;

  /// No description provided for @activityOnlyThisPatient.
  ///
  /// In en, this message translates to:
  /// **'Only this patient'**
  String get activityOnlyThisPatient;

  /// No description provided for @activitySomeBranch.
  ///
  /// In en, this message translates to:
  /// **'a branch'**
  String get activitySomeBranch;

  /// No description provided for @activitySomeAssistant.
  ///
  /// In en, this message translates to:
  /// **'an assistant'**
  String get activitySomeAssistant;

  /// No description provided for @activityBranchCreated.
  ///
  /// In en, this message translates to:
  /// **'Added the branch {branch}'**
  String activityBranchCreated(String branch);

  /// No description provided for @activityBranchUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited {branch}'**
  String activityBranchUpdated(String branch);

  /// No description provided for @activityBranchHoursUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed the working hours of {branch}'**
  String activityBranchHoursUpdated(String branch);

  /// No description provided for @activityBranchStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'{branch}: {before} → {after}'**
  String activityBranchStatusChanged(
    String branch,
    String before,
    String after,
  );

  /// No description provided for @activityDefaultBranchChanged.
  ///
  /// In en, this message translates to:
  /// **'Made {branch} the default branch'**
  String activityDefaultBranchChanged(String branch);

  /// No description provided for @activityDoctorPricesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed the doctor\'s visit prices'**
  String get activityDoctorPricesUpdated;

  /// No description provided for @activityBranchPricesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed the prices of {branch}'**
  String activityBranchPricesUpdated(String branch);

  /// No description provided for @activityProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited the profile'**
  String get activityProfileUpdated;

  /// No description provided for @activitySpecialtyChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed the specialty'**
  String get activitySpecialtyChanged;

  /// No description provided for @activityAssistantCreated.
  ///
  /// In en, this message translates to:
  /// **'Added the assistant {name} ({preset})'**
  String activityAssistantCreated(String name, String preset);

  /// No description provided for @activityAssistantUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited {name}\'s details'**
  String activityAssistantUpdated(String name);

  /// No description provided for @activityAssistantPermissionsChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed {name}\'s permissions'**
  String activityAssistantPermissionsChanged(String name);

  /// No description provided for @activityAssistantPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Reset {name}\'s password'**
  String activityAssistantPasswordReset(String name);

  /// No description provided for @activityAssistantDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled {name}'**
  String activityAssistantDisabled(String name);

  /// No description provided for @activityAssistantEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled {name}'**
  String activityAssistantEnabled(String name);

  /// No description provided for @activityAssistantRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed {name}'**
  String activityAssistantRemoved(String name);

  /// No description provided for @activityPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed their password'**
  String get activityPasswordChanged;

  /// No description provided for @activityPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Set their password'**
  String get activityPasswordSet;

  /// No description provided for @activityPasswordResetRequested.
  ///
  /// In en, this message translates to:
  /// **'{name} asked for a new password'**
  String activityPasswordResetRequested(String name);

  /// No description provided for @activityRegistrationSent.
  ///
  /// In en, this message translates to:
  /// **'Sent the sign-up request'**
  String get activityRegistrationSent;

  /// No description provided for @activityEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Confirmed the email'**
  String get activityEmailVerified;

  /// No description provided for @activityOther.
  ///
  /// In en, this message translates to:
  /// **'Other action: {action}'**
  String activityOther(String action);

  /// No description provided for @activityPermissionsAdded.
  ///
  /// In en, this message translates to:
  /// **'Added: {permissions}.'**
  String activityPermissionsAdded(String permissions);

  /// No description provided for @activityPermissionsRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed: {permissions}.'**
  String activityPermissionsRemoved(String permissions);

  /// No description provided for @activityPeriods.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Closed every day} =1{1 period a week} other{{count} periods a week}}'**
  String activityPeriods(int count);

  /// No description provided for @activityActionBranchCreated.
  ///
  /// In en, this message translates to:
  /// **'Branch added'**
  String get activityActionBranchCreated;

  /// No description provided for @activityActionBranchUpdated.
  ///
  /// In en, this message translates to:
  /// **'Branch edited'**
  String get activityActionBranchUpdated;

  /// No description provided for @activityActionBranchHoursUpdated.
  ///
  /// In en, this message translates to:
  /// **'Working hours changed'**
  String get activityActionBranchHoursUpdated;

  /// No description provided for @activityActionBranchStatusChanged.
  ///
  /// In en, this message translates to:
  /// **'Branch status changed'**
  String get activityActionBranchStatusChanged;

  /// No description provided for @activityActionDefaultBranchChanged.
  ///
  /// In en, this message translates to:
  /// **'Default branch changed'**
  String get activityActionDefaultBranchChanged;

  /// No description provided for @activityActionPricesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Prices changed'**
  String get activityActionPricesUpdated;

  /// No description provided for @activityActionProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile edited'**
  String get activityActionProfileUpdated;

  /// No description provided for @activityActionSpecialtyChanged.
  ///
  /// In en, this message translates to:
  /// **'Specialty changed'**
  String get activityActionSpecialtyChanged;

  /// No description provided for @activityActionAssistantCreated.
  ///
  /// In en, this message translates to:
  /// **'Assistant added'**
  String get activityActionAssistantCreated;

  /// No description provided for @activityActionAssistantUpdated.
  ///
  /// In en, this message translates to:
  /// **'Assistant edited'**
  String get activityActionAssistantUpdated;

  /// No description provided for @activityActionPermissionsChanged.
  ///
  /// In en, this message translates to:
  /// **'Permissions changed'**
  String get activityActionPermissionsChanged;

  /// No description provided for @activityActionAssistantPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Assistant password reset'**
  String get activityActionAssistantPasswordReset;

  /// No description provided for @activityActionAssistantDisabled.
  ///
  /// In en, this message translates to:
  /// **'Assistant disabled'**
  String get activityActionAssistantDisabled;

  /// No description provided for @activityActionAssistantEnabled.
  ///
  /// In en, this message translates to:
  /// **'Assistant enabled'**
  String get activityActionAssistantEnabled;

  /// No description provided for @activityActionAssistantRemoved.
  ///
  /// In en, this message translates to:
  /// **'Assistant removed'**
  String get activityActionAssistantRemoved;

  /// No description provided for @activityActionPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get activityActionPasswordChanged;

  /// No description provided for @activityActionPasswordSet.
  ///
  /// In en, this message translates to:
  /// **'Password chosen'**
  String get activityActionPasswordSet;

  /// No description provided for @activityActionPasswordResetRequested.
  ///
  /// In en, this message translates to:
  /// **'New password requested'**
  String get activityActionPasswordResetRequested;

  /// No description provided for @activityActionRegistrationSent.
  ///
  /// In en, this message translates to:
  /// **'Sign-up sent'**
  String get activityActionRegistrationSent;

  /// No description provided for @activityActionEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Email confirmed'**
  String get activityActionEmailVerified;

  /// No description provided for @assistantNotAddedYet.
  ///
  /// In en, this message translates to:
  /// **'Not added yet'**
  String get assistantNotAddedYet;

  /// No description provided for @assistantNameHint.
  ///
  /// In en, this message translates to:
  /// **'A first and a last name, at least'**
  String get assistantNameHint;

  /// No description provided for @activityPatientCreated.
  ///
  /// In en, this message translates to:
  /// **'Added a new patient'**
  String get activityPatientCreated;

  /// No description provided for @activityPatientLinked.
  ///
  /// In en, this message translates to:
  /// **'Added a patient who already has an account'**
  String get activityPatientLinked;

  /// No description provided for @activityPatientUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited the patient\'s details'**
  String get activityPatientUpdated;

  /// No description provided for @activityPatientPhoneChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed the patient\'s mobile number'**
  String get activityPatientPhoneChanged;

  /// No description provided for @activityPatientPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Reset the patient\'s password'**
  String get activityPatientPasswordReset;

  /// No description provided for @activityPatientArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived the patient\'s file'**
  String get activityPatientArchived;

  /// No description provided for @activityPatientUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Brought the patient\'s file back from the archive'**
  String get activityPatientUnarchived;

  /// No description provided for @activityPatientMedicalProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited the medical profile'**
  String get activityPatientMedicalProfileUpdated;

  /// No description provided for @activitySessionCreatedExamination.
  ///
  /// In en, this message translates to:
  /// **'Recorded an examination'**
  String get activitySessionCreatedExamination;

  /// No description provided for @activitySessionCreatedConsultation.
  ///
  /// In en, this message translates to:
  /// **'Recorded a consultation'**
  String get activitySessionCreatedConsultation;

  /// No description provided for @activitySessionClinicalUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited a visit\'s medical notes'**
  String get activitySessionClinicalUpdated;

  /// No description provided for @activitySessionPrivateNoteUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited a visit\'s private note'**
  String get activitySessionPrivateNoteUpdated;

  /// No description provided for @activitySessionAmountChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed the amount charged for a visit'**
  String get activitySessionAmountChanged;

  /// No description provided for @activitySessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted a visit'**
  String get activitySessionDeleted;

  /// D27: an amount that changed.
  ///
  /// In en, this message translates to:
  /// **'From {before} to {after}'**
  String activityFromTo(String before, String after);

  /// D27: why a visit was deleted (BR-S7).
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String activityReason(String reason);

  /// No description provided for @activityActionPatientCreated.
  ///
  /// In en, this message translates to:
  /// **'Patient added'**
  String get activityActionPatientCreated;

  /// No description provided for @activityActionPatientLinked.
  ///
  /// In en, this message translates to:
  /// **'Patient linked'**
  String get activityActionPatientLinked;

  /// No description provided for @activityActionPatientUpdated.
  ///
  /// In en, this message translates to:
  /// **'Patient edited'**
  String get activityActionPatientUpdated;

  /// No description provided for @activityActionPatientPhoneChanged.
  ///
  /// In en, this message translates to:
  /// **'Patient mobile changed'**
  String get activityActionPatientPhoneChanged;

  /// No description provided for @activityActionPatientPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'Patient password reset'**
  String get activityActionPatientPasswordReset;

  /// No description provided for @activityActionPatientArchived.
  ///
  /// In en, this message translates to:
  /// **'Patient archived'**
  String get activityActionPatientArchived;

  /// No description provided for @activityActionPatientUnarchived.
  ///
  /// In en, this message translates to:
  /// **'Patient unarchived'**
  String get activityActionPatientUnarchived;

  /// No description provided for @activityActionPatientMedicalProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Medical profile edited'**
  String get activityActionPatientMedicalProfileUpdated;

  /// No description provided for @activityActionSessionCreated.
  ///
  /// In en, this message translates to:
  /// **'Visit recorded'**
  String get activityActionSessionCreated;

  /// No description provided for @activityActionSessionClinicalUpdated.
  ///
  /// In en, this message translates to:
  /// **'Visit notes edited'**
  String get activityActionSessionClinicalUpdated;

  /// No description provided for @activityActionSessionPrivateNoteUpdated.
  ///
  /// In en, this message translates to:
  /// **'Private note edited'**
  String get activityActionSessionPrivateNoteUpdated;

  /// No description provided for @activityActionSessionAmountChanged.
  ///
  /// In en, this message translates to:
  /// **'Amount charged changed'**
  String get activityActionSessionAmountChanged;

  /// No description provided for @activityActionSessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Visit deleted'**
  String get activityActionSessionDeleted;

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

  /// Screen-reader name of the desktop Back pill, which shows the section it returns to.
  ///
  /// In en, this message translates to:
  /// **'Back to {section}'**
  String backToSection(String section);

  /// No description provided for @trialEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your free trial has ended'**
  String get trialEndedTitle;

  /// No description provided for @trialEndedBody.
  ///
  /// In en, this message translates to:
  /// **'Contact us to activate the service and keep using el3yada. Your patients and records are kept safe.'**
  String get trialEndedBody;

  /// No description provided for @trialEndedTitleAssistant.
  ///
  /// In en, this message translates to:
  /// **'The clinic\'s free trial has ended'**
  String get trialEndedTitleAssistant;

  /// No description provided for @trialEndedBodyAssistant.
  ///
  /// In en, this message translates to:
  /// **'Ask the doctor to contact us to activate the service. Then you can carry on as usual.'**
  String get trialEndedBodyAssistant;

  /// No description provided for @trialCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get trialCheckAgain;

  /// No description provided for @trialStillEnded.
  ///
  /// In en, this message translates to:
  /// **'The service isn\'t active yet.'**
  String get trialStillEnded;

  /// BR-T6: the shell banner in the last days of the free trial.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Your free trial ends today} =1{1 day left in your free trial} other{{days} days left in your free trial}}'**
  String trialBanner(int days);

  /// No description provided for @trialContactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get trialContactUs;

  /// No description provided for @errorTrialEnded.
  ///
  /// In en, this message translates to:
  /// **'The free trial has ended. Contact us to activate the service.'**
  String get errorTrialEnded;

  /// No description provided for @sessionFeeFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Free (trial)'**
  String get sessionFeeFreeTrial;

  /// No description provided for @sessionPlatformFeeFree.
  ///
  /// In en, this message translates to:
  /// **'No platform fee (free trial)'**
  String get sessionPlatformFeeFree;

  /// No description provided for @sessionConfirmFeeFree.
  ///
  /// In en, this message translates to:
  /// **'No fee: the clinic is in its free trial.'**
  String get sessionConfirmFeeFree;

  /// No description provided for @sessionSavedBodyFree.
  ///
  /// In en, this message translates to:
  /// **'{type} for {patient}. No fee (free trial).'**
  String sessionSavedBodyFree(String type, String patient);

  /// No description provided for @adminErrorServiceAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'This doctor\'s service is already active, so there\'s no trial to extend.'**
  String get adminErrorServiceAlreadyActive;

  /// No description provided for @adminErrorDoctorStatusNotChangeable.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be done for a doctor who is pending, rejected or disabled.'**
  String get adminErrorDoctorStatusNotChangeable;

  /// No description provided for @adminSettingTrialDays.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get adminSettingTrialDays;

  /// No description provided for @adminAppliesToNewDoctors.
  ///
  /// In en, this message translates to:
  /// **'Applies to doctors approved after the change'**
  String get adminAppliesToNewDoctors;

  /// No description provided for @adminDoctorsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All doctors'**
  String get adminDoctorsFilterAll;

  /// No description provided for @adminSignupsFilterTrialRunning.
  ///
  /// In en, this message translates to:
  /// **'In free trial'**
  String get adminSignupsFilterTrialRunning;

  /// No description provided for @adminSignupsFilterTrialEnded.
  ///
  /// In en, this message translates to:
  /// **'Trial ended'**
  String get adminSignupsFilterTrialEnded;

  /// No description provided for @adminDoctorsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No doctors} =1{1 doctor} other{{count} doctors}}'**
  String adminDoctorsCount(int count);

  /// No description provided for @adminTrialListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No doctors here'**
  String get adminTrialListEmpty;

  /// No description provided for @adminTrialListEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Doctors show up here by the state of their free trial.'**
  String get adminTrialListEmptyBody;

  /// No description provided for @adminServiceActive.
  ///
  /// In en, this message translates to:
  /// **'Service active'**
  String get adminServiceActive;

  /// No description provided for @adminTrialEnded.
  ///
  /// In en, this message translates to:
  /// **'Trial ended'**
  String get adminTrialEnded;

  /// No description provided for @adminTrialDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Trial: ends today} =1{Trial: 1 day left} other{Trial: {days} days left}}'**
  String adminTrialDaysLeft(int days);

  /// No description provided for @adminSectionTrial.
  ///
  /// In en, this message translates to:
  /// **'Free trial'**
  String get adminSectionTrial;

  /// No description provided for @adminServiceActiveBody.
  ///
  /// In en, this message translates to:
  /// **'The service is active. Sessions carry the platform fees.'**
  String get adminServiceActiveBody;

  /// No description provided for @adminTrialRunningBody.
  ///
  /// In en, this message translates to:
  /// **'The free trial ends on {date}. Sessions until then carry no fee.'**
  String adminTrialRunningBody(String date);

  /// No description provided for @adminTrialEndedBody.
  ///
  /// In en, this message translates to:
  /// **'The free trial ended on {date}. The doctor and their assistants can\'t use the clinic until you activate the service or extend the trial.'**
  String adminTrialEndedBody(String date);

  /// No description provided for @adminActivateService.
  ///
  /// In en, this message translates to:
  /// **'Activate service'**
  String get adminActivateService;

  /// No description provided for @adminActivateServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Activate the service for Dr. {name}?'**
  String adminActivateServiceTitle(String name);

  /// No description provided for @adminActivateServiceBody.
  ///
  /// In en, this message translates to:
  /// **'The free trial ends now, and platform fees apply to every session from now on.'**
  String get adminActivateServiceBody;

  /// No description provided for @adminServiceActivatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Service activated for Dr. {name}.'**
  String adminServiceActivatedMessage(String name);

  /// No description provided for @adminExtendTrial.
  ///
  /// In en, this message translates to:
  /// **'Extend trial'**
  String get adminExtendTrial;

  /// No description provided for @adminExtendTrialTitle.
  ///
  /// In en, this message translates to:
  /// **'Extend Dr. {name}\'s free trial'**
  String adminExtendTrialTitle(String name);

  /// No description provided for @adminExtendTrialBody.
  ///
  /// In en, this message translates to:
  /// **'The days are added to the end of the trial, or to today if it has ended.'**
  String get adminExtendTrialBody;

  /// No description provided for @adminExtendTrialDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get adminExtendTrialDays;

  /// No description provided for @adminTrialExtendedMessage.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name}\'s free trial now ends on {date}.'**
  String adminTrialExtendedMessage(String name, String date);

  /// No description provided for @adminAuditServiceActivated.
  ///
  /// In en, this message translates to:
  /// **'Activated a doctor\'s service'**
  String get adminAuditServiceActivated;

  /// No description provided for @adminAuditTrialExtended.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Extended a doctor\'s free trial by 1 day} other{Extended a doctor\'s free trial by {days} days}}'**
  String adminAuditTrialExtended(int days);

  /// No description provided for @adminActionServiceActivated.
  ///
  /// In en, this message translates to:
  /// **'Service activated'**
  String get adminActionServiceActivated;

  /// No description provided for @adminActionTrialExtended.
  ///
  /// In en, this message translates to:
  /// **'Trial extended'**
  String get adminActionTrialExtended;

  /// D0: the catalog download screen's heading (spec 6.9, BR-CAT11).
  ///
  /// In en, this message translates to:
  /// **'Getting the medicines and tests guide ready'**
  String get catalogSetupTitle;

  /// No description provided for @catalogSetupBody.
  ///
  /// In en, this message translates to:
  /// **'We\'re downloading the Egyptian medicines, lab tests and radiology guide to your device, so search is instant and works offline.'**
  String get catalogSetupBody;

  /// No description provided for @catalogSetupMeanwhile.
  ///
  /// In en, this message translates to:
  /// **'You can keep working. Until it finishes, search suggests what you\'ve written before and you can type any name.'**
  String get catalogSetupMeanwhile;

  /// No description provided for @catalogSetupWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi recommended'**
  String get catalogSetupWifi;

  /// No description provided for @catalogSetupProgress.
  ///
  /// In en, this message translates to:
  /// **'{received} of {total}'**
  String catalogSetupProgress(String received, String total);

  /// No description provided for @catalogVersionLine.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · {size}'**
  String catalogVersionLine(String version, String size);

  /// No description provided for @catalogVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String catalogVersionTitle(String version);

  /// No description provided for @catalogContinue.
  ///
  /// In en, this message translates to:
  /// **'Keep using the app'**
  String get catalogContinue;

  /// No description provided for @catalogPhaseChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for the latest version…'**
  String get catalogPhaseChecking;

  /// No description provided for @catalogPhaseDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String catalogPhaseDownloading(String percent);

  /// No description provided for @catalogPhaseVerifying.
  ///
  /// In en, this message translates to:
  /// **'Checking and preparing the file…'**
  String get catalogPhaseVerifying;

  /// No description provided for @catalogPhaseReady.
  ///
  /// In en, this message translates to:
  /// **'The guide is ready on your device'**
  String get catalogPhaseReady;

  /// No description provided for @catalogPhaseNotPublished.
  ///
  /// In en, this message translates to:
  /// **'No guide is published yet. Until it is, type names yourself; they\'re saved to your list.'**
  String get catalogPhaseNotPublished;

  /// No description provided for @catalogPhaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The guide isn\'t available on this device. Search covers what you\'ve written before.'**
  String get catalogPhaseUnavailable;

  /// No description provided for @catalogFailureNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Try again picks up where it stopped.'**
  String get catalogFailureNetwork;

  /// No description provided for @catalogFailureServer.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem. Try again in a little while.'**
  String get catalogFailureServer;

  /// No description provided for @catalogFailureChecksum.
  ///
  /// In en, this message translates to:
  /// **'The downloaded file was damaged and has been deleted. Try again.'**
  String get catalogFailureChecksum;

  /// No description provided for @catalogFailureCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The file isn\'t a valid guide and has been deleted. Try again.'**
  String get catalogFailureCorrupt;

  /// No description provided for @catalogFailureSchema.
  ///
  /// In en, this message translates to:
  /// **'The new version needs a newer app. Update the app to use it.'**
  String get catalogFailureSchema;

  /// No description provided for @catalogFailureStorage.
  ///
  /// In en, this message translates to:
  /// **'There isn\'t enough space on this device.'**
  String get catalogFailureStorage;

  /// No description provided for @catalogStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · ready'**
  String catalogStatusReady(String version);

  /// No description provided for @catalogStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Download stopped. Open it to try again.'**
  String get catalogStatusFailed;

  /// No description provided for @catalogStatusNotPublished.
  ///
  /// In en, this message translates to:
  /// **'No version published yet'**
  String get catalogStatusNotPublished;

  /// No description provided for @catalogStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not on this device'**
  String get catalogStatusUnavailable;

  /// No description provided for @catalogSettingsTile.
  ///
  /// In en, this message translates to:
  /// **'Medicines and tests guide'**
  String get catalogSettingsTile;

  /// No description provided for @catalogNotPublished.
  ///
  /// In en, this message translates to:
  /// **'No catalog version is published yet'**
  String get catalogNotPublished;

  /// Under a product the drug dataset marks N/A (not on the market).
  ///
  /// In en, this message translates to:
  /// **'May not be available'**
  String get catalogMayBeUnavailable;

  /// A small tag on an admin's custom catalog item (BR-CAT9).
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get catalogCustomTag;

  /// No description provided for @catalogTypeDrug.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get catalogTypeDrug;

  /// No description provided for @catalogTypeLab.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get catalogTypeLab;

  /// No description provided for @catalogTypeRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get catalogTypeRadiology;

  /// No description provided for @catalogTypeDrugs.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get catalogTypeDrugs;

  /// No description provided for @catalogTypeLabs.
  ///
  /// In en, this message translates to:
  /// **'Lab tests'**
  String get catalogTypeLabs;

  /// No description provided for @catalogTypeRadiologyPlural.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get catalogTypeRadiologyPlural;

  /// No description provided for @catalogReportMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing item'**
  String get catalogReportMissing;

  /// No description provided for @catalogReportWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong details'**
  String get catalogReportWrong;

  /// No description provided for @catalogReportOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catalogReportOther;

  /// No description provided for @catalogRouteOralSolid.
  ///
  /// In en, this message translates to:
  /// **'Oral (tablets, capsules)'**
  String get catalogRouteOralSolid;

  /// No description provided for @catalogRouteOralLiquid.
  ///
  /// In en, this message translates to:
  /// **'Oral liquids (syrups, drops)'**
  String get catalogRouteOralLiquid;

  /// No description provided for @catalogRouteInjection.
  ///
  /// In en, this message translates to:
  /// **'Injection'**
  String get catalogRouteInjection;

  /// No description provided for @catalogRouteTopical.
  ///
  /// In en, this message translates to:
  /// **'Topical (creams, ointments)'**
  String get catalogRouteTopical;

  /// No description provided for @catalogRouteEffervescent.
  ///
  /// In en, this message translates to:
  /// **'Effervescent'**
  String get catalogRouteEffervescent;

  /// No description provided for @catalogRouteRectal.
  ///
  /// In en, this message translates to:
  /// **'Rectal (suppositories)'**
  String get catalogRouteRectal;

  /// No description provided for @catalogRouteEye.
  ///
  /// In en, this message translates to:
  /// **'Eye'**
  String get catalogRouteEye;

  /// No description provided for @catalogRouteEar.
  ///
  /// In en, this message translates to:
  /// **'Ear'**
  String get catalogRouteEar;

  /// No description provided for @catalogRouteSpray.
  ///
  /// In en, this message translates to:
  /// **'Spray'**
  String get catalogRouteSpray;

  /// No description provided for @catalogRouteVaginal.
  ///
  /// In en, this message translates to:
  /// **'Vaginal'**
  String get catalogRouteVaginal;

  /// No description provided for @catalogRouteMouth.
  ///
  /// In en, this message translates to:
  /// **'Mouth and teeth'**
  String get catalogRouteMouth;

  /// No description provided for @catalogRouteSoap.
  ///
  /// In en, this message translates to:
  /// **'Soap and wash'**
  String get catalogRouteSoap;

  /// No description provided for @catalogRouteUnknown.
  ///
  /// In en, this message translates to:
  /// **'Not stated'**
  String get catalogRouteUnknown;

  /// No description provided for @catalogErrorShaMismatch.
  ///
  /// In en, this message translates to:
  /// **'The file doesn\'t match its manifest (sha256). Choose the pair the builder made together.'**
  String get catalogErrorShaMismatch;

  /// No description provided for @catalogErrorManifest.
  ///
  /// In en, this message translates to:
  /// **'The manifest has no valid sha256. Choose the .json the builder wrote with this file.'**
  String get catalogErrorManifest;

  /// No description provided for @catalogErrorFileInvalid.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t a catalog made by the catalog builder.'**
  String get catalogErrorFileInvalid;

  /// No description provided for @catalogErrorSchema.
  ///
  /// In en, this message translates to:
  /// **'This file\'s format is version {actual}; the apps read version {expected}. Build it with the matching catalog builder.'**
  String catalogErrorSchema(String actual, String expected);

  /// No description provided for @catalogErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than 150 MB.'**
  String get catalogErrorTooLarge;

  /// About: the LOINC notice and the other credits (BR-CAT14).
  ///
  /// In en, this message translates to:
  /// **'Data sources and licences'**
  String get catalogSourcesTitle;

  /// No description provided for @catalogSourcesIntro.
  ///
  /// In en, this message translates to:
  /// **'The app\'s medicines, lab tests and radiology guide is built from these sources. LOINC names are shown exactly as published.'**
  String get catalogSourcesIntro;

  /// No description provided for @catalogSourceDrugsTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get catalogSourceDrugsTitle;

  /// No description provided for @catalogSourceDrugsBody.
  ///
  /// In en, this message translates to:
  /// **'The Egyptian Drug Database by karem505, in the public domain (CC0). Prices aren\'t shown because they go out of date.'**
  String get catalogSourceDrugsBody;

  /// No description provided for @catalogSourceDrugsDate.
  ///
  /// In en, this message translates to:
  /// **'Data as of {date}'**
  String catalogSourceDrugsDate(String date);

  /// No description provided for @catalogSourceLoincTitle.
  ///
  /// In en, this message translates to:
  /// **'Lab tests and radiology (LOINC)'**
  String get catalogSourceLoincTitle;

  /// No description provided for @catalogSourceLoincBody.
  ///
  /// In en, this message translates to:
  /// **'Lab test names and codes come from LOINC, kept exactly as published. The required copyright notice:'**
  String get catalogSourceLoincBody;

  /// No description provided for @catalogSourceLoincRelease.
  ///
  /// In en, this message translates to:
  /// **'LOINC release on this device: {release}'**
  String catalogSourceLoincRelease(String release);

  /// No description provided for @catalogSourceRadlexTitle.
  ///
  /// In en, this message translates to:
  /// **'Radiology (LOINC/RSNA Radiology Playbook)'**
  String get catalogSourceRadlexTitle;

  /// No description provided for @catalogSourceRadlexBody.
  ///
  /// In en, this message translates to:
  /// **'Radiology procedures, modalities and body regions come from the LOINC/RSNA Radiology Playbook, which includes RadLex content:'**
  String get catalogSourceRadlexBody;

  /// No description provided for @catalogSourceOursTitle.
  ///
  /// In en, this message translates to:
  /// **'Arabic names and short names'**
  String get catalogSourceOursTitle;

  /// No description provided for @catalogSourceOursBody.
  ///
  /// In en, this message translates to:
  /// **'Arabic names and short names such as «صورة دم كاملة» and CBC are written by the el3yada team and kept separate from LOINC content.'**
  String get catalogSourceOursBody;

  /// No description provided for @adminCatalogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Medicines, lab tests and radiology on doctors\' devices'**
  String get adminCatalogSubtitle;

  /// No description provided for @adminCatalogPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish new version'**
  String get adminCatalogPublish;

  /// No description provided for @adminCatalogTabVersions.
  ///
  /// In en, this message translates to:
  /// **'Versions'**
  String get adminCatalogTabVersions;

  /// No description provided for @adminCatalogTabCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom items'**
  String get adminCatalogTabCustom;

  /// No description provided for @adminCatalogTabReports.
  ///
  /// In en, this message translates to:
  /// **'Doctor reports'**
  String get adminCatalogTabReports;

  /// No description provided for @adminCatalogCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get adminCatalogCurrent;

  /// No description provided for @adminCatalogCurrentPill.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get adminCatalogCurrentPill;

  /// No description provided for @adminCatalogAllVersions.
  ///
  /// In en, this message translates to:
  /// **'All versions'**
  String get adminCatalogAllVersions;

  /// No description provided for @adminCatalogPublishedOn.
  ///
  /// In en, this message translates to:
  /// **'Published {date}'**
  String adminCatalogPublishedOn(String date);

  /// No description provided for @adminCatalogCounts.
  ///
  /// In en, this message translates to:
  /// **'{drugs} medicines · {labs} lab tests · {radiology} radiology'**
  String adminCatalogCounts(String drugs, String labs, String radiology);

  /// No description provided for @adminCatalogDrugSource.
  ///
  /// In en, this message translates to:
  /// **'Drug data of {date}'**
  String adminCatalogDrugSource(String date);

  /// No description provided for @adminCatalogLoincRelease.
  ///
  /// In en, this message translates to:
  /// **'LOINC {release}'**
  String adminCatalogLoincRelease(String release);

  /// No description provided for @adminCatalogNothingPublishedBody.
  ///
  /// In en, this message translates to:
  /// **'Until a version is published, doctors\' search covers only what they\'ve written before.'**
  String get adminCatalogNothingPublishedBody;

  /// No description provided for @adminCatalogThisDevice.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get adminCatalogThisDevice;

  /// No description provided for @adminCatalogOpenSetup.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get adminCatalogOpenSetup;

  /// No description provided for @adminCatalogPublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish a new catalog version'**
  String get adminCatalogPublishTitle;

  /// No description provided for @adminCatalogPublishBody.
  ///
  /// In en, this message translates to:
  /// **'Upload the file the catalog builder made (catalog-v<n>.sqlite.gz) with its manifest. The server checks it, then devices download it in the background.'**
  String get adminCatalogPublishBody;

  /// No description provided for @adminCatalogNoFile.
  ///
  /// In en, this message translates to:
  /// **'No file chosen yet'**
  String get adminCatalogNoFile;

  /// No description provided for @adminCatalogNoManifest.
  ///
  /// In en, this message translates to:
  /// **'No manifest (.json) yet'**
  String get adminCatalogNoManifest;

  /// No description provided for @adminCatalogPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get adminCatalogPickFile;

  /// No description provided for @adminCatalogPickManifest.
  ///
  /// In en, this message translates to:
  /// **'Choose manifest'**
  String get adminCatalogPickManifest;

  /// No description provided for @adminCatalogChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the file\'s sha256…'**
  String get adminCatalogChecking;

  /// No description provided for @adminCatalogShaMatches.
  ///
  /// In en, this message translates to:
  /// **'The file matches its manifest (sha256)'**
  String get adminCatalogShaMatches;

  /// No description provided for @adminCatalogUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading… {sent} of {total}'**
  String adminCatalogUploading(String sent, String total);

  /// No description provided for @adminCatalogServerChecking.
  ///
  /// In en, this message translates to:
  /// **'The server is checking the file…'**
  String get adminCatalogServerChecking;

  /// No description provided for @adminCatalogDropTitle.
  ///
  /// In en, this message translates to:
  /// **'This version has far fewer items than the current one:'**
  String get adminCatalogDropTitle;

  /// No description provided for @adminCatalogDropRow.
  ///
  /// In en, this message translates to:
  /// **'{table}: {previous} → {current}'**
  String adminCatalogDropRow(String table, String previous, String current);

  /// No description provided for @adminCatalogDropBody.
  ///
  /// In en, this message translates to:
  /// **'Publish anyway only if that\'s intended, for example a cleaned-up medicines list.'**
  String get adminCatalogDropBody;

  /// No description provided for @adminCatalogPublishAnyway.
  ///
  /// In en, this message translates to:
  /// **'Publish anyway'**
  String get adminCatalogPublishAnyway;

  /// No description provided for @adminCatalogPublished.
  ///
  /// In en, this message translates to:
  /// **'Version {version} published'**
  String adminCatalogPublished(String version);

  /// No description provided for @adminCatalogPublishedBody.
  ///
  /// In en, this message translates to:
  /// **'Doctors\' devices download it in the background and switch to it when it\'s complete.'**
  String get adminCatalogPublishedBody;

  /// No description provided for @adminCatalogAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminCatalogAllTypes;

  /// No description provided for @adminCatalogShowDisabled.
  ///
  /// In en, this message translates to:
  /// **'Show disabled'**
  String get adminCatalogShowDisabled;

  /// No description provided for @adminCatalogSearchItems.
  ///
  /// In en, this message translates to:
  /// **'Search items'**
  String get adminCatalogSearchItems;

  /// No description provided for @adminCatalogAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get adminCatalogAddItem;

  /// No description provided for @adminCatalogEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get adminCatalogEditItem;

  /// No description provided for @adminCatalogEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get adminCatalogEdit;

  /// No description provided for @adminCatalogItemActions.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String adminCatalogItemActions(String name);

  /// No description provided for @adminCatalogItemBody.
  ///
  /// In en, this message translates to:
  /// **'Every doctor sees it in search within a minute, without a new catalog version.'**
  String get adminCatalogItemBody;

  /// No description provided for @adminCatalogNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items here yet. Add the medicines or tests the catalog is missing.'**
  String get adminCatalogNoItems;

  /// No description provided for @adminCatalogItemDisabled.
  ///
  /// In en, this message translates to:
  /// **'{name} is off. Doctors stop seeing it within a minute.'**
  String adminCatalogItemDisabled(String name);

  /// No description provided for @adminCatalogItemEnabled.
  ///
  /// In en, this message translates to:
  /// **'{name} is back on. Doctors see it within a minute.'**
  String adminCatalogItemEnabled(String name);

  /// No description provided for @adminCatalogUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed {when}'**
  String adminCatalogUpdated(String when);

  /// No description provided for @adminCatalogFieldTradeName.
  ///
  /// In en, this message translates to:
  /// **'Trade name'**
  String get adminCatalogFieldTradeName;

  /// No description provided for @adminCatalogFieldTradeNameHint.
  ///
  /// In en, this message translates to:
  /// **'As on the box, e.g. NEWCILLIN 500 MG 12 CAPS.'**
  String get adminCatalogFieldTradeNameHint;

  /// No description provided for @adminCatalogFieldTestName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminCatalogFieldTestName;

  /// No description provided for @adminCatalogFieldNameAr.
  ///
  /// In en, this message translates to:
  /// **'Arabic name (optional)'**
  String get adminCatalogFieldNameAr;

  /// No description provided for @adminCatalogFieldIngredient.
  ///
  /// In en, this message translates to:
  /// **'Active ingredient'**
  String get adminCatalogFieldIngredient;

  /// No description provided for @adminCatalogFieldGroup.
  ///
  /// In en, this message translates to:
  /// **'Medicine group'**
  String get adminCatalogFieldGroup;

  /// No description provided for @adminCatalogFieldRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get adminCatalogFieldRoute;

  /// No description provided for @adminCatalogFieldCode.
  ///
  /// In en, this message translates to:
  /// **'LOINC code (optional)'**
  String get adminCatalogFieldCode;

  /// No description provided for @adminCatalogFieldCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2093-3'**
  String get adminCatalogFieldCodeHint;

  /// No description provided for @adminCatalogFieldAliases.
  ///
  /// In en, this message translates to:
  /// **'Short names'**
  String get adminCatalogFieldAliases;

  /// No description provided for @adminCatalogFieldAliasesHint.
  ///
  /// In en, this message translates to:
  /// **'Separated by commas, e.g. CBC, Blood count'**
  String get adminCatalogFieldAliasesHint;

  /// No description provided for @adminCatalogAliasesTooMany.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 short names, each up to 100 characters'**
  String get adminCatalogAliasesTooMany;

  /// No description provided for @adminCatalogItemActive.
  ///
  /// In en, this message translates to:
  /// **'Shown to doctors'**
  String get adminCatalogItemActive;

  /// No description provided for @adminCatalogItemActiveHint.
  ///
  /// In en, this message translates to:
  /// **'Turn off to hide it from every doctor\'s search.'**
  String get adminCatalogItemActiveHint;

  /// No description provided for @adminCatalogSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminCatalogSave;

  /// No description provided for @adminCatalogReportsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get adminCatalogReportsOpen;

  /// No description provided for @adminCatalogReportsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get adminCatalogReportsDone;

  /// No description provided for @adminCatalogMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get adminCatalogMarkDone;

  /// No description provided for @adminCatalogReportHandled.
  ///
  /// In en, this message translates to:
  /// **'Marked as done'**
  String get adminCatalogReportHandled;

  /// No description provided for @adminCatalogHandledOn.
  ///
  /// In en, this message translates to:
  /// **'Handled {date}'**
  String adminCatalogHandledOn(String date);

  /// No description provided for @adminCatalogNoReports.
  ///
  /// In en, this message translates to:
  /// **'No reports here.'**
  String get adminCatalogNoReports;

  /// No description provided for @specialtyProfilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What each specialty sees first when searching medicines and tests'**
  String get specialtyProfilesSubtitle;

  /// No description provided for @specialtyDoctorCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No doctors} =1{1 doctor} other{{count} doctors}}'**
  String specialtyDoctorCount(int count);

  /// No description provided for @specialtyItemsSummary.
  ///
  /// In en, this message translates to:
  /// **'{groups} medicine groups · {labs} lab tests · {radiology} radiology'**
  String specialtyItemsSummary(int groups, int labs, int radiology);

  /// No description provided for @specialtyGeneralBadge.
  ///
  /// In en, this message translates to:
  /// **'Added to every specialty'**
  String get specialtyGeneralBadge;

  /// No description provided for @specialtyWithGeneral.
  ///
  /// In en, this message translates to:
  /// **'With General'**
  String get specialtyWithGeneral;

  /// No description provided for @specialtyGeneralBody.
  ///
  /// In en, this message translates to:
  /// **'Added to every specialty that includes it'**
  String get specialtyGeneralBody;

  /// No description provided for @specialtyGeneralExplained.
  ///
  /// In en, this message translates to:
  /// **'This is the General profile: the common medicines and tests (painkillers, antibiotics, CBC …) that come first in every specialty that includes it.'**
  String get specialtyGeneralExplained;

  /// No description provided for @specialtyUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changed {when}'**
  String specialtyUpdated(String when);

  /// No description provided for @specialtyCatalogNotReady.
  ///
  /// In en, this message translates to:
  /// **'The catalog is still downloading on this device; counts, names and search show up when it\'s done.'**
  String get specialtyCatalogNotReady;

  /// No description provided for @specialtyIncludeGeneral.
  ///
  /// In en, this message translates to:
  /// **'Include the General profile'**
  String get specialtyIncludeGeneral;

  /// No description provided for @specialtyIncludeGeneralHint.
  ///
  /// In en, this message translates to:
  /// **'Painkillers, antibiotics, stomach protection, CBC and the other common items come first too.'**
  String get specialtyIncludeGeneralHint;

  /// No description provided for @specialtyGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine groups'**
  String get specialtyGroupsTitle;

  /// No description provided for @specialtyGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Medicines in these groups appear under «Your specialty». The number is how many products each group has.'**
  String get specialtyGroupsHint;

  /// No description provided for @specialtyGroupsFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter groups'**
  String get specialtyGroupsFilter;

  /// No description provided for @specialtySelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None chosen} =1{1 chosen} other{{count} chosen}}'**
  String specialtySelectedCount(int count);

  /// No description provided for @specialtyRoutesTitle.
  ///
  /// In en, this message translates to:
  /// **'Preferred routes'**
  String get specialtyRoutesTitle;

  /// No description provided for @specialtyRoutesHint.
  ///
  /// In en, this message translates to:
  /// **'Shown first inside each section, for example syrups and suppositories for children'**
  String get specialtyRoutesHint;

  /// No description provided for @specialtyLabsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommended lab tests'**
  String get specialtyLabsTitle;

  /// No description provided for @specialtyNoLabs.
  ///
  /// In en, this message translates to:
  /// **'No recommended lab tests yet.'**
  String get specialtyNoLabs;

  /// No description provided for @specialtyAddLab.
  ///
  /// In en, this message translates to:
  /// **'Search the catalog to add a lab test'**
  String get specialtyAddLab;

  /// No description provided for @specialtyRadiologyTitle.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get specialtyRadiologyTitle;

  /// No description provided for @specialtyRadiologyHint.
  ///
  /// In en, this message translates to:
  /// **'Procedures of these body regions or modalities appear under «Your specialty»'**
  String get specialtyRadiologyHint;

  /// No description provided for @specialtyRegions.
  ///
  /// In en, this message translates to:
  /// **'Body regions'**
  String get specialtyRegions;

  /// No description provided for @specialtyModalities.
  ///
  /// In en, this message translates to:
  /// **'Modalities'**
  String get specialtyModalities;

  /// No description provided for @specialtyProcedures.
  ///
  /// In en, this message translates to:
  /// **'Recommended procedures'**
  String get specialtyProcedures;

  /// No description provided for @specialtyNoProcedures.
  ///
  /// In en, this message translates to:
  /// **'No recommended procedures yet.'**
  String get specialtyNoProcedures;

  /// No description provided for @specialtyAddProcedure.
  ///
  /// In en, this message translates to:
  /// **'Search the catalog to add a procedure'**
  String get specialtyAddProcedure;

  /// No description provided for @specialtyShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count})'**
  String specialtyShowAll(int count);

  /// No description provided for @specialtyShowFewer.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get specialtyShowFewer;

  /// No description provided for @specialtyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get specialtyRemove;

  /// No description provided for @specialtyCopyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy from another specialty'**
  String get specialtyCopyTitle;

  /// No description provided for @specialtyCopyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy the {name} profile?'**
  String specialtyCopyConfirmTitle(String name);

  /// No description provided for @specialtyCopyConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Its medicine groups, routes, tests and radiology replace this profile\'s. You can still change them afterwards.'**
  String get specialtyCopyConfirmBody;

  /// No description provided for @specialtyCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get specialtyCopy;

  /// No description provided for @specialtyCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied from {name}'**
  String specialtyCopied(String name);

  /// No description provided for @specialtyPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Search preview'**
  String get specialtyPreviewTitle;

  /// No description provided for @specialtyPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'What a doctor of this specialty sees first, with your unsaved changes'**
  String get specialtyPreviewHint;

  /// No description provided for @specialtyPreviewTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get specialtyPreviewTests;

  /// No description provided for @specialtyPreviewDrugsSample.
  ///
  /// In en, this message translates to:
  /// **'Try: ator, omep, panadol'**
  String get specialtyPreviewDrugsSample;

  /// No description provided for @specialtyPreviewTestsSample.
  ///
  /// In en, this message translates to:
  /// **'Try: CBC, echo, X-ray'**
  String get specialtyPreviewTestsSample;

  /// No description provided for @specialtyPreviewNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches.'**
  String get specialtyPreviewNothing;

  /// No description provided for @regWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to el3yada'**
  String get regWelcomeTitle;

  /// The welcome after sign-up: the free trial length (spec 6.16).
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{You have a free trial for 1 day.} other{You have a free trial for {days} days.}}'**
  String regWelcomeTrial(int days);

  /// No description provided for @regWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Add your patients and record sessions with no platform fees during the trial.'**
  String get regWelcomeBody;

  /// No description provided for @regWelcomeStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get regWelcomeStart;

  /// No description provided for @adminDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor account'**
  String get adminDoctorTitle;

  /// No description provided for @emailBannerDismiss.
  ///
  /// In en, this message translates to:
  /// **'Hide for now'**
  String get emailBannerDismiss;

  /// No description provided for @settingsVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify your email address'**
  String get settingsVerifyEmail;

  /// No description provided for @patientTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get patientTabFiles;

  /// No description provided for @recordCategoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get recordCategoryAll;

  /// No description provided for @recordCategoryRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get recordCategoryRadiology;

  /// No description provided for @recordCategoryLab.
  ///
  /// In en, this message translates to:
  /// **'Lab tests'**
  String get recordCategoryLab;

  /// No description provided for @recordCategoryPrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get recordCategoryPrescription;

  /// No description provided for @recordCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recordCategoryOther;

  /// No description provided for @recordChip.
  ///
  /// In en, this message translates to:
  /// **'{name} {count}'**
  String recordChip(String name, int count);

  /// No description provided for @recordOtherReport.
  ///
  /// In en, this message translates to:
  /// **'Medical report'**
  String get recordOtherReport;

  /// No description provided for @recordOtherReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get recordOtherReferral;

  /// No description provided for @recordOtherSickLeave.
  ///
  /// In en, this message translates to:
  /// **'Sick leave'**
  String get recordOtherSickLeave;

  /// No description provided for @recordOtherEcg.
  ///
  /// In en, this message translates to:
  /// **'ECG'**
  String get recordOtherEcg;

  /// No description provided for @recordOtherEegEmg.
  ///
  /// In en, this message translates to:
  /// **'EEG / EMG'**
  String get recordOtherEegEmg;

  /// No description provided for @recordOtherEndoscopy.
  ///
  /// In en, this message translates to:
  /// **'Endoscopy'**
  String get recordOtherEndoscopy;

  /// No description provided for @recordOtherConsent.
  ///
  /// In en, this message translates to:
  /// **'Consent form'**
  String get recordOtherConsent;

  /// No description provided for @recordOtherCustom.
  ///
  /// In en, this message translates to:
  /// **'Another type (type it)'**
  String get recordOtherCustom;

  /// No description provided for @recordOtherNone.
  ///
  /// In en, this message translates to:
  /// **'No type'**
  String get recordOtherNone;

  /// No description provided for @recordsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get recordsEmptyTitle;

  /// No description provided for @recordsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Scan or upload lab results, X-rays and other papers. The patient sees them in their app.'**
  String get recordsEmptyBody;

  /// No description provided for @recordsEmptyCategory.
  ///
  /// In en, this message translates to:
  /// **'No files in this category'**
  String get recordsEmptyCategory;

  /// No description provided for @recordAddFiles.
  ///
  /// In en, this message translates to:
  /// **'Upload files'**
  String get recordAddFiles;

  /// No description provided for @recordScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get recordScan;

  /// No description provided for @recordDropHint.
  ///
  /// In en, this message translates to:
  /// **'Drop the files to upload them'**
  String get recordDropHint;

  /// No description provided for @recordFilesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String recordFilesCount(int count);

  /// No description provided for @recordPagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String recordPagesCount(int count);

  /// No description provided for @sizeBytes.
  ///
  /// In en, this message translates to:
  /// **'{value} B'**
  String sizeBytes(String value);

  /// No description provided for @sizeKb.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String sizeKb(String value);

  /// No description provided for @sizeMb.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String sizeMb(String value);

  /// No description provided for @recordUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload files'**
  String get recordUploadTitle;

  /// No description provided for @recordScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan a document'**
  String get recordScanTitle;

  /// No description provided for @recordEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit file details'**
  String get recordEditTitle;

  /// No description provided for @recordFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get recordFieldCategory;

  /// No description provided for @recordFieldOtherType.
  ///
  /// In en, this message translates to:
  /// **'Document type (optional)'**
  String get recordFieldOtherType;

  /// No description provided for @recordFieldOtherTypeText.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get recordFieldOtherTypeText;

  /// No description provided for @recordFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get recordFieldTitle;

  /// No description provided for @recordTitleHint.
  ///
  /// In en, this message translates to:
  /// **'If left empty: {title}'**
  String recordTitleHint(String title);

  /// No description provided for @recordFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Document date'**
  String get recordFieldDate;

  /// No description provided for @recordFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get recordFieldNotes;

  /// No description provided for @recordFieldSession.
  ///
  /// In en, this message translates to:
  /// **'Link to a visit'**
  String get recordFieldSession;

  /// No description provided for @recordNoSession.
  ///
  /// In en, this message translates to:
  /// **'No visit'**
  String get recordNoSession;

  /// No description provided for @recordSessionOption.
  ///
  /// In en, this message translates to:
  /// **'{type} · {date}'**
  String recordSessionOption(String type, String date);

  /// No description provided for @recordCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get recordCategoryRequired;

  /// No description provided for @recordFilesHeading.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get recordFilesHeading;

  /// No description provided for @recordDetailsHeading.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get recordDetailsHeading;

  /// No description provided for @recordAddMore.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get recordAddMore;

  /// No description provided for @recordFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get recordFromFiles;

  /// No description provided for @recordFromCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get recordFromCamera;

  /// No description provided for @recordFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get recordFromGallery;

  /// No description provided for @recordSave.
  ///
  /// In en, this message translates to:
  /// **'Save to the patient\'s file'**
  String get recordSave;

  /// No description provided for @recordSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to the patient\'s file'**
  String get recordSaved;

  /// No description provided for @recordUpdated.
  ///
  /// In en, this message translates to:
  /// **'File details saved'**
  String get recordUpdated;

  /// No description provided for @recordPreparing.
  ///
  /// In en, this message translates to:
  /// **'Making it smaller…'**
  String get recordPreparing;

  /// No description provided for @recordUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String recordUploading(int percent);

  /// No description provided for @recordUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get recordUploaded;

  /// No description provided for @recordUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get recordUploadFailed;

  /// No description provided for @recordRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get recordRemoveFile;

  /// No description provided for @recordTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File larger than allowed ({mb} MB)'**
  String recordTooLarge(int mb);

  /// No description provided for @recordSavedSpace.
  ///
  /// In en, this message translates to:
  /// **'Reduced from {from} to {to}'**
  String recordSavedSpace(String from, String to);

  /// No description provided for @recordWaitForUploads.
  ///
  /// In en, this message translates to:
  /// **'Wait for every file to upload, or remove the ones that failed.'**
  String get recordWaitForUploads;

  /// No description provided for @recordNeedFiles.
  ///
  /// In en, this message translates to:
  /// **'Add at least one file'**
  String get recordNeedFiles;

  /// No description provided for @recordUploadExpired.
  ///
  /// In en, this message translates to:
  /// **'This file is no longer waiting. Upload it again.'**
  String get recordUploadExpired;

  /// No description provided for @recordErrorInvalidSession.
  ///
  /// In en, this message translates to:
  /// **'Choose one of this patient\'s visits'**
  String get recordErrorInvalidSession;

  /// No description provided for @recordErrorInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'The document date can\'t be in the future'**
  String get recordErrorInvalidDate;

  /// No description provided for @recordErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'One file can hold at most 20 attachments'**
  String get recordErrorTooMany;

  /// No description provided for @recordNoFilesYet.
  ///
  /// In en, this message translates to:
  /// **'No files added yet'**
  String get recordNoFilesYet;

  /// No description provided for @recordScanReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Check the pages'**
  String get recordScanReviewTitle;

  /// No description provided for @recordScanAddPages.
  ///
  /// In en, this message translates to:
  /// **'Scan more pages'**
  String get recordScanAddPages;

  /// No description provided for @recordScanPage.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String recordScanPage(int number);

  /// No description provided for @recordScanMoveEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get recordScanMoveEarlier;

  /// No description provided for @recordScanMoveLater.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get recordScanMoveLater;

  /// No description provided for @recordScanDeletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get recordScanDeletePage;

  /// No description provided for @recordScanMakePdf.
  ///
  /// In en, this message translates to:
  /// **'Make one PDF'**
  String get recordScanMakePdf;

  /// No description provided for @recordScanBuilding.
  ///
  /// In en, this message translates to:
  /// **'Making the PDF…'**
  String get recordScanBuilding;

  /// No description provided for @recordScanUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The scanner isn\'t available on this device.'**
  String get recordScanUnavailable;

  /// No description provided for @recordScanDenied.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access in the settings to scan.'**
  String get recordScanDenied;

  /// No description provided for @recordScanFailed.
  ///
  /// In en, this message translates to:
  /// **'The scan didn\'t work. Try again.'**
  String get recordScanFailed;

  /// No description provided for @recordDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get recordDetails;

  /// No description provided for @recordOpenWith.
  ///
  /// In en, this message translates to:
  /// **'Open with…'**
  String get recordOpenWith;

  /// No description provided for @recordDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get recordDownload;

  /// No description provided for @recordShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get recordShare;

  /// No description provided for @recordEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit details'**
  String get recordEdit;

  /// No description provided for @recordDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get recordDelete;

  /// No description provided for @recordDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this file?'**
  String get recordDeleteTitle;

  /// No description provided for @recordDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears from the patient\'s file, for you and for the patient.'**
  String get recordDeleteBody;

  /// No description provided for @recordDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get recordDeleted;

  /// No description provided for @recordDownloaded.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get recordDownloaded;

  /// No description provided for @recordCantOpen.
  ///
  /// In en, this message translates to:
  /// **'No app on this device opens this type of file.'**
  String get recordCantOpen;

  /// No description provided for @recordNoPreview.
  ///
  /// In en, this message translates to:
  /// **'This type of file opens in another app.'**
  String get recordNoPreview;

  /// No description provided for @recordPdfFailed.
  ///
  /// In en, this message translates to:
  /// **'This PDF couldn\'t be shown here. Open it with another app.'**
  String get recordPdfFailed;

  /// No description provided for @recordAttachmentOf.
  ///
  /// In en, this message translates to:
  /// **'{index} of {count}'**
  String recordAttachmentOf(int index, int count);

  /// No description provided for @recordAdded.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String recordAdded(String date);

  /// No description provided for @recordSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get recordSize;

  /// No description provided for @recordSourceScan.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get recordSourceScan;

  /// No description provided for @recordSourceUpload.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get recordSourceUpload;

  /// No description provided for @recordSourceChat.
  ///
  /// In en, this message translates to:
  /// **'From the chat'**
  String get recordSourceChat;

  /// No description provided for @recordVisit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get recordVisit;

  /// No description provided for @recordPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous file'**
  String get recordPrevious;

  /// No description provided for @recordNext.
  ///
  /// In en, this message translates to:
  /// **'Next file'**
  String get recordNext;

  /// No description provided for @recordLoadingFile.
  ///
  /// In en, this message translates to:
  /// **'Opening the file…'**
  String get recordLoadingFile;

  /// No description provided for @activityRecordCreated.
  ///
  /// In en, this message translates to:
  /// **'Added a file to the patient\'s record'**
  String get activityRecordCreated;

  /// No description provided for @activityRecordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Edited a file\'s details'**
  String get activityRecordUpdated;

  /// No description provided for @activityRecordDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted a file'**
  String get activityRecordDeleted;

  /// No description provided for @activityActionRecordCreated.
  ///
  /// In en, this message translates to:
  /// **'File added'**
  String get activityActionRecordCreated;

  /// No description provided for @activityActionRecordUpdated.
  ///
  /// In en, this message translates to:
  /// **'File edited'**
  String get activityActionRecordUpdated;

  /// No description provided for @activityActionRecordDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get activityActionRecordDeleted;

  /// No description provided for @patientTabPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get patientTabPrescriptions;

  /// No description provided for @rxKindMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication prescription'**
  String get rxKindMedication;

  /// No description provided for @rxKindInvestigations.
  ///
  /// In en, this message translates to:
  /// **'Investigations request'**
  String get rxKindInvestigations;

  /// No description provided for @rxKindMedicationHint.
  ///
  /// In en, this message translates to:
  /// **'Medicines with dose, timing and duration'**
  String get rxKindMedicationHint;

  /// No description provided for @rxKindInvestigationsHint.
  ///
  /// In en, this message translates to:
  /// **'Lab tests and radiology'**
  String get rxKindInvestigationsHint;

  /// No description provided for @rxNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New prescription'**
  String get rxNewTitle;

  /// No description provided for @rxNewMedication.
  ///
  /// In en, this message translates to:
  /// **'New prescription'**
  String get rxNewMedication;

  /// No description provided for @rxNewInvestigations.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get rxNewInvestigations;

  /// No description provided for @rxStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get rxStatusDraft;

  /// No description provided for @rxStatusReadyForReview.
  ///
  /// In en, this message translates to:
  /// **'Ready for review'**
  String get rxStatusReadyForReview;

  /// No description provided for @rxStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get rxStatusSent;

  /// No description provided for @rxStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get rxStatusCancelled;

  /// No description provided for @rxNoItems.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get rxNoItems;

  /// Items on a prescription.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String rxItemCount(int count);

  /// BR-AS10: the doctor sees who prepared a draft.
  ///
  /// In en, this message translates to:
  /// **'Prepared by {name}'**
  String rxPreparedBy(String name);

  /// No description provided for @rxListSeparator.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get rxListSeparator;

  /// No description provided for @rxSessionCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions and requests'**
  String get rxSessionCardTitle;

  /// No description provided for @rxSessionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No prescription for this visit yet.'**
  String get rxSessionEmpty;

  /// No description provided for @rxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions yet'**
  String get rxEmptyTitle;

  /// No description provided for @rxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Write a medication prescription or a lab and radiology request from one of today’s visits.'**
  String get rxEmptyBody;

  /// No description provided for @rxPickSession.
  ///
  /// In en, this message translates to:
  /// **'Which visit is this for?'**
  String get rxPickSession;

  /// No description provided for @rxNoSessionTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'No visit today'**
  String get rxNoSessionTodayTitle;

  /// No description provided for @rxNoSessionTodayBody.
  ///
  /// In en, this message translates to:
  /// **'A prescription belongs to a visit. Record today’s visit first, then write the prescription from it.'**
  String get rxNoSessionTodayBody;

  /// No description provided for @rxDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get rxDiagnosis;

  /// No description provided for @rxMedicines.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get rxMedicines;

  /// No description provided for @rxTests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get rxTests;

  /// No description provided for @rxNoMedicinesYet.
  ///
  /// In en, this message translates to:
  /// **'Add the first medicine.'**
  String get rxNoMedicinesYet;

  /// No description provided for @rxNoTestsYet.
  ///
  /// In en, this message translates to:
  /// **'Add the first test.'**
  String get rxNoTestsYet;

  /// No description provided for @rxAddMedicine.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get rxAddMedicine;

  /// No description provided for @rxEditMedicine.
  ///
  /// In en, this message translates to:
  /// **'Edit medicine'**
  String get rxEditMedicine;

  /// No description provided for @rxAddTest.
  ///
  /// In en, this message translates to:
  /// **'Add test'**
  String get rxAddTest;

  /// No description provided for @rxEditTest.
  ///
  /// In en, this message translates to:
  /// **'Edit test'**
  String get rxEditTest;

  /// No description provided for @rxAddToPrescription.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get rxAddToPrescription;

  /// No description provided for @rxAdvice.
  ///
  /// In en, this message translates to:
  /// **'General advice'**
  String get rxAdvice;

  /// No description provided for @rxRequestNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get rxRequestNotes;

  /// No description provided for @rxFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up date'**
  String get rxFollowUp;

  /// No description provided for @rxResultsOn.
  ///
  /// In en, this message translates to:
  /// **'Bring the results on'**
  String get rxResultsOn;

  /// No description provided for @rxClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear the date'**
  String get rxClearDate;

  /// No description provided for @rxSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get rxSaveDraft;

  /// No description provided for @rxDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get rxDraftSaved;

  /// No description provided for @rxPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get rxPreview;

  /// No description provided for @rxSubmitForReview.
  ///
  /// In en, this message translates to:
  /// **'Send to the doctor for review'**
  String get rxSubmitForReview;

  /// No description provided for @rxSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Sent to the doctor for review.'**
  String get rxSubmittedForReview;

  /// No description provided for @rxMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get rxMore;

  /// No description provided for @rxSaveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get rxSaveAsTemplate;

  /// No description provided for @rxDeleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get rxDeleteDraft;

  /// No description provided for @rxDeleteDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this draft?'**
  String get rxDeleteDraftTitle;

  /// No description provided for @rxDeleteDraftBody.
  ///
  /// In en, this message translates to:
  /// **'The patient never saw it. This can’t be undone.'**
  String get rxDeleteDraftBody;

  /// No description provided for @rxDraftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted.'**
  String get rxDraftDeleted;

  /// No description provided for @rxItemRemoved.
  ///
  /// In en, this message translates to:
  /// **'Item removed.'**
  String get rxItemRemoved;

  /// No description provided for @rxUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get rxUndo;

  /// No description provided for @rxRemoveItem.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get rxRemoveItem;

  /// No description provided for @rxDragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get rxDragToReorder;

  /// No description provided for @rxFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'From template'**
  String get rxFromTemplate;

  /// No description provided for @rxNoTemplates.
  ///
  /// In en, this message translates to:
  /// **'No templates yet'**
  String get rxNoTemplates;

  /// No description provided for @rxNoTemplatesBody.
  ///
  /// In en, this message translates to:
  /// **'Save a prescription as a template from its “More” menu to reuse it.'**
  String get rxNoTemplatesBody;

  /// No description provided for @rxTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get rxTemplateName;

  /// No description provided for @rxTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved.'**
  String get rxTemplateSaved;

  /// No description provided for @rxErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item.'**
  String get rxErrorEmpty;

  /// No description provided for @rxErrorNotEditable.
  ///
  /// In en, this message translates to:
  /// **'This prescription was already sent or cancelled, so it can’t be changed.'**
  String get rxErrorNotEditable;

  /// No description provided for @rxErrorNotSent.
  ///
  /// In en, this message translates to:
  /// **'Only a sent prescription can be cancelled.'**
  String get rxErrorNotSent;

  /// No description provided for @rxErrorInvalidCopySource.
  ///
  /// In en, this message translates to:
  /// **'A new copy can only be made from a sent or cancelled prescription of the same patient.'**
  String get rxErrorInvalidCopySource;

  /// No description provided for @rxErrorInvalidSession.
  ///
  /// In en, this message translates to:
  /// **'Pick one of this patient’s visits.'**
  String get rxErrorInvalidSession;

  /// No description provided for @rxErrorInvalidDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a valid date.'**
  String get rxErrorInvalidDate;

  /// No description provided for @rxErrorTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many items.'**
  String get rxErrorTooMany;

  /// No description provided for @rxSearchMedicine.
  ///
  /// In en, this message translates to:
  /// **'Search medicines (trade name or active ingredient)'**
  String get rxSearchMedicine;

  /// No description provided for @rxSearchLab.
  ///
  /// In en, this message translates to:
  /// **'Search lab tests'**
  String get rxSearchLab;

  /// No description provided for @rxSearchRadiology.
  ///
  /// In en, this message translates to:
  /// **'Search radiology'**
  String get rxSearchRadiology;

  /// No description provided for @rxMySpecialtyOnly.
  ///
  /// In en, this message translates to:
  /// **'My specialty only'**
  String get rxMySpecialtyOnly;

  /// No description provided for @rxSectionUsedBefore.
  ///
  /// In en, this message translates to:
  /// **'Used before'**
  String get rxSectionUsedBefore;

  /// No description provided for @rxSectionMySpecialty.
  ///
  /// In en, this message translates to:
  /// **'Your specialty'**
  String get rxSectionMySpecialty;

  /// No description provided for @rxSectionOthers.
  ///
  /// In en, this message translates to:
  /// **'From other specialties'**
  String get rxSectionOthers;

  /// No description provided for @rxCatalogNotReady.
  ///
  /// In en, this message translates to:
  /// **'The catalog is still downloading: only your own history is searched. You can type any name.'**
  String get rxCatalogNotReady;

  /// BR-CAT8: a name that isn’t in the catalog.
  ///
  /// In en, this message translates to:
  /// **'Use “{text}”'**
  String rxUseTyped(String text);

  /// No description provided for @rxNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches in the catalog.'**
  String get rxNoMatches;

  /// No description provided for @rxDrugName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get rxDrugName;

  /// No description provided for @rxActiveIngredient.
  ///
  /// In en, this message translates to:
  /// **'Active ingredient'**
  String get rxActiveIngredient;

  /// No description provided for @rxStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get rxStrength;

  /// No description provided for @rxForm.
  ///
  /// In en, this message translates to:
  /// **'Form'**
  String get rxForm;

  /// No description provided for @rxFormOtherText.
  ///
  /// In en, this message translates to:
  /// **'Form (type it)'**
  String get rxFormOtherText;

  /// No description provided for @rxDose.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get rxDose;

  /// No description provided for @rxDoseHint.
  ///
  /// In en, this message translates to:
  /// **'1 tablet'**
  String get rxDoseHint;

  /// No description provided for @rxFrequency.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get rxFrequency;

  /// No description provided for @rxFrequencyHint.
  ///
  /// In en, this message translates to:
  /// **'Every 8 hours'**
  String get rxFrequencyHint;

  /// No description provided for @rxTiming.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get rxTiming;

  /// No description provided for @rxTimingBeforeFood.
  ///
  /// In en, this message translates to:
  /// **'Before food'**
  String get rxTimingBeforeFood;

  /// No description provided for @rxTimingAfterFood.
  ///
  /// In en, this message translates to:
  /// **'After food'**
  String get rxTimingAfterFood;

  /// No description provided for @rxTimingWithFood.
  ///
  /// In en, this message translates to:
  /// **'With food'**
  String get rxTimingWithFood;

  /// No description provided for @rxTimingUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get rxTimingUnspecified;

  /// No description provided for @rxDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get rxDuration;

  /// No description provided for @rxDurationCount.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get rxDurationCount;

  /// No description provided for @rxDurationUnitDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get rxDurationUnitDays;

  /// No description provided for @rxDurationUnitWeeks.
  ///
  /// In en, this message translates to:
  /// **'Weeks'**
  String get rxDurationUnitWeeks;

  /// No description provided for @rxDurationContinuous.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get rxDurationContinuous;

  /// A medicine’s duration in days.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String rxDurationDays(int count);

  /// A medicine’s duration in weeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String rxDurationWeeks(int count);

  /// No description provided for @rxInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get rxInstructions;

  /// No description provided for @rxFormTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get rxFormTablet;

  /// No description provided for @rxFormCapsule.
  ///
  /// In en, this message translates to:
  /// **'Capsule'**
  String get rxFormCapsule;

  /// No description provided for @rxFormSyrup.
  ///
  /// In en, this message translates to:
  /// **'Syrup'**
  String get rxFormSyrup;

  /// No description provided for @rxFormInjection.
  ///
  /// In en, this message translates to:
  /// **'Injection'**
  String get rxFormInjection;

  /// No description provided for @rxFormCream.
  ///
  /// In en, this message translates to:
  /// **'Cream / ointment'**
  String get rxFormCream;

  /// No description provided for @rxFormDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get rxFormDrops;

  /// No description provided for @rxFormInhaler.
  ///
  /// In en, this message translates to:
  /// **'Inhaler'**
  String get rxFormInhaler;

  /// No description provided for @rxFormSuppository.
  ///
  /// In en, this message translates to:
  /// **'Suppository'**
  String get rxFormSuppository;

  /// No description provided for @rxFormSachet.
  ///
  /// In en, this message translates to:
  /// **'Sachet'**
  String get rxFormSachet;

  /// No description provided for @rxFormOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get rxFormOther;

  /// No description provided for @rxCategoryLab.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get rxCategoryLab;

  /// No description provided for @rxCategoryRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get rxCategoryRadiology;

  /// No description provided for @rxTestName.
  ///
  /// In en, this message translates to:
  /// **'Test name'**
  String get rxTestName;

  /// No description provided for @rxTestNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get rxTestNotes;

  /// No description provided for @rxTestNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Fasting 12 hours'**
  String get rxTestNotesHint;

  /// No description provided for @rxEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get rxEdit;

  /// No description provided for @rxSend.
  ///
  /// In en, this message translates to:
  /// **'Send to patient'**
  String get rxSend;

  /// No description provided for @rxSendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to the patient?'**
  String get rxSendTitle;

  /// No description provided for @rxSendBody.
  ///
  /// In en, this message translates to:
  /// **'The patient gets it in the app at once. A sent prescription can’t be changed: to correct it, cancel it and issue a new copy.'**
  String get rxSendBody;

  /// No description provided for @rxSendAndPrint.
  ///
  /// In en, this message translates to:
  /// **'Send and print'**
  String get rxSendAndPrint;

  /// No description provided for @rxSendAndPrintTitle.
  ///
  /// In en, this message translates to:
  /// **'Send and print?'**
  String get rxSendAndPrintTitle;

  /// No description provided for @rxSendAndPrintBody.
  ///
  /// In en, this message translates to:
  /// **'Printing sends it to the patient at the same moment, so the paper and the app always match.'**
  String get rxSendAndPrintBody;

  /// No description provided for @rxSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to the patient.'**
  String get rxSent;

  /// No description provided for @rxPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get rxPrint;

  /// No description provided for @rxPrintAll.
  ///
  /// In en, this message translates to:
  /// **'Print all'**
  String get rxPrintAll;

  /// No description provided for @rxShare.
  ///
  /// In en, this message translates to:
  /// **'Share PDF'**
  String get rxShare;

  /// No description provided for @rxPrintFailed.
  ///
  /// In en, this message translates to:
  /// **'Printing didn’t work. Try again.'**
  String get rxPrintFailed;

  /// No description provided for @rxCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel prescription'**
  String get rxCancelAction;

  /// No description provided for @rxCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this prescription?'**
  String get rxCancelTitle;

  /// No description provided for @rxCancelBody.
  ///
  /// In en, this message translates to:
  /// **'The patient sees it struck through, with your reason. You can then issue a new copy.'**
  String get rxCancelBody;

  /// No description provided for @rxCancelReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get rxCancelReason;

  /// No description provided for @rxCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel prescription'**
  String get rxCancelConfirm;

  /// No description provided for @rxCancelled.
  ///
  /// In en, this message translates to:
  /// **'Prescription cancelled.'**
  String get rxCancelled;

  /// No description provided for @rxCancelledNotice.
  ///
  /// In en, this message translates to:
  /// **'Cancelled. It can’t be printed.'**
  String get rxCancelledNotice;

  /// D15 banner on a cancelled document.
  ///
  /// In en, this message translates to:
  /// **'Cancelled: {reason}'**
  String rxCancelledReason(String reason);

  /// No description provided for @rxNewCopy.
  ///
  /// In en, this message translates to:
  /// **'Issue new copy'**
  String get rxNewCopy;

  /// No description provided for @rxPreviewFailed.
  ///
  /// In en, this message translates to:
  /// **'The preview couldn’t be built.'**
  String get rxPreviewFailed;

  /// No description provided for @rxSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescription header and printing'**
  String get rxSettingsTitle;

  /// No description provided for @rxSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How your prescriptions look on paper and in the patient’s app.'**
  String get rxSettingsSubtitle;

  /// No description provided for @rxSettingsTileHint.
  ///
  /// In en, this message translates to:
  /// **'Logo, signature, colour, language and paper'**
  String get rxSettingsTileHint;

  /// No description provided for @rxSettingsHeaderGroup.
  ///
  /// In en, this message translates to:
  /// **'Header'**
  String get rxSettingsHeaderGroup;

  /// No description provided for @rxSettingsNamesHint.
  ///
  /// In en, this message translates to:
  /// **'Your names, titles and degrees come from your profile; the branches in the footer come from Branches.'**
  String get rxSettingsNamesHint;

  /// No description provided for @rxLogo.
  ///
  /// In en, this message translates to:
  /// **'Clinic logo'**
  String get rxLogo;

  /// No description provided for @rxSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get rxSignature;

  /// No description provided for @rxUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get rxUploadImage;

  /// No description provided for @rxReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get rxReplaceImage;

  /// No description provided for @rxRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get rxRemoveImage;

  /// No description provided for @rxImagesGroup.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get rxImagesGroup;

  /// No description provided for @rxSettingsColor.
  ///
  /// In en, this message translates to:
  /// **'Clinic colour'**
  String get rxSettingsColor;

  /// No description provided for @rxSettingsHex.
  ///
  /// In en, this message translates to:
  /// **'Colour code'**
  String get rxSettingsHex;

  /// No description provided for @rxSettingsFooter.
  ///
  /// In en, this message translates to:
  /// **'Footer text'**
  String get rxSettingsFooter;

  /// No description provided for @rxSettingsFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, for example your working days.'**
  String get rxSettingsFooterHint;

  /// No description provided for @rxSettingsPrintGroup.
  ///
  /// In en, this message translates to:
  /// **'Language and paper'**
  String get rxSettingsPrintGroup;

  /// No description provided for @rxSettingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Prescription language'**
  String get rxSettingsLanguage;

  /// No description provided for @rxSettingsArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get rxSettingsArabic;

  /// No description provided for @rxSettingsEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get rxSettingsEnglish;

  /// No description provided for @rxSettingsPaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get rxSettingsPaper;

  /// No description provided for @rxPaperA5.
  ///
  /// In en, this message translates to:
  /// **'A5'**
  String get rxPaperA5;

  /// No description provided for @rxPaperA4.
  ///
  /// In en, this message translates to:
  /// **'A4'**
  String get rxPaperA4;

  /// No description provided for @rxPaperCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get rxPaperCustom;

  /// No description provided for @rxPaperWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get rxPaperWidth;

  /// No description provided for @rxPaperHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get rxPaperHeight;

  /// No description provided for @rxMm.
  ///
  /// In en, this message translates to:
  /// **'mm'**
  String get rxMm;

  /// No description provided for @rxPreprinted.
  ///
  /// In en, this message translates to:
  /// **'Pre-printed paper'**
  String get rxPreprinted;

  /// No description provided for @rxPreprintedHint.
  ///
  /// In en, this message translates to:
  /// **'For your own letterhead: the header and footer aren’t printed, and the text starts at the top margin.'**
  String get rxPreprintedHint;

  /// No description provided for @rxMarginTop.
  ///
  /// In en, this message translates to:
  /// **'Top margin'**
  String get rxMarginTop;

  /// No description provided for @rxMarginBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom margin'**
  String get rxMarginBottom;

  /// No description provided for @rxSettingsPreview.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get rxSettingsPreview;

  /// No description provided for @rxTestPrint.
  ///
  /// In en, this message translates to:
  /// **'Test print'**
  String get rxTestPrint;

  /// No description provided for @rxSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Print settings saved.'**
  String get rxSettingsSaved;

  /// No description provided for @rxSamplePatient.
  ///
  /// In en, this message translates to:
  /// **'Sample patient'**
  String get rxSamplePatient;

  /// No description provided for @rxSampleDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Acute tonsillitis'**
  String get rxSampleDiagnosis;

  /// No description provided for @rxSampleAdvice.
  ///
  /// In en, this message translates to:
  /// **'Rest and warm fluids.'**
  String get rxSampleAdvice;

  /// No description provided for @rxSampleDose.
  ///
  /// In en, this message translates to:
  /// **'1 tablet'**
  String get rxSampleDose;

  /// No description provided for @rxSampleFrequency.
  ///
  /// In en, this message translates to:
  /// **'Every 12 hours'**
  String get rxSampleFrequency;

  /// No description provided for @rxSampleWhenNeeded.
  ///
  /// In en, this message translates to:
  /// **'When needed'**
  String get rxSampleWhenNeeded;

  /// No description provided for @rxTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Templates and favourites'**
  String get rxTemplatesTitle;

  /// No description provided for @rxTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reuse prescriptions you write often.'**
  String get rxTemplatesSubtitle;

  /// No description provided for @rxTemplatesTileHint.
  ///
  /// In en, this message translates to:
  /// **'Saved prescriptions and frequently used items'**
  String get rxTemplatesTileHint;

  /// No description provided for @rxTemplatesGroup.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get rxTemplatesGroup;

  /// No description provided for @rxRenameTemplate.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rxRenameTemplate;

  /// No description provided for @rxDeleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get rxDeleteTemplate;

  /// No description provided for @rxDeleteTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this template?'**
  String get rxDeleteTemplateTitle;

  /// D23.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be removed. Prescriptions made from it stay as they are.'**
  String rxDeleteTemplateBody(String name);

  /// No description provided for @rxTemplateDeleted.
  ///
  /// In en, this message translates to:
  /// **'Template deleted.'**
  String get rxTemplateDeleted;

  /// No description provided for @rxFrequentGroup.
  ///
  /// In en, this message translates to:
  /// **'Frequently used'**
  String get rxFrequentGroup;

  /// No description provided for @rxFrequentHint.
  ///
  /// In en, this message translates to:
  /// **'They come first when you search. Remove one to stop suggesting it.'**
  String get rxFrequentHint;

  /// No description provided for @rxNoHistory.
  ///
  /// In en, this message translates to:
  /// **'Items you prescribe will appear here.'**
  String get rxNoHistory;

  /// D23.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Used once} other{Used {count} times}}'**
  String rxUsedTimes(int count);

  /// No description provided for @rxRemoveFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from suggestions'**
  String get rxRemoveFromHistory;

  /// D23.
  ///
  /// In en, this message translates to:
  /// **'“{name}” removed from suggestions.'**
  String rxHistoryItemRemoved(String name);

  /// PDF document title.
  ///
  /// In en, this message translates to:
  /// **'el3yada {kind}'**
  String rxPdfTitle(String kind);

  /// No description provided for @rxPdfDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis:'**
  String get rxPdfDiagnosis;

  /// No description provided for @rxPdfInstructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions:'**
  String get rxPdfInstructions;

  /// No description provided for @rxPdfNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes:'**
  String get rxPdfNotes;

  /// 6.4.1 zone 6.
  ///
  /// In en, this message translates to:
  /// **'Follow-up: {date}'**
  String rxPdfFollowUp(String date);

  /// 6.4.1 zone 6.
  ///
  /// In en, this message translates to:
  /// **'Bring the results on: {date}'**
  String rxPdfResultsOn(String date);

  /// No description provided for @rxPdfTestsIntro.
  ///
  /// In en, this message translates to:
  /// **'Please do the following tests:'**
  String get rxPdfTestsIntro;

  /// No description provided for @rxPdfLabGroup.
  ///
  /// In en, this message translates to:
  /// **'Lab tests'**
  String get rxPdfLabGroup;

  /// No description provided for @rxPdfRadiologyGroup.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get rxPdfRadiologyGroup;

  /// No description provided for @rxPdfPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rxPdfPatient;

  /// No description provided for @rxPdfDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get rxPdfDate;

  /// No description provided for @rxPdfAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get rxPdfAge;

  /// Patient strip.
  ///
  /// In en, this message translates to:
  /// **'{years} y'**
  String rxPdfAgeValue(int years);

  /// No description provided for @rxPdfFile.
  ///
  /// In en, this message translates to:
  /// **'File no.'**
  String get rxPdfFile;

  /// No description provided for @rxPdfVisit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get rxPdfVisit;

  /// No description provided for @rxPdfExamination.
  ///
  /// In en, this message translates to:
  /// **'Examination'**
  String get rxPdfExamination;

  /// No description provided for @rxPdfConsultation.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get rxPdfConsultation;

  /// No description provided for @rxPdfSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get rxPdfSignature;

  /// No description provided for @rxPdfScan.
  ///
  /// In en, this message translates to:
  /// **'Scan the code'**
  String get rxPdfScan;

  /// Page 2 of a long prescription.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String rxPdfPage(int page, int total);

  /// No description provided for @rxPdfTel.
  ///
  /// In en, this message translates to:
  /// **'Tel'**
  String get rxPdfTel;

  /// No description provided for @rxPdfWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get rxPdfWhatsapp;

  /// D27.
  ///
  /// In en, this message translates to:
  /// **'started a draft: {kind}'**
  String activityPrescriptionDraftCreated(String kind);

  /// D27.
  ///
  /// In en, this message translates to:
  /// **'issued a new copy: {kind}'**
  String activityPrescriptionCopied(String kind);

  /// D27.
  ///
  /// In en, this message translates to:
  /// **'edited a draft: {kind}'**
  String activityPrescriptionDraftUpdated(String kind);

  /// D27.
  ///
  /// In en, this message translates to:
  /// **'deleted a draft: {kind}'**
  String activityPrescriptionDraftDeleted(String kind);

  /// D27.
  ///
  /// In en, this message translates to:
  /// **'sent a draft for review: {kind}'**
  String activityPrescriptionSubmitted(String kind);

  /// D27.
  ///
  /// In en, this message translates to:
  /// **'sent to the patient: {kind}'**
  String activityPrescriptionSent(String kind);

  /// D27.
  ///
  /// In en, this message translates to:
  /// **'cancelled: {kind}'**
  String activityPrescriptionCancelled(String kind);

  /// D27 detail line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String activityRxItems(int count);

  /// No description provided for @activityRxSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'changed the print settings'**
  String get activityRxSettingsUpdated;

  /// No description provided for @activityRxLogoUpdated.
  ///
  /// In en, this message translates to:
  /// **'changed the prescription logo'**
  String get activityRxLogoUpdated;

  /// No description provided for @activityRxLogoRemoved.
  ///
  /// In en, this message translates to:
  /// **'removed the prescription logo'**
  String get activityRxLogoRemoved;

  /// No description provided for @activityRxSignatureUpdated.
  ///
  /// In en, this message translates to:
  /// **'changed the signature'**
  String get activityRxSignatureUpdated;

  /// No description provided for @activityRxSignatureRemoved.
  ///
  /// In en, this message translates to:
  /// **'removed the signature'**
  String get activityRxSignatureRemoved;

  /// No description provided for @activityActionPrescriptionDraftCreated.
  ///
  /// In en, this message translates to:
  /// **'Draft started'**
  String get activityActionPrescriptionDraftCreated;

  /// No description provided for @activityActionPrescriptionDraftUpdated.
  ///
  /// In en, this message translates to:
  /// **'Draft edited'**
  String get activityActionPrescriptionDraftUpdated;

  /// No description provided for @activityActionPrescriptionDraftDeleted.
  ///
  /// In en, this message translates to:
  /// **'Draft deleted'**
  String get activityActionPrescriptionDraftDeleted;

  /// No description provided for @activityActionPrescriptionSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Sent for review'**
  String get activityActionPrescriptionSubmitted;

  /// No description provided for @activityActionPrescriptionSent.
  ///
  /// In en, this message translates to:
  /// **'Prescription sent'**
  String get activityActionPrescriptionSent;

  /// No description provided for @activityActionPrescriptionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Prescription cancelled'**
  String get activityActionPrescriptionCancelled;

  /// No description provided for @activityActionRxSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Print settings'**
  String get activityActionRxSettingsUpdated;

  /// No description provided for @activityActionRxBrandingUpdated.
  ///
  /// In en, this message translates to:
  /// **'Logo or signature'**
  String get activityActionRxBrandingUpdated;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item is not available.'**
  String get errorNotFound;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this.'**
  String get errorForbidden;

  /// No description provided for @errorDeletionAlreadyRequested.
  ///
  /// In en, this message translates to:
  /// **'You already have a deletion request under review.'**
  String get errorDeletionAlreadyRequested;

  /// No description provided for @couldNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open it on this device'**
  String get couldNotOpen;

  /// No description provided for @newBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newBadge;

  /// No description provided for @allDoctors.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allDoctors;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeNewItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new item in your file} other{{count} new items in your file}}'**
  String homeNewItems(int count);

  /// No description provided for @homeLatestVisit.
  ///
  /// In en, this message translates to:
  /// **'Latest visit'**
  String get homeLatestVisit;

  /// No description provided for @homeLatestPrescription.
  ///
  /// In en, this message translates to:
  /// **'Latest prescription'**
  String get homeLatestPrescription;

  /// No description provided for @homeNextFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Next follow-up'**
  String get homeNextFollowUp;

  /// No description provided for @followUpWith.
  ///
  /// In en, this message translates to:
  /// **'{date} with {doctor}'**
  String followUpWith(String date, String doctor);

  /// No description provided for @homeRecentFiles.
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get homeRecentFiles;

  /// No description provided for @homeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your medical file is empty for now. Visits, prescriptions and files your doctor adds will appear here.'**
  String get homeEmpty;

  /// No description provided for @myDoctorsTitle.
  ///
  /// In en, this message translates to:
  /// **'My doctors'**
  String get myDoctorsTitle;

  /// No description provided for @myDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'My doctor'**
  String get myDoctorTitle;

  /// No description provided for @noDoctors.
  ///
  /// In en, this message translates to:
  /// **'You are not linked to a doctor yet.'**
  String get noDoctors;

  /// No description provided for @medicalProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Medical profile'**
  String get medicalProfileTitle;

  /// No description provided for @fileNumber.
  ///
  /// In en, this message translates to:
  /// **'File no. {number}'**
  String fileNumber(int number);

  /// No description provided for @thisDoctorsRecords.
  ///
  /// In en, this message translates to:
  /// **'This doctor\'s records'**
  String get thisDoctorsRecords;

  /// No description provided for @branchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get branchesTitle;

  /// No description provided for @noBranches.
  ///
  /// In en, this message translates to:
  /// **'No branch details yet. Contact the clinic.'**
  String get noBranches;

  /// No description provided for @mainBranch.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get mainBranch;

  /// No description provided for @branchTemporarilyClosed.
  ///
  /// In en, this message translates to:
  /// **'Temporarily closed'**
  String get branchTemporarilyClosed;

  /// No description provided for @reopensOn.
  ///
  /// In en, this message translates to:
  /// **'Reopens on {date}'**
  String reopensOn(String date);

  /// No description provided for @openInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get openInMaps;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @whatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsApp;

  /// No description provided for @phoneReception.
  ///
  /// In en, this message translates to:
  /// **'Reception'**
  String get phoneReception;

  /// No description provided for @phoneMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get phoneMobile;

  /// No description provided for @phoneLandline.
  ///
  /// In en, this message translates to:
  /// **'Landline'**
  String get phoneLandline;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @workingHoursNotSet.
  ///
  /// In en, this message translates to:
  /// **'Ask the clinic for its hours.'**
  String get workingHoursNotSet;

  /// No description provided for @closedDay.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closedDay;

  /// No description provided for @timeRange.
  ///
  /// In en, this message translates to:
  /// **'{start} – {end}'**
  String timeRange(String start, String end);

  /// No description provided for @visitPrices.
  ///
  /// In en, this message translates to:
  /// **'Visit prices'**
  String get visitPrices;

  /// No description provided for @priceAskClinic.
  ///
  /// In en, this message translates to:
  /// **'Ask the clinic'**
  String get priceAskClinic;

  /// No description provided for @moneyEgp.
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String moneyEgp(String amount);

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentCard;

  /// No description provided for @paymentInstapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get paymentInstapay;

  /// No description provided for @paymentWallet.
  ///
  /// In en, this message translates to:
  /// **'Mobile wallet'**
  String get paymentWallet;

  /// No description provided for @amenityElevator.
  ///
  /// In en, this message translates to:
  /// **'Elevator'**
  String get amenityElevator;

  /// No description provided for @amenityParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get amenityParking;

  /// No description provided for @amenityWheelchair.
  ///
  /// In en, this message translates to:
  /// **'Wheelchair access'**
  String get amenityWheelchair;

  /// No description provided for @amenityKidsArea.
  ///
  /// In en, this message translates to:
  /// **'Kids\' area'**
  String get amenityKidsArea;

  /// No description provided for @tabVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get tabVisits;

  /// No description provided for @tabPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get tabPrescriptions;

  /// No description provided for @tabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get tabFiles;

  /// No description provided for @noVisits.
  ///
  /// In en, this message translates to:
  /// **'No visits yet.'**
  String get noVisits;

  /// No description provided for @noPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions yet.'**
  String get noPrescriptions;

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files in this category.'**
  String get noFiles;

  /// No description provided for @visitTypeExamination.
  ///
  /// In en, this message translates to:
  /// **'Examination'**
  String get visitTypeExamination;

  /// No description provided for @visitTypeConsultation.
  ///
  /// In en, this message translates to:
  /// **'Consultation'**
  String get visitTypeConsultation;

  /// No description provided for @visitDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit details'**
  String get visitDetailsTitle;

  /// No description provided for @diagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosis;

  /// No description provided for @chiefComplaint.
  ///
  /// In en, this message translates to:
  /// **'Chief complaint'**
  String get chiefComplaint;

  /// No description provided for @findings.
  ///
  /// In en, this message translates to:
  /// **'Examination findings'**
  String get findings;

  /// No description provided for @vitals.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get vitals;

  /// No description provided for @vitalBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get vitalBloodPressure;

  /// No description provided for @vitalPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get vitalPulse;

  /// No description provided for @vitalTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get vitalTemperature;

  /// No description provided for @vitalWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get vitalWeight;

  /// No description provided for @vitalHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get vitalHeight;

  /// No description provided for @vitalGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood sugar'**
  String get vitalGlucose;

  /// No description provided for @doctorNotesForYou.
  ///
  /// In en, this message translates to:
  /// **'Your doctor\'s notes'**
  String get doctorNotesForYou;

  /// No description provided for @followUpDate.
  ///
  /// In en, this message translates to:
  /// **'Follow-up date'**
  String get followUpDate;

  /// No description provided for @rxTabMedications.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get rxTabMedications;

  /// No description provided for @rxTabInvestigations.
  ///
  /// In en, this message translates to:
  /// **'Lab & Radiology'**
  String get rxTabInvestigations;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemCount(int count);

  /// No description provided for @rxCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'This prescription was cancelled'**
  String get rxCancelledTitle;

  /// No description provided for @reasonValue.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String reasonValue(String reason);

  /// No description provided for @rxOpenNewCopy.
  ///
  /// In en, this message translates to:
  /// **'Open the new copy'**
  String get rxOpenNewCopy;

  /// No description provided for @rxSentOn.
  ///
  /// In en, this message translates to:
  /// **'Sent on {date}'**
  String rxSentOn(String date);

  /// No description provided for @viewPdf.
  ///
  /// In en, this message translates to:
  /// **'View PDF'**
  String get viewPdf;

  /// No description provided for @shareOrSave.
  ///
  /// In en, this message translates to:
  /// **'Share or save'**
  String get shareOrSave;

  /// A dose and the medicine form, for example "1 tablet".
  ///
  /// In en, this message translates to:
  /// **'{dose} {form}'**
  String doseAmountForm(String dose, String form);

  /// No description provided for @formTablet.
  ///
  /// In en, this message translates to:
  /// **'tablet'**
  String get formTablet;

  /// No description provided for @formCapsule.
  ///
  /// In en, this message translates to:
  /// **'capsule'**
  String get formCapsule;

  /// No description provided for @formSyrup.
  ///
  /// In en, this message translates to:
  /// **'syrup'**
  String get formSyrup;

  /// No description provided for @formInjection.
  ///
  /// In en, this message translates to:
  /// **'injection'**
  String get formInjection;

  /// No description provided for @formCream.
  ///
  /// In en, this message translates to:
  /// **'cream / ointment'**
  String get formCream;

  /// No description provided for @formDrops.
  ///
  /// In en, this message translates to:
  /// **'drops'**
  String get formDrops;

  /// No description provided for @formInhaler.
  ///
  /// In en, this message translates to:
  /// **'inhaler'**
  String get formInhaler;

  /// No description provided for @formSuppository.
  ///
  /// In en, this message translates to:
  /// **'suppository'**
  String get formSuppository;

  /// No description provided for @formSachet.
  ///
  /// In en, this message translates to:
  /// **'sachet'**
  String get formSachet;

  /// No description provided for @formOther.
  ///
  /// In en, this message translates to:
  /// **'other'**
  String get formOther;

  /// No description provided for @timingBeforeFood.
  ///
  /// In en, this message translates to:
  /// **'Before food'**
  String get timingBeforeFood;

  /// No description provided for @timingAfterFood.
  ///
  /// In en, this message translates to:
  /// **'After food'**
  String get timingAfterFood;

  /// No description provided for @timingWithFood.
  ///
  /// In en, this message translates to:
  /// **'With food'**
  String get timingWithFood;

  /// No description provided for @durationDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{for 1 day} other{for {count} days}}'**
  String durationDays(int count);

  /// No description provided for @durationWeeks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{for 1 week} other{for {count} weeks}}'**
  String durationWeeks(int count);

  /// No description provided for @durationContinuous.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get durationContinuous;

  /// No description provided for @investigationLab.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get investigationLab;

  /// No description provided for @investigationRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get investigationRadiology;

  /// No description provided for @fileCategoryPrescription.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get fileCategoryPrescription;

  /// No description provided for @fileCategoryLab.
  ///
  /// In en, this message translates to:
  /// **'Lab tests'**
  String get fileCategoryLab;

  /// No description provided for @fileCategoryRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get fileCategoryRadiology;

  /// No description provided for @fileCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get fileCategoryOther;

  /// No description provided for @otherTypeReport.
  ///
  /// In en, this message translates to:
  /// **'Medical report'**
  String get otherTypeReport;

  /// No description provided for @otherTypeReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get otherTypeReferral;

  /// No description provided for @otherTypeSickLeave.
  ///
  /// In en, this message translates to:
  /// **'Sick leave'**
  String get otherTypeSickLeave;

  /// No description provided for @otherTypeEcg.
  ///
  /// In en, this message translates to:
  /// **'ECG'**
  String get otherTypeEcg;

  /// No description provided for @otherTypeEegEmg.
  ///
  /// In en, this message translates to:
  /// **'EEG / EMG'**
  String get otherTypeEegEmg;

  /// No description provided for @otherTypeEndoscopy.
  ///
  /// In en, this message translates to:
  /// **'Endoscopy'**
  String get otherTypeEndoscopy;

  /// No description provided for @otherTypeConsent.
  ///
  /// In en, this message translates to:
  /// **'Consent form'**
  String get otherTypeConsent;

  /// No description provided for @fileDetails.
  ///
  /// In en, this message translates to:
  /// **'File details'**
  String get fileDetails;

  /// No description provided for @fileTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get fileTitle;

  /// No description provided for @fileCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get fileCategory;

  /// No description provided for @documentDate.
  ///
  /// In en, this message translates to:
  /// **'Document date'**
  String get documentDate;

  /// No description provided for @doctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctor;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @noAttachments.
  ///
  /// In en, this message translates to:
  /// **'This file has no attachments.'**
  String get noAttachments;

  /// No description provided for @cannotPreview.
  ///
  /// In en, this message translates to:
  /// **'{fileName} can\'t be previewed here. Use Share to open it with another app.'**
  String cannotPreview(String fileName);

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String pageOf(int current, int total);

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get personalInfo;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @ageYears.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =0{Under 1 year} =1{1 year} other{{years} years}}'**
  String ageYears(int years);

  /// No description provided for @bloodType.
  ///
  /// In en, this message translates to:
  /// **'Blood type'**
  String get bloodType;

  /// No description provided for @allergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergies;

  /// No description provided for @chronicDiseases.
  ///
  /// In en, this message translates to:
  /// **'Chronic diseases'**
  String get chronicDiseases;

  /// No description provided for @currentMedications.
  ///
  /// In en, this message translates to:
  /// **'Current medications'**
  String get currentMedications;

  /// No description provided for @surgeries.
  ///
  /// In en, this message translates to:
  /// **'Past surgeries'**
  String get surgeries;

  /// No description provided for @familyHistory.
  ///
  /// In en, this message translates to:
  /// **'Family history'**
  String get familyHistory;

  /// No description provided for @medicalProfileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get medicalProfileEmpty;

  /// No description provided for @medicalProfileReadOnly.
  ///
  /// In en, this message translates to:
  /// **'To update this information, contact your doctor.'**
  String get medicalProfileReadOnly;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notifyChat.
  ///
  /// In en, this message translates to:
  /// **'Chat messages'**
  String get notifyChat;

  /// No description provided for @notifyReminders.
  ///
  /// In en, this message translates to:
  /// **'Appointment reminders'**
  String get notifyReminders;

  /// No description provided for @notifyShowPreview.
  ///
  /// In en, this message translates to:
  /// **'Show message text in notifications'**
  String get notifyShowPreview;

  /// No description provided for @notifyShowPreviewHint.
  ///
  /// In en, this message translates to:
  /// **'Off keeps your messages private on the lock screen.'**
  String get notifyShowPreviewHint;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @requestAccountDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get requestAccountDeletion;

  /// No description provided for @deletionConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send your request to the el3yada team. Once it is approved you won\'t be able to sign in. Your doctors keep the medical records they are required to keep.'**
  String get deletionConfirmBody;

  /// No description provided for @deletionReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get deletionReasonLabel;

  /// No description provided for @deletionConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get deletionConfirmButton;

  /// No description provided for @deletionRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Your request was sent. We\'ll review it soon.'**
  String get deletionRequestSent;

  /// No description provided for @deletionPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Deletion request under review'**
  String get deletionPendingTitle;

  /// No description provided for @deletionPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Sent on {date}'**
  String deletionPendingBody(String date);

  /// No description provided for @deletionRejected.
  ///
  /// In en, this message translates to:
  /// **'Your last request was declined: {note}'**
  String deletionRejected(String note);

  /// No description provided for @termsGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get termsGateTitle;

  /// No description provided for @termsGateBody.
  ///
  /// In en, this message translates to:
  /// **'el3yada keeps your medical file safe and shares it only with your doctors. Please read and accept the Terms of Use and Privacy Policy to continue.'**
  String get termsGateBody;

  /// No description provided for @termsGateCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the Terms of Use and Privacy Policy'**
  String get termsGateCheckbox;

  /// No description provided for @termsGateContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get termsGateContinue;

  /// No description provided for @navDeletionRequests.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests'**
  String get navDeletionRequests;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @noDeletionRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests here.'**
  String get noDeletionRequests;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @approveDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve deletion?'**
  String get approveDeletionTitle;

  /// No description provided for @approveDeletionBody.
  ///
  /// In en, this message translates to:
  /// **'The patient will be signed out everywhere and can\'t sign in again. Medical records stay with their doctors.'**
  String get approveDeletionBody;

  /// No description provided for @rejectDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject the request'**
  String get rejectDeletionTitle;

  /// No description provided for @reasonRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason (the patient sees it)'**
  String get reasonRequiredLabel;

  /// No description provided for @errorInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid mobile number'**
  String get errorInvalidPhone;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @accountsSupportHint.
  ///
  /// In en, this message translates to:
  /// **'Search by mobile number only. Patient and assistant accounts are shown, never medical data.'**
  String get accountsSupportHint;

  /// No description provided for @noAccountsFound.
  ///
  /// In en, this message translates to:
  /// **'No account uses this number.'**
  String get noAccountsFound;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted at the patient\'s request'**
  String get accountDeleted;

  /// No description provided for @linkedDoctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors: {names}'**
  String linkedDoctors(String names);

  /// No description provided for @createdOn.
  ///
  /// In en, this message translates to:
  /// **'Created on {date}'**
  String createdOn(String date);

  /// No description provided for @assistantOf.
  ///
  /// In en, this message translates to:
  /// **'Assistant of {doctor}'**
  String assistantOf(String doctor);

  /// No description provided for @lastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {time}'**
  String lastActive(String time);

  /// No description provided for @loginEnabled.
  ///
  /// In en, this message translates to:
  /// **'Login enabled'**
  String get loginEnabled;

  /// No description provided for @loginDisabled.
  ///
  /// In en, this message translates to:
  /// **'Login disabled'**
  String get loginDisabled;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// No description provided for @searchChats.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get searchChats;

  /// No description provided for @noChats.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet.'**
  String get noChats;

  /// No description provided for @chatImage.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get chatImage;

  /// No description provided for @chatFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFile;

  /// No description provided for @chatNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatNoMessages;

  /// No description provided for @chatDoctorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The doctor isn\'t available right now.'**
  String get chatDoctorUnavailable;

  /// No description provided for @chatSuspended.
  ///
  /// In en, this message translates to:
  /// **'Sending is paused while the service is suspended.'**
  String get chatSuspended;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than allowed.'**
  String get fileTooLarge;

  /// No description provided for @chatCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get chatCamera;

  /// No description provided for @chatGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get chatGallery;

  /// No description provided for @chatFileOption.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get chatFileOption;

  /// No description provided for @saveToPatientFile.
  ///
  /// In en, this message translates to:
  /// **'Save to patient file'**
  String get saveToPatientFile;

  /// No description provided for @savedToPatientFile.
  ///
  /// In en, this message translates to:
  /// **'Saved to the patient\'s file'**
  String get savedToPatientFile;

  /// No description provided for @chatStart.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation.'**
  String get chatStart;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttach;

  /// No description provided for @chatTypeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get chatTypeMessage;

  /// No description provided for @chatSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSend;

  /// No description provided for @clinicAssistant.
  ///
  /// In en, this message translates to:
  /// **'Clinic assistant — {name}'**
  String clinicAssistant(String name);

  /// No description provided for @chatRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get chatRead;

  /// No description provided for @chatDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get chatDelivered;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose the category'**
  String get chooseCategory;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @apStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Waiting to confirm'**
  String get apStatusPending;

  /// No description provided for @apStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get apStatusConfirmed;

  /// No description provided for @apStatusCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get apStatusCheckedIn;

  /// No description provided for @apStatusWithDoctor.
  ///
  /// In en, this message translates to:
  /// **'With the doctor'**
  String get apStatusWithDoctor;

  /// No description provided for @apStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get apStatusCompleted;

  /// No description provided for @apStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get apStatusCancelled;

  /// No description provided for @apStatusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get apStatusNoShow;

  /// No description provided for @apStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get apStatusRejected;

  /// No description provided for @stageExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get stageExpected;

  /// No description provided for @stageWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get stageWaiting;

  /// No description provided for @stageWithDoctor.
  ///
  /// In en, this message translates to:
  /// **'With the doctor'**
  String get stageWithDoctor;

  /// No description provided for @stageDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stageDone;

  /// No description provided for @stageMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get stageMissed;

  /// No description provided for @queueNumber.
  ///
  /// In en, this message translates to:
  /// **'No. {number}'**
  String queueNumber(int number);

  /// No description provided for @errSlotTaken.
  ///
  /// In en, this message translates to:
  /// **'This time was just booked. Choose another one.'**
  String get errSlotTaken;

  /// No description provided for @errPeriodFull.
  ///
  /// In en, this message translates to:
  /// **'This period is fully booked.'**
  String get errPeriodFull;

  /// No description provided for @errOutsideHours.
  ///
  /// In en, this message translates to:
  /// **'This time is outside working hours.'**
  String get errOutsideHours;

  /// No description provided for @errBranchClosed.
  ///
  /// In en, this message translates to:
  /// **'The branch is closed at this time.'**
  String get errBranchClosed;

  /// No description provided for @errTooFarAhead.
  ///
  /// In en, this message translates to:
  /// **'Booking is open only for the coming days set by the clinic.'**
  String get errTooFarAhead;

  /// No description provided for @errTooSoon.
  ///
  /// In en, this message translates to:
  /// **'This time is too soon to book.'**
  String get errTooSoon;

  /// No description provided for @errSameDayOff.
  ///
  /// In en, this message translates to:
  /// **'Same-day booking isn\'t available. Please call the clinic.'**
  String get errSameDayOff;

  /// No description provided for @errUpcomingLimit.
  ///
  /// In en, this message translates to:
  /// **'You already have an upcoming booking with this doctor.'**
  String get errUpcomingLimit;

  /// No description provided for @errSelfBookingBlocked.
  ///
  /// In en, this message translates to:
  /// **'Please call the clinic to book.'**
  String get errSelfBookingBlocked;

  /// No description provided for @errConsultationRequiresExam.
  ///
  /// In en, this message translates to:
  /// **'A consultation isn\'t possible now. Book an examination.'**
  String get errConsultationRequiresExam;

  /// No description provided for @errCancelWindowPassed.
  ///
  /// In en, this message translates to:
  /// **'It\'s too late to change this booking. Please call the clinic.'**
  String get errCancelWindowPassed;

  /// No description provided for @errMaxReschedules.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the maximum number of changes for this booking.'**
  String get errMaxReschedules;

  /// No description provided for @errBookingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Online booking isn\'t available right now. Please call the clinic.'**
  String get errBookingUnavailable;

  /// No description provided for @errAlreadyHandled.
  ///
  /// In en, this message translates to:
  /// **'Someone else already updated this booking. The board was refreshed.'**
  String get errAlreadyHandled;

  /// No description provided for @errGuestNeedsAccount.
  ///
  /// In en, this message translates to:
  /// **'Create the patient\'s account first, then link the booking.'**
  String get errGuestNeedsAccount;

  /// No description provided for @boardOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline: the data may be out of date'**
  String get boardOffline;

  /// No description provided for @book.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// No description provided for @walkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get walkIn;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @doctorDelayed.
  ///
  /// In en, this message translates to:
  /// **'Doctor delayed'**
  String get doctorDelayed;

  /// No description provided for @minutesCount.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutesCount(int minutes);

  /// No description provided for @patientsNotified.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 patient notified} other{{count} patients notified}}'**
  String patientsNotified(int count);

  /// No description provided for @cancelRestOfDay.
  ///
  /// In en, this message translates to:
  /// **'Cancel the rest of today'**
  String get cancelRestOfDay;

  /// No description provided for @cancelRestOfDayBody.
  ///
  /// In en, this message translates to:
  /// **'Every booking that hasn\'t arrived yet at this branch today will be cancelled, and patients will be told to book again.'**
  String get cancelRestOfDayBody;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @bookingsCancelled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booking cancelled} other{{count} bookings cancelled}}'**
  String bookingsCancelled(int count);

  /// No description provided for @nowServing.
  ///
  /// In en, this message translates to:
  /// **'Now serving'**
  String get nowServing;

  /// No description provided for @countBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked: {count}'**
  String countBooked(int count);

  /// No description provided for @countArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived: {count}'**
  String countArrived(int count);

  /// No description provided for @delayedBy.
  ///
  /// In en, this message translates to:
  /// **'Delayed {minutes} min'**
  String delayedBy(int minutes);

  /// No description provided for @boardEmptyStage.
  ///
  /// In en, this message translates to:
  /// **'Nobody here'**
  String get boardEmptyStage;

  /// No description provided for @confirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmBooking;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkIn;

  /// No description provided for @callIn.
  ///
  /// In en, this message translates to:
  /// **'Call in'**
  String get callIn;

  /// No description provided for @undoNoShow.
  ///
  /// In en, this message translates to:
  /// **'Undo no-show'**
  String get undoNoShow;

  /// No description provided for @newPatient.
  ///
  /// In en, this message translates to:
  /// **'New patient'**
  String get newPatient;

  /// No description provided for @lastVisitOn.
  ///
  /// In en, this message translates to:
  /// **'Last visit: {date} — {type}'**
  String lastVisitOn(String date, String type);

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @late.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get late;

  /// No description provided for @consultationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Consultation not allowed'**
  String get consultationNotAllowed;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @waitedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String waitedMinutes(int minutes);

  /// No description provided for @markNoShow.
  ///
  /// In en, this message translates to:
  /// **'Mark no-show'**
  String get markNoShow;

  /// No description provided for @leftWithoutSeen.
  ///
  /// In en, this message translates to:
  /// **'Left without being seen'**
  String get leftWithoutSeen;

  /// No description provided for @sendBack.
  ///
  /// In en, this message translates to:
  /// **'Back to waiting'**
  String get sendBack;

  /// No description provided for @visitsCount.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsCount;

  /// No description provided for @lastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get lastVisit;

  /// No description provided for @recentAmounts.
  ///
  /// In en, this message translates to:
  /// **'Recent amounts'**
  String get recentAmounts;

  /// No description provided for @upcomingAndNoShows.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bookings · no-shows'**
  String get upcomingAndNoShows;

  /// No description provided for @bookingReason.
  ///
  /// In en, this message translates to:
  /// **'Reason for booking'**
  String get bookingReason;

  /// No description provided for @staffNotes.
  ///
  /// In en, this message translates to:
  /// **'Staff notes'**
  String get staffNotes;

  /// No description provided for @openBooking.
  ///
  /// In en, this message translates to:
  /// **'Open booking'**
  String get openBooking;

  /// No description provided for @searchPatient.
  ///
  /// In en, this message translates to:
  /// **'Name, phone or file number'**
  String get searchPatient;

  /// No description provided for @hasUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Has an upcoming booking'**
  String get hasUpcoming;

  /// No description provided for @chooseVisitType.
  ///
  /// In en, this message translates to:
  /// **'Choose the visit type'**
  String get chooseVisitType;

  /// No description provided for @guestNameAndPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter the name (two words at least) and the mobile number'**
  String get guestNameAndPhone;

  /// No description provided for @existingPatient.
  ///
  /// In en, this message translates to:
  /// **'Existing patient'**
  String get existingPatient;

  /// No description provided for @visitType.
  ///
  /// In en, this message translates to:
  /// **'Visit type'**
  String get visitType;

  /// No description provided for @firstVisitIsExam.
  ///
  /// In en, this message translates to:
  /// **'The first visit is always an examination.'**
  String get firstVisitIsExam;

  /// No description provided for @consultationCount.
  ///
  /// In en, this message translates to:
  /// **'Consultation {count} of {max} since the last examination'**
  String consultationCount(int count, int max);

  /// No description provided for @noOpenDays.
  ///
  /// In en, this message translates to:
  /// **'No open days in this range.'**
  String get noOpenDays;

  /// No description provided for @placesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Full} =1{1 place left} other{{count} places left}}'**
  String placesLeft(int count);

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'About {time}'**
  String estimatedTime(String time);

  /// No description provided for @tabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get tabUpcoming;

  /// No description provided for @tabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tabPast;

  /// No description provided for @tabCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tabCancelled;

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'No bookings here.'**
  String get noAppointments;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelBooking;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @bookingCancelled.
  ///
  /// In en, this message translates to:
  /// **'Your booking was cancelled.'**
  String get bookingCancelled;

  /// No description provided for @appointmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Booking details'**
  String get appointmentDetails;

  /// No description provided for @nowServingYourNumber.
  ///
  /// In en, this message translates to:
  /// **'Now serving {now} — your number {mine}'**
  String nowServingYourNumber(int now, int mine);

  /// No description provided for @waitingForClinic.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the clinic to confirm'**
  String get waitingForClinic;

  /// No description provided for @reschedule.
  ///
  /// In en, this message translates to:
  /// **'Change time'**
  String get reschedule;

  /// No description provided for @callClinic.
  ///
  /// In en, this message translates to:
  /// **'Call the clinic'**
  String get callClinic;

  /// No description provided for @openVisit.
  ///
  /// In en, this message translates to:
  /// **'Open the visit'**
  String get openVisit;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @byYou.
  ///
  /// In en, this message translates to:
  /// **'by you'**
  String get byYou;

  /// No description provided for @bySystem.
  ///
  /// In en, this message translates to:
  /// **'automatically'**
  String get bySystem;

  /// No description provided for @byClinic.
  ///
  /// In en, this message translates to:
  /// **'by the clinic'**
  String get byClinic;

  /// No description provided for @historyCreated.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get historyCreated;

  /// No description provided for @historyRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get historyRescheduled;

  /// No description provided for @historyExpired.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed in time'**
  String get historyExpired;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book an appointment'**
  String get bookAppointment;

  /// No description provided for @chooseDoctor.
  ///
  /// In en, this message translates to:
  /// **'Choose the doctor'**
  String get chooseDoctor;

  /// No description provided for @chooseBranch.
  ///
  /// In en, this message translates to:
  /// **'Choose the branch'**
  String get chooseBranch;

  /// No description provided for @chooseDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Choose the day and time'**
  String get chooseDateAndTime;

  /// No description provided for @bookingReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get bookingReasonOptional;

  /// No description provided for @cancelPolicy.
  ///
  /// In en, this message translates to:
  /// **'You can cancel or change up to {hours} hours before the appointment.'**
  String cancelPolicy(int hours);

  /// No description provided for @confirmBookingButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get confirmBookingButton;

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed'**
  String get bookingConfirmed;

  /// No description provided for @bookingMoved.
  ///
  /// In en, this message translates to:
  /// **'Your booking was moved'**
  String get bookingMoved;

  /// No description provided for @previousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get previousDay;

  /// No description provided for @nextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get nextDay;

  /// No description provided for @searchBookings.
  ///
  /// In en, this message translates to:
  /// **'Search bookings'**
  String get searchBookings;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @whenLabel.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get whenLabel;

  /// No description provided for @bookedBy.
  ///
  /// In en, this message translates to:
  /// **'Booked by'**
  String get bookedBy;

  /// No description provided for @overbooked.
  ///
  /// In en, this message translates to:
  /// **'Overbooked'**
  String get overbooked;

  /// No description provided for @checkedInNoSession.
  ///
  /// In en, this message translates to:
  /// **'Checked in, but no session was recorded'**
  String get checkedInNoSession;

  /// No description provided for @sourceApp.
  ///
  /// In en, this message translates to:
  /// **'patient app'**
  String get sourceApp;

  /// No description provided for @sourceStaff.
  ///
  /// In en, this message translates to:
  /// **'clinic'**
  String get sourceStaff;

  /// No description provided for @quickGuest.
  ///
  /// In en, this message translates to:
  /// **'Quick guest'**
  String get quickGuest;

  /// No description provided for @overbookTitle.
  ///
  /// In en, this message translates to:
  /// **'This place is full'**
  String get overbookTitle;

  /// No description provided for @overbookBody.
  ///
  /// In en, this message translates to:
  /// **'The period or time is already full. Book anyway as an extra?'**
  String get overbookBody;

  /// No description provided for @upcomingWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This patient already has an upcoming booking. You can change that one instead, or book another.'**
  String get upcomingWarningBody;

  /// No description provided for @bookAnyway.
  ///
  /// In en, this message translates to:
  /// **'Book anyway'**
  String get bookAnyway;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @next7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get next7Days;

  /// No description provided for @guestsOnly.
  ///
  /// In en, this message translates to:
  /// **'Guests only'**
  String get guestsOnly;

  /// No description provided for @scheduleConflictsLeft.
  ///
  /// In en, this message translates to:
  /// **'Some bookings still need a decision.'**
  String get scheduleConflictsLeft;

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved'**
  String get scheduleSaved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @specialDates.
  ///
  /// In en, this message translates to:
  /// **'Special dates'**
  String get specialDates;

  /// No description provided for @bookingSettings.
  ///
  /// In en, this message translates to:
  /// **'Booking settings'**
  String get bookingSettings;

  /// No description provided for @copySaturdayToAll.
  ///
  /// In en, this message translates to:
  /// **'Copy Saturday to all days'**
  String get copySaturdayToAll;

  /// No description provided for @addPeriod.
  ///
  /// In en, this message translates to:
  /// **'Add period'**
  String get addPeriod;

  /// No description provided for @closeADay.
  ///
  /// In en, this message translates to:
  /// **'Close a day'**
  String get closeADay;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @closures.
  ///
  /// In en, this message translates to:
  /// **'Closures and vacations'**
  String get closures;

  /// No description provided for @addClosure.
  ///
  /// In en, this message translates to:
  /// **'Add closure'**
  String get addClosure;

  /// No description provided for @closureScope.
  ///
  /// In en, this message translates to:
  /// **'Close which branches?'**
  String get closureScope;

  /// No description provided for @thisBranch.
  ///
  /// In en, this message translates to:
  /// **'This branch'**
  String get thisBranch;

  /// No description provided for @allBranches.
  ///
  /// In en, this message translates to:
  /// **'All branches'**
  String get allBranches;

  /// No description provided for @bookingMode.
  ///
  /// In en, this message translates to:
  /// **'Booking mode'**
  String get bookingMode;

  /// No description provided for @modeQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue numbers'**
  String get modeQueue;

  /// No description provided for @modeTimed.
  ///
  /// In en, this message translates to:
  /// **'Timed slots'**
  String get modeTimed;

  /// No description provided for @slotMinutes.
  ///
  /// In en, this message translates to:
  /// **'Slot length (minutes)'**
  String get slotMinutes;

  /// No description provided for @defaultCapacity.
  ///
  /// In en, this message translates to:
  /// **'Places per period'**
  String get defaultCapacity;

  /// No description provided for @avgVisitMinutes.
  ///
  /// In en, this message translates to:
  /// **'Average visit (minutes)'**
  String get avgVisitMinutes;

  /// No description provided for @selfBooking.
  ///
  /// In en, this message translates to:
  /// **'Patients can book from the app'**
  String get selfBooking;

  /// No description provided for @autoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm app bookings automatically'**
  String get autoConfirm;

  /// No description provided for @sameDayBooking.
  ///
  /// In en, this message translates to:
  /// **'Same-day booking'**
  String get sameDayBooking;

  /// No description provided for @staffOverbooking.
  ///
  /// In en, this message translates to:
  /// **'Staff can overbook after a warning'**
  String get staffOverbooking;

  /// No description provided for @windowDays.
  ///
  /// In en, this message translates to:
  /// **'Booking window (days)'**
  String get windowDays;

  /// No description provided for @minNoticeMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minimum notice (minutes)'**
  String get minNoticeMinutes;

  /// No description provided for @freeCancelMinutes.
  ///
  /// In en, this message translates to:
  /// **'Free cancel until (minutes before)'**
  String get freeCancelMinutes;

  /// No description provided for @maxReschedules.
  ///
  /// In en, this message translates to:
  /// **'Changes per booking'**
  String get maxReschedules;

  /// No description provided for @maxUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming bookings per patient'**
  String get maxUpcoming;

  /// No description provided for @nextDayShort.
  ///
  /// In en, this message translates to:
  /// **'(+1 day)'**
  String get nextDayShort;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get capacity;

  /// No description provided for @affectedBookings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 booking is affected} other{{count} bookings are affected}}'**
  String affectedBookings(int count);

  /// No description provided for @keepAll.
  ///
  /// In en, this message translates to:
  /// **'Keep all'**
  String get keepAll;

  /// No description provided for @cancelAll.
  ///
  /// In en, this message translates to:
  /// **'Cancel all'**
  String get cancelAll;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @applyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply changes'**
  String get applyChanges;

  /// No description provided for @billTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billTitle;

  /// No description provided for @billSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your platform invoices and payments'**
  String get billSubtitle;

  /// No description provided for @billInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get billInvoices;

  /// No description provided for @billEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invoices yet'**
  String get billEmptyTitle;

  /// No description provided for @billEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your first invoice appears on the 1st of next month.'**
  String get billEmptyBody;

  /// No description provided for @billAllSettledTitle.
  ///
  /// In en, this message translates to:
  /// **'All settled'**
  String get billAllSettledTitle;

  /// No description provided for @billAllSettledBody.
  ///
  /// In en, this message translates to:
  /// **'You have nothing to pay right now.'**
  String get billAllSettledBody;

  /// No description provided for @billRunningMonth.
  ///
  /// In en, this message translates to:
  /// **'This month so far'**
  String get billRunningMonth;

  /// No description provided for @billRunningMonthHint.
  ///
  /// In en, this message translates to:
  /// **'The running total, day by day'**
  String get billRunningMonthHint;

  /// No description provided for @billInvoiceOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Invoice for {month}'**
  String billInvoiceOfMonth(String month);

  /// No description provided for @billUnderReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment for {month} is under review'**
  String billUnderReviewTitle(String month);

  /// No description provided for @billUnderReviewBody.
  ///
  /// In en, this message translates to:
  /// **'The platform team is checking your transfer. You will be notified.'**
  String get billUnderReviewBody;

  /// No description provided for @billPay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get billPay;

  /// No description provided for @billPayTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit a payment'**
  String get billPayTitle;

  /// No description provided for @billStatusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get billStatusUnpaid;

  /// No description provided for @billStatusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get billStatusPendingReview;

  /// No description provided for @billStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get billStatusPaid;

  /// No description provided for @billStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get billStatusRejected;

  /// No description provided for @billStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get billStatusOverdue;

  /// No description provided for @billStatusWaived.
  ///
  /// In en, this message translates to:
  /// **'Waived'**
  String get billStatusWaived;

  /// No description provided for @billStatusNoCharge.
  ///
  /// In en, this message translates to:
  /// **'No charge'**
  String get billStatusNoCharge;

  /// No description provided for @billDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get billDueToday;

  /// No description provided for @billDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get billDueTomorrow;

  /// No description provided for @billDueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String billDueInDays(int days);

  /// No description provided for @billDueLate.
  ///
  /// In en, this message translates to:
  /// **'{days} days late'**
  String billDueLate(int days);

  /// No description provided for @billDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String billDueOn(String date);

  /// No description provided for @billCounts.
  ///
  /// In en, this message translates to:
  /// **'{examinations} exam + {consultations} consult'**
  String billCounts(int examinations, int consultations);

  /// No description provided for @billInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get billInvoiceTitle;

  /// No description provided for @billInvoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Counts, amounts and payments'**
  String get billInvoiceSubtitle;

  /// No description provided for @billInvoiceTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get billInvoiceTotals;

  /// No description provided for @billExaminationsLine.
  ///
  /// In en, this message translates to:
  /// **'{count} examinations'**
  String billExaminationsLine(int count);

  /// No description provided for @billConsultationsLine.
  ///
  /// In en, this message translates to:
  /// **'{count} consultations'**
  String billConsultationsLine(int count);

  /// No description provided for @billAdjustmentLine.
  ///
  /// In en, this message translates to:
  /// **'Adjustment: {reason}'**
  String billAdjustmentLine(String reason);

  /// No description provided for @billTotalDue.
  ///
  /// In en, this message translates to:
  /// **'Total due'**
  String get billTotalDue;

  /// No description provided for @billPeriodLine.
  ///
  /// In en, this message translates to:
  /// **'Period: {month}'**
  String billPeriodLine(String month);

  /// No description provided for @billPaidOn.
  ///
  /// In en, this message translates to:
  /// **'Paid on {date} {method}'**
  String billPaidOn(String date, String method);

  /// No description provided for @billByBranch.
  ///
  /// In en, this message translates to:
  /// **'By branch'**
  String get billByBranch;

  /// No description provided for @billPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get billPayments;

  /// No description provided for @billTimeline.
  ///
  /// In en, this message translates to:
  /// **'Status history'**
  String get billTimeline;

  /// No description provided for @billPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get billPaymentPending;

  /// No description provided for @billPaymentApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get billPaymentApproved;

  /// No description provided for @billPaymentRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get billPaymentRejected;

  /// No description provided for @billTransferOn.
  ///
  /// In en, this message translates to:
  /// **'Transferred {date}'**
  String billTransferOn(String date);

  /// No description provided for @billReference.
  ///
  /// In en, this message translates to:
  /// **'Ref {reference}'**
  String billReference(String reference);

  /// No description provided for @billRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String billRejectionReason(String reason);

  /// No description provided for @billRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your payment was rejected'**
  String get billRejectedTitle;

  /// No description provided for @billRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'{reason}. Submit the payment again with a clear screenshot.'**
  String billRejectedBody(String reason);

  /// No description provided for @billScreenshotN.
  ///
  /// In en, this message translates to:
  /// **'Screenshot {number}'**
  String billScreenshotN(int number);

  /// No description provided for @billMethodInstapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get billMethodInstapay;

  /// No description provided for @billMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get billMethodCash;

  /// No description provided for @billMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get billMethodBank;

  /// No description provided for @billMethodOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get billMethodOther;

  /// No description provided for @billInstapayTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to send the money'**
  String get billInstapayTitle;

  /// No description provided for @billInstapayAddress.
  ///
  /// In en, this message translates to:
  /// **'InstaPay address'**
  String get billInstapayAddress;

  /// No description provided for @billInstapayAccount.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get billInstapayAccount;

  /// No description provided for @billInstapayAmount.
  ///
  /// In en, this message translates to:
  /// **'Exact amount'**
  String get billInstapayAmount;

  /// No description provided for @billCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get billCopy;

  /// No description provided for @billCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get billCopied;

  /// No description provided for @billPaymentDetails.
  ///
  /// In en, this message translates to:
  /// **'Payment details'**
  String get billPaymentDetails;

  /// No description provided for @billScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots of the transfer'**
  String get billScreenshots;

  /// No description provided for @billScreenshotsHint.
  ///
  /// In en, this message translates to:
  /// **'1 to 3 images, up to 10 MB each'**
  String get billScreenshotsHint;

  /// No description provided for @billAddScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Add a screenshot'**
  String get billAddScreenshot;

  /// No description provided for @billRemoveScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Remove this screenshot'**
  String get billRemoveScreenshot;

  /// No description provided for @billErrorScreenshotRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one screenshot of the transfer'**
  String get billErrorScreenshotRequired;

  /// No description provided for @billAmountTransferred.
  ///
  /// In en, this message translates to:
  /// **'Amount transferred'**
  String get billAmountTransferred;

  /// No description provided for @billEgpUnit.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get billEgpUnit;

  /// No description provided for @billErrorAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the amount you transferred'**
  String get billErrorAmount;

  /// No description provided for @billTransferDate.
  ///
  /// In en, this message translates to:
  /// **'Transfer date'**
  String get billTransferDate;

  /// No description provided for @billReferenceOptional.
  ///
  /// In en, this message translates to:
  /// **'InstaPay reference (optional)'**
  String get billReferenceOptional;

  /// No description provided for @billSenderOptional.
  ///
  /// In en, this message translates to:
  /// **'Sender name (optional)'**
  String get billSenderOptional;

  /// No description provided for @billNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get billNoteOptional;

  /// No description provided for @billSubmitPayment.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get billSubmitPayment;

  /// No description provided for @billSubmittedSnack.
  ///
  /// In en, this message translates to:
  /// **'Your payment is under review'**
  String get billSubmittedSnack;

  /// No description provided for @billErrorNotPayable.
  ///
  /// In en, this message translates to:
  /// **'This invoice can\'t be paid right now. It may already be paid or under review.'**
  String get billErrorNotPayable;

  /// No description provided for @anaPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get anaPeriod;

  /// No description provided for @anaPresetToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get anaPresetToday;

  /// No description provided for @anaPresetYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get anaPresetYesterday;

  /// No description provided for @anaPresetThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get anaPresetThisWeek;

  /// No description provided for @anaPresetLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get anaPresetLastWeek;

  /// No description provided for @anaPresetThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get anaPresetThisMonth;

  /// No description provided for @anaPresetLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get anaPresetLastMonth;

  /// No description provided for @anaPresetLast3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get anaPresetLast3Months;

  /// No description provided for @anaPresetLast6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 months'**
  String get anaPresetLast6Months;

  /// No description provided for @anaPresetThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get anaPresetThisYear;

  /// No description provided for @anaPresetLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get anaPresetLastYear;

  /// No description provided for @anaPresetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get anaPresetCustom;

  /// No description provided for @anaAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All visits'**
  String get anaAllTypes;

  /// No description provided for @anaCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get anaCompare;

  /// No description provided for @anaInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get anaInsights;

  /// No description provided for @anaTileRevenue.
  ///
  /// In en, this message translates to:
  /// **'Clinic revenue'**
  String get anaTileRevenue;

  /// No description provided for @anaTileNet.
  ///
  /// In en, this message translates to:
  /// **'Net income'**
  String get anaTileNet;

  /// No description provided for @anaTileFees.
  ///
  /// In en, this message translates to:
  /// **'Platform fees'**
  String get anaTileFees;

  /// No description provided for @anaTileVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get anaTileVisits;

  /// No description provided for @anaTileVisitsSplit.
  ///
  /// In en, this message translates to:
  /// **'{examinations} exams · {consultations} consults'**
  String anaTileVisitsSplit(int examinations, int consultations);

  /// No description provided for @anaTilePatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get anaTilePatients;

  /// No description provided for @anaTileNewPatients.
  ///
  /// In en, this message translates to:
  /// **'New patients'**
  String get anaTileNewPatients;

  /// No description provided for @anaTileWeeklyAverage.
  ///
  /// In en, this message translates to:
  /// **'Patients per week'**
  String get anaTileWeeklyAverage;

  /// No description provided for @anaTileAveragePerVisit.
  ///
  /// In en, this message translates to:
  /// **'Revenue per visit'**
  String get anaTileAveragePerVisit;

  /// No description provided for @anaTileNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show rate'**
  String get anaTileNoShow;

  /// No description provided for @anaTileAppShare.
  ///
  /// In en, this message translates to:
  /// **'Booked from the app'**
  String get anaTileAppShare;

  /// No description provided for @anaTileWait.
  ///
  /// In en, this message translates to:
  /// **'Average wait'**
  String get anaTileWait;

  /// No description provided for @anaPercent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String anaPercent(String value);

  /// No description provided for @anaMinutes.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String anaMinutes(String value);

  /// No description provided for @anaNoChange.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get anaNoChange;

  /// No description provided for @anaUp.
  ///
  /// In en, this message translates to:
  /// **'up'**
  String get anaUp;

  /// No description provided for @anaDown.
  ///
  /// In en, this message translates to:
  /// **'down'**
  String get anaDown;

  /// No description provided for @anaChangeSemantics.
  ///
  /// In en, this message translates to:
  /// **'{direction} {percent} percent versus the previous period'**
  String anaChangeSemantics(String percent, String direction);

  /// No description provided for @anaInvoiceCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice for {month}'**
  String anaInvoiceCardTitle(String month);

  /// No description provided for @anaPreviousPeriod.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get anaPreviousPeriod;

  /// No description provided for @anaNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get anaNoData;

  /// No description provided for @anaC1Title.
  ///
  /// In en, this message translates to:
  /// **'Revenue over time'**
  String get anaC1Title;

  /// No description provided for @anaC1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Examinations and consultations'**
  String get anaC1Subtitle;

  /// No description provided for @anaC1Summary.
  ///
  /// In en, this message translates to:
  /// **'Revenue chart. Total {total}'**
  String anaC1Summary(String total);

  /// No description provided for @anaC2Title.
  ///
  /// In en, this message translates to:
  /// **'Visits over time'**
  String get anaC2Title;

  /// No description provided for @anaC2Summary.
  ///
  /// In en, this message translates to:
  /// **'Visits chart. {total} visits'**
  String anaC2Summary(int total);

  /// No description provided for @anaC3Title.
  ///
  /// In en, this message translates to:
  /// **'Patients per week'**
  String get anaC3Title;

  /// No description provided for @anaC3Summary.
  ///
  /// In en, this message translates to:
  /// **'Patients per week chart. Average {average}'**
  String anaC3Summary(String average);

  /// No description provided for @anaPatientsPerWeek.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get anaPatientsPerWeek;

  /// No description provided for @anaWeeklyAverageLine.
  ///
  /// In en, this message translates to:
  /// **'Average {average}'**
  String anaWeeklyAverageLine(String average);

  /// No description provided for @anaWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String anaWeekOf(String date);

  /// No description provided for @anaPatientsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} patients'**
  String anaPatientsCount(int count);

  /// No description provided for @anaC4Title.
  ///
  /// In en, this message translates to:
  /// **'Busy and quiet months'**
  String get anaC4Title;

  /// No description provided for @anaC4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Visits per month, last 12 months'**
  String get anaC4Subtitle;

  /// No description provided for @anaC4Summary.
  ///
  /// In en, this message translates to:
  /// **'Visits per month chart with the busiest and quietest months highlighted'**
  String get anaC4Summary;

  /// No description provided for @anaBusiest.
  ///
  /// In en, this message translates to:
  /// **'Busiest'**
  String get anaBusiest;

  /// No description provided for @anaQuietest.
  ///
  /// In en, this message translates to:
  /// **'Quietest'**
  String get anaQuietest;

  /// No description provided for @anaThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get anaThisYear;

  /// No description provided for @anaLastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get anaLastYear;

  /// No description provided for @anaVisitsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} visits'**
  String anaVisitsCount(int count);

  /// No description provided for @anaC5Title.
  ///
  /// In en, this message translates to:
  /// **'Busiest days and hours'**
  String get anaC5Title;

  /// No description provided for @anaC5Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Visits by weekday and hour'**
  String get anaC5Subtitle;

  /// No description provided for @anaC5Summary.
  ///
  /// In en, this message translates to:
  /// **'Heatmap of visits by weekday and hour'**
  String get anaC5Summary;

  /// No description provided for @anaHeatCell.
  ///
  /// In en, this message translates to:
  /// **'{day}, {hour}:00: {count} visits'**
  String anaHeatCell(String day, int hour, int count);

  /// No description provided for @anaSat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get anaSat;

  /// No description provided for @anaSun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get anaSun;

  /// No description provided for @anaMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get anaMon;

  /// No description provided for @anaTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get anaTue;

  /// No description provided for @anaWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get anaWed;

  /// No description provided for @anaThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get anaThu;

  /// No description provided for @anaFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get anaFri;

  /// No description provided for @anaC6Title.
  ///
  /// In en, this message translates to:
  /// **'New and returning patients'**
  String get anaC6Title;

  /// No description provided for @anaC6Summary.
  ///
  /// In en, this message translates to:
  /// **'New and returning patients per month'**
  String get anaC6Summary;

  /// No description provided for @anaNewPatients.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get anaNewPatients;

  /// No description provided for @anaReturningPatients.
  ///
  /// In en, this message translates to:
  /// **'Returning'**
  String get anaReturningPatients;

  /// No description provided for @anaC7Title.
  ///
  /// In en, this message translates to:
  /// **'Examinations and consultations'**
  String get anaC7Title;

  /// No description provided for @anaC7Summary.
  ///
  /// In en, this message translates to:
  /// **'{examinations} examinations and {consultations} consultations'**
  String anaC7Summary(int examinations, int consultations);

  /// No description provided for @anaByCount.
  ///
  /// In en, this message translates to:
  /// **'By number of visits'**
  String get anaByCount;

  /// No description provided for @anaByRevenue.
  ///
  /// In en, this message translates to:
  /// **'By revenue'**
  String get anaByRevenue;

  /// No description provided for @anaC8Title.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get anaC8Title;

  /// No description provided for @anaC8Summary.
  ///
  /// In en, this message translates to:
  /// **'Visits and revenue per branch'**
  String get anaC8Summary;

  /// No description provided for @anaC9Title.
  ///
  /// In en, this message translates to:
  /// **'Bookings funnel'**
  String get anaC9Title;

  /// No description provided for @anaC9Summary.
  ///
  /// In en, this message translates to:
  /// **'{booked} booked, {arrived} arrived, {seen} seen'**
  String anaC9Summary(int booked, int arrived, int seen);

  /// No description provided for @anaFunnelBooked.
  ///
  /// In en, this message translates to:
  /// **'Booked'**
  String get anaFunnelBooked;

  /// No description provided for @anaFunnelArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get anaFunnelArrived;

  /// No description provided for @anaFunnelSeen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get anaFunnelSeen;

  /// No description provided for @anaNoShows.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get anaNoShows;

  /// No description provided for @anaCancellations.
  ///
  /// In en, this message translates to:
  /// **'Cancellations'**
  String get anaCancellations;

  /// No description provided for @anaC10Title.
  ///
  /// In en, this message translates to:
  /// **'Booking sources'**
  String get anaC10Title;

  /// No description provided for @anaC10Summary.
  ///
  /// In en, this message translates to:
  /// **'Bookings per month by source'**
  String get anaC10Summary;

  /// No description provided for @anaSourceApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get anaSourceApp;

  /// No description provided for @anaSourceStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get anaSourceStaff;

  /// No description provided for @anaSourceWalkIn.
  ///
  /// In en, this message translates to:
  /// **'Walk-in'**
  String get anaSourceWalkIn;

  /// No description provided for @anaC11Title.
  ///
  /// In en, this message translates to:
  /// **'Patients not seen recently'**
  String get anaC11Title;

  /// No description provided for @anaC11Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a bar to open the list'**
  String get anaC11Subtitle;

  /// No description provided for @anaC11Summary.
  ///
  /// In en, this message translates to:
  /// **'Patients whose last visit was 3, 6 or 12 or more months ago'**
  String get anaC11Summary;

  /// No description provided for @anaNotSeenMonths.
  ///
  /// In en, this message translates to:
  /// **'More than {months} months'**
  String anaNotSeenMonths(int months);

  /// No description provided for @anaNotSeen12.
  ///
  /// In en, this message translates to:
  /// **'12 months or more'**
  String get anaNotSeen12;

  /// No description provided for @anaC12Title.
  ///
  /// In en, this message translates to:
  /// **'Waiting time'**
  String get anaC12Title;

  /// No description provided for @anaC12Summary.
  ///
  /// In en, this message translates to:
  /// **'Average wait per day'**
  String get anaC12Summary;

  /// No description provided for @revTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revTitle;

  /// No description provided for @revSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Month by month, with fees and net income'**
  String get revSubtitle;

  /// No description provided for @revTabMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get revTabMonth;

  /// No description provided for @revTabBranch.
  ///
  /// In en, this message translates to:
  /// **'By branch'**
  String get revTabBranch;

  /// No description provided for @revTabType.
  ///
  /// In en, this message translates to:
  /// **'By visit type'**
  String get revTabType;

  /// No description provided for @revTabPayment.
  ///
  /// In en, this message translates to:
  /// **'By payment method'**
  String get revTabPayment;

  /// No description provided for @revEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No visits in this period'**
  String get revEmptyTitle;

  /// No description provided for @revEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Change the year or the filters to see more.'**
  String get revEmptyBody;

  /// No description provided for @revColMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get revColMonth;

  /// No description provided for @revColExaminations.
  ///
  /// In en, this message translates to:
  /// **'Examinations'**
  String get revColExaminations;

  /// No description provided for @revColConsultations.
  ///
  /// In en, this message translates to:
  /// **'Consultations'**
  String get revColConsultations;

  /// No description provided for @revColRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revColRevenue;

  /// No description provided for @revColFees.
  ///
  /// In en, this message translates to:
  /// **'Platform fees'**
  String get revColFees;

  /// No description provided for @revColNet.
  ///
  /// In en, this message translates to:
  /// **'Net income'**
  String get revColNet;

  /// No description provided for @revColPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get revColPatients;

  /// No description provided for @revColNewPatients.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get revColNewPatients;

  /// No description provided for @revColVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get revColVisits;

  /// No description provided for @revColFreeDiscounted.
  ///
  /// In en, this message translates to:
  /// **'Free / discounted'**
  String get revColFreeDiscounted;

  /// No description provided for @revColChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get revColChange;

  /// No description provided for @revColInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get revColInvoice;

  /// No description provided for @revOpenInvoice.
  ///
  /// In en, this message translates to:
  /// **'Open invoice'**
  String get revOpenInvoice;

  /// No description provided for @revTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get revTotals;

  /// No description provided for @revBestMonth.
  ///
  /// In en, this message translates to:
  /// **'Best month'**
  String get revBestMonth;

  /// No description provided for @revWorstMonth.
  ///
  /// In en, this message translates to:
  /// **'Lowest month'**
  String get revWorstMonth;

  /// No description provided for @revMonthSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Day by day. Tap a day for its sessions.'**
  String get revMonthSubtitle;

  /// No description provided for @revDaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every session of the day'**
  String get revDaySubtitle;

  /// No description provided for @revNetShort.
  ///
  /// In en, this message translates to:
  /// **'Net {amount}'**
  String revNetShort(String amount);

  /// No description provided for @revRecordedBy.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String revRecordedBy(String name);

  /// No description provided for @revVisitPrice.
  ///
  /// In en, this message translates to:
  /// **'Visit price'**
  String get revVisitPrice;

  /// No description provided for @revAmountCharged.
  ///
  /// In en, this message translates to:
  /// **'Charged'**
  String get revAmountCharged;

  /// No description provided for @revDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get revDiscount;

  /// No description provided for @revMethodUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get revMethodUnspecified;

  /// No description provided for @abDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get abDashboardTitle;

  /// No description provided for @abDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The platform at a glance'**
  String get abDashboardSubtitle;

  /// No description provided for @abTileDoctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get abTileDoctors;

  /// No description provided for @abTileDoctorsCaption.
  ///
  /// In en, this message translates to:
  /// **'{active} active · {pending} pending · {suspended} suspended'**
  String abTileDoctorsCaption(int active, int pending, int suspended);

  /// No description provided for @abTilePatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get abTilePatients;

  /// No description provided for @abTileSessionsToday.
  ///
  /// In en, this message translates to:
  /// **'Sessions today'**
  String get abTileSessionsToday;

  /// No description provided for @abTileSessionsMonth.
  ///
  /// In en, this message translates to:
  /// **'Sessions this month'**
  String get abTileSessionsMonth;

  /// No description provided for @abTileBookingsToday.
  ///
  /// In en, this message translates to:
  /// **'Bookings today'**
  String get abTileBookingsToday;

  /// No description provided for @abTileNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show rate'**
  String get abTileNoShow;

  /// No description provided for @abLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get abLast30Days;

  /// No description provided for @abTileExpectedFees.
  ///
  /// In en, this message translates to:
  /// **'Expected fees this month'**
  String get abTileExpectedFees;

  /// No description provided for @abLiveThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Live, from the sessions saved'**
  String get abLiveThisMonth;

  /// No description provided for @abTileLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month collected'**
  String get abTileLastMonth;

  /// No description provided for @abCollectedOfInvoiced.
  ///
  /// In en, this message translates to:
  /// **'of {invoiced} invoiced'**
  String abCollectedOfInvoiced(String invoiced);

  /// No description provided for @abTileOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get abTileOutstanding;

  /// No description provided for @abTileOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue doctors'**
  String get abTileOverdue;

  /// No description provided for @abTilePaymentsToReview.
  ///
  /// In en, this message translates to:
  /// **'Payments to review'**
  String get abTilePaymentsToReview;

  /// No description provided for @abTileSignups.
  ///
  /// In en, this message translates to:
  /// **'Sign-ups to approve'**
  String get abTileSignups;

  /// No description provided for @abChartSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions, last 30 days'**
  String get abChartSessions;

  /// No description provided for @abChartInvoiced.
  ///
  /// In en, this message translates to:
  /// **'Invoiced and collected, last 12 months'**
  String get abChartInvoiced;

  /// No description provided for @abInvoiced.
  ///
  /// In en, this message translates to:
  /// **'Invoiced'**
  String get abInvoiced;

  /// No description provided for @abCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get abCollected;

  /// No description provided for @abListPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments to review'**
  String get abListPayments;

  /// No description provided for @abListPaymentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting for review.'**
  String get abListPaymentsEmpty;

  /// No description provided for @abListSignups.
  ///
  /// In en, this message translates to:
  /// **'Latest sign-ups'**
  String get abListSignups;

  /// No description provided for @abListSignupsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sign-ups yet.'**
  String get abListSignupsEmpty;

  /// No description provided for @abListDueSoon.
  ///
  /// In en, this message translates to:
  /// **'Invoices due in 3 days'**
  String get abListDueSoon;

  /// No description provided for @abListDueSoonEmpty.
  ///
  /// In en, this message translates to:
  /// **'No invoice is due soon.'**
  String get abListDueSoonEmpty;

  /// No description provided for @abSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get abSeeAll;

  /// No description provided for @abPaymentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments to review'**
  String get abPaymentsTitle;

  /// No description provided for @abPaymentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting, oldest first'**
  String abPaymentsSubtitle(int count);

  /// No description provided for @abPaymentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to review'**
  String get abPaymentsEmptyTitle;

  /// No description provided for @abPaymentsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New payments from doctors appear here.'**
  String get abPaymentsEmptyBody;

  /// No description provided for @abInvoiceOf.
  ///
  /// In en, this message translates to:
  /// **'Invoice for {month}'**
  String abInvoiceOf(String month);

  /// No description provided for @abAmountMismatch.
  ///
  /// In en, this message translates to:
  /// **'Amount differs'**
  String get abAmountMismatch;

  /// No description provided for @abInvoiceTotalShort.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String abInvoiceTotalShort(String total);

  /// No description provided for @abReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review payment'**
  String get abReviewTitle;

  /// No description provided for @abScreenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get abScreenshots;

  /// No description provided for @abNoScreenshots.
  ///
  /// In en, this message translates to:
  /// **'No screenshots'**
  String get abNoScreenshots;

  /// No description provided for @abInvoiceSummary.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get abInvoiceSummary;

  /// No description provided for @abDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get abDoctor;

  /// No description provided for @abMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get abMonth;

  /// No description provided for @abDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get abDueDate;

  /// No description provided for @abDoctorEntries.
  ///
  /// In en, this message translates to:
  /// **'What the doctor entered'**
  String get abDoctorEntries;

  /// No description provided for @abMismatchBanner.
  ///
  /// In en, this message translates to:
  /// **'The invoice total is {total}'**
  String abMismatchBanner(String total);

  /// No description provided for @abSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get abSubmitted;

  /// No description provided for @abEarlierAttempts.
  ///
  /// In en, this message translates to:
  /// **'Earlier attempts on this invoice'**
  String get abEarlierAttempts;

  /// No description provided for @abAlreadyApproved.
  ///
  /// In en, this message translates to:
  /// **'Already approved'**
  String get abAlreadyApproved;

  /// No description provided for @abAlreadyRejected.
  ///
  /// In en, this message translates to:
  /// **'Already rejected: {reason}'**
  String abAlreadyRejected(String reason);

  /// No description provided for @abApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get abApprove;

  /// No description provided for @abApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve this payment?'**
  String get abApproveTitle;

  /// No description provided for @abApproveBody.
  ///
  /// In en, this message translates to:
  /// **'{amount} from {doctor} will mark the invoice as paid.'**
  String abApproveBody(String amount, String doctor);

  /// No description provided for @abApprovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Payment approved'**
  String get abApprovedSnack;

  /// No description provided for @abReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get abReject;

  /// No description provided for @abRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject this payment'**
  String get abRejectTitle;

  /// No description provided for @abRejectBody.
  ///
  /// In en, this message translates to:
  /// **'The doctor sees the reason and can submit again.'**
  String get abRejectBody;

  /// No description provided for @abRejectAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount does not match'**
  String get abRejectAmount;

  /// No description provided for @abRejectUnclear.
  ///
  /// In en, this message translates to:
  /// **'Screenshot unclear'**
  String get abRejectUnclear;

  /// No description provided for @abRejectNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Transfer not received'**
  String get abRejectNotReceived;

  /// No description provided for @abRejectedSnack.
  ///
  /// In en, this message translates to:
  /// **'Payment rejected'**
  String get abRejectedSnack;

  /// No description provided for @abReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get abReasonLabel;

  /// No description provided for @abReasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Write at least 3 characters'**
  String get abReasonRequired;

  /// No description provided for @abNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get abNoteLabel;

  /// No description provided for @abSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get abSave;

  /// No description provided for @abSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get abSend;

  /// No description provided for @abInvoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get abInvoicesTitle;

  /// No description provided for @abInvoicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every doctor\'s monthly invoice'**
  String get abInvoicesSubtitle;

  /// No description provided for @abInvoicesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invoices match'**
  String get abInvoicesEmptyTitle;

  /// No description provided for @abInvoicesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Change the month or the status.'**
  String get abInvoicesEmptyBody;

  /// No description provided for @abFilterMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get abFilterMonth;

  /// No description provided for @abAllMonths.
  ///
  /// In en, this message translates to:
  /// **'All months'**
  String get abAllMonths;

  /// No description provided for @abAllStatuses.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get abAllStatuses;

  /// No description provided for @abTotalsInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get abTotalsInvoices;

  /// No description provided for @abTotalsExaminations.
  ///
  /// In en, this message translates to:
  /// **'Examinations'**
  String get abTotalsExaminations;

  /// No description provided for @abTotalsConsultations.
  ///
  /// In en, this message translates to:
  /// **'Consultations'**
  String get abTotalsConsultations;

  /// No description provided for @abTotalsAmount.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get abTotalsAmount;

  /// No description provided for @abInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get abInvoiceTitle;

  /// No description provided for @abMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark paid'**
  String get abMarkPaid;

  /// No description provided for @abMarkPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark this invoice as paid'**
  String get abMarkPaidTitle;

  /// No description provided for @abMarkPaidBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how the money arrived and add a note.'**
  String get abMarkPaidBody;

  /// No description provided for @abMarkedPaidSnack.
  ///
  /// In en, this message translates to:
  /// **'Invoice marked as paid'**
  String get abMarkedPaidSnack;

  /// No description provided for @abWaive.
  ///
  /// In en, this message translates to:
  /// **'Waive'**
  String get abWaive;

  /// No description provided for @abWaiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Waive this invoice'**
  String get abWaiveTitle;

  /// No description provided for @abWaiveBody.
  ///
  /// In en, this message translates to:
  /// **'The doctor owes nothing for this month. A reason is required.'**
  String get abWaiveBody;

  /// No description provided for @abWaivedSnack.
  ///
  /// In en, this message translates to:
  /// **'Invoice waived'**
  String get abWaivedSnack;

  /// No description provided for @abAdjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust amount'**
  String get abAdjust;

  /// No description provided for @abAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust the amount'**
  String get abAdjustTitle;

  /// No description provided for @abAdjustBody.
  ///
  /// In en, this message translates to:
  /// **'A discount lowers the total, a charge raises it. The total must stay above zero.'**
  String get abAdjustBody;

  /// No description provided for @abAdjustDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get abAdjustDiscount;

  /// No description provided for @abAdjustCharge.
  ///
  /// In en, this message translates to:
  /// **'Charge'**
  String get abAdjustCharge;

  /// No description provided for @abAdjustAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get abAdjustAmount;

  /// No description provided for @abAdjustedSnack.
  ///
  /// In en, this message translates to:
  /// **'Invoice adjusted'**
  String get abAdjustedSnack;

  /// No description provided for @abExtend.
  ///
  /// In en, this message translates to:
  /// **'Extend due date'**
  String get abExtend;

  /// No description provided for @abExtendTitle.
  ///
  /// In en, this message translates to:
  /// **'New due date'**
  String get abExtendTitle;

  /// No description provided for @abExtendedSnack.
  ///
  /// In en, this message translates to:
  /// **'Due date extended'**
  String get abExtendedSnack;

  /// No description provided for @abPendingHint.
  ///
  /// In en, this message translates to:
  /// **'A payment is waiting for review.'**
  String get abPendingHint;

  /// No description provided for @abOpenQueue.
  ///
  /// In en, this message translates to:
  /// **'Open the queue'**
  String get abOpenQueue;

  /// No description provided for @abDoctorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get abDoctorsTitle;

  /// No description provided for @abDoctorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} doctors'**
  String abDoctorsSubtitle(int count);

  /// No description provided for @abDoctorsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, email or clinic'**
  String get abDoctorsSearchHint;

  /// No description provided for @abDoctorsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No doctors found'**
  String get abDoctorsEmptyTitle;

  /// No description provided for @abDoctorsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get abDoctorsEmptyBody;

  /// No description provided for @abSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get abSort;

  /// No description provided for @abSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get abSortName;

  /// No description provided for @abSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get abSortNewest;

  /// No description provided for @abSortSessions.
  ///
  /// In en, this message translates to:
  /// **'Most sessions'**
  String get abSortSessions;

  /// No description provided for @abSortOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Most owed'**
  String get abSortOutstanding;

  /// No description provided for @abSessionsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions this month'**
  String abSessionsThisMonth(int count);

  /// No description provided for @abOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Owes'**
  String get abOutstanding;

  /// No description provided for @abDoctorActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get abDoctorActive;

  /// No description provided for @abDoctorPending.
  ///
  /// In en, this message translates to:
  /// **'Pending approval'**
  String get abDoctorPending;

  /// No description provided for @abDoctorSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get abDoctorSuspended;

  /// No description provided for @abDoctorDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get abDoctorDisabled;

  /// No description provided for @abDoctorRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get abDoctorRejected;

  /// No description provided for @abDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get abDoctorTitle;

  /// No description provided for @abTabProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get abTabProfile;

  /// No description provided for @abTabActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get abTabActivity;

  /// No description provided for @abTabInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get abTabInvoices;

  /// No description provided for @abTabPayments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get abTabPayments;

  /// No description provided for @abTabAudit.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get abTabAudit;

  /// No description provided for @abTabBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get abTabBranches;

  /// No description provided for @abTabAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get abTabAppointments;

  /// No description provided for @abTabAssistants.
  ///
  /// In en, this message translates to:
  /// **'Assistants'**
  String get abTabAssistants;

  /// No description provided for @abProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get abProfile;

  /// No description provided for @abFullName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get abFullName;

  /// No description provided for @abSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Specialty'**
  String get abSpecialty;

  /// No description provided for @abEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get abEmail;

  /// No description provided for @abPhone.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get abPhone;

  /// No description provided for @abLicense.
  ///
  /// In en, this message translates to:
  /// **'License number'**
  String get abLicense;

  /// No description provided for @abJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get abJoined;

  /// No description provided for @abStatusReason.
  ///
  /// In en, this message translates to:
  /// **'Status reason'**
  String get abStatusReason;

  /// No description provided for @abReasonBilling.
  ///
  /// In en, this message translates to:
  /// **'Unpaid invoice for {month}'**
  String abReasonBilling(String month);

  /// No description provided for @abActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get abActions;

  /// No description provided for @abSuspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get abSuspend;

  /// No description provided for @abSuspendTitle.
  ///
  /// In en, this message translates to:
  /// **'Suspend this doctor'**
  String get abSuspendTitle;

  /// No description provided for @abSuspendBody.
  ///
  /// In en, this message translates to:
  /// **'The doctor and the assistants can read but not add. A reason is required.'**
  String get abSuspendBody;

  /// No description provided for @abSuspendedSnack.
  ///
  /// In en, this message translates to:
  /// **'Doctor suspended'**
  String get abSuspendedSnack;

  /// No description provided for @abReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get abReactivate;

  /// No description provided for @abReactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Reactivate this doctor'**
  String get abReactivateTitle;

  /// No description provided for @abReactivateBody.
  ///
  /// In en, this message translates to:
  /// **'The clinic works normally again. A reason is required.'**
  String get abReactivateBody;

  /// No description provided for @abReactivatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Doctor reactivated'**
  String get abReactivatedSnack;

  /// No description provided for @abDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable account'**
  String get abDisable;

  /// No description provided for @abDisableTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable this account'**
  String get abDisableTitle;

  /// No description provided for @abDisableBody.
  ///
  /// In en, this message translates to:
  /// **'The doctor and the assistants can\'t sign in, and the bookings from today on are cancelled and the patients told.'**
  String get abDisableBody;

  /// No description provided for @abDisabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Account disabled'**
  String get abDisabledSnack;

  /// No description provided for @abSendReset.
  ///
  /// In en, this message translates to:
  /// **'Send password reset email'**
  String get abSendReset;

  /// No description provided for @abResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Send a password reset email?'**
  String get abResetTitle;

  /// No description provided for @abResetBody.
  ///
  /// In en, this message translates to:
  /// **'The doctor gets an email with a link to set a new password.'**
  String get abResetBody;

  /// No description provided for @abResetSent.
  ///
  /// In en, this message translates to:
  /// **'Email sent'**
  String get abResetSent;

  /// No description provided for @abAddNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get abAddNote;

  /// No description provided for @abNotes.
  ///
  /// In en, this message translates to:
  /// **'Internal notes'**
  String get abNotes;

  /// No description provided for @abNotesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet. Only admins see them.'**
  String get abNotesEmpty;

  /// No description provided for @abNoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Note added'**
  String get abNoteAdded;

  /// No description provided for @abSessionsPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Sessions per month'**
  String get abSessionsPerMonth;

  /// No description provided for @abSessionsOfMonth.
  ///
  /// In en, this message translates to:
  /// **'Sessions in {month}'**
  String abSessionsOfMonth(String month);

  /// No description provided for @abMaskedHint.
  ///
  /// In en, this message translates to:
  /// **'Patient names are masked'**
  String get abMaskedHint;

  /// No description provided for @abNoSessions.
  ///
  /// In en, this message translates to:
  /// **'No sessions this month'**
  String get abNoSessions;

  /// No description provided for @abStatusChanges.
  ///
  /// In en, this message translates to:
  /// **'Status changes'**
  String get abStatusChanges;

  /// No description provided for @abDeletedSessions.
  ///
  /// In en, this message translates to:
  /// **'Deleted sessions'**
  String get abDeletedSessions;

  /// No description provided for @abDeleteReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String abDeleteReason(String reason);

  /// No description provided for @abNothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here'**
  String get abNothingHere;

  /// No description provided for @abAuditSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get abAuditSuspended;

  /// No description provided for @abAuditReactivated.
  ///
  /// In en, this message translates to:
  /// **'Reactivated'**
  String get abAuditReactivated;

  /// No description provided for @abAuditDisabled.
  ///
  /// In en, this message translates to:
  /// **'Account disabled'**
  String get abAuditDisabled;

  /// No description provided for @abAuditServiceActivated.
  ///
  /// In en, this message translates to:
  /// **'Service activated'**
  String get abAuditServiceActivated;

  /// No description provided for @abAuditTrialExtended.
  ///
  /// In en, this message translates to:
  /// **'Trial extended'**
  String get abAuditTrialExtended;

  /// No description provided for @abAuditInvoiceOverdue.
  ///
  /// In en, this message translates to:
  /// **'Invoice became overdue'**
  String get abAuditInvoiceOverdue;

  /// No description provided for @abBranchDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get abBranchDefault;

  /// No description provided for @abAppointmentsCounts.
  ///
  /// In en, this message translates to:
  /// **'Bookings per month'**
  String get abAppointmentsCounts;

  /// No description provided for @abCountsOnly.
  ///
  /// In en, this message translates to:
  /// **'Counts only, no names'**
  String get abCountsOnly;

  /// No description provided for @abAppointmentsLine.
  ///
  /// In en, this message translates to:
  /// **'{bookings} bookings · {noShows} no-shows ({rate}%) · {cancellations} cancelled · {unseen} not seen'**
  String abAppointmentsLine(
    int bookings,
    int noShows,
    int cancellations,
    int rate,
    int unseen,
  );

  /// No description provided for @abNoAssistants.
  ///
  /// In en, this message translates to:
  /// **'No assistants'**
  String get abNoAssistants;

  /// No description provided for @billErrorTooManyScreenshots.
  ///
  /// In en, this message translates to:
  /// **'You can attach at most 3 screenshots'**
  String get billErrorTooManyScreenshots;

  /// No description provided for @abErrorInvoiceStatus.
  ///
  /// In en, this message translates to:
  /// **'This invoice\'s status doesn\'t allow this action. Refresh and check.'**
  String get abErrorInvoiceStatus;

  /// No description provided for @abErrorAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'This payment was already reviewed.'**
  String get abErrorAlreadyReviewed;

  /// No description provided for @abErrorAdjustment.
  ///
  /// In en, this message translates to:
  /// **'The total due must stay above zero. Waive the invoice instead.'**
  String get abErrorAdjustment;

  /// No description provided for @abErrorDueDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a later due date, within a year.'**
  String get abErrorDueDate;

  /// No description provided for @patientFilterUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Has a booking'**
  String get patientFilterUpcoming;

  /// No description provided for @patientFilterNoShows.
  ///
  /// In en, this message translates to:
  /// **'Has no-shows'**
  String get patientFilterNoShows;

  /// No description provided for @patientColumnNextBooking.
  ///
  /// In en, this message translates to:
  /// **'Next booking'**
  String get patientColumnNextBooking;

  /// No description provided for @patientColumnNoShows.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get patientColumnNoShows;

  /// No description provided for @visitsFilterBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get visitsFilterBranch;

  /// No description provided for @visitsNoneInBranch.
  ///
  /// In en, this message translates to:
  /// **'No visits in this branch.'**
  String get visitsNoneInBranch;

  /// No description provided for @filesAnyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get filesAnyDate;

  /// No description provided for @filesDateRange.
  ///
  /// In en, this message translates to:
  /// **'Filter by date'**
  String get filesDateRange;

  /// No description provided for @filesClearDates.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get filesClearDates;

  /// No description provided for @filesNoneInRange.
  ///
  /// In en, this message translates to:
  /// **'No files in these dates.'**
  String get filesNoneInRange;

  /// No description provided for @bookButton.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get bookButton;

  /// No description provided for @chatButton.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatButton;

  /// No description provided for @patientExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get patientExportCsv;

  /// No description provided for @patientExportDone.
  ///
  /// In en, this message translates to:
  /// **'The patient list is exported.'**
  String get patientExportDone;

  /// No description provided for @patientExportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too many patients for one file. Narrow the filters and try again.'**
  String get patientExportTooLarge;

  /// No description provided for @patientColumnUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get patientColumnUnread;

  /// D4: the unread chat badge, for screen readers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread message} other{{count} unread messages}}'**
  String patientUnreadSemantics(int count);

  /// D4 card: the next booking's day.
  ///
  /// In en, this message translates to:
  /// **'Next booking {date}'**
  String patientCardNextBooking(String date);

  /// D4 card and D6: missed bookings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 no-show} other{{count} no-shows}}'**
  String patientCardNoShows(int count);

  /// D4 card and D6: medical files.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String patientCardFiles(int count);

  /// No description provided for @patientTabAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get patientTabAppointments;

  /// No description provided for @patientAppointmentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get patientAppointmentsEmptyTitle;

  /// No description provided for @patientAppointmentsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Book a visit for this patient from here.'**
  String get patientAppointmentsEmptyBody;

  /// No description provided for @patientAppointmentsUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get patientAppointmentsUpcoming;

  /// No description provided for @patientAppointmentsPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get patientAppointmentsPast;

  /// D27: the doctor exported the register as CSV.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Exported the patient list (1 patient)} other{Exported the patient list ({count} patients)}}'**
  String activityPatientsExported(int count);

  /// No description provided for @activityActionPatientsExported.
  ///
  /// In en, this message translates to:
  /// **'Patient list exported'**
  String get activityActionPatientsExported;
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
