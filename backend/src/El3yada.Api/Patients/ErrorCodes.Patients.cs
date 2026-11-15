namespace El3yada.Api;

/// <summary>
/// Codes for patients, the medical profile, sessions and the fee summaries (Phase 2). The contract and the
/// extra fields each answer carries are in backend/docs/api-phase-2-patients.md.
/// </summary>
public static partial class ErrorCodes
{
    // ---- Patients -------------------------------------------------------------------------------------

    /// <summary>
    /// 409: createPatient for a number that is already one of this doctor's patients. The answer has
    /// <c>patientId</c> and <c>fileNumber</c>, so the app can open that profile.
    /// </summary>
    public const string PatientAlreadyLinked = "PATIENT_ALREADY_LINKED";

    /// <summary>409: updatePatientPhone to a number another patient account already uses (BR-P2).</summary>
    public const string PatientPhoneTaken = "PATIENT_PHONE_TAKEN";

    /// <summary>Field: date of birth in the future or more than 120 years ago («تاريخ الميلاد غير صحيح»).</summary>
    public const string InvalidDateOfBirth = "INVALID_DATE_OF_BIRTH";

    /// <summary>Field: national ID is not 14 digits («الرقم القومي يجب أن يكون 14 رقم»).</summary>
    public const string InvalidNationalId = "INVALID_NATIONAL_ID";

    // ---- Sessions -------------------------------------------------------------------------------------

    /// <summary>404: createSession for a patient who is not linked to this doctor (spec 9.1).</summary>
    public const string NotLinked = "NOT_LINKED";

    /// <summary>
    /// 409: a consultation that BR-S2 or BR-S3 refuses. The answer has <c>reason</c> (<c>firstVisit</c> or
    /// <c>limitReached</c>), <c>consultationsSinceExam</c> and <c>maxConsecutiveConsultations</c>, for the BR-S4 message.
    /// </summary>
    public const string ConsultationRequiresExam = "CONSULTATION_REQUIRES_EXAM";

    /// <summary>409: a new session in an archived branch.</summary>
    public const string SessionBranchArchived = "BRANCH_ARCHIVED";

    /// <summary>Field: the branch has no visit price for this type, so the amount charged must be typed (BR-S10, BR-PR6).</summary>
    public const string AmountRequired = "AMOUNT_REQUIRED";

    /// <summary>409: the amount charged can only be changed on the session's Cairo day (BR-S10).</summary>
    public const string AmountNotEditable = "AMOUNT_NOT_EDITABLE";

    /// <summary>
    /// 409: BR-S7 refuses the deletion. The answer has <c>reason</c>: <c>notLatest</c> (a newer session exists)
    /// or <c>notSameDay</c> (it was recorded on an earlier Cairo day).
    /// </summary>
    public const string SessionNotDeletable = "SESSION_NOT_DELETABLE";
}
