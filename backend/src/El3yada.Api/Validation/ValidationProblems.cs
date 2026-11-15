using System.Text.Json;
using FluentValidation.Results;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Infrastructure;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace El3yada.Api.Validation;

/// <summary>
/// Turns FluentValidation failures into a 400 <c>application/problem+json</c> response:
/// <c>errors</c> holds the messages per field (camelCase, as in the JSON body) and <c>errorCodes</c>
/// the error codes per field, which the app maps to ARB messages.
/// </summary>
public static class ValidationProblems
{
    public static IActionResult Create(
        HttpContext httpContext, IEnumerable<ValidationFailure> failures, string code = ErrorCodes.ValidationFailed)
    {
        var modelState = new ModelStateDictionary();
        var codes = new Dictionary<string, List<string>>();
        foreach (var failure in failures)
        {
            var field = ToJsonPath(failure.PropertyName);
            modelState.AddModelError(field, failure.ErrorMessage);
            if (!codes.TryGetValue(field, out var fieldCodes))
            {
                codes[field] = fieldCodes = [];
            }

            fieldCodes.Add(failure.ErrorCode);
        }

        var factory = httpContext.RequestServices.GetRequiredService<ProblemDetailsFactory>();
        var problem = factory.CreateValidationProblemDetails(httpContext, modelState, StatusCodes.Status400BadRequest);
        problem.Extensions["code"] = code;
        problem.Extensions["errorCodes"] = codes.ToDictionary(pair => pair.Key, pair => pair.Value.ToArray());

        return new BadRequestObjectResult(problem) { ContentTypes = { "application/problem+json" } };
    }

    /// <summary>A validation problem for one field, for checks that need the database (for example a wrong current password).</summary>
    public static IActionResult Field(HttpContext httpContext, string propertyName, string code, string message) =>
        Create(httpContext, [new ValidationFailure(propertyName, message) { ErrorCode = code }]);

    /// <summary>
    /// The <c>[ApiController]</c> answer when the body can't be read (bad JSON, wrong types): the same shape,
    /// with <c>INVALID_REQUEST</c> for each field that failed.
    /// </summary>
    public static IActionResult FromModelState(ActionContext context)
    {
        var failures = context.ModelState
            .Where(entry => entry.Value is { Errors.Count: > 0 })
            // JSON errors have keys like "$.identifier"; a missing or unreadable body has the parameter name.
            .Select(entry => new ValidationFailure(
                entry.Key.StartsWith('$') && entry.Key.TrimStart('$', '.') is { Length: > 0 } path ? path : "body",
                "The request body could not be read.") { ErrorCode = ErrorCodes.InvalidRequest });
        return Create(context.HttpContext, failures, ErrorCodes.InvalidRequest);
    }

    /// <summary>
    /// For input that is not an action argument: validate it in the action, then
    /// <c>if (!result.IsValid) return this.ValidationProblem(result);</c>.
    /// </summary>
    public static IActionResult ValidationProblem(this ControllerBase controller, ValidationResult result) =>
        Create(controller.HttpContext, result.Errors);

    // "Items[0].DrugName" -> "items[0].drugName"
    private static string ToJsonPath(string propertyName) =>
        string.Join('.', propertyName.Split('.').Select(JsonNamingPolicy.CamelCase.ConvertName));
}
