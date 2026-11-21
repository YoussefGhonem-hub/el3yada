namespace El3yada.Api.Audit;

/// <summary>Audit actions for the admin's changes to a doctor account (AD5 Audit tab, AD15). Not shown in D27.</summary>
public static partial class AuditActions
{
    /// <summary>BR-G4, by hand. Details: <c>before</c>, <c>after</c>, <c>reason</c>.</summary>
    public const string DoctorSuspended = "doctorSuspended";

    /// <summary>BR-G4, by hand. Details: <c>before</c>, <c>after</c>, <c>reason</c>.</summary>
    public const string DoctorReactivated = "doctorReactivated";

    /// <summary>The admin turned the service on after the free trial (BR-T5). Details: <c>{ trialEndsAtBefore }</c>.</summary>
    public const string DoctorServiceActivated = "doctorServiceActivated";

    /// <summary>The admin extended the free trial (BR-T5). Details: <c>{ before, after, days }</c>.</summary>
    public const string DoctorTrialExtended = "doctorTrialExtended";

    /// <summary>
    /// AD6: an admin created the doctor's account, active and without a trial. Details:
    /// <c>{ specialtyId, branchId, serviceActive }</c>. The doctor sets a password from the emailed link.
    /// </summary>
    public const string DoctorCreated = "doctorCreated";
}
