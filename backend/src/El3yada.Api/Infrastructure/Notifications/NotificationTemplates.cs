using El3yada.Api.Infrastructure.Auth;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Infrastructure.Notifications;

/// <summary>Notification types, stored in <c>Notifications.Type</c> and sent in the push data.</summary>
public static class NotificationTypes
{
    public const string ChatMessage = "chatMessage";
    public const string PasswordResetRequest = "passwordResetRequest";
    public const string DraftReady = "draftReady";
    public const string SessionRecorded = "sessionRecorded";
    public const string PrescriptionSent = "prescriptionSent";
    public const string PrescriptionCancelled = "prescriptionCancelled";
    public const string FileAdded = "fileAdded";
    public const string SignupApproved = "signupApproved";
    public const string SignupRejected = "signupRejected";
    public const string InvoiceCreated = "invoiceCreated";
    public const string InvoiceDue = "invoiceDue";
    public const string PaymentApproved = "paymentApproved";
    public const string PaymentRejected = "paymentRejected";
    public const string Suspended = "suspended";
    public const string Reactivated = "reactivated";
    public const string BookingConfirmed = "bookingConfirmed";
    public const string BookingPending = "bookingPending";
    public const string BookingRejected = "bookingRejected";
    public const string BookingExpired = "bookingExpired";
    public const string BookingReminder = "bookingReminder";
    public const string BookingRescheduled = "bookingRescheduled";
    public const string BookingCancelled = "bookingCancelled";
    public const string DoctorDelayed = "doctorDelayed";
    public const string TurnComing = "turnComing";
    public const string SelfBookingOff = "selfBookingOff";
    public const string StaffBookingActivity = "staffBookingActivity";
    public const string NewSignup = "newSignup";
    public const string NewPayment = "newPayment";
    public const string DeletionRequest = "deletionRequest";
    public const string Broadcast = "broadcast";
    public const string TrialEndingSoon = "trialEndingSoon";
    public const string TrialLastDay = "trialLastDay";

    public static bool IsChat(string type) => type == ChatMessage;

    public static bool IsReminder(string type) => type is BookingReminder or InvoiceDue or TurnComing;
}

/// <summary>
/// The texts of every event in spec 10.1, in Arabic and English. Endpoints build a message here
/// and pass it to <see cref="INotificationWriter"/>. Texts never contain diagnoses or file contents.
/// Phases 1–3 call, for example, <c>notifications.Add(patientUserId, NotificationTemplates.SessionRecorded(...))</c>.
/// </summary>
public static class NotificationTemplates
{
    public static NotificationMessage ChatMessage(string senderName, Guid chatId, Guid messageId, string route) => new(
        NotificationTypes.ChatMessage, $"رسالة جديدة من {senderName}", $"New message from {senderName}",
        "اضغط لفتح المحادثة", "Tap to open the chat", route, new { chatId, messageId });

    public static NotificationMessage PasswordResetRequest(string patientName, Guid patientId) => new(
        NotificationTypes.PasswordResetRequest, "طلب إعادة تعيين كلمة المرور", "Password reset request",
        $"المريض {patientName} طلب إعادة تعيين كلمة المرور", $"{patientName} asked for a password reset",
        $"/doctor/patients/{patientId}", new { patientId });

    public static NotificationMessage DraftReady(string patientName, Guid prescriptionId) => new(
        NotificationTypes.DraftReady, "مسودة روشتة جاهزة للمراجعة", "Prescription draft ready for review",
        $"المريض {patientName}", $"Patient {patientName}", $"/doctor/prescriptions/{prescriptionId}", new { prescriptionId });

    public static NotificationMessage SessionRecorded(Guid sessionId) => new(
        NotificationTypes.SessionRecorded, "تم تسجيل زيارة جديدة", "A new visit was recorded",
        "اضغط لعرض الزيارة", "Tap to see the visit", $"/patient/visits/{sessionId}", new { sessionId });

