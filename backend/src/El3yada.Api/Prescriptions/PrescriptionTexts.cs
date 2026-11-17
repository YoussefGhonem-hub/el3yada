using El3yada.Api.Prescriptions;

namespace El3yada.Api
{
    /// <summary>Codes for prescriptions (backend/docs/api-phase-3-prescriptions.md).</summary>
    public static partial class ErrorCodes
    {
        /// <summary>409: the document is sent or cancelled, so it can't be edited, deleted, sent or submitted (BR-RX2).</summary>
        public const string PrescriptionNotEditable = "PRESCRIPTION_NOT_EDITABLE";

        /// <summary>409: only a sent document can be cancelled.</summary>
        public const string PrescriptionNotSent = "PRESCRIPTION_NOT_SENT";

        /// <summary>409: a document needs at least one item to be sent (BR-RX3).</summary>
        public const string PrescriptionEmpty = "PRESCRIPTION_EMPTY";

        /// <summary>400 <c>copyFromId</c>: only a sent or cancelled document of the same kind can be copied.</summary>
        public const string InvalidCopySource = "INVALID_COPY_SOURCE";
    }
}

namespace El3yada.Api.Audit
{
    /// <summary>Prescriptions (spec 6.4) in the clinic's activity log (D27). Details: kind and counts, never the diagnosis, items or advice.</summary>
    public static partial class AuditActions
    {
        /// <summary>Details: kind, copyFromId.</summary>
        public const string PrescriptionDraftCreated = "prescriptionDraftCreated";

        /// <summary>Details: kind, items (count).</summary>
        public const string PrescriptionDraftUpdated = "prescriptionDraftUpdated";

        /// <summary>Details: kind.</summary>
        public const string PrescriptionDraftDeleted = "prescriptionDraftDeleted";

        /// <summary>BR-AS12. Details: kind.</summary>
        public const string PrescriptionSubmittedForReview = "prescriptionSubmittedForReview";

        /// <summary>Details: kind, items (count).</summary>
        public const string PrescriptionSent = "prescriptionSent";

        /// <summary>Details: kind. The reason is not logged (it may hold medical text).</summary>
        public const string PrescriptionCancelled = "prescriptionCancelled";

        /// <summary>D22 print settings. Details: fields (names only).</summary>
        public const string RxSettingsUpdated = "rxSettingsUpdated";

        /// <summary>D22 logo or signature. Details: image (logo or signature), removed.</summary>
        public const string RxBrandingUpdated = "rxBrandingUpdated";
    }

    public static partial class AuditTargets
    {
        public const string Prescription = "prescription";
    }
}

namespace El3yada.Api.Notifications
{
    public static partial class NotificationTexts
    {
        public const string PrescriptionSentType = "prescriptionSent";
        public const string PrescriptionCancelledType = "prescriptionCancelled";
        public const string PrescriptionReadyForReviewType = "prescriptionReadyForReview";

        /// <summary>To the patient (spec 10.1 «روشتة جديدة من د. …»): the kind and the doctor only.</summary>
        public static NotificationText PrescriptionSent(string kind, string doctorNameAr, string doctorNameEn) => new(
            PrescriptionSentType,
            "روشتة جديدة",
            "New prescription",
            $"{PrescriptionKinds.NameAr(kind)} جديدة من د. {doctorNameAr}",
            $"A new {PrescriptionKinds.NameEn(kind)} from Dr {doctorNameEn}");

        /// <summary>To the patient (spec 10.1 «تم إلغاء روشتة»). The reason stays in the app, not in the push text.</summary>
        public static NotificationText PrescriptionCancelled(string kind, string doctorNameAr, string doctorNameEn) => new(
            PrescriptionCancelledType,
            "تم إلغاء روشتة",
            "Prescription cancelled",
            $"ألغى د. {doctorNameAr} {PrescriptionKinds.NameAr(kind)}.",
            $"Dr {doctorNameEn} cancelled a {PrescriptionKinds.NameEn(kind)}.");

        /// <summary>To the doctor (spec 10.1, BR-AS12): «مسودة روشتة جاهزة للمراجعة — المريض …».</summary>
        public static NotificationText PrescriptionReadyForReview(string patientName, string assistantName) => new(
            PrescriptionReadyForReviewType,
            "مسودة روشتة جاهزة للمراجعة",
            "Prescription draft ready for review",
            $"المريض {patientName} — أعدّها {assistantName}",
            $"Patient {patientName} — prepared by {assistantName}");
    }
}
