using System.Text.Json;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Infrastructure.Time;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// The appointment jobs of spec 9.3 (Africa/Cairo). Each is idempotent, so running it twice, or on
/// two servers at once, changes nothing the second time: rows are selected by state and updated
/// only while still in that state.
/// </summary>
public sealed class AppointmentJobs(AppDbContext db, INotificationWriter notifications, BoardPublisher publisher, TimeProvider clock, ILogger<AppointmentJobs> logger)
{
    private DateTime Now => clock.GetUtcNow().UtcDateTime;

    /// <summary>
    /// <c>appointmentReminders</c>: 24 h before, and on the day 2 h before the period starts (queue mode) or the
    /// visit time (timed mode), skipping reminders whose time had passed at booking (case 27, AC-21). In queue
    /// mode the day's reminder says that turns go in order of arrival (BR-AP16).
    /// </summary>
    public async Task<int> SendRemindersAsync(CancellationToken ct)
    {
        var horizon = Now.AddDays(3);
        var due = await db.Appointments
            .Where(a => a.Status == AppointmentStatuses.Confirmed && a.PatientId != null && a.StartUtc > Now && a.StartUtc < horizon)
            .Select(a => new { Appointment = a, a.Branch.ReminderMinutesJson, a.Branch.NameAr, a.Branch.NameEn, PatientUserId = a.Patient!.UserId })
            .ToListAsync(ct);

        var today = CairoTime.Today(clock);
        var sent = 0;
        foreach (var row in due)
        {
            var a = row.Appointment;
            var already = Parse(a.RemindersSentJson);
            var changed = false;
            foreach (var minutes in Parse(row.ReminderMinutesJson).Where(m => !already.Contains(m)))
            {
                var at = a.StartUtc.AddMinutes(-minutes);
                if (Now < at) continue;
                already.Add(minutes);
                changed = true;
                if (a.CreatedAt > at) continue;   // its time had passed when the booking was made
                var text = AppointmentTexts.Reminder(a, row.NameAr, row.NameEn ?? row.NameAr, today);
                notifications.Add(row.PatientUserId, NotificationTemplates.BookingReminder(text.Ar, text.En, a.Id));
                sent++;
            }
            if (changed) a.RemindersSentJson = JsonSerializer.Serialize(already.Order());
        }
        await db.SaveChangesAsync(ct);
        return sent;
    }

    /// <summary><c>expirePendingAppointments</c>: pending bookings nobody confirmed by the minimum-notice time (BR-AP9).</summary>
    public async Task<int> ExpirePendingAsync(CancellationToken ct)
    {
        var rows = await db.Appointments
            .Where(a => a.Status == AppointmentStatuses.Pending && a.StartUtc.AddMinutes(-a.Branch.MinNoticeMinutes) <= Now)
            .Select(a => new { Appointment = a, PatientUserId = a.Patient == null ? (Guid?)null : a.Patient.UserId })
            .ToListAsync(ct);
        foreach (var row in rows)
        {
            var a = row.Appointment;
            a.Status = AppointmentStatuses.Cancelled;
            a.CancelledAt = Now;
            a.CancelledByRole = "system";
            a.CancelReason = "notConfirmed";
            a.UpdatedAt = Now;
            History(a, "expired");
            if (row.PatientUserId is { } user) notifications.Add(user, NotificationTemplates.BookingNotConfirmed(a.Id, expired: true));
        }
        await SaveAndPublishAsync(rows.Select(r => r.Appointment), ct);
        return rows.Count;
    }

