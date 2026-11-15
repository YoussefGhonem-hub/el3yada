using El3yada.Api.Auth;
using El3yada.Api.Validation;
using FluentValidation;

namespace El3yada.Api.Controllers;

/// <summary>A3. <c>identifier</c>: an email, or an Egyptian mobile in any accepted form.</summary>
public sealed record LoginRequest(string? Identifier, string? Password, DeviceInfo? Device);

public sealed class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        RuleFor(x => x.Identifier).Required().MaxChars(254)
            .Must(value => LoginIdentifier.Parse(value) is not null)
            .WithErrorCode(ErrorCodes.InvalidIdentifier)
            .WithMessage("Enter an email address or an Egyptian mobile number.");
        RuleFor(x => x.Password).Required().MaxChars(Passwords.MaxLength);
        RuleFor(x => x.Device!).SetValidator(new DeviceInfoValidator()).When(x => x.Device is not null);
    }
}

/// <summary>Second step of "log in as": the token from login and <c>patient</c> or <c>assistant</c>.</summary>
public sealed record SelectAccountRequest(string? SelectionToken, string? Role, DeviceInfo? Device);

public sealed class SelectAccountRequestValidator : AbstractValidator<SelectAccountRequest>
{
    public SelectAccountRequestValidator()
    {
        RuleFor(x => x.SelectionToken).Required().MaxChars(4000);
        RuleFor(x => x.Role).Required().OneOf(Roles.Patient, Roles.Assistant);
        RuleFor(x => x.Device!).SetValidator(new DeviceInfoValidator()).When(x => x.Device is not null);
    }
}

public sealed record RefreshRequest(string? RefreshToken);

public sealed class RefreshRequestValidator : AbstractValidator<RefreshRequest>
{
    public RefreshRequestValidator() => RuleFor(x => x.RefreshToken).Required().MaxChars(200);
}

/// <summary>Logout: the refresh token, and optionally the device ID or push token to remove (UserDevices).</summary>
public sealed record LogoutRequest(string? RefreshToken, string? DeviceId, string? PushToken);

public sealed class LogoutRequestValidator : AbstractValidator<LogoutRequest>
{
    public LogoutRequestValidator()
    {
        RuleFor(x => x.RefreshToken).Required().MaxChars(200);
        RuleFor(x => x.DeviceId).MaxChars(100);
        RuleFor(x => x.PushToken).MaxChars(512);
    }
}

/// <summary>A9. <c>acceptTerms</c> is required (true) for a patient who has not accepted the Terms yet.</summary>
public sealed record SetNewPasswordRequest(string? NewPassword, bool? AcceptTerms, DeviceInfo? Device);

public sealed class SetNewPasswordRequestValidator : AbstractValidator<SetNewPasswordRequest>
{
    public SetNewPasswordRequestValidator()
    {
        RuleFor(x => x.NewPassword).Required().StrongPassword();
        RuleFor(x => x.Device!).SetValidator(new DeviceInfoValidator()).When(x => x.Device is not null);
    }
}

public sealed record ChangePasswordRequest(string? CurrentPassword, string? NewPassword, DeviceInfo? Device);

public sealed class ChangePasswordRequestValidator : AbstractValidator<ChangePasswordRequest>
{
    public ChangePasswordRequestValidator()
    {
        RuleFor(x => x.CurrentPassword).Required().MaxChars(Passwords.MaxLength);
        RuleFor(x => x.NewPassword).Required().StrongPassword();
        RuleFor(x => x.Device!).SetValidator(new DeviceInfoValidator()).When(x => x.Device is not null);
    }
}

/// <summary>A8, email entered (doctors and admins).</summary>
public sealed record RequestPasswordResetEmailRequest(string? Email);

public sealed class RequestPasswordResetEmailRequestValidator : AbstractValidator<RequestPasswordResetEmailRequest>
{
    public RequestPasswordResetEmailRequestValidator() => RuleFor(x => x.Email).Required().Email();
}

/// <summary>A8, mobile entered (patients and assistants).</summary>
public sealed record RequestPatientPasswordResetRequest(string? Phone);

public sealed class RequestPatientPasswordResetRequestValidator : AbstractValidator<RequestPatientPasswordResetRequest>
{
    public RequestPatientPasswordResetRequestValidator() => RuleFor(x => x.Phone).Required().EgyptianMobile();
}

/// <summary>The token from the reset email and the new password.</summary>
public sealed record ResetPasswordRequest(string? Token, string? NewPassword);

public sealed class ResetPasswordRequestValidator : AbstractValidator<ResetPasswordRequest>
{
    public ResetPasswordRequestValidator()
    {
        RuleFor(x => x.Token).Required().MaxChars(200);
        RuleFor(x => x.NewPassword).Required().StrongPassword();
    }
}

public sealed record VerifyEmailRequest(string? Token);

public sealed class VerifyEmailRequestValidator : AbstractValidator<VerifyEmailRequest>
{
    public VerifyEmailRequestValidator() => RuleFor(x => x.Token).Required().MaxChars(200);
}

/// <summary>Language and appearance (A2, D24, P14, AD18). Send either or both.</summary>
public sealed record UpdatePreferencesRequest(string? Locale, string? ThemeMode);

public sealed class UpdatePreferencesRequestValidator : AbstractValidator<UpdatePreferencesRequest>
{
    public UpdatePreferencesRequestValidator()
    {
        RuleFor(x => x.Locale).OneOf("ar", "en");
        RuleFor(x => x.ThemeMode).OneOf("system", "light", "dark");
    }
}

/// <summary>The answer to forgot-password and resend calls, the same whether or not an account exists.</summary>
public sealed record AcceptedResponse(string Status);
