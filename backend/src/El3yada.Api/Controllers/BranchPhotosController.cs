using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.ClinicAdmin;
using El3yada.Api.Common;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

public sealed record ReorderBranchPhotosRequest(Guid? BranchId, List<Guid>? PhotoIds);

public sealed class ReorderBranchPhotosRequestValidator : AbstractValidator<ReorderBranchPhotosRequest>
{
    public ReorderBranchPhotosRequestValidator()
    {
        RuleFor(x => x.BranchId).Required();
        RuleFor(x => x.PhotoIds).NotNull().WithErrorCode(ErrorCodes.Required).WithMessage("Send every photo, in the new order.");
    }
}

public sealed record DeleteBranchPhotoRequest(Guid? BranchId, Guid? PhotoId);

public sealed class DeleteBranchPhotoRequestValidator : AbstractValidator<DeleteBranchPhotoRequest>
{
    public DeleteBranchPhotoRequestValidator()
    {
        RuleFor(x => x.BranchId).Required();
        RuleFor(x => x.PhotoId).Required();
    }
}

/// <summary>
/// D29 Info tab: branch photos [S] (BR-BR2, up to <see cref="MaxPhotos"/>), and P3, where linked patients see them.
/// Uploads are JPEG, PNG or WebP up to <see cref="PhotoMaxBytes"/>; each is stored as a JPEG of at most
/// <see cref="PhotoMaxEdge"/> px on the long edge (upright, without metadata such as GPS), with a thumbnail.
/// Adding, ordering and deleting are the doctor's (BR-AS5: AS17 shows the Info tab read-only); every clinic
/// caller and the doctor's linked patients can read them. Files are never public URLs.
/// </summary>
[ApiController]
[Route("api")]
public sealed class BranchPhotosController(AppDbContext db, IFileStorage storage, Auditor auditor, PatientContext patients) : ControllerBase
{
    /// <summary>BR-BR2: "Up to 5 photos".</summary>
    public const int MaxPhotos = 5;

    /// <summary>A photo is at most 10 MB as uploaded; what is stored is far smaller.</summary>
    public const long PhotoMaxBytes = 10 * 1024 * 1024;

    /// <summary>Sharp on a tablet held sideways, small on disk.</summary>
    public const int PhotoMaxEdge = 1600;

    /// <summary>
    /// <c>multipart/form-data</c>: <c>branchId</c> and <c>file</c>. <b>201</b> with the branch details; the new photo
    /// is the last one.
    /// </summary>
    [HttpPost("branches/uploadBranchPhoto")]
    [Clinic(DoctorOnly = true)]
    [RequestSizeLimit(PhotoMaxBytes + (512 * 1024))]
    [RequestFormLimits(MultipartBodyLengthLimit = PhotoMaxBytes + (512 * 1024))]
    public async Task<IActionResult> Upload(CancellationToken cancellationToken)
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

        if (!Guid.TryParse(form["branchId"].ToString(), out var branchId))
        {
            return ValidationProblems.Field(HttpContext, "branchId", ErrorCodes.Required, "This field is required.");
        }

        var file = form.Files.GetFile("file");
        if (file is null || file.Length == 0)
        {
            return ValidationProblems.Field(HttpContext, "file", ErrorCodes.Required, "Choose a photo.");
        }

        if (file.Length > PhotoMaxBytes)
        {
            return ValidationProblems.Field(HttpContext, "file", ErrorCodes.FileTooLarge, "The photo is larger than 10 MB.");
        }

        var header = new byte[FileTypes.SignatureLength];
        await using (var peek = file.OpenReadStream())
        {
            var read = await peek.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
            if (!FileTypes.IsImage(FileTypes.Detect(header.AsSpan(0, read))))
            {
                return ValidationProblems.Field(HttpContext, "file", ErrorCodes.FileTypeNotAllowed, "Use a JPEG, PNG or WebP photo.");
            }
        }

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await ClinicLocks.LockDoctorAsync(db, caller.DoctorId, cancellationToken);
        var branch = await db.Branches.Include(b => b.BranchPhotos)
            .SingleOrDefaultAsync(b => b.Id == branchId && b.DoctorId == caller.DoctorId, cancellationToken);
        if (branch is null)
        {
            return this.NotFoundProblem();
        }

        if (branch.BranchPhotos.Count >= MaxPhotos)
        {
            return this.ConflictProblem(ErrorCodes.BranchPhotoLimit, $"A branch has at most {MaxPhotos} photos. Delete one first.");
        }

        byte[] jpeg;
        try
        {
            await using var content = file.OpenReadStream();
            jpeg = Thumbnailer.CreateJpeg(content, PhotoMaxEdge);
        }
        catch (FileStorageException ex)
        {
            return ValidationProblems.Field(HttpContext, "file", ex.Code, ex.Message);
        }

        var photo = new BranchPhoto
        {
            Id = Guid.NewGuid(),
            BranchId = branch.Id,
            SortOrder = branch.BranchPhotos.Count == 0 ? 0 : branch.BranchPhotos.Max(p => p.SortOrder) + 1,
        };
        var path = StoragePath.BranchPhoto(caller.DoctorId, branch.Id, photo.Id);
        using (var stream = new MemoryStream(jpeg, writable: false))
        {
            await storage.SaveAsync(path, stream, FileTypes.Jpeg, cancellationToken: cancellationToken);
        }

