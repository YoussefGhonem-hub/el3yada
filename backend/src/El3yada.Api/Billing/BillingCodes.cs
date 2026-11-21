using El3yada.Api.Audit;

namespace El3yada.Api
{
    public static partial class ErrorCodes
    {
        /// <summary><c>submitPayment</c> on an invoice that is paid, waived, under review or without a charge (409).</summary>
        public const string InvoiceNotPayable = "INVOICE_NOT_PAYABLE";

        /// <summary>An admin action the invoice's status does not allow (409), for example waiving a paid invoice.</summary>
        public const string InvoiceStatusInvalid = "INVOICE_STATUS_INVALID";

        /// <summary>The payment was already approved or rejected, maybe by another admin (409).</summary>
        public const string PaymentAlreadyReviewed = "PAYMENT_ALREADY_REVIEWED";

        /// <summary>An adjustment that would leave nothing or less than nothing to pay (422).</summary>
        public const string AdjustmentInvalid = "ADJUSTMENT_INVALID";

        /// <summary>A new due date that is not after the current one, or too far away (400).</summary>
        public const string DueDateInvalid = "DUE_DATE_INVALID";

        public const string TooManyScreenshots = "TOO_MANY_SCREENSHOTS";
    }
}

namespace El3yada.Api.Audit
{
    /// <summary>Billing audit actions (spec 9.1, 9.3). Month close and the daily check write them as the system.</summary>
    public static partial class AuditActions
    {
        public const string InvoiceCreated = "invoiceCreated";
        public const string InvoiceOverdue = "invoiceOverdue";
        public const string PaymentSubmitted = "paymentSubmitted";
        public const string PaymentApproved = "paymentApproved";
        public const string PaymentRejected = "paymentRejected";
        public const string InvoiceAdjusted = "invoiceAdjusted";
        public const string InvoiceWaived = "invoiceWaived";
        public const string InvoiceMarkedPaid = "invoiceMarkedPaid";
        public const string InvoiceDueDateExtended = "invoiceDueDateExtended";
        public const string DoctorDisabled = "doctorDisabled";
        public const string DoctorNoteAdded = "doctorNoteAdded";
        public const string StatsReconciled = "statsReconciled";
    }

    public static partial class AuditTargets
    {
        public const string Invoice = "invoice";
        public const string Payment = "payment";
    }
}
