using El3yada.Api.Infrastructure.Errors;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace El3yada.Api.Infrastructure.Validation;

/// <summary>
/// Runs the FluentValidation validator registered for each action argument (spec 11) and
/// answers 400 with <c>code = VALIDATION_FAILED</c> and the failing fields. Registered globally.
/// </summary>
public sealed class FluentValidationFilter(IServiceProvider services) : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        foreach (var argument in context.ActionArguments.Values)
        {
            if (argument is null) continue;
            var validatorType = typeof(IValidator<>).MakeGenericType(argument.GetType());
            if (services.GetService(validatorType) is not IValidator validator) continue;

            var result = await validator.ValidateAsync(new ValidationContext<object>(argument), context.HttpContext.RequestAborted);
            if (result.IsValid) continue;

            var errors = result.Errors
                .GroupBy(e => ToCamelCase(e.PropertyName))
                .ToDictionary(g => g.Key, g => g.Select(e => e.ErrorCode).Distinct().ToArray());
            var problem = new ValidationProblemDetails(errors)
            {
                Status = StatusCodes.Status400BadRequest,
                Title = ErrorCodes.ValidationFailed,
                Extensions = { ["code"] = ErrorCodes.ValidationFailed },
            };
            context.Result = new BadRequestObjectResult(problem) { ContentTypes = { "application/problem+json" } };
            return;
        }

        await next();
    }

    private static string ToCamelCase(string name) =>
        string.IsNullOrEmpty(name) ? name : char.ToLowerInvariant(name[0]) + name[1..];
}
