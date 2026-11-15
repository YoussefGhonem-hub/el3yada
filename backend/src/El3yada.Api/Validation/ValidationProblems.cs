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
    public static IActionResult Create(HttpContext httpContext, IEnumerable<ValidationFailure> failures)
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
        problem.Extensions["errorCodes"] = codes.ToDictionary(pair => pair.Key, pair => pair.Value.ToArray());

        return new BadRequestObjectResult(problem) { ContentTypes = { "application/problem+json" } };
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
