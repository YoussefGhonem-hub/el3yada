namespace El3yada.Api;

/// <summary>
/// Codes for branches, visit prices, the doctor's profile and assistants (D22, D25–D29, D37, AS19).
/// backend/docs/api-phase-2-clinic.md lists them with their answers.
/// </summary>
public static partial class ErrorCodes
{
    // ---- Branches ------------------------------------------------------------------------------------

    /// <summary>409: the doctor already has <c>maxBranchesPerDoctor</c> branches that are not archived (BR-BR1).</summary>
    public const string BranchLimitReached = "BRANCH_LIMIT_REACHED";

    /// <summary>409: the default branch can't be archived; choose another default first (BR-BR3).</summary>
    public const string CannotArchiveDefaultBranch = "CANNOT_ARCHIVE_DEFAULT_BRANCH";

    /// <summary>409: the change would leave the doctor without an active branch (BR-BR1).</summary>
    public const string LastActiveBranch = "LAST_ACTIVE_BRANCH";

    /// <summary>
    /// 409: the branch has bookings from today on that must be moved or cancelled first (BR-BR9). The answer
    /// has <c>bookings</c>, the list, and <c>totalCount</c>.
    /// </summary>
    public const string BranchHasBookings = "BRANCH_HAS_BOOKINGS";

    /// <summary>409: only an active branch can be the default (BR-BR3).</summary>
    public const string BranchNotActive = "BRANCH_NOT_ACTIVE";

    /// <summary>Field: a branch ID that is not one of the doctor's branches, or is archived.</summary>
    public const string InvalidBranch = "INVALID_BRANCH";

    /// <summary>409: the branch already has <c>BranchPhotosController.MaxPhotos</c> photos (BR-BR2 [S]); delete one first.</summary>
    public const string BranchPhotoLimit = "BRANCH_PHOTO_LIMIT";

    // ---- Working hours (spec section 11) -------------------------------------------------------------

    /// <summary>Field: a period ends before it starts and is not marked as ending the next day.</summary>
    public const string PeriodEndBeforeStart = "PERIOD_END_BEFORE_START";

    /// <summary>Field: a period is shorter than 15 minutes or longer than 16 hours.</summary>
    public const string PeriodLengthOutOfRange = "PERIOD_LENGTH_OUT_OF_RANGE";

    /// <summary>Field: two periods overlap («الفترات متداخلة»).</summary>
    public const string PeriodsOverlap = "PERIODS_OVERLAP";

    // ---- Assistants ----------------------------------------------------------------------------------

    /// <summary>409: the doctor has <c>maxAssistantsPerDoctor</c> assistants («وصلت للحد الأقصى لعدد المساعدين», BR-AS1).</summary>
    public const string AssistantLimitReached = "ASSISTANT_LIMIT_REACHED";

    /// <summary>409: the mobile number is already an assistant, of this doctor or another (BR-AS3).</summary>
    public const string AssistantPhoneTaken = "ASSISTANT_PHONE_TAKEN";

    /// <summary>409: the assistant was removed; removal is final (BR-AS8). Add them again as a new assistant.</summary>
    public const string AssistantRemoved = "ASSISTANT_REMOVED";
}
