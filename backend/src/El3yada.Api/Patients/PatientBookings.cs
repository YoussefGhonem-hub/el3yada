using El3yada.Api.Features.Appointments;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Patients;

/// <summary>A patient's next booking with the doctor (D4, D6): the nearest pending or confirmed one from today on.</summary>
public sealed record NextBookingView(Guid AppointmentId, DateOnly Date, string VisitType, string Status, Guid BranchId);

/// <summary>The booking columns of the patients register (D4) and the profile header (D6), read for the rows shown.</summary>
public static class PatientBookings
{
    public static async Task<Dictionary<Guid, NextBookingView>> NextAsync(
        AppDbContext db, Guid doctorId, IReadOnlyCollection<Guid> patientIds, DateOnly today, CancellationToken cancellationToken)
    {
        if (patientIds.Count == 0)
        {
            return [];
        }

        var upcoming = await db.Appointments.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.PatientId != null && patientIds.Contains(a.PatientId.Value) && a.LocalDate >= today
                && (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed))
            .Select(a => new { PatientId = a.PatientId!.Value, a.Id, a.LocalDate, a.VisitType, a.Status, a.BranchId, a.StartUtc })
            .ToListAsync(cancellationToken);
        return upcoming
            .GroupBy(a => a.PatientId)
            .ToDictionary(
                g => g.Key,
                g =>
                {
                    var next = g.OrderBy(a => a.LocalDate).ThenBy(a => a.StartUtc).First();
                    return new NextBookingView(next.Id, next.LocalDate, next.VisitType, next.Status, next.BranchId);
                });
    }

    public static async Task<Dictionary<Guid, int>> NoShowsAsync(
        AppDbContext db, Guid doctorId, IReadOnlyCollection<Guid> patientIds, CancellationToken cancellationToken)
    {
        if (patientIds.Count == 0)
        {
            return [];
        }

        return await db.Appointments.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.PatientId != null && patientIds.Contains(a.PatientId.Value) && a.Status == AppointmentStatuses.NoShow)
            .GroupBy(a => a.PatientId!.Value)
            .Select(g => new { PatientId = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.PatientId, g => g.Count, cancellationToken);
    }
}
