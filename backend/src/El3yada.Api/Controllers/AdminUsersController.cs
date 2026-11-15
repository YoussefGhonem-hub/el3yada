using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

public sealed record CreateAdminRequest(string? Email, string? DisplayName, string? AdminRole);

public sealed class CreateAdminRequestValidator : AbstractValidator<CreateAdminRequest>
{
    public CreateAdminRequestValidator()
    {
        RuleFor(x => x.Email).Required().Email();
        RuleFor(x => x.DisplayName).Required().FullName();
        RuleFor(x => x.AdminRole).Required().OneOf(AdminRoles.All);
    }
}

public sealed record SetAdminRoleRequest(Guid? UserId, string? AdminRole);

public sealed class SetAdminRoleRequestValidator : AbstractValidator<SetAdminRoleRequest>
{
    public SetAdminRoleRequestValidator()
    {
        RuleFor(x => x.UserId).Required();
        RuleFor(x => x.AdminRole).Required().OneOf(AdminRoles.All);
    }
}

/// <summary><c>status</c>: <c>disabled</c> or <c>active</c>.</summary>
public sealed record SetAdminStatusRequest(Guid? UserId, string? Status);

public sealed class SetAdminStatusRequestValidator : AbstractValidator<SetAdminStatusRequest>
{
    public SetAdminStatusRequestValidator()
    {
        RuleFor(x => x.UserId).Required();
        RuleFor(x => x.Status).Required().OneOf(AccountStatuses.Active, AccountStatuses.Disabled);
    }
}

public sealed record AdminUserView(
    Guid UserId, string DisplayName, string? Email, string AdminRole, string Status, bool MustChangePassword,
    DateTime CreatedAt, DateTime? LastLoginAt);

/// <summary>createAdmin answer: the temporary password is shown once and never stored in clear.</summary>
public sealed record CreatedAdminResponse(AdminUserView Admin, string TemporaryPassword);

public sealed record UpdateAdminProfileRequest(string? DisplayName);

public sealed class UpdateAdminProfileRequestValidator : AbstractValidator<UpdateAdminProfileRequest>
{
    public UpdateAdminProfileRequestValidator() => RuleFor(x => x.DisplayName).Required().FullName();
}

