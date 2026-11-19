namespace El3yada.Api.Infrastructure.Errors;

/// <summary>
/// A business error with a stable code from the spec (for example <c>CONSULTATION_REQUIRES_EXAM</c>).
/// <see cref="ApiExceptionHandler"/> turns it into a ProblemDetails response with a <c>code</c>
/// field, which the app maps to an ARB message.
/// </summary>
public sealed class ApiException(int status, string code, string? detail = null) : Exception(detail ?? code)
{
    public int Status { get; } = status;
    public string Code { get; } = code;

    /// <summary>Optional data for the app, written as <c>details</c> (for example who handled a card first).</summary>
    public object? Details { get; init; }

    public static ApiException NotFound(string code = ErrorCodes.NotFound) => new(StatusCodes.Status404NotFound, code);
    public static ApiException Forbidden(string code = ErrorCodes.Forbidden) => new(StatusCodes.Status403Forbidden, code);
    public static ApiException Conflict(string code, string? detail = null) => new(StatusCodes.Status409Conflict, code, detail);
    public static ApiException BadRequest(string code, string? detail = null) => new(StatusCodes.Status400BadRequest, code, detail);
}

/// <summary>Error codes shared by the API and the app. Add new ones here and to the app's error mapping.</summary>
public static class ErrorCodes
{
    public const string ValidationFailed = "VALIDATION_FAILED";
    public const string NotFound = "NOT_FOUND";
    public const string Forbidden = "FORBIDDEN";
    public const string Unauthorized = "UNAUTHORIZED";
    public const string Internal = "INTERNAL_ERROR";

    // Phase 4: patient app and account support.
    public const string DeletionAlreadyRequested = "DELETION_ALREADY_REQUESTED";
    public const string DeletionAlreadyReviewed = "DELETION_ALREADY_REVIEWED";
    public const string AccountDeleted = "ACCOUNT_DELETED";
    public const string AccountRoleNotSupported = "ACCOUNT_ROLE_NOT_SUPPORTED";
    public const string FileMissing = "FILE_MISSING";

    // Staff access (spec 9.4).
    public const string PermissionDenied = "PERMISSION_DENIED";
    public const string DoctorSuspended = "DOCTOR_SUSPENDED";
    public const string ClinicInactive = "CLINIC_INACTIVE";
    public const string NotLinked = "NOT_LINKED";

    // Phase 5: chat and files.
    public const string ChatUnavailable = "CHAT_UNAVAILABLE";
    public const string FileTooLarge = "FILE_TOO_LARGE";
    public const string FileRequired = "FILE_REQUIRED";

    // Phase 6: bookings (spec 6.12.6) and the live board.
    public const string SlotTaken = "SLOT_TAKEN";
    public const string PeriodFull = "PERIOD_FULL";
    public const string OutsideHours = "OUTSIDE_HOURS";
    public const string BranchClosed = "BRANCH_CLOSED";
    public const string TooFarAhead = "TOO_FAR_AHEAD";
    public const string TooSoon = "TOO_SOON";
    public const string SameDayOff = "SAME_DAY_OFF";
    public const string UpcomingLimit = "UPCOMING_LIMIT";
    public const string SelfBookingBlocked = "SELF_BOOKING_BLOCKED";
    public const string ConsultationRequiresExam = "CONSULTATION_REQUIRES_EXAM";
    public const string CancelWindowPassed = "CANCEL_WINDOW_PASSED";
    public const string MaxReschedules = "MAX_RESCHEDULES";
    public const string BookingUnavailable = "BOOKING_UNAVAILABLE";
    public const string InvalidTransition = "INVALID_TRANSITION";
    public const string AlreadyHandled = "ALREADY_HANDLED";
    public const string OverbookingWarning = "OVERBOOKING_WARNING";
    public const string GuestNeedsAccount = "GUEST_NEEDS_ACCOUNT";
    public const string ScheduleConflicts = "SCHEDULE_CONFLICTS";
}
