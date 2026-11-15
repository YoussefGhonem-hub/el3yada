using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Api.Patients;
using El3yada.Api.Sessions;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// Sessions (spec 6.2; D8, D9, AS5; spec 9.1 <c>createSession</c>, <c>deleteSession</c>). A session of another
/// doctor, or a deleted one, is 404. Contract: backend/docs/api-phase-2-patients.md.
/// </summary>
[ApiController]
[Route("api/sessions")]
[Clinic]
public sealed class SessionsController(
    AppDbContext db, Auditor auditor, NotificationWriter notifications, TimeProvider time) : ControllerBase
{
    private const string DoctorOnly = "doctorOnly";

    private DateOnly Today => CairoTime.Today(time);

    /// <summary>
    /// Session times are stored to the millisecond (DATETIME2(3)); cutting the rest first keeps the stored time
    /// and its Cairo day key the same, even a moment before midnight.
    /// </summary>
    private DateTime Now
    {
        get
        {
            var now = time.GetUtcNow().UtcDateTime;
            return new DateTime(now.Ticks - (now.Ticks % TimeSpan.TicksPerMillisecond), DateTimeKind.Utc);
        }
    }

    /// <summary>D8 step 1 / AS5: the consultation rule state, the platform fees and the visit prices for this branch.</summary>
    [HttpGet("newSessionInfo")]
    [Clinic(ClinicPermissions.SessionsCreate)]
    public async Task<IActionResult> NewSessionInfo([FromQuery] NewSessionInfoQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var patientId = query.PatientId!.Value;
        var branchId = query.BranchId!.Value;
        if (!caller.CanUseBranch(branchId))
        {
            return this.BranchNotAllowed();
        }

        var link = await db.DoctorPatients.AsNoTracking()
            .Where(l => l.DoctorId == caller.DoctorId && l.PatientId == patientId)
            .Select(l => new VisitCounters(
                l.FirstSessionAt, l.LastSessionId, l.LastSessionAt, l.LastSessionType, l.LastSessionBranchId,
                l.LastSessionBranch != null ? l.LastSessionBranch.NameAr : null,
                l.LastSessionBranch != null ? l.LastSessionBranch.NameEn : null,
                l.SessionCount, l.ExamCount, l.ConsultationCount, l.ConsultationsSinceExam))
            .SingleOrDefaultAsync(cancellationToken);
        if (link is null)
        {
            return this.NotFoundProblem();
        }

        var (branch, problem) = await BranchForNewSessionAsync(caller, branchId, cancellationToken);
        if (problem is not null)
        {
            return problem;
        }

        var settings = await db.AppSettings.AsNoTracking().SingleAsync(cancellationToken);
        var doctor = await DoctorPricesAsync(caller.DoctorId, cancellationToken);
        var visits = link.View(Today);
        var blocked = ConsultationRule.ConsultationBlockedReason(
            visits.Examinations, visits.ConsultationsSinceExam, settings.MaxConsecutiveConsultations);

        SessionTypeOptionView Option(string type, bool allowed, int fee)
        {
            var price = VisitPrice.For(
                type, branch!.ExaminationPricePiasters, branch.ConsultationPricePiasters,
                doctor.ExaminationPricePiasters, doctor.ConsultationPricePiasters);
            return new SessionTypeOptionView(allowed, fee, price.Piasters, price.Source);
        }

        return Ok(new NewSessionInfoView(
            patientId,
            branchId,
            IsFirstVisit: visits.Total == 0,
            visits.LastVisit,
            visits.ConsultationsSinceExam,
            settings.MaxConsecutiveConsultations,
            ConsultationAllowed: blocked is null,
            blocked,
            Option(SessionTypes.Examination, true, settings.ExamFeePiasters),
            Option(SessionTypes.Consultation, blocked is null, settings.ConsultationFeePiasters)));
    }

    /// <summary>
    /// D8 / AS5 save (spec 9.1 <c>createSession</c>), one transaction: the consultation rule with the link
    /// locked (BR-S2–S4, AC-2), the fee snapshot (BR-S5), the visit price and amount charged (BR-S10), the link
    /// counters, the day and month stats, the patient's notification and the audit row.
    /// </summary>
    [HttpPost("createSession")]
    [Clinic(ClinicPermissions.SessionsCreate, BlockedWhileSuspended = true)]
    public async Task<IActionResult> CreateSession(CreateSessionRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (!caller.IsDoctor && request.DoctorOnlyFields() is { Count: > 0 } doctorFields)
        {
            // BR-AS5: an assistant records type, complaint, vitals and the amount; the clinical fields are the doctor's.
            return this.PermissionDenied(DoctorOnly).WithFields(("fields", doctorFields));
        }

        var patientId = request.PatientId!.Value;
        var branchId = request.BranchId!.Value;
        var type = request.Type!;
        if (!caller.CanUseBranch(branchId))
        {
            return this.BranchNotAllowed();
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var link = await PatientLinks.LockAsync(db, caller.DoctorId, patientId, cancellationToken);
        if (link is null)
        {
            return this.Problem(StatusCodes.Status404NotFound, ErrorCodes.NotLinked, "This patient is not one of your patients.");
        }

        var (branch, problem) = await BranchForNewSessionAsync(caller, branchId, cancellationToken);
        if (problem is not null)
        {
            return problem;
        }

        // Read inside the transaction: the session keeps the fee and the limit as they are now (BR-S5, BR-S3).
        var settings = await db.AppSettings.AsNoTracking().SingleAsync(cancellationToken);
        if (ConsultationRule.BlockedReason(type, link.ExamCount, link.ConsultationsSinceExam, settings.MaxConsecutiveConsultations)
            is { } reason)
        {
            return this.ConflictProblem(ErrorCodes.ConsultationRequiresExam, "Record an examination first.")
                .WithFields(
                    ("reason", reason),
                    ("consultationsSinceExam", link.ConsultationsSinceExam),
                    ("maxConsecutiveConsultations", settings.MaxConsecutiveConsultations));
        }

        var doctor = await DoctorPricesAsync(caller.DoctorId, cancellationToken);
        var price = VisitPrice.For(
            type, branch!.ExaminationPricePiasters, branch.ConsultationPricePiasters,
            doctor.ExaminationPricePiasters, doctor.ConsultationPricePiasters);
        var amount = request.AmountChargedPiasters ?? price.Piasters;
        if (amount is null)
        {
            return ValidationProblems.Field(
                HttpContext, "amountChargedPiasters", ErrorCodes.AmountRequired,
                "There is no visit price for this type: enter the amount charged.");
        }

        var now = Now;
        var day = CairoTime.DayOf(now);
        var month = CairoTime.MonthKey(day);
        var fee = type == SessionTypes.Examination ? settings.ExamFeePiasters : settings.ConsultationFeePiasters;
        var session = new Session
        {
            Id = Guid.NewGuid(),
            DoctorId = caller.DoctorId,
            PatientId = patientId,
            LinkId = link.Id,
            BranchId = branchId,
            Type = type,
            FeePiasters = fee,
            PatientFeePiasters = amount.Value,
            ListPricePiasters = price.Piasters,
            PaymentMethod = request.PaymentMethod,
            DayKey = day,
            MonthKey = month,
            CreatedBy = caller.UserId,
            CreatedByRole = caller.Role,
            // BR-AS7: «بانتظار الطبيب» until the doctor saves a clinical field.
            AwaitingDoctor = !caller.IsDoctor,
            Findings = Text.TrimToNull(request.Findings),
            Diagnosis = Text.TrimToNull(request.Diagnosis),
            PatientNotes = Text.TrimToNull(request.PatientNotes),
            FollowUpDate = request.FollowUpDate,
            CreatedAt = now,
            UpdatedAt = now,
        };
        session.ChiefComplaint = Text.TrimToNull(request.ChiefComplaint);
        SetVitals(session, request.Vitals);
        db.Sessions.Add(session);
        if (Text.TrimToNull(request.PrivateNote) is { } note)
        {
            db.SessionPrivateNotes.Add(new SessionPrivateNote { SessionId = session.Id, Text = note, UpdatedAt = now });
        }

        LinkCounters.Of(link).With(new SessionFact(session.Id, type, now, branchId)).ApplyTo(link);
        link.UpdatedAt = now;
        if (link.Archived)
        {
            // A patient seen today is not archived any more (BR-P7 hides inactive patients).
            link.Archived = false;
            link.ArchivedAt = null;
        }

        await FeeStats.AddAsync(db, caller.DoctorId, day, month, type, fee, cancellationToken);
        var patientUserId = await db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).SingleAsync(cancellationToken);
        notifications.Add(
            patientUserId,
            NotificationTexts.VisitRecorded(type == SessionTypes.Examination, doctor.FullName, branch.NameAr, branch.NameEn ?? branch.NameAr),
            $"/visits/{session.Id}",
            new { sessionId = session.Id, doctorId = caller.DoctorId });
        auditor.AddClinic(
            caller, AuditActions.SessionCreated, AuditTargets.Session, session.Id,
            new { type, branchId, feePiasters = fee, awaitingDoctor = session.AwaitingDoctor }, patientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        var view = await SessionQueries.DetailAsync(db, caller, session.Id, day, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, view);
    }

    /// <summary>
    /// D9. Open to <c>sessionsCreate</c>, <c>clinicalView</c> or <c>billingView</c> (D2 and D3 rows open it), with
    /// the fields the caller may see. Doctor-wide: the patient file is not limited to the assistant's branches.
    /// </summary>
    [HttpGet("{sessionId:guid}")]
    public async Task<IActionResult> Get(Guid sessionId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (this.RequireAny(caller, ClinicPermissions.SessionsCreate, ClinicPermissions.ClinicalView, ClinicPermissions.BillingView)
            is { } denied)
        {
            return denied;
        }

        var view = await SessionQueries.DetailAsync(db, caller, sessionId, Today, cancellationToken);
        return view is null ? this.NotFoundProblem() : Ok(view);
    }

    /// <summary>
    /// D6 Sessions tab, AS4: the patient's sessions with this doctor, newest first, paged. Open to
    /// <c>sessionsCreate</c> or <c>clinicalView</c>. Doctor-wide: the patient file is not limited to the
    /// assistant's branches (BR-AS13).
    /// </summary>
    [HttpGet("/api/patients/{patientId:guid}/sessions")]
    public async Task<IActionResult> PatientSessions(Guid patientId, [FromQuery] PatientSessionsQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (this.RequireAny(caller, ClinicPermissions.SessionsCreate, ClinicPermissions.ClinicalView) is { } denied)
        {
            return denied;
        }

        if (!await PatientLinks.ExistsAsync(db, caller.DoctorId, patientId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var sessionsOfPatient = db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == caller.DoctorId && s.PatientId == patientId && !s.Deleted)
            .OrderByDescending(s => s.CreatedAt);
        var page = await SessionQueries.ListRows(sessionsOfPatient, caller).ToPageAsync(query, cancellationToken);
        return Ok(new PagedResult<SessionListItem>(
            page.Items.Select(row => SessionQueries.Item(row, caller)).ToList(), page.Page, page.PageSize, page.TotalCount));
    }

    /// <summary>The doctor's private note (spec 6.2). Doctor only: never patients, admins or assistants (AC-11, BR-AS5).</summary>
    [HttpGet("{sessionId:guid}/privateNote")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> GetPrivateNote(Guid sessionId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (!await SessionExistsAsync(caller, sessionId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var note = await db.SessionPrivateNotes.AsNoTracking()
            .Where(n => n.SessionId == sessionId)
            .Select(n => new { n.Text, n.UpdatedAt })
            .SingleOrDefaultAsync(cancellationToken);
        Response.Headers.CacheControl = "no-store";
        return Ok(new PrivateNoteView(sessionId, note?.Text, note?.UpdatedAt));
    }

    /// <summary>Sets or (with empty text) removes the private note. Doctor only; allowed while suspended.</summary>
    [HttpPost("setPrivateNote")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> SetPrivateNote(SetPrivateNoteRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var sessionId = request.SessionId!.Value;
        var patientId = await db.Sessions
            .Where(s => s.Id == sessionId && s.DoctorId == caller.DoctorId && !s.Deleted)
            .Select(s => (Guid?)s.PatientId)
            .SingleOrDefaultAsync(cancellationToken);
        if (patientId is null)
        {
            return this.NotFoundProblem();
        }

        var now = Now;
        var text = Text.TrimToNull(request.Text);
        var note = await db.SessionPrivateNotes.SingleOrDefaultAsync(n => n.SessionId == sessionId, cancellationToken);
        if (text is null && note is not null)
        {
            db.SessionPrivateNotes.Remove(note);
        }
        else if (text is not null && note is null)
        {
            db.SessionPrivateNotes.Add(new SessionPrivateNote { SessionId = sessionId, Text = text, UpdatedAt = now });
        }
        else if (text is not null && note!.Text != text)
        {
            note.Text = text;
            note.UpdatedAt = now;
        }

        if (db.ChangeTracker.HasChanges())
        {
            auditor.AddClinic(
                caller, AuditActions.SessionPrivateNoteUpdated, AuditTargets.Session, sessionId, new { cleared = text is null }, patientId);
            await db.SaveChangesAsync(cancellationToken);
        }

        Response.Headers.CacheControl = "no-store";
        return Ok(new PrivateNoteView(sessionId, text, text is null ? null : note?.UpdatedAt ?? now));
    }

    /// <summary>
    /// D9 clinical fields (doctor only, allowed while suspended). Type and time never change (BR-S6). The
    /// doctor's save ends «بانتظار الطبيب» (BR-AS7).
    /// </summary>
    [HttpPost("updateClinical")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> UpdateClinical(UpdateClinicalRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var sessionId = request.SessionId!.Value;
        var session = await db.Sessions.SingleOrDefaultAsync(
            s => s.Id == sessionId && s.DoctorId == caller.DoctorId && !s.Deleted, cancellationToken);
        if (session is null)
        {
            return this.NotFoundProblem();
        }

        if (request.FollowUpDate is { } followUp && !CreateSessionRequestValidator.FollowUpIsValid(followUp, session.DayKey))
        {
            return ValidationProblems.Field(
                HttpContext, "followUpDate", ErrorCodes.OutOfRange, "The follow-up date must be from the session day up to 2 years after.");
        }

        var before = ClinicalFields(session);
        session.ChiefComplaint = Text.TrimToNull(request.ChiefComplaint);
        session.Findings = Text.TrimToNull(request.Findings);
        session.Diagnosis = Text.TrimToNull(request.Diagnosis);
        session.PatientNotes = Text.TrimToNull(request.PatientNotes);
        session.FollowUpDate = request.FollowUpDate;
        SetVitals(session, request.Vitals);
        var after = ClinicalFields(session);
        var changed = before.Keys.Where(key => !Equals(before[key], after[key])).ToList();

        // BR-AS7: the doctor has saved the clinical part. A save that leaves every field empty doesn't count.
        var reviewed = session.AwaitingDoctor && after.Values.Any(value => value is not null);
        if (reviewed)
        {
            session.AwaitingDoctor = false;
        }

        if (changed.Count > 0 || reviewed)
        {
            session.UpdatedAt = Now;
            auditor.AddClinic(
                caller, AuditActions.SessionClinicalUpdated, AuditTargets.Session, sessionId, new { fields = changed }, session.PatientId);
            await db.SaveChangesAsync(cancellationToken);
        }

        return Ok(await SessionQueries.DetailAsync(db, caller, sessionId, Today, cancellationToken));
    }

    /// <summary>
    /// BR-S10: the amount charged (and payment method) on the session's Cairo day, by the doctor or by whoever
    /// recorded the session. Every change is logged with before and after.
    /// </summary>
    [HttpPost("updateAmountCharged")]
    [Clinic(ClinicPermissions.SessionsCreate)]
    public async Task<IActionResult> UpdateAmountCharged(UpdateAmountChargedRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var sessionId = request.SessionId!.Value;
        var session = await db.Sessions.SingleOrDefaultAsync(
            s => s.Id == sessionId && s.DoctorId == caller.DoctorId && !s.Deleted, cancellationToken);
        if (session is null)
        {
            return this.NotFoundProblem();
        }

        if (!caller.IsDoctor && session.CreatedBy != caller.UserId)
        {
            return this.PermissionDenied(DoctorOnly);
        }

        if (session.DayKey != Today)
        {
            return this.ConflictProblem(ErrorCodes.AmountNotEditable, "The amount can only be changed on the day of the session.");
        }

        var amount = request.AmountChargedPiasters!.Value;
        if (session.PatientFeePiasters != amount || session.PaymentMethod != request.PaymentMethod)
        {
            auditor.AddClinic(
                caller, AuditActions.SessionAmountChanged, AuditTargets.Session, sessionId,
                new
                {
                    before = session.PatientFeePiasters,
                    after = amount,
                    paymentMethodBefore = session.PaymentMethod,
                    paymentMethodAfter = request.PaymentMethod,
                },
                session.PatientId);
            session.PatientFeePiasters = amount;
            session.PaymentMethod = request.PaymentMethod;
            session.UpdatedAt = Now;
            await db.SaveChangesAsync(cancellationToken);
        }

        return Ok(await SessionQueries.DetailAsync(db, caller, sessionId, Today, cancellationToken));
    }

    /// <summary>
    /// BR-S7 (spec 9.1 <c>deleteSession</c>): only the patient's latest session with this doctor, on the Cairo
    /// day it was recorded, with a reason. Soft: the link counters are rebuilt from the remaining sessions,
    /// the stats drop by its fee, and the deletion is in the admin audit log (AC-5).
    /// </summary>
    [HttpPost("deleteSession")]
    [Clinic(ClinicPermissions.SessionsDelete)]
    public async Task<IActionResult> DeleteSession(DeleteSessionRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var sessionId = request.SessionId!.Value;
        var target = await db.Sessions.AsNoTracking()
            .Where(s => s.Id == sessionId && s.DoctorId == caller.DoctorId && !s.Deleted)
            .Select(s => new { s.PatientId, s.BranchId })
            .SingleOrDefaultAsync(cancellationToken);
        if (target is null)
        {
            return this.NotFoundProblem();
        }

        if (!caller.CanUseBranch(target.BranchId))
        {
            return this.BranchNotAllowed();
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        // Same lock as createSession: a delete and a new session for one patient never interleave.
        var link = (await PatientLinks.LockAsync(db, caller.DoctorId, target.PatientId, cancellationToken))!;
        var session = await db.Sessions.SingleAsync(s => s.Id == sessionId, cancellationToken);
        if (session.Deleted)
        {
            return this.NotFoundProblem();
        }

        var remaining = await db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == caller.DoctorId && s.PatientId == target.PatientId && !s.Deleted && s.Id != sessionId)
            .Select(s => new SessionFact(s.Id, s.Type, s.CreatedAt, s.BranchId))
            .ToListAsync(cancellationToken);
        var isLatest = remaining.All(s => s.CreatedAt < session.CreatedAt);
        if (DeleteRule.BlockedReason(isLatest, session.DayKey, Today) is { } blocked)
        {
            return this.ConflictProblem(ErrorCodes.SessionNotDeletable, "This session can't be deleted.").WithFields(("reason", blocked));
        }

        var now = Now;
        var reason = Text.CollapseSpaces(request.Reason!);
        session.Deleted = true;
        session.DeletedAt = now;
        session.DeletedBy = caller.UserId;
        session.DeleteReason = reason;
        session.UpdatedAt = now;
        LinkCounters.From(remaining).ApplyTo(link);
        link.UpdatedAt = now;
        await FeeStats.RemoveAsync(db, caller.DoctorId, session.DayKey, session.MonthKey, session.Type, session.FeePiasters, cancellationToken);
        auditor.AddClinic(
            caller, AuditActions.SessionDeleted, AuditTargets.Session, sessionId,
            new { reason, type = session.Type, feePiasters = session.FeePiasters, day = session.DayKey }, session.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Ok(new DeletedSessionResponse(sessionId, now));
    }

    private Task<bool> SessionExistsAsync(ClinicCaller caller, Guid sessionId, CancellationToken cancellationToken) =>
        db.Sessions.AnyAsync(s => s.Id == sessionId && s.DoctorId == caller.DoctorId && !s.Deleted, cancellationToken);

    private sealed record BranchForSession(
        Guid Id, string NameAr, string? NameEn, string Status, int? ExaminationPricePiasters, int? ConsultationPricePiasters);

    private sealed record DoctorPrices(string FullName, int? ExaminationPricePiasters, int? ConsultationPricePiasters);

    /// <summary>
    /// The branch of a new session: one of the doctor's branches (404 otherwise) that isn't archived. Callers
    /// check <see cref="ClinicCaller.CanUseBranch"/> first (BR-AS13).
    /// </summary>
    private async Task<(BranchForSession? Branch, IActionResult? Problem)> BranchForNewSessionAsync(
        ClinicCaller caller, Guid branchId, CancellationToken cancellationToken)
    {
        var branch = await db.Branches.AsNoTracking()
            .Where(b => b.Id == branchId && b.DoctorId == caller.DoctorId)
            .Select(b => new BranchForSession(b.Id, b.NameAr, b.NameEn, b.Status, b.ExaminationPricePiasters, b.ConsultationPricePiasters))
            .SingleOrDefaultAsync(cancellationToken);
        if (branch is null)
        {
            return (null, this.NotFoundProblem());
        }

        return branch.Status == "archived"
            ? (null, this.ConflictProblem(ErrorCodes.SessionBranchArchived, "This branch is archived."))
            : (branch, null);
    }

    private Task<DoctorPrices> DoctorPricesAsync(Guid doctorId, CancellationToken cancellationToken) =>
        db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new DoctorPrices(d.FullName, d.ExaminationPricePiasters, d.ConsultationPricePiasters))
            .SingleAsync(cancellationToken);

    /// <summary>Vitals as sent (all cleared when <paramref name="vitals"/> is null), rounded to the columns' decimals.</summary>
    private static void SetVitals(Session session, VitalsInput? vitals)
    {
        session.BpSys = vitals?.BpSys;
        session.BpDia = vitals?.BpDia;
        session.Pulse = vitals?.Pulse;
        session.TempC = vitals?.TempC is { } temp ? Math.Round(temp, 1, MidpointRounding.AwayFromZero) : null;
        session.WeightKg = vitals?.WeightKg is { } weight ? Math.Round(weight, 2, MidpointRounding.AwayFromZero) : null;
        session.HeightCm = vitals?.HeightCm is { } height ? Math.Round(height, 1, MidpointRounding.AwayFromZero) : null;
        session.Glucose = vitals?.Glucose;
    }

    /// <summary>The clinical fields by JSON name, to find what an update changed (names go in the audit row, values never).</summary>
    private static Dictionary<string, object?> ClinicalFields(Session s) => new()
    {
        ["chiefComplaint"] = s.ChiefComplaint,
        ["findings"] = s.Findings,
        ["diagnosis"] = s.Diagnosis,
        ["patientNotes"] = s.PatientNotes,
        ["followUpDate"] = s.FollowUpDate,
        ["vitals.bpSys"] = s.BpSys,
        ["vitals.bpDia"] = s.BpDia,
        ["vitals.pulse"] = s.Pulse,
        ["vitals.tempC"] = s.TempC,
        ["vitals.weightKg"] = s.WeightKg,
        ["vitals.heightCm"] = s.HeightCm,
        ["vitals.glucose"] = s.Glucose,
    };
}