        await storage.CreateThumbnailAsync(path, StoragePath.BranchPhotoThumbnail(caller.DoctorId, branch.Id, photo.Id), cancellationToken);
        photo.Path = path.Value;
        db.BranchPhotos.Add(photo);
        auditor.AddClinic(caller, AuditActions.BranchPhotosUpdated, AuditTargets.Branch, branch.Id,
            new { added = photo.Id, count = branch.BranchPhotos.Count + 1, sizeBytes = jpeg.Length });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, await BranchQueries.LoadDetailsAsync(db, caller, branch.Id, cancellationToken));
    }

    /// <summary><c>photoIds</c>: every photo of the branch, once each, in the new order (the first is the cover).</summary>
    [HttpPost("branches/reorderBranchPhotos")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> Reorder(ReorderBranchPhotosRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var branch = await db.Branches.Include(b => b.BranchPhotos)
            .SingleOrDefaultAsync(b => b.Id == request.BranchId && b.DoctorId == caller.DoctorId, cancellationToken);
        if (branch is null)
        {
            return this.NotFoundProblem();
        }

        var ids = request.PhotoIds!;
        if (ids.Count != branch.BranchPhotos.Count || ids.Distinct().Count() != ids.Count
            || !ids.All(id => branch.BranchPhotos.Any(p => p.Id == id)))
        {
            return ValidationProblems.Field(HttpContext, "photoIds", ErrorCodes.InvalidValue, "Send each of the branch's photos once.");
        }

        for (var i = 0; i < ids.Count; i++)
        {
            branch.BranchPhotos.Single(p => p.Id == ids[i]).SortOrder = i;
        }

        auditor.AddClinic(caller, AuditActions.BranchPhotosUpdated, AuditTargets.Branch, branch.Id, new { reordered = ids.Count });
        await db.SaveChangesAsync(cancellationToken);
        return Ok(await BranchQueries.LoadDetailsAsync(db, caller, branch.Id, cancellationToken));
    }

    [HttpPost("branches/deleteBranchPhoto")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> Delete(DeleteBranchPhotoRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var photo = await db.BranchPhotos
            .SingleOrDefaultAsync(p => p.Id == request.PhotoId && p.BranchId == request.BranchId && p.Branch.DoctorId == caller.DoctorId, cancellationToken);
        if (photo is null)
        {
            return this.NotFoundProblem();
        }

        db.BranchPhotos.Remove(photo);
        auditor.AddClinic(caller, AuditActions.BranchPhotosUpdated, AuditTargets.Branch, photo.BranchId, new { removed = photo.Id });
        await db.SaveChangesAsync(cancellationToken);
        if (StoragePath.TryParse(photo.Path, out var path))
        {
            await storage.DeleteAsync(path, CancellationToken.None);
            await storage.DeleteAsync(StoragePath.BranchPhotoThumbnail(caller.DoctorId, photo.BranchId, photo.Id), CancellationToken.None);
        }

        return Ok(await BranchQueries.LoadDetailsAsync(db, caller, photo.BranchId, cancellationToken));
    }

    /// <summary>The photo (JPEG), or its thumbnail with <c>?thumb=true</c>, for any of the doctor's clinic callers.</summary>
    [HttpGet("branches/{branchId:guid}/photos/{photoId:guid}")]
    [Clinic]
    public async Task<IActionResult> Get(Guid branchId, Guid photoId, [FromQuery] bool thumb, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        return await StreamAsync(caller.DoctorId, branchId, photoId, thumb, cancellationToken);
    }

    /// <summary>P3: the photo, or its thumbnail, for a patient linked to the doctor (spec 9.4). Archived branches' photos aren't shown.</summary>
    [HttpGet("patient/doctors/{doctorId:guid}/branches/{branchId:guid}/photos/{photoId:guid}")]
    [Authorize(Policy = Policies.Patient)]
    public async Task<IActionResult> GetForPatient(Guid doctorId, Guid branchId, Guid photoId, [FromQuery] bool thumb, CancellationToken cancellationToken)
    {
        var patientId = await patients.GetPatientIdAsync(cancellationToken);
        var linked = await db.DoctorPatients.AnyAsync(l => l.DoctorId == doctorId && l.PatientId == patientId, cancellationToken)
            && await db.Branches.AnyAsync(b => b.Id == branchId && b.DoctorId == doctorId && b.Status != BranchStatuses.Archived, cancellationToken);
        return linked ? await StreamAsync(doctorId, branchId, photoId, thumb, cancellationToken) : this.NotFoundProblem();
    }

    private async Task<IActionResult> StreamAsync(Guid doctorId, Guid branchId, Guid photoId, bool thumb, CancellationToken cancellationToken)
    {
        var stored = await db.BranchPhotos.AsNoTracking()
            .Where(p => p.Id == photoId && p.BranchId == branchId && p.Branch.DoctorId == doctorId)
            .Select(p => p.Path)
            .SingleOrDefaultAsync(cancellationToken);
        if (!StoragePath.TryParse(stored, out var path))
        {
            return this.NotFoundProblem();
        }

        var file = thumb ? StoragePath.BranchPhotoThumbnail(doctorId, branchId, photoId) : path;
        if (await storage.OpenReadAsync(file, cancellationToken) is not { } content)
        {
            return this.NotFoundProblem();
        }

        // A photo never changes once stored (a new one gets a new ID).
        Response.Headers.CacheControl = "private, max-age=86400";
        Response.Headers.XContentTypeOptions = "nosniff";
        return new FileStreamResult(content.Content, FileTypes.Jpeg);
    }
}
