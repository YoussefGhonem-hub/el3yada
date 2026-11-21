using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Paging;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// <c>searchAppointments</c> (D33, AS15, spec 6.12.8). The doctor searches every branch; an assistant
/// only their branches, with <c>appointmentsView</c>. Summary chips count each status for the filter.
/// </summary>
public sealed class AppointmentSearchService(AppDbContext db, AppointmentService appointments)
{
    public async Task<SearchResultDto> SearchAsync(BookingActor actor, SearchAppointmentsQuery q, CancellationToken ct)
    {
        actor.Staff!.Require(StaffPermission.AppointmentsView);
        var query = appointments.Scoped(actor);

        if (q.From is { } from) query = query.Where(a => a.LocalDate >= from);
        if (q.To is { } to) query = query.Where(a => a.LocalDate <= to);
        if (q.BranchIds is { Count: > 0 } branches) query = query.Where(a => branches.Contains(a.BranchId));
        if (q.VisitType is { } type) query = query.Where(a => a.VisitType == type);
        if (q.Source is { } source) query = query.Where(a => a.Source == source);
        if (q.BookedBy is { } by) query = query.Where(a => a.BookedBy == by);
        if (q.PatientId is { } patientId) query = query.Where(a => a.PatientId == patientId);
        if (q.GuestsOnly) query = query.Where(a => a.PatientId == null);
        if (q.RescheduledOnly) query = query.Where(a => a.RescheduleCount > 0);
        if (q.OverbookedOnly) query = query.Where(a => a.Overbooked);
        if (q.CheckedInNoSession) query = query.Where(a => a.FlaggedNoSession);
        if (q.Period == "morning") query = query.Where(a => a.PeriodStartLocal < new TimeOnly(15, 0));
        if (q.Period == "evening") query = query.Where(a => a.PeriodStartLocal >= new TimeOnly(15, 0));
        if (!string.IsNullOrWhiteSpace(q.Q))
        {
            var term = q.Q.Trim();
            var digits = new string(term.Where(char.IsDigit).ToArray());
            int.TryParse(digits, out var fileNumber);
            var phoneTail = digits.Length >= 4 ? digits.TrimStart('0') : null;
            query = query.Where(a =>
                (a.GuestName != null && a.GuestName.Contains(term))
                || (phoneTail != null && a.GuestPhone != null && a.GuestPhone.EndsWith(phoneTail))
                || db.DoctorPatients.Any(l => l.DoctorId == a.DoctorId && l.PatientId == a.PatientId
                    && (l.PatientName.Contains(term) || l.SearchName.Contains(term)
                        || (phoneTail != null && l.PatientPhone.EndsWith(phoneTail))
                        || (fileNumber > 0 && l.FileNumber == fileNumber))));
        }

        // Counts before the status filter, so the chips show every status for the other filters.
        var counts = await query.GroupBy(a => a.Status).Select(g => new { g.Key, Count = g.Count() }).ToDictionaryAsync(x => x.Key, x => x.Count, ct);
        if (q.Statuses is { Count: > 0 } statuses) query = query.Where(a => statuses.Contains(a.Status));

        query = q.Sort switch
        {
            "status" => query.OrderBy(a => a.Status).ThenBy(a => a.StartUtc),
            "dateDesc" => query.OrderByDescending(a => a.LocalDate).ThenByDescending(a => a.StartUtc).ThenByDescending(a => a.QueueNumber),
            "patient" => query.OrderBy(a => a.GuestName ?? db.DoctorPatients.Where(l => l.DoctorId == a.DoctorId && l.PatientId == a.PatientId).Select(l => l.PatientName).FirstOrDefault()),
            _ => query.OrderBy(a => a.LocalDate).ThenBy(a => a.StartUtc).ThenBy(a => a.QueueNumber),
        };
        var page = await query.Select(appointments.Projection(forPatient: false)).ToPagedAsync(q, ct);
        return new SearchResultDto(page, counts);
    }
}
