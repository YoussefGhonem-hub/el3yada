using El3yada.Api.Auth;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Doctors;

/// <summary>
/// <c>trialReminders</c> (spec 6.16, BR-T6 [S]): pushes before the free trial ends, to the doctor and their active
/// assistants. Runs daily from <see cref="Billing.BillingJobsHost"/>.
/// <list type="bullet">
/// <item><c>trialEndingSoon</c> once the trial has 3 days left or fewer (2 or 3, as the banner counts them,
/// <see cref="TrialView.DaysLeft"/>);</item>
/// <item><c>trialLastDay</c> once it has less than a day left.</item>
/// </list>
/// Idempotent without its own table: a reminder is skipped when the recipient already has one of that type since
/// that window opened for the trial's current end. An extended trial (BR-T5) moves the windows, so it gets its
/// reminders again. Each doctor is handled under a lock on their row, so two servers never send twice.
/// </summary>
public sealed class TrialReminders(AppDbContext db, INotificationWriter notifications, TimeProvider time)
{
    /// <summary>The "ending soon" reminder starts this many days before the end (BR-T6's banner too).</summary>
    public const int SoonDays = 3;

    /// <summary>Sends the reminders that are due. Returns how many notifications were added.</summary>
    public async Task<int> SendAsync(CancellationToken cancellationToken)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var horizon = now.AddDays(SoonDays);
        var doctors = await db.Doctors.AsNoTracking()
            .Where(d => d.TrialEndsAt > now && d.TrialEndsAt <= horizon
                && (d.Status == DoctorStatuses.Active || d.Status == DoctorStatuses.Suspended)
                && d.User.Status == AccountStatuses.Active)
            .Select(d => d.UserId)
            .ToListAsync(cancellationToken);

        var sent = 0;
        foreach (var doctorId in doctors)
        {
            sent += await RemindAsync(doctorId, now, cancellationToken);
        }

        return sent;
    }

    private async Task<int> RemindAsync(Guid doctorId, DateTime now, CancellationToken cancellationToken)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await ClinicLocks.LockDoctorAsync(db, doctorId, cancellationToken);

        // Read again under the lock: an admin may have activated the service or extended the trial meanwhile.
        var doctor = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new { d.FullName, d.TrialEndsAt })
            .SingleAsync(cancellationToken);
        if (TrialView.Of(doctor.TrialEndsAt, now) is not { Ended: false } trial || trial.DaysLeft > SoonDays)
        {
            return 0;
        }

        var lastDay = trial.DaysLeft <= 1;
        var type = lastDay ? NotificationTypes.TrialLastDay : NotificationTypes.TrialEndingSoon;
        var windowStart = trial.EndsAt.AddDays(-(lastDay ? 1 : SoonDays));
        var assistants = await db.Assistants.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.Status == AssistantStatuses.Active && a.User.Status == AccountStatuses.Active)
            .Select(a => a.UserId)
            .ToListAsync(cancellationToken);
        var already = await db.Notifications.AsNoTracking()
            .Where(n => n.Type == type && n.CreatedAt >= windowStart && (n.RecipientUserId == doctorId || assistants.Contains(n.RecipientUserId)))
            .Select(n => n.RecipientUserId)
            .ToListAsync(cancellationToken);

        var sent = 0;
        if (!already.Contains(doctorId))
        {
            notifications.Add(doctorId, lastDay
                ? NotificationTemplates.TrialLastDay(trial.EndsAt, doctorId)
                : NotificationTemplates.TrialEndingSoon(trial.DaysLeft, trial.EndsAt, doctorId));
            sent++;
        }

        foreach (var assistantId in assistants.Where(id => !already.Contains(id)))
        {
            notifications.Add(assistantId, lastDay
                ? NotificationTemplates.TrialLastDayForAssistant(doctor.FullName, trial.EndsAt, doctorId)
                : NotificationTemplates.TrialEndingSoonForAssistant(doctor.FullName, trial.DaysLeft, trial.EndsAt, doctorId));
            sent++;
        }

        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return sent;
    }
}
