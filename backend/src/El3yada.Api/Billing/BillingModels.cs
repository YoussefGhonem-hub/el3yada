using System.Globalization;
using El3yada.Api.Notifications;

namespace El3yada.Api.Billing;

/// <summary>Invoices.Status values (spec 6.7).</summary>
public static class InvoiceStatuses
{
    public const string Unpaid = "unpaid";
    public const string PendingReview = "pendingReview";
    public const string Paid = "paid";
    public const string Rejected = "rejected";
    public const string Overdue = "overdue";
    public const string Waived = "waived";
    public const string NoCharge = "noCharge";

    public static readonly string[] All = [Unpaid, PendingReview, Paid, Rejected, Overdue, Waived, NoCharge];

    /// <summary>The doctor can submit a payment (BR-PAY1).</summary>
    public static bool Payable(string status) => status is Unpaid or Rejected or Overdue;

    /// <summary>The invoice still counts as money the doctor owes.</summary>
    public static readonly string[] Outstanding = [Unpaid, PendingReview, Rejected, Overdue];
}

/// <summary>Payments.Status values.</summary>
public static class PaymentStatuses
{
    public const string PendingReview = "pendingReview";
    public const string Approved = "approved";
    public const string Rejected = "rejected";
}

/// <summary>How an admin recorded a manual payment (BR-PAY4). Invoices.PaidMethod holds one of these (or <c>instapay</c>).</summary>
public static class PaidMethods
{
    public const string InstaPay = "instapay";
    public const string Cash = "cash";
    public const string BankTransfer = "bankTransfer";
    public const string Other = "other";

    public static readonly string[] Manual = [InstaPay, Cash, BankTransfer, Other];
}

/// <summary>
/// The suspension reason stored on a doctor suspended by <c>dailyBillingCheck</c> (BR-G1): <c>billing:2026-10</c>, the
/// oldest overdue month. Only these suspensions are lifted automatically (BR-G3); a suspension an admin made by hand
/// (BR-G4) has the admin's text as its reason and stays until an admin reactivates the doctor.
/// </summary>
public static class BillingSuspension
{
    public const string Prefix = "billing:";

    public static string Reason(string monthKey) => Prefix + monthKey;

    public static bool IsBilling(string? reason) => reason?.StartsWith(Prefix, StringComparison.Ordinal) == true;

    public static string? MonthOf(string? reason) => IsBilling(reason) ? reason![Prefix.Length..] : null;
}

public static class BillingLimits
{
    public const int MaxScreenshots = 3;

    /// <summary>Payment screenshots are images of 10 MB or less (spec 9.4).</summary>
    public const long ScreenshotMaxBytes = 10L * 1024 * 1024;

    public const int MaxAmountPiasters = 100_000_000;

    public const int MaxExtensionDays = 365;
}

/// <summary>Arabic and English names for notifications and texts about a billing month.</summary>
public static class MonthNames
{
    private static readonly string[] Arabic =
    [
        "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
    ];

    private static readonly string[] English =
    [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December",
    ];

    /// <summary><paramref name="monthKey"/> as <c>yyyy-MM</c>.</summary>
    public static (string Ar, string En) Of(string monthKey)
    {
        var parts = monthKey.Split('-');
        var month = int.Parse(parts[1], CultureInfo.InvariantCulture);
        return ($"{Arabic[month - 1]} {parts[0]}", $"{English[month - 1]} {parts[0]}");
    }

    public static (string Ar, string En) Of(DateOnly day) => Of(day.ToString("yyyy-MM", CultureInfo.InvariantCulture));
}

public static class Money
{
    /// <summary>Whole pounds when there are no piasters, otherwise two decimals: 4800 or 4800.50.</summary>
    public static string Egp(int piasters) =>
        piasters % 100 == 0
            ? (piasters / 100).ToString("N0", CultureInfo.InvariantCulture)
            : (piasters / 100m).ToString("N2", CultureInfo.InvariantCulture);
}

/// <summary>Notifications of the billing flow (spec 6.7 BR-G7, 6.6). Never contain patient data.</summary>
public static class BillingNotifications
{
    public const string InvoiceCreated = "invoiceCreated";
    public const string InvoiceDueSoon = "invoiceDueSoon";
    public const string InvoiceDueToday = "invoiceDueToday";
    public const string BillingSuspended = "billingSuspended";
    public const string BillingReactivated = "billingReactivated";
    public const string PaymentSubmitted = "paymentSubmitted";
    public const string PaymentApproved = "paymentApproved";
    public const string PaymentRejected = "paymentRejected";
    public const string InvoiceWaived = "invoiceWaived";
    public const string InvoicePaidManually = "invoicePaidManually";
    public const string InvoiceAdjusted = "invoiceAdjusted";
    public const string InvoiceDueDateExtended = "invoiceDueDateExtended";

