namespace El3yada.Api;

/// <summary>Codes for the admin's actions on a doctor account (AD5). backend/docs/api-phase-1.md lists them.</summary>
public static partial class ErrorCodes
{
    /// <summary>
    /// 409: <c>setDoctorStatus</c> moves a doctor only between <c>active</c> and <c>suspended</c> (BR-G4). A doctor
    /// who is pending approval, rejected or disabled can't be suspended or reactivated. The answer has <c>status</c>,
    /// the doctor's current status.
    /// </summary>
    public const string DoctorStatusNotChangeable = "DOCTOR_STATUS_NOT_CHANGEABLE";

    /// <summary>409: <c>extendDoctorTrial</c> for a doctor whose service is already active: there is no trial (BR-T5).</summary>
    public const string ServiceAlreadyActive = "SERVICE_ALREADY_ACTIVE";
}
