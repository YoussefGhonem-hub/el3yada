using System.Text.Json;
using El3yada.Data;
using El3yada.Data.Entities;

namespace El3yada.Api.Notifications;

/// <summary>
/// Writes Notifications rows (the in-app notification centre, spec 10.1) in both languages. Like the audit
/// log, a row is added to the request's DbContext and saved with the change. Push delivery (FCM, SignalR)
/// comes in Phase 5 and will read these rows; nothing is sent from here.
/// <para>Text never contains diagnoses or file contents (spec 10.1, privacy).</para>
/// </summary>
public sealed class NotificationWriter(AppDbContext db, TimeProvider time)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public Notification Add(Guid recipientUserId, NotificationText text, string? route = null, object? data = null)
    {
        var row = new Notification
        {
            Id = Guid.NewGuid(),
            RecipientUserId = recipientUserId,
            Type = text.Type,
            TitleAr = Truncate(text.TitleAr, 150),
            TitleEn = Truncate(text.TitleEn, 150),
            BodyAr = Truncate(text.BodyAr, 500),
            BodyEn = Truncate(text.BodyEn, 500),
            Route = route,
            DataJson = data is null ? null : JsonSerializer.Serialize(data, JsonOptions),
            CreatedAt = time.GetUtcNow().UtcDateTime,
        };
        db.Notifications.Add(row);
        return row;
    }

    private static string Truncate(string value, int max) => value.Length <= max ? value : value[..(max - 1)] + "…";
}

/// <summary>A notification's type and its Arabic and English title and body.</summary>
public sealed record NotificationText(string Type, string TitleAr, string TitleEn, string BodyAr, string BodyEn);

/// <summary>Notifications (spec 10.1). Types are stable: the app may switch on them. Phase 1 here; later phases add theirs in their own files.</summary>
public static partial class NotificationTexts
{
    public const string DoctorRegistrationReceived = "doctorRegistrationReceived";
    public const string DoctorRegistrationResubmitted = "doctorRegistrationResubmitted";
    public const string DoctorRegistrationApproved = "doctorRegistrationApproved";
    public const string DoctorRegistrationRejected = "doctorRegistrationRejected";
    public const string PatientPasswordResetRequested = "patientPasswordResetRequested";
    public const string AssistantPasswordResetRequested = "assistantPasswordResetRequested";

    /// <summary>To every active admin: «طلب تسجيل جديد».</summary>
    public static NotificationText RegistrationReceived(string doctorName, string specialtyAr, string specialtyEn) => new(
        DoctorRegistrationReceived,
        "طلب تسجيل جديد",
        "New sign-up request",
        $"د. {doctorName} — {specialtyAr}",
        $"Dr {doctorName} — {specialtyEn}");

    /// <summary>To every active admin, after an edit following a rejection (A7).</summary>
    public static NotificationText RegistrationResubmitted(string doctorName, string specialtyAr, string specialtyEn) => new(
        DoctorRegistrationResubmitted,
        "طلب تسجيل معدّل",
        "Sign-up request resubmitted",
        $"د. {doctorName} — {specialtyAr}",
        $"Dr {doctorName} — {specialtyEn}");

    /// <summary>To the doctor: «تم تفعيل حسابك».</summary>
    public static NotificationText RegistrationApproved() => new(
        DoctorRegistrationApproved,
        "تم تفعيل حسابك",
        "Your account is approved",
        "تمت الموافقة على طلبك، ويمكنك الآن استخدام العيادة.",
        "Your sign-up was approved. You can start using el3yada now.");

    /// <summary>To the doctor: «تم رفض طلبك» with the admin's reason (A7).</summary>
    public static NotificationText RegistrationRejected(string reason) => new(
        DoctorRegistrationRejected,
        "تم رفض طلبك",
        "Your sign-up was not approved",
        $"السبب: {reason}",
        $"Reason: {reason}");

    /// <summary>To each linked doctor and their assistants with patientsResetPassword (A8).</summary>
    public static NotificationText PatientResetRequested(string patientName) => new(
        PatientPasswordResetRequested,
        "طلب إعادة تعيين كلمة المرور",
        "Password reset request",
        $"المريض {patientName} طلب إعادة تعيين كلمة المرور",
        $"Your patient {patientName} asked for a password reset");

    /// <summary>To the assistant's doctor (BR-AS11).</summary>
    public static NotificationText AssistantResetRequested(string assistantName) => new(
        AssistantPasswordResetRequested,
        "طلب إعادة تعيين كلمة المرور",
        "Password reset request",
        $"المساعد {assistantName} طلب إعادة تعيين كلمة المرور",
        $"Your assistant {assistantName} asked for a password reset");
}
