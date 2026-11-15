namespace El3yada.Api.Notifications;

public static partial class NotificationTexts
{
    public const string SessionRecorded = "sessionRecorded";

    /// <summary>
    /// To the patient (spec 10.1 «تم تسجيل زيارة جديدة»). The visit type, the doctor and the branch only: never
    /// a diagnosis or notes (spec 10.1, privacy).
    /// </summary>
    public static NotificationText VisitRecorded(bool examination, string doctorName, string branchNameAr, string branchNameEn) => new(
        SessionRecorded,
        "تم تسجيل زيارة جديدة",
        "New visit recorded",
        $"{(examination ? "كشف" : "استشارة")} لدى د. {doctorName} — {branchNameAr}",
        $"{(examination ? "Examination" : "Consultation")} with Dr {doctorName} — {branchNameEn}");
}
