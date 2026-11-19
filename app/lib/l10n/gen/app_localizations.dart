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

  /// No description provided for @rxKindMedication.
  ///
  /// In en, this message translates to:
  /// **'Medication prescription'**
  String get rxKindMedication;

  /// No description provided for @rxKindInvestigations.
  ///
  /// In en, this message translates to:
  /// **'Lab & radiology request'**
  String get rxKindInvestigations;

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

  /// No description provided for @rxAdvice.
  ///
  /// In en, this message translates to:
  /// **'Advice'**
  String get rxAdvice;

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
