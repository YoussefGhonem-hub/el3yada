namespace El3yada.Api.Notifications;

/// <summary>A doctor suspended or reactivated (spec 10.1, BR-G7): to the doctor and all their assistants.</summary>
public static partial class NotificationTexts
{
    public const string DoctorSuspended = "doctorSuspended";
    public const string DoctorReactivated = "doctorReactivated";

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
