using El3yada.Api.Billing;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Sessions;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Analytics;

// ---- View models of D1 (spec 6.14). Money is in piasters; fields the caller may not see are null (BR-REV1). ----

/// <summary>A KPI tile: the value, the previous period's value and the change in percent (BR-REV4).</summary>
public sealed record Tile(double Value, double? Previous, double? ChangePct);

public sealed record PeriodView(DateOnly From, DateOnly To, DateOnly PreviousFrom, DateOnly PreviousTo, string Preset, string Bucket, bool Compare);

/// <summary>What the caller may see: the page hides anything that is false, it never shows it as zero.</summary>
public sealed record DashboardAccess(bool Revenue, bool Patients, bool Billing);

public sealed record DashboardTiles(
    Tile? Revenue,
    Tile? NetIncome,
    Tile? PlatformFees,
    Tile? Visits,
    Tile? Examinations,
    Tile? Consultations,
    Tile? UniquePatients,
    Tile? NewPatients,
    Tile? WeeklyAveragePatients,
    Tile? AverageRevenuePerVisit,
    Tile? NoShowRate,
    Tile? AppShare,
    Tile? AverageWaitMinutes);

/// <summary>C1: revenue per bucket, split by visit type, with the previous period's total at the same position (dashed line).</summary>
public sealed record RevenuePoint(DateOnly Date, int ExaminationPiasters, int ConsultationPiasters, int? PreviousTotalPiasters);

/// <summary>C2: visits per bucket.</summary>
public sealed record VisitsPoint(DateOnly Date, int Examinations, int Consultations, int? PreviousTotal);

/// <summary>C3: unique patients in a week (Saturday start); <c>average</c> is the weekly average of the period.</summary>
public sealed record WeekPatientsPoint(DateOnly WeekStart, int Patients);

public sealed record WeeklyPatientsChart(IReadOnlyList<WeekPatientsPoint> Weeks, double Average);

/// <summary>C4: visits per month over the last 12 months, the same months a year earlier, and the 3 busiest and quietest highlighted.</summary>
public sealed record MonthPoint(string MonthKey, int Visits, int LastYearVisits, bool Busiest, bool Quietest);

/// <summary>C6: new and returning patients in a month.</summary>
public sealed record NewReturningPoint(string MonthKey, int New, int Returning);

/// <summary>C7: the share of each visit type by count and by revenue (revenue is null without <c>revenueView</c>).</summary>
public sealed record TypeSplit(int Examinations, int Consultations, int? ExaminationRevenuePiasters, int? ConsultationRevenuePiasters);

/// <summary>C8: a branch's visits and revenue (only when there are two or more).</summary>
public sealed record BranchPoint(Guid BranchId, string NameAr, string? NameEn, int Visits, int? RevenuePiasters);

/// <summary>C9: booked → arrived → seen, and the weekly no-shows and cancellations.</summary>
public sealed record FunnelChart(int Booked, int Arrived, int Seen, int NoShows, int Cancellations, IReadOnlyList<WeekLines> Weeks);

public sealed record WeekLines(DateOnly WeekStart, int NoShows, int Cancellations);

/// <summary>C10: bookings by source per month.</summary>
public sealed record SourcePoint(string MonthKey, int App, int Staff, int WalkIn);

/// <summary>C11: patients whose last visit was more than 3, 6 or 12 months ago. <c>filter</c> is the D4 filter that lists them.</summary>
public sealed record NotSeenBucket(int Months, int Patients, string Filter);

/// <summary>C12 [S]: the average wait (check-in to call-in) of a day.</summary>
public sealed record WaitPoint(DateOnly Date, double Minutes);

/// <summary>An automatic sentence in both languages (spec 6.14 "Insights"), with the screen and filter it opens.</summary>
public sealed record Insight(string Code, string TextAr, string TextEn, string Screen, string? Filter);

/// <summary>The invoice card of D1: the invoice to pay and the days left (needs <c>billingView</c>).</summary>
public sealed record InvoiceCard(Guid Id, string MonthKey, int TotalDuePiasters, DateOnly DueDate, string Status, int DaysLeft);

