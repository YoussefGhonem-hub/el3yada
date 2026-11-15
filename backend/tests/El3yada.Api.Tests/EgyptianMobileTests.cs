using El3yada.Api.Validation;
using FluentValidation;
using FluentValidation.TestHelper;

namespace El3yada.Api.Tests;

/// <summary>Same cases as app/test/core/validators_test.dart, plus a few .NET-specific ones.</summary>
public class EgyptianMobileTests
{
    [Theory]
    [InlineData("01012345678", "+201012345678")]
    [InlineData("+201112345678", "+201112345678")]
    [InlineData("00201212345678", "+201212345678")]
    [InlineData("201512345678", "+201512345678")]
    [InlineData("010 1234 5678", "+201012345678")]
    [InlineData("(010) 1234-5678", "+201012345678")]
    [InlineData("٠١٠١٢٣٤٥٦٧٨", "+201012345678")] // Arabic-Indic digits
    [InlineData("۰۱۰۱۲۳۴۵۶۷۸", "+201012345678")] // Persian digits
    public void Accepts_the_usual_forms_and_returns_E164(string input, string expected)
    {
        Assert.Equal(expected, EgyptianMobile.Normalize(input));
    }

    [Theory]
    [InlineData("01312345678")] // 013 is not a mobile prefix
    [InlineData("0101234567")] // too short
    [InlineData("010123456789")] // too long
    [InlineData("+2001012345678")]
    [InlineData("abc")]
    [InlineData("")]
    [InlineData("०१०१२३४५६७८")] // Devanagari digits: \d would accept them, [0-9] does not
    public void Rejects_invalid_numbers(string input)
    {
        Assert.Null(EgyptianMobile.Normalize(input));
    }

    [Fact]
    public void The_rule_reports_INVALID_MOBILE()
    {
        var validator = new PhoneValidator();

        validator.TestValidate(new PhoneInput("0123"))
            .ShouldHaveValidationErrorFor(x => x.Phone)
            .WithErrorCode(ErrorCodes.InvalidMobile);
        validator.TestValidate(new PhoneInput("+20 101 234 5678")).ShouldNotHaveAnyValidationErrors();
        // Null passes the rule; NotEmpty() makes the field required.
        validator.TestValidate(new PhoneInput(null))
            .ShouldHaveValidationErrorFor(x => x.Phone)
            .WithErrorCode("NotEmptyValidator");
    }

    private sealed record PhoneInput(string? Phone);

    private sealed class PhoneValidator : AbstractValidator<PhoneInput>
    {
        public PhoneValidator() => RuleFor(x => x.Phone).NotEmpty().EgyptianMobile();
    }
}
