namespace El3yada.Api.Notifications;

public static partial class NotificationTexts
{
    public const string DoctorSpecialtyChanged = "doctorSpecialtyChanged";

    /// <summary>To every active admin when a doctor changes their specialty in D22 (it applies at once, without review).</summary>
    public static NotificationText SpecialtyChanged(
        string doctorName, string beforeAr, string beforeEn, string afterAr, string afterEn) => new(
        DoctorSpecialtyChanged,
        "تغيير تخصص طبيب",
        "A doctor changed their specialty",
        $"د. {doctorName}: {beforeAr} ← {afterAr}",
        $"Dr {doctorName}: {beforeEn} → {afterEn}");
}