    public static NotificationMessage PrescriptionSent(string doctorName, Guid prescriptionId) => new(
        NotificationTypes.PrescriptionSent, $"روشتة جديدة من {doctorName}", $"New prescription from {doctorName}",
        "اضغط لعرض الروشتة", "Tap to see it", $"/patient/prescriptions/{prescriptionId}", new { prescriptionId });

    public static NotificationMessage PrescriptionCancelled(Guid prescriptionId) => new(
        NotificationTypes.PrescriptionCancelled, "تم إلغاء روشتة", "A prescription was cancelled",
        "اضغط للتفاصيل", "Tap for details", $"/patient/prescriptions/{prescriptionId}", new { prescriptionId });

    public static NotificationMessage FileAdded(Guid recordId) => new(
        NotificationTypes.FileAdded, "ملف جديد", "New file",
        "تم إضافة ملف جديد إلى ملفك الطبي", "A new file was added to your medical file", $"/patient/records/{recordId}", new { recordId });

    public static NotificationMessage SignupApproved() => new(
        NotificationTypes.SignupApproved, "تم تفعيل حسابك", "Your account is active",
        "يمكنك الآن استخدام التطبيق", "You can start using the app", "/doctor/live");

    public static NotificationMessage SignupRejected(string reason) => new(
        NotificationTypes.SignupRejected, "تم رفض طلبك", "Your registration was declined",
        $"السبب: {reason}", $"Reason: {reason}", "/");

    public static NotificationMessage InvoiceCreated(string monthAr, string monthEn, string amount, string dueAr, string dueEn, Guid invoiceId) => new(
        NotificationTypes.InvoiceCreated, $"فاتورة شهر {monthAr}", $"{monthEn} invoice",
        $"{amount} ج.م — آخر موعد {dueAr}", $"EGP {amount}, due {dueEn}", $"/doctor/billing/{invoiceId}", new { invoiceId });

    public static NotificationMessage InvoiceDue(string monthAr, string monthEn, Guid invoiceId) => new(
        NotificationTypes.InvoiceDue, "تذكير بالسداد", "Payment reminder",
        $"آخر موعد لسداد فاتورة {monthAr} يقترب", $"Your {monthEn} invoice is due soon", $"/doctor/billing/{invoiceId}", new { invoiceId });

    public static NotificationMessage PaymentReviewed(bool approved, string? reason, Guid invoiceId) => approved
        ? new(NotificationTypes.PaymentApproved, "تم قبول الدفع", "Payment approved", "شكراً لك", "Thank you", $"/doctor/billing/{invoiceId}", new { invoiceId })
        : new(NotificationTypes.PaymentRejected, "تم رفض الدفع", "Payment rejected", $"السبب: {reason}", $"Reason: {reason}", $"/doctor/billing/{invoiceId}", new { invoiceId });

    public static NotificationMessage Suspended() => new(
        NotificationTypes.Suspended, "تم إيقاف الخدمة", "Service suspended",
        "برجاء سداد الفاتورة المستحقة لإعادة التفعيل", "Pay the overdue invoice to reactivate", "/doctor/billing");

    public static NotificationMessage Reactivated() => new(
        NotificationTypes.Reactivated, "تم إعادة تفعيل الخدمة", "Service reactivated", "شكراً لك", "Thank you", "/doctor/live");

    public static NotificationMessage NewSignup(string doctorName, Guid doctorId) => new(
        NotificationTypes.NewSignup, "طلب تسجيل جديد", "New sign-up request", doctorName, doctorName, $"/admin/signups/{doctorId}", new { doctorId });

    public static NotificationMessage NewPayment(string doctorName, Guid paymentId) => new(
        NotificationTypes.NewPayment, "دفعة جديدة للمراجعة", "New payment to review", doctorName, doctorName, $"/admin/payments/{paymentId}", new { paymentId });

    // ---- Bookings (Phase 6) -------------------------------------------------------------------

