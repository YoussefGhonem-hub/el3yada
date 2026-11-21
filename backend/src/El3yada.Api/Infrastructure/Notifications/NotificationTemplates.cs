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
    public const string CheckedIn = "checkedIn";
    public const string NextInLine = "nextInLine";
    public const string SelfBookingOff = "selfBookingOff";
    public const string StaffBookingActivity = "staffBookingActivity";
    public const string NewSignup = "newSignup";
    public const string NewPayment = "newPayment";
    public const string DeletionRequest = "deletionRequest";
    public const string Broadcast = "broadcast";

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

    /// <param name="queue">Queue mode: no number yet, turns go in order of arrival (BR-AP3).</param>
    public static NotificationMessage BookingConfirmed(string whenAr, string whenEn, Guid appointmentId, bool queue = false) => new(
        NotificationTypes.BookingConfirmed, "تم تأكيد حجزك", "Booking confirmed",
        queue ? $"{whenAr} — الدور بأسبقية الحضور" : whenAr, queue ? $"{whenEn}. Turns go in order of arrival" : whenEn,
        $"/patient/appointments/{appointmentId}", new { appointmentId });

    /// <summary>
    /// BR-AP16, queue mode, at check-in: «تم تسجيل حضورك — دورك رقم 7، وقبلك 3 مرضى», with the estimated wait
    /// (patients ahead × the branch's average visit time).
    /// </summary>
    public static NotificationMessage CheckedIn(int number, int ahead, int waitMinutes, Guid appointmentId)
    {
        var aheadText = Features.Appointments.AppointmentTexts.Ahead(ahead);
        var wait = Features.Appointments.AppointmentTexts.Minutes(waitMinutes);
        return new(
            NotificationTypes.CheckedIn, "تم تسجيل حضورك", "You're checked in",
            ahead == 0 ? $"دورك رقم {number}، {aheadText.Ar}" : $"دورك رقم {number}، {aheadText.Ar}. الانتظار المتوقع {wait.Ar}",
            ahead == 0 ? $"Your number is {number}, and {aheadText.En}" : $"Your number is {number}, and {aheadText.En}. Estimated wait {wait.En}",
            $"/patient/appointments/{appointmentId}", new { appointmentId, queueNumber = number, ahead, waitMinutes });
    }

    /// <summary>[S] BR-AP16: the patient before them went in to the doctor.</summary>
    public static NotificationMessage NextInLine(int number, Guid appointmentId) => new(
        NotificationTypes.NextInLine, "دورك التالي", "You're next",
        $"دورك رقم {number}: استعد للدخول للطبيب", $"Number {number}: get ready to go in to the doctor",
        $"/patient/appointments/{appointmentId}", new { appointmentId, queueNumber = number });

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
