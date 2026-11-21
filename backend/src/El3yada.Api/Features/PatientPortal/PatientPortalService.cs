using System.Linq.Expressions;
using System.Text.Json;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Paging;
using El3yada.Api.Infrastructure.Time;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.PatientPortal;

/// <summary>
/// Read side of the patient app (P1–P10). The visibility rules of spec 9.4 live here, in one place:
/// <list type="bullet">
/// <item>every query is filtered by the caller's own <c>PatientId</c>;</item>
/// <item>sessions and files: not deleted;</item>
/// <item>prescriptions: <c>sent</c> or <c>cancelled</c> only (never drafts or <c>readyForReview</c>);</item>
/// <item>private notes, fees, staff notes and the doctor's revenue are never selected.</item>
/// </list>
/// </summary>
public sealed class PatientPortalService(AppDbContext db, PatientContext patient, TimeProvider clock)
{
    private const int SnippetLength = 120;

    internal static readonly string[] VisibleRxStatuses = ["sent", "cancelled"];

    // ---- Reusable projections (translated to SQL by EF Core) ---------------------------------

    private static Expression<Func<Session, VisitListItemDto>> ToVisitItem() =>
        s => new VisitListItemDto(
            s.Id,
            new DoctorRef(s.Doctor.UserId, s.Doctor.FullName, s.Doctor.FullNameEn, s.Doctor.Title, s.Doctor.TitleEn),
            new BranchRef(s.Branch.Id, s.Branch.NameAr, s.Branch.NameEn),
            s.Type,
            s.CreatedAt,
            s.DayKey,
            s.Diagnosis == null ? null
                : s.Diagnosis.Length > SnippetLength ? s.Diagnosis.Substring(0, SnippetLength) : s.Diagnosis,
            s.PatientSeenAt == null);

    private static Expression<Func<Prescription, PrescriptionListItemDto>> ToRxItem() =>
        p => new PrescriptionListItemDto(
            p.Id,
            p.Kind,
            p.Status,
            new DoctorRef(p.Doctor.UserId, p.Doctor.FullName, p.Doctor.FullNameEn, p.Doctor.Title, p.Doctor.TitleEn),
            p.SessionId,
            p.SentAt,
            p.CancelledAt,
            p.PrescriptionMedicationItems.Count + p.PrescriptionInvestigationItems.Count,
            p.PatientSeenAt == null);

    private static Expression<Func<MedicalRecord, RecordListItemDto>> ToRecordItem() =>
        r => new RecordListItemDto(
            r.Id,
            new DoctorRef(r.Doctor.UserId, r.Doctor.FullName, r.Doctor.FullNameEn, r.Doctor.Title, r.Doctor.TitleEn),
            r.SessionId,
            r.Category,
            r.OtherType,
            r.OtherTypeText,
            r.Title,
            r.DocumentDate,
            r.MedicalRecordAttachments.Count,
            r.MedicalRecordAttachments
                .OrderBy(a => a.SortOrder)
                .Select(a => new AttachmentDto(a.Id, a.FileName, a.MimeType, a.SizeBytes, a.PageCount, a.ThumbPath != null))
                .FirstOrDefault(),
            r.PatientSeenAt == null);

    // ---- Visible rows ------------------------------------------------------------------------

    private IQueryable<Session> Sessions(Guid patientId) =>
        db.Sessions.AsNoTracking().Where(s => s.PatientId == patientId && !s.Deleted);

    private IQueryable<Prescription> Prescriptions(Guid patientId) =>
        db.Prescriptions.AsNoTracking().Where(p => p.PatientId == patientId && VisibleRxStatuses.Contains(p.Status));

    private IQueryable<MedicalRecord> Records(Guid patientId) =>
        db.MedicalRecords.AsNoTracking().Where(r => r.PatientId == patientId && !r.Deleted);

    // ---- P2 / P3: doctors --------------------------------------------------------------------