/// <summary>
/// AD14 admin users (super admins only; spec 9.1 <c>createAdmin</c>, <c>setAdminRole</c>) and AD18 admin profile.
/// An admin can't change their own role or disable themselves, and there is always at least one active super admin.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminUsersController(
    AppDbContext db, Passwords passwords, SessionService sessions, Auditor auditor,
    AccountStateCache stateCache, TimeProvider time) : ControllerBase
{
    [HttpGet("admins")]
    [Authorize(Policy = Policies.SuperAdmin)]
    public async Task<IActionResult> List(CancellationToken cancellationToken) =>
        Ok(await db.Users.AsNoTracking()
            .Where(u => u.Role == Roles.Admin)
            .OrderBy(u => u.DisplayName)
            .Select(u => new AdminUserView(u.Id, u.DisplayName, u.Email, u.AdminRole!, u.Status, u.MustChangePassword, u.CreatedAt, u.LastLoginAt))
            .ToListAsync(cancellationToken));

    /// <summary>Creates an admin with a temporary password (shown once); they must set their own at first sign-in (A9).</summary>
    [HttpPost("createAdmin")]
    [Authorize(Policy = Policies.SuperAdmin)]
    public async Task<IActionResult> CreateAdmin(CreateAdminRequest request, CancellationToken cancellationToken)
    {
        var email = Text.NormalizeEmail(request.Email!);
        if (await db.Users.AnyAsync(u => u.Email == email, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.EmailAlreadyRegistered, "An account with this email already exists.");
        }

        var (user, temporaryPassword) = NewAdmin(email, Text.CollapseSpaces(request.DisplayName!), request.AdminRole!, passwords, time);
        db.Users.Add(user);
        auditor.Add(AuditActions.AdminCreated, AuditTargets.User, user.Id, new { adminRole = user.AdminRole });
        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.IsUniqueViolation("UQ_Users_Email"))
        {
            return this.ConflictProblem(ErrorCodes.EmailAlreadyRegistered, "An account with this email already exists.");
        }

        Response.Headers.CacheControl = "no-store";
        return StatusCode(StatusCodes.Status201Created, new CreatedAdminResponse(View(user), temporaryPassword));
    }

    [HttpPost("setAdminRole")]
    [Authorize(Policy = Policies.SuperAdmin)]
    public async Task<IActionResult> SetAdminRole(SetAdminRoleRequest request, CancellationToken cancellationToken)
    {
        var userId = request.UserId!.Value;
        if (userId == User.UserId())
        {
            return this.ConflictProblem(ErrorCodes.CannotChangeOwnRole, "You can't change your own admin role.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var superAdmins = await LockActiveSuperAdminsAsync(cancellationToken);
        var admin = await LockAdminAsync(userId, cancellationToken);
        if (admin is null)
        {
            return this.NotFoundProblem();
        }

        if (admin.AdminRole == request.AdminRole)
        {
            return Ok(View(admin));
        }

        if (admin.AdminRole == AdminRoles.SuperAdmin && admin.Status == AccountStatuses.Active
            && !superAdmins.Any(id => id != admin.Id))
        {
            return this.ConflictProblem(ErrorCodes.LastSuperAdmin, "There must be at least one active super admin.");
        }

        var before = admin.AdminRole;
        admin.AdminRole = request.AdminRole;
        admin.UpdatedAt = time.GetUtcNow().UtcDateTime;
        auditor.Add(AuditActions.AdminRoleChanged, AuditTargets.User, admin.Id, new { before, after = admin.AdminRole });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        // Their current access token now carries the old role: it gets 401 TOKEN_OUTDATED and the app refreshes.
        stateCache.Invalidate(admin.Id);
        return Ok(View(admin));
    }

    /// <summary>Disable (signs the admin out everywhere at once) or enable an admin account.</summary>
    [HttpPost("setAdminStatus")]
    [Authorize(Policy = Policies.SuperAdmin)]
    public async Task<IActionResult> SetAdminStatus(SetAdminStatusRequest request, CancellationToken cancellationToken)
    {
        var userId = request.UserId!.Value;
        if (userId == User.UserId())
        {
            return this.ConflictProblem(ErrorCodes.CannotDisableSelf, "You can't disable your own account.");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var superAdmins = await LockActiveSuperAdminsAsync(cancellationToken);
        var admin = await LockAdminAsync(userId, cancellationToken);
        if (admin is null)
        {
            return this.NotFoundProblem();
        }

        if (admin.Status == request.Status)
        {
            return Ok(View(admin));
        }

        var disable = request.Status == AccountStatuses.Disabled;
        if (disable && admin.AdminRole == AdminRoles.SuperAdmin && !superAdmins.Any(id => id != admin.Id))
        {
            return this.ConflictProblem(ErrorCodes.LastSuperAdmin, "There must be at least one active super admin.");
        }

        admin.Status = request.Status!;
        admin.UpdatedAt = time.GetUtcNow().UtcDateTime;
        auditor.Add(disable ? AuditActions.AdminDisabled : AuditActions.AdminEnabled, AuditTargets.User, admin.Id);
        if (disable)
        {
            await sessions.SignOutEverywhereAsync(admin, cancellationToken);
        }
        else
        {
            await db.SaveChangesAsync(cancellationToken);
            stateCache.Invalidate(admin.Id);
        }

        await transaction.CommitAsync(cancellationToken);
        return Ok(View(admin));
    }

    /// <summary>AD18: the signed-in admin's profile. Password: <c>POST /api/auth/changePassword</c>; language and theme: <c>updatePreferences</c>.</summary>
    [HttpGet("profile")]
    public async Task<IActionResult> GetProfile(CancellationToken cancellationToken)
    {
        var admin = await db.Users.AsNoTracking().SingleAsync(u => u.Id == User.UserId(), cancellationToken);
        return Ok(new { admin = View(admin), admin.Locale, admin.ThemeMode });
    }

    [HttpPost("updateAdminProfile")]
    public async Task<IActionResult> UpdateProfile(UpdateAdminProfileRequest request, CancellationToken cancellationToken)
    {
        var admin = await db.Users.SingleAsync(u => u.Id == User.UserId(), cancellationToken);
        admin.DisplayName = Text.CollapseSpaces(request.DisplayName!);
        admin.UpdatedAt = time.GetUtcNow().UtcDateTime;
        auditor.Add(AuditActions.AdminProfileUpdated, AuditTargets.User, admin.Id);
        await db.SaveChangesAsync(cancellationToken);
        stateCache.Invalidate(admin.Id);
        return Ok(new { admin = View(admin), admin.Locale, admin.ThemeMode });
    }

    /// <summary>A new admin user with a temporary password and <c>mustChangePassword</c>. Shared with seed-admin.</summary>
    internal static (User User, string TemporaryPassword) NewAdmin(
        string email, string displayName, string adminRole, Passwords passwords, TimeProvider time)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var temporaryPassword = Passwords.GenerateTemporary(Passwords.AdminTemporaryLength);
        var user = new User
        {
            Id = Guid.NewGuid(),
            Role = Roles.Admin,
            AdminRole = adminRole,
            Status = AccountStatuses.Active,
            DisplayName = displayName,
            Email = email,
            // The address was typed by a super admin (or the server owner), so it counts as verified.
            EmailVerifiedAt = now,
            SecurityStamp = Guid.NewGuid(),
            MustChangePassword = true,
            CreatedAt = now,
            UpdatedAt = now,
        };
        user.PasswordHash = passwords.Hash(user, temporaryPassword);
        return (user, temporaryPassword);
    }

    private static AdminUserView View(User u) =>
        new(u.Id, u.DisplayName, u.Email, u.AdminRole!, u.Status, u.MustChangePassword, u.CreatedAt, u.LastLoginAt);

    /// <summary>
    /// Locks every active super admin row until the transaction ends and returns their IDs. Every admin change
    /// takes these locks first, in the same order, so two super admins demoting each other at the same moment
    /// run one after the other and the second sees LAST_SUPER_ADMIN.
    /// </summary>
    private Task<List<Guid>> LockActiveSuperAdminsAsync(CancellationToken cancellationToken) =>
        db.Database.SqlQuery<Guid>($"""
            SELECT [Id] AS [Value] FROM [Users] WITH (UPDLOCK, HOLDLOCK)
            WHERE [Role] = 'admin' AND [AdminRole] = 'superAdmin' AND [Status] = 'active'
            """).ToListAsync(cancellationToken);

    /// <summary>Reads the target admin with an update lock.</summary>
    private Task<User?> LockAdminAsync(Guid userId, CancellationToken cancellationToken) =>
        db.Users.FromSqlInterpolated($"SELECT * FROM [Users] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {userId} AND [Role] = 'admin'")
            .SingleOrDefaultAsync(cancellationToken);
}
