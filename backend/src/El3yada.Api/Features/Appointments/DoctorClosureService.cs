using El3yada.Api.Common;
using El3yada.Api.Infrastructure.Ids;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// What disabling a doctor does to their bookings (spec 9.1 <c>setDoctorStatus</c>, Phase 7): every booking that has not
/// started is cancelled by the system and its patient is told. Done in the caller's transaction; the live boards are
/// published after it commits.
/// </summary>
public sealed class DoctorClosureService(AppDbContext db, INotificationWriter notifications, TimeProvider clock)
{
    /// <summary>Cancels the doctor's pending and confirmed bookings from today on. Returns the boards to publish after the commit.</summary>
    public async Task<IReadOnlyList<(Guid BranchId, DateOnly Date)>> CancelFutureBookingsAsync(Guid doctorId, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var today = CairoTime.Today(clock);
        var bookings = await db.Appointments
            .Where(a => a.DoctorId == doctorId && a.LocalDate >= today
                && (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed))
            .Select(a => new { Appointment = a, PatientUserId = a.Patient == null ? (Guid?)null : a.Patient.UserId })
            .ToListAsync(cancellationToken);
        foreach (var row in bookings)
        {
            var a = row.Appointment;
            a.Status = AppointmentStatuses.Cancelled;
            a.CancelledAt = now;
            a.CancelledByRole = "system";
            a.CancelReason = "doctorDisabled";
            a.UpdatedAt = now;
            db.AppointmentHistories.Add(new AppointmentHistory
            {
                Id = NewId.Next(), AppointmentId = a.Id, At = now, ByRole = "system", Action = "cancelled", Reason = "doctorDisabled",
            });
            if (row.PatientUserId is { } userId)
            {
                notifications.Add(userId, NotificationTemplates.BookingCancelledByClinic(null, a.Id));
            }
        }

        return bookings.Select(b => (b.Appointment.BranchId, b.Appointment.LocalDate)).Distinct().ToList();
    }
}