    public async Task<IReadOnlyList<MyDoctorDto>> GetMyDoctorsAsync(CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        return await db.DoctorPatients.AsNoTracking()
            .Where(l => l.PatientId == pid)
            .OrderByDescending(l => l.LastSessionAt).ThenBy(l => l.LinkedAt)
            .Select(l => new MyDoctorDto(
                new DoctorRef(l.Doctor.UserId, l.Doctor.FullName, l.Doctor.FullNameEn, l.Doctor.Title, l.Doctor.TitleEn),
                new SpecialtyRef(l.Doctor.Specialty.Id, l.Doctor.Specialty.NameAr, l.Doctor.Specialty.NameEn),
                l.Doctor.Status,
                l.FileNumber,
                l.LinkedAt,
                l.LastSessionAt,
                l.Doctor.DefaultBranch == null ? null : new BranchRef(l.Doctor.DefaultBranch.Id, l.Doctor.DefaultBranch.NameAr, l.Doctor.DefaultBranch.NameEn),
                l.Doctor.DefaultBranch == null ? null : l.Doctor.DefaultBranch.Area,
                new NewCounts(
                    db.Sessions.Count(s => s.PatientId == pid && s.DoctorId == l.DoctorId && !s.Deleted && s.PatientSeenAt == null),
                    db.Prescriptions.Count(p => p.PatientId == pid && p.DoctorId == l.DoctorId && VisibleRxStatuses.Contains(p.Status) && p.PatientSeenAt == null),
                    db.MedicalRecords.Count(r => r.PatientId == pid && r.DoctorId == l.DoctorId && !r.Deleted && r.PatientSeenAt == null))))
            .ToListAsync(ct);
    }

    public async Task<DoctorInfoDto> GetDoctorInfoAsync(Guid doctorId, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);

