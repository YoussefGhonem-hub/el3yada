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
