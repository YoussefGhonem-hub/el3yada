using El3yada.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>Checks that the API is up, can reach SQL Server, and has every migration applied.</summary>
[ApiController]
[AllowAnonymous]
[Route("api/health")]
[Microsoft.AspNetCore.Authorization.AllowAnonymous]
public class HealthController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var canConnect = await db.Database.CanConnectAsync(cancellationToken);
        if (!canConnect)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new { status = "down", database = "unreachable" });
        }

        var pending = (await db.Database.GetPendingMigrationsAsync(cancellationToken)).ToList();
        return Ok(new
        {
            status = pending.Count == 0 ? "ok" : "migrationsPending",
            database = db.Database.GetDbConnection().Database,
            appliedMigrations = (await db.Database.GetAppliedMigrationsAsync(cancellationToken)).Count(),
            pendingMigrations = pending,
        });
    }
}
