using FluentValidation;

namespace El3yada.Api.Validation;

/// <summary>Shared FluentValidation rules from spec section 11.</summary>
public static class RuleBuilderExtensions
{
    /// <summary>
    /// An Egyptian mobile number in any accepted form (see <see cref="Validation.EgyptianMobile.Normalize"/>).
    /// Null passes, so add <c>NotEmpty()</c> when the field is required. The endpoint stores
    /// <c>EgyptianMobile.Normalize(value)</c>, the E.164 form.
    /// </summary>
    public static IRuleBuilderOptions<T, string?> EgyptianMobile<T>(this IRuleBuilder<T, string?> rule) =>
        rule.Must(value => value is null || Validation.EgyptianMobile.Normalize(value) is not null)
            .WithErrorCode(ErrorCodes.InvalidMobile)
            .WithMessage("Enter a valid Egyptian mobile number.");
}
