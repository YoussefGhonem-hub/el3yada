using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Patients;
using El3yada.Api.Sessions;
using El3yada.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// Day lists and platform-fee totals (spec 6.5; D1 fee cards, D2, D3, AS1). Totals are counts and sums of the
/// fee snapshots of non-deleted sessions (BR-B1, BR-S5), read with SQL aggregates, so they always match the
/// sessions and the invoice. Days and months are Cairo dates (AC-4).
/// </summary>
[ApiController]
[Route("api/sessions")]
[Clinic]
public sealed class SessionReportsController(AppDbContext db, TimeProvider time) : ControllerBase
{
    private DateOnly Today => CairoTime.Today(time);

    /// <summary>
    /// D2 / AS1: one day's sessions, newest first, with totals for the rows listed. An assistant sees only
    /// their branches (BR-AS13).
    /// </summary>
    [HttpGet("day")]
    public async Task<IActionResult> Day([FromQuery] DaySessionsQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (this.RequireAny(caller, ClinicPermissions.SessionsCreate, ClinicPermissions.BillingView) is { } denied)
        {
            return denied;
        }

        var day = CairoDays.ParseDay(query.Day) ?? Today;
        var sessions = db.Sessions.AsNoTracking().Where(s => s.DoctorId == caller.DoctorId && s.DayKey == day && !s.Deleted);
        if (query.BranchId is { } branchId)
        {
            if (!caller.CanUseBranch(branchId))
            {
                return this.BranchNotAllowed();
            }

            if (!await IsDoctorBranchAsync(caller, branchId, cancellationToken))
            {
                return this.NotFoundProblem();
            }

            sessions = sessions.Where(s => s.BranchId == branchId);
        }
        else if (caller.BranchScope is { } scope)
        {
            var branchIds = scope.ToList();
            sessions = sessions.Where(s => branchIds.Contains(s.BranchId));
        }

        if (query.Type is { } type)
        {
            sessions = sessions.Where(s => s.Type == type);
        }

        if (query.RecordedBy is { } recordedBy)
        {
            sessions = sessions.Where(s => s.CreatedBy == recordedBy);
        }

        var rows = await SessionQueries.ListRows(sessions.OrderByDescending(s => s.CreatedAt), caller).ToListAsync(cancellationToken);
        return Ok(new DaySessionsView(
            day,
            rows.Select(row => SessionQueries.Item(row, caller)).ToList(),
            rows.Aggregate(FeeTotalsView.Zero, (totals, row) => totals.Add(row.Type, 1, row.FeePiasters)),
            caller.Has(ClinicPermissions.RevenueView) ? rows.Sum(row => row.PatientFeePiasters) : null));
    }

    /// <summary>D1 platform fee cards (BR-B2, AC-4): today and this month for the whole clinic, every branch.</summary>
    [HttpGet("feeSummary")]
    [Clinic(ClinicPermissions.BillingView)]
    public async Task<IActionResult> FeeSummary(CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var today = Today;
        var month = CairoTime.MonthKey(today);
        var groups = await db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == caller.DoctorId && s.MonthKey == month && !s.Deleted)
            .GroupBy(s => new { s.DayKey, s.Type })
            .Select(g => new { g.Key.DayKey, g.Key.Type, Count = g.Count(), Fees = g.Sum(s => s.FeePiasters) })
            .ToListAsync(cancellationToken);
        return Ok(new FeeSummaryView(
            today,
            month,
            groups.Where(g => g.DayKey == today).Aggregate(FeeTotalsView.Zero, (totals, g) => totals.Add(g.Type, g.Count, g.Fees)),
            groups.Aggregate(FeeTotalsView.Zero, (totals, g) => totals.Add(g.Type, g.Count, g.Fees))));
    }

    /// <summary>
    /// D3 (BR-B3, BR-BR7): a month's totals, totals per branch that add up to them, and one row per day (up to
    /// today for the current month). Billing is per doctor, so this is clinic-wide for assistants too; the
    /// branch filter narrows everything.
    /// </summary>
    [HttpGet("month")]
    [Clinic(ClinicPermissions.BillingView)]
    public async Task<IActionResult> Month([FromQuery] MonthFeesQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var today = Today;
        var first = CairoTime.ParseMonthKey(query.Month) ?? new DateOnly(today.Year, today.Month, 1);
        var month = CairoTime.MonthKey(first);
        var sessions = db.Sessions.AsNoTracking().Where(s => s.DoctorId == caller.DoctorId && s.MonthKey == month && !s.Deleted);
        if (query.BranchId is { } branchId)
        {
            if (!await IsDoctorBranchAsync(caller, branchId, cancellationToken))
            {
                return this.NotFoundProblem();
            }

            sessions = sessions.Where(s => s.BranchId == branchId);
        }

        var groups = await sessions
            .GroupBy(s => new { s.DayKey, s.BranchId, s.Type })
            .Select(g => new { g.Key.DayKey, g.Key.BranchId, g.Key.Type, Count = g.Count(), Fees = g.Sum(s => s.FeePiasters) })
            .ToListAsync(cancellationToken);

        var branchIds = groups.Select(g => g.BranchId).Distinct().ToList();
        var branches = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == caller.DoctorId && branchIds.Contains(b.Id))
            .OrderByDescending(b => b.IsDefault).ThenBy(b => b.CreatedAt)
            .Select(b => new { b.Id, b.NameAr, b.NameEn })
            .ToListAsync(cancellationToken);

        // Days that have happened: the whole of a past month, up to today for this month, none for a future one.
        var monthEnd = first.AddMonths(1).AddDays(-1);
        var last = monthEnd < today ? monthEnd : today;

        var days = new List<DayFeesView>();
        for (var day = first; day <= last; day = day.AddDays(1))
        {
            var current = day;
            days.Add(new DayFeesView(
                day, groups.Where(g => g.DayKey == current).Aggregate(FeeTotalsView.Zero, (totals, g) => totals.Add(g.Type, g.Count, g.Fees))));
        }

        return Ok(new MonthFeesView(
            month,
            query.BranchId,
            groups.Aggregate(FeeTotalsView.Zero, (totals, g) => totals.Add(g.Type, g.Count, g.Fees)),
            branches.Select(b => new BranchFeesView(
                b.Id, b.NameAr, b.NameEn,
                groups.Where(g => g.BranchId == b.Id).Aggregate(FeeTotalsView.Zero, (totals, g) => totals.Add(g.Type, g.Count, g.Fees))))
                .ToList(),
            days));
    }

    private Task<bool> IsDoctorBranchAsync(ClinicCaller caller, Guid branchId, CancellationToken cancellationToken) =>
        db.Branches.AnyAsync(b => b.Id == branchId && b.DoctorId == caller.DoctorId, cancellationToken);
}
