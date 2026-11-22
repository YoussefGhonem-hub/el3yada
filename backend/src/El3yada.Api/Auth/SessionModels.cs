using System.Text.Json.Serialization;
using FluentValidation;
using El3yada.Api.Doctors;
using El3yada.Api.Features.AccountDeletion;
using El3yada.Api.Validation;
using El3yada.Data;

namespace El3yada.Api.Auth;

/// <summary>
/// The device that signs in (optional in every sign-in call). It ties the refresh token to the device,
/// registers the push token (UserDevices), and lets the API refuse a patient on desktop (A14).
/// </summary>
public sealed record DeviceInfo(string? DeviceId, string? Platform, string? AppVersion, string? PushToken);

public sealed class DeviceInfoValidator : AbstractValidator<DeviceInfo>
{
    public DeviceInfoValidator()
    {
        RuleFor(x => x.DeviceId).Required().MaxChars(100)
            .Must(id => id is null || id.All(c => c is > ' ' and <= '~'))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use printable ASCII characters only.");
        RuleFor(x => x.Platform).Required().OneOf(Platforms.All);
        RuleFor(x => x.AppVersion).Required().MaxChars(20);
        RuleFor(x => x.PushToken).MaxChars(512)
            .Must(token => token is null || token.All(c => c is > ' ' and <= '~'))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use printable ASCII characters only.");
    }
}

/// <summary>
/// Who is signed in and what the app needs for routing (A1). Returned by <c>GET /api/auth/me</c> and,
/// with tokens, by every sign-in call (<see cref="SignedInResponse"/>).
/// </summary>
public class SessionView
{
    public SessionView()
    {
    }

    protected SessionView(SessionView other)
    {
        UserId = other.UserId;
        DisplayName = other.DisplayName;
        Role = other.Role;
        AdminRole = other.AdminRole;
        DoctorId = other.DoctorId;
        AccountStatus = other.AccountStatus;
        DoctorStatus = other.DoctorStatus;
        DoctorStatusReason = other.DoctorStatusReason;
        Trial = other.Trial;
        MustChangePassword = other.MustChangePassword;
        MustAcceptTerms = other.MustAcceptTerms;
        Email = other.Email;
        EmailVerified = other.EmailVerified;
        Phone = other.Phone;
        Locale = other.Locale;
        ThemeMode = other.ThemeMode;
        PendingDeletion = other.PendingDeletion;
    }

    public Guid UserId { get; init; }

    public string DisplayName { get; init; } = "";

    /// <summary><c>admin</c>, <c>doctor</c>, <c>assistant</c> or <c>patient</c>.</summary>
    public string Role { get; init; } = "";

    /// <summary><c>superAdmin</c> or <c>admin</c> for admins, otherwise null.</summary>
    public string? AdminRole { get; init; }

    /// <summary>A doctor's own user ID, or an assistant's doctor. Null for patients and admins.</summary>
    public Guid? DoctorId { get; init; }

    /// <summary>
    /// <c>active</c>, or <c>pendingDeletion</c> during an account's deletion grace period (then
    /// <see cref="PendingDeletion"/> is set and the app shows only A16). A disabled account gets 403 ACCOUNT_DISABLED instead.
    /// </summary>
    public string AccountStatus { get; init; } = AccountStatuses.Active;

    /// <summary>
    /// The account's deletion in progress (BR-DEL3), or null. The session may only restore, sign out, read its own
    /// state and, for a doctor, pay invoices; everything else answers 403 ACCOUNT_PENDING_DELETION.
    /// </summary>
    public PendingDeletionView? PendingDeletion { get; init; }

    /// <summary>
    /// For a doctor, their status; for an assistant, their doctor's (<c>active</c> or <c>suspended</c>; any other
    /// status is refused with CLINIC_NOT_ACTIVE). Null for patients and admins.
    /// </summary>
    public string? DoctorStatus { get; init; }

    /// <summary>The admin's reason when a doctor is <c>rejected</c> (A7) or suspended. Only sent to the doctor.</summary>
    public string? DoctorStatusReason { get; init; }

