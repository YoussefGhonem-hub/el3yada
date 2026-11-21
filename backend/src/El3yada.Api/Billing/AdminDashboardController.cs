using El3yada.Api.Common;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Sessions;
using El3yada.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Billing;

public sealed record DoctorCountsView(int Active, int PendingApproval, int Suspended, int Disabled, int Rejected, int InTrial);

public sealed record TypeCountsView(int Examinations, int Consultations);

public sealed record InvoicedCollectedView(string MonthKey, int InvoicedPiasters, int CollectedPiasters);

public sealed record SessionsPerDayView(DateOnly Day, int Examinations, int Consultations);

public sealed record LatestSignupView(Guid DoctorId, string FullName, string? FullNameEn, string SpecialtyAr, string SpecialtyEn, string Status, DateTime CreatedAt);

/// <summary>
/// AD1 (spec 7.5). Counts, fee totals and invoice totals only: the platform's own numbers. The clinic's revenue is the
/// doctor's private data and never appears here (BR-REV1).
/// </summary>
public sealed record AdminDashboardView(
    DoctorCountsView Doctors,
    int TotalPatients,
    TypeCountsView SessionsToday,
    TypeCountsView SessionsThisMonth,
    int BookingsToday,
    double? NoShowRateLast30Days,
    int ExpectedFeesThisMonthPiasters,
    InvoicedCollectedView LastMonth,
    int OutstandingPiasters,
    int OverdueDoctors,
    int PaymentsToReview,
    int SignupsToReview,
    IReadOnlyList<SessionsPerDayView> SessionsPerDay,
    IReadOnlyList<InvoicedCollectedView> InvoicedVsCollected,
    IReadOnlyList<PaymentQueueItem> LatestPayments,
    IReadOnlyList<LatestSignupView> LatestSignups,
    IReadOnlyList<AdminInvoiceItem> InvoicesDueSoon);

