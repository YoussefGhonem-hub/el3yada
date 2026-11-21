using El3yada.Api.Billing;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Sessions;
using El3yada.Data;
using FluentValidation;
using El3yada.Api.Validation;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Analytics;

/// <summary>The filter of D35: a year, or a custom range, and optionally a branch and a visit type.</summary>
public sealed class RevenueQuery
{
    public int? Year { get; init; }

    public DateOnly? From { get; init; }

    public DateOnly? To { get; init; }

    public Guid? BranchId { get; init; }

    public string? Type { get; init; }

    /// <summary><c>yyyy-MM</c>, for the days of a month.</summary>
    public string? Month { get; init; }

    /// <summary>A Cairo day, for the sessions of a day.</summary>
    public DateOnly? Day { get; init; }
}

public sealed class RevenueQueryValidator : AbstractValidator<RevenueQuery>
{
    public RevenueQueryValidator()
    {
        RuleFor(x => x.Year).InclusiveBetween(2020, 2100).WithErrorCode(ErrorCodes.OutOfRange).When(x => x.Year is not null);
        RuleFor(x => x.Type).OneOf(SessionTypes.All).When(x => x.Type is not null);
        RuleFor(x => x.Month)
            .Must(month => CairoTime.ParseMonthKey(month) is not null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use the form 2026-10.")
            .When(x => x.Month is not null);
        RuleFor(x => x)
            .Must(x => x.To >= x.From && x.To!.Value.DayNumber - x.From!.Value.DayNumber < PeriodPresets.MaxCustomDays)
            .WithName("to").WithErrorCode(ErrorCodes.OutOfRange).WithMessage("The range must end after it starts and be shorter than about two years.")
            .When(x => x.From is not null && x.To is not null);
    }
}

/// <summary>One line of the revenue tables: the columns of D35 (spec 6.14). Money is in piasters.</summary>
public sealed record RevenueRow(
    int Examinations,
    int ExaminationRevenuePiasters,
    int Consultations,
    int ConsultationRevenuePiasters,
    int RevenuePiasters,
    int PlatformFeesPiasters,
    int NetPiasters,
    int UniquePatients,
    int NewPatients,
    int FreeVisits,
    int DiscountedVisits,
    int DiscountPiasters);

/// <summary>A month of the table, with its change against the month before and its platform invoice (D19) when the caller may see it.</summary>
public sealed record RevenueMonthRow(string MonthKey, RevenueRow Row, double? ChangePct, Guid? InvoiceId, string? InvoiceStatus);

public sealed record RevenueDayRow(DateOnly Day, RevenueRow Row);

public sealed record RevenueBranchRow(Guid BranchId, string NameAr, string? NameEn, RevenueRow Row);

public sealed record RevenueTypeRow(string Type, RevenueRow Row);

public sealed record RevenuePaymentRow(string? Method, RevenueRow Row);

/// <summary>D35 "By month", with the year's totals, the best and worst months, and the other tabs.</summary>
public sealed record RevenueReportView(
    DateOnly From,
    DateOnly To,
    IReadOnlyList<RevenueMonthRow> Months,
    RevenueRow Totals,
    string? BestMonth,
    string? WorstMonth,
    IReadOnlyList<RevenueBranchRow> ByBranch,
    IReadOnlyList<RevenueTypeRow> ByType,
    IReadOnlyList<RevenuePaymentRow> ByPaymentMethod);

public sealed record RevenueMonthView(string MonthKey, IReadOnlyList<RevenueDayRow> Days, RevenueRow Totals);

/// <summary>A session of a day (D35's last level): the visit price, the amount charged and the discount.</summary>
public sealed record RevenueSessionRow(
    Guid Id,
    DateTime At,
    Guid PatientId,
    string PatientName,
    Guid BranchId,
    string BranchNameAr,
    string? BranchNameEn,
    string Type,
    int? ListPricePiasters,
    int AmountChargedPiasters,
    int DiscountPiasters,
    string? PaymentMethod,
    string RecordedBy,
    string RecordedByRole);

public sealed record RevenueDayView(DateOnly Day, IReadOnlyList<RevenueSessionRow> Sessions, RevenueRow Totals);

/// <summary>
/// D35 (<c>getRevenueReport</c>, spec 6.14, 9.1): the year month by month, a month day by day and a day session by session,
/// from the same sessions and the same filters as the dashboard, so the totals match (AC-23). Only for callers with
/// <c>revenueView</c> (the doctor, or an assistant with it).
/// </summary>
public sealed class RevenueService(AppDbContext db, AnalyticsData data, TimeProvider time)
{
    public async Task<RevenueReportView?> ReportAsync(ClinicCaller caller, RevenueQuery query, bool seeInvoices, CancellationToken cancellationToken)
    {
        var today = CairoTime.Today(time);
        var (from, to) = Range(query, today);
        var (branches, allowed) = await data.BranchesAsync(caller, query.BranchId, cancellationToken);
        if (!allowed)
        {
            return null;
        }

        // One month earlier, only to say how the first month changed.
        var monthBefore = new DateOnly(from.Year, from.Month, 1).AddMonths(-1);
        var rows = await data.SessionsAsync(caller.DoctorId, monthBefore, to, branches, query.Type, cancellationToken);
        var inRange = rows.Where(s => s.Day >= from && s.Day <= to).ToList();
        var firstVisit = await data.FirstVisitsAsync(caller.DoctorId, rows.Select(s => s.PatientId).Distinct().ToList(), cancellationToken);

        var invoices = seeInvoices
            ? await db.Invoices.AsNoTracking()
                .Where(i => i.DoctorId == caller.DoctorId)
                .Select(i => new { i.MonthKey, i.Id, i.Status })
                .ToDictionaryAsync(i => i.MonthKey, cancellationToken)
            : [];

        var months = new List<RevenueMonthRow>();
        var previousRevenue = (int?)Row(rows.Where(s => CairoTime.MonthKey(s.Day) == CairoTime.MonthKey(monthBefore)).ToList(), firstVisit, null).RevenuePiasters;
        for (var month = new DateOnly(from.Year, from.Month, 1); month <= to; month = month.AddMonths(1))
        {
            var key = CairoTime.MonthKey(month);
            var row = Row(inRange.Where(s => CairoTime.MonthKey(s.Day) == key).ToList(), firstVisit, key);
            invoices.TryGetValue(key, out var invoice);
            months.Add(new RevenueMonthRow(key, row, Pct.Change(row.RevenuePiasters, previousRevenue), invoice?.Id, invoice?.Status));
            previousRevenue = row.RevenuePiasters;
        }

        var scored = months.Where(m => m.Row.RevenuePiasters > 0).ToList();
        var branchNames = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == caller.DoctorId)
            .Select(b => new { b.Id, b.NameAr, b.NameEn })
            .ToDictionaryAsync(b => b.Id, cancellationToken);
        return new RevenueReportView(
            from,
            to,
            months,
            Row(inRange, firstVisit, null, new Period(from, to)),
            scored.Count >= 2 ? scored.MaxBy(m => m.Row.RevenuePiasters)!.MonthKey : null,
            scored.Count >= 2 ? scored.MinBy(m => m.Row.RevenuePiasters)!.MonthKey : null,
            inRange.GroupBy(s => s.BranchId)
                .Where(g => branchNames.ContainsKey(g.Key))
                .Select(g => new RevenueBranchRow(g.Key, branchNames[g.Key].NameAr, branchNames[g.Key].NameEn, Row(g.ToList(), firstVisit, null, new Period(from, to))))
                .OrderByDescending(r => r.Row.RevenuePiasters).ToList(),
            inRange.GroupBy(s => s.Type)
                .Select(g => new RevenueTypeRow(g.Key, Row(g.ToList(), firstVisit, null, new Period(from, to))))
                .OrderBy(r => r.Type).ToList(),
            inRange.GroupBy(s => s.PaymentMethod)
                .Select(g => new RevenuePaymentRow(g.Key, Row(g.ToList(), firstVisit, null, new Period(from, to))))
                .OrderByDescending(r => r.Row.RevenuePiasters).ToList());
    }