        // Branch details are readable only by the doctor's linked patients (spec 9.4).
        var doctor = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.PatientId == pid && l.DoctorId == doctorId)
            .Select(l => new
            {
                Ref = new DoctorRef(l.Doctor.UserId, l.Doctor.FullName, l.Doctor.FullNameEn, l.Doctor.Title, l.Doctor.TitleEn),
                Specialty = new SpecialtyRef(l.Doctor.Specialty.Id, l.Doctor.Specialty.NameAr, l.Doctor.Specialty.NameEn),
                l.Doctor.DegreesAr,
                l.Doctor.DegreesEn,
                l.Doctor.Status,
                l.FileNumber,
                l.Doctor.ExaminationPricePiasters,
                l.Doctor.ConsultationPricePiasters,
            })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();

        var branches = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == doctorId && b.Status != "archived")
            .OrderByDescending(b => b.IsDefault).ThenBy(b => b.CreatedAt)
            .Select(b => new
            {
                b.Id, b.NameAr, b.NameEn, b.Description, b.IsDefault, b.Status, b.ClosedMessage, b.ReopenDate,
                Address = new AddressDto(b.Governorate, b.City, b.Area, b.AddressDetails, b.Landmark, b.MapUrl),
                b.Email,
                Phones = b.BranchPhones.OrderBy(p => p.SortOrder).Select(p => new BranchPhoneDto(p.Number, p.Label, p.IsWhatsapp)).ToList(),
                Hours = b.BranchPeriods.OrderBy(p => p.Weekday).ThenBy(p => p.StartLocal)
                    .Select(p => new WorkingPeriodDto(p.Weekday, p.StartLocal, p.EndLocal, p.EndsNextDay, p.Label)).ToList(),
                b.ExaminationPricePiasters,
                b.ConsultationPricePiasters,
                b.PaymentMethodsJson,
                b.AmenitiesJson,
            })
            .AsSplitQuery()
            .ToListAsync(ct);

        return new DoctorInfoDto(
            doctor.Ref, doctor.Specialty, doctor.DegreesAr, doctor.DegreesEn, doctor.Status, doctor.FileNumber,
            branches.Select(b => new BranchInfoDto(
                b.Id, b.NameAr, b.NameEn, b.Description, b.IsDefault, b.Status, b.ClosedMessage, b.ReopenDate,
                b.Address, b.Email, b.Phones, b.Hours,
                // BR-PR2: a branch without its own prices uses the doctor's.
                new VisitPricesDto(
                    b.ExaminationPricePiasters ?? doctor.ExaminationPricePiasters,
                    b.ConsultationPricePiasters ?? doctor.ConsultationPricePiasters),
                ParseStringList(b.PaymentMethodsJson),
                ParseStringList(b.AmenitiesJson))).ToList());
    }

    // ---- P1: home ----------------------------------------------------------------------------

    public async Task<PatientHomeDto> GetHomeAsync(Guid? doctorId, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        var today = CairoTime.Today(clock);

        var fullName = await db.Patients.AsNoTracking().Where(p => p.Id == pid).Select(p => p.FullName).FirstAsync(ct);

        var sessions = Sessions(pid).Where(s => doctorId == null || s.DoctorId == doctorId);
        var prescriptions = Prescriptions(pid).Where(p => doctorId == null || p.DoctorId == doctorId);
        var records = Records(pid).Where(r => doctorId == null || r.DoctorId == doctorId);

        var latestVisit = await sessions.OrderByDescending(s => s.CreatedAt).Select(ToVisitItem()).FirstOrDefaultAsync(ct);
        var latestRx = await prescriptions.OrderByDescending(p => p.SentAt).Select(ToRxItem()).FirstOrDefaultAsync(ct);
        var followUp = await sessions
            .Where(s => s.FollowUpDate != null && s.FollowUpDate >= today)
            .OrderBy(s => s.FollowUpDate)
            .Select(s => new FollowUpDto(
                s.FollowUpDate!.Value,
                new DoctorRef(s.Doctor.UserId, s.Doctor.FullName, s.Doctor.FullNameEn, s.Doctor.Title, s.Doctor.TitleEn),
                s.Id))
            .FirstOrDefaultAsync(ct);
        var recentFiles = await records
            .OrderByDescending(r => r.DocumentDate).ThenByDescending(r => r.CreatedAt)
            .Take(3)
            .Select(ToRecordItem())
            .ToListAsync(ct);

        var counts = new NewCounts(
            await sessions.CountAsync(s => s.PatientSeenAt == null, ct),
            await prescriptions.CountAsync(p => p.PatientSeenAt == null, ct),
            await records.CountAsync(r => r.PatientSeenAt == null, ct));

        return new PatientHomeDto(fullName, latestVisit, latestRx, followUp, recentFiles, counts);
    }

    // ---- P4 / P5: visits ---------------------------------------------------------------------

    public async Task<PagedResult<VisitListItemDto>> GetVisitsAsync(PatientListQuery query, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        return await Sessions(pid)
            .Where(s => query.DoctorId == null || s.DoctorId == query.DoctorId)
            .Where(s => query.BranchId == null || s.BranchId == query.BranchId)
            .Where(s => query.From == null || s.DayKey >= query.From)
            .Where(s => query.To == null || s.DayKey <= query.To)
            .OrderByDescending(s => s.CreatedAt)
            .Select(ToVisitItem())
            .ToPagedAsync(query, ct);
    }

    public async Task<VisitDetailDto> GetVisitAsync(Guid sessionId, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);

        // Selects named columns only: SessionPrivateNotes is a separate table and is never joined (AC-11).
        var visit = await Sessions(pid)
            .Where(s => s.Id == sessionId)
            .Select(s => new
            {
                s.Id,
                Doctor = new DoctorRef(s.Doctor.UserId, s.Doctor.FullName, s.Doctor.FullNameEn, s.Doctor.Title, s.Doctor.TitleEn),
                Branch = new VisitBranchDto(
                    s.Branch.Id, s.Branch.NameAr, s.Branch.NameEn,
                    new AddressDto(s.Branch.Governorate, s.Branch.City, s.Branch.Area, s.Branch.AddressDetails, s.Branch.Landmark, s.Branch.MapUrl),
                    s.Branch.BranchPhones.OrderBy(p => p.SortOrder).Select(p => new BranchPhoneDto(p.Number, p.Label, p.IsWhatsapp)).ToList()),
                s.Type, s.CreatedAt, s.DayKey, s.ChiefComplaint, s.Findings,
                Vitals = new VitalsDto(s.BpSys, s.BpDia, s.Pulse, s.TempC, s.WeightKg, s.HeightCm, s.Glucose),
                s.Diagnosis, s.PatientNotes, s.FollowUpDate,
                IsNew = s.PatientSeenAt == null,
            })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();

        var prescriptions = await Prescriptions(pid).Where(p => p.SessionId == sessionId)
            .OrderBy(p => p.SentAt).Select(ToRxItem()).ToListAsync(ct);
        var files = await Records(pid).Where(r => r.SessionId == sessionId)
            .OrderByDescending(r => r.DocumentDate).Select(ToRecordItem()).ToListAsync(ct);

        return new VisitDetailDto(
            visit.Id, visit.Doctor, visit.Branch, visit.Type, visit.CreatedAt, visit.DayKey,
            visit.ChiefComplaint, visit.Findings, visit.Vitals, visit.Diagnosis, visit.PatientNotes,
            visit.FollowUpDate, visit.IsNew, prescriptions, files);
    }

    // ---- P6 / P7: prescriptions --------------------------------------------------------------

    public async Task<PagedResult<PrescriptionListItemDto>> GetPrescriptionsAsync(PatientListQuery query, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        return await Prescriptions(pid)
            .Where(p => query.Kind == null || p.Kind == query.Kind)
            .Where(p => query.DoctorId == null || p.DoctorId == query.DoctorId)
            .OrderByDescending(p => p.SentAt).ThenByDescending(p => p.CreatedAt)
            .Select(ToRxItem())
            .ToPagedAsync(query, ct);
    }

    public async Task<PrescriptionDetailDto> GetPrescriptionAsync(Guid id, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        return await Prescriptions(pid)
            .Where(p => p.Id == id)
            .Select(p => new PrescriptionDetailDto(
                p.Id,
                p.Kind,
                p.Status,
                new DoctorRef(p.Doctor.UserId, p.Doctor.FullName, p.Doctor.FullNameEn, p.Doctor.Title, p.Doctor.TitleEn),
                p.SessionId,
                p.Session.DayKey,
                p.Diagnosis,
                p.Advice,
                p.SentAt,
                p.CancelledAt,
                p.CancelReason,
                p.ReplacesRxId,
                // "Issue new copy" (D15): the visible prescription that replaced this one.
                db.Prescriptions
                    .Where(n => n.ReplacesRxId == p.Id && VisibleRxStatuses.Contains(n.Status))
                    .Select(n => (Guid?)n.Id)
                    .FirstOrDefault(),
                p.PdfPath != null,
                p.PatientSeenAt == null,
                p.PrescriptionMedicationItems.OrderBy(i => i.SortOrder)
                    .Select(i => new MedicationItemDto(i.DrugName, i.ActiveIngredient, i.Form, i.Strength, i.Dose, i.Frequency, i.Timing, i.Duration, i.Instructions))
                    .ToList(),
                p.PrescriptionInvestigationItems.OrderBy(i => i.SortOrder)
                    .Select(i => new InvestigationItemDto(i.Category, i.Name, i.Notes))
                    .ToList()))
            .AsSplitQuery()
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();
    }

    /// <summary>The stored PDF path of a visible prescription.</summary>
    public async Task<(string Path, string FileName)> GetPrescriptionPdfAsync(Guid id, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        var rx = await Prescriptions(pid).Where(p => p.Id == id)
            .Select(p => new { p.PdfPath, p.Kind, p.Session.DayKey })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();
        if (rx.PdfPath is null) throw ApiException.NotFound(ErrorCodes.FileMissing);
        return (rx.PdfPath, $"el3yada-{rx.Kind}-{rx.DayKey:yyyy-MM-dd}.pdf");
    }

    // ---- P8 / P9: medical files --------------------------------------------------------------

    public async Task<PagedResult<RecordListItemDto>> GetRecordsAsync(PatientListQuery query, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        return await Records(pid)
            .Where(r => query.Kind == null || r.Category == query.Kind)
            .Where(r => query.DoctorId == null || r.DoctorId == query.DoctorId)
            .Where(r => query.From == null || r.DocumentDate >= query.From)
            .Where(r => query.To == null || r.DocumentDate <= query.To)
            .OrderByDescending(r => r.DocumentDate).ThenByDescending(r => r.CreatedAt)
            .Select(ToRecordItem())
            .ToPagedAsync(query, ct);
    }

    public async Task<RecordCountsDto> GetRecordCountsAsync(Guid? doctorId, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        var counts = await Records(pid)
            .Where(r => doctorId == null || r.DoctorId == doctorId)
            .GroupBy(r => r.Category)
            .Select(g => new { Category = g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Category, x => x.Count, ct);
        return new RecordCountsDto(
            counts.GetValueOrDefault("prescription"),
            counts.GetValueOrDefault("lab"),
            counts.GetValueOrDefault("radiology"),
            counts.GetValueOrDefault("other"));
    }

    public async Task<RecordDetailDto> GetRecordAsync(Guid id, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        return await Records(pid)
            .Where(r => r.Id == id)
            .Select(r => new RecordDetailDto(
                r.Id,
                new DoctorRef(r.Doctor.UserId, r.Doctor.FullName, r.Doctor.FullNameEn, r.Doctor.Title, r.Doctor.TitleEn),
                r.SessionId,
                r.Category,
                r.OtherType,
                r.OtherTypeText,
                r.Title,
                r.DocumentDate,
                r.Notes,
                r.Source,
                r.PatientSeenAt == null,
                r.MedicalRecordAttachments.OrderBy(a => a.SortOrder)
                    .Select(a => new AttachmentDto(a.Id, a.FileName, a.MimeType, a.SizeBytes, a.PageCount, a.ThumbPath != null))
                    .ToList()))
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();
    }

    /// <summary>The stored path of one attachment (or its thumbnail) of a visible record.</summary>
    public async Task<(string Path, string FileName, string MimeType)> GetAttachmentAsync(
        Guid recordId, Guid attachmentId, bool thumbnail, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        var attachment = await db.MedicalRecordAttachments.AsNoTracking()
            .Where(a => a.Id == attachmentId && a.RecordId == recordId && a.Record.PatientId == pid && !a.Record.Deleted)
            .Select(a => new { a.Path, a.ThumbPath, a.FileName, a.MimeType })
            .FirstOrDefaultAsync(ct) ?? throw ApiException.NotFound();

        if (!thumbnail) return (attachment.Path, attachment.FileName, attachment.MimeType);
        if (attachment.ThumbPath is null) throw ApiException.NotFound(ErrorCodes.FileMissing);
        return (attachment.ThumbPath, Path.ChangeExtension(attachment.FileName, ".jpg"), "image/jpeg");
    }

    // ---- P10: medical profile ----------------------------------------------------------------

    public async Task<PersonalInfoDto> GetPersonalInfoAsync(CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        return await db.Patients.AsNoTracking()
            .Where(p => p.Id == pid)
            .Select(p => new PersonalInfoDto(p.Id, p.FullName, p.Phone, p.Gender, p.DateOfBirth, p.DateOfBirthEstimated, p.BloodType))
            .FirstAsync(ct);
    }

    public async Task<MedicalProfileDto> GetMedicalProfileAsync(CancellationToken ct)
    {
        var personal = await GetPersonalInfoAsync(ct);
        var links = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.PatientId == personal.PatientId)
            .OrderByDescending(l => l.LastSessionAt).ThenBy(l => l.LinkedAt)
            .Select(l => new
            {
                Doctor = new DoctorRef(l.Doctor.UserId, l.Doctor.FullName, l.Doctor.FullNameEn, l.Doctor.Title, l.Doctor.TitleEn),
                l.FamilyHistory,
                l.ProfileNotes,
                Items = l.PatientMedicalProfileItems.OrderBy(i => i.SortOrder).ThenBy(i => i.CreatedAt)
                    .Select(i => new { i.Kind, i.Text }).ToList(),
            })
            .AsSplitQuery()
            .ToListAsync(ct);

        return new MedicalProfileDto(personal, links.Select(l => new DoctorMedicalProfileDto(
            l.Doctor,
            l.Items.Where(i => i.Kind == "allergy").Select(i => i.Text).ToList(),
            l.Items.Where(i => i.Kind == "chronicDisease").Select(i => i.Text).ToList(),
            l.Items.Where(i => i.Kind == "currentMedication").Select(i => i.Text).ToList(),
            l.Items.Where(i => i.Kind == "surgery").Select(i => i.Text).ToList(),
            l.FamilyHistory,
            l.ProfileNotes)).ToList());
    }

    // ---- "New" badges ------------------------------------------------------------------------

    /// <summary>Sets <c>PatientSeenAt</c> on the caller's own items that are still unseen. Idempotent.</summary>
    public async Task MarkSeenAsync(MarkSeenRequest request, CancellationToken ct)
    {
        var pid = await patient.GetPatientIdAsync(ct);
        var now = clock.GetUtcNow().UtcDateTime;

        if (request.Visits is { Count: > 0 } visits)
            await db.Sessions
                .Where(s => s.PatientId == pid && !s.Deleted && s.PatientSeenAt == null && visits.Contains(s.Id))
                .ExecuteUpdateAsync(u => u.SetProperty(s => s.PatientSeenAt, now), ct);

        if (request.Prescriptions is { Count: > 0 } rx)
            await db.Prescriptions
                .Where(p => p.PatientId == pid && VisibleRxStatuses.Contains(p.Status) && p.PatientSeenAt == null && rx.Contains(p.Id))
                .ExecuteUpdateAsync(u => u.SetProperty(p => p.PatientSeenAt, now), ct);

        if (request.Files is { Count: > 0 } files)
            await db.MedicalRecords
                .Where(r => r.PatientId == pid && !r.Deleted && r.PatientSeenAt == null && files.Contains(r.Id))
                .ExecuteUpdateAsync(u => u.SetProperty(r => r.PatientSeenAt, now), ct);
    }

    private static IReadOnlyList<string> ParseStringList(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return [];
        try
        {
            return JsonSerializer.Deserialize<List<string>>(json) ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }
}
