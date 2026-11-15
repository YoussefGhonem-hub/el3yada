using El3yada.Api.Clinic;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Sessions;

/// <summary>
/// Reads sessions for clinic callers: only the caller's doctor's non-deleted sessions, and only the fields the
/// caller may see (spec 6.10, AS4). Clinical fields are not even read from the database without
/// <c>clinicalView</c>, and the private note never is (it has its own endpoint, doctor only).
/// </summary>
public static class SessionQueries
{
    /// <summary>Money fields need <c>revenueView</c>, or having recorded the session (BR-S10: they typed it).</summary>
    public static bool CanSeeAmount(ClinicCaller caller, Guid recordedBy) =>
        caller.Has(ClinicPermissions.RevenueView) || recordedBy == caller.UserId;

    /// <summary>The doctor, or the person who recorded it, on the session's Cairo day (BR-S10).</summary>
    public static bool CanEditAmount(ClinicCaller caller, Guid recordedBy, DateOnly sessionDay, DateOnly today) =>
        sessionDay == today && (caller.IsDoctor || (recordedBy == caller.UserId && caller.Has(ClinicPermissions.SessionsCreate)));

    public static async Task<SessionDetailView?> DetailAsync(
        AppDbContext db, ClinicCaller caller, Guid sessionId, DateOnly today, CancellationToken cancellationToken)
    {
        var clinical = caller.Has(ClinicPermissions.ClinicalView);
        var row = await db.Sessions.AsNoTracking()
            .Where(s => s.Id == sessionId && s.DoctorId == caller.DoctorId && !s.Deleted)
            .Select(s => new
            {
                s.Id,
                s.PatientId,
                s.Link.FileNumber,
                s.Link.PatientName,
                s.Type,
                s.CreatedAt,
                s.DayKey,
                s.BranchId,
                BranchNameAr = s.Branch.NameAr,
                BranchNameEn = s.Branch.NameEn,
                s.FeePiasters,
                s.PatientFeePiasters,
                s.ListPricePiasters,
                s.PaymentMethod,
                s.CreatedBy,
                RecorderName = s.CreatedByNavigation.DisplayName,
                s.CreatedByRole,
                s.AwaitingDoctor,
                ChiefComplaint = clinical ? s.ChiefComplaint : null,
                Findings = clinical ? s.Findings : null,
                BpSys = clinical ? s.BpSys : null,
                BpDia = clinical ? s.BpDia : null,
                Pulse = clinical ? s.Pulse : null,
                TempC = clinical ? s.TempC : null,
                WeightKg = clinical ? s.WeightKg : null,
                HeightCm = clinical ? s.HeightCm : null,
                Glucose = clinical ? s.Glucose : null,
                Diagnosis = clinical ? s.Diagnosis : null,
                PatientNotes = clinical ? s.PatientNotes : null,
                FollowUpDate = clinical ? s.FollowUpDate : null,
                HasPrivateNote = s.SessionPrivateNote != null,
                IsLatest = s.Link.LastSessionId == s.Id,
                s.UpdatedAt,
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (row is null)
        {
            return null;
        }

        var amount = CanSeeAmount(caller, row.CreatedBy);
        var deleteBlocked = DeleteRule.BlockedReason(row.IsLatest, row.DayKey, today);
        return new SessionDetailView(
            row.Id,
            row.PatientId,
            row.FileNumber,
            row.PatientName,
            row.Type,
            row.CreatedAt,
            row.DayKey,
            new SessionBranchView(row.BranchId, row.BranchNameAr, row.BranchNameEn),
            row.FeePiasters,
            amount ? row.PatientFeePiasters : null,
            amount ? row.ListPricePiasters : null,
            amount ? row.PaymentMethod : null,
            new RecordedByView(row.CreatedBy, row.RecorderName, row.CreatedByRole),
            row.AwaitingDoctor,
            clinical
                ? new SessionClinicalView(
                    row.ChiefComplaint,
                    row.Findings,
                    new VitalsView(row.BpSys, row.BpDia, row.Pulse, row.TempC, row.WeightKg, row.HeightCm, row.Glucose),
                    row.Diagnosis,
                    row.PatientNotes,
                    row.FollowUpDate)
                : null,
            caller.IsDoctor ? row.HasPrivateNote : null,
            new SessionActionsView(
                EditClinical: caller.IsDoctor,
                EditAmount: CanEditAmount(caller, row.CreatedBy, row.DayKey, today),
                Delete: deleteBlocked is null && caller.Has(ClinicPermissions.SessionsDelete) && caller.CanUseBranch(row.BranchId),
                DeleteBlockedReason: deleteBlocked,
                PrivateNote: caller.IsDoctor),
            row.UpdatedAt);
    }

    /// <summary>List rows of <paramref name="sessions"/> (already filtered to the caller's doctor and non-deleted), read as the caller may see them.</summary>
    public static IQueryable<SessionListRow> ListRows(IQueryable<Session> sessions, ClinicCaller caller)
    {
        var clinical = caller.Has(ClinicPermissions.ClinicalView);
        return sessions.Select(s => new SessionListRow(
            s.Id, s.CreatedAt, s.DayKey, s.Type, s.PatientId, s.Link.FileNumber, s.Link.PatientName,
            s.BranchId, s.Branch.NameAr, s.Branch.NameEn, s.FeePiasters, s.PatientFeePiasters, s.PaymentMethod,
            s.CreatedBy, s.CreatedByNavigation.DisplayName, s.CreatedByRole, s.AwaitingDoctor,
            clinical ? s.ChiefComplaint : null, clinical ? s.Diagnosis : null));
    }

    public static SessionListItem Item(SessionListRow row, ClinicCaller caller)
    {
        var amount = CanSeeAmount(caller, row.CreatedBy);
        return new SessionListItem(
            row.Id, row.CreatedAt, row.DayKey, row.Type, row.PatientId, row.FileNumber, row.PatientName,
            new SessionBranchView(row.BranchId, row.BranchNameAr, row.BranchNameEn),
            row.FeePiasters,
            amount ? row.PatientFeePiasters : null,
            amount ? row.PaymentMethod : null,
            new RecordedByView(row.CreatedBy, row.RecorderName, row.CreatedByRole),
            row.AwaitingDoctor,
            row.ChiefComplaint,
            row.Diagnosis);
    }
}

/// <summary>A session list row as read from the database, before the caller's money filter.</summary>
public sealed record SessionListRow(
    Guid Id,
    DateTime CreatedAt,
    DateOnly DayKey,
    string Type,
    Guid PatientId,
    int FileNumber,
    string PatientName,
    Guid BranchId,
    string BranchNameAr,
    string? BranchNameEn,
    int FeePiasters,
    int PatientFeePiasters,
    string? PaymentMethod,
    Guid CreatedBy,
    string RecorderName,
    string CreatedByRole,
    bool AwaitingDoctor,
    string? ChiefComplaint,
    string? Diagnosis);