    public static NotificationMessage BookingConfirmed(string whenAr, string whenEn, Guid appointmentId) => new(
        NotificationTypes.BookingConfirmed, "تم تأكيد حجزك", "Booking confirmed", whenAr, whenEn,
        $"/patient/appointments/{appointmentId}", new { appointmentId });

    public static NotificationMessage BookingPending(Guid appointmentId) => new(
        NotificationTypes.BookingPending, "حجزك في انتظار تأكيد العيادة", "Waiting for the clinic to confirm",
        "سنبلغك عند التأكيد", "We'll tell you when it's confirmed", $"/patient/appointments/{appointmentId}", new { appointmentId });

    public static NotificationMessage BookingNotConfirmed(Guid appointmentId, bool expired) => new(
        expired ? NotificationTypes.BookingExpired : NotificationTypes.BookingRejected,
        "لم يتم تأكيد الحجز", "Your booking wasn't confirmed",
        "برجاء اختيار موعد آخر", "Please choose another time", "/patient/appointments/book", new { appointmentId });

    public static NotificationMessage BookingReminder(string whenAr, string whenEn, Guid appointmentId) => new(
        NotificationTypes.BookingReminder, "تذكير بموعدك", "Appointment reminder", whenAr, whenEn,
        $"/patient/appointments/{appointmentId}", new { appointmentId });

    public static NotificationMessage BookingRescheduledByClinic(string whenAr, string whenEn, Guid appointmentId) => new(
        NotificationTypes.BookingRescheduled, "تم تغيير موعدك", "Your appointment was moved", $"الموعد الجديد: {whenAr}", $"New time: {whenEn}",
        $"/patient/appointments/{appointmentId}", new { appointmentId });

    public static NotificationMessage BookingCancelledByClinic(string? reason, Guid appointmentId) => new(
        NotificationTypes.BookingCancelled, "تم إلغاء موعدك", "Your appointment was cancelled",
        reason is null ? "احجز موعداً جديداً" : $"{reason} — احجز موعداً جديداً", reason is null ? "Book a new one" : $"{reason}. Book a new one",
        "/patient/appointments/book", new { appointmentId });

    public static NotificationMessage DoctorDelayed(int minutes) => new(
        NotificationTypes.DoctorDelayed, "الطبيب متأخر", "The doctor is running late",
        $"الطبيب متأخر حوالي {minutes} دقيقة", $"The doctor is about {minutes} minutes late", "/patient/appointments");

    public static NotificationMessage SelfBookingOff() => new(
        NotificationTypes.SelfBookingOff, "الحجز من التطبيق متوقف", "App booking is off",
        "برجاء الاتصال بالعيادة لحجز موعدك القادم", "Please call the clinic to book your next visit", "/patient/appointments");

    public static NotificationMessage StaffBookingActivity(string titleAr, string titleEn, string bodyAr, string bodyEn, Guid appointmentId) => new(
        NotificationTypes.StaffBookingActivity, titleAr, titleEn, bodyAr, bodyEn, $"/doctor/appointments/{appointmentId}", new { appointmentId });

    // ---- Free trial (spec 6.16, BR-T6) ---------------------------------------------------------
    // Like A15, they ask the doctor to contact us. The route opens the settings, which have the support contact; once
    // the trial has ended the app sends the doctor and assistants to A15 from any route anyway.

    private const string ContactUsAr = "تواصل معنا لتفعيل الخدمة ومواصلة استخدام العيادة.";
    private const string ContactUsEn = "Contact us to activate the service and keep using your clinic.";
    private const string AskDoctorAr = "اطلب من الطبيب التواصل معنا لتفعيل الخدمة.";
    private const string AskDoctorEn = "Ask the doctor to contact us to activate the service.";

