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
