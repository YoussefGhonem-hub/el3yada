using System.Security.Cryptography;
using El3yada.Api.Auth;

namespace El3yada.Api.Features.AccountDeletion
{
    /// <summary>DeletionRequests.Status values (spec 6.17).</summary>
    public static class DeletionStatuses
    {
        /// <summary>The account is disabled; the identity is erased once ScheduledFor has passed.</summary>
        public const string Scheduled = "scheduled";

        /// <summary>A doctor whose grace period ended with an invoice still to pay (BR-DEL9). Erased once all are paid.</summary>
        public const string WaitingPayment = "waitingPayment";

        /// <summary>The user restored the account, or an admin cancelled the deletion.</summary>
        public const string Restored = "restored";

        /// <summary>The identity was erased (BR-DEL4).</summary>
        public const string Completed = "completed";

        public static readonly string[] All = [Scheduled, WaitingPayment, Restored, Completed];

        /// <summary>The deletion is still in progress: the account can be restored.</summary>
        public static readonly string[] Open = [Scheduled, WaitingPayment];

        public static bool IsOpen(string status) => status is Scheduled or WaitingPayment;
    }

    /// <summary>
    /// What an erased account is replaced with (BR-DEL4, BR-DEL5). Names are the Arabic forms the clinic sees; the app
    /// shows its own label for each, in the user's language (deletedPatient, deletedDoctor …).
    /// </summary>
    public static class Tombstones
    {
        public const string PatientName = "مريض محذوف";
        public const string DoctorName = "طبيب محذوف";
        public const string AssistantName = "مساعد محذوف";
        public const string AdminName = "مسؤول محذوف";

        public const string PatientNameEn = "Deleted patient";
        public const string DoctorNameEn = "Deleted doctor";
        public const string AssistantNameEn = "Deleted assistant";
        public const string AdminNameEn = "Deleted admin";

        /// <summary>Doctors.LicenseNumber after erasure (the column is required, 3 to 20 characters).</summary>
        public const string LicenseNumber = "deleted";

        /// <summary>Branch addresses after erasure (AddressDetails is required).</summary>
        public const string Address = "—";

        /// <summary>The name for <paramref name="role"/> (Users.DisplayName, Patients/Assistants/Doctors.FullName).</summary>
        public static string NameFor(string role) => role switch
        {
            Roles.Patient => PatientName,
            Roles.Doctor => DoctorName,
            Roles.Assistant => AssistantName,
            _ => AdminName,
        };

        /// <summary>
        /// A value for a required phone column that frees the number (UQ_Patients_Phone has no filter): <c>~</c> and
        /// 15 random hex digits, which no E.164 number can equal. 60 random bits, so two erased accounts never share one.
        /// </summary>
        public static string Phone() => "~" + Convert.ToHexString(RandomNumberGenerator.GetBytes(8))[..15].ToLowerInvariant();

        /// <summary>True for a phone this class made: views show nothing in its place.</summary>
        public static bool IsPhone(string? phone) => phone is not null && phone.StartsWith('~');

        /// <summary>
        /// Users.Email after erasure. Users need a phone or an email (CK_Users_Identifier), and the email is unique, so
        /// it is per user. <c>.invalid</c> is reserved (RFC 2606): nothing is ever sent there.
        /// </summary>
        public static string Email(Guid userId) => $"deleted-{userId:N}@deleted.invalid";
    }
}

namespace El3yada.Api
{
    public static partial class ErrorCodes
    {
        /// <summary>
        /// 403: the account is in its deletion grace period. Only the endpoints of A16 answer (restore, sign out, the
        /// session, a doctor's billing). The app reloads the session and shows the restore screen.
        /// </summary>
        public const string AccountPendingDeletion = "ACCOUNT_PENDING_DELETION";

        /// <summary>409: the account already has a deletion in progress, or the action is closed while it has one.</summary>
        public const string AccountDeletionScheduled = "ACCOUNT_DELETION_SCHEDULED";

        /// <summary>409: restoreAccount or adminCancelAccountDeletion with no deletion in progress (already restored or erased).</summary>
        public const string AccountNotPendingDeletion = "ACCOUNT_NOT_PENDING_DELETION";

        /// <summary>
        /// 409: a doctor with an invoice unpaid, overdue, rejected or in payment review can't start deleting the account
        /// (BR-DEL7). <c>details.invoices</c> lists them.
        /// </summary>
        public const string UnpaidInvoices = "UNPAID_INVOICES";

        /// <summary>403: the chat's patient or doctor account is being deleted or was erased (BR-DEL6). History stays readable.</summary>
        public const string ChatClosed = "CHAT_CLOSED";
    }
}

namespace El3yada.Api.Audit
{
    /// <summary>Account deletion audit actions (spec 6.17). The daily job writes its rows as the system.</summary>
    public static partial class AuditActions
    {
        public const string AccountDeletionRequested = "accountDeletionRequested";
        public const string AccountDeletionScheduledByAdmin = "accountDeletionScheduledByAdmin";
        public const string AccountRestored = "accountRestored";
        public const string AccountDeletionCancelled = "accountDeletionCancelled";
        public const string AccountDeletionWaitingPayment = "accountDeletionWaitingPayment";
        public const string AccountErased = "accountErased";
        public const string FinalInvoiceIssued = "finalInvoiceIssued";
        public const string FinalInvoiceRemoved = "finalInvoiceRemoved";
        public const string InvoiceFeesCarried = "invoiceFeesCarried";
    }

    public static partial class AuditTargets
    {
        public const string DeletionRequest = "deletionRequest";
    }
}
