namespace El3yada.Api.Audit;

/// <summary>Audit actions for branches, prices, the doctor's profile and assistants. They appear in D27 and AD15.</summary>
public static partial class AuditActions
{
    public const string BranchCreated = "branchCreated";
    public const string BranchUpdated = "branchUpdated";
    /// <summary>
    /// <c>updateBranchSchedule</c> (D29, AS17): weekly hours, special dates, closures or booking settings. Rows written
    /// before it, by the retired <c>updateBranchHours</c>, carry <c>branchHoursUpdated</c>.
    /// </summary>
    public const string BranchScheduleUpdated = "branchScheduleUpdated";

    public const string BranchStatusChanged = "branchStatusChanged";
    public const string DefaultBranchChanged = "defaultBranchChanged";
    public const string PricesUpdated = "pricesUpdated";
    public const string DoctorProfileUpdated = "doctorProfileUpdated";
    public const string DoctorSpecialtyChanged = "doctorSpecialtyChanged";
    public const string AssistantCreated = "assistantCreated";
    public const string AssistantUpdated = "assistantUpdated";

    /// <summary>D27 "permission changed": the keys switched on and off.</summary>
    public const string AssistantPermissionsChanged = "assistantPermissionsChanged";

    public const string AssistantPasswordReset = "assistantPasswordReset";
    public const string AssistantDisabled = "assistantDisabled";
    public const string AssistantEnabled = "assistantEnabled";
    public const string AssistantRemoved = "assistantRemoved";
}

public static partial class AuditTargets
{
    public const string Branch = "branch";
    public const string Assistant = "assistant";
}