    /// <summary>To the doctor, with 2 or 3 days left.</summary>
    public static NotificationMessage TrialEndingSoon(int daysLeft, DateTime endsAt, Guid doctorId) => new(
        NotificationTypes.TrialEndingSoon, "الفترة التجريبية تنتهي قريباً", "Your free trial ends soon",
        $"باقي {El3yada.Api.Notifications.NotificationTexts.ArabicDays(daysLeft)} على نهاية الفترة التجريبية المجانية. {ContactUsAr}",
        $"Your free trial ends in {daysLeft} {(daysLeft == 1 ? "day" : "days")}. {ContactUsEn}",
        "/doctor/settings", new { doctorId, trialEndsAt = endsAt, daysLeft });

    /// <summary>To the doctor, with less than a day left.</summary>
    public static NotificationMessage TrialLastDay(DateTime endsAt, Guid doctorId) => new(
        NotificationTypes.TrialLastDay, "آخر يوم في الفترة التجريبية", "Last day of your free trial",
        $"تنتهي الفترة التجريبية المجانية خلال 24 ساعة. {ContactUsAr}", $"Your free trial ends within 24 hours. {ContactUsEn}",
        "/doctor/settings", new { doctorId, trialEndsAt = endsAt, daysLeft = 1 });

    /// <summary>To each active assistant, with 2 or 3 days left.</summary>
    public static NotificationMessage TrialEndingSoonForAssistant(string doctorName, int daysLeft, DateTime endsAt, Guid doctorId) => new(
        NotificationTypes.TrialEndingSoon, "الفترة التجريبية للعيادة تنتهي قريباً", "The clinic's free trial ends soon",
        $"باقي {El3yada.Api.Notifications.NotificationTexts.ArabicDays(daysLeft)} على نهاية الفترة التجريبية لعيادة د. {doctorName}. {AskDoctorAr}",
        $"Dr {doctorName}'s clinic's free trial ends in {daysLeft} {(daysLeft == 1 ? "day" : "days")}. {AskDoctorEn}",
        "/assistant/settings", new { doctorId, trialEndsAt = endsAt, daysLeft });

    /// <summary>To each active assistant, with less than a day left.</summary>
    public static NotificationMessage TrialLastDayForAssistant(string doctorName, DateTime endsAt, Guid doctorId) => new(
        NotificationTypes.TrialLastDay, "آخر يوم في الفترة التجريبية للعيادة", "Last day of the clinic's free trial",
        $"تنتهي الفترة التجريبية لعيادة د. {doctorName} خلال 24 ساعة. {AskDoctorAr}", $"Dr {doctorName}'s clinic's free trial ends within 24 hours. {AskDoctorEn}",
        "/assistant/settings", new { doctorId, trialEndsAt = endsAt, daysLeft = 1 });
}

/// <summary>Who receives clinic events (spec 10.1): the doctor and the assistants with a permission.</summary>
public sealed class NotificationRecipients(AppDbContext db)
{
    /// <param name="includeDoctor">False for booking alerts, which reach the doctor only if switched on.</param>
    /// <param name="branchId">Only assistants assigned to this branch (or to all branches).</param>
    public async Task<IReadOnlyList<Guid>> StaffAsync(Guid doctorId, StaffPermission permission, Guid? branchId = null, bool includeDoctor = true, CancellationToken ct = default)
    {
        var query = db.Assistants.AsNoTracking().Where(a => a.DoctorId == doctorId && a.Status == "active");
        query = permission switch
        {
            StaffPermission.Chat => query.Where(a => a.Chat),
            StaffPermission.PatientsResetPassword => query.Where(a => a.PatientsResetPassword),
            StaffPermission.BillingView => query.Where(a => a.BillingView),
            StaffPermission.BillingPay => query.Where(a => a.BillingPay),
            StaffPermission.AppointmentsView => query.Where(a => a.AppointmentsView),
            StaffPermission.PrescriptionsDraft => query.Where(a => a.PrescriptionsDraft),
            _ => query.Where(_ => false),
        };
        if (branchId is { } b) query = query.Where(a => a.AllBranches || a.Branches.Any(x => x.Id == b));

        var ids = await query.Select(a => a.UserId).ToListAsync(ct);
        if (includeDoctor) ids.Add(doctorId);
        return ids;
    }
}