    /// <summary>
    /// <c>markNoShows</c>: confirmed bookings not checked in 30 minutes after their period (or slot) ends
    /// become no-shows; reaching the branch's limit turns off self-booking for that patient (BR-AP8).
    /// </summary>
    public async Task<int> MarkNoShowsAsync(CancellationToken ct)
    {
        var cutoff = Now.AddMinutes(-30);
        var rows = await db.Appointments
            .Where(a => a.Status == AppointmentStatuses.Confirmed && (a.EndUtc ?? a.StartUtc) <= cutoff)
            .Select(a => new { Appointment = a, a.Branch.NoShowLimitCount, a.Branch.NoShowLimitDays })
            .ToListAsync(ct);
        foreach (var row in rows)
        {
            row.Appointment.Status = AppointmentStatuses.NoShow;
            row.Appointment.NoShowAt = Now;
            row.Appointment.UpdatedAt = Now;
            History(row.Appointment, "noShow");
        }
        await db.SaveChangesAsync(ct);

        foreach (var group in rows.Where(r => r.Appointment.PatientId != null).GroupBy(r => (r.Appointment.DoctorId, r.Appointment.PatientId!.Value)))
        {
            var (doctorId, patientId) = group.Key;
            var limit = group.First();
            var since = Now.AddDays(-limit.NoShowLimitDays);
            var count = await db.Appointments.CountAsync(a => a.DoctorId == doctorId && a.PatientId == patientId
                && a.Status == AppointmentStatuses.NoShow && a.NoShowAt >= since, ct);
            if (count < limit.NoShowLimitCount) continue;

            var link = await db.DoctorPatients.FirstOrDefaultAsync(l => l.DoctorId == doctorId && l.PatientId == patientId && !l.SelfBookingBlocked, ct);
            if (link is null) continue;
            link.SelfBookingBlocked = true;
            link.SelfBookingBlockedReason = "noShowLimit";
            link.UpdatedAt = Now;
            var userId = await db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).FirstAsync(ct);
            notifications.Add(userId, NotificationTemplates.SelfBookingOff());
        }
        await SaveAndPublishAsync(rows.Select(r => r.Appointment), ct);
        return rows.Count;
    }

    /// <summary><c>flagCheckedInNoSession</c>: yesterday's (and older) bookings still checked in (BR-AP11).</summary>
    public async Task<int> FlagCheckedInNoSessionAsync(CancellationToken ct)
    {
        var today = CairoTime.Today(clock);
        return await db.Appointments
            .Where(a => (a.Status == AppointmentStatuses.CheckedIn || a.Status == AppointmentStatuses.WithDoctor) && a.LocalDate < today && !a.FlaggedNoSession)
            .ExecuteUpdateAsync(u => u.SetProperty(a => a.FlaggedNoSession, true), ct);
    }

    public async Task RunAllAsync(CancellationToken ct)
    {
        foreach (var (name, job) in new (string, Func<CancellationToken, Task<int>>)[]
        {
            ("appointmentReminders", SendRemindersAsync),
            ("expirePendingAppointments", ExpirePendingAsync),
            ("markNoShows", MarkNoShowsAsync),
            ("flagCheckedInNoSession", FlagCheckedInNoSessionAsync),
        })
        {
            try
            {
                var count = await job(ct);
                if (count > 0) logger.LogInformation("Job {Job} handled {Count} bookings", name, count);
            }
            catch (Exception error) when (error is not OperationCanceledException)
            {
                logger.LogError(error, "Job {Job} failed", name);
            }
        }
    }

    private void History(Appointment a, string action) => db.AppointmentHistories.Add(new AppointmentHistory
    {
        Id = NewId.Next(), AppointmentId = a.Id, At = Now, ByRole = "system", Action = action,
    });

    private async Task SaveAndPublishAsync(IEnumerable<Appointment> changed, CancellationToken ct)
    {
        await db.SaveChangesAsync(ct);
        foreach (var (branch, date) in changed.Select(a => (a.BranchId, a.LocalDate)).Distinct())
            await publisher.PublishAsync(branch, date, ct);
    }

    private static List<int> Parse(string json)
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

/// <summary>Runs the appointment jobs every few minutes. Off with <c>Jobs:Enabled = false</c> (tests).</summary>
public sealed class AppointmentJobsHost(IServiceScopeFactory scopes, IConfiguration configuration) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (!configuration.GetValue("Jobs:Enabled", true)) return;
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(configuration.GetValue("Jobs:IntervalMinutes", 5)));
        do
        {
            await using var scope = scopes.CreateAsyncScope();
            await scope.ServiceProvider.GetRequiredService<AppointmentJobs>().RunAllAsync(stoppingToken);
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }
}
