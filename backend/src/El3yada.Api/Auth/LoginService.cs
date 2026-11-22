using El3yada.Api.Audit;
using El3yada.Api.Configuration;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Auth;

/// <summary>A login identifier (A3): with "@" an email (lower case), otherwise an Egyptian mobile (E.164).</summary>
public sealed record LoginIdentifier(bool IsEmail, string Value)
{
    public static LoginIdentifier? Parse(string? input)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            return null;
        }

        if (input.Contains('@'))
        {
            return RuleBuilderExtensions.IsEmail(input) ? new LoginIdentifier(true, Text.NormalizeEmail(input)) : null;
        }

        return EgyptianMobile.Normalize(input) is { } mobile ? new LoginIdentifier(false, mobile) : null;
    }
}

/// <summary>What <see cref="LoginService"/> decided.</summary>
public abstract record LoginOutcome
{
    public sealed record SignedIn(SignedInResponse Session) : LoginOutcome;

    public sealed record ChooseAccount(ChooseAccountResponse Choice) : LoginOutcome;

    /// <summary>401 INVALID_CREDENTIALS: no account with this identifier and password.</summary>
    public sealed record InvalidCredentials : LoginOutcome;

    /// <summary>429 TOO_MANY_ATTEMPTS until <paramref name="Until"/>.</summary>
    public sealed record Locked(DateTimeOffset Until) : LoginOutcome;

    /// <summary>403 with ACCOUNT_DISABLED, CLINIC_NOT_ACTIVE or PATIENT_DESKTOP_NOT_SUPPORTED. Only after a correct password.</summary>
    public sealed record Refused(string Code) : LoginOutcome;
}