public sealed record DashboardView(
    PeriodView Period,
    DashboardAccess Access,
    DashboardTiles Tiles,
    IReadOnlyList<RevenuePoint>? RevenueSeries,
    IReadOnlyList<VisitsPoint>? VisitsSeries,
    WeeklyPatientsChart? PatientsPerWeek,
    IReadOnlyList<MonthPoint>? Months,
    int[][]? Heatmap,
    IReadOnlyList<NewReturningPoint>? NewVsReturning,
    TypeSplit? TypeSplit,
    IReadOnlyList<BranchPoint>? Branches,
    FunnelChart? Funnel,
    IReadOnlyList<SourcePoint>? Sources,
    IReadOnlyList<NotSeenBucket>? NotSeen,
    IReadOnlyList<WaitPoint>? WaitingTimes,
    IReadOnlyList<Insight> Insights,
    InvoiceCard? Invoice);

/// <summary>
/// D1 (<c>getDashboard</c>, spec 6.14, 9.1). Reads the doctor's non-deleted sessions and bookings in the period and in the
/// previous one with SQL, and builds every tile, chart and insight from them, so a change of period, branch or visit type
/// changes everything together and the totals match D35 (AC-23). Today is live because it is read from the sessions too.
/// </summary>
public sealed class DashboardService(AppDbContext db, AnalyticsData data, TimeProvider time)
{
    public async Task<DashboardView?> BuildAsync(ClinicCaller caller, AnalyticsQuery query, CancellationToken cancellationToken)
    {
        var today = CairoTime.Today(time);
        var preset = query.Preset ?? PeriodPresets.ThisMonth;
        var period = Period.Resolve(preset, today, query.From, query.To);
        var previous = period.Previous;
        var compare = query.Compare ?? true;

        var (branches, allowed) = await data.BranchesAsync(caller, query.BranchId, cancellationToken);
        if (!allowed)
        {
            return null;
        }

        var access = new DashboardAccess(
            caller.Has(ClinicPermissions.RevenueView),
            caller.Has(ClinicPermissions.AppointmentsView),
            caller.Has(ClinicPermissions.BillingView));

        var all = await data.SessionsAsync(caller.DoctorId, previous.From, period.To, branches, query.Type, cancellationToken);
        var current = all.Where(s => period.Contains(s.Day)).ToList();
        var before = compare ? all.Where(s => previous.Contains(s.Day)).ToList() : [];
        var bookingRows = access.Patients
            ? await data.BookingsAsync(caller.DoctorId, previous.From, period.To, branches, cancellationToken)
            : [];
        var bookings = bookingRows.Where(b => period.Contains(b.Day)).ToList();
        var oldBookings = compare ? bookingRows.Where(b => previous.Contains(b.Day)).ToList() : [];

        var patientIds = all.Select(s => s.PatientId).Distinct().ToList();
        var firstVisit = await data.FirstVisitsAsync(caller.DoctorId, patientIds, cancellationToken);

        var now = Stats.Of(current, bookings, firstVisit, period);
        var then = compare ? Stats.Of(before, oldBookings, firstVisit, previous) : null;
        Tile T(double value, double? other) => new(Pct.Round(value), other is null ? null : Pct.Round(other.Value), Pct.Change(value, other));
        Tile? Money(Func<Stats, double> pick) => access.Revenue ? T(pick(now), then is null ? null : pick(then)) : null;
        Tile? Count(Func<Stats, double> pick) => access.Patients ? T(pick(now), then is null ? null : pick(then)) : null;

        var tiles = new DashboardTiles(
            Money(s => s.Revenue),
            Money(s => s.Revenue - s.Fees),
            access.Billing ? T(now.Fees, then?.Fees) : null,
            Count(s => s.Visits),
            Count(s => s.Examinations),
            Count(s => s.Consultations),
            Count(s => s.UniquePatients),
            Count(s => s.NewPatients),
            Count(s => s.WeeklyPatients),
            Money(s => s.Visits == 0 ? 0 : s.Revenue / s.Visits),
            access.Patients && now.NoShowRate is { } rate ? T(rate * 100, then?.NoShowRate * 100) : null,
            access.Patients && now.AppShare is { } share ? T(share * 100, then?.AppShare * 100) : null,
            access.Patients && now.AverageWait is { } wait ? T(wait, then?.AverageWait) : null);

        var bucket = period.Bucket;
        var starts = period.BucketStarts(bucket);
        var previousStarts = previous.BucketStarts(bucket);
        var series = starts.Select((start, index) =>
        {
            var inBucket = current.Where(s => Period.BucketOf(s.Day, bucket) == start).ToList();
            var otherStart = compare && index < previousStarts.Count ? previousStarts[index] : (DateOnly?)null;
            var other = otherStart is null
                ? null
                : before.Where(s => Period.BucketOf(s.Day, bucket) == otherStart).ToList();
            return (Start: start, In: inBucket, Other: other);
        }).ToList();

        var revenueSeries = access.Revenue
            ? series.Select(b => new RevenuePoint(
                b.Start,
                b.In.Where(s => s.IsExamination).Sum(s => s.PatientFeePiasters),
                b.In.Where(s => !s.IsExamination).Sum(s => s.PatientFeePiasters),
                b.Other?.Sum(s => s.PatientFeePiasters))).ToList()
            : null;
        var visitsSeries = access.Patients
            ? series.Select(b => new VisitsPoint(
                b.Start, b.In.Count(s => s.IsExamination), b.In.Count(s => !s.IsExamination), b.Other?.Count)).ToList()
            : null;

        var weeks = new List<WeekPatientsPoint>();
        for (var week = Period.WeekStart(period.From); week <= period.To; week = week.AddDays(7))
        {
            var weekStart = week;
            weeks.Add(new WeekPatientsPoint(
                weekStart, current.Where(s => s.Day >= weekStart && s.Day < weekStart.AddDays(7)).Select(s => s.PatientId).Distinct().Count()));
        }

        var months = access.Patients ? await MonthsAsync(caller.DoctorId, today, branches, query.Type, cancellationToken) : null;
        var heatmap = access.Patients ? Heatmap(current) : null;

        var allBranches = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == caller.DoctorId && (branches == null || branches.Contains(b.Id)))
            .Select(b => new { b.Id, b.NameAr, b.NameEn })
            .ToListAsync(cancellationToken);

