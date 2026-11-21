using El3yada.Api.Configuration;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Auth;

/// <summary>
/// Everything about an account that decides whether it may use the API and where the app sends it (A1),
/// read from Users, Doctors, Assistants and Patients in one query.
/// </summary>
public sealed record AccountState
{
    public required Guid UserId { get; init; }
    public required string Role { get; init; }
    public string? AdminRole { get; init; }
    public required string UserStatus { get; init; }
    public required Guid SecurityStamp { get; init; }
    public required bool MustChangePassword { get; init; }
    public required string DisplayName { get; init; }
    public string? Email { get; init; }
    public bool EmailVerified { get; init; }
    public string? Phone { get; init; }
    public required string Locale { get; init; }
    public required string ThemeMode { get; init; }
    public DateTime? AcceptedTermsAt { get; init; }

    /// <summary>A doctor's own ID, or an assistant's doctor.</summary>
    public Guid? DoctorId { get; init; }

    /// <summary>A doctor's own status, or an assistant's doctor's status.</summary>
    public string? DoctorStatus { get; init; }

    /// <summary>The rejection (or suspension) reason. Only for the doctor themselves, never for assistants.</summary>
    public string? DoctorStatusReason { get; init; }

    /// <summary>The clinic's free trial end (Doctors.TrialEndsAt): the doctor's own, or an assistant's doctor's.</summary>
    public DateTime? TrialEndsAt { get; init; }

    public string? AssistantStatus { get; init; }

    /// <summary>For an assistant: whether their doctor's user account is active.</summary>
    public bool DoctorUserActive { get; init; } = true;

    public string? PatientStatus { get; init; }

    public string StampHash => SecretTokens.StampHash(SecurityStamp);

    /// <summary>
    /// The account is in its deletion grace period (BR-DEL2): the session may only restore, sign out, read its own
    /// state and, for a doctor, pay invoices (<see cref="AllowWhilePendingDeletionAttribute"/>).
    /// </summary>
    public bool IsPendingDeletion => UserStatus == AccountStatuses.PendingDeletion;

    /// <summary>
    /// Why this account may not use the API at all, or null. <c>ACCOUNT_DISABLED</c>: the user, doctor,
    /// assistant or patient record is disabled or removed. <c>CLINIC_NOT_ACTIVE</c>: an assistant whose doctor
    /// is pending, rejected or disabled (BR-AS9). Pending, rejected and suspended doctors are not blocked here:
    /// they sign in and see A6, A7 or the suspension banner. Nor is a clinic whose free trial ended: its doctor and
    /// assistants sign in and see A15 (BR-T4). Nor is an account waiting for its deletion: it signs in to the restore
    /// screen (A16, BR-DEL3), whatever its clinic's state.
    /// </summary>
    public string? BlockCode => this switch
    {
        { UserStatus: AccountStatuses.PendingDeletion } => null,
        { UserStatus: not AccountStatuses.Active } => ErrorCodes.AccountDisabled,
        { Role: Roles.Doctor, DoctorStatus: DoctorStatuses.Disabled or null } => ErrorCodes.AccountDisabled,
        { Role: Roles.Assistant, AssistantStatus: not "active" } => ErrorCodes.AccountDisabled,
        { Role: Roles.Assistant } when !DoctorUserActive || !DoctorStatuses.ClinicIsOpen(DoctorStatus) => ErrorCodes.ClinicNotActive,
        { Role: Roles.Patient, PatientStatus: not "active" } => ErrorCodes.AccountDisabled,
        _ => null,
    };

    /// <summary>A patient who has not accepted the Terms yet must accept them in A9 (spec section 12).</summary>
    public bool MustAcceptTerms => Role == Roles.Patient && AcceptedTermsAt is null;

    public bool IsSuperAdmin => Role == Roles.Admin && AdminRole == AdminRoles.SuperAdmin;

    /// <summary>Reads the current state from the database, or null when the user does not exist.</summary>
    public static Task<AccountState?> LoadAsync(AppDbContext db, Guid userId, CancellationToken cancellationToken) =>
        db.Users.AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => new AccountState
            {
                UserId = u.Id,
                Role = u.Role,
                AdminRole = u.AdminRole,
                UserStatus = u.Status,
                SecurityStamp = u.SecurityStamp,
                MustChangePassword = u.MustChangePassword,
                DisplayName = u.DisplayName,
                Email = u.Email,
                EmailVerified = u.EmailVerifiedAt != null,
                Phone = u.Phone,
                Locale = u.Locale,
                ThemeMode = u.ThemeMode,
                AcceptedTermsAt = u.AcceptedTermsAt,
                DoctorId = u.Role == Roles.Doctor ? u.Id : u.AssistantUser != null ? u.AssistantUser.DoctorId : null,
                DoctorStatus = u.Role == Roles.Doctor
                    ? u.DoctorUser!.Status
                    : u.AssistantUser != null ? u.AssistantUser.Doctor.Status : null,
                DoctorStatusReason = u.Role == Roles.Doctor ? u.DoctorUser!.StatusReason : null,
                TrialEndsAt = u.Role == Roles.Doctor
                    ? u.DoctorUser!.TrialEndsAt
                    : u.AssistantUser != null ? u.AssistantUser.Doctor.TrialEndsAt : null,
                AssistantStatus = u.AssistantUser != null ? u.AssistantUser.Status : null,
                DoctorUserActive = u.AssistantUser == null || u.AssistantUser.Doctor.User.Status == AccountStatuses.Active,
                PatientStatus = u.Patient != null ? u.Patient.Status : null,
            })
            .SingleOrDefaultAsync(cancellationToken);
}

/// <summary>
/// A short cache of <see cref="AccountState"/> for the check that runs on every authenticated request
/// (security stamp, status, role). Every endpoint that changes one of those calls <see cref="Invalidate"/>
/// after saving, so this API instance sees the change at once. Other instances see it within
/// Auth:UserStateCacheSeconds (30 s by default).
/// </summary>
public sealed class AccountStateCache(IMemoryCache cache, IOptions<AuthOptions> options)
{
    private readonly TimeSpan _lifetime = TimeSpan.FromSeconds(options.Value.UserStateCacheSeconds);

    public async Task<AccountState?> GetAsync(AppDbContext db, Guid userId, CancellationToken cancellationToken)
    {
        var key = Key(userId);
        if (cache.TryGetValue(key, out AccountState? state))
        {
            return state;
        }

        state = await AccountState.LoadAsync(db, userId, cancellationToken);
        if (state is not null && _lifetime > TimeSpan.Zero)
        {
            cache.Set(key, state, _lifetime);
        }

        return state;
    }

    public void Invalidate(Guid userId) => cache.Remove(Key(userId));

    private static string Key(Guid userId) => $"account-state:{userId:N}";
}
