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
}
