using System.Security.Claims;
using El3yada.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Infrastructure.Auth;

/// <summary>
/// Authorization policies. Everything is denied by default (the fallback policy
/// is <see cref="SignedIn"/>); public endpoints opt out with <c>[AllowAnonymous]</c>.
/// Doctor and assistant policies (permissions, doctor status) are added in Phase 2.
/// </summary>
public static class Policies
{
    /// <summary>Any active account.</summary>
    public const string SignedIn = "signedIn";

    public const string Patient = "patient";

    /// <summary>The doctor or an assistant. Permissions and the doctor's status come from <see cref="StaffAccess"/>.</summary>
    public const string Staff = "staff";

    /// <summary>Both admin sub-roles.</summary>
    public const string Admin = "admin";

    public static void Configure(AuthorizationOptions options)
    {
        var signedIn = Build(Roles.Admin, Roles.Doctor, Roles.Assistant, Roles.Patient);
        options.AddPolicy(SignedIn, signedIn);
        options.AddPolicy(Patient, Build(Roles.Patient));
        options.AddPolicy(Staff, Build(Roles.Doctor, Roles.Assistant));
        options.AddPolicy(Admin, Build(Roles.Admin));
        options.FallbackPolicy = signedIn;
    }

    private static AuthorizationPolicy Build(params string[] roles) =>
        new AuthorizationPolicyBuilder()
            .RequireAuthenticatedUser()
            .AddRequirements(new ActiveAccountRequirement(roles))
            .Build();
}

/// <summary>The caller has one of <see cref="Roles"/>, and their account is active right now.</summary>
public sealed class ActiveAccountRequirement(IReadOnlyCollection<string> roles) : IAuthorizationRequirement
{
    public IReadOnlyCollection<string> Roles { get; } = roles;
}

/// <summary>
/// Reads the account from the database on every request (spec 9.4), so a disabled
/// account or a password change (new <c>SecurityStamp</c>) takes effect at once,
/// without waiting for the access token to expire.
/// </summary>
public sealed class ActiveAccountHandler(AppDbContext db, IHttpContextAccessor accessor)
    : AuthorizationHandler<ActiveAccountRequirement>
{
    private const string CacheKey = "el3yada.account";

    private sealed record Account(string Role, string Status, Guid SecurityStamp);

    protected override async Task HandleRequirementAsync(AuthorizationHandlerContext context, ActiveAccountRequirement requirement)
    {
        var userId = HttpCurrentUser.TryGetUserId(context.User);
        var role = context.User.FindFirstValue(AuthClaims.Role);
        if (userId is null || role is null || !requirement.Roles.Contains(role)) return;

        var account = await LoadAsync(userId.Value);
        if (account is null || account.Role != role || account.Status != "active") return;

        var stamp = context.User.FindFirstValue(AuthClaims.SecurityStamp);
        if (!Guid.TryParse(stamp, out var tokenStamp) || tokenStamp != account.SecurityStamp) return;

        context.Succeed(requirement);
    }

    // One query per request, even when several policies run.
    private async Task<Account?> LoadAsync(Guid userId)
    {
        var items = accessor.HttpContext?.Items;
        if (items?.TryGetValue(CacheKey, out var cached) == true) return (Account?)cached;

        var account = await db.Users.AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => new Account(u.Role, u.Status, u.SecurityStamp))
            .FirstOrDefaultAsync();

        if (items is not null) items[CacheKey] = account;
        return account;
    }
}
