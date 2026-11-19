using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Validation;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Development;

public sealed record DevTokenRequest(string Identifier, string? Role);

public sealed record DevTokenResponse(Guid UserId, string Role, string AccessToken, DateTime ExpiresAt);

/// <summary>
/// Development-only helpers, mapped only when the environment is Development:
/// <c>POST /api/dev/seed</c> creates the demo data, <c>POST /api/dev/token</c> signs in as any demo
/// user without a password. They stand in for Phase 1 login until it exists. Never mapped in prod.
/// </summary>
public static class DevEndpoints
{
    public static void MapDevEndpoints(this WebApplication app)
    {
        if (!app.Environment.IsDevelopment()) return;

        var dev = app.MapGroup("/api/dev").AllowAnonymous().ExcludeFromDescription();

        dev.MapPost("/seed", (DemoDataSeeder seeder, CancellationToken ct) => seeder.SeedAsync(ct));

        dev.MapPost("/token", async (DevTokenRequest request, AppDbContext db, JwtTokenFactory tokens, CancellationToken ct) =>
        {
            var identifier = request.Identifier.Trim().ToLowerInvariant();
            var isEmail = identifier.Contains('@');
            string? phone = null;
            if (!isEmail && !EgyptianPhone.TryNormalize(identifier, out phone)) return Results.BadRequest();

            var user = await db.Users
                .Where(u => isEmail ? u.Email == identifier : u.Phone == phone)
                .Where(u => request.Role == null || u.Role == request.Role)
                .OrderBy(u => u.Role == Roles.Patient ? 0 : 1)
                .FirstOrDefaultAsync(ct);
            if (user is null) return Results.NotFound();

            var doctorId = user.Role == Roles.Assistant
                ? await db.Assistants.Where(a => a.UserId == user.Id).Select(a => (Guid?)a.DoctorId).FirstOrDefaultAsync(ct)
                : null;
            var (token, expires) = tokens.CreateAccessToken(user, doctorId);
            return Results.Ok(new DevTokenResponse(user.Id, user.Role, token, expires));
        });
    }
}