/// <summary>
/// The login rules of A3 and spec 9.1:
/// <list type="bullet">
/// <item>An email matches any account with that email (doctors and admins sign in by email).</item>
/// <item>A mobile matches the patient account and the (not removed) assistant account with that number.
/// The password is checked against each. One match signs in; two matches answer "choose account" with a
/// selection token. Nothing about which accounts exist is revealed before a password matches.</item>
/// <item>Failed passwords count per account (Users.AccessFailedCount) and per identifier (in memory, for
/// identifiers with no account too). At Auth:MaxFailedLogins the account and identifier lock for
/// Auth:LockoutMinutes, answered with 429 TOO_MANY_ATTEMPTS.</item>
/// <item>Disabled accounts, assistants of a clinic that is not active, and patients on desktop are refused
/// with 403, but only once the password is right.</item>
/// </list>
/// </summary>
public sealed class LoginService(
    AppDbContext db,
    Passwords passwords,
    SessionService sessions,
    TokenService tokens,
    IdentifierThrottle throttle,
    Auditor auditor,
    TimeProvider time,
    IOptions<AuthOptions> authOptions,
    ILogger<LoginService> logger)
{
    private const string ThrottlePurpose = IdentifierThrottle.LoginPurpose;

    private AuthOptions Options => authOptions.Value;

    public async Task<LoginOutcome> LoginAsync(
        LoginIdentifier identifier, string password, DeviceInfo? device, string? ipAddress, CancellationToken cancellationToken)
    {
        if (throttle.BlockedUntil(ThrottlePurpose, identifier.Value) is { } blockedUntil)
        {
            return new LoginOutcome.Locked(blockedUntil);
        }

        var now = time.GetUtcNow().UtcDateTime;
        var candidates = await FindCandidatesAsync(identifier, cancellationToken);
        var unlocked = candidates.Where(u => u.LockoutEndAt is null || u.LockoutEndAt <= now).ToList();
        if (candidates.Count > 0 && unlocked.Count == 0)
        {
            return new LoginOutcome.Locked(candidates.Max(u => u.LockoutEndAt!.Value));
        }

        // Always the same number of hash checks (1 for an email, 2 for a mobile), so the response time
        // doesn't tell how many accounts a number has.
        for (var i = unlocked.Count; i < (identifier.IsEmail ? 1 : 2); i++)
        {
            passwords.VerifyDummy(password);
        }

        var matched = unlocked.Where(u => passwords.Verify(u, password)).ToList();
        if (matched.Count == 0)
        {
            await RecordFailureAsync(identifier, unlocked, cancellationToken);
            return new LoginOutcome.InvalidCredentials();
        }

        throttle.Reset(ThrottlePurpose, identifier.Value);
        foreach (var user in matched)
        {
            user.AccessFailedCount = 0;
            user.LockoutEndAt = null;
        }

        // Accounts the password opened, minus those that may not sign in here.
        var eligible = new List<(User User, AccountState State)>();
        string? refusal = null;
        foreach (var user in matched)
        {
            var state = await AccountState.LoadAsync(db, user.Id, cancellationToken);
            var code = state?.BlockCode
                ?? (state?.Role == Roles.Patient && Platforms.IsDesktop(device?.Platform) ? ErrorCodes.PatientDesktopNotSupported : null);
            if (state is null || code is not null)
            {
                refusal ??= code ?? ErrorCodes.AccountDisabled;
                continue;
            }

            eligible.Add((user, state));
        }

        if (eligible.Count == 0)
        {
            await db.SaveChangesAsync(cancellationToken);
            logger.LogInformation("Login refused for user {UserId}: {Code}", matched[0].Id, refusal);
            return new LoginOutcome.Refused(refusal!);
        }

        if (eligible.Count == 1)
        {
            var session = await sessions.SignInAsync(eligible[0].User, device, null, ipAddress, cancellationToken);
            logger.LogInformation("User {UserId} signed in", eligible[0].User.Id);
            return new LoginOutcome.SignedIn(session);
        }

        await db.SaveChangesAsync(cancellationToken);
        return new LoginOutcome.ChooseAccount(await BuildChoiceAsync(eligible.Select(e => e.State).ToList(), cancellationToken));
    }

    /// <summary>The second step of "log in as": the selection token from login and the chosen role.</summary>
    public async Task<LoginOutcome> SelectAccountAsync(
        string selectionToken, string role, DeviceInfo? device, string? ipAddress, CancellationToken cancellationToken)
    {
        var accounts = await tokens.RedeemSelectionTokenAsync(selectionToken);
        if (accounts is null)
        {
            return new LoginOutcome.Refused(ErrorCodes.SelectionTokenInvalid);
        }

        foreach (var (userId, stampHash) in accounts)
        {
            var user = await db.Users.SingleOrDefaultAsync(u => u.Id == userId && u.Role == role, cancellationToken);
            if (user is null)
            {
                continue;
            }

            var state = await AccountState.LoadAsync(db, user.Id, cancellationToken);
            if (state is null || state.StampHash != stampHash)
            {
                // The password changed since the login step.
                return new LoginOutcome.Refused(ErrorCodes.SelectionTokenInvalid);
            }

            var code = state.BlockCode
                ?? (state.Role == Roles.Patient && Platforms.IsDesktop(device?.Platform) ? ErrorCodes.PatientDesktopNotSupported : null);
            if (code is not null)
            {
                return new LoginOutcome.Refused(code);
            }

            var session = await sessions.SignInAsync(user, device, null, ipAddress, cancellationToken);
            logger.LogInformation("User {UserId} signed in after choosing an account", user.Id);
            return new LoginOutcome.SignedIn(session);
        }

        return new LoginOutcome.Refused(ErrorCodes.SelectionTokenInvalid);
    }

    private async Task<List<User>> FindCandidatesAsync(LoginIdentifier identifier, CancellationToken cancellationToken)
    {
        if (identifier.IsEmail)
        {
            return await db.Users.Where(u => u.Email == identifier.Value).ToListAsync(cancellationToken);
        }

        // Patients and assistants sign in with their mobile (A3). A removed assistant can't.
        return await db.Users
            .Where(u => u.Phone == identifier.Value
                && (u.Role == Roles.Patient
                    || (u.Role == Roles.Assistant && u.AssistantUser != null && u.AssistantUser.Status != "removed")))
            .OrderBy(u => u.Role == Roles.Patient ? 0 : 1)
            .ToListAsync(cancellationToken);
    }

    private async Task RecordFailureAsync(LoginIdentifier identifier, List<User> unlocked, CancellationToken cancellationToken)
    {
        var lockout = TimeSpan.FromMinutes(Options.LockoutMinutes);
        throttle.RecordFailure(ThrottlePurpose, identifier.Value, Options.MaxFailedLogins, lockout);

        var now = time.GetUtcNow().UtcDateTime;
        foreach (var user in unlocked)
        {
            user.AccessFailedCount++;
            if (user.AccessFailedCount >= Options.MaxFailedLogins)
            {
                user.AccessFailedCount = 0;
                user.LockoutEndAt = now + lockout;
                auditor.Add(
                    AuditActions.AccountLockedOut, AuditTargets.User, user.Id,
                    new { minutes = Options.LockoutMinutes }, actor: AuditActor.System);
                logger.LogWarning("User {UserId} locked out after failed logins", user.Id);
            }
        }

        if (unlocked.Count > 0)
        {
            await db.SaveChangesAsync(cancellationToken);
        }

        logger.LogInformation("Login failed ({Accounts} matching accounts)", unlocked.Count);
    }

    private async Task<ChooseAccountResponse> BuildChoiceAsync(List<AccountState> states, CancellationToken cancellationToken)
    {
        var doctorIds = states.Where(s => s.Role == Roles.Assistant && s.DoctorId is not null).Select(s => s.DoctorId!.Value).ToList();
        var doctorNames = await db.Doctors
            .Where(d => doctorIds.Contains(d.UserId))
            .ToDictionaryAsync(d => d.UserId, d => d.FullName, cancellationToken);

        var (token, expires) = tokens.CreateSelectionToken(states);
        var choices = states
            .OrderBy(s => s.Role == Roles.Patient ? 0 : 1)
            .Select(s => new AccountChoice(
                s.Role,
                s.DisplayName,
                s.Role == Roles.Assistant && s.DoctorId is { } d ? doctorNames.GetValueOrDefault(d) : null,
                s.IsPendingDeletion))
            .ToList();
        return new ChooseAccountResponse(token, expires, choices);
    }
}
