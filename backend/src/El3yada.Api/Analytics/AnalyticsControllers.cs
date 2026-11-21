using El3yada.Api.Billing;
using El3yada.Api.Clinic;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Analytics;

/// <summary>
/// D1 (<c>getDashboard</c>, spec 9.1): KPI tiles, charts C1–C12 and insights for a period, branch and visit type. Open to the doctor
/// and to assistants with <c>appointmentsView</c>, <c>billingView</c> or <c>revenueView</c>; each part answers only what the caller
/// may see, and money is absent without <c>revenueView</c> (BR-REV1, AC-23). An admin gets 403.
/// </summary>
[ApiController]
[Route("api/dashboard")]
[Clinic]
public sealed class DashboardController(DashboardService dashboard) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get([FromQuery] AnalyticsQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (this.RequireAny(caller, ClinicPermissions.AppointmentsView, ClinicPermissions.BillingView, ClinicPermissions.RevenueView) is { } denied)
        {
            return denied;
        }

        return await dashboard.BuildAsync(caller, query, cancellationToken) is { } view ? Ok(view) : this.BranchNotAllowed();
    }
}

/// <summary>D35 (<c>getRevenueReport</c>, spec 9.1): the doctor, or an assistant with <c>revenueView</c>. An admin gets 403.</summary>
[ApiController]
[Route("api/revenue")]
[Clinic(ClinicPermissions.RevenueView)]
public sealed class RevenueController(RevenueService revenue) : ControllerBase
{
    /// <summary>By month, with the totals, the best and worst months and the branch, visit type and payment method tabs.</summary>
    [HttpGet]
    public async Task<IActionResult> Report([FromQuery] RevenueQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        return await revenue.ReportAsync(caller, query, caller.Has(ClinicPermissions.BillingView), cancellationToken) is { } view
            ? Ok(view)
            : this.BranchNotAllowed();
    }

    /// <summary>The days of one month (<c>?month=2026-10</c>).</summary>
    [HttpGet("month")]
    public async Task<IActionResult> Month([FromQuery] RevenueQuery query, CancellationToken cancellationToken) =>
        await revenue.MonthAsync(HttpContext.Clinic(), query, cancellationToken) is { } view ? Ok(view) : this.BranchNotAllowed();

    /// <summary>The sessions of one day (<c>?day=2026-10-12</c>).</summary>
    [HttpGet("day")]
    public async Task<IActionResult> Day([FromQuery] RevenueQuery query, CancellationToken cancellationToken) =>
        await revenue.DayAsync(HttpContext.Clinic(), query, cancellationToken) is { } view ? Ok(view) : this.BranchNotAllowed();
}
