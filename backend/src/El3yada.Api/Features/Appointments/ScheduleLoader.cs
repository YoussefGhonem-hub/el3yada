using System.Text.Json;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>Everything the availability engine needs for one branch over a date range.</summary>
public sealed class BranchSchedule
{
    public required Branch Branch { get; init; }
    public required BookingSettings Settings { get; init; }
    public required IReadOnlyList<BranchPeriod> Weekly { get; init; }
    public required IReadOnlyDictionary<DateOnly, IReadOnlyList<PeriodTemplate>> Overrides { get; init; }
    public required IReadOnlyList<ClosureWindow> Closures { get; init; }
    public required IReadOnlyList<ExistingBooking> Bookings { get; init; }

    public IReadOnlyList<PeriodTemplate> WeeklyFor(DateOnly date)
    {
        var weekday = Infrastructure.Time.CairoTime.IsoWeekday(date);
        return Weekly.Where(p => p.Weekday == weekday)
            .Select(p => new PeriodTemplate(p.StartLocal, p.EndLocal, p.EndsNextDay, p.Label, p.Capacity))
            .ToList();
    }

    public DayAvailability Day(AvailabilityRequest request) => AvailabilityEngine.ForDay(
        request, Settings, Branch.Status, WeeklyFor(request.Date),
        Overrides.TryGetValue(request.Date, out var o) ? o : null,
        Closures.Where(c => c.FromLocal < request.Date.AddDays(2).ToDateTime(TimeOnly.MinValue)
                         && c.ToLocal > request.Date.ToDateTime(TimeOnly.MinValue)).ToList(),
        Bookings);
}

public sealed class ScheduleLoader(AppDbContext db)
{
    public static BookingSettings SettingsOf(Branch b) => new(
        b.BookingMode, b.SlotMinutes, b.ExamSlots, b.ConsultationSlots, b.DefaultCapacity, b.AvgVisitMinutes,
        b.SelfBooking, b.AutoConfirm, b.WindowDays, b.MinNoticeMinutes, b.SameDay, b.FreeCancelMinutes,
        b.MaxReschedules, b.MaxUpcomingPerPatient, b.NoShowLimitCount, b.NoShowLimitDays,
        ParseInts(b.ReminderMinutesJson), b.StaffOverbooking);

    /// <param name="tracking">True inside booking transactions, to update the branch row if needed.</param>
    public async Task<BranchSchedule> LoadAsync(Guid branchId, DateOnly from, DateOnly to, CancellationToken ct, bool tracking = false)
    {
        var branches = tracking ? db.Branches : db.Branches.AsNoTracking();
        var branch = await branches.FirstOrDefaultAsync(b => b.Id == branchId, ct) ?? throw ApiException.NotFound();

        var weekly = await db.BranchPeriods.AsNoTracking().Where(p => p.BranchId == branchId).ToListAsync(ct);
        var overrides = await db.BranchDateOverrides.AsNoTracking()
            .Where(o => o.BranchId == branchId && o.Date >= from && o.Date <= to)
            .Select(o => new
            {
                o.Date,
                Periods = o.BranchDateOverridePeriods
                    .Select(p => new PeriodTemplate(p.StartLocal, p.EndLocal, p.EndsNextDay, p.Label, p.Capacity)).ToList(),
            })
            .ToListAsync(ct);

        var fromLocal = from.ToDateTime(TimeOnly.MinValue);
        var toLocal = to.AddDays(2).ToDateTime(TimeOnly.MinValue);
        var closures = await db.BranchClosures.AsNoTracking()
            .Where(c => c.DoctorId == branch.DoctorId && (c.BranchId == null || c.BranchId == branchId)
                        && c.FromLocal < toLocal && c.ToLocal > fromLocal)
            .Select(c => new ClosureWindow(c.FromLocal, c.ToLocal))
            .ToListAsync(ct);

        var bookings = await db.Appointments.AsNoTracking()
            .Where(a => a.BranchId == branchId && a.LocalDate >= from && a.LocalDate <= to
                        && AppointmentStatuses.UsingCapacity.Contains(a.Status))
            .Select(a => new ExistingBooking(a.Id, a.LocalDate, a.PeriodStartLocal, a.StartUtc, a.EndUtc, a.Status, a.Overbooked))
            .ToListAsync(ct);

        return new BranchSchedule
        {
            Branch = branch,
            Settings = SettingsOf(branch),
            Weekly = weekly,
            Overrides = overrides.ToDictionary(o => o.Date, o => (IReadOnlyList<PeriodTemplate>)o.Periods),
            Closures = closures,
            Bookings = bookings,
        };
    }

    private static IReadOnlyList<int> ParseInts(string json)
    {
        try
        {
            return JsonSerializer.Deserialize<List<int>>(json) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }
}
