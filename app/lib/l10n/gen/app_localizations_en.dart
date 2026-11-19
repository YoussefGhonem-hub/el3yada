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
  String get rxKindMedication => 'Medication prescription';

  @override
  String get rxKindInvestigations => 'Lab & radiology request';

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
  String get rxAdvice => 'Advice';

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
}
