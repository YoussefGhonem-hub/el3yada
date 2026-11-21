namespace El3yada.Api.Notifications;

/// <summary>A doctor suspended or reactivated (spec 10.1, BR-G7): to the doctor and all their assistants.</summary>
public static partial class NotificationTexts
{
    public const string DoctorSuspended = "doctorSuspended";
    public const string DoctorReactivated = "doctorReactivated";
    public const string DoctorServiceActivated = "doctorServiceActivated";
    public const string DoctorTrialExtended = "doctorTrialExtended";

    /// <summary>
    /// To a doctor whose account an admin created (AD6): waiting in the notification centre for their first
    /// sign-in. There is no trial, so no trial length.
    /// </summary>
    public static NotificationText AccountCreated() => new(
        DoctorWelcome,
        "أهلاً بك في «العيادة»",
        "Welcome to el3yada",
        "حسابك جاهز ويمكنك استخدام العيادة الآن.",
        "Your account is ready and you can use your clinic now.");

    /// <summary>To the doctor: the service is on after the free trial (BR-T5).</summary>
    public static NotificationText ServiceActivated() => new(
        DoctorServiceActivated,
        "تم تفعيل الخدمة",
        "Your service is active",
        "تم تفعيل الخدمة، ويمكنك الآن استخدام العيادة كالمعتاد.",
        "Your service is active. You can use your clinic as usual.");

    /// <summary>To each active assistant.</summary>
    public static NotificationText ServiceActivatedForAssistant(string doctorName) => new(
        DoctorServiceActivated,
        "تم تفعيل الخدمة",
        "The clinic's service is active",
        $"تم تفعيل خدمة عيادة د. {doctorName}، ويمكنك الآن استخدام العيادة كالمعتاد.",
        $"Dr {doctorName}'s clinic is active. You can use it as usual.");

    /// <summary>To the doctor: the free trial now ends on <paramref name="until"/> (a Cairo date).</summary>
    public static NotificationText TrialExtended(DateTime until) => new(
        DoctorTrialExtended,
        "تم مد الفترة التجريبية",
        "Your free trial is extended",
        $"تم مد الفترة التجريبية المجانية حتى {CairoDate(until)}.",
        $"Your free trial now runs until {CairoDate(until)}.");

    /// <summary>To each active assistant.</summary>
    public static NotificationText TrialExtendedForAssistant(string doctorName, DateTime until) => new(
        DoctorTrialExtended,
        "تم مد الفترة التجريبية",
        "The clinic's free trial is extended",
        $"تم مد الفترة التجريبية لعيادة د. {doctorName} حتى {CairoDate(until)}.",
        $"Dr {doctorName}'s clinic's free trial now runs until {CairoDate(until)}.");

    /// <summary>YYYY-MM-DD in Cairo time, the same in both languages.</summary>
    private static string CairoDate(DateTime utc) => Common.CairoTime.DayOf(utc).ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);

    /// <summary>To the doctor: «تم إيقاف الخدمة» with the admin's reason.</summary>
    public static NotificationText Suspended(string reason) => new(
        DoctorSuspended,
        "تم إيقاف الخدمة",
        "Your clinic is suspended",
        $"السبب: {reason}",
        $"Reason: {reason}");

    /// <summary>To each active assistant. The reason is for the doctor only, so it isn't here.</summary>
    public static NotificationText SuspendedForAssistant(string doctorName) => new(
        DoctorSuspended,
        "تم إيقاف الخدمة",
        "The clinic is suspended",
        $"تم إيقاف خدمة عيادة د. {doctorName}: لا يمكن إضافة مرضى أو تسجيل زيارات حتى إعادة التفعيل.",
        $"Dr {doctorName}'s clinic is suspended: adding patients and recording visits are paused until it is reactivated.");

    /// <summary>To the doctor: «تم إعادة تفعيل الخدمة».</summary>
    public static NotificationText Reactivated() => new(
        DoctorReactivated,
        "تم إعادة تفعيل الخدمة",
        "Your clinic is active again",
        "يمكنك الآن استخدام العيادة كالمعتاد.",
        "You can use your clinic as usual again.");

    /// <summary>To each active assistant.</summary>
    public static NotificationText ReactivatedForAssistant(string doctorName) => new(
        DoctorReactivated,
        "تم إعادة تفعيل الخدمة",
        "The clinic is active again",
        $"تم إعادة تفعيل خدمة عيادة د. {doctorName}.",
        $"Dr {doctorName}'s clinic is active again.");
}
