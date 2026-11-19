using El3yada.Api.Infrastructure.Auth;
using El3yada.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

public sealed record PatientLookupDto(
    Guid PatientId, string Name, string Phone, int FileNumber, int SessionCount, bool ConsultationAllowed,
    int ConsultationsSinceExam, DateTime? LastVisitAt, string? LastVisitType, Guid? UpcomingAppointmentId);

/// <summary>
/// D32 step 1 "Existing patient": find the doctor's patients by name, phone or file number, with what
/// booking needs (visit-type rule BR-AP4, upcoming booking BR-AP21). Read-only and small on purpose:
/// the full patients register (D4, <c>getPatientsRegister</c>) is Phase 2.
/// </summary>
[ApiController]
[Route("api/staff/patients")]
[Authorize(Policy = Policies.Staff)]
[Produces("application/json")]
public sealed class PatientLookupController(AppDbContext db, StaffAccess staffAccess, TimeProvider clock) : ControllerBase
{
    [HttpGet("lookup", Name = "lookupPatientsForBooking")]
    public async Task<IReadOnlyList<PatientLookupDto>> Lookup([FromQuery] string? q, CancellationToken ct)
    {
        var staff = (await staffAccess.GetAsync(ct)).Require(StaffPermission.AppointmentsManage);
        var max = await db.AppSettings.AsNoTracking().Select(s => s.MaxConsecutiveConsultations).FirstAsync(ct);
        var now = clock.GetUtcNow().UtcDateTime;

        var links = db.DoctorPatients.AsNoTracking().Where(l => l.DoctorId == staff.DoctorId && !l.Archived);
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            var digits = new string(term.Where(char.IsDigit).ToArray());
            int.TryParse(digits, out var fileNumber);
            var phoneTail = digits.Length >= 4 ? digits.TrimStart('0') : null;
            links = links.Where(l => l.PatientName.Contains(term) || l.SearchName.Contains(term)
                                     || (phoneTail != null && l.PatientPhone.EndsWith(phoneTail))
                                     || (fileNumber > 0 && digits.Length == term.Length && l.FileNumber == fileNumber));
        }

        return await links
            .OrderByDescending(l => l.LastSessionAt).ThenBy(l => l.PatientName)
            .Take(20)
            .Select(l => new PatientLookupDto(
                l.PatientId, l.PatientName, l.PatientPhone, l.FileNumber, l.SessionCount,
                l.SessionCount > 0 && l.ConsultationsSinceExam < max, l.ConsultationsSinceExam, l.LastSessionAt, l.LastSessionType,
                db.Appointments.Where(a => a.DoctorId == l.DoctorId && a.PatientId == l.PatientId
                                           && (a.Status == AppointmentStatuses.Pending || a.Status == AppointmentStatuses.Confirmed) && a.StartUtc > now)
                    .OrderBy(a => a.StartUtc).Select(a => (Guid?)a.Id).FirstOrDefault()))
            .ToListAsync(ct);
    }
}