    /// <summary>
    /// The clinic's free trial (spec 6.16), for a doctor or an assistant; null when there is none (the service is
    /// active) and for other roles. <c>trial.ended</c> sends the app to A15.
    /// </summary>
    public TrialView? Trial { get; init; }

    /// <summary>The user must set a new password before anything else (A9).</summary>
    public bool MustChangePassword { get; init; }

    /// <summary>A patient who has not accepted the Terms: A9 shows the required checkbox.</summary>
    public bool MustAcceptTerms { get; init; }

    public string? Email { get; init; }

    /// <summary>False when the account has an email that is not verified yet (A5). True when it has no email.</summary>
    public bool EmailVerified { get; init; }

    public string? Phone { get; init; }

    public string Locale { get; init; } = "ar";

    public string ThemeMode { get; init; } = "system";

    /// <summary>
    /// The session as of <paramref name="now"/> (the trial's state depends on it), with the deletion in progress read
    /// from the database when the account is in its grace period.
    /// </summary>
    public static async Task<SessionView> OfAsync(AppDbContext db, AccountState account, DateTime now, CancellationToken cancellationToken)
    {
        var view = Of(account, now);
        return account.IsPendingDeletion
            ? new SessionView(view) { PendingDeletion = await PendingDeletionView.LoadAsync(db, account.UserId, account.Role, cancellationToken) }
            : view;
    }

    /// <summary>The session as of <paramref name="now"/>, without <see cref="PendingDeletion"/>: use <see cref="OfAsync"/>.</summary>
    private static SessionView Of(AccountState account, DateTime now) => new()
    {
        UserId = account.UserId,
        DisplayName = account.DisplayName,
        Role = account.Role,
        AdminRole = account.AdminRole,
        DoctorId = account.DoctorId,
        AccountStatus = account.IsPendingDeletion
            ? AccountStatuses.PendingDeletion
            : account.BlockCode is null ? AccountStatuses.Active : AccountStatuses.Disabled,
        DoctorStatus = account.DoctorStatus,
        DoctorStatusReason = account.DoctorStatusReason,
        Trial = account.Role is Roles.Doctor or Roles.Assistant ? TrialView.Of(account.TrialEndsAt, now) : null,
        MustChangePassword = account.MustChangePassword,
        MustAcceptTerms = account.MustAcceptTerms,
        Email = account.Email,
        EmailVerified = account.Email is null || account.EmailVerified,
        Phone = account.Phone,
        Locale = account.Locale,
        ThemeMode = account.ThemeMode,
    };
}

/// <summary>A successful sign-in: <c>result = "signedIn"</c>, the session and its tokens.</summary>
public sealed class SignedInResponse(
    SessionView session, string accessToken, DateTime accessTokenExpiresAt, string refreshToken, DateTime refreshTokenExpiresAt)
    : SessionView(session)
{
    [JsonPropertyOrder(-1)]
    public string Result => "signedIn";

    public string AccessToken { get; } = accessToken;

    public DateTime AccessTokenExpiresAt { get; } = accessTokenExpiresAt;

    public string RefreshToken { get; } = refreshToken;

    public DateTime RefreshTokenExpiresAt { get; } = refreshTokenExpiresAt;
}

/// <summary>
/// The password matched a patient account and an assistant account on the same number (A3).
/// The app asks «الدخول كـ: مريض / مساعد طبيب», then calls <c>selectAccount</c>.
/// </summary>
public sealed record ChooseAccountResponse(
    string SelectionToken, DateTime SelectionTokenExpiresAt, IReadOnlyList<AccountChoice> Accounts)
{
    [JsonPropertyOrder(-1)]
    public string Result => "chooseAccount";
}

/// <summary>
/// One account to choose. <c>DoctorName</c> is the assistant's doctor («عيادة د. …»). <c>PendingDeletion</c>: this
/// account is in its deletion grace period, so choosing it opens the restore screen (A16).
/// </summary>
public sealed record AccountChoice(string Role, string DisplayName, string? DoctorName, bool PendingDeletion = false);
