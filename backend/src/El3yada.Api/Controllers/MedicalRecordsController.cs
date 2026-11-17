using System.IO.Compression;
using System.Text.RegularExpressions;
using El3yada.Api.Audit;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Api.Patients;
using El3yada.Api.Records;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.EntityFrameworkCore;
using Microsoft.Net.Http.Headers;

namespace El3yada.Api.Controllers;

/// <summary>
/// Medical files (spec 6.3, D10–D12, AS6). Contract: backend/docs/api-phase-3-files.md. A file is uploaded on its
/// own first (<c>uploadFile</c>: checked, optimized, kept 24 hours), then claimed by <c>createRecord</c>, so each
/// file has its own progress and retry. Doctor, or an assistant with <c>filesManage</c>; only the doctor deletes.
/// </summary>
[ApiController]
[Route("api")]
[Clinic]
public sealed partial class MedicalRecordsController(
    AppDbContext db, IFileStorage storage, Auditor auditor, NotificationWriter notifications, TimeProvider time,
    ILogger<MedicalRecordsController> logger) : ControllerBase
{
    /// <summary>The admin's limit is at most 200 MB (AppSettings.MaxUploadMb), plus the thumbnail and the form.</summary>
    private const long UploadRequestMaxBytes = (200L + 3) * 1024 * 1024;

    private static readonly FileExtensionContentTypeProvider ContentTypes = new();

    [GeneratedRegex(@"^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*\z", RegexOptions.CultureInvariant)]
    private static partial Regex MimePattern();

    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>D10/D11 step 1: one file, checked and optimized, kept for createRecord.</summary>
    [HttpPost("records/uploadFile")]
    [Clinic(ClinicPermissions.FilesManage, BlockedWhileSuspended = true)]
    [RequestSizeLimit(UploadRequestMaxBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = UploadRequestMaxBytes)]
    public async Task<IActionResult> UploadFile(CancellationToken cancellationToken)
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

        var file = form.Files.GetFile("file");
        if (file is null || file.Length == 0)
        {
            return ValidationProblems.Field(HttpContext, "file", ErrorCodes.Required, "Choose a file.");
        }

        var maxMb = await db.AppSettings.Select(s => s.MaxUploadMb).SingleAsync(cancellationToken);
        if (file.Length > maxMb * 1024L * 1024L)
        {
            return ((ObjectResult)ValidationProblems.Field(HttpContext, "file", ErrorCodes.FileTooLarge, $"The file is larger than {maxMb} MB."))
                .WithFields(("maxMb", maxMb));
        }

        int? pageCount = null;
        if (form["pageCount"].ToString() is { Length: > 0 } pages)
        {
            if (!int.TryParse(pages, out var count) || count < 1 || count > RecordLimits.MaxPageCount)
            {
                return ValidationProblems.Field(HttpContext, "pageCount", ErrorCodes.OutOfRange, $"From 1 to {RecordLimits.MaxPageCount}.");
            }

            pageCount = count;
        }

        var thumbnail = form.Files.GetFile("thumbnail");
        if (thumbnail is not null)
        {
            if (thumbnail.Length > RecordLimits.ThumbnailMaxBytes)
            {
                return ValidationProblems.Field(HttpContext, "thumbnail", ErrorCodes.FileTooLarge, "The thumbnail is larger than 2 MB.");
            }

            if (!FileTypes.IsImage(await DetectAsync(thumbnail, cancellationToken)))
            {
                return ValidationProblems.Field(HttpContext, "thumbnail", ErrorCodes.FileTypeNotAllowed, "The thumbnail must be a JPEG or PNG image.");
            }
        }

        var detected = await DetectAsync(file, cancellationToken);
        var fileName = CleanFileName(file.FileName);
        var mimeType = detected ?? MimeTypeOf(file.ContentType, fileName);

        var source = Path.Combine(Path.GetTempPath(), $"el3yada-upload-{Guid.NewGuid():N}.tmp");
        var uploadId = Guid.NewGuid();
        StoragePath? path = null;
        StoragePath? thumbPath = null;
        try
        {
            await using (var input = file.OpenReadStream())
            await using (var copy = new FileStream(source, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, FileOptions.Asynchronous))
            {
                await input.CopyToAsync(copy, cancellationToken);
            }

            await using var optimized = await FileOptimizer.OptimizeAsync(source, detected, mimeType, fileName, cancellationToken);
            if (optimized.MimeType == FileTypes.Jpeg && detected is FileTypes.Png or FileTypes.Webp)
            {
                fileName = Path.ChangeExtension(fileName, ".jpg");
            }

            path = StoragePath.PendingUpload(caller.DoctorId, uploadId, optimized.StoredType);
            await storage.SaveAsync(path, optimized.Content, optimized.StoredType, cancellationToken: cancellationToken);

            thumbPath = StoragePath.PendingUploadThumbnail(caller.DoctorId, uploadId);
            if (FileTypes.IsImage(optimized.StoredType))
            {
                await storage.CreateThumbnailAsync(path, thumbPath, cancellationToken);
            }
            else if (thumbnail is not null && optimized.StoredType == FileTypes.Pdf)
            {
                try
                {
                    await using var thumbStream = thumbnail.OpenReadStream();
                    await storage.SaveThumbnailAsync(thumbStream, thumbPath, cancellationToken);
                }
                catch (FileStorageException ex)
                {
                    await DeleteQuietlyAsync(path, thumbPath);
                    return ValidationProblems.Field(HttpContext, "thumbnail", ex.Code, ex.Message);
                }
            }
            else
            {
                thumbPath = null;
            }

            var now = Now;
            var upload = new PendingUpload
            {
                Id = uploadId,
                DoctorId = caller.DoctorId,
                UploadedBy = caller.UserId,
                Path = path.Value,
                ThumbPath = thumbPath?.Value,
                FileName = fileName,
                MimeType = optimized.MimeType,
                SizeBytes = optimized.SizeBytes,
                StoredSizeBytes = optimized.StoredSizeBytes,
                OriginalSizeBytes = file.Length,
                PageCount = optimized.StoredType == FileTypes.Pdf ? pageCount : null,
                CreatedAt = now,
                ExpiresAt = now + RecordLimits.UploadLifetime,
            };
            db.PendingUploads.Add(upload);
            await db.SaveChangesAsync(cancellationToken);
            logger.LogInformation(
                "Upload {UploadId}: {OriginalBytes} → {StoredBytes} bytes stored", uploadId, file.Length, optimized.StoredSizeBytes);

            Response.Headers.CacheControl = "no-store";
            return StatusCode(StatusCodes.Status201Created, new UploadView(
                uploadId, fileName, upload.MimeType, upload.SizeBytes, upload.StoredSizeBytes, upload.OriginalSizeBytes,
                upload.PageCount, thumbPath is not null, optimized.Optimized, upload.ExpiresAt));
        }
        catch (FileStorageException ex)
        {
            await DeleteQuietlyAsync(path, thumbPath);
            return ValidationProblems.Field(HttpContext, "file", ex.Code, ex.Message);
        }
        catch
        {
            await DeleteQuietlyAsync(path, thumbPath);
            throw;
        }
        finally
        {
            try
            {
                System.IO.File.Delete(source);
            }
            catch (IOException)
            {
            }
        }
    }

    /// <summary>D10/D11 step 2: the record, with the pending uploads as its attachments (in the order sent).</summary>
    [HttpPost("records/createRecord")]
    [Clinic(ClinicPermissions.FilesManage, BlockedWhileSuspended = true)]
    public async Task<IActionResult> CreateRecord(CreateRecordRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var patientId = request.PatientId!.Value;
        if (!await PatientLinks.ExistsAsync(db, caller.DoctorId, patientId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        if (request.SessionId is { } sessionId && !await SessionBelongsAsync(caller.DoctorId, patientId, sessionId, cancellationToken))
        {
            return ValidationProblems.Field(HttpContext, "sessionId", ErrorCodes.InvalidSession, "Pick one of this patient's visits.");
        }

        var now = Now;
        var ids = request.UploadIds!;
        var uploads = await db.PendingUploads
            .Where(u => ids.Contains(u.Id) && u.DoctorId == caller.DoctorId && u.ExpiresAt > now)
            .ToDictionaryAsync(u => u.Id, cancellationToken);
        if (ids.FirstOrDefault(id => !uploads.ContainsKey(id)) is var missing && missing != Guid.Empty)
        {
            return ((ObjectResult)ValidationProblems.Field(HttpContext, "uploadIds", ErrorCodes.UploadNotFound, "This file is no longer waiting. Upload it again."))
                .WithFields(("uploadId", missing));
        }

        var doctor = await db.Doctors.Where(d => d.UserId == caller.DoctorId)
            .Select(d => new { d.FullName, d.FullNameEn, d.User.Locale })
            .SingleAsync(cancellationToken);
        var record = new MedicalRecord
        {
            Id = Guid.NewGuid(),
            DoctorId = caller.DoctorId,
            PatientId = patientId,
            CreatedBy = caller.UserId,
            CreatedByRole = caller.Role,
            Source = request.Source!,
            CreatedAt = now,
            UpdatedAt = now,
        };
        Apply(record, request, request.SessionId, doctor.Locale);

        var moved = new List<(StoragePath From, StoragePath To)>();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            db.MedicalRecords.Add(record);
            var order = 0;
            foreach (var id in ids)
            {
                var upload = uploads[id];
                var attachmentId = Guid.NewGuid();
                var from = StoragePath.Parse(upload.Path);
                var to = StoragePath.MedicalAttachment(caller.DoctorId, patientId, record.Id, attachmentId, from.ContentType);
                StoragePath? thumbTo = null;
                if (upload.ThumbPath is not null)
                {
                    var thumbFrom = StoragePath.Parse(upload.ThumbPath);
                    thumbTo = StoragePath.MedicalAttachmentThumbnail(caller.DoctorId, patientId, record.Id, attachmentId);
                    if (await storage.MoveAsync(thumbFrom, thumbTo, cancellationToken))
                    {
                        moved.Add((thumbFrom, thumbTo));
                    }
                    else
                    {
                        thumbTo = null;
                    }
                }

                if (!await storage.MoveAsync(from, to, cancellationToken))
                {
                    throw new InvalidOperationException($"Pending upload {id} has no file.");
                }

                moved.Add((from, to));
                db.MedicalRecordAttachments.Add(new MedicalRecordAttachment
                {
                    Id = attachmentId,
                    RecordId = record.Id,
                    Path = to.Value,
                    ThumbPath = thumbTo?.Value,
                    FileName = upload.FileName,
                    MimeType = upload.MimeType,
                    SizeBytes = upload.SizeBytes,
                    StoredSizeBytes = upload.StoredSizeBytes,
                    PageCount = upload.PageCount,
                    SortOrder = order++,
                });
                db.PendingUploads.Remove(upload);
            }

            var patientUserId = await db.Patients.Where(p => p.Id == patientId).Select(p => p.UserId).SingleAsync(cancellationToken);
            notifications.Add(
                patientUserId,
                NotificationTexts.MedicalRecordAdded(record.Category, doctor.FullName, doctor.FullNameEn ?? doctor.FullName),
                $"/files/{record.Id}",
                new { recordId = record.Id, doctorId = caller.DoctorId });
            auditor.AddClinic(
                caller, AuditActions.MedicalRecordCreated, AuditTargets.MedicalRecord, record.Id,
                new { category = record.Category, source = record.Source, attachments = ids.Count, sizeBytes = uploads.Values.Sum(u => u.SizeBytes) },
                patientId);
            await db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch
        {
            // Put the files back, so the uploads can be claimed again.
            foreach (var (from, to) in moved)
            {
                await storage.MoveAsync(to, from, CancellationToken.None);
            }

            throw;
        }

        var view = await LoadViewAsync(caller.DoctorId, record.Id, cancellationToken);
        return StatusCode(StatusCodes.Status201Created, view);
    }

    /// <summary>D6 Files tab and AS6: newest first, with the counts for the category chips.</summary>
    [HttpGet("patients/{patientId:guid}/records")]
    [Clinic(ClinicPermissions.FilesManage)]
    public async Task<IActionResult> List(Guid patientId, [FromQuery] RecordListQuery query, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        if (!await PatientLinks.ExistsAsync(db, caller.DoctorId, patientId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var records = db.MedicalRecords.AsNoTracking()
            .Where(r => r.DoctorId == caller.DoctorId && r.PatientId == patientId && !r.Deleted);
        var counts = await records.GroupBy(r => r.Category)
            .Select(g => new { Category = g.Key, Count = g.Count() })
            .ToDictionaryAsync(g => g.Category, g => g.Count, cancellationToken);
        if (query.Category is { } category)
        {
            records = records.Where(r => r.Category == category);
        }

        var total = await records.CountAsync(cancellationToken);
        var pageIds = await records
            .OrderByDescending(r => r.DocumentDate).ThenByDescending(r => r.CreatedAt).ThenByDescending(r => r.Id)
            .Skip((query.Page - 1) * query.PageSize).Take(query.PageSize)
            .Select(r => r.Id)
            .ToListAsync(cancellationToken);
        var views = await LoadViewsAsync(caller.DoctorId, pageIds, cancellationToken);

        return Ok(new RecordPageView(
            pageIds.Select(id => views[id]).ToList(), query.Page, query.PageSize, total,
            new RecordCountsView(
                counts.GetValueOrDefault(RecordCategories.Radiology), counts.GetValueOrDefault(RecordCategories.Lab),
                counts.GetValueOrDefault(RecordCategories.Prescription), counts.GetValueOrDefault(RecordCategories.Other))));
    }

    /// <summary>D12.</summary>
    [HttpGet("records/{recordId:guid}")]
    [Clinic(ClinicPermissions.FilesManage)]
    public async Task<IActionResult> Get(Guid recordId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var view = await LoadViewAsync(caller.DoctorId, recordId, cancellationToken);
        return view is null ? this.NotFoundProblem() : Ok(view);
    }

    /// <summary>The original bytes (decompressed when stored gzip-compressed), inline or as a download.</summary>
    [HttpGet("records/{recordId:guid}/attachments/{attachmentId:guid}")]
    [Clinic(ClinicPermissions.FilesManage)]
    public async Task<IActionResult> Download(Guid recordId, Guid attachmentId, [FromQuery] bool download, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var attachment = await FindAttachmentAsync(caller.DoctorId, recordId, attachmentId, cancellationToken);
        if (attachment is null || !StoragePath.TryParse(attachment.Path, out var path)
            || await storage.OpenReadAsync(path, cancellationToken) is not { } stored)
        {
            return this.NotFoundProblem();
        }

        var content = path.ContentType == FileTypes.Gzip
            ? new GZipStream(stored.Content, CompressionMode.Decompress)
            : stored.Content;
        var disposition = new ContentDispositionHeaderValue(download ? "attachment" : "inline");
        disposition.SetHttpFileName(attachment.FileName);
        Response.Headers.ContentDisposition = disposition.ToString();
        Response.Headers.CacheControl = "private, no-store";
        Response.Headers.XContentTypeOptions = "nosniff";
        Response.ContentLength = attachment.SizeBytes;
        return new FileStreamResult(content, attachment.MimeType);
    }

    [HttpGet("records/{recordId:guid}/attachments/{attachmentId:guid}/thumbnail")]
    [Clinic(ClinicPermissions.FilesManage)]
    public async Task<IActionResult> Thumbnail(Guid recordId, Guid attachmentId, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var attachment = await FindAttachmentAsync(caller.DoctorId, recordId, attachmentId, cancellationToken);
        if (attachment?.ThumbPath is null || !StoragePath.TryParse(attachment.ThumbPath, out var path)
            || await storage.OpenReadAsync(path, cancellationToken) is not { } stored)
        {
            return this.NotFoundProblem();
        }

        Response.Headers.CacheControl = "private, max-age=86400";
        Response.Headers.XContentTypeOptions = "nosniff";
        return new FileStreamResult(stored.Content, FileTypes.Jpeg);
    }

    /// <summary>D12 "edit details" and "change category": every field replaced.</summary>
    [HttpPost("records/updateRecord")]
    [Clinic(ClinicPermissions.FilesManage, BlockedWhileSuspended = true)]
    public async Task<IActionResult> UpdateRecord(UpdateRecordRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var record = await db.MedicalRecords
            .SingleOrDefaultAsync(r => r.Id == request.RecordId && r.DoctorId == caller.DoctorId && !r.Deleted, cancellationToken);
        if (record is null)
        {
            return this.NotFoundProblem();
        }

        if (request.SessionId is { } sessionId && !await SessionBelongsAsync(caller.DoctorId, record.PatientId, sessionId, cancellationToken))
        {
            return ValidationProblems.Field(HttpContext, "sessionId", ErrorCodes.InvalidSession, "Pick one of this patient's visits.");
        }

        var locale = await db.Users.Where(u => u.Id == caller.DoctorId).Select(u => u.Locale).SingleAsync(cancellationToken);
        var before = new { record.Category, record.OtherType, record.OtherTypeText, record.Title, record.DocumentDate, record.Notes, record.SessionId };
        Apply(record, request, request.SessionId, locale);
        var after = new { record.Category, record.OtherType, record.OtherTypeText, record.Title, record.DocumentDate, record.Notes, record.SessionId };
        var fields = Changed(before, after);
        if (fields.Count > 0)
        {
            record.UpdatedAt = Now;
            auditor.AddClinic(
                caller, AuditActions.MedicalRecordUpdated, AuditTargets.MedicalRecord, record.Id,
                new { fields, category = record.Category }, record.PatientId);
            await db.SaveChangesAsync(cancellationToken);
        }

        return Ok(await LoadViewAsync(caller.DoctorId, record.Id, cancellationToken));
    }

    /// <summary>D12 Delete: soft (the files stay for the audit trail). Doctor only (6.10).</summary>
    [HttpPost("records/deleteRecord")]
    [Clinic(DoctorOnly = true, BlockedWhileSuspended = true)]
    public async Task<IActionResult> DeleteRecord(DeleteRecordRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var record = await db.MedicalRecords
            .SingleOrDefaultAsync(r => r.Id == request.RecordId && r.DoctorId == caller.DoctorId && !r.Deleted, cancellationToken);
        if (record is null)
        {
            return this.NotFoundProblem();
        }

        var now = Now;
        record.Deleted = true;
        record.DeletedAt = now;
        record.DeletedBy = caller.UserId;
        record.UpdatedAt = now;
        auditor.AddClinic(
            caller, AuditActions.MedicalRecordDeleted, AuditTargets.MedicalRecord, record.Id,
            new { category = record.Category }, record.PatientId);
        await db.SaveChangesAsync(cancellationToken);
        return NoContent();
    }

    private static List<string> Changed(object before, object after)
    {
        var fields = new List<string>();
        foreach (var property in before.GetType().GetProperties())
        {
            if (!Equals(property.GetValue(before), after.GetType().GetProperty(property.Name)!.GetValue(after)))
            {
                fields.Add(char.ToLowerInvariant(property.Name[0]) + property.Name[1..]);
            }
        }

        return fields;
    }

    /// <summary>The BR-F3 fields. An empty title becomes the category (or the Other type) and the date.</summary>
    private void Apply(MedicalRecord record, IRecordFields input, Guid? sessionId, string locale)
    {
        record.Category = input.Category!;
        record.OtherType = input.Category == RecordCategories.Other ? input.OtherType : null;
        record.OtherTypeText = record.OtherType == RecordOtherTypes.Custom ? Text.CollapseSpaces(input.OtherTypeText!) : null;
        record.DocumentDate = input.DocumentDate ?? CairoTime.Today(time);
        record.Notes = Text.TrimToNull(input.Notes);
        record.SessionId = sessionId;
        record.Title = Text.TrimToNull(input.Title) is { } title ? Text.CollapseSpaces(title) : DefaultTitle(record, locale);
    }

    private static string DefaultTitle(MedicalRecord record, string locale)
    {
        var arabic = locale != "en";
        var name = record.OtherTypeText
            ?? (arabic ? RecordOtherTypes.NameAr(record.OtherType) : RecordOtherTypes.NameEn(record.OtherType))
            ?? (arabic ? RecordCategories.NameAr(record.Category) : RecordCategories.NameEn(record.Category));
        return $"{name} {record.DocumentDate:yyyy-MM-dd}";
    }

    private Task<bool> SessionBelongsAsync(Guid doctorId, Guid patientId, Guid sessionId, CancellationToken cancellationToken) =>
        db.Sessions.AnyAsync(s => s.Id == sessionId && s.DoctorId == doctorId && s.PatientId == patientId && !s.Deleted, cancellationToken);

    private Task<MedicalRecordAttachment?> FindAttachmentAsync(Guid doctorId, Guid recordId, Guid attachmentId, CancellationToken cancellationToken) =>
        db.MedicalRecordAttachments.AsNoTracking()
            .SingleOrDefaultAsync(
                a => a.Id == attachmentId && a.RecordId == recordId && a.Record.DoctorId == doctorId && !a.Record.Deleted,
                cancellationToken);

    private async Task<RecordView?> LoadViewAsync(Guid doctorId, Guid recordId, CancellationToken cancellationToken) =>
        (await LoadViewsAsync(doctorId, [recordId], cancellationToken)).GetValueOrDefault(recordId);

    private async Task<Dictionary<Guid, RecordView>> LoadViewsAsync(Guid doctorId, IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken)
    {
        if (ids.Count == 0)
        {
            return [];
        }

        var rows = await db.MedicalRecords.AsNoTracking()
            .Where(r => ids.Contains(r.Id) && r.DoctorId == doctorId && !r.Deleted)
            .Select(r => new
            {
                Record = r,
                Session = r.Session == null || r.Session.Deleted ? null : new RecordSessionView(r.Session.Id, r.Session.Type, r.Session.CreatedAt),
                CreatorName = r.CreatedByNavigation.DisplayName,
                Attachments = r.MedicalRecordAttachments.OrderBy(a => a.SortOrder).ToList(),
            })
            .ToListAsync(cancellationToken);
        return rows.ToDictionary(
            row => row.Record.Id,
            row => new RecordView(
                row.Record.Id, row.Record.PatientId, row.Record.Category, row.Record.OtherType, row.Record.OtherTypeText,
                row.Record.Title, row.Record.DocumentDate, row.Record.Notes, row.Session, row.Record.Source,
                row.Record.CreatedAt, row.Record.UpdatedAt,
                new RecordCreatorView(row.Record.CreatedBy, row.Record.CreatedByRole, row.CreatorName),
                row.Attachments.Select(a => new AttachmentView(
                    a.Id, a.FileName, a.MimeType, a.SizeBytes, a.StoredSizeBytes, a.PageCount, a.ThumbPath is not null,
                    Previewable: FileTypes.IsImage(a.MimeType) || a.MimeType == FileTypes.Pdf)).ToList(),
                row.Attachments.Sum(a => a.SizeBytes)));
    }

    private static async Task<string?> DetectAsync(IFormFile file, CancellationToken cancellationToken)
    {
        var header = new byte[FileTypes.SignatureLength];
        await using var stream = file.OpenReadStream();
        var read = await stream.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
        return FileTypes.Detect(header.AsSpan(0, read));
    }

    /// <summary>The part's type when it is a real type, else the type its extension names, else octet-stream.</summary>
    private static string MimeTypeOf(string? partType, string fileName)
    {
        var type = partType?.Split(';', 2)[0].Trim().ToLowerInvariant();
        if (type is { Length: > 0 and <= 100 } && type != FileTypes.Binary && MimePattern().IsMatch(type))
        {
            return type;
        }

        if (!ContentTypes.TryGetContentType(fileName, out var byExtension) || byExtension.Length > 100)
        {
            return FileTypes.Binary;
        }

        // The registered names, not the old Windows ones.
        return byExtension switch
        {
            "application/x-zip-compressed" => "application/zip",
            "application/x-gzip" => "application/gzip",
            _ => byExtension,
        };
    }

    /// <summary>The name to show: no folders, no control characters, at most 255 characters.</summary>
    private static string CleanFileName(string? name)
    {
        var clean = new string(Path.GetFileName(name ?? "").Where(c => !char.IsControl(c)).ToArray()).Trim();
        if (clean.Length == 0)
        {
            return "file";
        }

        if (clean.Length > 255)
        {
            var extension = Path.GetExtension(clean);
            clean = clean[..(255 - Math.Min(extension.Length, 20))] + extension[..Math.Min(extension.Length, 20)];
        }

        return clean;
    }

    private async Task DeleteQuietlyAsync(params StoragePath?[] paths)
    {
        foreach (var path in paths)
        {
            if (path is not null)
            {
                await storage.DeleteAsync(path, CancellationToken.None);
            }
        }
    }
}
