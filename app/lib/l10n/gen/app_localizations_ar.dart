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
}
