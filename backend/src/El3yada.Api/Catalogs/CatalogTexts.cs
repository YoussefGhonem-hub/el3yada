namespace El3yada.Api
{
    /// <summary>Codes for catalogs (backend/docs/api-phase-3-catalogs.md).</summary>
    public static partial class ErrorCodes
    {
        /// <summary>400 <c>file</c>: the file's sha256 is not the one in the manifest.</summary>
        public const string CatalogShaMismatch = "CATALOG_SHA_MISMATCH";

        /// <summary>400 <c>file</c>: not a gzip-compressed SQLite catalog with the meta table and the three item tables.</summary>
        public const string CatalogFileInvalid = "CATALOG_FILE_INVALID";

        /// <summary>400 <c>file</c>: <c>meta.schema_version</c> is not the one this API serves. The answer has <c>expected</c> and <c>actual</c>.</summary>
        public const string CatalogSchemaUnsupported = "CATALOG_SCHEMA_UNSUPPORTED";

        /// <summary>409: a table has more than 5% fewer rows than the current version. Send again with <c>confirmDrop=true</c>. The answer has <c>drops</c>.</summary>
        public const string CatalogCountDrop = "CATALOG_COUNT_DROP";

        /// <summary>404: no catalog version has been published yet.</summary>
        public const string CatalogNotPublished = "CATALOG_NOT_PUBLISHED";
    }
}

namespace El3yada.Api.Audit
{
    /// <summary>Catalog administration (AD19, AD20): in the admin audit log (AD15).</summary>
    public static partial class AuditActions
    {
        /// <summary>Details: version, schemaVersion, counts, sizeBytes, confirmedDrop.</summary>
        public const string CatalogPublished = "catalogPublished";

        /// <summary>Details: type, created, active.</summary>
        public const string CatalogCustomItemSaved = "catalogCustomItemSaved";

        public const string CatalogReportHandled = "catalogReportHandled";

        /// <summary>Details: includeGeneral, counts per item type, copiedFrom.</summary>
        public const string SpecialtyProfileUpdated = "specialtyProfileUpdated";
    }

    public static partial class AuditTargets
    {
        public const string CatalogVersion = "catalogVersion";
        public const string CatalogCustomItem = "catalogCustomItem";
        public const string CatalogReport = "catalogReport";
        public const string Specialty = "specialty";
    }
}

namespace El3yada.Api.Notifications
{
    public static partial class NotificationTexts
    {
        public const string CatalogReportReceived = "catalogReportReceived";

        /// <summary>To every active admin (AD20 "Doctor reports").</summary>
        public static NotificationText CatalogReport(string doctorName) => new(
            CatalogReportReceived,
            "بلاغ عن عنصر في الكتالوج",
            "Catalog item report",
            $"أرسل د. {doctorName} بلاغاً عن عنصر في الكتالوج.",
            $"Dr {doctorName} reported a catalog item.");
    }
}
