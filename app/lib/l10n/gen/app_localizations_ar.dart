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
  String adminSignupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طلب منتظر',
      many: '$count طلباً منتظراً',
      few: '$count طلبات منتظرة',
      two: 'طلبان منتظران',
      one: 'طلب واحد منتظر',
      zero: 'لا توجد طلبات منتظرة',
    );
    return '$_temp0';
  }

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
  String get adminSignupsEmptyTitle => 'لا توجد طلبات تسجيل منتظرة';

  @override
  String get adminSignupsEmptyBody =>
      'تظهر طلبات الأطباء الجدد هنا فور تسجيلهم.';

  @override
  String get adminSignupsNoMatchTitle => 'لا توجد طلبات تطابق البحث';

  @override
  String get adminSignupsNoMatchBody =>
      'راجع الكتابة، أو ابحث برقم الموبايل أو رقم النقابة.';

  @override
  String get adminSelectRequest => 'اختر طلباً لمراجعته';

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
  String adminAddressBuilding(String value) {
    return 'عقار $value';
  }

  @override
  String adminAddressFloor(String value) {
    return 'الدور $value';
  }

  @override
  String adminAddressApartment(String value) {
    return 'شقة $value';
  }

  @override
  String get adminPhoneMobile => 'موبايل';

  @override
  String get adminPhoneLandline => 'أرضي';

  @override
  String get adminPhoneReception => 'الاستقبال';

  @override
  String get adminOpenMap => 'افتح الموقع على الخريطة';

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
}
