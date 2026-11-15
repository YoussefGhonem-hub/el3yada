// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Doctory';

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
      'تطبيق الكمبيوتر مخصص للأطباء والمساعدين والإدارة. حمّل تطبيق Doctory على موبايلك لمتابعة ملفك الطبي وحجوزاتك.';

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
}
