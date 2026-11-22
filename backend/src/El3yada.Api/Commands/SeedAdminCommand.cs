using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Controllers;
using El3yada.Api.Validation;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Commands;

/// <summary>
/// <c>dotnet run --project src/El3yada.Api -- seed-admin &lt;email&gt; [--name "First Last"] [--reset]</c>
/// <para>
/// Creates a super admin (spec section 5: the first super admin comes from a seed script) with a temporary
/// password, printed once, and <c>mustChangePassword</c>. It refuses an email that already exists. With
/// <c>--reset</c>, an existing admin with that email instead gets a new temporary password, becomes an active
/// super admin and is signed out everywhere (recovery when every super admin is locked out). It never touches
/// an account that is not an admin.
/// </para>
/// </summary>
public static class SeedAdminCommand
{
    public const string Name = "seed-admin";

    public const string DefaultDisplayName = "Super Admin";

    public static bool IsInvocation(string[] args) => args.Length > 0 && args[0] == Name;

    /// <summary>Runs the command with the app's services and returns the process exit code.</summary>
    public static async Task<int> RunAsync(IServiceProvider services, string[] args, TextWriter output)
    {
        await using var scope = services.CreateAsyncScope();
        var provider = scope.ServiceProvider;
        return await ExecuteAsync(
            provider.GetRequiredService<AppDbContext>(),
            provider.GetRequiredService<Passwords>(),
            provider.GetRequiredService<TimeProvider>(),
            args,
            output);
    }

    /// <summary>The command itself, called directly by tests. <paramref name="args"/> starts with "seed-admin".</summary>
    public static async Task<int> ExecuteAsync(
        AppDbContext db, Passwords passwords, TimeProvider time, string[] args, TextWriter output, CancellationToken cancellationToken = default)
    {
        if (!TryParse(args, out var email, out var displayName, out var reset, out var error))
        {
            await output.WriteLineAsync(error);
            await output.WriteLineAsync($"Usage: dotnet run --project src/El3yada.Api -- {Name} <email> [--name \"First Last\"] [--reset]");
            return 2;
        }

        var existing = await db.Users.SingleOrDefaultAsync(u => u.Email == email, cancellationToken);
        if (existing is not null)
        {
            if (!reset)
            {
                await output.WriteLineAsync($"An account with the email {email} already exists. Nothing was changed.");
                await output.WriteLineAsync("To give an existing admin a new temporary password, add --reset.");
                return 1;
            }

            if (existing.Role != Roles.Admin)
            {
                await output.WriteLineAsync($"The account {email} is not an admin ({existing.Role}). Nothing was changed.");
                return 1;
            }

            var newPassword = Passwords.GenerateTemporary(Passwords.AdminTemporaryLength);
            var now = time.GetUtcNow().UtcDateTime;
            existing.PasswordHash = passwords.Hash(existing, newPassword);
            existing.MustChangePassword = true;
            existing.AdminRole = AdminRoles.SuperAdmin;
            existing.Status = AccountStatuses.Active;
            existing.AccessFailedCount = 0;
            existing.LockoutEndAt = null;
            existing.SecurityStamp = Guid.NewGuid();
            existing.UpdatedAt = now;
            // Recovery also ends a deletion in progress, so the daily job doesn't erase the account just brought back.
            await db.DeletionRequests
                .Where(r => r.UserId == existing.Id && (r.Status == "scheduled" || r.Status == "waitingPayment"))
                .ExecuteUpdateAsync(
                    set => set.SetProperty(r => r.Status, "restored").SetProperty(r => r.RestoredAt, (DateTime?)now)
                        .SetProperty(r => r.RestoredBy, (Guid?)existing.Id).SetProperty(r => r.RestoreReason, "seed-admin --reset"),
                    cancellationToken);
            db.AuditLogs.Add(AuditRow(existing.Id, "reset", now));
            await db.SaveChangesAsync(cancellationToken);
            await db.RefreshTokens.Where(t => t.UserId == existing.Id && t.RevokedAt == null)
                .ExecuteUpdateAsync(set => set.SetProperty(t => t.RevokedAt, now), cancellationToken);
            await PrintAsync(output, "Reset the super admin", email, newPassword);
            return 0;
        }

        var (user, temporaryPassword) = AdminUsersController.NewAdmin(email, displayName, AdminRoles.SuperAdmin, passwords, time);
        db.Users.Add(user);
        db.AuditLogs.Add(AuditRow(user.Id, "created", user.CreatedAt));
        await db.SaveChangesAsync(cancellationToken);
        await PrintAsync(output, "Created the super admin", email, temporaryPassword);
        return 0;
    }

    private static Data.Entities.AuditLog AuditRow(Guid userId, string what, DateTime at) => new()
    {
        ActorRole = AuditActor.System.Role,
        Action = AuditActions.AdminSeeded,
        TargetType = AuditTargets.User,
        TargetId = userId.ToString(),
        DetailsJson = Auditor.Serialize(new { what, adminRole = AdminRoles.SuperAdmin }),
        At = at,
    };

    private static async Task PrintAsync(TextWriter output, string what, string email, string password)
    {
        await output.WriteLineAsync($"{what} {email}.");
        await output.WriteLineAsync($"Temporary password (shown once): {password}");
        await output.WriteLineAsync("Sign in with it; the app then asks for a new password.");
    }

    private static bool TryParse(string[] args, out string email, out string displayName, out bool reset, out string error)
    {
        email = "";
        displayName = DefaultDisplayName;
        reset = false;
        error = "";
        string? rawEmail = null;
        for (var i = 1; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--reset":
                    reset = true;
                    break;
                case "--name" when i + 1 < args.Length:
                    displayName = Text.CollapseSpaces(args[++i]);
                    break;
                case var value when !value.StartsWith("--", StringComparison.Ordinal) && rawEmail is null:
                    rawEmail = value;
                    break;
                default:
                    error = $"Unknown argument: {args[i]}";
                    return false;
            }
        }

        if (rawEmail is null || !RuleBuilderExtensions.IsEmail(rawEmail))
        {
            error = "Give the admin's email address.";
            return false;
        }

        if (!RuleBuilderExtensions.IsFullName(displayName))
        {
            error = "The --name must be a first and a last name (letters only).";
            return false;
        }

        email = Text.NormalizeEmail(rawEmail);
        return true;
    }
}
