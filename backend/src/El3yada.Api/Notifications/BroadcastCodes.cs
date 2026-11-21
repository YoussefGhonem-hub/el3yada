namespace El3yada.Api
{
    /// <summary>Codes for AD16 broadcasts (backend/docs/api-broadcast.md).</summary>
    public static partial class ErrorCodes
    {
        /// <summary>409: no chosen doctor can receive the broadcast now (pending, rejected or disabled), or there are no doctors.</summary>
        public const string BroadcastNoRecipients = "BROADCAST_NO_RECIPIENTS";
    }
}

namespace El3yada.Api.Audit
{
    /// <summary>AD16.</summary>
    public static partial class AuditActions
    {
        /// <summary>
        /// An admin sent a broadcast. Target: <c>broadcast</c> with the broadcast's id. Details:
        /// <c>{ audience, recipients, doctorIds, titleAr, bodyAr, titleEn, bodyEn }</c> (<c>doctorIds</c> only for
        /// <c>selected</c>). AD16's history reads these rows.
        /// </summary>
        public const string BroadcastSent = "broadcastSent";
    }

    public static partial class AuditTargets
    {
        public const string Broadcast = "broadcast";
    }
}
