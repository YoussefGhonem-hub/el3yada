namespace El3yada.Api.Audit;

/// <summary>Audit actions for the admin's changes to a doctor account (AD5 Audit tab, AD15). Not shown in D27.</summary>
public static partial class AuditActions
{
    /// <summary>BR-G4, by hand. Details: <c>before</c>, <c>after</c>, <c>reason</c>.</summary>
    public const string DoctorSuspended = "doctorSuspended";

    /// <summary>BR-G4, by hand. Details: <c>before</c>, <c>after</c>, <c>reason</c>.</summary>
    public const string DoctorReactivated = "doctorReactivated";
}
