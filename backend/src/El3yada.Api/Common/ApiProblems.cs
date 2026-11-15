using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;

namespace El3yada.Api.Common;

/// <summary>
/// <c>application/problem+json</c> responses with a stable <c>code</c> (see <see cref="ErrorCodes"/>).
/// The <c>title</c> is English text for logs and developers; the app shows its own ARB message for the code.
/// </summary>
public static class ApiProblems
{
    public const string ContentType = "application/problem+json";

    /// <summary>For controller actions: <c>return ApiProblems.Result(HttpContext, 409, ErrorCodes.X, "…");</c></summary>
    public static ObjectResult Result(HttpContext httpContext, int status, string code, string title, string? detail = null)
    {
        var factory = httpContext.RequestServices.GetRequiredService<ProblemDetailsFactory>();
        var problem = factory.CreateProblemDetails(httpContext, status, title, detail: detail);
        problem.Extensions["code"] = code;
        return new ObjectResult(problem) { StatusCode = status, ContentTypes = { ContentType } };
    }

    /// <summary>For middleware and authentication events, which write the response themselves.</summary>
    public static async Task WriteAsync(
        HttpContext httpContext, int status, string code, string title, IDictionary<string, object?>? extensions = null)
    {
        httpContext.Response.StatusCode = status;
        var problem = new ProblemDetails { Status = status, Title = title };
        problem.Extensions["code"] = code;
        if (extensions is not null)
        {
            foreach (var (key, value) in extensions)
            {
                problem.Extensions[key] = value;
            }
        }

        var service = httpContext.RequestServices.GetRequiredService<IProblemDetailsService>();
        await service.WriteAsync(new ProblemDetailsContext { HttpContext = httpContext, ProblemDetails = problem });
    }

    /// <summary>The code for a problem that has none (unknown route, server error, status code pages).</summary>
    public static string CodeForStatus(int? status) => status switch
    {
        400 => ErrorCodes.InvalidRequest,
        401 => ErrorCodes.Unauthenticated,
        403 => ErrorCodes.Forbidden,
        404 => ErrorCodes.NotFound,
        405 => ErrorCodes.MethodNotAllowed,
        413 => ErrorCodes.RequestTooLarge,
        415 => ErrorCodes.UnsupportedMediaType,
        429 => ErrorCodes.TooManyAttempts,
        _ => ErrorCodes.ServerError,
    };
}

/// <summary>Common results for controllers, so each action reads as one line per outcome.</summary>
public static class ControllerProblemExtensions
{
    public static ObjectResult Problem(this ControllerBase controller, int status, string code, string title) =>
        ApiProblems.Result(controller.HttpContext, status, code, title);

    public static ObjectResult NotFoundProblem(this ControllerBase controller, string title = "Not found.") =>
        ApiProblems.Result(controller.HttpContext, StatusCodes.Status404NotFound, ErrorCodes.NotFound, title);

    public static ObjectResult ConflictProblem(this ControllerBase controller, string code, string title) =>
        ApiProblems.Result(controller.HttpContext, StatusCodes.Status409Conflict, code, title);

    public static ObjectResult ForbiddenProblem(this ControllerBase controller, string code, string title) =>
        ApiProblems.Result(controller.HttpContext, StatusCodes.Status403Forbidden, code, title);
}
