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
  String get loginWelcome => 'أهلاً بعودتك';

  @override
  String get loginWelcomeBody => 'سجّل دخولك للمتابعة.';

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
  String get navSignups => 'الأطباء';

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
  String get regSubmit => 'إنشاء الحساب';

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
  String get addressDetailsLabel => 'العنوان بالتفصيل';

  @override
  String get addressDetailsHint =>
      'مثال: 12 شارع 9، عمارة النور، الدور التالت، شقة 5';

  @override
  String get mapLinkLabel => 'لينك جوجل ماب (اختياري)';

  @override
  String get mapLinkHelp =>
      'افتح مكان العيادة في جوجل ماب، واضغط «مشاركة» ثم «نسخ الرابط»، والصقه هنا.';

  @override
  String get mapLinkShort => 'جوجل ماب';

  @override
  String get mapLinkOpen => 'افتح في جوجل ماب';

  @override
  String get mapLinkClear => 'إزالة اللينك';

  @override
  String get mapLinkInvalid => 'ده مش لينك جوجل ماب.';

  @override
  String get mapLinkOpenFailed => 'تعذّر فتح جوجل ماب على هذا الجهاز.';

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
  String get regReviewIntro => 'راجع بياناتك، ثم أنشئ حسابك.';

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
  String get regListSeparator => '، ';

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

  @override
  String get adminMyProfile => 'ملفي الشخصي';

  @override
  String get adminCancel => 'إلغاء';

  @override
  String get adminClose => 'إغلاق';

  @override
  String get adminSave => 'حفظ';

  @override
  String get adminRefresh => 'تحديث';

  @override
  String get adminRefreshFailed => 'تعذّر التحديث، وتظهر آخر قائمة.';

  @override
  String get adminListSeparator => '، ';

  @override
  String get adminNotProvided => 'غير مذكور';

  @override
  String get adminSystem => 'النظام';

  @override
  String get adminUnknownUser => 'مستخدم غير معروف';

  @override
  String get adminNew => 'جديد';

  @override
  String adminDoctorName(String name) {
    return 'د. $name';
  }

  @override
  String get adminJustNow => 'الآن';

  @override
  String adminMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String adminHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
    );
    return '$_temp0';
  }

  @override
  String adminDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوماً',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String adminMoneyEgp(String amount) {
    return '$amount ج.م';
  }

  @override
  String get adminCurrency => 'ج.م';

  @override
  String get adminUnitDays => 'يوم';

  @override
  String get adminUnitMb => 'ميجابايت';

  @override
  String get adminStatusPending => 'في انتظار المراجعة';

  @override
  String get adminStatusActive => 'نشط';

  @override
  String get adminStatusRejected => 'مرفوض';

  @override
  String get adminStatusSuspended => 'موقوف';

  @override
  String get adminStatusDisabled => 'معطّل';

  @override
  String get adminRoleAdmin => 'مسؤول';

  @override
  String get adminRoleSuperAdmin => 'مسؤول رئيسي';

  @override
  String get adminEmptyValue => '(فارغ)';

  @override
  String get adminOn => 'مفعّل';

  @override
  String get adminOff => 'متوقف';

  @override
  String get adminErrorOutOfRange => 'القيمة خارج النطاق المسموح.';

  @override
  String get adminErrorInvalidValue => 'قيمة غير صحيحة.';

  @override
  String get adminErrorInvalidVersion => 'اكتب الإصدار بالشكل 1.2.3.';

  @override
  String get adminErrorUnknownSetting =>
      'هذا الإعداد لم يعد موجوداً. حدّث التطبيق.';

  @override
  String get adminErrorInvalidName =>
      'اكتب الاسم ثنائياً على الأقل، بالحروف فقط.';

  @override
  String get adminErrorReasonRequired => 'اكتب سبب الرفض (3 أحرف على الأقل).';

  @override
  String get adminErrorRegistrationNotPending =>
      'تمت مراجعة هذا الطلب بالفعل، ربما بواسطة مسؤول آخر.';

  @override
  String get adminErrorEmailTaken => 'يوجد حساب بهذا البريد الإلكتروني بالفعل.';

  @override
  String get adminErrorLicenseMissing =>
      'ملف كارنيه النقابة غير موجود على الخادم. اطلب من الطبيب رفعه مرة أخرى.';

  @override
  String get adminErrorOwnRole => 'لا يمكنك تغيير دورك بنفسك.';

  @override
  String get adminErrorDisableSelf => 'لا يمكنك تعطيل حسابك بنفسك.';

  @override
  String get adminErrorLastSuperAdmin =>
      'يجب أن يبقى مسؤول رئيسي نشط واحد على الأقل.';

  @override
  String get adminErrorNotFound => 'هذا العنصر لم يعد موجوداً.';

  @override
  String get adminErrorForbidden => 'ليست لديك صلاحية لهذا الإجراء.';

  @override
  String get adminErrorAmount => 'أدخل مبلغاً بالجنيه، بحد أقصى رقمين عشريين.';

  @override
  String get adminErrorWholeNumber => 'أدخل رقماً صحيحاً.';

  @override
  String adminErrorRange(String min, String max) {
    return 'أدخل قيمة من $min إلى $max.';
  }

  @override
  String adminErrorMaxLength(String max) {
    return 'الحد الأقصى $max حرف.';
  }

  @override
  String get adminErrorInvalidPhone =>
      'أدخل رقم موبايل أو أرضي أو خطاً ساخناً صحيحاً.';

  @override
  String get adminErrorInvalidWhatsapp =>
      'أدخل رقم موبايل صحيحاً (الأرقام الدولية تبدأ بـ +).';

  @override
  String get adminFixErrors => 'صحّح الحقول المحددة ثم احفظ.';

  @override
  String get adminSignupsSearchHint => 'ابحث بالاسم أو البريد أو الرقم';

  @override
  String get adminClearSearch => 'مسح البحث';

  @override
  String get adminSort => 'الترتيب';

  @override
  String get adminSortNewest => 'الأحدث أولاً';

  @override
  String get adminSortOldest => 'الأقدم أولاً (حسب الدور)';

  @override
  String get adminSignupsEmptyTitle => 'لا يوجد أطباء بعد';

  @override
  String get adminSignupsEmptyBody => 'يظهر الأطباء هنا فور تسجيلهم.';

  @override
  String get adminSignupsNoMatchTitle => 'لا يوجد أطباء يطابقون البحث';

  @override
  String get adminSignupsNoMatchBody =>
      'راجع الكتابة، أو ابحث برقم الموبايل أو رقم النقابة.';

  @override
  String get adminSelectRequest => 'اختر طبيباً لعرض حسابه';

  @override
  String adminSubmittedShort(String time) {
    return 'أُرسل $time';
  }

  @override
  String get adminReviewTitle => 'طلب تسجيل';

  @override
  String adminSubmittedAt(String relative, String date) {
    return 'أُرسل $relative · $date';
  }

  @override
  String get adminResubmitted => 'أُعيد إرساله';

  @override
  String get adminEmailNotVerified => 'البريد غير مؤكد';

  @override
  String get adminEmailVerified => 'مؤكد';

  @override
  String get adminPreviousRejection => 'سبب الرفض السابق';

  @override
  String get adminSectionAccount => 'الحساب';

  @override
  String get adminSectionProfessional => 'البيانات المهنية';

  @override
  String get adminSectionBranch => 'العيادة (الفرع الأول)';

  @override
  String get adminSectionPrices => 'أسعار الكشف والاستشارة';

  @override
  String get adminSectionReviews => 'المراجعات السابقة';

  @override
  String get adminFieldFullName => 'الاسم بالكامل';

  @override
  String get adminFieldFullNameEn => 'الاسم بالإنجليزية';

  @override
  String get adminFieldEmail => 'البريد الإلكتروني';

  @override
  String get adminFieldMobile => 'الموبايل';

  @override
  String get adminFieldLanguage => 'اللغة';

  @override
  String get adminFieldTitle => 'اللقب';

  @override
  String get adminFieldTitleEn => 'اللقب بالإنجليزية';

  @override
  String get adminFieldSpecialty => 'التخصص';

  @override
  String get adminFieldExtraSpecialties => 'تخصصات إضافية';

  @override
  String get adminFieldLicenseNumber => 'رقم النقابة';

  @override
  String get adminFieldDegreesAr => 'المؤهلات (عربي)';

  @override
  String get adminFieldDegreesEn => 'المؤهلات (إنجليزي)';

  @override
  String get adminFieldBranchName => 'اسم الفرع';

  @override
  String get adminFieldBranchNameEn => 'اسم الفرع بالإنجليزية';

  @override
  String get adminFieldAddress => 'العنوان';

  @override
  String get adminFieldLandmark => 'علامة مميزة';

  @override
  String get adminFieldBranchEmail => 'بريد العيادة';

  @override
  String get adminFieldPhones => 'أرقام التليفون';

  @override
  String get adminFieldExamPrice => 'الكشف';

  @override
  String get adminFieldConsultPrice => 'الاستشارة';

  @override
  String get adminPhoneMobile => 'موبايل';

  @override
  String get adminPhoneLandline => 'أرضي';

  @override
  String get adminPhoneReception => 'الاستقبال';

  @override
  String adminReviewApprovedBy(String name) {
    return 'وافق عليه $name';
  }

  @override
  String adminReviewRejectedBy(String name) {
    return 'رفضه $name';
  }

  @override
  String get adminApprove => 'موافقة';

  @override
  String get adminReject => 'رفض';

  @override
  String get adminReviewHint =>
      'طابق كارنيه النقابة مع الاسم ورقم النقابة قبل اتخاذ القرار.';

  @override
  String adminApproveTitle(String name) {
    return 'الموافقة على د. $name؟';
  }

  @override
  String get adminApproveBody =>
      'سيصبح الحساب نشطاً وسيصل للطبيب إشعار بذلك، ويمكنه البدء في استخدام «العيادة» فوراً.';

  @override
  String adminApprovedMessage(String name) {
    return 'تمت الموافقة على د. $name، ويمكنه الآن استخدام «العيادة».';
  }

  @override
  String adminRejectTitle(String name) {
    return 'رفض طلب د. $name؟';
  }

  @override
  String get adminRejectBody =>
      'سيرى الطبيب هذا السبب، ويمكنه تصحيح بياناته وإعادة إرسال الطلب.';

  @override
  String get adminRejectReasonLabel => 'سبب الرفض';

  @override
  String get adminRejectPresets => 'أسباب شائعة';

  @override
  String get adminRejectPresetLicense =>
      'صورة كارنيه النقابة غير واضحة، ارفع صورة أوضح.';

  @override
  String get adminRejectPresetNumber => 'رقم النقابة لا يطابق الكارنيه.';

  @override
  String get adminRejectPresetBranch =>
      'عنوان العيادة أو رقم التليفون غير مكتمل.';

  @override
  String adminRejectedMessage(String name) {
    return 'تم رفض طلب د. $name، وسيظهر له السبب.';
  }

  @override
  String get adminLicenseTitle => 'كارنيه النقابة';

  @override
  String get adminLicenseSubtitle => 'طابق الاسم والرقم مع البيانات المسجلة.';

  @override
  String get adminLicenseImageLabel => 'صورة كارنيه النقابة، افتحها للتكبير.';

  @override
  String adminLicenseImageOf(String name) {
    return 'كارنيه نقابة د. $name';
  }

  @override
  String get adminLicenseZoom => 'تكبير';

  @override
  String get adminLicensePdf => 'كارنيه النقابة (PDF)';

  @override
  String get adminLicenseFile => 'ملف';

  @override
  String get adminLicenseFileName => 'ترخيص';

  @override
  String get adminLicenseOpen => 'فتح';

  @override
  String get adminLicenseCantOpen =>
      'لا يمكن فتح الملف على هذا الجهاز. افتحه من تطبيق الكمبيوتر.';

  @override
  String adminFileSizeKb(int kb) {
    return '$kb كيلوبايت';
  }

  @override
  String get adminZoomIn => 'تكبير';

  @override
  String get adminZoomOut => 'تصغير';

  @override
  String get adminZoomReset => 'ملء الشاشة';

  @override
  String adminSettingsLastChange(String name, String time) {
    return 'آخر تعديل بواسطة $name · $time';
  }

  @override
  String get adminGroupBilling => 'الفوترة';

  @override
  String get adminGroupBillingBody =>
      'رسوم المنصة على كل زيارة، وقواعد السداد.';

  @override
  String get adminGroupPayment => 'الدفع';

  @override
  String get adminGroupPaymentBody =>
      'الحساب الذي يحوّل إليه الأطباء المستحقات، ويظهر في شاشة الفواتير.';

  @override
  String get adminGroupFiles => 'الملفات';

  @override
  String get adminGroupFilesBody => 'الحد الأقصى لرفع الملفات الطبية.';

  @override
  String get adminGroupClinics => 'العيادات';

  @override
  String get adminGroupClinicsBody => 'الحدود المسموحة لكل عيادة.';

  @override
  String get adminGroupVersions => 'أقل إصدار مسموح للتطبيق';

  @override
  String get adminGroupVersionsBody =>
      'التطبيقات الأقدم يلزمها التحديث قبل أن تفتح.';

  @override
  String get adminGroupMaintenance => 'الصيانة';

  @override
  String get adminGroupMaintenanceBody =>
      'أغلق التطبيق أمام الجميع عدا الإدارة، مع رسالتك.';

  @override
  String get adminGroupSupport => 'بيانات الدعم';

  @override
  String get adminGroupSupportBody =>
      'تظهر في شاشات الحساب المعطّل والطلب المنتظر والصيانة.';

  @override
  String get adminGroupLegal => 'الشروط والخصوصية';

  @override
  String get adminGroupLegalBody =>
      'يوافق عليها المرضى عند أول دخول. إذا تُركت إحدى اللغتين فارغة تظهر الأخرى.';

  @override
  String get adminSettingExamFee => 'رسوم الكشف';

  @override
  String get adminSettingConsultationFee => 'رسوم الاستشارة';

  @override
  String get adminSettingGracePeriod => 'مهلة السداد';

  @override
  String get adminSettingMaxConsultations => 'أقصى عدد استشارات متتالية';

  @override
  String get adminSettingInstapayAddress => 'عنوان إنستاباي';

  @override
  String get adminSettingInstapayName => 'اسم حساب إنستاباي';

  @override
  String get adminSettingInstapayInstructionsAr => 'تعليمات الدفع (عربي)';

  @override
  String get adminSettingInstapayInstructionsEn => 'تعليمات الدفع (إنجليزي)';

  @override
  String get adminSettingMaxUpload => 'أقصى حجم للملف';

  @override
  String get adminSettingMaxAssistants => 'أقصى عدد مساعدين لكل طبيب';

  @override
  String get adminSettingMaxBranches => 'أقصى عدد فروع لكل طبيب';

  @override
  String get adminSettingVersionAndroid => 'أقل إصدار لأندرويد';

  @override
  String get adminSettingVersionIos => 'أقل إصدار لـ iOS';

  @override
  String get adminSettingVersionWindows => 'أقل إصدار لويندوز';

  @override
  String get adminSettingVersionMacos => 'أقل إصدار لـ macOS';

  @override
  String get adminSettingMaintenance => 'وضع الصيانة';

  @override
  String get adminSettingMaintenanceMessageAr => 'رسالة الصيانة (عربي)';

  @override
  String get adminSettingMaintenanceMessageEn => 'رسالة الصيانة (إنجليزي)';

  @override
  String get adminSettingSupportPhone => 'هاتف الدعم';

  @override
  String get adminSettingSupportWhatsapp => 'واتساب الدعم';

  @override
  String get adminSettingSupportEmail => 'بريد الدعم';

  @override
  String get adminSettingTermsAr => 'الشروط والأحكام (عربي)';

  @override
  String get adminSettingTermsEn => 'الشروط والأحكام (إنجليزي)';

  @override
  String get adminSettingPrivacyAr => 'سياسة الخصوصية (عربي)';

  @override
  String get adminSettingPrivacyEn => 'سياسة الخصوصية (إنجليزي)';

  @override
  String adminRangeHint(String min, String max) {
    return 'من $min إلى $max';
  }

  @override
  String get adminVersionHint => 'مثل 1.2.0';

  @override
  String get adminPhoneHint => 'موبايل أو أرضي أو خط ساخن';

  @override
  String get adminWhatsappHint => 'رقم مصري، أو دولي يبدأ بـ +';

  @override
  String get adminAppliesToNewSessions => 'يُطبّق على الجلسات الجديدة فقط';

  @override
  String get adminAppliesToNewInvoices => 'يُطبّق على الفواتير الجديدة فقط';

  @override
  String adminWasValue(String value) {
    return 'القيمة المحفوظة: $value';
  }

  @override
  String adminCharacterCount(String count, String max) {
    return '$count / $max';
  }

  @override
  String adminFieldHistory(String field) {
    return 'سجل تغييرات: $field';
  }

  @override
  String get adminMaintenanceOn =>
      'مفعّل: يرى الجميع شاشة الصيانة عدا الإدارة.';

  @override
  String get adminMaintenanceOff => 'متوقف: التطبيق متاح للجميع.';

  @override
  String get adminMaintenanceWillStart => 'ستبدأ الصيانة فور الحفظ.';

  @override
  String get adminMaintenanceWillEnd => 'سيفتح التطبيق للجميع فور الحفظ.';

  @override
  String adminUnsavedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعديل لم يُحفظ',
      many: '$count تعديلاً لم يُحفظ',
      few: '$count تعديلات لم تُحفظ',
      two: 'تعديلان لم يُحفظا',
      one: 'تعديل واحد لم يُحفظ',
    );
    return '$_temp0';
  }

  @override
  String get adminAllSaved => 'تم حفظ كل التعديلات';

  @override
  String get adminDiscard => 'تجاهل';

  @override
  String get adminDiscardTitle => 'تجاهل التعديلات؟';

  @override
  String adminDiscardBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لم يُحفظ $count تعديل وسيضيع.',
      many: 'لم يُحفظ $count تعديلاً وسيضيع.',
      few: 'لم تُحفظ $count تعديلات وستضيع.',
      two: 'لم يُحفظ التعديلان وسيضيعان.',
      one: 'لم يُحفظ تعديلك وسيضيع.',
    );
    return '$_temp0';
  }

  @override
  String adminSettingsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حفظ $count إعداد',
      many: 'تم حفظ $count إعداداً',
      few: 'تم حفظ $count إعدادات',
      two: 'تم حفظ إعدادين',
      one: 'تم حفظ إعداد واحد',
    );
    return '$_temp0';
  }

  @override
  String get adminHistoryTitle => 'سجل التغييرات';

  @override
  String get adminHistoryAll => 'كل الإعدادات';

  @override
  String get adminHistoryEmptyTitle => 'لا توجد تغييرات بعد';

  @override
  String get adminHistoryEmptyBody => 'يظهر هنا كل تغيير محفوظ ومن قام به.';

  @override
  String adminHistoryChangedBy(String name, String time) {
    return '$name · $time';
  }

  @override
  String get adminHistoryChangedTo => 'تغيّر إلى';

  @override
  String get adminHistoryBefore => 'قبل';

  @override
  String get adminHistoryAfter => 'بعد';

  @override
  String get adminHistoryShowFull => 'اعرض النص كاملاً';

  @override
  String adminAdminsCount(int count, int superAdmins) {
    return 'المسؤولون: $count · المسؤولون الرئيسيون النشطون: $superAdmins';
  }

  @override
  String get adminAdminsRestricted =>
      'إدارة المسؤولين متاحة للمسؤول الرئيسي فقط.';

  @override
  String get adminAddAdmin => 'إضافة مسؤول';

  @override
  String get adminAddAdminBody =>
      'سيحصل على كلمة مرور مؤقتة، ويختار كلمة مروره عند أول دخول.';

  @override
  String get adminRoleAdminBody => 'كل الصلاحيات عدا إدارة المسؤولين.';

  @override
  String get adminRoleSuperAdminBody =>
      'كل الصلاحيات، بما فيها إضافة المسؤولين وتغيير أدوارهم.';

  @override
  String get adminColumnName => 'الاسم';

  @override
  String get adminColumnRole => 'الدور';

  @override
  String get adminColumnStatus => 'الحالة';

  @override
  String get adminColumnLastSignIn => 'آخر دخول';

  @override
  String get adminPasswordNotSet => 'لم يعيّن كلمة مرور بعد';

  @override
  String get adminNeverSignedIn => 'لم يدخل بعد';

  @override
  String adminLastSignIn(String time) {
    return 'آخر دخول: $time';
  }

  @override
  String adminYouSuffix(String name) {
    return '$name (أنت)';
  }

  @override
  String get adminThatsYou => 'هذا حسابك، ويمكن لمسؤول رئيسي آخر تعديله.';

  @override
  String adminActionsFor(String name) {
    return 'إجراءات $name';
  }

  @override
  String get adminMakeSuper => 'اجعله مسؤولاً رئيسياً';

  @override
  String get adminMakeAdmin => 'اجعله مسؤولاً عادياً';

  @override
  String adminMakeSuperTitle(String name) {
    return 'جعل $name مسؤولاً رئيسياً؟';
  }

  @override
  String get adminMakeSuperBody =>
      'سيتمكن من إضافة المسؤولين وتغيير أدوارهم وتعطيلهم.';

  @override
  String adminMakeAdminTitle(String name) {
    return 'جعل $name مسؤولاً عادياً؟';
  }

  @override
  String get adminMakeAdminBody =>
      'لن يتمكن من إدارة المسؤولين، ويسري التغيير فوراً.';

  @override
  String adminRoleChanged(String name) {
    return 'تم تغيير دور $name.';
  }

  @override
  String get adminDisable => 'تعطيل';

  @override
  String get adminEnable => 'تفعيل';

  @override
  String adminDisableTitle(String name) {
    return 'تعطيل حساب $name؟';
  }

  @override
  String get adminDisableBody =>
      'سيتم تسجيل خروجه من كل الأجهزة فوراً، ولن يستطيع الدخول حتى تعيد تفعيله.';

  @override
  String adminEnableTitle(String name) {
    return 'تفعيل حساب $name؟';
  }

  @override
  String get adminEnableBody => 'سيتمكن من الدخول مرة أخرى بكلمة مروره.';

  @override
  String adminDisabledMessage(String name) {
    return 'تم تعطيل حساب $name.';
  }

  @override
  String adminEnabledMessage(String name) {
    return 'تم تفعيل حساب $name.';
  }

  @override
  String get adminNotAllowedTitle => 'غير مسموح';

  @override
  String adminCreatedTitle(String name) {
    return 'تمت إضافة $name';
  }

  @override
  String get adminPasswordOnceWarning =>
      'انسخ كلمة المرور المؤقتة الآن، فهي تظهر مرة واحدة فقط ولا يمكن عرضها مرة أخرى. أرسلها له بطريقة آمنة.';

  @override
  String get adminTemporaryPassword => 'كلمة المرور المؤقتة';

  @override
  String get adminCopyPassword => 'نسخ كلمة المرور';

  @override
  String get adminCopied => 'تم النسخ';

  @override
  String adminPasswordNextStep(String email) {
    return 'يسجل الدخول بالبريد $email وكلمة المرور هذه، ثم يختار كلمة مروره.';
  }

  @override
  String adminAuditCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجل',
      many: '$count سجلاً',
      few: '$count سجلات',
      two: 'سجلان',
      one: 'سجل واحد',
      zero: 'لا توجد سجلات',
    );
    return '$_temp0';
  }

  @override
  String get adminAuditEmptyTitle => 'لا توجد عمليات مسجلة بعد';

  @override
  String get adminAuditNoMatchTitle => 'لا توجد عمليات تطابق هذه الفلاتر';

  @override
  String get adminAuditNoMatchBody => 'جرّب مدة أطول أو امسح بعض الفلاتر.';

  @override
  String get adminAuditEnd => 'هذه كل النتائج.';

  @override
  String get adminClearFilters => 'مسح الفلاتر';

  @override
  String get adminClearFilter => 'مسح';

  @override
  String get adminFilterAction => 'العملية';

  @override
  String get adminFilterAllActions => 'كل العمليات';

  @override
  String get adminFilterWho => 'المنفّذ';

  @override
  String get adminFilterEveryone => 'الجميع';

  @override
  String get adminFilterTarget => 'الهدف';

  @override
  String get adminFilterAllTargets => 'كل الأهداف';

  @override
  String get adminFilterDates => 'أي تاريخ';

  @override
  String adminFilterBy(String name) {
    return 'بواسطة $name';
  }

  @override
  String adminDateRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String get adminColumnWhen => 'الوقت';

  @override
  String get adminColumnWho => 'المنفّذ';

  @override
  String get adminColumnWhat => 'العملية';

  @override
  String get adminColumnTarget => 'الهدف';

  @override
  String get adminTargetDoctor => 'طبيب';

  @override
  String get adminTargetUser => 'حساب';

  @override
  String get adminTargetSettings => 'الإعدادات';

  @override
  String get adminDetailFields => 'الإعدادات المعدّلة';

  @override
  String get adminDetailChannel => 'الطريقة';

  @override
  String get adminChannelEmail => 'رابط البريد';

  @override
  String get adminChannelDoctor => 'عن طريق الطبيب';

  @override
  String get adminEntryNumber => 'رقم السجل';

  @override
  String get adminOnlyThisPerson => 'هذا المنفّذ فقط';

  @override
  String get adminOnlyThisRecord => 'هذا الهدف فقط';

  @override
  String get adminOpenRegistration => 'افتح طلب التسجيل';

  @override
  String get adminCopyDetails => 'نسخ التفاصيل';

  @override
  String get adminCopiedDetails => 'تم نسخ التفاصيل';

  @override
  String get adminAuditRegistrationSubmitted => 'أرسل طلب تسجيل';

  @override
  String get adminAuditRegistrationResubmitted =>
      'أعاد إرسال طلب التسجيل بعد رفضه';

  @override
  String get adminAuditRegistrationApproved => 'وافق على طلب تسجيل طبيب';

  @override
  String get adminAuditRegistrationRejected => 'رفض طلب تسجيل طبيب';

  @override
  String get adminAuditLicenseViewed => 'اطّلع على كارنيه نقابة طبيب';

  @override
  String get adminAuditAdminSeeded => 'أنشأ أول مسؤول رئيسي';

  @override
  String adminAuditAdminCreated(String role) {
    return 'أضاف مسؤولاً ($role)';
  }

  @override
  String adminAuditAdminRoleChanged(String before, String after) {
    return 'غيّر دور مسؤول من $before إلى $after';
  }

  @override
  String get adminAuditAdminDisabled => 'عطّل حساب مسؤول';

  @override
  String get adminAuditAdminEnabled => 'فعّل حساب مسؤول';

  @override
  String get adminAuditProfileUpdated => 'حدّث ملفه الشخصي';

  @override
  String adminAuditSettingsUpdated(String fields) {
    return 'عدّل الإعدادات: $fields';
  }

  @override
  String get adminAuditPasswordSet => 'عيّن كلمة مرور جديدة';

  @override
  String get adminAuditPasswordChanged => 'غيّر كلمة المرور';

  @override
  String get adminAuditResetRequestedEmail =>
      'طلب إعادة تعيين كلمة المرور عبر البريد';

  @override
  String get adminAuditResetRequestedDoctor =>
      'طلب من طبيبه إعادة تعيين كلمة المرور';

  @override
  String get adminAuditPasswordReset => 'أعاد تعيين كلمة المرور برابط البريد';

  @override
  String get adminAuditLockedOut =>
      'أغلق حساباً 15 دقيقة بعد محاولات دخول خاطئة';

  @override
  String get adminAuditTokenReuse => 'أنهى جلسة لاستخدام رمز الدخول مرتين';

  @override
  String get adminAuditEmailVerified => 'أكّد بريده الإلكتروني';

  @override
  String get adminActionRegistrationSubmitted => 'إرسال طلب تسجيل';

  @override
  String get adminActionRegistrationResubmitted => 'إعادة إرسال طلب تسجيل';

  @override
  String get adminActionRegistrationApproved => 'الموافقة على طلب تسجيل';

  @override
  String get adminActionRegistrationRejected => 'رفض طلب تسجيل';

  @override
  String get adminActionLicenseViewed => 'عرض كارنيه النقابة';

  @override
  String get adminActionAdminSeeded => 'إنشاء أول مسؤول رئيسي';

  @override
  String get adminActionAdminCreated => 'إضافة مسؤول';

  @override
  String get adminActionAdminRoleChanged => 'تغيير دور مسؤول';

  @override
  String get adminActionAdminDisabled => 'تعطيل مسؤول';

  @override
  String get adminActionAdminEnabled => 'تفعيل مسؤول';

  @override
  String get adminActionProfileUpdated => 'تحديث الملف الشخصي';

  @override
  String get adminActionSettingsUpdated => 'تعديل الإعدادات';

  @override
  String get adminActionPasswordSet => 'تعيين كلمة مرور';

  @override
  String get adminActionPasswordChanged => 'تغيير كلمة المرور';

  @override
  String get adminActionResetRequested => 'طلب إعادة تعيين كلمة المرور';

  @override
  String get adminActionPasswordReset => 'إعادة تعيين كلمة المرور';

  @override
  String get adminActionLockedOut => 'إغلاق حساب مؤقتاً';

  @override
  String get adminActionTokenReuse => 'إعادة استخدام رمز الدخول';

  @override
  String get adminActionEmailVerified => 'تأكيد البريد';

  @override
  String get adminProfileSubtitle => 'حسابك، واللغة والمظهر، وكلمة المرور.';

  @override
  String get adminProfileAccount => 'الحساب';

  @override
  String get adminEditName => 'تعديل الاسم';

  @override
  String get adminMemberSince => 'مسؤول منذ';

  @override
  String get adminNameSaved => 'تم حفظ الاسم';

  @override
  String get adminPreferences => 'اللغة والمظهر';

  @override
  String get adminPreferencesBody => 'تُحفظ على هذا الجهاز وفي حسابك.';

  @override
  String get adminLanguage => 'اللغة';

  @override
  String get adminChangePassword => 'تغيير كلمة المرور';

  @override
  String get adminChangePasswordBody =>
      'سيتم تسجيل الخروج من أجهزتك الأخرى عند التغيير.';

  @override
  String get adminCurrentPassword => 'كلمة المرور الحالية';

  @override
  String get adminPasswordChanged =>
      'تم تغيير كلمة المرور، وتم تسجيل الخروج من أجهزتك الأخرى.';

  @override
  String get adminLogoutBody => 'تسجيل الخروج من «العيادة» على هذا الجهاز.';

  @override
  String get navActivityLog => 'سجل النشاط';

  @override
  String clinicOfDoctor(String name) {
    return 'عيادة د. $name';
  }

  @override
  String get clinicCurrentBranch => 'الفرع الحالي';

  @override
  String get clinicBranchTemporarilyClosed => 'مغلق مؤقتاً';

  @override
  String get clinicSuspendedBanner =>
      'تم إيقاف الخدمة لعدم سداد الفاتورة. برجاء السداد لإعادة التفعيل.';

  @override
  String get clinicPayNow => 'ادفع الآن';

  @override
  String get clinicLoadFailed => 'تعذّر تحميل بيانات العيادة.';

  @override
  String get errorPermissionDenied =>
      'ليست لديك صلاحية لهذا الإجراء. تواصل مع الطبيب.';

  @override
  String get errorDoctorSuspended => 'غير متاح أثناء إيقاف الخدمة.';

  @override
  String get errorBranchNotAllowed => 'هذا الفرع ليس من فروعك.';

  @override
  String get tempPasswordTitle => 'كلمة المرور المؤقتة';

  @override
  String tempPasswordBody(String name) {
    return 'أعطها لـ $name. لن تظهر مرة أخرى، وسيختار كلمة مرور جديدة عند تسجيل الدخول.';
  }

  @override
  String get tempPasswordCopy => 'نسخ';

  @override
  String get tempPasswordCopied => 'تم النسخ';

  @override
  String get tempPasswordShareWhatsApp => 'واتساب';

  @override
  String get tempPasswordShareSms => 'رسالة SMS';

  @override
  String tempPasswordMessage(String phone, String password) {
    return 'حسابك على تطبيق «العيادة»: $phone\nكلمة المرور المؤقتة: $password\nستختار كلمة مرور جديدة عند تسجيل الدخول.';
  }

  @override
  String get tempPasswordMessageCopied =>
      'لا يوجد تطبيق رسائل. تم نسخ الرسالة، الصقها حيث تريد.';

  @override
  String get branchErrorLimitReached =>
      'وصلت للحد الأقصى لعدد الفروع. أرشف فرعاً لإضافة فرع جديد.';

  @override
  String get branchErrorArchiveDefault =>
      'لا يمكن أرشفة الفرع الافتراضي. اجعل فرعاً آخر هو الافتراضي أولاً.';

  @override
  String get branchErrorLastActive =>
      'يجب أن يبقى فرع واحد مفتوح على الأقل، لذلك لا يمكن إغلاق هذا الفرع أو أرشفته.';

  @override
  String get branchErrorHasBookings =>
      'لدى هذا الفرع حجوزات قادمة. انقلها أو ألغها أولاً.';

  @override
  String get branchErrorNotActive =>
      'الفرع المفتوح فقط يمكن أن يكون الافتراضي.';

  @override
  String get branchErrorInvalidBranch =>
      'اختر فرعاً من فروع العيادة غير المؤرشفة.';

  @override
  String get branchErrorPeriodEndBeforeStart =>
      'تنتهي قبل أن تبدأ. فعّل «تنتهي في اليوم التالي» إذا كانت بعد منتصف الليل.';

  @override
  String get branchErrorPeriodLength => 'مدة الفترة من 15 دقيقة إلى 16 ساعة.';

  @override
  String get branchErrorPeriodsOverlap => 'الفترات متداخلة';

  @override
  String get assistantErrorLimitReached => 'وصلت للحد الأقصى لعدد المساعدين';

  @override
  String get assistantErrorPhoneTaken =>
      'هذا الرقم مسجّل كمساعد بالفعل، في هذه العيادة أو غيرها.';

  @override
  String get assistantErrorRemoved =>
      'تمت إزالة هذا المساعد. أضفه من جديد كمساعد جديد.';

  @override
  String get profileTopBarTooltip => 'ملفي الشخصي';

  @override
  String get settingsSubtitleDoctor =>
      'ملفك الشخصي والأسعار واللغة والإشعارات وكلمة المرور.';

  @override
  String get settingsSubtitleAssistant =>
      'اللغة والإشعارات وكلمة المرور، وما يمكنك فعله في العيادة.';

  @override
  String get settingsProfileHint => 'الاسم واللقب والدرجات العلمية والتخصصات';

  @override
  String settingsPermissionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صلاحية',
      many: '$count صلاحية',
      few: '$count صلاحيات',
      two: 'صلاحيتان',
      one: 'صلاحية واحدة',
      zero: 'بدون صلاحيات',
    );
    return '$_temp0';
  }

  @override
  String settingsBranchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فرع',
      many: '$count فرعاً',
      few: '$count فروع',
      two: 'فرعان',
      one: 'فرع واحد',
      zero: 'بدون فروع',
    );
    return '$_temp0';
  }

  @override
  String get settingsClinicGroup => 'العيادة';

  @override
  String get settingsPricesHint => 'الكشف والاستشارة، للطبيب ولكل فرع';

  @override
  String get settingsMyPermissions => 'صلاحياتي';

  @override
  String get settingsMyPermissionsFooter =>
      'الطبيب فقط يمكنه تغييرها، وتُطبق التغييرات فوراً.';

  @override
  String get settingsNoPermissions => 'لا توجد صلاحيات بعد. تواصل مع الطبيب.';

  @override
  String get settingsMyBranches => 'فروعي';

  @override
  String get settingsAllBranchesFooter =>
      'تعمل في كل الفروع، ومنها ما يضيفه الطبيب لاحقاً.';

  @override
  String get settingsNotifications => 'الإشعارات';

  @override
  String get settingsNotifyChat => 'رسائل المحادثات';

  @override
  String get settingsNotifyChatHint => 'الرسائل الجديدة من المرضى';

  @override
  String get settingsNotifyReminders => 'التذكيرات';

  @override
  String get settingsNotifyRemindersHint => 'الفواتير والمواعيد';

  @override
  String get settingsNotifyBookings => 'الحجوزات';

  @override
  String get settingsNotifyBookingsHint =>
      'الحجوزات الجديدة والمعدّلة والملغاة';

  @override
  String get settingsShowPreview => 'إظهار نص الرسالة في الإشعارات';

  @override
  String get settingsShowPreviewHint =>
      'عند الإيقاف: يظهر فقط أن رسالة وصلت، دون نصها.';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsAbout => 'عن التطبيق';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get pricesTitle => 'أسعار الكشف والاستشارة';

  @override
  String get assistantPresetReception => 'استقبال';

  @override
  String get assistantPresetClinical => 'مساعد طبي';

  @override
  String get assistantPresetOfficeManager => 'مدير العيادة';

  @override
  String get assistantPresetCustom => 'مخصص';

  @override
  String get assistantPresetReceptionBody =>
      'المرضى والزيارات والملفات والحجوزات.';

  @override
  String get assistantPresetClinicalBody =>
      'الاستقبال، مع الملف الطبي والمسودات والمحادثات.';

  @override
  String get assistantPresetOfficeManagerBody =>
      'الاستقبال، مع الفواتير ومواعيد العمل والأسعار والمحادثات.';

  @override
  String get assistantPresetCustomBody => 'ما تختاره من القائمة أدناه.';

  @override
  String get assistantGroupPatients => 'المرضى';

  @override
  String get assistantGroupSessions => 'الزيارات';

  @override
  String get assistantGroupClinical => 'الملف الطبي';

  @override
  String get assistantGroupFiles => 'الملفات والروشتات';

  @override
  String get assistantGroupChat => 'المحادثات';

  @override
  String get assistantGroupBilling => 'الفواتير';

  @override
  String get assistantGroupAppointments => 'الحجوزات';

  @override
  String get assistantGroupMoney => 'الإيرادات والأسعار';

  @override
  String get assistantPermPatientsManage => 'إدارة المرضى';

  @override
  String get assistantPermPatientsManageHelp =>
      'إضافة المرضى وربطهم وتعديل بياناتهم وأرشفتهم.';

  @override
  String get assistantPermPatientsResetPassword =>
      'إعادة تعيين كلمات مرور المرضى';

  @override
  String get assistantPermPatientsResetPasswordHelp =>
      'إعطاء المريض كلمة مرور مؤقتة جديدة، واستلام طلباته لإعادة التعيين.';

  @override
  String get assistantPermSessionsCreate => 'تسجيل الزيارات';

  @override
  String get assistantPermSessionsCreateHelp =>
      'نوع الزيارة والشكوى والعلامات الحيوية، وقائمة الزيارات.';

  @override
  String get assistantPermSessionsDelete => 'حذف الزيارات';

  @override
  String get assistantPermSessionsDeleteHelp =>
      'بنفس شروط الطبيب. مغلقة افتراضياً.';

  @override
  String get assistantPermClinicalView => 'عرض الملف الطبي';

  @override
  String get assistantPermClinicalViewHelp =>
      'التاريخ المرضي والفحص والتشخيص والملاحظات والروشتات.';

  @override
  String get assistantPermClinicalEditProfile => 'تعديل التاريخ المرضي';

  @override
  String get assistantPermClinicalEditProfileHelp =>
      'الحساسية والأمراض المزمنة والأدوية والعمليات والتاريخ العائلي.';

  @override
  String get assistantPermFilesManage => 'الملفات';

  @override
  String get assistantPermFilesManageHelp =>
      'مسح الملفات ورفعها وعرضها، وحفظ مرفقات المحادثات.';

  @override
  String get assistantPermPrescriptionsPrint => 'طباعة الروشتات';

  @override
  String get assistantPermPrescriptionsPrintHelp =>
      'فتح الروشتات التي أرسلها الطبيب وطباعتها ومشاركتها.';

  @override
  String get assistantPermPrescriptionsDraft => 'تجهيز مسودات الروشتات';

  @override
  String get assistantPermPrescriptionsDraftHelp =>
      'كتابة المسودات وإرسالها للطبيب للمراجعة.';

  @override
  String get assistantPermChat => 'المحادثات';

  @override
  String get assistantPermChatHelp =>
      'قراءة رسائل المرضى والرد عليها نيابة عن الطبيب.';

  @override
  String get assistantPermBillingView => 'عرض الفواتير';

  @override
  String get assistantPermBillingViewHelp =>
      'بطاقات الرسوم والإجماليات اليومية والشهرية والفواتير.';

  @override
  String get assistantPermBillingPay => 'سداد الفواتير';

  @override
  String get assistantPermBillingPayHelp => 'إرسال سداد الفاتورة.';

  @override
  String get assistantPermAppointmentsView => 'عرض الحجوزات';

  @override
  String get assistantPermAppointmentsViewHelp =>
      'التقويم ولوحة اليوم والبحث، في فروعه.';

  @override
  String get assistantPermAppointmentsManage => 'إدارة الحجوزات';

  @override
  String get assistantPermAppointmentsManageHelp =>
      'الحجز والتأكيد والتغيير والإلغاء وتسجيل الحضور ونداء التالي.';

  @override
  String get assistantPermScheduleManage => 'إدارة مواعيد العمل';

  @override
  String get assistantPermScheduleManageHelp =>
      'مواعيد العمل والأيام الخاصة وإعدادات الحجز في فروعه.';

  @override
  String get assistantPermRevenueView => 'عرض الإيرادات';

  @override
  String get assistantPermRevenueViewHelp =>
      'إيرادات العيادة وصافي الدخل والمبالغ المحصّلة.';

  @override
  String get assistantPermPricesManage => 'إدارة أسعار الكشف والاستشارة';

  @override
  String get assistantPermPricesManageHelp => 'أسعار الطبيب، وأسعار فروعه.';

  @override
  String get assistantStatusRemoved => 'تمت إزالته';

  @override
  String get branchStatusActive => 'مفتوح';

  @override
  String get branchStatusArchived => 'مؤرشف';

  @override
  String get branchDefault => 'افتراضي';

  @override
  String get branchPayCash => 'نقداً';

  @override
  String get branchPayCard => 'بطاقة';

  @override
  String get branchPayInstapay => 'إنستاباي';

  @override
  String get branchPayWallet => 'محفظة إلكترونية';

  @override
  String get branchAmenityElevator => 'مصعد';

  @override
  String get branchAmenityParking => 'مكان لركن السيارات';

  @override
  String get branchAmenityWheelchair => 'مدخل للكراسي المتحركة';

  @override
  String get branchAmenityKidsArea => 'مكان انتظار للأطفال';

  @override
  String branchEndsNextDayShort(String range) {
    return '$range (اليوم التالي)';
  }

  @override
  String get profileSubtitle =>
      'بياناتك الشخصية والمهنية كما تظهر للمرضى والإدارة.';

  @override
  String profileLastSaved(String time) {
    return 'آخر حفظ $time';
  }

  @override
  String get profilePersonal => 'البيانات الشخصية';

  @override
  String get profileFullNameAr => 'الاسم بالعربية';

  @override
  String get profileReadOnlyNote =>
      'هذه البيانات تخص حسابك وترخيصك. لتغييرها تواصل مع الدعم.';

  @override
  String get profileProfessional => 'البيانات المهنية';

  @override
  String get profileDegreesHint => 'مثال: ماجستير الباطنة، جامعة القاهرة';

  @override
  String get profileSpecialtyNote =>
      'يُطبَّق تغيير التخصص فوراً، ويتم إبلاغ الإدارة.';

  @override
  String get profileSaved => 'تم حفظ الملف الشخصي';

  @override
  String get profileSavedSpecialty =>
      'تم الحفظ. التخصص الجديد مُطبّق الآن، وتم إبلاغ الإدارة.';

  @override
  String get profilePrescriptionHeader => 'رأس الروشتة';

  @override
  String get profilePrescriptionHeaderTitle =>
      'الشعار والتوقيع واللون وإعدادات الطباعة';

  @override
  String get profilePrescriptionHeaderLater =>
      'ستضبط شكل الروشتة عند إضافة الروشتات للتطبيق.';

  @override
  String get settingsLaterPhase => 'مرحلة لاحقة';

  @override
  String get pricesSubtitle => 'ما يدفعه المرضى في العيادة، للطبيب ولكل فرع.';

  @override
  String get pricesFutureOnly =>
      'تُطبق الأسعار الجديدة على الزيارات القادمة فقط';

  @override
  String get pricesDoctorTitle => 'أسعار الطبيب';

  @override
  String get pricesDoctorBody => 'يستخدمها كل فرع ليس له أسعار خاصة.';

  @override
  String get pricesBranchesTitle => 'أسعار الفروع';

  @override
  String get pricesUseDoctor => 'استخدام أسعار الطبيب';

  @override
  String pricesUseDoctorOn(String examination, String consultation) {
    return 'الكشف: $examination، الاستشارة: $consultation';
  }

  @override
  String get pricesUseDoctorOff =>
      'أسعار خاصة بهذا الفرع، والسعر الفارغ يستخدم سعر الطبيب.';

  @override
  String get pricesEmptyAskClinic =>
      'فارغ: سيرى المرضى «يُرجى الاستفسار من العيادة»، ويُكتب المبلغ في كل زيارة.';

  @override
  String pricesEmptyUsesDoctor(String price) {
    return 'فارغ: يُطبق سعر الطبيب ($price).';
  }

  @override
  String get pricesAskClinic => 'يُرجى الاستفسار من العيادة';

  @override
  String get pricesSaved => 'تم حفظ الأسعار، وتُطبق على الزيارات من الآن.';

  @override
  String get pricesNotYourBranch =>
      'يغيّر هذه الأسعار الطبيب أو مساعدو هذا الفرع فقط.';

  @override
  String get pricesHistoryTitle => 'سجل التغييرات';

  @override
  String get pricesHistoryEmptyTitle => 'لا توجد تغييرات في الأسعار بعد';

  @override
  String get pricesHistoryEmptyBody => 'يظهر هنا كل تغيير، مع من قام به ومتى.';

  @override
  String get pricesNotSet => 'بدون سعر';

  @override
  String pricesChange(String type, String before, String after) {
    return '$type: $before ← $after';
  }

  @override
  String pricesChangedBy(String name, String role, String time) {
    return '$name ($role)، $time';
  }

  @override
  String get branchesSubtitle =>
      'أماكن استقبال المرضى. اضغط على فرع لتعديل بياناته أو مواعيده أو حالته.';

  @override
  String get branchesEmptyTitle => 'لا توجد فروع بعد';

  @override
  String get branchAdd => 'إضافة فرع';

  @override
  String branchCountOf(int count, int limit) {
    return '$count من $limit فروع';
  }

  @override
  String get branchArchivedHint => 'مؤرشف: لا يظهر للمرضى ولا يقبل حجوزات';

  @override
  String get branchClosedToday => 'مغلق اليوم';

  @override
  String branchUpcomingBookings(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حجز قادم',
      many: '$count حجزاً قادماً',
      few: '$count حجوزات قادمة',
      two: 'حجزان قادمان',
      one: 'حجز قادم واحد',
      zero: 'لا توجد حجوزات قادمة',
    );
    return '$_temp0';
  }

  @override
  String branchReopensOn(String date) {
    return 'يعود للعمل يوم $date';
  }

  @override
  String get branchSaved => 'تم الحفظ';

  @override
  String get branchTabInfo => 'البيانات';

  @override
  String get branchTabAddress => 'العنوان والخريطة';

  @override
  String get branchTabContact => 'التواصل';

  @override
  String get branchTabHours => 'مواعيد العمل';

  @override
  String get branchTabClinic => 'معلومات للمرضى';

  @override
  String branchTabUnsaved(String tab) {
    return '$tab، غير محفوظ';
  }

  @override
  String get branchDescription => 'وصف قصير (اختياري)';

  @override
  String get branchDescriptionHint => 'مثال: الدور الثاني، بجوار الصيدلية';

  @override
  String get branchAreaLabel => 'المنطقة (اختياري)';

  @override
  String get branchEmailLabel => 'بريد العيادة (اختياري)';

  @override
  String get branchPaymentMethods => 'طرق الدفع في العيادة';

  @override
  String get branchAmenities => 'المرافق';

  @override
  String get branchForPatients => 'ما يراه المرضى';

  @override
  String get branchForPatientsBody => 'تظهر على بطاقة الفرع عند الحجز.';

  @override
  String get branchPricesTitle => 'أسعار هذا الفرع';

  @override
  String branchHoursQueueNote(int count) {
    return 'الحجز هنا بنظام الدور. كل فترة تستقبل $count مريضاً ما لم تحدد لها عدداً آخر.';
  }

  @override
  String get branchHoursTimedNote => 'الحجز هنا بمواعيد محددة.';

  @override
  String get branchCopySaturday => 'نسخ السبت لكل الأيام';

  @override
  String get branchCopySaturdayTitle => 'نسخ مواعيد السبت لكل الأيام؟';

  @override
  String get branchCopySaturdayBody =>
      'تُستبدل فترات الأيام الأخرى بفترات السبت، ولا يُحفظ شيء حتى تضغط حفظ.';

  @override
  String get branchDayClosed => 'مغلق';

  @override
  String get branchAddPeriod => 'إضافة فترة';

  @override
  String get branchRemovePeriod => 'حذف هذه الفترة';

  @override
  String get branchPeriodFrom => 'من';

  @override
  String get branchPeriodTo => 'إلى';

  @override
  String get branchEndsNextDay => 'تنتهي في اليوم التالي';

  @override
  String get branchPeriodMorning => 'صباحي';

  @override
  String get branchPeriodEvening => 'مسائي';

  @override
  String get branchCapacity => 'عدد المرضى';

  @override
  String get branchErrorTooManyPeriods => '10 فترات في اليوم كحد أقصى.';

  @override
  String get branchStatusTitle => 'حالة الفرع';

  @override
  String get branchStatusActiveBody => 'مفتوح: يراه المرضى ويمكنهم الحجز.';

  @override
  String get branchStatusDefaultBody =>
      'مفتوح، وهو الفرع الافتراضي: تُسجّل الزيارات الجديدة عليه ما لم تختر فرعاً آخر.';

  @override
  String get branchStatusClosedBody =>
      'يرى المرضى رسالتك على بطاقة الفرع ولا يمكنهم الحجز فيه.';

  @override
  String get branchStatusArchivedBody =>
      'مخفي عن المرضى والحجز. يبقى سجله، ويمكنك إعادته.';

  @override
  String get branchPatientsSee => 'يرى المرضى';

  @override
  String get branchMakeDefault => 'اجعله الافتراضي';

  @override
  String branchMakeDefaultTitle(String name) {
    return 'جعل $name الفرع الافتراضي؟';
  }

  @override
  String get branchMakeDefaultBody =>
      'تستخدم الزيارات الجديدة الفرع الافتراضي ما لم يُختر فرع آخر.';

  @override
  String branchDefaultMessage(String name) {
    return 'أصبح $name الفرع الافتراضي.';
  }

  @override
  String get branchCloseTemporarily => 'إغلاق مؤقت';

  @override
  String get branchCloseBody =>
      'يرى المرضى هذه الرسالة على بطاقة الفرع، ولا يمكنهم الحجز حتى تعيد فتحه.';

  @override
  String get branchClosedMessageLabel => 'رسالة للمرضى';

  @override
  String get branchClosedMessageHint => 'مثال: مغلق للتجديدات';

  @override
  String get branchReopenDateAdd => 'تاريخ العودة المتوقع (اختياري)';

  @override
  String get branchCloseConfirm => 'إغلاق الفرع';

  @override
  String get branchClosedMessage => 'تم إغلاق الفرع مؤقتاً.';

  @override
  String get branchEditClosure => 'تعديل الرسالة';

  @override
  String get branchReopen => 'إعادة الفتح';

  @override
  String get branchReopenedMessage => 'تمت إعادة فتح الفرع.';

  @override
  String get branchArchive => 'أرشفة';

  @override
  String branchArchiveTitle(String name) {
    return 'أرشفة $name؟';
  }

  @override
  String get branchArchiveBody =>
      'يختفي عن المرضى ولا يقبل حجوزات. تبقى زياراته وسجله، ويمكنك إعادته لاحقاً.';

  @override
  String get branchArchivedMessage => 'تمت أرشفة الفرع.';

  @override
  String get branchRestore => 'إعادة الفرع';

  @override
  String get branchRestoredMessage => 'عاد الفرع وأصبح مفتوحاً.';

  @override
  String get branchRefusedTitle => 'غير ممكن الآن';

  @override
  String branchBookingsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حجز قادم',
      many: '$count حجزاً قادماً',
      few: '$count حجوزات قادمة',
      two: 'حجزان قادمان',
      one: 'حجز قادم واحد',
    );
    return '$_temp0';
  }

  @override
  String branchBookingsMore(int count) {
    return 'و$count غيرها.';
  }

  @override
  String get branchBookingsHint =>
      'انقلها لفرع آخر أو ألغها من تقويم الحجوزات، ثم حاول مرة أخرى. يُبلَّغ المرضى الملغاة حجوزاتهم برابط لإعادة الحجز.';

  @override
  String branchBookingGuest(String name) {
    return '$name (ضيف)';
  }

  @override
  String get branchLaterTabs => 'لاحقاً';

  @override
  String get branchLaterTabsTitle => 'إعدادات الحجز والأيام الخاصة';

  @override
  String get branchLaterTabsBody => 'تُضاف مع الحجوزات.';

  @override
  String get branchAddedMessage => 'تمت إضافة الفرع. حدّد مواعيد العمل الآن.';

  @override
  String get branchNewNextSteps =>
      'مواعيد العمل والأسعار في الخطوة التالية، بعد إضافة الفرع.';

  @override
  String get assistantsSubtitle => 'من يعمل معك، وما يمكن لكل منهم فعله.';

  @override
  String get assistantAdd => 'إضافة مساعد';

  @override
  String assistantCountOf(int count, int limit) {
    return '$count من $limit مساعدين';
  }

  @override
  String get assistantsEmptyTitle => 'لا يوجد مساعدون بعد';

  @override
  String get assistantsEmptyBody =>
      'أضف موظف الاستقبال ليسجل الزيارات والحجوزات نيابة عنك.';

  @override
  String get assistantChoose => 'اختر مساعداً لعرض بياناته';

  @override
  String get assistantAddBody =>
      'يحصل على كلمة مرور مؤقتة، ويختار كلمة مروره عند أول تسجيل دخول.';

  @override
  String get assistantNeverActive => 'لم يستخدم العيادة بعد';

  @override
  String assistantLastActive(String time) {
    return 'آخر نشاط $time';
  }

  @override
  String assistantAddedOn(String date) {
    return 'أُضيف في $date';
  }

  @override
  String get assistantDetails => 'البيانات';

  @override
  String get assistantPhoneHint => 'يسجّل الدخول بهذا الرقم.';

  @override
  String get assistantBranches => 'الفروع';

  @override
  String get assistantBranchesHint =>
      'تظهر له الحجوزات ولوحة اليوم وقوائم الزيارات في هذه الفروع فقط.';

  @override
  String get assistantAllBranches => 'كل الفروع';

  @override
  String get assistantSomeBranches => 'فروع محددة';

  @override
  String get assistantAllBranchesBody => 'ومنها الفروع التي تضيفها لاحقاً.';

  @override
  String get assistantErrorBranchRequired => 'اختر فرعاً واحداً على الأقل.';

  @override
  String get assistantPermissions => 'الصلاحيات';

  @override
  String get assistantPermissionsHint =>
      'اختر قالباً ثم عدّل الاختيارات. بعضها يحتاج غيره، فيُختار تلقائياً.';

  @override
  String assistantAlsoOn(String permissions) {
    return 'تم تفعيل أيضاً: $permissions';
  }

  @override
  String assistantAlsoOff(String permissions) {
    return 'تم إيقاف أيضاً: $permissions';
  }

  @override
  String assistantSaved(String name) {
    return 'تم حفظ تغييرات $name، وتُطبق مع إجرائه التالي.';
  }

  @override
  String get assistantAccountActions => 'الحساب';

  @override
  String get assistantResetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get assistantResetPasswordHint => 'كلمة مرور مؤقتة جديدة عند نسيانها.';

  @override
  String assistantResetTitle(String name) {
    return 'إعادة تعيين كلمة مرور $name؟';
  }

  @override
  String get assistantResetBody =>
      'يُسجَّل خروجه من كل الأجهزة، ويدخل من جديد بكلمة المرور المؤقتة الجديدة.';

  @override
  String get assistantNewPasswordTitle => 'كلمة مرور مؤقتة جديدة';

  @override
  String get assistantDisableHint =>
      'يمنعه من الدخول فوراً، ويمكنك تفعيله لاحقاً.';

  @override
  String get assistantEnableHint => 'يمكنه تسجيل الدخول مرة أخرى.';

  @override
  String assistantDisableTitle(String name) {
    return 'إيقاف $name؟';
  }

  @override
  String get assistantDisableBody =>
      'يُسجَّل خروجه فوراً، ولا يمكنه الدخول حتى تعيد تفعيله.';

  @override
  String assistantEnableTitle(String name) {
    return 'تفعيل $name؟';
  }

  @override
  String get assistantEnableBody => 'يمكنه الدخول مرة أخرى بكلمة مروره.';

  @override
  String get assistantRemove => 'إزالة';

  @override
  String get assistantRemoveHint => 'نهائي. يبقى سجل نشاطه.';

  @override
  String assistantRemoveTitle(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get assistantRemoveBody =>
      'يُسجَّل خروجه فوراً ولا يمكن إعادته. يبقى سجل نشاطه، ويمكن إضافة رقمه من جديد كمساعد جديد.';

  @override
  String assistantRemovedMessage(String name) {
    return 'تمت إزالة $name.';
  }

  @override
  String assistantRemovedTitle(String name) {
    return 'تمت إزالة $name';
  }

  @override
  String activityCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نشاط',
      many: '$count نشاطاً',
      few: '$count أنشطة',
      two: 'نشاطان',
      one: 'نشاط واحد',
      zero: 'لا يوجد نشاط بعد',
    );
    return '$_temp0';
  }

  @override
  String get activityEmptyTitle => 'لا يوجد نشاط بعد';

  @override
  String get activityEmptyBody => 'يظهر هنا ما تفعله أنت ومساعدوك في العيادة.';

  @override
  String get activityToday => 'اليوم';

  @override
  String get activityYesterday => 'أمس';

  @override
  String activityWhoWhen(String who, String time) {
    return '$who، $time';
  }

  @override
  String activityRemovedPerson(String name) {
    return '$name (تمت إزالته)';
  }

  @override
  String activityPatientFile(String name, int number) {
    return '$name، ملف $number';
  }

  @override
  String get activityPatientUnlinked => 'مريض لم يعد في العيادة';

  @override
  String get activityOnlyThisPatient => 'هذا المريض فقط';

  @override
  String get activitySomeBranch => 'فرع';

  @override
  String get activitySomeAssistant => 'مساعد';

  @override
  String activityBranchCreated(String branch) {
    return 'أضاف $branch';
  }

  @override
  String activityBranchUpdated(String branch) {
    return 'عدّل بيانات $branch';
  }

  @override
  String activityBranchHoursUpdated(String branch) {
    return 'غيّر مواعيد العمل في $branch';
  }

  @override
  String activityBranchStatusChanged(
    String branch,
    String before,
    String after,
  ) {
    return 'غيّر حالة $branch: $before ← $after';
  }

  @override
  String activityDefaultBranchChanged(String branch) {
    return 'جعل $branch الفرع الافتراضي';
  }

  @override
  String get activityDoctorPricesUpdated => 'غيّر أسعار الطبيب';

  @override
  String activityBranchPricesUpdated(String branch) {
    return 'غيّر أسعار $branch';
  }

  @override
  String get activityProfileUpdated => 'عدّل الملف الشخصي';

  @override
  String get activitySpecialtyChanged => 'غيّر التخصص';

  @override
  String activityAssistantCreated(String name, String preset) {
    return 'أضاف المساعد $name ($preset)';
  }

  @override
  String activityAssistantUpdated(String name) {
    return 'عدّل بيانات $name';
  }

  @override
  String activityAssistantPermissionsChanged(String name) {
    return 'غيّر صلاحيات $name';
  }

  @override
  String activityAssistantPasswordReset(String name) {
    return 'أعاد تعيين كلمة مرور $name';
  }

  @override
  String activityAssistantDisabled(String name) {
    return 'أوقف $name';
  }

  @override
  String activityAssistantEnabled(String name) {
    return 'فعّل $name';
  }

  @override
  String activityAssistantRemoved(String name) {
    return 'أزال $name';
  }

  @override
  String get activityPasswordChanged => 'غيّر كلمة المرور';

  @override
  String get activityPasswordSet => 'اختار كلمة مرور';

  @override
  String activityPasswordResetRequested(String name) {
    return 'طلب $name كلمة مرور جديدة';
  }

  @override
  String get activityRegistrationSent => 'أرسل طلب التسجيل';

  @override
  String get activityEmailVerified => 'أكّد البريد الإلكتروني';

  @override
  String activityOther(String action) {
    return 'إجراء آخر: $action';
  }

  @override
  String activityPermissionsAdded(String permissions) {
    return 'أضاف: $permissions.';
  }

  @override
  String activityPermissionsRemoved(String permissions) {
    return 'أزال: $permissions.';
  }

  @override
  String activityPeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فترة في الأسبوع',
      many: '$count فترة في الأسبوع',
      few: '$count فترات في الأسبوع',
      two: 'فترتان في الأسبوع',
      one: 'فترة واحدة في الأسبوع',
      zero: 'مغلق كل الأيام',
    );
    return '$_temp0';
  }

  @override
  String get activityActionBranchCreated => 'إضافة فرع';

  @override
  String get activityActionBranchUpdated => 'تعديل فرع';

  @override
  String get activityActionBranchHoursUpdated => 'تغيير مواعيد العمل';

  @override
  String get activityActionBranchStatusChanged => 'تغيير حالة فرع';

  @override
  String get activityActionDefaultBranchChanged => 'تغيير الفرع الافتراضي';

  @override
  String get activityActionPricesUpdated => 'تغيير الأسعار';

  @override
  String get activityActionProfileUpdated => 'تعديل الملف الشخصي';

  @override
  String get activityActionSpecialtyChanged => 'تغيير التخصص';

  @override
  String get activityActionAssistantCreated => 'إضافة مساعد';

  @override
  String get activityActionAssistantUpdated => 'تعديل مساعد';

  @override
  String get activityActionPermissionsChanged => 'تغيير الصلاحيات';

  @override
  String get activityActionAssistantPasswordReset =>
      'إعادة تعيين كلمة مرور مساعد';

  @override
  String get activityActionAssistantDisabled => 'إيقاف مساعد';

  @override
  String get activityActionAssistantEnabled => 'تفعيل مساعد';

  @override
  String get activityActionAssistantRemoved => 'إزالة مساعد';

  @override
  String get activityActionPasswordChanged => 'تغيير كلمة المرور';

  @override
  String get activityActionPasswordSet => 'اختيار كلمة المرور';

  @override
  String get activityActionPasswordResetRequested => 'طلب كلمة مرور جديدة';

  @override
  String get activityActionRegistrationSent => 'إرسال التسجيل';

  @override
  String get activityActionEmailVerified => 'تأكيد البريد';

  @override
  String get assistantNotAddedYet => 'لم يُضف بعد';

  @override
  String get assistantNameHint => 'الاسم الأول واسم العائلة على الأقل';

  @override
  String get activityPatientCreated => 'أضاف مريضاً جديداً';

  @override
  String get activityPatientLinked => 'أضاف مريضاً لديه حساب بالفعل';

  @override
  String get activityPatientUpdated => 'عدّل بيانات المريض';

  @override
  String get activityPatientPhoneChanged => 'غيّر رقم موبايل المريض';

  @override
  String get activityPatientPasswordReset => 'أعاد تعيين كلمة مرور المريض';

  @override
  String get activityPatientArchived => 'نقل ملف المريض إلى الأرشيف';

  @override
  String get activityPatientUnarchived => 'أعاد ملف المريض من الأرشيف';

  @override
  String get activityPatientMedicalProfileUpdated => 'عدّل الملف الطبي';

  @override
  String get activitySessionCreatedExamination => 'سجّل كشفاً';

  @override
  String get activitySessionCreatedConsultation => 'سجّل استشارة';

  @override
  String get activitySessionClinicalUpdated => 'عدّل البيانات الطبية لزيارة';

  @override
  String get activitySessionPrivateNoteUpdated => 'عدّل الملاحظة الخاصة لزيارة';

  @override
  String get activitySessionAmountChanged => 'غيّر المبلغ المدفوع لزيارة';

  @override
  String get activitySessionDeleted => 'حذف زيارة';

  @override
  String activityFromTo(String before, String after) {
    return 'من $before إلى $after';
  }

  @override
  String activityReason(String reason) {
    return 'السبب: $reason';
  }

  @override
  String get activityActionPatientCreated => 'إضافة مريض';

  @override
  String get activityActionPatientLinked => 'ربط مريض';

  @override
  String get activityActionPatientUpdated => 'تعديل بيانات مريض';

  @override
  String get activityActionPatientPhoneChanged => 'تغيير موبايل مريض';

  @override
  String get activityActionPatientPasswordReset => 'إعادة تعيين كلمة مرور مريض';

  @override
  String get activityActionPatientArchived => 'أرشفة مريض';

  @override
  String get activityActionPatientUnarchived => 'إلغاء أرشفة مريض';

  @override
  String get activityActionPatientMedicalProfileUpdated => 'تعديل الملف الطبي';

  @override
  String get activityActionSessionCreated => 'تسجيل زيارة';

  @override
  String get activityActionSessionClinicalUpdated => 'تعديل بيانات زيارة';

  @override
  String get activityActionSessionPrivateNoteUpdated => 'تعديل ملاحظة خاصة';

  @override
  String get activityActionSessionAmountChanged => 'تغيير المبلغ المدفوع';

  @override
  String get activityActionSessionDeleted => 'حذف زيارة';

  @override
  String get sessionToday => 'اليوم';

  @override
  String get sessionYesterday => 'أمس';

  @override
  String sessionDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يوماً',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String get sessionTypeExamination => 'كشف';

  @override
  String get sessionTypeConsultation => 'استشارة';

  @override
  String get sessionPaymentCash => 'نقداً';

  @override
  String get sessionPaymentCard => 'بطاقة';

  @override
  String get sessionPaymentInstapay => 'إنستاباي';

  @override
  String get sessionPaymentWallet => 'محفظة إلكترونية';

  @override
  String get sessionAwaitingDoctor => 'بانتظار الطبيب';

  @override
  String get patientHasAllergies => 'لديه حساسية';

  @override
  String get patientAllergyFlag => 'حساسية';

  @override
  String patientFileNumber(String number) {
    return 'ملف $number';
  }

  @override
  String feesEquation(String examinations, String consultations, String total) {
    return '$examinations + $consultations = $total';
  }

  @override
  String feesExaminationCount(int count) {
    return '$count كشف';
  }

  @override
  String feesConsultationCount(int count) {
    return '$count استشارة';
  }

  @override
  String get patientAdd => 'إضافة مريض';

  @override
  String patientRegisterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مريض',
      many: '$count مريضاً',
      few: '$count مرضى',
      two: 'مريضان',
      one: 'مريض واحد',
      zero: 'لا يوجد مرضى',
    );
    return '$_temp0';
  }

  @override
  String get patientSearchHint => 'ابحث بالاسم أو رقم الموبايل أو رقم الملف';

  @override
  String get patientNoMatchTitle => 'لا يوجد مرضى مطابقون';

  @override
  String get patientNoMatchBody => 'جرّب اسماً أو رقماً أو فلتراً آخر.';

  @override
  String get patientFilterClear => 'مسح الفلاتر';

  @override
  String get patientEmptyTitle => 'لا يوجد مرضى بعد';

  @override
  String get patientEmptyBody => 'أضف أول مريض لفتح ملفه.';

  @override
  String get patientFilterLastVisit => 'آخر زيارة';

  @override
  String get patientFilterAny => 'الكل';

  @override
  String get patientFilterBranch => 'الفرع';

  @override
  String get patientFilterAllBranches => 'كل الفروع';

  @override
  String get patientFilterVisits => 'عدد الزيارات';

  @override
  String get patientFilterNewThisMonth => 'جدد هذا الشهر';

  @override
  String get patientFilterChronic => 'مرض مزمن';

  @override
  String get patientFilterArchived => 'المؤرشفون';

  @override
  String get patientVisitsOne => 'زيارة واحدة';

  @override
  String get patientVisitsFew => 'من 2 إلى 4 زيارات';

  @override
  String get patientVisitsMany => '5 زيارات أو أكثر';

  @override
  String get patientLastVisitThisWeek => 'هذا الأسبوع';

  @override
  String get patientLastVisitThisMonth => 'هذا الشهر';

  @override
  String get patientLastVisitNotSeen3m => 'لم يزر منذ 3 أشهر';

  @override
  String get patientLastVisitNotSeen6m => 'لم يزر منذ 6 أشهر';

  @override
  String get patientLastVisitNotSeen12m => 'لم يزر منذ سنة';

  @override
  String get patientLastVisitNever => 'لم يزر بعد';

  @override
  String get patientArchived => 'مؤرشف';

  @override
  String get patientNoVisits => 'لا توجد زيارات بعد';

  @override
  String get patientColumnFile => 'الملف';

  @override
  String get patientColumnName => 'الاسم';

  @override
  String get patientColumnPhone => 'الموبايل';

  @override
  String get patientColumnAge => 'السن';

  @override
  String get patientColumnFirstVisit => 'أول زيارة';

  @override
  String get patientColumnLastVisit => 'آخر زيارة';

  @override
  String get patientColumnVisits => 'الزيارات';

  @override
  String get patientColumnPaid => 'المدفوع';

  @override
  String get patientColumnAllergies => 'الحساسية';

  @override
  String patientVisitsSplit(int examinations, int consultations) {
    return '$examinations كشف، $consultations استشارة';
  }

  @override
  String get patientGenderMale => 'ذكر';

  @override
  String get patientGenderFemale => 'أنثى';

  @override
  String patientAgeYears(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years سنة',
      many: '$years سنة',
      few: '$years سنوات',
      two: 'سنتان',
      one: 'سنة واحدة',
      zero: 'أقل من سنة',
    );
    return '$_temp0';
  }

  @override
  String patientAgeGender(String age, String gender) {
    return '$age، $gender';
  }

  @override
  String patientVisitsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count زيارة',
      many: '$count زيارة',
      few: '$count زيارات',
      two: 'زيارتان',
      one: 'زيارة واحدة',
      zero: 'لا زيارات',
    );
    return '$_temp0';
  }

  @override
  String patientVisitsSummary(
    String visits,
    String examinations,
    String consultations,
  ) {
    return '$visits: $examinations، $consultations';
  }

  @override
  String get patientSortFileNumber => 'رقم الملف';

  @override
  String get patientSortGender => 'النوع';

  @override
  String get patientSortExaminations => 'عدد الكشوف';

  @override
  String get patientSortConsultations => 'عدد الاستشارات';

  @override
  String get patientSortFiles => 'الملفات';

  @override
  String get patientSortLinkedAt => 'تاريخ الإضافة';

  @override
  String get patientTotalPaid => 'إجمالي المدفوع';

  @override
  String patientLastVisitSemantics(String type, String date, String ago) {
    return 'آخر زيارة: $type، $date، $ago';
  }

  @override
  String get patientResetPasswordTitle => 'إعادة تعيين كلمة المرور؟';

  @override
  String patientResetPasswordBody(String name) {
    return 'سيحصل $name على كلمة مرور مؤقتة جديدة، ويُسجَّل خروجه من كل الأجهزة، ثم يختار كلمة مرور جديدة عند تسجيل الدخول.';
  }

  @override
  String get patientResetPassword => 'إعادة تعيين كلمة المرور';

  @override
  String get patientNewTemporaryPassword => 'كلمة مرور مؤقتة جديدة';

  @override
  String get patientArchiveTitle => 'أرشفة هذا المريض؟';

  @override
  String get patientUnarchiveTitle => 'إعادة هذا المريض إلى القائمة؟';

  @override
  String get patientArchiveBody =>
      'سيختفي من قائمة المرضى دون حذف أي بيانات، وتعيده أي زيارة جديدة.';

  @override
  String get patientUnarchiveBody => 'سيظهر في قائمة المرضى مرة أخرى.';

  @override
  String get patientArchive => 'أرشفة';

  @override
  String get patientUnarchive => 'إلغاء الأرشفة';

  @override
  String get patientArchivedDone => 'تمت أرشفة المريض';

  @override
  String get patientUnarchivedDone => 'عاد المريض إلى القائمة';

  @override
  String get patientMoreActions => 'إجراءات أخرى';

  @override
  String get sessionNew => 'زيارة جديدة';

  @override
  String get patientEdit => 'تعديل';

  @override
  String get patientLinkedNote =>
      'أنشأت عيادة أخرى حساب هذا المريض، لذلك ترى اسمه ورقم موبايله ونوعه وتاريخ ميلاده، والسجلات التي تضيفها عيادتك فقط.';

  @override
  String get patientDetails => 'البيانات الشخصية';

  @override
  String get patientBloodType => 'فصيلة الدم';

  @override
  String get patientNationalId => 'الرقم القومي';

  @override
  String get patientAddress => 'العنوان';

  @override
  String get patientEmergencyContact => 'جهة اتصال للطوارئ';

  @override
  String get patientNoTabs => 'صلاحياتك لا تشمل الملف الطبي لهذا المريض.';

  @override
  String get patientTabOverview => 'نظرة عامة';

  @override
  String get patientTabSessions => 'الزيارات';

  @override
  String get patientCantOpenApp => 'لا يوجد تطبيق على هذا الجهاز يمكنه فتحه.';

  @override
  String get patientCall => 'اتصال';

  @override
  String get patientWhatsApp => 'واتساب';

  @override
  String get patientFileSummary => 'ملخص الملف';

  @override
  String get patientConsultationsSinceExam => 'الاستشارات منذ آخر كشف';

  @override
  String sessionConsultationCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استشارة $count من $max منذ آخر كشف',
      zero: 'لا استشارات منذ آخر كشف (الحد $max)',
    );
    return '$_temp0';
  }

  @override
  String get patientProfileEmptyTitle => 'لا يوجد ملف طبي بعد';

  @override
  String get patientProfileEmptyBody =>
      'سجّل الحساسية والأمراض المزمنة والأدوية الحالية.';

  @override
  String get patientEditMedicalProfile => 'تعديل الملف الطبي';

  @override
  String get patientAllergies => 'الحساسية';

  @override
  String get patientChronicDiseases => 'الأمراض المزمنة';

  @override
  String get patientCurrentMedications => 'الأدوية الحالية';

  @override
  String get patientSurgeries => 'العمليات السابقة';

  @override
  String get patientFamilyHistory => 'التاريخ العائلي';

  @override
  String get patientGeneralNotes => 'ملاحظات';

  @override
  String get patientNoAllergies => 'لا توجد حساسية معروفة';

  @override
  String get patientNothingRecorded => 'لا يوجد شيء مسجل';

  @override
  String get patientSessionsEmptyTitle => 'لا توجد زيارات بعد';

  @override
  String get patientSessionsEmptyBody => 'الزيارة الأولى تكون كشفاً دائماً.';

  @override
  String get patientLoadMore => 'عرض المزيد';

  @override
  String sessionPlatformFeeShort(String amount) {
    return 'الرسوم $amount';
  }

  @override
  String sessionRecordedBy(String name) {
    return 'سجّلها $name';
  }

  @override
  String get patientCheckFields => 'راجع الحقول المحددة.';

  @override
  String get patientAddSubtitle =>
      'سيحصل المريض على حساب ورقم ملف، وتظهر كلمة المرور المؤقتة مرة واحدة فقط.';

  @override
  String get patientMobile => 'رقم الموبايل';

  @override
  String get patientMobileHint => 'يسجّل المريض الدخول به.';

  @override
  String get patientMobileLabel => 'الموبايل';

  @override
  String get patientPhoneChecking => 'جارٍ التحقق من الرقم…';

  @override
  String get patientPhoneNew => 'رقم جديد. أكمل بيانات المريض.';

  @override
  String get patientPhoneOurs => 'هذا الرقم لمريض مسجل لديك بالفعل';

  @override
  String get patientPhoneElsewhere => 'هذا الرقم له حساب على «العيادة» بالفعل';

  @override
  String get patientPhoneElsewhereBody =>
      'اربط المريض لإضافته إلى قائمتك دون إنشاء حساب جديد.';

  @override
  String get patientLinkTitle => 'هذا المريض لديه حساب بالفعل';

  @override
  String patientLinkBody(String phone) {
    return 'الرقم $phone لمريض مسجل في عيادة أخرى. الربط يضيفه إلى قائمتك برقم ملف جديد.';
  }

  @override
  String get patientLinkPrivacy =>
      'ستظهر لك بياناته الأساسية فقط (الاسم والموبايل والنوع وتاريخ الميلاد)، والسجلات التي تنشئها عيادتك.';

  @override
  String get patientLinkConfirm => 'ربط المريض';

  @override
  String get patientLinkedTitle => 'تمت إضافة المريض';

  @override
  String get patientLinkedBody =>
      'هذا المريض لديه حساب بالفعل، وتمت إضافته إلى قائمتك.';

  @override
  String get patientOpenFile => 'فتح الملف';

  @override
  String get patientErrorName => 'اكتب الاسم ثنائي على الأقل';

  @override
  String get patientErrorAge => 'اكتب سناً من 0 إلى 120';

  @override
  String get patientErrorDateOfBirth => 'تاريخ الميلاد غير صحيح';

  @override
  String get patientErrorNationalId => 'الرقم القومي يجب أن يكون 14 رقم';

  @override
  String get patientIdentity => 'البيانات الأساسية';

  @override
  String get patientFullName => 'الاسم بالكامل';

  @override
  String get patientFullNameHint => 'اسمان على الأقل';

  @override
  String get patientGender => 'النوع';

  @override
  String get patientDateOfBirth => 'تاريخ الميلاد أو السن';

  @override
  String get patientUseDate => 'تاريخ';

  @override
  String get patientUseAge => 'سن';

  @override
  String get patientAgeLabel => 'السن بالسنوات';

  @override
  String get patientYearsSuffix => 'سنة';

  @override
  String get patientDateOfBirthLabel => 'تاريخ الميلاد';

  @override
  String get patientMoreDetails => 'بيانات إضافية';

  @override
  String get patientOptional => 'اختيارية';

  @override
  String get patientNationalIdHint => '14 رقماً';

  @override
  String get patientNotSet => 'غير محددة';

  @override
  String get patientEmergencyName => 'اسم جهة الاتصال للطوارئ';

  @override
  String get patientEmergencyPhone => 'رقم جهة الاتصال للطوارئ';

  @override
  String get patientEditTitle => 'تعديل بيانات المريض';

  @override
  String get patientMedicalProfile => 'الملف الطبي';

  @override
  String get patientDiscardBody => 'لم تُحفظ تعديلاتك وستضيع.';

  @override
  String get patientSaved => 'تم الحفظ';

  @override
  String get patientNoChanges => 'لا توجد تعديلات';

  @override
  String get patientUnsaved => 'توجد تعديلات لم تُحفظ';

  @override
  String get patientPhoneChangeHint =>
      'رقم دخول المريض، ويُغيَّر وحده بعد التأكيد.';

  @override
  String get patientChangePhone => 'تغيير الرقم';

  @override
  String patientChangePhoneBody(String name) {
    return 'سيسجّل $name الدخول بالرقم الجديد، وتبقى الأجهزة المسجلة حالياً كما هي.';
  }

  @override
  String get patientNewMobile => 'رقم الموبايل الجديد';

  @override
  String get patientChangePhoneConfirm => 'تغيير الرقم';

  @override
  String get patientPhoneSame => 'هذا هو الرقم الحالي.';

  @override
  String get patientPhoneChanged =>
      'تم تغيير رقم الموبايل، وسيسجّل المريض الدخول بالرقم الجديد.';

  @override
  String get patientFamilyHistoryHint => 'مثال: الأب: سكر';

  @override
  String patientListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصراً',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا يوجد',
    );
    return '$_temp0';
  }

  @override
  String get patientListFull => 'القائمة تتسع لـ 50 عنصراً كحد أقصى.';

  @override
  String get patientListDuplicate => 'موجود في القائمة بالفعل.';

  @override
  String get patientMoveUp => 'نقل لأعلى';

  @override
  String get patientMoveDown => 'نقل لأسفل';

  @override
  String patientRemoveItem(String item) {
    return 'حذف $item';
  }

  @override
  String get patientAddItemHint => 'أضف عنصراً';

  @override
  String get patientAddItem => 'إضافة';

  @override
  String sessionConsultationLimit(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'لا يمكن تسجيل أكثر من $max استشارة متتالية. يجب تسجيل كشف أولاً.',
      few: 'لا يمكن تسجيل أكثر من $max استشارات متتالية. يجب تسجيل كشف أولاً.',
      two: 'لا يمكن تسجيل أكثر من استشارتين متتاليتين. يجب تسجيل كشف أولاً.',
      one: 'لا يمكن تسجيل أكثر من استشارة واحدة متتالية. يجب تسجيل كشف أولاً.',
    );
    return '$_temp0';
  }

  @override
  String get sessionRuleFirstVisit =>
      'هذه أول زيارة للمريض لديك، لذلك يجب أن تكون كشفاً.';

  @override
  String sessionRuleChanged(String message) {
    return 'سُجّلت زيارة لهذا المريض الآن من جهاز آخر. $message';
  }

  @override
  String get sessionStepType => 'نوع الزيارة';

  @override
  String get sessionStepDetails => 'التفاصيل والمبلغ';

  @override
  String get sessionPickType => 'اختر نوع الزيارة.';

  @override
  String sessionPicked(String type) {
    return 'تم اختيار $type';
  }

  @override
  String get sessionNext => 'التالي';

  @override
  String get sessionSave => 'حفظ الزيارة';

  @override
  String get sessionAmountRequired => 'أدخل المبلغ المحصّل';

  @override
  String get sessionClinical => 'البيانات الطبية';

  @override
  String get sessionChiefComplaint => 'الشكوى الرئيسية';

  @override
  String get sessionFindings => 'نتائج الفحص';

  @override
  String get sessionDiagnosis => 'التشخيص';

  @override
  String get sessionPatientNotes => 'ملاحظات للمريض';

  @override
  String get sessionPatientNotesHint => 'يراها المريض في تطبيقه.';

  @override
  String get sessionAmountCharged => 'المبلغ المحصّل';

  @override
  String get sessionNoPrice =>
      'لا يوجد سعر محدد لهذا الفرع. أدخل ما دفعه المريض.';

  @override
  String sessionVisitPrice(String amount) {
    return 'سعر الزيارة $amount';
  }

  @override
  String get sessionFree => 'مجاناً';

  @override
  String get sessionAmountLabel => 'المبلغ';

  @override
  String get sessionCurrency => 'ج.م';

  @override
  String get sessionAmountHint => 'يمكن تخفيضه كخصم، ولا يغيّر رسوم المنصة.';

  @override
  String get sessionFreeVisit => 'زيارة مجانية';

  @override
  String get sessionPaymentMethod => 'طريقة الدفع (اختيارية)';

  @override
  String sessionBranch(String name) {
    return 'الفرع: $name';
  }

  @override
  String get sessionChangeBranch => 'تغيير الفرع';

  @override
  String get sessionFirstVisit => 'أول زيارة لديك: كشف فقط';

  @override
  String sessionLastSession(String type, String date) {
    return 'آخر زيارة: $type، $date';
  }

  @override
  String get sessionNoPriceShort => 'لا يوجد سعر';

  @override
  String get sessionNoPriceHint => 'اكتب المبلغ في الخطوة التالية';

  @override
  String get sessionVisitPriceLabel => 'سعر الزيارة';

  @override
  String sessionPlatformFee(String amount) {
    return 'رسوم المنصة $amount';
  }

  @override
  String get sessionPrivateNote => 'ملاحظة خاصة';

  @override
  String get sessionPrivateNoteHint => 'لا تظهر للمريض';

  @override
  String get sessionPrivateNotePlaceholder => 'لا يقرؤها أحد غيرك.';

  @override
  String get sessionFollowUp => 'موعد المتابعة';

  @override
  String get sessionClearFollowUp => 'مسح موعد المتابعة';

  @override
  String sessionConfirmTitle(String type) {
    return 'حفظ كـ $type؟';
  }

  @override
  String sessionConfirmFee(String amount) {
    return 'ستُضاف رسوم قدرها $amount.';
  }

  @override
  String get sessionConfirmPatient => 'المريض';

  @override
  String get sessionConfirmBranch => 'الفرع';

  @override
  String get sessionConfirmLocked => 'لا يمكن تغيير النوع والوقت بعد الحفظ.';

  @override
  String get sessionConfirmSave => 'حفظ';

  @override
  String get sessionLater => 'قريباً';

  @override
  String get sessionSaved => 'تم حفظ الزيارة';

  @override
  String sessionSavedBody(String type, String patient, String fee) {
    return '$type للمريض $patient، وأُضيفت رسوم $fee.';
  }

  @override
  String get sessionWritePrescription => 'كتابة روشتة';

  @override
  String get sessionLabRequest => 'طلب تحاليل أو أشعة';

  @override
  String get sessionAttachFiles => 'إرفاق ملفات';

  @override
  String get sessionView => 'عرض الزيارة';

  @override
  String get sessionPickPatient => 'اختر المريض';

  @override
  String get sessionRecentPatients => 'المرضى الأحدث زيارة';

  @override
  String get sessionSearchResults => 'النتائج';

  @override
  String get sessionVitals => 'العلامات الحيوية';

  @override
  String get sessionVitalsHint => 'الضغط والنبض والحرارة والوزن والطول والسكر';

  @override
  String get sessionVitalBp => 'ضغط الدم';

  @override
  String get sessionVitalBpSys => 'الانقباضي';

  @override
  String get sessionVitalBpDia => 'الانبساطي';

  @override
  String get sessionVitalPulse => 'النبض';

  @override
  String get sessionVitalTemp => 'الحرارة';

  @override
  String get sessionVitalWeight => 'الوزن';

  @override
  String get sessionVitalHeight => 'الطول';

  @override
  String get sessionVitalGlucose => 'السكر';

  @override
  String get sessionVitalBpPair => 'أدخل قيمتي الضغط معاً.';

  @override
  String get sessionVitalUnusual => 'القيمة غير معتادة، تأكد منها';

  @override
  String get sessionNoVitals => 'لم تُسجَّل علامات حيوية';

  @override
  String get sessionRecordedByDoctor => 'الطبيب';

  @override
  String feesExaminationsFee(String amount) {
    return 'الكشوف $amount';
  }

  @override
  String feesConsultationsFee(String amount) {
    return 'الاستشارات $amount';
  }

  @override
  String get sessionDetailsTitle => 'تفاصيل الزيارة';

  @override
  String get sessionLocked => 'لا يمكن تغييره بعد الحفظ';

  @override
  String get sessionSummary => 'الزيارة';

  @override
  String get sessionTime => 'الوقت';

  @override
  String get sessionType => 'النوع';

  @override
  String get sessionBranchLabel => 'الفرع';

  @override
  String get sessionPlatformFeeLabel => 'رسوم المنصة';

  @override
  String get sessionRecordedByLabel => 'سجّلها';

  @override
  String sessionRecordedByAssistant(String name) {
    return '$name (مساعد)';
  }

  @override
  String get sessionEditAmount => 'تعديل المبلغ';

  @override
  String get sessionAmountSaved => 'تم حفظ المبلغ';

  @override
  String get sessionAmountLogged => 'يُسجَّل كل تعديل في سجل النشاط.';

  @override
  String get sessionNotRecorded => 'غير مسجل';

  @override
  String get sessionAwaitingHint =>
      'سجّلها مساعد. أضف البيانات الطبية لإزالة «بانتظار الطبيب».';

  @override
  String get sessionNoPrivateNote => 'لا توجد ملاحظة خاصة';

  @override
  String get sessionDelete => 'حذف الزيارة';

  @override
  String get sessionDeleted => 'تم حذف الزيارة';

  @override
  String get sessionNotDeletableLatest => 'لا يمكن حذف إلا آخر زيارة للمريض.';

  @override
  String get sessionNotDeletableDay =>
      'لا يمكن حذف الزيارة إلا في يوم تسجيلها.';

  @override
  String get sessionDeleteTitle => 'حذف هذه الزيارة؟';

  @override
  String get sessionDeleteBody =>
      'ستُخصم رسومها من إجمالي اليوم والشهر، ويُسجَّل الحذف مع السبب.';

  @override
  String get sessionDeleteReason => 'السبب';

  @override
  String get sessionDeleteReasonRequired => 'اكتب السبب (3 أحرف على الأقل).';

  @override
  String get sessionDeleteConfirm => 'حذف';

  @override
  String get sessionTodayTitle => 'زيارات اليوم';

  @override
  String get sessionDayTitle => 'الزيارات';

  @override
  String get sessionRecordedByAll => 'الجميع';

  @override
  String get sessionDayNoMatch => 'لا توجد زيارات مطابقة';

  @override
  String get sessionDayEmptyTitle => 'لا توجد زيارات في هذا اليوم';

  @override
  String get sessionDayEmptyBody => 'تظهر هنا الزيارات التي تسجلها مع رسومها.';

  @override
  String get sessionPreviousDay => 'اليوم السابق';

  @override
  String get sessionNextDay => 'اليوم التالي';

  @override
  String get sessionBackToToday => 'اليوم';

  @override
  String get feesPlatformFees => 'رسوم المنصة';

  @override
  String get feesCollected => 'المحصّل';

  @override
  String get feesMonthTitle => 'ملخص الشهر';

  @override
  String get feesMonthSubtitle => 'رسوم المنصة والكشوف والاستشارات';

  @override
  String get feesPreviousMonth => 'الشهر السابق';

  @override
  String get feesNextMonth => 'الشهر التالي';

  @override
  String get feesMonthTotals => 'إجمالي الشهر';

  @override
  String get feesPerBranch => 'حسب الفرع';

  @override
  String get feesMonthNoDays => 'لا توجد أيام في هذا الشهر بعد.';

  @override
  String get feesColumnDay => 'اليوم';

  @override
  String get feesColumnExaminations => 'كشف';

  @override
  String get feesColumnConsultations => 'استشارة';

  @override
  String get feesColumnAmount => 'الرسوم';

  @override
  String get feesToday => 'اليوم';

  @override
  String get feesThisMonth => 'هذا الشهر';

  @override
  String get homeAnalyticsLaterTitle => 'الرسوم البيانية والتحليلات قادمة';

  @override
  String get homeAnalyticsLaterBody =>
      'ستصل الإيرادات وتطور الزيارات والحجوزات في تحديث قادم.';

  @override
  String get homeToday => 'اليوم';

  @override
  String get homeSearchPatient => 'بحث عن مريض';

  @override
  String get homeTodaySessions => 'زيارات اليوم';

  @override
  String homeTodaySessionsIn(String branch) {
    return 'زيارات اليوم في $branch';
  }

  @override
  String get homeNoSessionsTitle => 'لا توجد زيارات اليوم بعد';

  @override
  String get homeNoSessionsBody => 'سجّل أول زيارة اليوم.';

  @override
  String get sessionErrorNotLinked => 'هذا المريض ليس ضمن قائمتك.';

  @override
  String get patientErrorAlreadyLinked => 'هذا الرقم لمريض مسجل لديك بالفعل.';

  @override
  String get patientErrorPhoneTaken => 'هذا الرقم مستخدم لحساب مريض آخر.';

  @override
  String get sessionErrorBranchArchived => 'هذا الفرع مؤرشف. اختر فرعاً آخر.';

  @override
  String get sessionErrorAmountNotEditable =>
      'لا يمكن تعديل المبلغ إلا في يوم الزيارة.';

  @override
  String get sessionNoClinical => 'لا توجد بيانات طبية بعد.';

  @override
  String sessionConsultationShort(int count, int max) {
    return '$count من $max';
  }

  @override
  String backToSection(String section) {
    return 'رجوع إلى $section';
  }

  @override
  String get trialEndedTitle => 'انتهت الفترة التجريبية المجانية';

  @override
  String get trialEndedBody =>
      'تواصل معنا لتفعيل الخدمة ومواصلة استخدام «العيادة». بيانات مرضاك وسجلاتك محفوظة كما هي.';

  @override
  String get trialEndedTitleAssistant => 'انتهت الفترة التجريبية للعيادة';

  @override
  String get trialEndedBodyAssistant =>
      'اطلب من الطبيب التواصل معنا لتفعيل الخدمة، وبعدها تتابع عملك كالمعتاد.';

  @override
  String get trialCheckAgain => 'تحقق مرة أخرى';

  @override
  String get trialStillEnded => 'لم تُفعَّل الخدمة بعد.';

  @override
  String trialBanner(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'تبقّى $days يوم على نهاية الفترة التجريبية المجانية',
      many: 'تبقّى $days يوماً على نهاية الفترة التجريبية المجانية',
      few: 'تبقّت $days أيام على نهاية الفترة التجريبية المجانية',
      two: 'تبقّى يومان على نهاية الفترة التجريبية المجانية',
      one: 'تبقّى يوم واحد على نهاية الفترة التجريبية المجانية',
      zero: 'تنتهي الفترة التجريبية المجانية اليوم',
    );
    return '$_temp0';
  }

  @override
  String get trialContactUs => 'تواصل معنا';

  @override
  String get errorTrialEnded =>
      'انتهت الفترة التجريبية المجانية. تواصل معنا لتفعيل الخدمة.';

  @override
  String get sessionFeeFreeTrial => 'مجاناً (فترة تجريبية)';

  @override
  String get sessionPlatformFeeFree => 'بدون رسوم منصة (فترة تجريبية)';

  @override
  String get sessionConfirmFeeFree =>
      'بدون رسوم: العيادة في الفترة التجريبية المجانية.';

  @override
  String sessionSavedBodyFree(String type, String patient) {
    return '$type للمريض $patient، بدون رسوم (فترة تجريبية).';
  }

  @override
  String get adminErrorServiceAlreadyActive =>
      'الخدمة مفعّلة بالفعل لهذا الطبيب، فلا توجد فترة تجريبية لمدّها.';

  @override
  String get adminErrorDoctorStatusNotChangeable =>
      'لا يمكن تنفيذ هذا لطبيب قيد المراجعة أو مرفوض أو معطّل.';

  @override
  String get adminSettingTrialDays => 'الفترة التجريبية المجانية';

  @override
  String get adminAppliesToNewDoctors =>
      'يُطبّق على الأطباء المعتمدين بعد التغيير';

  @override
  String get adminDoctorsFilterAll => 'كل الأطباء';

  @override
  String get adminSignupsFilterTrialRunning => 'في الفترة التجريبية';

  @override
  String get adminSignupsFilterTrialEnded => 'انتهت التجربة';

  @override
  String adminDoctorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طبيب',
      many: '$count طبيباً',
      few: '$count أطباء',
      two: 'طبيبان',
      one: 'طبيب واحد',
      zero: 'لا يوجد أطباء',
    );
    return '$_temp0';
  }

  @override
  String get adminTrialListEmpty => 'لا يوجد أطباء هنا';

  @override
  String get adminTrialListEmptyBody =>
      'يظهر هنا الأطباء حسب حالة فترتهم التجريبية.';

  @override
  String get adminServiceActive => 'الخدمة مفعّلة';

  @override
  String get adminTrialEnded => 'انتهت التجربة';

  @override
  String adminTrialDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'فترة تجريبية: باقي $days يوم',
      many: 'فترة تجريبية: باقي $days يوماً',
      few: 'فترة تجريبية: باقي $days أيام',
      two: 'فترة تجريبية: باقي يومان',
      one: 'فترة تجريبية: باقي يوم واحد',
      zero: 'فترة تجريبية: تنتهي اليوم',
    );
    return '$_temp0';
  }

  @override
  String get adminSectionTrial => 'الفترة التجريبية';

  @override
  String get adminServiceActiveBody =>
      'الخدمة مفعّلة، وتُحتسب رسوم المنصة على الجلسات.';

  @override
  String adminTrialRunningBody(String date) {
    return 'تنتهي الفترة التجريبية المجانية يوم $date، والجلسات حتى ذلك الحين بدون رسوم.';
  }

  @override
  String adminTrialEndedBody(String date) {
    return 'انتهت الفترة التجريبية المجانية يوم $date. لا يستطيع الطبيب ومساعدوه استخدام العيادة حتى تفعّل الخدمة أو تمدّ الفترة التجريبية.';
  }

  @override
  String get adminActivateService => 'تفعيل الخدمة';

  @override
  String adminActivateServiceTitle(String name) {
    return 'تفعيل الخدمة لـ د. $name؟';
  }

  @override
  String get adminActivateServiceBody =>
      'تنتهي الفترة التجريبية الآن، وتُحتسب رسوم المنصة على كل جلسة من الآن فصاعداً.';

  @override
  String adminServiceActivatedMessage(String name) {
    return 'تم تفعيل الخدمة لـ د. $name.';
  }

  @override
  String get adminExtendTrial => 'مدّ الفترة التجريبية';

  @override
  String adminExtendTrialTitle(String name) {
    return 'مدّ الفترة التجريبية لـ د. $name';
  }

  @override
  String get adminExtendTrialBody =>
      'تُضاف الأيام إلى نهاية الفترة التجريبية، أو إلى اليوم إن كانت قد انتهت.';

  @override
  String get adminExtendTrialDays => 'عدد الأيام';

  @override
  String adminTrialExtendedMessage(String name, String date) {
    return 'الفترة التجريبية لـ د. $name تنتهي الآن يوم $date.';
  }

  @override
  String get adminAuditServiceActivated => 'فعّل الخدمة لطبيب';

  @override
  String adminAuditTrialExtended(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'مدّ الفترة التجريبية لطبيب $days يوماً',
      few: 'مدّ الفترة التجريبية لطبيب $days أيام',
      two: 'مدّ الفترة التجريبية لطبيب يومين',
      one: 'مدّ الفترة التجريبية لطبيب يوماً واحداً',
    );
    return '$_temp0';
  }

  @override
  String get adminActionServiceActivated => 'تفعيل الخدمة';

  @override
  String get adminActionTrialExtended => 'مدّ الفترة التجريبية';

  @override
  String get catalogSetupTitle => 'بنجهّز دليل الأدوية والتحاليل';

  @override
  String get catalogSetupBody =>
      'بننزّل دليل الأدوية المصرية والتحاليل والأشعة على جهازك، عشان البحث يبقى فوري ويشتغل من غير نت.';

  @override
  String get catalogSetupMeanwhile =>
      'تقدر تكمّل شغلك عادي. لحد ما يخلص، البحث بيقترح اللي كتبته قبل كده وتقدر تكتب أي اسم.';

  @override
  String get catalogSetupWifi => 'يُفضّل استخدام Wi-Fi';

  @override
  String catalogSetupProgress(String received, String total) {
    return '$received من $total';
  }

  @override
  String catalogVersionLine(String version, String size) {
    return 'الإصدار $version · $size';
  }

  @override
  String catalogVersionTitle(String version) {
    return 'الإصدار $version';
  }

  @override
  String get catalogContinue => 'كمّل استخدام التطبيق';

  @override
  String get catalogPhaseChecking => 'بندوّر على آخر إصدار…';

  @override
  String catalogPhaseDownloading(String percent) {
    return 'جاري التنزيل… $percent٪';
  }

  @override
  String get catalogPhaseVerifying => 'بنراجع الملف ونجهّزه…';

  @override
  String get catalogPhaseReady => 'الدليل جاهز على جهازك';

  @override
  String get catalogPhaseNotPublished =>
      'لسه مفيش دليل منشور. لحد ما يتنشر، اكتب الاسم بإيدك وهيتحفظ في قايمتك.';

  @override
  String get catalogPhaseUnavailable =>
      'الدليل مش متاح على الجهاز ده. البحث هيكون في اللي كتبته قبل كده بس.';

  @override
  String get catalogFailureNetwork =>
      'مفيش اتصال بالإنترنت. «إعادة المحاولة» هتكمّل من مكان ما وقف.';

  @override
  String get catalogFailureServer =>
      'حصلت مشكلة في السيرفر. جرّب تاني بعد شوية.';

  @override
  String get catalogFailureChecksum =>
      'الملف اللي نزل مش سليم واتمسح. جرّب تاني.';

  @override
  String get catalogFailureCorrupt => 'الملف مش دليل صالح واتمسح. جرّب تاني.';

  @override
  String get catalogFailureSchema =>
      'الإصدار الجديد محتاج تحديث للتطبيق. حدّث التطبيق عشان تستخدمه.';

  @override
  String get catalogFailureStorage => 'مفيش مساحة كفاية على الجهاز.';

  @override
  String catalogStatusReady(String version) {
    return 'الإصدار $version · جاهز';
  }

  @override
  String get catalogStatusFailed => 'التنزيل وقف. افتحه عشان تعيد المحاولة.';

  @override
  String get catalogStatusNotPublished => 'لسه مفيش إصدار منشور';

  @override
  String get catalogStatusUnavailable => 'مش موجود على الجهاز ده';

  @override
  String get catalogSettingsTile => 'دليل الأدوية والتحاليل';

  @override
  String get catalogNotPublished => 'لسه مفيش إصدار منشور من الكتالوج';

  @override
  String get catalogMayBeUnavailable => 'قد لا يكون متوفرًا';

  @override
  String get catalogCustomTag => 'مُضاف';

  @override
  String get catalogTypeDrug => 'دواء';

  @override
  String get catalogTypeLab => 'تحليل';

  @override
  String get catalogTypeRadiology => 'أشعة';

  @override
  String get catalogTypeDrugs => 'أدوية';

  @override
  String get catalogTypeLabs => 'تحاليل';

  @override
  String get catalogTypeRadiologyPlural => 'أشعة';

  @override
  String get catalogReportMissing => 'عنصر ناقص';

  @override
  String get catalogReportWrong => 'بيانات غلط';

  @override
  String get catalogReportOther => 'حاجة تانية';

  @override
  String get catalogRouteOralSolid => 'بالفم (أقراص وكبسولات)';

  @override
  String get catalogRouteOralLiquid => 'شراب ونقط بالفم';

  @override
  String get catalogRouteInjection => 'حقن';

  @override
  String get catalogRouteTopical => 'موضعي (كريمات ومراهم)';

  @override
  String get catalogRouteEffervescent => 'فوّار';

  @override
  String get catalogRouteRectal => 'لبوس شرجي';

  @override
  String get catalogRouteEye => 'للعين';

  @override
  String get catalogRouteEar => 'للأذن';

  @override
  String get catalogRouteSpray => 'بخاخ';

  @override
  String get catalogRouteVaginal => 'مهبلي';

  @override
  String get catalogRouteMouth => 'للفم والأسنان';

  @override
  String get catalogRouteSoap => 'صابون وغسول';

  @override
  String get catalogRouteUnknown => 'غير محدد';

  @override
  String get catalogErrorShaMismatch =>
      'الملف مش مطابق للـ manifest ‏(sha256). اختار الملفين اللي طلعوا مع بعض من الـ builder.';

  @override
  String get catalogErrorManifest =>
      'الـ manifest مفيهوش sha256 سليم. اختار ملف الـ ‎.json اللي طلع مع الملف ده.';

  @override
  String get catalogErrorFileInvalid =>
      'الملف ده مش كتالوج من الـ catalog builder.';

  @override
  String catalogErrorSchema(String actual, String expected) {
    return 'صيغة الملف ده إصدار $actual والتطبيقات بتقرا إصدار $expected. اعمله بنسخة الـ catalog builder المناسبة.';
  }

  @override
  String get catalogErrorTooLarge => 'الملف أكبر من 150 ميجا.';

  @override
  String get catalogSourcesTitle => 'مصادر البيانات والتراخيص';

  @override
  String get catalogSourcesIntro =>
      'دليل الأدوية والتحاليل والأشعة في التطبيق مبني على المصادر دي. أسماء LOINC بتظهر زي ما هي منشورة بالظبط.';

  @override
  String get catalogSourceDrugsTitle => 'الأدوية';

  @override
  String get catalogSourceDrugsBody =>
      'قاعدة بيانات الأدوية المصرية Egyptian Drug Database من karem505، ومتاحة كملكية عامة بترخيص CC0. الأسعار مش بتظهر لأنها بتتغيّر بسرعة.';

  @override
  String catalogSourceDrugsDate(String date) {
    return 'البيانات بتاريخ $date';
  }

  @override
  String get catalogSourceLoincTitle => 'التحاليل والأشعة: LOINC';

  @override
  String get catalogSourceLoincBody =>
      'أسماء التحاليل وأكوادها من LOINC، ومحفوظة بنصها الأصلي. ده إشعار حقوق النشر المطلوب:';

  @override
  String catalogSourceLoincRelease(String release) {
    return 'إصدار LOINC على الجهاز ده: $release';
  }

  @override
  String get catalogSourceRadlexTitle =>
      'الأشعة: LOINC/RSNA Radiology Playbook';

  @override
  String get catalogSourceRadlexBody =>
      'أسماء الأشعة وأنواعها ومناطق الجسم من LOINC/RSNA Radiology Playbook، وفيه محتوى من RadLex:';

  @override
  String get catalogSourceOursTitle => 'الأسماء العربية والاختصارات';

  @override
  String get catalogSourceOursBody =>
      'الأسماء العربية والاختصارات زي «صورة دم كاملة» و CBC كتبها فريق «العيادة»، ومحفوظة منفصلة عن محتوى LOINC.';

  @override
  String get adminCatalogSubtitle =>
      'الأدوية والتحاليل والأشعة على أجهزة الأطباء';

  @override
  String get adminCatalogPublish => 'نشر إصدار جديد';

  @override
  String get adminCatalogTabVersions => 'الإصدارات';

  @override
  String get adminCatalogTabCustom => 'عناصر مضافة';

  @override
  String get adminCatalogTabReports => 'بلاغات الأطباء';

  @override
  String get adminCatalogCurrent => 'الإصدار الحالي';

  @override
  String get adminCatalogCurrentPill => 'الحالي';

  @override
  String get adminCatalogAllVersions => 'كل الإصدارات';

  @override
  String adminCatalogPublishedOn(String date) {
    return 'اتنشر $date';
  }

  @override
  String adminCatalogCounts(String drugs, String labs, String radiology) {
    return '$drugs دواء · $labs تحليل · $radiology أشعة';
  }

  @override
  String adminCatalogDrugSource(String date) {
    return 'بيانات الأدوية بتاريخ $date';
  }

  @override
  String adminCatalogLoincRelease(String release) {
    return 'LOINC $release';
  }

  @override
  String get adminCatalogNothingPublishedBody =>
      'لحد ما يتنشر إصدار، بحث الأطباء هيكون في اللي كتبوه قبل كده بس.';

  @override
  String get adminCatalogThisDevice => 'على الجهاز ده';

  @override
  String get adminCatalogOpenSetup => 'التفاصيل';

  @override
  String get adminCatalogPublishTitle => 'نشر إصدار جديد من الكتالوج';

  @override
  String get adminCatalogPublishBody =>
      'ارفع الملف اللي طلّعه الـ catalog builder ‏(catalog-v<n>.sqlite.gz) مع الـ manifest بتاعه. السيرفر بيراجعه وبعدين الأجهزة بتنزّله في الخلفية.';

  @override
  String get adminCatalogNoFile => 'لسه ما اخترتش ملف';

  @override
  String get adminCatalogNoManifest => 'لسه مفيش manifest ‏(.json)';

  @override
  String get adminCatalogPickFile => 'اختيار الملف';

  @override
  String get adminCatalogPickManifest => 'اختيار الـ manifest';

  @override
  String get adminCatalogChecking => 'بنراجع الـ sha256 بتاع الملف…';

  @override
  String get adminCatalogShaMatches => 'الملف مطابق للـ manifest ‏(sha256)';

  @override
  String adminCatalogUploading(String sent, String total) {
    return 'بيترفع… $sent من $total';
  }

  @override
  String get adminCatalogServerChecking => 'السيرفر بيراجع الملف…';

  @override
  String get adminCatalogDropTitle =>
      'الإصدار ده فيه عناصر أقل بكتير من الحالي:';

  @override
  String adminCatalogDropRow(String table, String previous, String current) {
    return '$table: كانت $previous وبقت $current';
  }

  @override
  String get adminCatalogDropBody =>
      'انشره بس لو ده مقصود، زي مثلاً قايمة أدوية اتنضّفت.';

  @override
  String get adminCatalogPublishAnyway => 'انشر برضه';

  @override
  String adminCatalogPublished(String version) {
    return 'اتنشر الإصدار $version';
  }

  @override
  String get adminCatalogPublishedBody =>
      'أجهزة الأطباء هتنزّله في الخلفية وتبدأ تستخدمه أول ما يخلص.';

  @override
  String get adminCatalogAllTypes => 'الكل';

  @override
  String get adminCatalogShowDisabled => 'اعرض المتوقفة';

  @override
  String get adminCatalogSearchItems => 'دوّر في العناصر';

  @override
  String get adminCatalogAddItem => 'إضافة عنصر';

  @override
  String get adminCatalogEditItem => 'تعديل العنصر';

  @override
  String get adminCatalogEdit => 'تعديل';

  @override
  String adminCatalogItemActions(String name) {
    return 'إجراءات $name';
  }

  @override
  String get adminCatalogItemBody =>
      'كل الأطباء هيلاقوه في البحث خلال دقيقة، من غير إصدار جديد للكتالوج.';

  @override
  String get adminCatalogNoItems =>
      'مفيش عناصر هنا لسه. ضيف الأدوية أو التحاليل اللي ناقصة من الكتالوج.';

  @override
  String adminCatalogItemDisabled(String name) {
    return 'اتوقف $name. هيختفي من بحث الأطباء خلال دقيقة.';
  }

  @override
  String adminCatalogItemEnabled(String name) {
    return 'رجع $name. الأطباء هيلاقوه خلال دقيقة.';
  }

  @override
  String adminCatalogUpdated(String when) {
    return 'آخر تعديل $when';
  }

  @override
  String get adminCatalogFieldTradeName => 'الاسم التجاري';

  @override
  String get adminCatalogFieldTradeNameHint =>
      'زي ما هو مكتوب على العلبة، مثلاً NEWCILLIN 500 MG 12 CAPS.';

  @override
  String get adminCatalogFieldTestName => 'الاسم';

  @override
  String get adminCatalogFieldNameAr => 'الاسم بالعربي (اختياري)';

  @override
  String get adminCatalogFieldIngredient => 'المادة الفعالة';

  @override
  String get adminCatalogFieldGroup => 'مجموعة الدواء';

  @override
  String get adminCatalogFieldRoute => 'طريقة الاستخدام';

  @override
  String get adminCatalogFieldCode => 'كود LOINC (اختياري)';

  @override
  String get adminCatalogFieldCodeHint => 'زي 2093-3';

  @override
  String get adminCatalogFieldAliases => 'أسماء مختصرة';

  @override
  String get adminCatalogFieldAliasesHint =>
      'افصل بينهم بفاصلة، زي: CBC، صورة دم';

  @override
  String get adminCatalogAliasesTooMany =>
      'لحد 10 أسماء مختصرة، كل واحد لحد 100 حرف';

  @override
  String get adminCatalogItemActive => 'ظاهر للأطباء';

  @override
  String get adminCatalogItemActiveHint =>
      'اقفله عشان يختفي من بحث كل الأطباء.';

  @override
  String get adminCatalogSave => 'حفظ';

  @override
  String get adminCatalogReportsOpen => 'مفتوحة';

  @override
  String get adminCatalogReportsDone => 'اتعملت';

  @override
  String get adminCatalogMarkDone => 'تم التعامل معاه';

  @override
  String get adminCatalogReportHandled => 'اتعلّم إنه اتعمل';

  @override
  String adminCatalogHandledOn(String date) {
    return 'اتعمل $date';
  }

  @override
  String get adminCatalogNoReports => 'مفيش بلاغات هنا.';

  @override
  String get specialtyProfilesSubtitle =>
      'اللي كل تخصص بيشوفه الأول وهو بيدوّر على الأدوية والتحاليل';

  @override
  String specialtyDoctorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طبيب',
      few: '$count أطباء',
      two: 'طبيبين',
      one: 'طبيب واحد',
      zero: 'مفيش أطباء',
    );
    return '$_temp0';
  }

  @override
  String specialtyItemsSummary(int groups, int labs, int radiology) {
    return '$groups مجموعة أدوية · $labs تحليل · $radiology أشعة';
  }

  @override
  String get specialtyGeneralBadge => 'بيتضاف لكل التخصصات';

  @override
  String get specialtyWithGeneral => 'مع الملف العام';

  @override
  String get specialtyGeneralBody => 'بيتضاف لكل تخصص مفعّل فيه الملف العام';

  @override
  String get specialtyGeneralExplained =>
      'ده الملف العام: الأدوية والتحاليل الشائعة (مسكنات، مضادات حيوية، صورة دم …) اللي بتظهر الأول في كل تخصص مفعّل فيه.';

  @override
  String specialtyUpdated(String when) {
    return 'آخر تعديل $when';
  }

  @override
  String get specialtyCatalogNotReady =>
      'الكتالوج لسه بيتنزّل على الجهاز ده؛ الأعداد والأسماء والبحث هيظهروا أول ما يخلص.';

  @override
  String get specialtyIncludeGeneral => 'ضم الملف العام';

  @override
  String get specialtyIncludeGeneralHint =>
      'المسكنات والمضادات الحيوية وحماية المعدة وصورة الدم وباقي الحاجات الشائعة تظهر الأول كمان.';

  @override
  String get specialtyGroupsTitle => 'مجموعات الأدوية';

  @override
  String get specialtyGroupsHint =>
      'الأدوية اللي في المجموعات دي بتظهر تحت «تخصصك». الرقم هو عدد المنتجات في كل مجموعة.';

  @override
  String get specialtyGroupsFilter => 'دوّر في المجموعات';

  @override
  String specialtySelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مختارة',
      two: 'اختيارين',
      one: 'اختيار واحد',
      zero: 'مفيش اختيارات',
    );
    return '$_temp0';
  }

  @override
  String get specialtyRoutesTitle => 'طرق الاستخدام المفضلة';

  @override
  String get specialtyRoutesHint =>
      'بتظهر الأول جوه كل قسم، زي الشراب واللبوس للأطفال';

  @override
  String get specialtyLabsTitle => 'تحاليل مقترحة';

  @override
  String get specialtyNoLabs => 'مفيش تحاليل مقترحة لسه.';

  @override
  String get specialtyAddLab => 'دوّر في الكتالوج عشان تضيف تحليل';

  @override
  String get specialtyRadiologyTitle => 'الأشعة';

  @override
  String get specialtyRadiologyHint =>
      'الأشعة على مناطق الجسم دي أو من الأنواع دي بتظهر تحت «تخصصك»';

  @override
  String get specialtyRegions => 'مناطق الجسم';

  @override
  String get specialtyModalities => 'أنواع الأشعة';

  @override
  String get specialtyProcedures => 'أشعة مقترحة';

  @override
  String get specialtyNoProcedures => 'مفيش أشعة مقترحة لسه.';

  @override
  String get specialtyAddProcedure => 'دوّر في الكتالوج عشان تضيف أشعة';

  @override
  String specialtyShowAll(int count) {
    return 'اعرض الكل ($count)';
  }

  @override
  String get specialtyShowFewer => 'اعرض أقل';

  @override
  String get specialtyRemove => 'شيل';

  @override
  String get specialtyCopyTitle => 'نسخ من تخصص تاني';

  @override
  String specialtyCopyConfirmTitle(String name) {
    return 'ننسخ ملف $name؟';
  }

  @override
  String get specialtyCopyConfirmBody =>
      'مجموعات الأدوية وطرق الاستخدام والتحاليل والأشعة بتاعته هتحل محل اللي هنا. تقدر تعدّلهم بعد كده.';

  @override
  String get specialtyCopy => 'انسخ';

  @override
  String specialtyCopied(String name) {
    return 'اتنسخ من $name';
  }

  @override
  String get specialtyPreviewTitle => 'معاينة البحث';

  @override
  String get specialtyPreviewHint =>
      'اللي دكتور التخصص ده هيشوفه الأول، بالتعديلات اللي لسه ما اتحفظتش';

  @override
  String get specialtyPreviewTests => 'تحاليل وأشعة';

  @override
  String get specialtyPreviewDrugsSample => 'جرّب: ator أو omep أو بنادول';

  @override
  String get specialtyPreviewTestsSample => 'جرّب: CBC أو سونار أو echo';

  @override
  String get specialtyPreviewNothing => 'مفيش نتايج.';

  @override
  String get regWelcomeTitle => 'أهلاً بك في العيادة';

  @override
  String regWelcomeTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'معك فترة تجريبية مجانية لمدة $days يوم.',
      many: 'معك فترة تجريبية مجانية لمدة $days يوماً.',
      few: 'معك فترة تجريبية مجانية لمدة $days أيام.',
      two: 'معك فترة تجريبية مجانية لمدة يومين.',
      one: 'معك فترة تجريبية مجانية لمدة يوم واحد.',
    );
    return '$_temp0';
  }

  @override
  String get regWelcomeBody =>
      'أضف مرضاك وسجّل جلساتك بدون رسوم منصة خلال الفترة التجريبية.';

  @override
  String get regWelcomeStart => 'ابدأ الآن';

  @override
  String get adminDoctorTitle => 'حساب طبيب';

  @override
  String get emailBannerDismiss => 'إخفاء الآن';

  @override
  String get settingsVerifyEmail => 'تأكيد البريد الإلكتروني';

  @override
  String get patientTabFiles => 'الملفات';

  @override
  String get recordCategoryAll => 'الكل';

  @override
  String get recordCategoryRadiology => 'أشعة';

  @override
  String get recordCategoryLab => 'تحاليل';

  @override
  String get recordCategoryPrescription => 'روشتات';

  @override
  String get recordCategoryOther => 'أخرى';

  @override
  String recordChip(String name, int count) {
    return '$name $count';
  }

  @override
  String get recordOtherReport => 'تقرير طبي';

  @override
  String get recordOtherReferral => 'تحويل';

  @override
  String get recordOtherSickLeave => 'إجازة مرضية';

  @override
  String get recordOtherEcg => 'رسم قلب';

  @override
  String get recordOtherEegEmg => 'رسم مخ / أعصاب';

  @override
  String get recordOtherEndoscopy => 'منظار';

  @override
  String get recordOtherConsent => 'إقرار';

  @override
  String get recordOtherCustom => 'نوع آخر (اكتبه)';

  @override
  String get recordOtherNone => 'بدون نوع';

  @override
  String get recordsEmptyTitle => 'لا توجد ملفات بعد';

  @override
  String get recordsEmptyBody =>
      'امسح أو ارفع نتائج التحاليل والأشعة وأي أوراق أخرى. يراها المريض في تطبيقه.';

  @override
  String get recordsEmptyCategory => 'لا توجد ملفات في هذا التصنيف';

  @override
  String get recordAddFiles => 'رفع ملفات';

  @override
  String get recordScan => 'مسح ضوئي';

  @override
  String get recordDropHint => 'أفلت الملفات لرفعها';

  @override
  String recordFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفاً',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String recordPagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صفحة',
      many: '$count صفحة',
      few: '$count صفحات',
      two: 'صفحتان',
      one: 'صفحة واحدة',
    );
    return '$_temp0';
  }

  @override
  String sizeBytes(String value) {
    return '$value بايت';
  }

  @override
  String sizeKb(String value) {
    return '$value ك.ب';
  }

  @override
  String sizeMb(String value) {
    return '$value ميجا';
  }

  @override
  String get recordUploadTitle => 'رفع ملفات';

  @override
  String get recordScanTitle => 'مسح مستند';

  @override
  String get recordEditTitle => 'تعديل بيانات الملف';

  @override
  String get recordFieldCategory => 'التصنيف';

  @override
  String get recordFieldOtherType => 'نوع المستند (اختياري)';

  @override
  String get recordFieldOtherTypeText => 'اكتب النوع';

  @override
  String get recordFieldTitle => 'العنوان (اختياري)';

  @override
  String recordTitleHint(String title) {
    return 'لو تركته فارغاً: $title';
  }

  @override
  String get recordFieldDate => 'تاريخ المستند';

  @override
  String get recordFieldNotes => 'ملاحظات (اختياري)';

  @override
  String get recordFieldSession => 'ربط بزيارة';

  @override
  String get recordNoSession => 'بدون زيارة';

  @override
  String recordSessionOption(String type, String date) {
    return '$type · $date';
  }

  @override
  String get recordCategoryRequired => 'اختر التصنيف';

  @override
  String get recordFilesHeading => 'الملفات';

  @override
  String get recordDetailsHeading => 'البيانات';

  @override
  String get recordAddMore => 'إضافة ملفات';

  @override
  String get recordFromFiles => 'اختيار ملفات';

  @override
  String get recordFromCamera => 'الكاميرا';

  @override
  String get recordFromGallery => 'الصور';

  @override
  String get recordSave => 'حفظ في ملف المريض';

  @override
  String get recordSaved => 'تم الحفظ في ملف المريض';

  @override
  String get recordUpdated => 'تم حفظ بيانات الملف';

  @override
  String get recordPreparing => 'جارٍ تصغير الحجم…';

  @override
  String recordUploading(int percent) {
    return 'جارٍ الرفع $percent%';
  }

  @override
  String get recordUploaded => 'تم الرفع';

  @override
  String get recordUploadFailed => 'فشل الرفع';

  @override
  String get recordRemoveFile => 'إزالة';

  @override
  String recordTooLarge(int mb) {
    return 'حجم الملف أكبر من المسموح ($mb ميجا)';
  }

  @override
  String recordSavedSpace(String from, String to) {
    return 'تم تقليل الحجم من $from إلى $to';
  }

  @override
  String get recordWaitForUploads =>
      'انتظر حتى تُرفع كل الملفات، أو أزل الملفات التي فشلت.';

  @override
  String get recordNeedFiles => 'أضف ملفاً واحداً على الأقل';

  @override
  String get recordUploadExpired => 'انتهت مهلة هذا الملف. ارفعه مرة أخرى.';

  @override
  String get recordErrorInvalidSession => 'اختر زيارة من زيارات هذا المريض';

  @override
  String get recordErrorInvalidDate =>
      'تاريخ المستند لا يمكن أن يكون في المستقبل';

  @override
  String get recordErrorTooMany => 'الملف الواحد يحمل 20 مرفقاً على الأكثر';

  @override
  String get recordNoFilesYet => 'لم تُضف ملفات بعد';

  @override
  String get recordScanReviewTitle => 'راجع الصفحات';

  @override
  String get recordScanAddPages => 'مسح صفحات أخرى';

  @override
  String recordScanPage(int number) {
    return 'صفحة $number';
  }

  @override
  String get recordScanMoveEarlier => 'تقديم';

  @override
  String get recordScanMoveLater => 'تأخير';

  @override
  String get recordScanDeletePage => 'حذف الصفحة';

  @override
  String get recordScanMakePdf => 'تجميعها في ملف PDF';

  @override
  String get recordScanBuilding => 'جارٍ تجهيز ملف PDF…';

  @override
  String get recordScanUnavailable => 'الماسح الضوئي غير متاح على هذا الجهاز.';

  @override
  String get recordScanDenied =>
      'اسمح باستخدام الكاميرا من الإعدادات للمسح الضوئي.';

  @override
  String get recordScanFailed => 'لم ينجح المسح. حاول مرة أخرى.';

  @override
  String get recordDetails => 'البيانات';

  @override
  String get recordOpenWith => 'فتح باستخدام…';

  @override
  String get recordDownload => 'تنزيل';

  @override
  String get recordShare => 'مشاركة';

  @override
  String get recordEdit => 'تعديل البيانات';

  @override
  String get recordDelete => 'حذف';

  @override
  String get recordDeleteTitle => 'حذف هذا الملف؟';

  @override
  String get recordDeleteBody => 'سيختفي من ملف المريض، عندك وعند المريض.';

  @override
  String get recordDeleted => 'تم حذف الملف';

  @override
  String get recordDownloaded => 'تم حفظ الملف';

  @override
  String get recordCantOpen =>
      'لا يوجد تطبيق على هذا الجهاز يفتح هذا النوع من الملفات.';

  @override
  String get recordNoPreview => 'هذا النوع من الملفات يُفتح في تطبيق آخر.';

  @override
  String get recordPdfFailed => 'تعذّر عرض ملف PDF هنا. افتحه بتطبيق آخر.';

  @override
  String recordAttachmentOf(int index, int count) {
    return '$index من $count';
  }

  @override
  String recordAdded(String date) {
    return 'أُضيف $date';
  }

  @override
  String get recordSize => 'الحجم';

  @override
  String get recordSourceScan => 'مسح ضوئي';

  @override
  String get recordSourceUpload => 'مرفوع';

  @override
  String get recordSourceChat => 'من المحادثة';

  @override
  String get recordVisit => 'الزيارة';

  @override
  String get recordPrevious => 'الملف السابق';

  @override
  String get recordNext => 'الملف التالي';

  @override
  String get recordLoadingFile => 'جارٍ فتح الملف…';

  @override
  String get activityRecordCreated => 'أضاف ملفاً إلى ملف المريض';

  @override
  String get activityRecordUpdated => 'عدّل بيانات ملف';

  @override
  String get activityRecordDeleted => 'حذف ملفاً';

  @override
  String get activityActionRecordCreated => 'إضافة ملف';

  @override
  String get activityActionRecordUpdated => 'تعديل ملف';

  @override
  String get activityActionRecordDeleted => 'حذف ملف';

  @override
  String get patientTabPrescriptions => 'الروشتات';

  @override
  String get rxKindMedication => 'روشتة علاج';

  @override
  String get rxKindInvestigations => 'روشتة تحاليل وأشعة';

  @override
  String get rxKindMedicationHint => 'أدوية بالجرعة والمواعيد والمدة';

  @override
  String get rxKindInvestigationsHint => 'تحاليل وأشعة';

  @override
  String get rxNewTitle => 'روشتة جديدة';

  @override
  String get rxNewMedication => 'روشتة علاج جديدة';

  @override
  String get rxNewInvestigations => 'طلب تحاليل وأشعة';

  @override
  String get rxStatusDraft => 'مسودة';

  @override
  String get rxStatusReadyForReview => 'جاهزة للمراجعة';

  @override
  String get rxStatusSent => 'مُرسلة';

  @override
  String get rxStatusCancelled => 'ملغاة';

  @override
  String get rxNoItems => 'لا توجد عناصر بعد';

  @override
  String rxItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصراً',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'بدون عناصر',
    );
    return '$_temp0';
  }

  @override
  String rxPreparedBy(String name) {
    return 'أعدّها $name';
  }

  @override
  String get rxListSeparator => '، ';

  @override
  String get rxSessionCardTitle => 'الروشتات والطلبات';

  @override
  String get rxSessionEmpty => 'لا توجد روشتة لهذه الزيارة بعد.';

  @override
  String get rxEmptyTitle => 'لا توجد روشتات بعد';

  @override
  String get rxEmptyBody =>
      'اكتب روشتة علاج أو طلب تحاليل وأشعة من إحدى زيارات اليوم.';

  @override
  String get rxPickSession => 'لأي زيارة؟';

  @override
  String get rxNoSessionTodayTitle => 'لا توجد زيارة اليوم';

  @override
  String get rxNoSessionTodayBody =>
      'كل روشتة تتبع زيارة. سجّل زيارة اليوم أولاً ثم اكتب الروشتة منها.';

  @override
  String get rxDiagnosis => 'التشخيص';

  @override
  String get rxMedicines => 'الأدوية';

  @override
  String get rxTests => 'الفحوصات';

  @override
  String get rxNoMedicinesYet => 'أضف أول دواء.';

  @override
  String get rxNoTestsYet => 'أضف أول فحص.';

  @override
  String get rxAddMedicine => 'إضافة دواء';

  @override
  String get rxEditMedicine => 'تعديل الدواء';

  @override
  String get rxAddTest => 'إضافة فحص';

  @override
  String get rxEditTest => 'تعديل الفحص';

  @override
  String get rxAddToPrescription => 'إضافة';

  @override
  String get rxAdvice => 'نصائح عامة';

  @override
  String get rxRequestNotes => 'ملاحظات';

  @override
  String get rxFollowUp => 'موعد المتابعة';

  @override
  String get rxResultsOn => 'إحضار النتائج في';

  @override
  String get rxClearDate => 'مسح التاريخ';

  @override
  String get rxSaveDraft => 'حفظ المسودة';

  @override
  String get rxDraftSaved => 'تم الحفظ';

  @override
  String get rxPreview => 'معاينة';

  @override
  String get rxSubmitForReview => 'إرسال للطبيب للمراجعة';

  @override
  String get rxSubmittedForReview => 'تم الإرسال للطبيب للمراجعة.';

  @override
  String get rxMore => 'المزيد';

  @override
  String get rxSaveAsTemplate => 'حفظ كقالب';

  @override
  String get rxDeleteDraft => 'حذف المسودة';

  @override
  String get rxDeleteDraftTitle => 'حذف هذه المسودة؟';

  @override
  String get rxDeleteDraftBody => 'المريض لم يرها. لا يمكن التراجع عن الحذف.';

  @override
  String get rxDraftDeleted => 'تم حذف المسودة.';

  @override
  String get rxItemRemoved => 'تم حذف العنصر.';

  @override
  String get rxUndo => 'تراجع';

  @override
  String get rxRemoveItem => 'حذف';

  @override
  String get rxDragToReorder => 'اسحب لتغيير الترتيب';

  @override
  String get rxFromTemplate => 'من قالب';

  @override
  String get rxNoTemplates => 'لا توجد قوالب بعد';

  @override
  String get rxNoTemplatesBody =>
      'احفظ أي روشتة كقالب من قائمة «المزيد» لتستخدمها مرة أخرى.';

  @override
  String get rxTemplateName => 'اسم القالب';

  @override
  String get rxTemplateSaved => 'تم حفظ القالب.';

  @override
  String get rxErrorEmpty => 'أضف عنصراً واحداً على الأقل.';

  @override
  String get rxErrorNotEditable =>
      'هذه الروشتة أُرسلت أو أُلغيت ولا يمكن تعديلها.';

  @override
  String get rxErrorNotSent => 'لا يمكن إلغاء إلا روشتة مُرسلة.';

  @override
  String get rxErrorInvalidCopySource =>
      'يمكن إصدار نسخة جديدة فقط من روشتة مُرسلة أو ملغاة لنفس المريض.';

  @override
  String get rxErrorInvalidSession => 'اختر إحدى زيارات هذا المريض.';

  @override
  String get rxErrorInvalidDate => 'اختر تاريخاً صحيحاً.';

  @override
  String get rxErrorTooMany => 'عدد العناصر أكبر من المسموح.';

  @override
  String get rxSearchMedicine =>
      'ابحث عن دواء (الاسم التجاري أو المادة الفعالة)';

  @override
  String get rxSearchLab => 'ابحث عن تحليل';

  @override
  String get rxSearchRadiology => 'ابحث عن أشعة';

  @override
  String get rxMySpecialtyOnly => 'تخصصي فقط';

  @override
  String get rxSectionUsedBefore => 'استخدمتها من قبل';

  @override
  String get rxSectionMySpecialty => 'من تخصصك';

  @override
  String get rxSectionOthers => 'من تخصصات أخرى';

  @override
  String get rxCatalogNotReady =>
      'الكتالوج لسه بيتحمّل: البحث في سجلك فقط. تقدر تكتب أي اسم.';

  @override
  String rxUseTyped(String text) {
    return 'استخدام «$text»';
  }

  @override
  String get rxNoMatches => 'لا توجد نتائج في الكتالوج.';

  @override
  String get rxDrugName => 'اسم الدواء';

  @override
  String get rxActiveIngredient => 'المادة الفعالة';

  @override
  String get rxStrength => 'التركيز';

  @override
  String get rxForm => 'الشكل';

  @override
  String get rxFormOtherText => 'الشكل (اكتبه)';

  @override
  String get rxDose => 'الجرعة';

  @override
  String get rxDoseHint => 'قرص واحد';

  @override
  String get rxFrequency => 'عدد المرات';

  @override
  String get rxFrequencyHint => 'كل 8 ساعات';

  @override
  String get rxTiming => 'التوقيت';

  @override
  String get rxTimingBeforeFood => 'قبل الأكل';

  @override
  String get rxTimingAfterFood => 'بعد الأكل';

  @override
  String get rxTimingWithFood => 'مع الأكل';

  @override
  String get rxTimingUnspecified => 'غير محدد';

  @override
  String get rxDuration => 'المدة';

  @override
  String get rxDurationCount => 'العدد';

  @override
  String get rxDurationUnitDays => 'أيام';

  @override
  String get rxDurationUnitWeeks => 'أسابيع';

  @override
  String get rxDurationContinuous => 'مستمر';

  @override
  String rxDurationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يوماً',
      few: '$count أيام',
      two: 'يومين',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String rxDurationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أسبوع',
      many: '$count أسبوعاً',
      few: '$count أسابيع',
      two: 'أسبوعين',
      one: 'أسبوع',
    );
    return '$_temp0';
  }

  @override
  String get rxInstructions => 'تعليمات';

  @override
  String get rxFormTablet => 'أقراص';

  @override
  String get rxFormCapsule => 'كبسولات';

  @override
  String get rxFormSyrup => 'شراب';

  @override
  String get rxFormInjection => 'حقن';

  @override
  String get rxFormCream => 'كريم / مرهم';

  @override
  String get rxFormDrops => 'نقط';

  @override
  String get rxFormInhaler => 'بخاخ';

  @override
  String get rxFormSuppository => 'لبوس';

  @override
  String get rxFormSachet => 'أكياس';

  @override
  String get rxFormOther => 'أخرى';

  @override
  String get rxCategoryLab => 'تحليل';

  @override
  String get rxCategoryRadiology => 'أشعة';

  @override
  String get rxTestName => 'اسم الفحص';

  @override
  String get rxTestNotes => 'ملاحظات';

  @override
  String get rxTestNotesHint => 'صائم 12 ساعة';

  @override
  String get rxEdit => 'تعديل';

  @override
  String get rxSend => 'إرسال للمريض';

  @override
  String get rxSendTitle => 'إرسال للمريض؟';

  @override
  String get rxSendBody =>
      'سيصل للمريض في التطبيق فوراً. لا يمكن تعديل الروشتة بعد الإرسال: للتصحيح ألغِها وأصدر نسخة جديدة.';

  @override
  String get rxSendAndPrint => 'إرسال وطباعة';

  @override
  String get rxSendAndPrintTitle => 'إرسال وطباعة؟';

  @override
  String get rxSendAndPrintBody =>
      'الطباعة ترسلها للمريض في نفس اللحظة، علشان الورقة والتطبيق يكونوا متطابقين دايماً.';

  @override
  String get rxSent => 'تم الإرسال للمريض.';

  @override
  String get rxPrint => 'طباعة';

  @override
  String get rxPrintAll => 'طباعة الكل';

  @override
  String get rxShare => 'مشاركة PDF';

  @override
  String get rxPrintFailed => 'لم تنجح الطباعة. حاول مرة أخرى.';

  @override
  String get rxCancelAction => 'إلغاء الروشتة';

  @override
  String get rxCancelTitle => 'إلغاء هذه الروشتة؟';

  @override
  String get rxCancelBody =>
      'سيراها المريض مشطوبة مع السبب. بعدها تقدر تصدر نسخة جديدة.';

  @override
  String get rxCancelReason => 'السبب';

  @override
  String get rxCancelConfirm => 'إلغاء الروشتة';

  @override
  String get rxCancelled => 'تم إلغاء الروشتة.';

  @override
  String get rxCancelledNotice => 'ملغاة ولا يمكن طباعتها.';

  @override
  String rxCancelledReason(String reason) {
    return 'ملغاة: $reason';
  }

  @override
  String get rxNewCopy => 'إصدار نسخة جديدة';

  @override
  String get rxPreviewFailed => 'تعذّر عرض المعاينة.';

  @override
  String get rxSettingsTitle => 'رأس الروشتة والطباعة';

  @override
  String get rxSettingsSubtitle => 'شكل روشتاتك على الورق وفي تطبيق المريض.';

  @override
  String get rxSettingsTileHint => 'الشعار والتوقيع واللون واللغة والورق';

  @override
  String get rxSettingsHeaderGroup => 'رأس الروشتة';

  @override
  String get rxSettingsNamesHint =>
      'الأسماء والألقاب والدرجات من ملفك الشخصي، والفروع في أسفل الروشتة من صفحة الفروع.';

  @override
  String get rxLogo => 'شعار العيادة';

  @override
  String get rxSignature => 'التوقيع';

  @override
  String get rxUploadImage => 'رفع';

  @override
  String get rxReplaceImage => 'تغيير';

  @override
  String get rxRemoveImage => 'حذف';

  @override
  String get rxImagesGroup => 'صور';

  @override
  String get rxSettingsColor => 'لون العيادة';

  @override
  String get rxSettingsHex => 'كود اللون';

  @override
  String get rxSettingsFooter => 'نص أسفل الروشتة';

  @override
  String get rxSettingsFooterHint => 'اختياري، مثلاً أيام العمل.';

  @override
  String get rxSettingsPrintGroup => 'اللغة والورق';

  @override
  String get rxSettingsLanguage => 'لغة الروشتة';

  @override
  String get rxSettingsArabic => 'العربية';

  @override
  String get rxSettingsEnglish => 'English';

  @override
  String get rxSettingsPaper => 'الورق';

  @override
  String get rxPaperA5 => 'A5';

  @override
  String get rxPaperA4 => 'A4';

  @override
  String get rxPaperCustom => 'مقاس خاص';

  @override
  String get rxPaperWidth => 'العرض';

  @override
  String get rxPaperHeight => 'الطول';

  @override
  String get rxMm => 'مم';

  @override
  String get rxPreprinted => 'ورق مطبوع مسبقاً';

  @override
  String get rxPreprintedHint =>
      'لورق العيادة المطبوع: لا يُطبع الرأس والتذييل، ويبدأ النص من الهامش العلوي.';

  @override
  String get rxMarginTop => 'الهامش العلوي';

  @override
  String get rxMarginBottom => 'الهامش السفلي';

  @override
  String get rxSettingsPreview => 'معاينة مباشرة';

  @override
  String get rxTestPrint => 'طباعة تجريبية';

  @override
  String get rxSettingsSaved => 'تم حفظ إعدادات الطباعة.';

  @override
  String get rxSamplePatient => 'مريض تجريبي';

  @override
  String get rxSampleDiagnosis => 'التهاب اللوزتين الحاد';

  @override
  String get rxSampleAdvice => 'راحة ومشروبات دافئة.';

  @override
  String get rxSampleDose => 'قرص';

  @override
  String get rxSampleFrequency => 'كل 12 ساعة';

  @override
  String get rxSampleWhenNeeded => 'عند اللزوم';

  @override
  String get rxTemplatesTitle => 'القوالب والمفضلة';

  @override
  String get rxTemplatesSubtitle => 'أعد استخدام الروشتات التي تكتبها كثيراً.';

  @override
  String get rxTemplatesTileHint =>
      'الروشتات المحفوظة والعناصر الأكثر استخداماً';

  @override
  String get rxTemplatesGroup => 'القوالب';

  @override
  String get rxRenameTemplate => 'إعادة تسمية';

  @override
  String get rxDeleteTemplate => 'حذف القالب';

  @override
  String get rxDeleteTemplateTitle => 'حذف هذا القالب؟';

  @override
  String rxDeleteTemplateBody(String name) {
    return 'سيتم حذف «$name». الروشتات التي استخدمته تبقى كما هي.';
  }

  @override
  String get rxTemplateDeleted => 'تم حذف القالب.';

  @override
  String get rxFrequentGroup => 'الأكثر استخداماً';

  @override
  String get rxFrequentHint =>
      'تظهر أولاً عند البحث. احذف أي عنصر لإيقاف اقتراحه.';

  @override
  String get rxNoHistory => 'ستظهر هنا العناصر التي تكتبها.';

  @override
  String rxUsedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استُخدم $count مرة',
      many: 'استُخدم $count مرة',
      few: 'استُخدم $count مرات',
      two: 'استُخدم مرتين',
      one: 'استُخدم مرة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get rxRemoveFromHistory => 'إزالة من الاقتراحات';

  @override
  String rxHistoryItemRemoved(String name) {
    return 'تمت إزالة «$name» من الاقتراحات.';
  }

  @override
  String rxPdfTitle(String kind) {
    return '$kind — العيادة';
  }

  @override
  String get rxPdfDiagnosis => 'التشخيص:';

  @override
  String get rxPdfInstructions => 'تعليمات:';

  @override
  String get rxPdfNotes => 'ملاحظات:';

  @override
  String rxPdfFollowUp(String date) {
    return 'موعد المتابعة: $date';
  }

  @override
  String rxPdfResultsOn(String date) {
    return 'إحضار النتائج في: $date';
  }

  @override
  String get rxPdfTestsIntro => 'مطلوب عمل الفحوصات الآتية:';

  @override
  String get rxPdfLabGroup => 'تحاليل';

  @override
  String get rxPdfRadiologyGroup => 'أشعة';

  @override
  String get rxPdfPatient => 'المريض';

  @override
  String get rxPdfDate => 'التاريخ';

  @override
  String get rxPdfAge => 'السن';

  @override
  String rxPdfAgeValue(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years سنة',
      many: '$years سنة',
      few: '$years سنوات',
      two: 'سنتان',
      one: 'سنة',
      zero: 'أقل من سنة',
    );
    return '$_temp0';
  }

  @override
  String get rxPdfFile => 'رقم الملف';

  @override
  String get rxPdfVisit => 'الزيارة';

  @override
  String get rxPdfExamination => 'كشف';

  @override
  String get rxPdfConsultation => 'استشارة';

  @override
  String get rxPdfSignature => 'التوقيع';

  @override
  String get rxPdfScan => 'امسح الكود';

  @override
  String rxPdfPage(int page, int total) {
    return 'صفحة $page من $total';
  }

  @override
  String get rxPdfTel => 'ت';

  @override
  String get rxPdfWhatsapp => 'واتساب';

  @override
  String activityPrescriptionDraftCreated(String kind) {
    return 'بدأ مسودة: $kind';
  }

  @override
  String activityPrescriptionCopied(String kind) {
    return 'أصدر نسخة جديدة: $kind';
  }

  @override
  String activityPrescriptionDraftUpdated(String kind) {
    return 'عدّل مسودة: $kind';
  }

  @override
  String activityPrescriptionDraftDeleted(String kind) {
    return 'حذف مسودة: $kind';
  }

  @override
  String activityPrescriptionSubmitted(String kind) {
    return 'أرسل مسودة للمراجعة: $kind';
  }

  @override
  String activityPrescriptionSent(String kind) {
    return 'أرسل للمريض: $kind';
  }

  @override
  String activityPrescriptionCancelled(String kind) {
    return 'ألغى: $kind';
  }

  @override
  String activityRxItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصراً',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String get activityRxSettingsUpdated => 'غيّر إعدادات الطباعة';

  @override
  String get activityRxLogoUpdated => 'غيّر شعار الروشتة';

  @override
  String get activityRxLogoRemoved => 'حذف شعار الروشتة';

  @override
  String get activityRxSignatureUpdated => 'غيّر التوقيع';

  @override
  String get activityRxSignatureRemoved => 'حذف التوقيع';

  @override
  String get activityActionPrescriptionDraftCreated => 'بدء مسودة';

  @override
  String get activityActionPrescriptionDraftUpdated => 'تعديل مسودة';

  @override
  String get activityActionPrescriptionDraftDeleted => 'حذف مسودة';

  @override
  String get activityActionPrescriptionSubmitted => 'إرسال للمراجعة';

  @override
  String get activityActionPrescriptionSent => 'إرسال روشتة';

  @override
  String get activityActionPrescriptionCancelled => 'إلغاء روشتة';

  @override
  String get activityActionRxSettingsUpdated => 'إعدادات الطباعة';

  @override
  String get activityActionRxBrandingUpdated => 'الشعار أو التوقيع';
}
