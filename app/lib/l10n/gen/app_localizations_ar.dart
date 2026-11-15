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
  String get navLiveShort => 'المباشر';

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
  String get done => 'تم';

  @override
  String get navBadgeNew => 'جديد';

  @override
  String navBadgeUnread(int count) {
    return '$count غير مقروءة';
  }

  @override
  String navItemWithBadge(String label, String badge) {
    return '$label، $badge';
  }

  @override
  String get splashSlow => 'جارٍ الاتصال…';

  @override
  String get languageTitle => 'اختر اللغة';

  @override
  String get languageBody => 'يمكنك تغييرها لاحقاً من الإعدادات.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get continueButton => 'متابعة';

  @override
  String get chooseAccountTitle => 'الدخول كـ';

  @override
  String get chooseAccountBody => 'هذا الرقم له حسابان. اختر أحدهما.';

  @override
  String assistantAtClinic(String doctorName) {
    return 'مساعد في عيادة $doctorName';
  }

  @override
  String get errorSignInAgain =>
      'انتهت مهلة تسجيل الدخول. سجّل الدخول مرة أخرى.';

  @override
  String get errorServer => 'حدثت مشكلة لدينا. حاول مرة أخرى بعد قليل.';

  @override
  String get errorInvalidEmail => 'أدخل بريداً إلكترونياً صحيحاً.';

  @override
  String get errorInvalidMobile => 'أدخل رقم موبايل مصرياً صحيحاً.';

  @override
  String get errorTooLong => 'النص طويل جداً.';

  @override
  String errorRetryInMinutes(int minutes) {
    return 'محاولات كثيرة، حاول بعد $minutes دقيقة.';
  }

  @override
  String get forgotTitle => 'نسيت كلمة المرور';

  @override
  String get forgotBody =>
      'أدخل البريد الإلكتروني أو رقم الموبايل الذي تسجّل الدخول به.';

  @override
  String get forgotSubmit => 'إرسال';

  @override
  String get forgotEmailSentTitle => 'راجع بريدك';

  @override
  String get forgotEmailSentBody =>
      'إذا كان هذا البريد مسجّلاً لدينا فسيصله رابط لتعيين كلمة مرور جديدة. راجع مجلد الرسائل غير المرغوبة أيضاً.';

  @override
  String get forgotPhoneSentTitle => 'تم إرسال الطلب';

  @override
  String get forgotPhoneSentBody =>
      'سيتم إرسال طلب لطبيبك لإعادة تعيين كلمة المرور، وسيعطيك كلمة مرور مؤقتة.';

  @override
  String get backToLogin => 'العودة لتسجيل الدخول';

  @override
  String get setPasswordTitle => 'عيّن كلمة مرور جديدة';

  @override
  String get setPasswordBody =>
      'اختر كلمة مرور لا يعرفها غيرك، وستستخدمها من الآن.';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get passwordRulesTitle => 'كلمة المرور تحتاج إلى';

  @override
  String get passwordRuleLength => '8 أحرف على الأقل';

  @override
  String get passwordRuleLetter => 'حرف';

  @override
  String get passwordRuleNumber => 'رقم';

  @override
  String passwordRuleMet(String rule) {
    return 'تم: $rule';
  }

  @override
  String passwordRuleNotMet(String rule) {
    return 'لم يتحقق بعد: $rule';
  }

  @override
  String get acceptTermsLabel => 'أوافق على الشروط والأحكام وسياسة الخصوصية';

  @override
  String get savePasswordButton => 'حفظ كلمة المرور';

  @override
  String get errorPasswordsDontMatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get errorWeakPassword => 'استخدم 8 أحرف على الأقل تشمل حرفاً ورقماً.';

  @override
  String get errorPasswordSameAsOld => 'اختر كلمة مرور لم تستخدمها هنا من قبل.';

  @override
  String get errorCurrentPasswordIncorrect => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get errorTermsNotAccepted =>
      'وافق على الشروط وسياسة الخصوصية للمتابعة.';

  @override
  String get termsTitle => 'الشروط والأحكام';

  @override
  String get privacyTitle => 'سياسة الخصوصية';

  @override
  String get legalEmpty => 'هذا النص غير متاح بعد.';

  @override
  String legalUpdated(String date) {
    return 'آخر تحديث $date';
  }

  @override
  String get accountDisabledTitle => 'الحساب موقوف';

  @override
  String get accountDisabledBody => 'تم إيقاف حسابك. تواصل مع الدعم.';

  @override
  String get clinicNotActiveTitle => 'حساب العيادة غير مفعّل';

  @override
  String get clinicNotActiveBody => 'حساب العيادة غير مفعّل، تواصل مع الطبيب.';

  @override
  String get supportTitle => 'تواصل مع الدعم';

  @override
  String get supportWhatsapp => 'واتساب';

  @override
  String get supportCall => 'اتصال';

  @override
  String get supportEmail => 'البريد';

  @override
  String get updateTitle => 'يلزم تحديث التطبيق';

  @override
  String get updateBody =>
      'هذا الإصدار من «العيادة» لم يعد مدعوماً. حدّث التطبيق لتواصل استخدامه.';

  @override
  String get updateButton => 'تحديث';

  @override
  String get updateNoLink =>
      'نزّل أحدث إصدار من المكان الذي ثبّتّ منه التطبيق.';

  @override
  String appVersionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get maintenanceTitle => 'سنعود قريباً';

  @override
  String get maintenanceBody =>
      '«العيادة» تحت الصيانة الآن. حاول مرة أخرى بعد قليل.';

  @override
  String get retryButton => 'حاول مرة أخرى';

  @override
  String get adminSignIn => 'دخول الإدارة';

  @override
  String get forgotHaveCode => 'معي رمز';

  @override
  String get resetCodeBody =>
      'أدخل الرمز الموجود في البريد واختر كلمة مرور جديدة.';

  @override
  String get resetCodeLabel => 'الرمز من البريد';

  @override
  String get resetDoneTitle => 'تم تغيير كلمة المرور';

  @override
  String get resetDoneBody =>
      'سجّل الدخول بكلمة المرور الجديدة. تم تسجيل الخروج من الأجهزة الأخرى.';

  @override
  String get errorEmailTokenInvalid =>
      'هذا الرمز غير صحيح. راجعه وحاول مرة أخرى.';

  @override
  String get errorEmailTokenExpired =>
      'انتهت صلاحية هذا الرمز. اطلب بريداً جديداً.';

  @override
  String get errorEmailTokenUsed =>
      'تم استخدام هذا الرمز من قبل. اطلب بريداً جديداً.';

  @override
  String get regTitle => 'تسجيل طبيب';

  @override
  String get regResubmitTitle => 'تعديل الطلب';

  @override
  String get regStepAccount => 'الحساب';

  @override
  String get regStepProfessional => 'البيانات المهنية';

  @override
  String get regStepBranch => 'الفرع الأول';

  @override
  String get regStepReview => 'المراجعة والإرسال';

  @override
  String regStepOf(int step, int count) {
    return 'الخطوة $step من $count';
  }

  @override
  String regStepSemantics(int step, int count, String name) {
    return 'الخطوة $step من $count: $name';
  }

  @override
  String get regNext => 'التالي';

  @override
  String get regBack => 'السابق';

  @override
  String get regSubmit => 'إرسال للمراجعة';

  @override
  String get regResubmit => 'إعادة الإرسال للمراجعة';

  @override
  String get regFixErrors => 'راجع الحقول المحددة.';

  @override
  String get regAccountSection => 'حسابك';

  @override
  String get regAccountIntro => 'ستسجّل الدخول بهذا البريد أو رقم الموبايل.';

  @override
  String get regPasswordSection => 'اختر كلمة مرور';

  @override
  String get regFullNameLabel => 'الاسم بالكامل';

  @override
  String get regFullNameHint => 'كما في كارنيه النقابة، اسمان على الأقل';

  @override
  String get regEmailLabel => 'البريد الإلكتروني';

  @override
  String get regMobileLabel => 'رقم الموبايل';

  @override
  String get regProfessionalSection => 'ممارستك المهنية';

  @override
  String get regTitleLabel => 'اللقب المهني';

  @override
  String get regTitleOther => 'أخرى';

  @override
  String get regTitleOtherLabel => 'اكتب لقبك';

  @override
  String get regSpecialtyLabel => 'التخصص الأساسي';

  @override
  String get regSpecialtyChoose => 'اختر تخصصك';

  @override
  String get regSpecialtyHint => 'ستظهر أدوية تخصصك وتحاليله أولاً عند البحث.';

  @override
  String get regSpecialtiesError => 'تعذّر تحميل التخصصات.';

  @override
  String get regExtraSpecialtiesLabel => 'تخصصات أخرى (اختياري، حتى 2)';

  @override
  String get regExtraSpecialtiesShort => 'تخصصات أخرى';

  @override
  String get regAddSpecialty => 'إضافة تخصص';

  @override
  String regRemoveSpecialty(String name) {
    return 'إزالة $name';
  }

  @override
  String get regSearchHint => 'بحث';

  @override
  String get regClearSearch => 'مسح البحث';

  @override
  String get regNoResults => 'لا توجد نتائج مطابقة.';

  @override
  String get regSyndicateSection => 'نقابة الأطباء';

  @override
  String get regLicenseNumberLabel => 'رقم النقابة';

  @override
  String get regLicenseFileLabel => 'كارنيه النقابة أو ترخيص المزاولة';

  @override
  String get regLicenseFileShort => 'كارنيه النقابة';

  @override
  String get regLicenseFileHint => 'صورة واضحة أو ملف PDF، حتى 10 ميجا';

  @override
  String get regLicenseReplace => 'تغيير';

  @override
  String get regLicenseUndo => 'الإبقاء على الملف الحالي';

  @override
  String get regLicenseCurrent => 'الملف الحالي';

  @override
  String get regLicenseKept => 'يبقى ما لم تغيّره';

  @override
  String get regLicenseImage => 'صورة';

  @override
  String get regLicensePdf => 'PDF';

  @override
  String get regLicenseOpen => 'فتح صورة كارنيه النقابة';

  @override
  String get regSourceCamera => 'التقاط صورة';

  @override
  String get regSourceGallery => 'اختيار من الصور';

  @override
  String get regSourceFiles => 'اختيار ملف (صورة أو PDF)';

  @override
  String regFileSizeKb(int size) {
    return '$size كيلوبايت';
  }

  @override
  String regFileSizeMb(String size) {
    return '$size ميجا';
  }

  @override
  String get regBranchSection => 'بيانات الفرع';

  @override
  String get regBranchIntro =>
      'سيظهر هذا الفرع للمرضى، ويمكنك إضافة فروع أخرى بعد تفعيل الحساب.';

  @override
  String get regBranchNameLabel => 'اسم الفرع';

  @override
  String get regBranchNameHint => 'مثال: فرع المعادي';

  @override
  String get regGovernorateLabel => 'المحافظة';

  @override
  String get regGovernorateChoose => 'اختر المحافظة';

  @override
  String get regCityLabel => 'المدينة أو الحي';

  @override
  String get regStreetLabel => 'الشارع والعنوان';

  @override
  String get regBuildingLabel => 'العمارة';

  @override
  String get regFloorLabel => 'الدور';

  @override
  String get regApartmentLabel => 'الشقة';

  @override
  String get regLandmarkLabel => 'علامة مميزة (اختياري)';

  @override
  String get regLandmarkHint => 'مثال: بجوار محطة المترو';

  @override
  String get regPhonesSection => 'أرقام تليفون العيادة';

  @override
  String get regPhonesHint =>
      'من رقم واحد إلى 5 أرقام: موبايل أو أرضي أو خط ساخن.';

  @override
  String regPhoneLabel(int index) {
    return 'الرقم $index';
  }

  @override
  String get regPhoneType => 'نوع الرقم';

  @override
  String get regPhoneTypeReception => 'الاستقبال';

  @override
  String get regPhoneTypeMobile => 'موبايل';

  @override
  String get regPhoneTypeLandline => 'أرضي';

  @override
  String get regPhoneWhatsapp => 'واتساب';

  @override
  String get regAddPhone => 'إضافة رقم';

  @override
  String get regRemovePhone => 'حذف هذا الرقم';

  @override
  String get regPricesSection => 'أسعار الكشف والاستشارة (اختياري)';

  @override
  String get regPricesHint =>
      'يرى المرضى هذه الأسعار، ويمكنك تغييرها لاحقاً من الإعدادات.';

  @override
  String get regExaminationPrice => 'الكشف';

  @override
  String get regConsultationPrice => 'الاستشارة';

  @override
  String get regCurrency => 'ج.م';

  @override
  String regPriceValue(String amount) {
    return '$amount ج.م';
  }

  @override
  String get regReviewIntro => 'راجع بياناتك، ثم أرسلها للمراجعة.';

  @override
  String get regReviewIntroResubmit =>
      'راجع تعديلاتك، ثم أعد إرسالها للمراجعة.';

  @override
  String get regEdit => 'تعديل';

  @override
  String regEditSection(String section) {
    return 'تعديل $section';
  }

  @override
  String get regNotSet => 'غير محدد';

  @override
  String get regAddressLabel => 'العنوان';

  @override
  String get regLandmarkShort => 'علامة مميزة';

  @override
  String get regPhonesLabel => 'أرقام التليفون';

  @override
  String regBuildingValue(String value) {
    return 'عمارة $value';
  }

  @override
  String regFloorValue(String value) {
    return 'الدور $value';
  }

  @override
  String regApartmentValue(String value) {
    return 'شقة $value';
  }

  @override
  String get regListSeparator => '، ';

  @override
  String get regErrorInvalidName =>
      'اكتب الاسم ثنائياً على الأقل، بالحروف فقط.';

  @override
  String get regErrorEmailTaken =>
      'يوجد حساب بهذا البريد. سجّل الدخول أو استخدم بريداً آخر.';

  @override
  String get regErrorTitleRequired => 'اختر لقبك أو اكتبه.';

  @override
  String get regErrorSpecialtyRequired => 'اختر تخصصك.';

  @override
  String get regErrorInvalidSpecialty => 'اختر تخصصاً من القائمة.';

  @override
  String get regErrorLicenseNumberRequired => 'رقم النقابة مطلوب.';

  @override
  String get regErrorInvalidLicenseNumber =>
      'أدخل رقم النقابة: من 3 إلى 20 حرفاً أو رقماً.';

  @override
  String get regErrorLicenseRequired => 'أضف صورة كارنيه النقابة أو الترخيص.';

  @override
  String get regErrorFileTooLarge =>
      'حجم الملف أكبر من 10 ميجا. اختر ملفاً أصغر.';

  @override
  String get regErrorFileType =>
      'استخدم صورة (JPEG أو PNG أو WebP) أو ملف PDF.';

  @override
  String get regErrorFileContent => 'تعذّرت قراءة هذا الملف. جرّب ملفاً آخر.';

  @override
  String get regErrorPickFailed =>
      'تعذّر الفتح. تحقق من أذونات التطبيق ثم حاول مرة أخرى.';

  @override
  String get regErrorGovernorateRequired => 'اختر المحافظة.';

  @override
  String get regErrorBranchName => 'استخدم من 2 إلى 60 حرفاً.';

  @override
  String get regErrorInvalidPhone =>
      'أدخل رقماً مصرياً صحيحاً: موبايل أو أرضي أو خط ساخن.';

  @override
  String get regErrorPhoneRequired => 'أضف رقم تليفون واحداً على الأقل.';

  @override
  String get regErrorPrice =>
      'قيمة غير صحيحة. أدخل مبلغاً من 0 إلى 100,000 برقمين عشريين على الأكثر.';

  @override
  String get regErrorInvalidValue => 'قيمة غير صحيحة.';

  @override
  String get regErrorNotEditable => 'لا يمكن تعديل هذا الطلب الآن.';

  @override
  String get regErrorResendCooldown => 'انتظر دقيقة قبل إرسال بريد آخر.';

  @override
  String get regPendingTitle => 'حسابك قيد المراجعة';

  @override
  String get regPendingBody => 'سيصلك إشعار فور تفعيله.';

  @override
  String get regRefresh => 'تحديث';

  @override
  String get regStillPending =>
      'ما زال طلبك قيد المراجعة، وسنرسل لك إشعاراً فور تفعيله.';

  @override
  String get regSubmittedData => 'البيانات المرسلة';

  @override
  String regSubmittedOn(String date) {
    return 'أُرسلت في $date';
  }

  @override
  String get regDataError => 'تعذّر تحميل بياناتك.';

  @override
  String get regVerifyCardTitle => 'أكّد بريدك الإلكتروني';

  @override
  String regVerifyCardBody(String email) {
    return 'أرسلنا رابطاً إلى $email.';
  }

  @override
  String get regRejectedTitle => 'لم تتم الموافقة على طلبك';

  @override
  String get regRejectedBody =>
      'عدّل ما طلبه فريق المراجعة، ثم أرسل طلبك مرة أخرى.';

  @override
  String get regRejectedReason => 'سبب الرفض';

  @override
  String get regRejectedNoReason =>
      'لم يُذكر سبب. تواصل مع الدعم لمعرفة المزيد.';

  @override
  String get regEditAndResubmit => 'تعديل وإعادة الإرسال';

  @override
  String get regVerifyTitle => 'أكّد بريدك الإلكتروني';

  @override
  String get regVerifySentTo => 'أرسلنا رابط التأكيد إلى';

  @override
  String get regVerifyBody =>
      'افتح الرابط الموجود في البريد. إذا فُتح في المتصفح بدلاً من التطبيق، فانسخ الرمز من البريد والصقه هنا.';

  @override
  String get regVerifyButton => 'تأكيد';

  @override
  String get regVerifiedCheck => 'أكّدت بريدي';

  @override
  String get regResend => 'إعادة إرسال البريد';

  @override
  String regResendIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ث';
  }

  @override
  String get regResent =>
      'تم الإرسال. راجع البريد الوارد ومجلد الرسائل غير المرغوبة.';

  @override
  String get regNotVerifiedYet =>
      'لم يتم التأكيد بعد. افتح الرابط في البريد ثم حاول مرة أخرى.';

  @override
  String get regVerifiedTitle => 'تم تأكيد البريد';

  @override
  String get regVerifiedBody => 'شكراً لك، تم تأكيد بريدك الإلكتروني.';
}