    /// <summary>A month's days, up to today for the current month.</summary>
    public async Task<RevenueMonthView?> MonthAsync(ClinicCaller caller, RevenueQuery query, CancellationToken cancellationToken)
    {
        var today = CairoTime.Today(time);
        var first = CairoTime.ParseMonthKey(query.Month) ?? new DateOnly(today.Year, today.Month, 1);
        var last = first.AddMonths(1).AddDays(-1);
        if (last > today)
        {
            last = today;
        }

        var (branches, allowed) = await data.BranchesAsync(caller, query.BranchId, cancellationToken);
        if (!allowed)
        {
            return null;
        }

        var rows = await data.SessionsAsync(caller.DoctorId, first, last < first ? first : last, branches, query.Type, cancellationToken);
        var firstVisit = await data.FirstVisitsAsync(caller.DoctorId, rows.Select(s => s.PatientId).Distinct().ToList(), cancellationToken);
        var days = new List<RevenueDayRow>();
        for (var day = first; day <= last; day = day.AddDays(1))
        {
            var current = day;
            days.Add(new RevenueDayRow(day, Row(rows.Where(s => s.Day == current).ToList(), firstVisit, null, new Period(day, day))));
        }

        return new RevenueMonthView(CairoTime.MonthKey(first), days, Row(rows, firstVisit, null, new Period(first, last < first ? first : last)));
    }