[ApiController]
[Route("api/admin/dashboard")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminDashboardController(AppDbContext db, TimeProvider time) : ControllerBase
{
    /// <summary>AD1: every tile, both charts and the three action lists in one answer.</summary>
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var today = CairoTime.Today(time);
        var month = CairoTime.MonthKey(today);
        var lastMonth = CairoTime.MonthKey(today.AddMonths(-1));
        var thirtyDaysAgo = today.AddDays(-29);

        var byStatus = await db.Doctors.AsNoTracking()
            .GroupBy(d => d.Status)
            .Select(g => new { Status = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Status, g => g.Count, cancellationToken);
        int Of(string status) => byStatus.GetValueOrDefault(status);
        var inTrial = await db.Doctors.AsNoTracking().CountAsync(d => d.TrialEndsAt > now, cancellationToken);

        var monthSessions = await db.Sessions.AsNoTracking()
            .Where(s => s.MonthKey == month && !s.Deleted)
            .GroupBy(s => new { s.DayKey, s.Type })
            .Select(g => new { g.Key.DayKey, g.Key.Type, Count = g.Count(), Fees = g.Sum(s => s.FeePiasters) })
            .ToListAsync(cancellationToken);
        TypeCountsView Counts(IEnumerable<(string Type, int Count)> rows) => new(
            rows.Where(r => r.Type == SessionTypes.Examination).Sum(r => r.Count),
            rows.Where(r => r.Type == SessionTypes.Consultation).Sum(r => r.Count));

        var perDay = await db.Sessions.AsNoTracking()
            .Where(s => s.DayKey >= thirtyDaysAgo && s.DayKey <= today && !s.Deleted)
            .GroupBy(s => new { s.DayKey, s.Type })
            .Select(g => new { g.Key.DayKey, g.Key.Type, Count = g.Count() })
            .ToListAsync(cancellationToken);
        var chart = Enumerable.Range(0, 30)
            .Select(i => thirtyDaysAgo.AddDays(i))
            .Select(day => new SessionsPerDayView(
                day,
                perDay.Where(r => r.DayKey == day && r.Type == SessionTypes.Examination).Sum(r => r.Count),
                perDay.Where(r => r.DayKey == day && r.Type == SessionTypes.Consultation).Sum(r => r.Count)))
            .ToList();

        var bookingsToday = await db.Appointments.AsNoTracking()
            .CountAsync(a => a.LocalDate == today && a.Status != AppointmentStatuses.Cancelled && a.Status != AppointmentStatuses.Rejected, cancellationToken);
        var noShows = await db.Appointments.AsNoTracking()
            .Where(a => a.LocalDate >= thirtyDaysAgo && a.LocalDate <= today
                && (a.Status == AppointmentStatuses.NoShow || a.Status == AppointmentStatuses.Completed
                    || a.Status == AppointmentStatuses.CheckedIn || a.Status == AppointmentStatuses.WithDoctor))
            .GroupBy(a => a.Status == AppointmentStatuses.NoShow)
            .Select(g => new { NoShow = g.Key, Count = g.Count() })
            .ToListAsync(cancellationToken);
        var noShowCount = noShows.Where(g => g.NoShow).Sum(g => g.Count);
        var reached = noShows.Sum(g => g.Count);

        var from12 = new DateOnly(today.Year, today.Month, 1).AddMonths(-11);
        var invoiceMonths = await db.Invoices.AsNoTracking()
            .Where(i => i.PeriodStart >= from12)
            .GroupBy(i => i.MonthKey)
            .Select(g => new
            {
                MonthKey = g.Key,
                Invoiced = g.Where(i => i.Status != InvoiceStatuses.NoCharge && i.Status != InvoiceStatuses.Waived).Sum(i => i.TotalDuePiasters),
                Collected = g.Where(i => i.Status == InvoiceStatuses.Paid).Sum(i => i.TotalDuePiasters),
            })
            .ToDictionaryAsync(g => g.MonthKey, cancellationToken);
        var invoicedVsCollected = Enumerable.Range(0, 12)
            .Select(i => CairoTime.MonthKey(today.AddMonths(i - 11)))
            .Select(key => invoiceMonths.TryGetValue(key, out var row)
                ? new InvoicedCollectedView(key, row.Invoiced, row.Collected)
                : new InvoicedCollectedView(key, 0, 0))
            .ToList();

        var outstanding = InvoiceStatuses.Outstanding;
        var latestPayments = await db.Payments.AsNoTracking()
            .Where(p => p.Status == PaymentStatuses.PendingReview)
            .OrderBy(p => p.SubmittedAt)
            .Take(5)
            .Select(p => new PaymentQueueItem(
                p.Id, p.InvoiceId, p.DoctorId, p.Doctor.FullName, p.Doctor.FullNameEn, p.Invoice.MonthKey, p.Invoice.TotalDuePiasters,
                p.AmountPiasters, p.AmountPiasters != p.Invoice.TotalDuePiasters, p.SubmittedAt, p.Status))
            .ToListAsync(cancellationToken);
        var signups = await db.Doctors.AsNoTracking()
            .OrderByDescending(d => d.CreatedAt)
            .Take(5)
            .Select(d => new LatestSignupView(d.UserId, d.FullName, d.FullNameEn, d.Specialty.NameAr, d.Specialty.NameEn, d.Status, d.CreatedAt))
            .ToListAsync(cancellationToken);
        var dueSoon = await db.Invoices.AsNoTracking()
            .Where(i => (i.Status == InvoiceStatuses.Unpaid || i.Status == InvoiceStatuses.Rejected)
                && i.DueDate >= today && i.DueDate <= today.AddDays(3))
            .OrderBy(i => i.DueDate)
            .Take(10)
            .Select(i => new AdminInvoiceItem(
                i.Id, i.DoctorId, i.Doctor.FullName, i.Doctor.FullNameEn, i.MonthKey, i.ExamCount, i.ConsultationCount,
                i.TotalDuePiasters, i.DueDate, i.Status))
            .ToListAsync(cancellationToken);

        var last = invoiceMonths.TryGetValue(lastMonth, out var lastRow) ? lastRow : null;
        return Ok(new AdminDashboardView(
            new DoctorCountsView(
                Of(DoctorStatuses.Active), Of(DoctorStatuses.PendingApproval), Of(DoctorStatuses.Suspended), Of(DoctorStatuses.Disabled),
                Of(DoctorStatuses.Rejected), inTrial),
            await db.Patients.AsNoTracking().CountAsync(p => p.Status == "active", cancellationToken),
            Counts(monthSessions.Where(r => r.DayKey == today).Select(r => (r.Type, r.Count))),
            Counts(monthSessions.Select(r => (r.Type, r.Count))),
            bookingsToday,
            reached == 0 ? null : Math.Round(noShowCount / (double)reached, 3),
            monthSessions.Sum(r => r.Fees),
            new InvoicedCollectedView(lastMonth, last?.Invoiced ?? 0, last?.Collected ?? 0),
            await db.Invoices.AsNoTracking().Where(i => outstanding.Contains(i.Status)).SumAsync(i => (int?)i.TotalDuePiasters, cancellationToken) ?? 0,
            await db.Invoices.AsNoTracking().Where(i => i.Status == InvoiceStatuses.Overdue).Select(i => i.DoctorId).Distinct().CountAsync(cancellationToken),
            await db.Payments.AsNoTracking().CountAsync(p => p.Status == PaymentStatuses.PendingReview, cancellationToken),
            Of(DoctorStatuses.PendingApproval),
            chart,
            invoicedVsCollected,
            latestPayments,
            signups,
            dueSoon));
    }
}
