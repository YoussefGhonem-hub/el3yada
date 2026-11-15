using FluentValidation;
using FluentValidation.Results;
using Microsoft.AspNetCore.Mvc.Filters;

namespace El3yada.Api.Validation;

/// <summary>
/// Before every controller action, runs the FluentValidation validator of each argument that has one
/// (validators are found in DI, registered from this assembly in Program.cs). On failure the action
/// does not run and the response is a 400 ValidationProblem (see <see cref="ValidationProblems"/>).
/// </summary>
public sealed class ValidationFilter : IAsyncActionFilter
{
    public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var services = context.HttpContext.RequestServices;
        List<ValidationFailure>? failures = null;

        foreach (var argument in context.ActionArguments.Values)
        {
            if (argument is null)
            {
                continue;
            }

            var validatorType = typeof(IValidator<>).MakeGenericType(argument.GetType());
            if (services.GetService(validatorType) is not IValidator validator)
            {
                continue;
            }

            var result = await validator.ValidateAsync(
                new ValidationContext<object>(argument), context.HttpContext.RequestAborted);
            if (!result.IsValid)
            {
                (failures ??= []).AddRange(result.Errors);
            }
        }

        if (failures is null)
        {
            await next();
            return;
        }

        context.Result = ValidationProblems.Create(context.HttpContext, failures);
    }
}
