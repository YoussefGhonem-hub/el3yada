using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Configuration;
using El3yada.Api.Notifications;
using El3yada.Api.Prescriptions;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.Net.Http.Headers;

namespace El3yada.Api.Controllers;

/// <summary>
/// Prescriptions and investigation requests (spec 6.4, D13–D15, AS7, AS8). Contract:
/// backend/docs/api-phase-3-prescriptions.md. The app builds the PDF (6.4.1) and uploads it with
/// <c>sendPrescription</c>, so the patient sees exactly what was printed (BR-RX4).
/// <list type="bullet">
/// <item>Drafts: the doctor, or an assistant with <c>prescriptionsDraft</c> (BR-AS12).</item>
/// <item>Send and cancel: the doctor only (spec D12, 6.10).</item>
/// <item>Reads: <c>clinicalView</c> sees every status; <c>prescriptionsPrint</c> sees sent ones only (AS8).</item>
/// </list>
/// </summary>
[ApiController]
[Route("api")]
[Clinic]
public sealed class PrescriptionsController(
    AppDbContext db, IFileStorage storage, Auditor auditor, NotificationWriter notifications, TimeProvider time,
    IOptions<AppLinksOptions> appLinks, IOptions<JsonOptions> jsonOptions) : ControllerBase
{
    private const long SendRequestMaxBytes = PrescriptionLimits.PdfMaxBytes + (1024 * 1024);

    private DateTime Now => time.GetUtcNow().UtcDateTime;

    private Task<List<PrescriptionView>> ViewsAsync(IReadOnlyList<Guid> ids, CancellationToken cancellationToken) =>
        PrescriptionStore.ViewsAsync(db, ids, appLinks.Value.QrUrl, cancellationToken);

    private async Task<PrescriptionView> ViewAsync(Guid id, CancellationToken cancellationToken) =>
        (await ViewsAsync([id], cancellationToken)).Single();

    /// <summary>
    /// D13/D14: a new draft for one of the doctor's sessions (BR-RX1). The diagnosis comes from the session, and a
    /// medication prescription takes the session's follow-up date. With <c>copyFromId</c> ("Issue new copy", D15),
    /// the diagnosis, advice, follow-up and items come from that sent or cancelled document instead.
    /// </summary>
    [HttpPost("prescriptions/createPrescriptionDraft")]
    [Clinic(ClinicPermissions.PrescriptionsDraft, BlockedWhileSuspended = true)]
    public async Task<IActionResult> CreateDraft(CreatePrescriptionDraftRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var session = await db.Sessions.AsNoTracking()
            .SingleOrDefaultAsync(s => s.Id == request.SessionId && s.DoctorId == caller.DoctorId && !s.Deleted, cancellationToken);
        if (session is null)
        {
            return ValidationProblems.Field(HttpContext, "sessionId", ErrorCodes.InvalidSession, "Pick one of this doctor's visits.");
        }

        var kind = request.Kind!;
        Prescription? source = null;
        if (request.CopyFromId is { } copyFromId)
        {
            source = await db.Prescriptions.AsNoTracking().SingleOrDefaultAsync(
                p => p.Id == copyFromId && p.DoctorId == caller.DoctorId && p.Kind == kind
                    && (p.Status == PrescriptionStatuses.Sent || p.Status == PrescriptionStatuses.Cancelled),
                cancellationToken);
            if (source is null || source.PatientId != session.PatientId)
            {
                return ValidationProblems.Field(HttpContext, "copyFromId", ErrorCodes.InvalidCopySource, "Copy a sent document of this kind for this patient.");
            }
        }

        var now = Now;
        var prescription = new Prescription
        {
            Id = Guid.NewGuid(),
            DoctorId = caller.DoctorId,
            PatientId = session.PatientId,
            SessionId = session.Id,
            Kind = kind,
            Diagnosis = source is null ? session.Diagnosis : source.Diagnosis,
            Advice = source?.Advice,
            FollowUpDate = source is null ? (kind == PrescriptionKinds.Medication ? session.FollowUpDate : null) : source.FollowUpDate,
            Status = PrescriptionStatuses.Draft,
            PreparedBy = caller.UserId,
            PreparedByRole = caller.Role,
            ReplacesRxId = source?.Id,
            QrShortCode = await PrescriptionStore.NewShortCodeAsync(db, cancellationToken),
            CreatedAt = now,
            UpdatedAt = now,
        };

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        db.Prescriptions.Add(prescription);
        if (source is not null)
        {
            await PrescriptionStore.ReplaceItemsAsync(db, prescription, await PrescriptionStore.ItemInputsAsync(db, source, cancellationToken), cancellationToken);
        }

        auditor.AddClinic(
            caller, AuditActions.PrescriptionDraftCreated, AuditTargets.Prescription, prescription.Id,
            new { kind, copyFromId = source?.Id }, prescription.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, await ViewAsync(prescription.Id, cancellationToken));
    }

    /// <summary>D13/D14 "Save draft": everything replaced; items in the order sent (that is how they are reordered).</summary>
    [HttpPost("prescriptions/updatePrescriptionDraft")]
    [Clinic(ClinicPermissions.PrescriptionsDraft, BlockedWhileSuspended = true)]
    public async Task<IActionResult> UpdateDraft(UpdatePrescriptionDraftRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var prescription = await LockAsync(caller.DoctorId, request.PrescriptionId!.Value, cancellationToken);
        if (prescription is null)
        {
            return this.NotFoundProblem();
        }

        if (!PrescriptionStatuses.IsEditable(prescription.Status))
        {
            return NotEditable(prescription);
        }

        var items = request.Items ?? [];
        if (PrescriptionItemRules.Check(prescription.Kind, items) is { Count: > 0 } failures)
        {
            return ValidationProblems.Create(HttpContext, failures);
        }

        prescription.Diagnosis = Text.TrimToNull(request.Diagnosis);
        prescription.Advice = Text.TrimToNull(request.Advice);
        prescription.FollowUpDate = request.FollowUpDate;
        prescription.UpdatedAt = Now;
        await PrescriptionStore.ReplaceItemsAsync(db, prescription, items, cancellationToken);
        auditor.AddClinic(
            caller, AuditActions.PrescriptionDraftUpdated, AuditTargets.Prescription, prescription.Id,
            new { kind = prescription.Kind, items = items.Count }, prescription.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Ok(await ViewAsync(prescription.Id, cancellationToken));
    }

    /// <summary>Discards a draft (drafts were never seen by the patient, so nothing is kept).</summary>
    [HttpPost("prescriptions/deletePrescriptionDraft")]
    [Clinic(ClinicPermissions.PrescriptionsDraft, BlockedWhileSuspended = true)]
    public async Task<IActionResult> DeleteDraft(PrescriptionIdRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var prescription = await LockAsync(caller.DoctorId, request.PrescriptionId!.Value, cancellationToken);
        if (prescription is null)
        {
            return this.NotFoundProblem();
        }

        if (!PrescriptionStatuses.IsEditable(prescription.Status))
        {
            return NotEditable(prescription);
        }

        await db.PrescriptionMedicationItems.Where(i => i.PrescriptionId == prescription.Id).ExecuteDeleteAsync(cancellationToken);
        await db.PrescriptionInvestigationItems.Where(i => i.PrescriptionId == prescription.Id).ExecuteDeleteAsync(cancellationToken);
        db.Prescriptions.Remove(prescription);
        auditor.AddClinic(
            caller, AuditActions.PrescriptionDraftDeleted, AuditTargets.Prescription, prescription.Id,
            new { kind = prescription.Kind }, prescription.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return NoContent();
    }

    /// <summary>
    /// AS7 «إرسال للطبيب للمراجعة» (BR-AS12, [S]): an assistant marks a draft ready, and the doctor is notified.
    /// The doctor reviews it in D13/D14 and sends it from D15.
    /// </summary>
    [HttpPost("prescriptions/submitDraftForReview")]
    [Clinic(ClinicPermissions.PrescriptionsDraft, BlockedWhileSuspended = true)]
    public async Task<IActionResult> SubmitForReview(PrescriptionIdRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (caller.IsDoctor)
        {
            return this.PermissionDenied("assistantOnly");
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var prescription = await LockAsync(caller.DoctorId, request.PrescriptionId!.Value, cancellationToken);
        if (prescription is null)
        {
            return this.NotFoundProblem();
        }

        if (prescription.Status != PrescriptionStatuses.Draft)
        {
            return prescription.Status == PrescriptionStatuses.ReadyForReview
                ? Ok(await ViewAsync(prescription.Id, cancellationToken))
                : NotEditable(prescription);
        }

        if (!await HasItemsAsync(prescription, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.PrescriptionEmpty, "Add at least one item first.");
        }

        prescription.Status = PrescriptionStatuses.ReadyForReview;
        prescription.UpdatedAt = Now;
        var patientName = await db.DoctorPatients
            .Where(l => l.DoctorId == caller.DoctorId && l.PatientId == prescription.PatientId)
            .Select(l => l.PatientName).SingleAsync(cancellationToken);
        notifications.Add(
            caller.DoctorId,
            NotificationTexts.PrescriptionReadyForReview(patientName, caller.AssistantName!),
            $"/prescriptions/{prescription.Id}",
            new { prescriptionId = prescription.Id, patientId = prescription.PatientId });
        auditor.AddClinic(
            caller, AuditActions.PrescriptionSubmittedForReview, AuditTargets.Prescription, prescription.Id,
            new { kind = prescription.Kind }, prescription.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Ok(await ViewAsync(prescription.Id, cancellationToken));
    }

    /// <summary>
    /// D15 "Send to patient" and "Send and print" (BR-RX2–RX5): <c>multipart/form-data</c> with <c>data</c>
    /// (<c>{ "prescriptionId": "…" }</c>) and <c>pdf</c>, the document the app built. Doctor only. Stores the PDF,
    /// marks the document sent, counts its items in the doctor's history (BR-CAT4) and notifies the patient.
    /// </summary>
    [HttpPost("prescriptions/sendPrescription")]
    [Clinic(DoctorOnly = true, BlockedWhileSuspended = true)]
    [RequestSizeLimit(SendRequestMaxBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = SendRequestMaxBytes)]
    public async Task<IActionResult> Send(CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (!Request.HasFormContentType)
        {
            return this.Problem(StatusCodes.Status415UnsupportedMediaType, ErrorCodes.UnsupportedMediaType, "Send multipart/form-data.");
        }

        IFormCollection form;
        try
        {
            form = await Request.ReadFormAsync(cancellationToken);
        }
        catch (Exception ex) when (ex is InvalidDataException or BadHttpRequestException)
        {
            return this.Problem(StatusCodes.Status413PayloadTooLarge, ErrorCodes.RequestTooLarge, "The request is too large.");
        }

        SendPrescriptionData? data = null;
        if (form["data"].ToString() is { Length: > 0 } json)
        {
            try
            {
                data = JsonSerializer.Deserialize<SendPrescriptionData>(json, jsonOptions.Value.JsonSerializerOptions);
            }
            catch (JsonException)
            {
            }
        }

        if (data?.PrescriptionId is not { } prescriptionId)
        {
            return ValidationProblems.Field(HttpContext, "data.prescriptionId", ErrorCodes.Required, "The prescription is required.");
        }

        var pdf = form.Files.GetFile("pdf");
        if (pdf is null || pdf.Length == 0)
        {
            return ValidationProblems.Field(HttpContext, "pdf", ErrorCodes.Required, "Attach the prescription PDF.");
        }

        if (pdf.Length > PrescriptionLimits.PdfMaxBytes)
        {
            return ValidationProblems.Field(HttpContext, "pdf", ErrorCodes.FileTooLarge, "The PDF is larger than 10 MB.");
        }

        var header = new byte[FileTypes.SignatureLength];
        await using (var peek = pdf.OpenReadStream())
        {
            var read = await peek.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
            if (FileTypes.Detect(header.AsSpan(0, read)) != FileTypes.Pdf)
            {
                return ValidationProblems.Field(HttpContext, "pdf", ErrorCodes.FileTypeNotAllowed, "Attach a PDF file.");
            }
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var prescription = await LockAsync(caller.DoctorId, prescriptionId, cancellationToken);
        if (prescription is null)
        {
            return this.NotFoundProblem();
        }

        if (!PrescriptionStatuses.IsEditable(prescription.Status))
        {
            return NotEditable(prescription);
        }

        if (!await HasItemsAsync(prescription, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.PrescriptionEmpty, "Add at least one item before sending.");
        }

        var path = StoragePath.PrescriptionPdf(caller.DoctorId, prescription.PatientId, prescription.Id);
        try
        {
            await using (var content = pdf.OpenReadStream())
            {
                await storage.SaveAsync(path, content, FileTypes.Pdf, PrescriptionLimits.PdfMaxBytes, cancellationToken);
            }

            var now = Now;
            prescription.Status = PrescriptionStatuses.Sent;
            prescription.PdfPath = path.Value;
            prescription.SentAt = now;
            prescription.UpdatedAt = now;
            var doctor = await db.Doctors.Where(d => d.UserId == caller.DoctorId)
                .Select(d => new { d.FullName, d.FullNameEn }).SingleAsync(cancellationToken);
            var patientUserId = await db.Patients.Where(p => p.Id == prescription.PatientId).Select(p => p.UserId).SingleAsync(cancellationToken);
            notifications.Add(
                patientUserId,
                NotificationTexts.PrescriptionSent(prescription.Kind, doctor.FullName, doctor.FullNameEn ?? doctor.FullName),
                $"/prescriptions/{prescription.Id}",
                new { prescriptionId = prescription.Id, doctorId = caller.DoctorId });
            await PrescriptionStore.CountUseAsync(db, prescription, now, cancellationToken);
            var itemCount = await ItemCountAsync(prescription, cancellationToken);
            auditor.AddClinic(
                caller, AuditActions.PrescriptionSent, AuditTargets.Prescription, prescription.Id,
                new { kind = prescription.Kind, items = itemCount }, prescription.PatientId);
            await db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            await storage.DeleteAsync(path, CancellationToken.None);
            throw;
        }

        return Ok(await ViewAsync(prescriptionId, cancellationToken));
    }

    /// <summary>D15 Cancel (BR-RX2): the patient sees the document struck through. Doctor only.</summary>
    [HttpPost("prescriptions/cancelPrescription")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> Cancel(CancelPrescriptionRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var prescription = await LockAsync(caller.DoctorId, request.PrescriptionId!.Value, cancellationToken);
        if (prescription is null)
        {
            return this.NotFoundProblem();
        }

        if (prescription.Status != PrescriptionStatuses.Sent)
        {
            return this.ConflictProblem(ErrorCodes.PrescriptionNotSent, "Only a sent document can be cancelled.")
                .WithFields(("status", prescription.Status));
        }

        var now = Now;
        prescription.Status = PrescriptionStatuses.Cancelled;
        prescription.CancelledAt = now;
        prescription.CancelReason = Text.CollapseSpaces(request.Reason!);
        prescription.UpdatedAt = now;
        var doctor = await db.Doctors.Where(d => d.UserId == caller.DoctorId)
            .Select(d => new { d.FullName, d.FullNameEn }).SingleAsync(cancellationToken);
        var patientUserId = await db.Patients.Where(p => p.Id == prescription.PatientId).Select(p => p.UserId).SingleAsync(cancellationToken);
        notifications.Add(
            patientUserId,
            NotificationTexts.PrescriptionCancelled(prescription.Kind, doctor.FullName, doctor.FullNameEn ?? doctor.FullName),
            $"/prescriptions/{prescription.Id}",
            new { prescriptionId = prescription.Id, doctorId = caller.DoctorId });
        auditor.AddClinic(
            caller, AuditActions.PrescriptionCancelled, AuditTargets.Prescription, prescription.Id,
            new { kind = prescription.Kind }, prescription.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Ok(await ViewAsync(prescription.Id, cancellationToken));
    }

    /// <summary>D9 and D15 "Print all": the session's documents, oldest first.</summary>
    [HttpGet("sessions/{sessionId:guid}/prescriptions")]
    public async Task<IActionResult> ForSession(Guid sessionId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (ReadDenied(caller) is { } denied)
        {
            return denied;
        }

        if (!await db.Sessions.AnyAsync(s => s.Id == sessionId && s.DoctorId == caller.DoctorId && !s.Deleted, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var ids = await PrescriptionStore.Visible(db, caller)
            .Where(p => p.SessionId == sessionId)
            .OrderBy(p => p.CreatedAt).Select(p => p.Id)
            .ToListAsync(cancellationToken);
        return Ok(await ViewsAsync(ids, cancellationToken));
    }

    /// <summary>D6 Prescriptions tab: newest first, paged.</summary>
    [HttpGet("patients/{patientId:guid}/prescriptions")]
    public async Task<IActionResult> ForPatient(Guid patientId, [FromQuery] PrescriptionListQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (ReadDenied(caller) is { } denied)
        {
            return denied;
        }

        if (!await db.DoctorPatients.AnyAsync(l => l.DoctorId == caller.DoctorId && l.PatientId == patientId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var prescriptions = PrescriptionStore.Visible(db, caller).Where(p => p.PatientId == patientId);
        if (query.Kind is { } kind)
        {
            prescriptions = prescriptions.Where(p => p.Kind == kind);
        }

        var page = await prescriptions
            .OrderByDescending(p => p.CreatedAt).ThenByDescending(p => p.Id)
            .Select(p => p.Id)
            .ToPageAsync(query, cancellationToken);
        return Ok(new PagedResult<PrescriptionView>(await ViewsAsync(page.Items, cancellationToken), page.Page, page.PageSize, page.TotalCount));
    }

    [HttpGet("prescriptions/{prescriptionId:guid}")]
    public async Task<IActionResult> Get(Guid prescriptionId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (ReadDenied(caller) is { } denied)
        {
            return denied;
        }

        return await PrescriptionStore.Visible(db, caller).AnyAsync(p => p.Id == prescriptionId, cancellationToken)
            ? Ok(await ViewAsync(prescriptionId, cancellationToken))
            : this.NotFoundProblem();
    }

    /// <summary>The stored PDF (BR-RX5 "Reprint": every copy is identical). Sent and cancelled documents; AS8 sent only.</summary>
    [HttpGet("prescriptions/{prescriptionId:guid}/pdf")]
    public async Task<IActionResult> Pdf(Guid prescriptionId, [FromQuery] bool download, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (ReadDenied(caller) is { } denied)
        {
            return denied;
        }

        var row = await PrescriptionStore.Visible(db, caller)
            .Where(p => p.Id == prescriptionId && p.PdfPath != null)
            .Select(p => new { p.PdfPath, p.SentAt, p.Kind })
            .SingleOrDefaultAsync(cancellationToken);
        if (row is null || !StoragePath.TryParse(row.PdfPath, out var path) || await storage.OpenReadAsync(path, cancellationToken) is not { } stored)
        {
            return this.NotFoundProblem();
        }

        var disposition = new ContentDispositionHeaderValue(download ? "attachment" : "inline");
        disposition.SetHttpFileName($"{(row.Kind == PrescriptionKinds.Medication ? "prescription" : "request")}-{row.SentAt:yyyy-MM-dd}.pdf");
        Response.Headers.ContentDisposition = disposition.ToString();
        Response.Headers.CacheControl = "private, no-store";
        Response.Headers.XContentTypeOptions = "nosniff";
        return new FileStreamResult(stored.Content, FileTypes.Pdf);
    }

    /// <summary>"Used before" (BR-CAT4): the doctor's most used items, for ranking search results on the device.</summary>
    [HttpGet("prescriptions/itemHistory")]
    [Clinic(ClinicPermissions.PrescriptionsDraft)]
    public async Task<IActionResult> ItemHistory(CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        return Ok(await db.DoctorItemHistories.AsNoTracking()
            .Where(h => h.DoctorId == caller.DoctorId)
            .OrderByDescending(h => h.UseCount).ThenByDescending(h => h.LastUsedAt)
            .Take(PrescriptionLimits.HistoryLimit)
            .Select(h => new ItemHistoryView(h.Id, h.Kind, h.Name, h.CatalogId, h.Form, h.Strength, h.UseCount, h.LastUsedAt))
            .ToListAsync(cancellationToken));
    }

    /// <summary>D23 [S]: forget a frequently used item.</summary>
    [HttpPost("prescriptions/deleteHistoryItem")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> DeleteHistoryItem(HistoryItemIdRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var deleted = await db.DoctorItemHistories
            .Where(h => h.Id == request.ItemId && h.DoctorId == caller.DoctorId)
            .ExecuteDeleteAsync(cancellationToken);
        return deleted == 0 ? this.NotFoundProblem() : NoContent();
    }

    /// <summary>D23 [S] templates (BR-RX6). Doctor only.</summary>
    [HttpGet("prescriptionTemplates")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> Templates([FromQuery] string? kind, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var rows = await db.PrescriptionTemplates.AsNoTracking()
            .Where(t => t.DoctorId == caller.DoctorId && (kind == null || t.Kind == kind))
            .OrderBy(t => t.Name)
            .ToListAsync(cancellationToken);
        return Ok(rows.Select(TemplateViewOf).ToList());
    }

    [HttpPost("prescriptionTemplates/createTemplate")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> CreateTemplate(CreateTemplateRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var now = Now;
        var template = new PrescriptionTemplate
        {
            Id = Guid.NewGuid(),
            DoctorId = caller.DoctorId,
            Kind = request.Kind!,
            Name = Text.CollapseSpaces(request.Name!),
            ItemsJson = PrescriptionStore.TemplateItemsJson(request.Kind!, request.Items!),
            Advice = Text.TrimToNull(request.Advice),
            CreatedAt = now,
            UpdatedAt = now,
        };
        db.PrescriptionTemplates.Add(template);
        await db.SaveChangesAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, TemplateViewOf(template));
    }

    [HttpPost("prescriptionTemplates/updateTemplate")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> UpdateTemplate(UpdateTemplateRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var template = await db.PrescriptionTemplates
            .SingleOrDefaultAsync(t => t.Id == request.TemplateId && t.DoctorId == caller.DoctorId, cancellationToken);
        if (template is null)
        {
            return this.NotFoundProblem();
        }

        if (PrescriptionItemRules.Check(template.Kind, request.Items) is { Count: > 0 } failures)
        {
            return ValidationProblems.Create(HttpContext, failures);
        }

        template.Name = Text.CollapseSpaces(request.Name!);
        template.ItemsJson = PrescriptionStore.TemplateItemsJson(template.Kind, request.Items!);
        template.Advice = Text.TrimToNull(request.Advice);
        template.UpdatedAt = Now;
        await db.SaveChangesAsync(cancellationToken);
        return Ok(TemplateViewOf(template));
    }

    [HttpPost("prescriptionTemplates/deleteTemplate")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> DeleteTemplate(TemplateIdRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var deleted = await db.PrescriptionTemplates
            .Where(t => t.Id == request.TemplateId && t.DoctorId == caller.DoctorId)
            .ExecuteDeleteAsync(cancellationToken);
        return deleted == 0 ? this.NotFoundProblem() : NoContent();
    }

    private static TemplateView TemplateViewOf(PrescriptionTemplate t) =>
        new(t.Id, t.Kind, t.Name, PrescriptionStore.TemplateItems(t.Kind, t.ItemsJson), t.Advice, t.CreatedAt, t.UpdatedAt);

    /// <summary>Reading prescriptions needs <c>clinicalView</c> or <c>prescriptionsPrint</c> (6.10).</summary>
    private ObjectResult? ReadDenied(ClinicCaller caller) =>
        this.RequireAny(caller, ClinicPermissions.PrescriptionsPrint, ClinicPermissions.ClinicalView);

    /// <summary>The prescription with an update lock until the transaction ends, so two saves or sends run one at a time.</summary>
    private Task<Prescription?> LockAsync(Guid doctorId, Guid prescriptionId, CancellationToken cancellationToken) =>
        db.Prescriptions
            .FromSqlInterpolated($"SELECT * FROM [Prescriptions] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {prescriptionId} AND [DoctorId] = {doctorId}")
            .SingleOrDefaultAsync(cancellationToken);

    private async Task<bool> HasItemsAsync(Prescription prescription, CancellationToken cancellationToken) =>
        await ItemCountAsync(prescription, cancellationToken) > 0;

    private Task<int> ItemCountAsync(Prescription prescription, CancellationToken cancellationToken) =>
        prescription.Kind == PrescriptionKinds.Medication
            ? db.PrescriptionMedicationItems.CountAsync(i => i.PrescriptionId == prescription.Id, cancellationToken)
            : db.PrescriptionInvestigationItems.CountAsync(i => i.PrescriptionId == prescription.Id, cancellationToken);

    private ObjectResult NotEditable(Prescription prescription) =>
        this.ConflictProblem(ErrorCodes.PrescriptionNotEditable, "This document is already sent; cancel it and issue a new copy.")
            .WithFields(("status", prescription.Status));
}
