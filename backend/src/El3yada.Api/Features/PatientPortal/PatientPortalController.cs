using El3yada.Api.Auth;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Api.Infrastructure.Errors;
using El3yada.Api.Infrastructure.Files;
using El3yada.Api.Infrastructure.Paging;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace El3yada.Api.Features.PatientPortal;

/// <summary>
/// The patient app (spec 7.4, P1–P10 and P14). Read-only, except the "New" badges and the
/// deletion request. Only the <c>patient</c> role reaches these routes; doctors, assistants
/// and admins get 403 (AC-11, AC-12).
/// </summary>
[ApiController]
[Route("api/patient")]
[Authorize(Policy = Policies.Patient)]
[Produces("application/json")]
public sealed class PatientPortalController(
    PatientPortalService portal,
    PatientAccountService account,
    IFileStorage storage) : ControllerBase
{
    /// <summary>P1 home cards. <paramref name="doctorId"/> limits them to one doctor (doctor selector).</summary>
    [HttpGet("home", Name = "getPatientHome")]
    public Task<PatientHomeDto> GetHome([FromQuery] Guid? doctorId, CancellationToken ct) =>
        portal.GetHomeAsync(doctorId, ct);

    /// <summary>P2 my doctors.</summary>
    [HttpGet("doctors", Name = "getMyDoctors")]
    public Task<IReadOnlyList<MyDoctorDto>> GetDoctors(CancellationToken ct) => portal.GetMyDoctorsAsync(ct);

    /// <summary>P3 doctor info with branches, hours and prices. 404 unless the caller is linked to the doctor.</summary>
    [HttpGet("doctors/{doctorId:guid}", Name = "getMyDoctor")]
    public Task<DoctorInfoDto> GetDoctor(Guid doctorId, CancellationToken ct) => portal.GetDoctorInfoAsync(doctorId, ct);

    /// <summary>P4 visits, newest first.</summary>
    [HttpGet("visits", Name = "getMyVisits")]
    public Task<PagedResult<VisitListItemDto>> GetVisits([FromQuery] PatientListQuery query, CancellationToken ct) =>
        portal.GetVisitsAsync(query, ct);

    /// <summary>P5 visit details. Private notes are never part of the answer.</summary>
    [HttpGet("visits/{sessionId:guid}", Name = "getMyVisit")]
    public Task<VisitDetailDto> GetVisit(Guid sessionId, CancellationToken ct) => portal.GetVisitAsync(sessionId, ct);

    /// <summary>P6 prescriptions (<c>sent</c> and <c>cancelled</c> only). <c>kind</c>: medication or investigations.</summary>
    [HttpGet("prescriptions", Name = "getMyPrescriptions")]
    public Task<PagedResult<PrescriptionListItemDto>> GetPrescriptions([FromQuery] PatientListQuery query, CancellationToken ct) =>
        portal.GetPrescriptionsAsync(query, ct);

    /// <summary>P7 prescription details.</summary>
    [HttpGet("prescriptions/{id:guid}", Name = "getMyPrescription")]
    public Task<PrescriptionDetailDto> GetPrescription(Guid id, CancellationToken ct) => portal.GetPrescriptionAsync(id, ct);

    /// <summary>P7 the PDF exactly as the doctor sent it.</summary>
    [HttpGet("prescriptions/{id:guid}/pdf", Name = "getMyPrescriptionPdf")]
    [Produces("application/pdf")]
    public async Task<IActionResult> GetPrescriptionPdf(Guid id, CancellationToken ct)
    {
        var (path, fileName) = await portal.GetPrescriptionPdfAsync(id, ct);
        return await StreamAsync(path, "application/pdf", fileName, ct);
    }

    /// <summary>P8 medical files. <c>kind</c>: prescription, lab, radiology or other.</summary>
    [HttpGet("records", Name = "getMyRecords")]
    public Task<PagedResult<RecordListItemDto>> GetRecords([FromQuery] PatientListQuery query, CancellationToken ct) =>
        portal.GetRecordsAsync(query, ct);

    /// <summary>P8 the count on each category tab.</summary>
    [HttpGet("records/counts", Name = "getMyRecordCounts")]
    public Task<RecordCountsDto> GetRecordCounts([FromQuery] Guid? doctorId, CancellationToken ct) =>
        portal.GetRecordCountsAsync(doctorId, ct);

    /// <summary>P9 one medical file with its attachments.</summary>
    [HttpGet("records/{id:guid}", Name = "getMyRecord")]
    public Task<RecordDetailDto> GetRecord(Guid id, CancellationToken ct) => portal.GetRecordAsync(id, ct);

    /// <summary>P9 download one attachment, or its thumbnail with <c>?thumbnail=true</c>.</summary>
    [HttpGet("records/{recordId:guid}/attachments/{attachmentId:guid}", Name = "getMyAttachment")]
    public async Task<IActionResult> GetAttachment(Guid recordId, Guid attachmentId, [FromQuery] bool thumbnail, CancellationToken ct)
    {
        var (path, fileName, mimeType) = await portal.GetAttachmentAsync(recordId, attachmentId, thumbnail, ct);
        return await StreamAsync(path, mimeType, fileName, ct);
    }

    /// <summary>P10 personal info and each doctor's medical profile (read-only).</summary>
    [HttpGet("medical-profile", Name = "getMyMedicalProfile")]
    public Task<MedicalProfileDto> GetMedicalProfile(CancellationToken ct) => portal.GetMedicalProfileAsync(ct);

    /// <summary>Clears the "New" badge of the given items. Unknown or foreign ids are ignored.</summary>
    [HttpPost("seen", Name = "markSeen")]
    public async Task<IActionResult> MarkSeen(MarkSeenRequest request, CancellationToken ct)
    {
        await portal.MarkSeenAsync(request, ct);
        return NoContent();
    }

    /// <summary>P14 account: personal info, preferences and the latest deletion request.</summary>
    [HttpGet("account", Name = "getPatientAccount")]
    public Task<PatientAccountDto> GetAccount(CancellationToken ct) => account.GetAccountAsync(ct);

    /// <summary>The latest deletion request, or 204 when there is none.</summary>
    [HttpGet("deletion-request", Name = "getAccountDeletionRequest")]
    public async Task<ActionResult<DeletionRequestDto>> GetDeletionRequest(CancellationToken ct) =>
        await account.GetDeletionRequestAsync(ct) is { } request ? request : NoContent();

    /// <summary><c>requestAccountDeletion</c> (P14 → AD12). 409 <c>DELETION_ALREADY_REQUESTED</c> while one is pending.</summary>
    [HttpPost("deletion-request", Name = "requestAccountDeletion")]
    public async Task<ActionResult<DeletionRequestDto>> RequestDeletion(RequestAccountDeletionRequest request, CancellationToken ct)
    {
        var created = await account.RequestDeletionAsync(request, ct);
        return CreatedAtRoute("getAccountDeletionRequest", null, created);
    }

    private async Task<IActionResult> StreamAsync(string path, string mimeType, string fileName, CancellationToken ct)
    {
        var stream = await storage.OpenReadAsync(path, ct) ?? throw ApiException.NotFound(ErrorCodes.FileMissing);
        // Medical content: never cached by proxies or the browser, never sniffed as another type.
        Response.Headers.CacheControl = "private, no-store";
        Response.Headers.XContentTypeOptions = "nosniff";
        return File(stream, mimeType, fileName, enableRangeProcessing: true);
    }
}
