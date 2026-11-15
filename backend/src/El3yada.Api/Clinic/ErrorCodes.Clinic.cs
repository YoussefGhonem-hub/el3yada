namespace El3yada.Api;

/// <summary>
/// Codes every clinic endpoint can answer (<see cref="Clinic.ClinicAttribute"/>), with DOCTOR_PENDING_APPROVAL,
/// DOCTOR_REJECTED and DOCTOR_SUSPENDED from Phase 1. Feature codes live next to their feature.
/// </summary>
public static partial class ErrorCodes
{
    /// <summary>
    /// 403: an assistant without the permission this needs, or a doctor-only action (BR-AS5). The answer has
    /// <c>permission</c>: the missing key (spec 6.10), or <c>doctorOnly</c>.
    /// </summary>
    public const string PermissionDenied = "PERMISSION_DENIED";

    /// <summary>403: the branch is not one of the assistant's branches (BR-AS13).</summary>
    public const string BranchNotAllowed = "BRANCH_NOT_ALLOWED";
}
