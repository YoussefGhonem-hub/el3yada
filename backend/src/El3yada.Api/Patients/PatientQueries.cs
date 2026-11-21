using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Patients;

/// <summary>
/// Reads one doctor's view of a patient. Everything is filtered by the caller's doctor (BR-P3: a doctor sees
/// only what their own clinic created), and money and clinical fields by the caller's permissions.
/// </summary>
public static class PatientQueries
{
    /// <summary>The D6 header and summary, or null when the patient is not linked to the caller's doctor.</summary>
    public static async Task<PatientDetailView?> DetailAsync(
        AppDbContext db, ClinicCaller caller, Guid patientId, DateOnly today, CancellationToken cancellationToken)
    {
        var doctorId = caller.DoctorId;
        var row = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.DoctorId == doctorId && l.PatientId == patientId)
            .Select(l => new
            {
                LinkId = l.Id,
                l.FileNumber,
                l.Archived,
                l.ArchivedAt,
                l.LinkedAt,
                Visits = new VisitCounters(
                    l.FirstSessionAt, l.LastSessionId, l.LastSessionAt, l.LastSessionType, l.LastSessionBranchId,
                    l.LastSessionBranch != null ? l.LastSessionBranch.NameAr : null,
                    l.LastSessionBranch != null ? l.LastSessionBranch.NameEn : null,
                    l.SessionCount, l.ExamCount, l.ConsultationCount, l.ConsultationsSinceExam),
                l.Patient.FullName,
                l.Patient.Phone,
                l.Patient.Gender,
                l.Patient.DateOfBirth,
                l.Patient.DateOfBirthEstimated,
                l.Patient.NationalId,
                l.Patient.Address,
                l.Patient.BloodType,
                l.Patient.EmergencyContactName,
                l.Patient.EmergencyContactPhone,
                l.Patient.CreatedByDoctorId,
                l.Patient.Status,
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (row is null)
        {
            return null;
        }

        // BR-P3: the optional details are the creating clinic's.
        var ownsDetails = row.CreatedByDoctorId == doctorId;
        int? totalPaid = caller.Has(ClinicPermissions.RevenueView)
            ? await db.Sessions
                .Where(s => s.DoctorId == doctorId && s.PatientId == patientId && !s.Deleted)
                .SumAsync(s => s.PatientFeePiasters, cancellationToken)
            : null;
        bool? hasAllergies = caller.Has(ClinicPermissions.ClinicalView)
            ? await db.PatientMedicalProfileItems.AnyAsync(i => i.LinkId == row.LinkId && i.Kind == ProfileKinds.Allergy, cancellationToken)
            : null;
        var files = await db.MedicalRecords.AsNoTracking()
            .Where(r => r.DoctorId == doctorId && r.PatientId == patientId && !r.Deleted)
            .GroupBy(r => r.Category)
            .Select(g => new { Category = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Category, g => g.Count, cancellationToken);
        var prescriptions = await db.Prescriptions
            .CountAsync(p => p.DoctorId == doctorId && p.PatientId == patientId && p.Status == "sent", cancellationToken);

        return new PatientDetailView(
            patientId,
            row.FileNumber,
            row.FullName,
            row.Phone,
            row.Gender,
            row.DateOfBirth,
            row.DateOfBirthEstimated,
            PatientAge.Years(row.DateOfBirth, today),
            ownsDetails ? row.NationalId : null,
            ownsDetails ? row.Address : null,
            ownsDetails ? row.BloodType : null,
            ownsDetails ? row.EmergencyContactName : null,
            ownsDetails ? row.EmergencyContactPhone : null,
            ownsDetails,
            row.Status,
            row.Archived,
            row.ArchivedAt,
            row.LinkedAt,
            row.Visits.View(today),
            totalPaid,
            hasAllergies,
            new PatientFilesView(
                files.GetValueOrDefault(FileCategories.Prescription),
                files.GetValueOrDefault(FileCategories.Lab),
                files.GetValueOrDefault(FileCategories.Radiology),
                files.GetValueOrDefault(FileCategories.Other),
                files.Values.Sum()),
            prescriptions,
            (await PatientBookings.NextAsync(db, doctorId, [patientId], today, cancellationToken)).GetValueOrDefault(patientId),
            (await PatientBookings.NoShowsAsync(db, doctorId, [patientId], cancellationToken)).GetValueOrDefault(patientId));
    }
}

/// <summary>The link's counter columns, read in a query and turned into <see cref="PatientVisitsView"/>.</summary>
public sealed record VisitCounters(
    DateTime? FirstSessionAt,
    Guid? LastSessionId,
    DateTime? LastSessionAt,
    string? LastSessionType,
    Guid? LastSessionBranchId,
    string? LastBranchNameAr,
    string? LastBranchNameEn,
    int SessionCount,
    int ExamCount,
    int ConsultationCount,
    int ConsultationsSinceExam)
{
    public PatientVisitsView View(DateOnly today)
    {
        LastVisitView? last = null;
        if (LastSessionId is { } id && LastSessionAt is { } at && LastSessionType is { } type && LastSessionBranchId is { } branchId)
        {
            var day = CairoTime.DayOf(at);
            last = new LastVisitView(id, at, day, today.DayNumber - day.DayNumber, type, branchId, LastBranchNameAr ?? "", LastBranchNameEn);
        }

        return new PatientVisitsView(FirstSessionAt, last, SessionCount, ExamCount, ConsultationCount, ConsultationsSinceExam);
    }
}
