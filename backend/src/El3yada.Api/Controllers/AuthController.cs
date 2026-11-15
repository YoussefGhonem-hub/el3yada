using System.Globalization;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Configuration;
using El3yada.Api.Email;
using El3yada.Api.Notifications;
using El3yada.Api.Validation;
using El3yada.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Controllers;

/// <summary>
/// Sign-in, sessions and passwords (A1, A3, A5, A8, A9; spec 9.1 <c>login</c>, <c>requestPatientPasswordReset</c>).
/// The contract for the app is backend/docs/api-phase-1.md.
/// </summary>
[ApiController]
[Route("api/auth")]
public sealed class AuthController(
    AppDbContext db,
    LoginService login,
    SessionService sessions,
    Passwords passwords,
    EmailTokens emailTokens,
    EmailTemplates emailTemplates,
    EmailQueue emailQueue,
    IdentifierThrottle throttle,
    NotificationWriter notifications,
    Auditor auditor,
    AccountStateCache stateCache,
    TimeProvider time,
    IOptions<AuthOptions> authOptions,
    IOptions<RateLimitOptions> rateLimits) : ControllerBase
{
    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>A3: email or mobile and password → a session, or "choose account" (same number, two accounts).</summary>
    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Login)]
    public async Task<IActionResult> Login(LoginRequest request, CancellationToken cancellationToken)
    {
        var identifier = LoginIdentifier.Parse(request.Identifier)!;
        var outcome = await login.LoginAsync(identifier, request.Password!, request.Device, HttpContext.ClientIp(), cancellationToken);
        return ToResult(outcome);
    }

    /// <summary>"Log in as" (A3): completes a login that answered <c>chooseAccount</c>.</summary>
    [HttpPost("selectAccount")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Login)]
    public async Task<IActionResult> SelectAccount(SelectAccountRequest request, CancellationToken cancellationToken)
    {
        var outcome = await login.SelectAccountAsync(
            request.SelectionToken!, request.Role!, request.Device, HttpContext.ClientIp(), cancellationToken);
        return ToResult(outcome);
    }

    /// <summary>New access and refresh tokens for a refresh token. The old refresh token stops working.</summary>
    [HttpPost("refresh")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Refresh)]
    public async Task<IActionResult> Refresh(RefreshRequest request, CancellationToken cancellationToken)
    {
        var outcome = await sessions.RefreshAsync(request.RefreshToken!, HttpContext.ClientIp(), cancellationToken);
        return outcome switch
        {
            { Session: { } session } => Ok(session),
            { ErrorCode: ErrorCodes.RefreshTokenReused } => this.Problem(
                StatusCodes.Status401Unauthorized, ErrorCodes.RefreshTokenReused, "This session was revoked. Sign in again."),
            { ErrorCode: ErrorCodes.AccountDisabled } => this.ForbiddenProblem(ErrorCodes.AccountDisabled, "This account is disabled."),
            { ErrorCode: ErrorCodes.ClinicNotActive } => this.ForbiddenProblem(ErrorCodes.ClinicNotActive, "The clinic account is not active."),
            _ => this.Problem(StatusCodes.Status401Unauthorized, ErrorCodes.RefreshTokenInvalid, "Sign in again."),
        };
    }

    /// <summary>Ends this device's session and removes its push token. Always 204, even for an unknown token.</summary>
    [HttpPost("logout")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Refresh)]
    public async Task<IActionResult> Logout(LogoutRequest request, CancellationToken cancellationToken)
    {
        await sessions.LogoutAsync(request.RefreshToken!, Text.TrimToNull(request.DeviceId), Text.TrimToNull(request.PushToken), cancellationToken);
        return NoContent();
    }

    /// <summary>The signed-in account, for splash routing (A1) and the A6 "Refresh" button.</summary>
    [HttpGet("me")]
    [AllowWhilePasswordChangeRequired]
    public async Task<IActionResult> Me(CancellationToken cancellationToken)
    {
        var account = await AccountState.LoadAsync(db, User.UserId(), cancellationToken);
        return account is null ? this.NotFoundProblem() : Ok(SessionView.Of(account));
    }

    /// <summary>Language and appearance, saved in Users.Locale and Users.ThemeMode (push language, spec 12).</summary>
    [HttpPost("updatePreferences")]
    [AllowWhilePasswordChangeRequired]
    public async Task<IActionResult> UpdatePreferences(UpdatePreferencesRequest request, CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleAsync(u => u.Id == User.UserId(), cancellationToken);
        user.Locale = request.Locale ?? user.Locale;
        user.ThemeMode = request.ThemeMode ?? user.ThemeMode;
        user.UpdatedAt = Now;
        await db.SaveChangesAsync(cancellationToken);
        stateCache.Invalidate(user.Id);
        return Ok(SessionView.Of((await AccountState.LoadAsync(db, user.Id, cancellationToken))!));
    }

    /// <summary>
    /// A9: the first password of an account created with a temporary one (or after a reset by the doctor).
    /// Signs out every other device and returns a new session for this one.
    /// </summary>
    [HttpPost("setNewPassword")]
    [AllowWhilePasswordChangeRequired]
    public async Task<IActionResult> SetNewPassword(SetNewPasswordRequest request, CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleAsync(u => u.Id == User.UserId(), cancellationToken);
        if (!user.MustChangePassword)
        {
            return this.ConflictProblem(ErrorCodes.PasswordChangeNotRequired, "Use changePassword to change the password.");
        }

        if (user.Role == Roles.Patient && user.AcceptedTermsAt is null && request.AcceptTerms != true)
        {
            return ValidationProblems.Field(HttpContext, "acceptTerms", ErrorCodes.TermsNotAccepted, "Accept the Terms and Privacy Policy.");
        }

        if (passwords.Verify(user, request.NewPassword!))
        {
            return ValidationProblems.Field(HttpContext, "newPassword", ErrorCodes.PasswordSameAsOld, "Choose a password you haven't used here.");
        }

        user.PasswordHash = passwords.Hash(user, request.NewPassword!);
        user.MustChangePassword = false;
        user.AccessFailedCount = 0;
        user.LockoutEndAt = null;
        if (request.AcceptTerms == true && user.AcceptedTermsAt is null)
        {
            user.AcceptedTermsAt = Now;
        }

        auditor.Add(AuditActions.PasswordSet, AuditTargets.User, user.Id, new { termsAccepted = user.AcceptedTermsAt is not null });
        return Ok(await RestartSessionAsync(user, request.Device, cancellationToken));
    }

    /// <summary>Change password (D22, P14, AS12, AD18). Signs out every other device.</summary>
    [HttpPost("changePassword")]
    [AllowWhilePasswordChangeRequired]
    [EnableRateLimiting(RateLimitPolicies.Login)]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest request, CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleAsync(u => u.Id == User.UserId(), cancellationToken);
        if (!passwords.Verify(user, request.CurrentPassword!))
        {
            return ValidationProblems.Field(HttpContext, "currentPassword", ErrorCodes.CurrentPasswordIncorrect, "The current password is wrong.");
        }

        if (Passwords.Normalize(request.CurrentPassword!) == Passwords.Normalize(request.NewPassword!))
        {
            return ValidationProblems.Field(HttpContext, "newPassword", ErrorCodes.PasswordSameAsOld, "Choose a new password.");
        }

        user.PasswordHash = passwords.Hash(user, request.NewPassword!);
        user.MustChangePassword = false;
        auditor.Add(AuditActions.PasswordChanged, AuditTargets.User, user.Id);
        return Ok(await RestartSessionAsync(user, request.Device, cancellationToken));
    }

    /// <summary>A8, email (doctors and admins): emails a reset link. The same answer whether or not the email exists.</summary>
    [HttpPost("requestPasswordResetEmail")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.PasswordReset)]
    public async Task<IActionResult> RequestPasswordResetEmail(RequestPasswordResetEmailRequest request, CancellationToken cancellationToken)
    {
        var email = Text.NormalizeEmail(request.Email!);
        if (!throttle.TryAcquire("resetEmail", email, rateLimits.Value.PasswordResetPerIdentifierPerHour, TimeSpan.FromHours(1)))
        {
            return TooManyAttempts(TimeSpan.FromHours(1));
        }

        var user = await db.Users.SingleOrDefaultAsync(
            u => u.Email == email && (u.Role == Roles.Doctor || u.Role == Roles.Admin) && u.Status == AccountStatuses.Active,
            cancellationToken);
        if (user is not null)
        {
            var minutes = authOptions.Value.PasswordResetTokenMinutes;
            var token = await emailTokens.IssueAsync(user.Id, UserTokenPurposes.PasswordReset, TimeSpan.FromMinutes(minutes), cancellationToken);
            auditor.Add(AuditActions.PasswordResetRequested, AuditTargets.User, user.Id, new { channel = "email" }, actor: AuditActor.System);
            await db.SaveChangesAsync(cancellationToken);
            emailQueue.Enqueue(emailTemplates.PasswordReset(user.Email!, user.DisplayName, user.Locale, token, minutes, user.Id));
        }

        return Accepted(new AcceptedResponse("requested"));
    }

    /// <summary>
    /// A8, mobile (patients and assistants), spec 9.1 <c>requestPatientPasswordReset</c>: notifies every doctor
    /// linked to the patient and their assistants with <c>patientsResetPassword</c>; for an assistant, their doctor.
    /// The same answer whether or not the number exists.
    /// </summary>
    [HttpPost("requestPatientPasswordReset")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.PasswordReset)]
    public async Task<IActionResult> RequestPatientPasswordReset(RequestPatientPasswordResetRequest request, CancellationToken cancellationToken)
    {
        var phone = EgyptianMobile.Normalize(request.Phone)!;
        if (!throttle.TryAcquire("resetPhone", phone, rateLimits.Value.PasswordResetPerIdentifierPerHour, TimeSpan.FromHours(1)))
        {
            return TooManyAttempts(TimeSpan.FromHours(1));
        }

        await NotifyPatientDoctorsAsync(phone, cancellationToken);
        await NotifyAssistantDoctorAsync(phone, cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        return Accepted(new AcceptedResponse("requested"));
    }

    /// <summary>Sets a new password with the token from the reset email. Signs out every device.</summary>
    [HttpPost("resetPassword")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.EmailToken)]
    public async Task<IActionResult> ResetPassword(ResetPasswordRequest request, CancellationToken cancellationToken)
    {
        var (token, error) = await emailTokens.RedeemAsync(request.Token!.Trim(), UserTokenPurposes.PasswordReset, cancellationToken);
        if (token is null)
        {
            return EmailTokenProblem(error!);
        }

        var user = token.User;
        user.PasswordHash = passwords.Hash(user, request.NewPassword!);
        user.MustChangePassword = false;
        user.AccessFailedCount = 0;
        user.LockoutEndAt = null;
        // The link reached this inbox, so the address is verified too.
        user.EmailVerifiedAt ??= Now;
        auditor.Add(AuditActions.PasswordReset, AuditTargets.User, user.Id, new { channel = "email" }, actor: new AuditActor(user.Id, user.Role));
        await sessions.SignOutEverywhereAsync(user, cancellationToken);
        return Ok(new AcceptedResponse("passwordReset"));
    }

    /// <summary>A5 [S]: the token from the verification email.</summary>
    [HttpPost("verifyEmail")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.EmailToken)]
    public async Task<IActionResult> VerifyEmail(VerifyEmailRequest request, CancellationToken cancellationToken)
    {
        var (token, error) = await emailTokens.RedeemAsync(request.Token!.Trim(), UserTokenPurposes.EmailVerify, cancellationToken);
        if (token is null)
        {
            return EmailTokenProblem(error!);
        }

        token.User.EmailVerifiedAt ??= Now;
        auditor.Add(AuditActions.EmailVerified, AuditTargets.User, token.UserId, actor: new AuditActor(token.UserId, token.User.Role));
        await db.SaveChangesAsync(cancellationToken);
        stateCache.Invalidate(token.UserId);
        return Ok(new AcceptedResponse("emailVerified"));
    }

    /// <summary>A5 [S] "Resend": a new verification email, at most one a minute.</summary>
    [HttpPost("resendVerificationEmail")]
    public async Task<IActionResult> ResendVerificationEmail(CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleAsync(u => u.Id == User.UserId(), cancellationToken);
        if (user.Email is null)
        {
            return this.Problem(StatusCodes.Status400BadRequest, ErrorCodes.InvalidRequest, "This account has no email address.");
        }

        if (user.EmailVerifiedAt is not null)
        {
            return this.ConflictProblem(ErrorCodes.EmailAlreadyVerified, "The email address is already verified.");
        }

        var cooldown = TimeSpan.FromSeconds(authOptions.Value.VerificationEmailCooldownSeconds);
        if (await emailTokens.LastIssuedAsync(user.Id, UserTokenPurposes.EmailVerify, cancellationToken) is { } last
            && Now - last < cooldown)
        {
            return TooManyAttempts(cooldown - (Now - last), ErrorCodes.VerificationEmailCooldown);
        }

        var hours = authOptions.Value.EmailVerificationTokenHours;
        var token = await emailTokens.IssueAsync(user.Id, UserTokenPurposes.EmailVerify, TimeSpan.FromHours(hours), cancellationToken);
        await db.SaveChangesAsync(cancellationToken);
        emailQueue.Enqueue(emailTemplates.VerifyEmail(user.Email, user.DisplayName, user.Locale, token, hours, user.Id));
        return Accepted(new AcceptedResponse("sent"));
    }

    /// <summary>After a password change: everyone out, then a fresh session for the device that made the change.</summary>
    private async Task<SignedInResponse> RestartSessionAsync(Data.Entities.User user, DeviceInfo? device, CancellationToken cancellationToken)
    {
        string? deviceId = null;
        if (TokenService.SessionOf(User) is { } familyId)
        {
            deviceId = await db.RefreshTokens.Where(t => t.FamilyId == familyId).Select(t => t.DeviceId).FirstOrDefaultAsync(cancellationToken);
        }

        await sessions.SignOutEverywhereAsync(user, cancellationToken);
        return await sessions.SignInAsync(user, device, deviceId, HttpContext.ClientIp(), cancellationToken);
    }

    private async Task NotifyPatientDoctorsAsync(string phone, CancellationToken cancellationToken)
    {
        var patient = await db.Patients
            .Where(p => p.Phone == phone && p.Status == "active" && p.User.Role == Roles.Patient && p.User.Status == AccountStatuses.Active)
            .Select(p => new { p.Id, p.UserId })
            .SingleOrDefaultAsync(cancellationToken);
        if (patient is null)
        {
            return;
        }

        var links = await db.DoctorPatients
            .Where(l => l.PatientId == patient.Id && (l.Doctor.Status == DoctorStatuses.Active || l.Doctor.Status == DoctorStatuses.Suspended))
            .Select(l => new
            {
                l.Id,
                l.DoctorId,
                l.PatientName,
                Assistants = l.Doctor.Assistants
                    .Where(a => a.PatientsResetPassword && a.Status == "active" && a.User.Status == AccountStatuses.Active)
                    .Select(a => a.UserId)
                    .ToList(),
            })
            .ToListAsync(cancellationToken);

        foreach (var link in links)
        {
            var text = NotificationTexts.PatientResetRequested(link.PatientName);
            var data = new { patientId = patient.Id, linkId = link.Id };
            foreach (var recipient in link.Assistants.Prepend(link.DoctorId))
            {
                notifications.Add(recipient, text, $"/patients/{patient.Id}", data);
            }
        }

        if (links.Count > 0)
        {
            auditor.Add(
                AuditActions.PasswordResetRequested, AuditTargets.User, patient.UserId,
                new { channel = "doctor", doctors = links.Count }, patientId: patient.Id, actor: AuditActor.System);
        }
    }

    private async Task NotifyAssistantDoctorAsync(string phone, CancellationToken cancellationToken)
    {
        var assistants = await db.Assistants
            .Where(a => a.Phone == phone && a.Status != "removed" && a.User.Role == Roles.Assistant)
            .Select(a => new { a.UserId, a.DoctorId, a.FullName })
            .ToListAsync(cancellationToken);
        foreach (var assistant in assistants)
        {
            notifications.Add(
                assistant.DoctorId, NotificationTexts.AssistantResetRequested(assistant.FullName),
                $"/assistants/{assistant.UserId}", new { assistantId = assistant.UserId });
            auditor.Add(
                AuditActions.PasswordResetRequested, AuditTargets.User, assistant.UserId,
                new { channel = "doctor" }, doctorId: assistant.DoctorId, actor: AuditActor.System);
        }
    }

    private IActionResult ToResult(LoginOutcome outcome) => outcome switch
    {
        LoginOutcome.SignedIn signedIn => Ok(signedIn.Session),
        LoginOutcome.ChooseAccount choose => Ok(choose.Choice),
        LoginOutcome.Locked locked => TooManyAttempts(locked.Until - time.GetUtcNow()),
        LoginOutcome.Refused { Code: ErrorCodes.SelectionTokenInvalid } => this.Problem(
            StatusCodes.Status401Unauthorized, ErrorCodes.SelectionTokenInvalid, "Sign in again."),
        LoginOutcome.Refused refused => this.ForbiddenProblem(refused.Code, refused.Code switch
        {
            ErrorCodes.ClinicNotActive => "The clinic account is not active.",
            ErrorCodes.PatientDesktopNotSupported => "Patient accounts use the mobile app.",
            _ => "This account is disabled.",
        }),
        _ => this.Problem(StatusCodes.Status401Unauthorized, ErrorCodes.InvalidCredentials, "Wrong identifier or password."),
    };

    private ObjectResult TooManyAttempts(TimeSpan retryAfter, string code = ErrorCodes.TooManyAttempts)
    {
        var seconds = Math.Max(1, (int)Math.Ceiling(retryAfter.TotalSeconds));
        Response.Headers.RetryAfter = seconds.ToString(CultureInfo.InvariantCulture);
        return this.Problem(StatusCodes.Status429TooManyRequests, code, "Too many attempts. Try again later.");
    }

    private ObjectResult EmailTokenProblem(string code) => this.Problem(StatusCodes.Status400BadRequest, code, code switch
    {
        ErrorCodes.EmailTokenExpired => "This link has expired. Ask for a new one.",
        ErrorCodes.EmailTokenUsed => "This link was already used.",
        _ => "This link is not valid.",
    });
}