    /// <summary>One day's sessions with the visit price, the amount charged and who recorded each.</summary>
    public async Task<RevenueDayView?> DayAsync(ClinicCaller caller, RevenueQuery query, CancellationToken cancellationToken)
    {
        var day = query.Day ?? CairoTime.Today(time);
        var (branches, allowed) = await data.BranchesAsync(caller, query.BranchId, cancellationToken);
        if (!allowed)
        {
            return null;
        }

        var sessions = db.Sessions.AsNoTracking().Where(s => s.DoctorId == caller.DoctorId && !s.Deleted && s.DayKey == day);
        if (branches is not null)
        {
            sessions = sessions.Where(s => branches.Contains(s.BranchId));
        }

        if (query.Type is not null)
        {
            sessions = sessions.Where(s => s.Type == query.Type);
        }

        var list = await sessions
            .OrderByDescending(s => s.CreatedAt)
            .Select(s => new RevenueSessionRow(
                s.Id, s.CreatedAt, s.PatientId, s.Link.PatientName, s.BranchId, s.Branch.NameAr, s.Branch.NameEn, s.Type,
                s.ListPricePiasters, s.PatientFeePiasters,
                s.ListPricePiasters != null && s.ListPricePiasters > s.PatientFeePiasters ? s.ListPricePiasters.Value - s.PatientFeePiasters : 0,
                s.PaymentMethod, s.CreatedByNavigation.DisplayName, s.CreatedByRole))
            .ToListAsync(cancellationToken);
        var rows = await data.SessionsAsync(caller.DoctorId, day, day, branches, query.Type, cancellationToken);
        var firstVisit = await data.FirstVisitsAsync(caller.DoctorId, rows.Select(s => s.PatientId).Distinct().ToList(), cancellationToken);
        return new RevenueDayView(day, list, Row(rows, firstVisit, null, new Period(day, day)));
    }

    // ---- Helpers -------------------------------------------------------------------------------------------------

    private static (DateOnly From, DateOnly To) Range(RevenueQuery query, DateOnly today)
    {
        if (query.From is { } from && query.To is { } to)
        {
            return (from, to);
        }

        var year = query.Year ?? today.Year;
        var end = new DateOnly(year, 12, 31);
        return (new DateOnly(year, 1, 1), end > today ? today : end);
    }

    /// <summary>
    /// One line from the sessions in it. <paramref name="monthKey"/> or <paramref name="period"/> says what "new patients"
    /// means: first visit in that month (or period). With neither, the new-patient count is left at what the rows alone say.
    /// </summary>
    private static RevenueRow Row(
        IReadOnlyList<SessionRow> sessions, IReadOnlyDictionary<Guid, DateOnly> firstVisit, string? monthKey, Period? period = null)
    {
        var patients = sessions.Select(s => s.PatientId).Distinct().ToList();
        var fresh = patients.Count(p => firstVisit.TryGetValue(p, out var day)
            && (monthKey is not null ? CairoTime.MonthKey(day) == monthKey : period is { } range && range.Contains(day)));
        var revenue = sessions.Sum(s => s.PatientFeePiasters);
        var fees = sessions.Sum(s => s.FeePiasters);
        return new RevenueRow(
            sessions.Count(s => s.IsExamination),
            sessions.Where(s => s.IsExamination).Sum(s => s.PatientFeePiasters),
            sessions.Count(s => !s.IsExamination),
            sessions.Where(s => !s.IsExamination).Sum(s => s.PatientFeePiasters),
            revenue,
            fees,
            revenue - fees,
            patients.Count,
            fresh,
            sessions.Count(s => s.PatientFeePiasters == 0),
            sessions.Count(s => s.DiscountPiasters > 0),
            sessions.Sum(s => s.DiscountPiasters));
    }
}
