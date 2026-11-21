using El3yada.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>Checks that the API is up, can reach SQL Server, and has every migration applied.</summary>
[ApiController]
[AllowAnonymous]
[Route("api/health")]
public class HealthController(AppDbContext db, El3yada.Api.Billing.JobStatus jobs) : ControllerBase
{
    /// <summary>
    /// 200 while every scheduled billing job's last run succeeded (or none has run yet), 503 with the failing job names
    /// after a failed run, until the next success. Point an uptime monitor here to be alerted (no patient data in it).
    /// </summary>
    [HttpGet("jobs")]
    public IActionResult Jobs()
    {
        var failing = jobs.Failing;
        return failing.Count == 0
            ? Ok(new { status = "ok", ran = jobs.Snapshot.Count })
            : StatusCode(StatusCodes.Status503ServiceUnavailable, new { status = "failing", failing });
    }

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
