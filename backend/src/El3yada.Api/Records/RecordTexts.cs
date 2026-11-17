using El3yada.Api.Records;

namespace El3yada.Api
{
    /// <summary>Codes for medical files (backend/docs/api-phase-3-files.md).</summary>
    public static partial class ErrorCodes
    {
        /// <summary>400: the upload expired, was already used or belongs to another clinic. The answer has <c>uploadId</c>.</summary>
        public const string UploadNotFound = "UPLOAD_NOT_FOUND";

        /// <summary>400: the session is not this patient's with this doctor, or it was deleted.</summary>
        public const string InvalidSession = "INVALID_SESSION";

        /// <summary>400: more items than allowed (a record holds at most 20 files).</summary>
        public const string TooMany = "TOO_MANY";

        /// <summary>400: a date outside its allowed range (a document date in the future).</summary>
        public const string InvalidDate = "INVALID_DATE";
    }
}

namespace El3yada.Api.Audit
{
    /// <summary>Medical files (BR-F3): in the clinic's activity log (D27). Details hold IDs, the category and sizes, never file names or notes.</summary>
    public static partial class AuditActions
    {
        /// <summary>Details: category, source, attachments (count), sizeBytes.</summary>
        public const string MedicalRecordCreated = "medicalRecordCreated";

        /// <summary>Details: fields (names only), category.</summary>
        public const string MedicalRecordUpdated = "medicalRecordUpdated";

        /// <summary>Details: category.</summary>
        public const string MedicalRecordDeleted = "medicalRecordDeleted";
    }

    public static partial class AuditTargets
    {
        public const string MedicalRecord = "medicalRecord";
    }
}

namespace El3yada.Api.Notifications
{
    public static partial class NotificationTexts
    {
        public const string RecordAdded = "recordAdded";

        /// <summary>
        /// To the patient (BR-F9, spec 10.1): the category and the doctor only. Never the title or the notes,
        /// which may hold medical text.
        /// </summary>
        public static NotificationText MedicalRecordAdded(string category, string doctorNameAr, string doctorNameEn) => new(
            RecordAdded,
            "ملف جديد",
            "New file",
            $"أضاف د. {doctorNameAr} ملفاً جديداً ({RecordCategories.NameAr(category)}) إلى ملفك الطبي.",
            $"Dr {doctorNameEn} added a new file ({RecordCategories.NameEn(category)}) to your medical file.");
    }
}
