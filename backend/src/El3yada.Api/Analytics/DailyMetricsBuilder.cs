using System.Text.Json;
using El3yada.Api.Common;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Sessions;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Analytics;

/// <summary>
/// <c>buildDailyMetrics</c> (spec 9.3, BR-REV5): one <c>DoctorDailyMetrics</c> row per doctor, branch and Cairo day,
/// made from the day's non-deleted sessions and its bookings. Today is never stored: the dashboard reads today live.
/// Rebuilding a day replaces its rows, so the job is safe to run twice.
/// </summary>
public sealed class DailyMetricsBuilder(AppDbContext db, TimeProvider time, ILogger<DailyMetricsBuilder> logger)
{
    /// <summary>
    /// Builds <paramref name="day"/> for every doctor (<paramref name="onlyDoctorId"/> null) or one. Returns the number
    /// of rows written.
    /// </summary>
    public async Task<int> BuildDayAsync(DateOnly day, Guid? onlyDoctorId, CancellationToken cancellationToken)
    {
        var (start, end) = CairoTime.DayRangeUtc(day);
        var now = time.GetUtcNow().UtcDateTime;

        var sessions = await db.Sessions.AsNoTracking()
            .Where(s => s.DayKey == day && !s.Deleted && (onlyDoctorId == null || s.DoctorId == onlyDoctorId))
            .Select(s => new
            {
                s.DoctorId, s.BranchId, s.PatientId, s.Type, s.PatientFeePiasters, s.ListPricePiasters, s.FeePiasters, s.CreatedAt,
            })
            .ToListAsync(cancellationToken);

        // Patients whose first visit with the doctor happened on this day.
        var firstToday = (await db.DoctorPatients.AsNoTracking()
                .Where(l => l.FirstSessionAt >= start && l.FirstSessionAt < end && (onlyDoctorId == null || l.DoctorId == onlyDoctorId))
                .Select(l => new { l.DoctorId, l.PatientId })
                .ToListAsync(cancellationToken))
            .Select(l => (l.DoctorId, l.PatientId))
            .ToHashSet();

        var bookings = await db.Appointments.AsNoTracking()
            .Where(a => a.LocalDate == day && (onlyDoctorId == null || a.DoctorId == onlyDoctorId))
            .Select(a => new { a.DoctorId, a.BranchId, a.Status, a.Source, a.CheckedInAt, a.CalledAt })
            .ToListAsync(cancellationToken);

        var keys = sessions.Select(s => (s.DoctorId, s.BranchId))
            .Concat(bookings.Select(b => (b.DoctorId, b.BranchId)))
            .Distinct()
            .ToList();

        var existing = await db.DoctorDailyMetrics
            .Where(m => m.Date == day && (onlyDoctorId == null || m.DoctorId == onlyDoctorId))
            .ToListAsync(cancellationToken);
        db.DoctorDailyMetrics.RemoveRange(existing.Where(m => !keys.Contains((m.DoctorId, m.BranchId))));

        foreach (var (doctorId, branchId) in keys)
        {
            var mine = sessions.Where(s => s.DoctorId == doctorId && s.BranchId == branchId).ToList();
            var theirs = bookings.Where(b => b.DoctorId == doctorId && b.BranchId == branchId).ToList();
            var hours = new int[24];
            foreach (var session in mine)
            {
                hours[CairoTime.ToCairo(session.CreatedAt).Hour]++;
            }

            var row = existing.FirstOrDefault(m => m.DoctorId == doctorId && m.BranchId == branchId);
            if (row is null)
            {
                row = new DoctorDailyMetric { DoctorId = doctorId, BranchId = branchId, Date = day };
                db.DoctorDailyMetrics.Add(row);
            }

            row.ExamCount = mine.Count(s => s.Type == SessionTypes.Examination);
            row.ConsultationCount = mine.Count(s => s.Type == SessionTypes.Consultation);
            row.PatientRevenuePiasters = mine.Sum(s => s.PatientFeePiasters);
            row.DiscountPiasters = mine.Sum(s => s.ListPricePiasters is { } list && list > s.PatientFeePiasters ? list - s.PatientFeePiasters : 0);
            row.PlatformFeesPiasters = mine.Sum(s => s.FeePiasters);
            row.UniquePatients = mine.Select(s => s.PatientId).Distinct().Count();
            row.NewPatients = mine.Select(s => s.PatientId).Distinct().Count(p => firstToday.Contains((doctorId, p)));
            row.FreeVisits = mine.Count(s => s.PatientFeePiasters == 0);
            row.Bookings = theirs.Count(b => b.Status is not (AppointmentStatuses.Cancelled or AppointmentStatuses.Rejected));
            row.CompletedBookings = theirs.Count(b => b.Status == AppointmentStatuses.Completed);
            row.NoShows = theirs.Count(b => b.Status == AppointmentStatuses.NoShow);
            row.Cancellations = theirs.Count(b => b.Status == AppointmentStatuses.Cancelled);
            row.AppBookings = theirs.Count(b => b.Source == "patientApp" && b.Status is not (AppointmentStatuses.Cancelled or AppointmentStatuses.Rejected));
            row.WalkIns = theirs.Count(b => b.Source == "walkIn");
            row.VisitsByHourJson = JsonSerializer.Serialize(hours);
            var waits = theirs
                .Where(b => b.CheckedInAt is not null && b.CalledAt is not null && b.CalledAt >= b.CheckedInAt)
                .Select(b => (b.CalledAt!.Value - b.CheckedInAt!.Value).TotalMinutes)
                .ToList();
            row.AvgWaitMinutes = waits.Count == 0 ? null : (decimal)Math.Round(waits.Average(), 1);
            row.BuiltAt = now;
        }

        await db.SaveChangesAsync(cancellationToken);
        logger.LogInformation("Daily metrics for {Day}: {Rows} rows", day, keys.Count);
        return keys.Count;
    }

    /// <summary>
    /// Rebuilds the earlier days whose sessions changed in the last <paramref name="lookback"/> (a session deleted
    /// later, an amount edited): "rebuild a day again if a session from that day changes" (BR-REV5).
    /// </summary>
    public async Task<int> RebuildChangedDaysAsync(TimeSpan lookback, CancellationToken cancellationToken)
    {
        var since = time.GetUtcNow().UtcDateTime - lookback;
        var today = CairoTime.Today(time);
        var changed = await db.Sessions.AsNoTracking()
            .Where(s => s.UpdatedAt >= since && s.DayKey < today)
            .Select(s => new { s.DoctorId, s.DayKey })
            .Distinct()
            .ToListAsync(cancellationToken);
        var rows = 0;
        foreach (var item in changed)
        {
            rows += await BuildDayAsync(item.DayKey, item.DoctorId, cancellationToken);
        }

        return rows;
    }
}