    /// <summary>To the doctor at month close (BR-B5).</summary>
    public static NotificationText Created(string monthKey, int totalPiasters, DateOnly dueDate)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            InvoiceCreated,
            "فاتورة جديدة",
            "New invoice",
            $"فاتورة شهر {ar}: {Money.Egp(totalPiasters)} ج.م، تُسدّد قبل {dueDate:yyyy-MM-dd}.",
            $"Your {en} invoice: EGP {Money.Egp(totalPiasters)}, due by {dueDate:yyyy-MM-dd}.");
    }

    /// <summary>2 days before the due date.</summary>
    public static NotificationText DueSoon(string monthKey, int totalPiasters, DateOnly dueDate)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            InvoiceDueSoon,
            "فاتورتك تستحق خلال يومين",
            "Your invoice is due in 2 days",
            $"فاتورة شهر {ar} ({Money.Egp(totalPiasters)} ج.م) تستحق في {dueDate:yyyy-MM-dd}.",
            $"Your {en} invoice (EGP {Money.Egp(totalPiasters)}) is due on {dueDate:yyyy-MM-dd}.");
    }

    public static NotificationText DueToday(string monthKey, int totalPiasters)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            InvoiceDueToday,
            "فاتورتك تستحق اليوم",
            "Your invoice is due today",
            $"آخر موعد لسداد فاتورة شهر {ar} ({Money.Egp(totalPiasters)} ج.م) هو اليوم، وإلا سيتم إيقاف الخدمة.",
            $"Today is the last day to pay your {en} invoice (EGP {Money.Egp(totalPiasters)}) before the service is suspended.");
    }

    /// <summary>To the doctor when <c>dailyBillingCheck</c> suspends them (BR-G1, BR-G7).</summary>
    public static NotificationText Suspended(string monthKey)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            BillingSuspended,
            "تم إيقاف الخدمة",
            "Service suspended",
            $"تم إيقاف الخدمة لعدم سداد فاتورة شهر {ar}. برجاء السداد لإعادة التفعيل.",
            $"The service was suspended because the {en} invoice was not paid. Pay it to reactivate.");
    }

    /// <summary>To the clinic's assistants (BR-G8).</summary>
    public static NotificationText SuspendedForAssistant(string doctorName) => new(
        BillingSuspended,
        "تم إيقاف خدمة العيادة",
        "The clinic's service is suspended",
        $"تم إيقاف خدمة عيادة د. {doctorName}. يمكنك الاطلاع على البيانات فقط.",
        $"Dr {doctorName}'s clinic service is suspended. You can view data only.");

    public static NotificationText Reactivated() => new(
        BillingReactivated,
        "تمت إعادة تفعيل الخدمة",
        "Service reactivated",
        "تم سداد الفاتورة وإعادة تفعيل حسابك. يمكنك مواصلة العمل الآن.",
        "Your invoice is settled and your account is active again.");

    public static NotificationText ReactivatedForAssistant(string doctorName) => new(
        BillingReactivated,
        "تمت إعادة تفعيل العيادة",
        "The clinic is active again",
        $"عادت عيادة د. {doctorName} للعمل بشكل كامل.",
        $"Dr {doctorName}'s clinic is fully active again.");

    /// <summary>To every admin when a doctor submits a payment (AD17).</summary>
    public static NotificationText Submitted(string doctorName, string monthKey)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            PaymentSubmitted,
            "دفعة جديدة للمراجعة",
            "A payment to review",
            $"د. {doctorName} أرسل إيصال سداد فاتورة {ar}.",
            $"Dr {doctorName} submitted a payment for the {en} invoice.");
    }

    public static NotificationText Approved(string monthKey)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            PaymentApproved,
            "تم قبول الدفع",
            "Payment approved",
            $"تم قبول سداد فاتورة شهر {ar}. شكراً لك.",
            $"Your payment for the {en} invoice was approved. Thank you.");
    }

    public static NotificationText Rejected(string monthKey, string reason)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            PaymentRejected,
            "تم رفض الدفع",
            "Payment rejected",
            $"تم رفض سداد فاتورة شهر {ar}. السبب: {reason}. يمكنك إرسال إيصال جديد.",
            $"Your payment for the {en} invoice was rejected. Reason: {reason}. You can submit a new one.");
    }

    public static NotificationText Waived(string monthKey)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            InvoiceWaived,
            "تم إعفاؤك من الفاتورة",
            "Invoice waived",
            $"تم إعفاؤك من فاتورة شهر {ar}.",
            $"The {en} invoice was waived.");
    }

    public static NotificationText PaidManually(string monthKey)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            InvoicePaidManually,
            "تم تسجيل سداد الفاتورة",
            "Invoice marked as paid",
            $"تم تسجيل سداد فاتورة شهر {ar}.",
            $"The {en} invoice was marked as paid.");
    }

    public static NotificationText Adjusted(string monthKey, int totalPiasters)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            InvoiceAdjusted,
            "تم تعديل فاتورتك",
            "Invoice adjusted",
            $"تم تعديل فاتورة شهر {ar}. الإجمالي المستحق الآن {Money.Egp(totalPiasters)} ج.م.",
            $"The {en} invoice was adjusted. The total due is now EGP {Money.Egp(totalPiasters)}.");
    }

    public static NotificationText DueDateExtended(string monthKey, DateOnly dueDate)
    {
        var (ar, en) = MonthNames.Of(monthKey);
        return new(
            InvoiceDueDateExtended,
            "تم تمديد موعد السداد",
            "Due date extended",
            $"تم تمديد موعد سداد فاتورة شهر {ar} إلى {dueDate:yyyy-MM-dd}.",
            $"The due date of the {en} invoice is now {dueDate:yyyy-MM-dd}.");
    }
}
