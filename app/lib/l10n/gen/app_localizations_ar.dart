// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'العيادة';

  @override
  String get appTagline => 'عيادتك منظمة.';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get identifierLabel => 'رقم الموبايل أو البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get signInButton => 'دخول';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get registerAsDoctor => 'تسجيل كطبيب';

  @override
  String get comingSoon => 'قريباً';

  @override
  String get errorRequired => 'هذا الحقل مطلوب';

  @override
  String get errorInvalidIdentifier =>
      'أدخل رقم موبايل مصري أو بريداً إلكترونياً صحيحاً';

  @override
  String get errorInvalidCredentials =>
      'رقم الهاتف/البريد أو كلمة المرور غير صحيحة';

  @override
  String get errorTooManyAttempts => 'محاولات كثيرة، حاول لاحقاً';

  @override
  String get errorNoInternet => 'لا يوجد اتصال بالإنترنت';

  @override
  String get errorUnknown => 'حدث خطأ غير متوقع، حاول مرة أخرى';

  @override
  String get patientDesktopTitle => 'حساب المريض على تطبيق الموبايل فقط';

  @override
  String get patientDesktopBody =>
      'تطبيق الكمبيوتر مخصص للأطباء والمساعدين والإدارة. حمّل تطبيق «العيادة» على موبايلك لمتابعة ملفك الطبي وحجوزاتك.';

  @override
  String get ok => 'حسناً';

  @override
  String get underConstructionTitle => 'هذه الشاشة لم تُنفذ بعد';

  @override
  String underConstructionBody(String screenId) {
    return 'الشاشة $screenId في spec.md';
  }

  @override
  String get switchLanguage => 'تغيير اللغة';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeSystem => 'تلقائي';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get devAccountsTitle => 'حسابات تجريبية (للتطوير فقط)';

  @override
  String get devAccountsBody =>
      'اضغط على حساب لملء البيانات. أي كلمة مرور تنفع ما عدا \"wrong\".';

  @override
  String get roleAdmin => 'الإدارة';

  @override
  String get roleDoctor => 'الطبيب';

  @override
  String get roleAssistant => 'مساعد الطبيب';

  @override
  String get rolePatient => 'المريض';

  @override
  String get navLive => 'اللوحة المباشرة';

  @override
  String get navDashboard => 'لوحة التحكم';

  @override
  String get navRevenue => 'الإيرادات';

  @override
  String get navAppointments => 'الحجوزات';

  @override
  String get navPatients => 'المرضى';

  @override
  String get navChats => 'المحادثات';

  @override
  String get navBilling => 'الفواتير';

  @override
  String get navBranches => 'الفروع';

  @override
  String get navAssistants => 'المساعدون';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get navMore => 'المزيد';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navMedicalFile => 'الملف الطبي';

  @override
  String get navAccount => 'الحساب';

  @override
  String get navDoctors => 'الأطباء';

  @override
  String get navPayments => 'المدفوعات';

  @override
  String get navInvoices => 'الفواتير';

  @override
  String get navSignups => 'طلبات التسجيل';

  @override
  String get navAccounts => 'الحسابات';

  @override
  String get navCatalogs => 'القوائم الطبية';

  @override
  String get navSpecialties => 'التخصصات';

  @override
  String get navAdmins => 'المسؤولون';

  @override
  String get navAuditLog => 'سجل العمليات';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get errorNotFound => 'هذا العنصر غير متاح.';

  @override
  String get errorForbidden => 'ليس لديك صلاحية للوصول إلى هذا.';

  @override
  String get errorDeletionAlreadyRequested =>
      'لديك طلب حذف قيد المراجعة بالفعل.';

  @override
  String get couldNotOpen => 'تعذّر الفتح على هذا الجهاز';

  @override
  String get newBadge => 'جديد';

  @override
  String get allDoctors => 'الكل';

  @override
  String homeGreeting(String name) {
    return 'أهلاً، $name';
  }

  @override
  String homeNewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر جديد في ملفك',
      few: '$count عناصر جديدة في ملفك',
      two: 'عنصران جديدان في ملفك',
      one: 'عنصر جديد في ملفك',
    );
    return '$_temp0';
  }

  @override
  String get homeLatestVisit => 'آخر زيارة';

  @override
  String get homeLatestPrescription => 'آخر روشتة';

  @override
  String get homeNextFollowUp => 'موعد المتابعة القادم';

  @override
  String followUpWith(String date, String doctor) {
    return '$date مع $doctor';
  }

  @override
  String get homeRecentFiles => 'أحدث الملفات';

  @override
  String get homeEmpty =>
      'ملفك الطبي فارغ حالياً. ستظهر هنا الزيارات والروشتات والملفات التي يضيفها طبيبك.';

  @override
  String get myDoctorsTitle => 'أطبائي';

  @override
  String get myDoctorTitle => 'طبيبي';

  @override
  String get noDoctors => 'لم يتم ربطك بأي طبيب بعد.';

  @override
  String get medicalProfileTitle => 'الملف الصحي';

  @override
  String fileNumber(int number) {
    return 'ملف رقم $number';
  }

  @override
  String get thisDoctorsRecords => 'سجلاتي عند هذا الطبيب';

  @override
  String get branchesTitle => 'الفروع';

  @override
  String get noBranches => 'لا توجد بيانات للفروع بعد. تواصل مع العيادة.';

  @override
  String get mainBranch => 'الرئيسي';

  @override
  String get branchTemporarilyClosed => 'مغلق مؤقتاً';

  @override
  String reopensOn(String date) {
    return 'يعاود العمل يوم $date';
  }

  @override
  String get openInMaps => 'افتح في الخرائط';

  @override
  String get call => 'اتصال';

  @override
  String get whatsApp => 'واتساب';

  @override
  String get phoneReception => 'الاستقبال';

  @override
  String get phoneMobile => 'موبايل';

  @override
  String get phoneLandline => 'تليفون أرضي';

  @override
  String get workingHours => 'مواعيد العمل';

  @override
  String get workingHoursNotSet => 'استفسر من العيادة عن المواعيد.';

  @override
  String get closedDay => 'مغلق';

  @override
  String timeRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get visitPrices => 'أسعار الكشف والاستشارة';

  @override
  String get priceAskClinic => 'يُرجى الاستفسار من العيادة';

  @override
  String moneyEgp(String amount) {
    return '$amount ج.م';
  }

  @override
  String get paymentCash => 'نقداً';

  @override
  String get paymentCard => 'بطاقة';

  @override
  String get paymentInstapay => 'إنستاباي';

  @override
  String get paymentWallet => 'محفظة إلكترونية';

  @override
  String get amenityElevator => 'مصعد';

  @override
  String get amenityParking => 'موقف سيارات';

  @override
  String get amenityWheelchair => 'مناسب للكراسي المتحركة';

  @override
  String get amenityKidsArea => 'ركن للأطفال';

  @override
  String get tabVisits => 'الزيارات';

  @override
  String get tabPrescriptions => 'الروشتات';

  @override
  String get tabFiles => 'الملفات';

  @override
  String get noVisits => 'لا توجد زيارات بعد.';

  @override
  String get noPrescriptions => 'لا توجد روشتات بعد.';

  @override
  String get noFiles => 'لا توجد ملفات في هذا القسم.';

  @override
  String get visitTypeExamination => 'كشف';

  @override
  String get visitTypeConsultation => 'استشارة';

  @override
  String get visitDetailsTitle => 'تفاصيل الزيارة';

  @override
  String get diagnosis => 'التشخيص';

  @override
  String get chiefComplaint => 'الشكوى';

  @override
  String get findings => 'نتيجة الفحص';

  @override
  String get vitals => 'العلامات الحيوية';

  @override
  String get vitalBloodPressure => 'ضغط الدم';

  @override
  String get vitalPulse => 'النبض';

  @override
  String get vitalTemperature => 'الحرارة';

  @override
  String get vitalWeight => 'الوزن';

  @override
  String get vitalHeight => 'الطول';

  @override
  String get vitalGlucose => 'السكر';

  @override
  String get doctorNotesForYou => 'ملاحظات الطبيب لك';

  @override
  String get followUpDate => 'موعد المتابعة';

  @override
  String get rxTabMedications => 'العلاج';

  @override
  String get rxTabInvestigations => 'التحاليل والأشعة';

  @override
  String get rxKindMedication => 'روشتة علاج';

  @override
  String get rxKindInvestigations => 'روشتة تحاليل وأشعة';

  @override
  String get statusCancelled => 'ملغاة';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String get rxCancelledTitle => 'تم إلغاء هذه الروشتة';

  @override
  String reasonValue(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get rxOpenNewCopy => 'افتح النسخة الجديدة';

  @override
  String rxSentOn(String date) {
    return 'أُرسلت يوم $date';
  }

  @override
  String get rxAdvice => 'نصائح الطبيب';

  @override
  String get viewPdf => 'عرض PDF';

  @override
  String get shareOrSave => 'مشاركة أو حفظ';

  @override
  String doseAmountForm(String dose, String form) {
    return '$dose $form';
  }

  @override
  String get formTablet => 'قرص';

  @override
  String get formCapsule => 'كبسولة';

  @override
  String get formSyrup => 'شراب';

  @override
  String get formInjection => 'حقنة';

  @override
  String get formCream => 'كريم / مرهم';

  @override
  String get formDrops => 'نقط';

  @override
  String get formInhaler => 'بخاخ';

  @override
  String get formSuppository => 'لبوس';

  @override
  String get formSachet => 'كيس';

  @override
  String get formOther => 'أخرى';

  @override
  String get timingBeforeFood => 'قبل الأكل';

  @override
  String get timingAfterFood => 'بعد الأكل';

  @override
  String get timingWithFood => 'مع الأكل';

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لمدة $count يوم',
      few: 'لمدة $count أيام',
      two: 'لمدة يومين',
      one: 'لمدة يوم',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لمدة $count أسبوع',
      few: 'لمدة $count أسابيع',
      two: 'لمدة أسبوعين',
      one: 'لمدة أسبوع',
    );
    return '$_temp0';
  }

  @override
  String get durationContinuous => 'مستمر';

  @override
  String get investigationLab => 'تحليل';

  @override
  String get investigationRadiology => 'أشعة';

  @override
  String get fileCategoryPrescription => 'روشتات';

  @override
  String get fileCategoryLab => 'تحاليل';

  @override
  String get fileCategoryRadiology => 'أشعة';

  @override
  String get fileCategoryOther => 'أخرى';

  @override
  String get otherTypeReport => 'تقرير طبي';

  @override
  String get otherTypeReferral => 'تحويل';

  @override
  String get otherTypeSickLeave => 'إجازة مرضية';

  @override
  String get otherTypeEcg => 'رسم قلب';

  @override
  String get otherTypeEegEmg => 'رسم مخ / عضلات';

  @override
  String get otherTypeEndoscopy => 'منظار';

  @override
  String get otherTypeConsent => 'إقرار';

  @override
  String get fileDetails => 'بيانات الملف';

  @override
  String get fileTitle => 'العنوان';

  @override
  String get fileCategory => 'النوع';

  @override
  String get documentDate => 'تاريخ المستند';

  @override
  String get doctor => 'الطبيب';

  @override
  String get notes => 'ملاحظات';

  @override
  String get noAttachments => 'لا توجد مرفقات في هذا الملف.';

  @override
  String cannotPreview(String fileName) {
    return 'لا يمكن عرض $fileName هنا. استخدم المشاركة لفتحه بتطبيق آخر.';
  }

  @override
  String pageOf(int current, int total) {
    return '$current من $total';
  }

  @override
  String get personalInfo => 'البيانات الشخصية';

  @override
  String get fullName => 'الاسم بالكامل';

  @override
  String get mobileNumber => 'رقم الموبايل';

  @override
  String get gender => 'النوع';

  @override
  String get genderMale => 'ذكر';

  @override
  String get genderFemale => 'أنثى';

  @override
  String get age => 'السن';

  @override
  String ageYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years سنة',
      few: '$years سنوات',
      two: 'سنتان',
      one: 'سنة واحدة',
      zero: 'أقل من سنة',
    );
    return '$_temp0';
  }

  @override
  String get bloodType => 'فصيلة الدم';

  @override
  String get allergies => 'الحساسية';

  @override
  String get chronicDiseases => 'الأمراض المزمنة';

  @override
  String get currentMedications => 'الأدوية الحالية';

  @override
  String get surgeries => 'العمليات السابقة';

  @override
  String get familyHistory => 'التاريخ المرضي للعائلة';

  @override
  String get medicalProfileEmpty => 'لم يُسجَّل شيء بعد.';

  @override
  String get medicalProfileReadOnly => 'لتحديث هذه البيانات، تواصل مع طبيبك.';

  @override
  String get settingsGeneral => 'عام';

  @override
  String get language => 'اللغة';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notifyChat => 'رسائل المحادثة';

  @override
  String get notifyReminders => 'تذكير بالمواعيد';

  @override
  String get notifyShowPreview => 'إظهار نص الرسالة في الإشعارات';

  @override
  String get notifyShowPreviewHint =>
      'إيقافه يحافظ على خصوصية رسائلك على شاشة القفل.';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get requestAccountDeletion => 'طلب حذف الحساب';

  @override
  String get deletionConfirmBody =>
      'سيتم إرسال طلبك لفريق «العيادة». بعد الموافقة لن تتمكن من تسجيل الدخول. يحتفظ أطباؤك بالسجلات الطبية الملزمين بحفظها.';

  @override
  String get deletionReasonLabel => 'السبب (اختياري)';

  @override
  String get deletionConfirmButton => 'إرسال الطلب';

  @override
  String get deletionRequestSent => 'تم إرسال طلبك وسنراجعه قريباً.';

  @override
  String get deletionPendingTitle => 'طلب الحذف قيد المراجعة';

  @override
  String deletionPendingBody(String date) {
    return 'أُرسل يوم $date';
  }

  @override
  String deletionRejected(String note) {
    return 'تم رفض طلبك السابق: $note';
  }

  @override
  String get termsGateTitle => 'قبل أن تبدأ';

  @override
  String get termsGateBody =>
      'يحافظ تطبيق «العيادة» على ملفك الطبي ولا يشاركه إلا مع أطبائك. برجاء قراءة شروط الاستخدام وسياسة الخصوصية والموافقة عليها للمتابعة.';

  @override
  String get termsGateCheckbox =>
      'قرأت شروط الاستخدام وسياسة الخصوصية وأوافق عليها';

  @override
  String get termsGateContinue => 'متابعة';

  @override
  String get navDeletionRequests => 'طلبات حذف الحسابات';

  @override
  String get statusPending => 'قيد المراجعة';

  @override
  String get statusApproved => 'مقبولة';

  @override
  String get statusRejected => 'مرفوضة';

  @override
  String get noDeletionRequests => 'لا توجد طلبات هنا.';

  @override
  String get approve => 'موافقة';

  @override
  String get reject => 'رفض';

  @override
  String get approveDeletionTitle => 'الموافقة على الحذف؟';

  @override
  String get approveDeletionBody =>
      'سيتم تسجيل خروج المريض من كل الأجهزة ولن يتمكن من الدخول مرة أخرى. تبقى السجلات الطبية لدى أطبائه.';

  @override
  String get rejectDeletionTitle => 'رفض الطلب';

  @override
  String get reasonRequiredLabel => 'السبب (يظهر للمريض)';

  @override
  String get errorInvalidPhone => 'رقم الموبايل غير صحيح';

  @override
  String get search => 'بحث';

  @override
  String get accountsSupportHint =>
      'البحث برقم الموبايل فقط. تظهر حسابات المرضى والمساعدين بدون أي بيانات طبية.';

  @override
  String get noAccountsFound => 'لا يوجد حساب بهذا الرقم.';

  @override
  String get accountDeleted => 'تم حذف الحساب بناءً على طلب المريض';

  @override
  String linkedDoctors(String names) {
    return 'الأطباء: $names';
  }

  @override
  String createdOn(String date) {
    return 'أُنشئ يوم $date';
  }

  @override
  String assistantOf(String doctor) {
    return 'مساعد $doctor';
  }

  @override
  String lastActive(String time) {
    return 'آخر نشاط $time';
  }

  @override
  String get loginEnabled => 'الدخول مفعّل';

  @override
  String get loginDisabled => 'الدخول موقوف';

  @override
  String get markAllRead => 'تحديد الكل كمقروء';

  @override
  String get noNotifications => 'لا توجد إشعارات بعد.';

  @override
  String get searchChats => 'ابحث بالاسم أو رقم الموبايل';

  @override
  String get noChats => 'لا توجد محادثات بعد.';

  @override
  String get chatImage => 'صورة';

  @override
  String get chatFile => 'ملف';

  @override
  String get chatNoMessages => 'لا توجد رسائل بعد';

  @override
  String get chatDoctorUnavailable => 'الطبيب غير متاح حالياً';

  @override
  String get chatSuspended => 'الإرسال متوقف أثناء إيقاف الخدمة.';

  @override
  String get fileTooLarge => 'حجم الملف أكبر من المسموح';

  @override
  String get chatCamera => 'الكاميرا';

  @override
  String get chatGallery => 'معرض الصور';

  @override
  String get chatFileOption => 'ملف';

  @override
  String get saveToPatientFile => 'حفظ في ملف المريض';

  @override
  String get savedToPatientFile => 'تم الحفظ في ملف المريض';

  @override
  String get chatStart => 'ابدأ المحادثة.';

  @override
  String get chatAttach => 'إرفاق';

  @override
  String get chatTypeMessage => 'اكتب رسالة';

  @override
  String get chatSend => 'إرسال';

  @override
  String clinicAssistant(String name) {
    return 'مساعد العيادة — $name';
  }

  @override
  String get chatRead => 'مقروءة';

  @override
  String get chatDelivered => 'تم التوصيل';

  @override
  String get chooseCategory => 'اختر نوع الملف';
}
