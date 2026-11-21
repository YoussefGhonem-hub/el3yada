namespace El3yada.Api;

public static partial class ErrorCodes
{
    public const string Unauthorized = "UNAUTHORIZED";
    public const string Internal = "INTERNAL_ERROR";
    // Phase 4: patient app and account support. Account deletion codes are in Features/AccountDeletion.
    public const string AccountDeleted = "ACCOUNT_DELETED";
    public const string AccountRoleNotSupported = "ACCOUNT_ROLE_NOT_SUPPORTED";
    public const string FileMissing = "FILE_MISSING";
    public const string ClinicInactive = "CLINIC_INACTIVE";
    // Phase 5: chat and files.
    public const string ChatUnavailable = "CHAT_UNAVAILABLE";
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
    public const string CancelWindowPassed = "CANCEL_WINDOW_PASSED";
    public const string MaxReschedules = "MAX_RESCHEDULES";
    public const string BookingUnavailable = "BOOKING_UNAVAILABLE";
    public const string InvalidTransition = "INVALID_TRANSITION";
    public const string AlreadyHandled = "ALREADY_HANDLED";
    public const string OverbookingWarning = "OVERBOOKING_WARNING";
    public const string GuestNeedsAccount = "GUEST_NEEDS_ACCOUNT";
    public const string ScheduleConflicts = "SCHEDULE_CONFLICTS";
}