        var notSeen = access.Patients ? await NotSeenAsync(caller.DoctorId, today, cancellationToken) : null;
        var insights = BuildInsights(access, preset, now, then, months, heatmap, notSeen);

        return new DashboardView(
            new PeriodView(period.From, period.To, previous.From, previous.To, preset, bucket, compare),
            access,
            tiles,
            revenueSeries,
            visitsSeries,
            access.Patients ? new WeeklyPatientsChart(weeks, Pct.Round(now.WeeklyPatients)) : null,
            months,
            heatmap,
            access.Patients ? NewVsReturning(current, firstVisit, period) : null,
            access.Patients
                ? new TypeSplit(
                    now.Examinations, now.Consultations,
                    access.Revenue ? current.Where(s => s.IsExamination).Sum(s => s.PatientFeePiasters) : null,
                    access.Revenue ? current.Where(s => !s.IsExamination).Sum(s => s.PatientFeePiasters) : null)
                : null,
            access.Patients && allBranches.Count >= 2
                ? allBranches.Select(b => new BranchPoint(
                    b.Id, b.NameAr, b.NameEn, current.Count(s => s.BranchId == b.Id),
                    access.Revenue ? current.Where(s => s.BranchId == b.Id).Sum(s => s.PatientFeePiasters) : null)).ToList()
                : null,
            access.Patients ? Funnel(bookings) : null,
            access.Patients ? Sources(bookings, period) : null,
            notSeen,
            access.Patients ? Waits(bookings) : null,
            insights,
            access.Billing ? await InvoiceCardAsync(caller.DoctorId, today, cancellationToken) : null);
    }

    // ---- Tiles -------------------------------------------------------------------------------------------------

    /// <summary>The numbers of one period.</summary>
    private sealed record Stats(
        int Visits, int Examinations, int Consultations, double Revenue, double Fees, double Discount, int UniquePatients,
        int NewPatients, double WeeklyPatients, double? NoShowRate, double? AppShare, double? AverageWait)
    {
        public static Stats Of(
            IReadOnlyList<SessionRow> sessions, IReadOnlyList<BookingRow> bookings, IReadOnlyDictionary<Guid, DateOnly> firstVisit, Period period)
        {
            var patients = sessions.Select(s => s.PatientId).Distinct().ToList();
            var weeks = Math.Max(1, period.Days / 7.0);
            var reached = bookings.Count(b => b.Status is AppointmentStatuses.NoShow or AppointmentStatuses.Completed
                or AppointmentStatuses.CheckedIn or AppointmentStatuses.WithDoctor);
            var kept = bookings.Count(b => b.Status is not (AppointmentStatuses.Cancelled or AppointmentStatuses.Rejected));
            var waits = bookings
                .Where(b => b.CheckedInAt is not null && b.CalledAt is not null && b.CalledAt >= b.CheckedInAt)
                .Select(b => (b.CalledAt!.Value - b.CheckedInAt!.Value).TotalMinutes)
                .ToList();
            return new Stats(
                sessions.Count,
                sessions.Count(s => s.IsExamination),
                sessions.Count(s => !s.IsExamination),
                sessions.Sum(s => (double)s.PatientFeePiasters),
                sessions.Sum(s => (double)s.FeePiasters),
                sessions.Sum(s => (double)s.DiscountPiasters),
                patients.Count,
                patients.Count(p => firstVisit.TryGetValue(p, out var day) && period.Contains(day)),
                patients.Count / weeks,
                reached == 0 ? null : bookings.Count(b => b.Status == AppointmentStatuses.NoShow) / (double)reached,
                kept == 0 ? null : bookings.Count(b => b.Source == "patientApp"
                    && b.Status is not (AppointmentStatuses.Cancelled or AppointmentStatuses.Rejected)) / (double)kept,
                waits.Count == 0 ? null : waits.Average());
        }
    }

    // ---- Charts ------------------------------------------------------------------------------------------------

    /// <summary>C4: visits per month for the last 12 months, and the same months a year earlier (the filters apply).</summary>
    private async Task<IReadOnlyList<MonthPoint>> MonthsAsync(
        Guid doctorId, DateOnly today, IReadOnlyList<Guid>? branches, string? type, CancellationToken cancellationToken)
    {
        var first = new DateOnly(today.Year, today.Month, 1).AddMonths(-11);
        var sessions = db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == doctorId && !s.Deleted && s.DayKey >= first.AddYears(-1));
        if (branches is not null)
        {
            sessions = sessions.Where(s => branches.Contains(s.BranchId));
        }

        if (type is not null)
        {
            sessions = sessions.Where(s => s.Type == type);
        }

        var counts = await sessions.GroupBy(s => s.MonthKey).Select(g => new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Key, g => g.Count, cancellationToken);
        var keys = Enumerable.Range(0, 12).Select(i => first.AddMonths(i)).ToList();
        var visits = keys.Select(k => counts.GetValueOrDefault(CairoTime.MonthKey(k))).ToList();

        // Highlights only mean something once there are at least six months with visits to compare.
        var withData = visits.Count(v => v > 0);
        var busiest = new HashSet<int>();
        var quietest = new HashSet<int>();
        if (withData >= 6)
        {
            var ranked = Enumerable.Range(0, 12).OrderByDescending(i => visits[i]).ThenBy(i => i).ToList();
            busiest = ranked.Take(3).ToHashSet();
            quietest = ranked.AsEnumerable().Reverse().Take(3).ToHashSet();
        }

        return keys.Select((key, i) => new MonthPoint(
            CairoTime.MonthKey(key), visits[i], counts.GetValueOrDefault(CairoTime.MonthKey(key.AddYears(-1))),
            busiest.Contains(i), quietest.Contains(i))).ToList();
    }

    /// <summary>C5: visits by weekday (Saturday first) and hour of the day (Cairo).</summary>
    private static int[][] Heatmap(IReadOnlyList<SessionRow> sessions)
    {
        var grid = Enumerable.Range(0, 7).Select(_ => new int[24]).ToArray();
        foreach (var session in sessions)
        {
            var local = CairoTime.ToCairo(session.CreatedAt);
            grid[((int)local.DayOfWeek + 1) % 7][local.Hour]++;
        }

        return grid;
    }

    private static IReadOnlyList<NewReturningPoint> NewVsReturning(
        IReadOnlyList<SessionRow> sessions, IReadOnlyDictionary<Guid, DateOnly> firstVisit, Period period)
    {
        var months = new List<NewReturningPoint>();
        for (var month = new DateOnly(period.From.Year, period.From.Month, 1); month <= period.To; month = month.AddMonths(1))
        {
            var key = CairoTime.MonthKey(month);
            var patients = sessions.Where(s => CairoTime.MonthKey(s.Day) == key).Select(s => s.PatientId).Distinct().ToList();
            var fresh = patients.Count(p => firstVisit.TryGetValue(p, out var day) && CairoTime.MonthKey(day) == key);
            months.Add(new NewReturningPoint(key, fresh, patients.Count - fresh));
        }

        return months.TakeLast(12).ToList();
    }

    private static FunnelChart Funnel(IReadOnlyList<BookingRow> bookings)
    {
        var weeks = bookings
            .GroupBy(b => Period.WeekStart(b.Day))
            .OrderBy(g => g.Key)
            .Select(g => new WeekLines(g.Key, g.Count(b => b.Status == AppointmentStatuses.NoShow), g.Count(b => b.Status == AppointmentStatuses.Cancelled)))
            .ToList();
        return new FunnelChart(
            bookings.Count(b => b.Status is not (AppointmentStatuses.Cancelled or AppointmentStatuses.Rejected)),
            bookings.Count(b => b.Status is AppointmentStatuses.CheckedIn or AppointmentStatuses.WithDoctor or AppointmentStatuses.Completed),
            bookings.Count(b => b.Status == AppointmentStatuses.Completed),
            bookings.Count(b => b.Status == AppointmentStatuses.NoShow),
            bookings.Count(b => b.Status == AppointmentStatuses.Cancelled),
            weeks);
    }

    private static IReadOnlyList<SourcePoint> Sources(IReadOnlyList<BookingRow> bookings, Period period)
    {
        var months = new List<SourcePoint>();
        for (var month = new DateOnly(period.From.Year, period.From.Month, 1); month <= period.To; month = month.AddMonths(1))
        {
            var key = CairoTime.MonthKey(month);
            var kept = bookings.Where(b => CairoTime.MonthKey(b.Day) == key
                && b.Status is not (AppointmentStatuses.Cancelled or AppointmentStatuses.Rejected)).ToList();
            months.Add(new SourcePoint(
                key, kept.Count(b => b.Source == "patientApp"), kept.Count(b => b.Source == "staff"), kept.Count(b => b.Source == "walkIn")));
        }

        return months.TakeLast(12).ToList();
    }

    private static IReadOnlyList<WaitPoint> Waits(IReadOnlyList<BookingRow> bookings) =>
        bookings
            .Where(b => b.CheckedInAt is not null && b.CalledAt is not null && b.CalledAt >= b.CheckedInAt)
            .GroupBy(b => b.Day)
            .OrderBy(g => g.Key)
            .Select(g => new WaitPoint(g.Key, Pct.Round(g.Average(b => (b.CalledAt!.Value - b.CheckedInAt!.Value).TotalMinutes))))
            .ToList();

    /// <summary>C11: patients whose last visit was more than 3, 6 or 12 months ago (the same rule as the D4 filters, AC-24).</summary>
    private async Task<IReadOnlyList<NotSeenBucket>> NotSeenAsync(Guid doctorId, DateOnly today, CancellationToken cancellationToken)
    {
        var links = db.DoctorPatients.AsNoTracking().Where(l => l.DoctorId == doctorId && !l.Archived && l.LastSessionAt != null);
        var result = new List<NotSeenBucket>();
        foreach (var (months, filter) in new[] { (3, "notSeen3m"), (6, "notSeen6m"), (12, "notSeen12m") })
        {
            var cutoff = CairoTime.StartUtc(today.AddMonths(-months));
            result.Add(new NotSeenBucket(months, await links.CountAsync(l => l.LastSessionAt < cutoff, cancellationToken), filter));
        }

        return result;
    }

    private async Task<InvoiceCard?> InvoiceCardAsync(Guid doctorId, DateOnly today, CancellationToken cancellationToken)
    {
        var invoice = await db.Invoices.AsNoTracking()
            .Where(i => i.DoctorId == doctorId
                && (i.Status == InvoiceStatuses.Unpaid || i.Status == InvoiceStatuses.Rejected || i.Status == InvoiceStatuses.Overdue
                    || i.Status == InvoiceStatuses.PendingReview))
            .OrderBy(i => i.MonthKey)
            .Select(i => new { i.Id, i.MonthKey, i.TotalDuePiasters, i.DueDate, i.Status })
            .FirstOrDefaultAsync(cancellationToken);
        return invoice is null
            ? null
            : new InvoiceCard(invoice.Id, invoice.MonthKey, invoice.TotalDuePiasters, invoice.DueDate, invoice.Status, invoice.DueDate.DayNumber - today.DayNumber);
    }

    // ---- Insights ----------------------------------------------------------------------------------------------

    private static readonly string[] WeekdaysAr = ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"];

    private static readonly string[] WeekdaysEn = ["Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];

    /// <summary>Short sentences from simple rules, not AI (spec 6.14): each shows only when it has something to say.</summary>
    private static List<Insight> BuildInsights(
        DashboardAccess access, string preset, Stats now, Stats? then, IReadOnlyList<MonthPoint>? months, int[][]? heatmap,
        IReadOnlyList<NotSeenBucket>? notSeen)
    {
        var insights = new List<Insight>();

        if (access.Revenue && then is { Revenue: > 0 } && Pct.Change(now.Revenue, then.Revenue) is { } change && Math.Abs(change) >= 5)
        {
            var thisMonth = preset is PeriodPresets.ThisMonth or PeriodPresets.LastMonth;
            var higher = change > 0;
            var value = Pct.Culture(Math.Abs(Math.Round(change)));
            insights.Add(new Insight(
                "revenueChange",
                thisMonth
                    ? $"إيرادات {(preset == PeriodPresets.ThisMonth ? "هذا" : "ذلك")} الشهر {(higher ? "أعلى" : "أقل")} بنسبة {value}% من الشهر السابق"
                    : $"إيرادات هذه الفترة {(higher ? "أعلى" : "أقل")} بنسبة {value}% من الفترة السابقة",
                thisMonth
                    ? $"Revenue {(preset == PeriodPresets.ThisMonth ? "this" : "that")} month is {value}% {(higher ? "higher" : "lower")} than the month before"
                    : $"Revenue this period is {value}% {(higher ? "higher" : "lower")} than the previous period",
                "revenue", null));
        }

        if (access.Patients && heatmap is not null && heatmap.Sum(row => row.Sum()) >= 10)
        {
            var best = (Day: 0, Hour: 0, Count: -1);
            for (var day = 0; day < 7; day++)
            {
                for (var hour = 0; hour < 24; hour++)
                {
                    if (heatmap[day][hour] > best.Count)
                    {
                        best = (day, hour, heatmap[day][hour]);
                    }
                }
            }

            var (ar, en) = best.Hour switch
            {
                < 5 => ("ليلاً", "at night"),
                < 12 => ("صباحاً", "in the morning"),
                < 17 => ("ظهراً", "in the afternoon"),
                _ => ("مساءً", "in the evening"),
            };
            insights.Add(new Insight(
                "busiestTime", $"أكثر الأوقات زحاماً: {WeekdaysAr[best.Day]} {ar}", $"Busiest time: {WeekdaysEn[best.Day]} {en}", "dashboard", null));
        }

        if (access.Patients && months is not null && months.Count(m => m.Visits > 0) >= 6)
        {
            var withData = months.Where(m => m.Visits > 0).ToList();
            var average = withData.Average(m => m.Visits);
            var quiet = withData.OrderBy(m => m.Visits).First();
            var below = (int)Math.Round((1 - quiet.Visits / average) * 100);
            if (below >= 10)
            {
                var (monthAr, monthEn) = MonthNames.Of(quiet.MonthKey);
                insights.Add(new Insight(
                    "quietestMonth",
                    $"أهدأ شهر خلال السنة: {monthAr.Split(' ')[0]}، أقل من المتوسط بنسبة {below}%",
                    $"Quietest month of the year: {monthEn.Split(' ')[0]}, {below}% below the average",
                    "dashboard", null));
            }
        }

        if (access.Patients && notSeen?.FirstOrDefault(b => b.Months == 6) is { Patients: > 0 } inactive)
        {
            insights.Add(new Insight(
                "notSeen6Months",
                $"{inactive.Patients} {(inactive.Patients == 1 ? "مريض لم يزرك" : "مريضاً لم يزوروك")} منذ 6 أشهر",
                $"{inactive.Patients} {(inactive.Patients == 1 ? "patient hasn't" : "patients haven't")} visited in 6 months",
                "patients", inactive.Filter));
        }

        if (access.Patients && now.NoShowRate is { } rate && then?.NoShowRate is { } before && rate - before >= 0.03)
        {
            var value = Pct.Culture(Math.Round(rate * 100));
            insights.Add(new Insight(
                "noShowUp", $"نسبة عدم الحضور ارتفعت إلى {value}%", $"The no-show rate rose to {value}%", "dashboard", null));
        }

        return insights;
    }
}
