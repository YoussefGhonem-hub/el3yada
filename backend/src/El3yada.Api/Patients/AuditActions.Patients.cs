namespace El3yada.Api.Audit;

/// <summary>
/// Audit actions for patients and sessions. Each row has the clinic's doctorId (D27) and the patient. Details
/// hold IDs, types, field names and amounts, never medical text (diagnoses, notes, profile items).
/// </summary>
public static partial class AuditActions
{
    /// <summary>A new patient account and its link (BR-P1, BR-P4). Details: fileNumber.</summary>
    public const string PatientCreated = "patientCreated";

    /// <summary>An existing patient linked to this doctor (BR-P3). Details: fileNumber.</summary>
    public const string PatientLinked = "patientLinked";

    /// <summary>Identity fields changed. Details: fields (names only).</summary>
    public const string PatientUpdated = "patientUpdated";

    public const string PatientPhoneChanged = "patientPhoneChanged";

    /// <summary>A new temporary password (BR-P5).</summary>
    public const string PatientPasswordReset = "patientPasswordReset";

    public const string PatientArchived = "patientArchived";

    public const string PatientUnarchived = "patientUnarchived";

    /// <summary>The medical profile changed. Details: fields (list names), added, removed (item counts).</summary>
    public const string PatientMedicalProfileUpdated = "patientMedicalProfileUpdated";

    /// <summary>D4 "Export CSV". Details: rows, language and the filters used (never names or phones).</summary>
    public const string PatientsExported = "patientsExported";

    /// <summary>Details: type, branchId, feePiasters, awaitingDoctor.</summary>
    public const string SessionCreated = "sessionCreated";

    /// <summary>Details: fields (names only).</summary>
    public const string SessionClinicalUpdated = "sessionClinicalUpdated";

    public const string SessionPrivateNoteUpdated = "sessionPrivateNoteUpdated";

    /// <summary>BR-S10. Details: before, after (piasters), paymentMethodBefore, paymentMethodAfter.</summary>
    public const string SessionAmountChanged = "sessionAmountChanged";

    /// <summary>
    /// Actions whose details hold the clinic's revenue (amounts charged to patients). The doctor's activity log
    /// (D27) shows them; the admin audit log (AD15) lists the row without its details (BR-REV1).
    /// </summary>
    public static readonly IReadOnlySet<string> ClinicRevenueDetails = new HashSet<string> { SessionAmountChanged };

    /// <summary>BR-S7, shown in the admin audit log (AD15). Details: reason, type, feePiasters, day.</summary>
    public const string SessionDeleted = "sessionDeleted";
}

public static partial class AuditTargets
{
    public const string Patient = "patient";
    public const string Session = "session";
}
