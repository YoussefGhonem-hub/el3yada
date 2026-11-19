using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Infrastructure.Errors;

/// <summary>
/// Every error leaves the API as RFC 9457 ProblemDetails with a <c>code</c> extension.
/// Unexpected exceptions are logged and returned as <c>INTERNAL_ERROR</c> without details.
/// </summary>
public sealed class ApiExceptionHandler(IProblemDetailsService problemDetails, ILogger<ApiExceptionHandler> logger)
    : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var (status, code) = exception switch
        {
            ApiException api => (api.Status, api.Code),
            OperationCanceledException when httpContext.RequestAborted.IsCancellationRequested => (499, "CANCELLED"),
            _ => (StatusCodes.Status500InternalServerError, ErrorCodes.Internal),
        };

        if (status >= 500) logger.LogError(exception, "Unhandled exception on {Method} {Path}", httpContext.Request.Method, httpContext.Request.Path);

        httpContext.Response.StatusCode = status;
        var problem = new ProblemDetails { Status = status, Title = code, Extensions = { ["code"] = code } };
        if (exception is ApiException { Details: { } details }) problem.Extensions["details"] = details;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = httpContext,
            Exception = exception,
            ProblemDetails = problem,
        });
    }

    /// <summary>Adds <c>code</c> to the framework's own problem responses (401, 403, 404, model binding).</summary>
    public static void Customize(ProblemDetailsContext context)
    {
        var problem = context.ProblemDetails;
        if (problem.Extensions.ContainsKey("code")) return;
        problem.Extensions["code"] = problem.Status switch
        {
            StatusCodes.Status400BadRequest => ErrorCodes.ValidationFailed,
            StatusCodes.Status401Unauthorized => ErrorCodes.Unauthorized,
            StatusCodes.Status403Forbidden => ErrorCodes.Forbidden,
            StatusCodes.Status404NotFound => ErrorCodes.NotFound,
            _ => ErrorCodes.Internal,
        };
    }
}
