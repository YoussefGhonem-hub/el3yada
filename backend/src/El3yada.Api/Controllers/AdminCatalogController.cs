using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Catalogs;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// AD20 catalogs (publish a version, custom items, doctor reports) and AD19 specialty profiles. Any admin.
/// Contract: backend/docs/api-phase-3-catalogs.md.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminCatalogController(AppDbContext db, IFileStorage storage, Auditor auditor, CatalogSizes sizes, TimeProvider time)
    : ControllerBase
{
    private const long PublishRequestMaxBytes = CatalogSchema.MaxFileBytes + (1024 * 1024);

    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>
    /// spec 9.1 <c>publishCatalog</c>: <c>multipart/form-data</c> with <c>file</c> (the builder's
    /// <c>catalog-v{n}.sqlite.gz</c>), <c>manifest</c> (its <c>catalog-v{n}.json</c>) and optional
    /// <c>confirmDrop=true</c>. Checks the sha256, the schema version and the row counts (no table more than 5%
    /// smaller than the current version unless confirmed), then stores it as the next version and makes it current.
    /// Apps download it in the background and switch when it's complete (BR-CAT12).
    /// </summary>
    [HttpPost("publishCatalog")]
    [RequestSizeLimit(PublishRequestMaxBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = PublishRequestMaxBytes)]
    public async Task<IActionResult> Publish(CancellationToken cancellationToken)
    {
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
            return ValidationProblems.Field(HttpContext, "file", ErrorCodes.Required, "Choose the catalog file (.sqlite.gz).");
        }

        var manifestText = form.Files.GetFile("manifest") is { } manifestFile
            ? await new StreamReader(manifestFile.OpenReadStream()).ReadToEndAsync(cancellationToken)
            : form["manifest"].ToString();
        if (string.IsNullOrWhiteSpace(manifestText))
        {
            return ValidationProblems.Field(HttpContext, "manifest", ErrorCodes.Required, "Choose the manifest (.json) made with the file.");
        }

        string? manifestSha;
        try
        {
            using var manifest = JsonDocument.Parse(manifestText);
            manifestSha = manifest.RootElement.TryGetProperty("sha256", out var sha) ? sha.GetString()?.Trim().ToLowerInvariant() : null;
        }
        catch (JsonException)
        {
            manifestSha = null;
        }

        if (manifestSha is not { Length: 64 })
        {
            return ValidationProblems.Field(HttpContext, "manifest", ErrorCodes.InvalidRequest, "The manifest has no sha256.");
        }

        var confirmDrop = bool.TryParse(form["confirmDrop"].ToString(), out var confirm) && confirm;
        var temp = Path.Combine(Path.GetTempPath(), $"el3yada-publish-{Guid.NewGuid():N}.gz");
        try
        {
            await using (var input = file.OpenReadStream())
            await using (var copy = System.IO.File.Create(temp))
            {
                await input.CopyToAsync(copy, cancellationToken);
            }

            if (await CatalogFile.Sha256Async(temp, cancellationToken) != manifestSha)
            {
                return ValidationProblems.Field(HttpContext, "file", ErrorCodes.CatalogShaMismatch, "The file doesn't match its manifest (sha256).");
            }

            if (await CatalogFile.InspectAsync(temp, cancellationToken) is not { } info)
            {
                return ValidationProblems.Field(HttpContext, "file", ErrorCodes.CatalogFileInvalid, "This is not a catalog made by the catalog builder.");
            }

            if (info.SchemaVersion != CatalogSchema.ExpectedVersion)
            {
                return ((ObjectResult)ValidationProblems.Field(HttpContext, "file", ErrorCodes.CatalogSchemaUnsupported, "This catalog's format is not the one the apps read."))
                    .WithFields(("expected", CatalogSchema.ExpectedVersion), ("actual", info.SchemaVersion));
            }

            var previous = await CatalogController.CurrentVersionAsync(db, cancellationToken);
            if (previous is not null && !confirmDrop)
            {
                var drops = new[]
                    {
                        (Table: "drugs", Previous: previous.DrugCount, Current: info.Drugs),
                        (Table: "labs", Previous: previous.LabCount, Current: info.Labs),
                        (Table: "radiology", Previous: previous.RadiologyCount, Current: info.Radiology),
                    }
                    .Where(d => d.Current < d.Previous * (1 - CatalogSchema.AllowedDrop))
                    .Select(d => new { table = d.Table, previous = d.Previous, current = d.Current })
                    .ToList();
                if (drops.Count > 0)
                {
                    return this.ConflictProblem(ErrorCodes.CatalogCountDrop, "This version has much fewer items than the current one. Send it again with confirmDrop=true if that is intended.")
                        .WithFields(("drops", drops));
                }
            }

            var number = (await db.CatalogVersions.MaxAsync(v => (int?)v.VersionNumber, cancellationToken) ?? 0) + 1;
            var path = StoragePath.Catalog(number);
            long size;
            await using (var content = System.IO.File.OpenRead(temp))
            {
                size = (await storage.SaveAsync(path, content, FileTypes.Gzip, CatalogSchema.MaxFileBytes, cancellationToken)).SizeBytes;
            }

            var adminId = User.UserId();
            var version = new CatalogVersion
            {
                Id = Guid.NewGuid(),
                VersionNumber = number,
                SchemaVersion = info.SchemaVersion,
                StoragePath = path.Value,
                Sha256 = manifestSha,
                SizeBytes = size,
                DrugCount = info.Drugs,
                LabCount = info.Labs,
                RadiologyCount = info.Radiology,
                DrugDatasetDate = info.DrugSourceDate,
                LoincRelease = info.LoincRelease,
                PublishedAt = Now,
                PublishedBy = adminId,
            };
            try
            {
                db.CatalogVersions.Add(version);
                var settings = await db.AppSettings.SingleAsync(cancellationToken);
                settings.CurrentCatalogVersionId = version.Id;
                auditor.Add(
                    AuditActions.CatalogPublished, AuditTargets.CatalogVersion, version.Id,
                    new
                    {
                        version = number, schemaVersion = info.SchemaVersion, drugs = info.Drugs, labs = info.Labs, radiology = info.Radiology,
                        sizeBytes = size, uncompressedSizeBytes = info.UncompressedBytes, confirmedDrop = confirmDrop,
                    });
                await db.SaveChangesAsync(cancellationToken);
            }
            catch
            {
                await storage.DeleteAsync(path, CancellationToken.None);
                throw;
            }

            // Measured while checking the file: the space D0 needs on the device once it is unpacked.
            sizes.Remember(number, info.UncompressedBytes);
            return StatusCode(StatusCodes.Status201Created, CatalogController.ViewOf(version, info.UncompressedBytes));
        }
        finally
        {
            try
            {
                System.IO.File.Delete(temp);
            }
            catch (IOException)
            {
            }
        }
    }

    /// <summary>AD20 "Current version" and history, newest first. <c>current</c> marks the one apps download.</summary>
    [HttpGet("catalogVersions")]
    public async Task<IActionResult> Versions(CancellationToken cancellationToken)
    {
        var currentId = await db.AppSettings.Select(s => s.CurrentCatalogVersionId).SingleAsync(cancellationToken);
        var rows = await db.CatalogVersions.AsNoTracking()
            .OrderByDescending(v => v.VersionNumber)
            .Select(v => new { Version = v, PublishedByName = v.PublishedByNavigation.DisplayName })
            .ToListAsync(cancellationToken);
        var views = new List<CatalogVersionView>(rows.Count);
        foreach (var row in rows)
        {
            views.Add(CatalogController.ViewOf(row.Version, await sizes.GetAsync(storage, row.Version, cancellationToken)));
        }

        return Ok(rows.Select((r, i) => new
        {
            version = views[i],
            current = r.Version.Id == currentId,
            publishedBy = new { userId = r.Version.PublishedBy, displayName = r.PublishedByName },
        }));
    }

    /// <summary>AD20 custom items (BR-CAT9), newest change first.</summary>
    [HttpGet("catalog/customItems")]
    public async Task<IActionResult> CustomItems([FromQuery] CustomItemListQuery query, CancellationToken cancellationToken)
    {
        var items = db.CatalogCustomItems.AsNoTracking();
        if (query.Type is { } type)
        {
            items = items.Where(i => i.Type == type);
        }

        if (query.Active is { } active)
        {
            items = items.Where(i => i.Active == active);
        }

        if (Text.TrimToNull(query.Search) is { } search)
        {
            items = items.Where(i => i.NameEn.Contains(search) || (i.NameAr != null && i.NameAr.Contains(search))
                || (i.ActiveIngredient != null && i.ActiveIngredient.Contains(search)) || (i.LoincCode != null && i.LoincCode.Contains(search)));
        }

        var page = await items.OrderByDescending(i => i.UpdatedAt).ThenBy(i => i.Id).ToPageAsync(query, cancellationToken);
        return Ok(new PagedResult<CustomItemView>(page.Items.Select(CatalogController.ViewOf).ToList(), page.Page, page.PageSize, page.TotalCount));
    }

    [HttpPost("catalog/createCustomItem")]
    public async Task<IActionResult> CreateCustomItem(CreateCustomItemRequest request, CancellationToken cancellationToken)
    {
        var now = Now;
        var item = new CatalogCustomItem
        {
            Id = Guid.NewGuid(),
            Type = request.Type!,
            Active = true,
            CreatedBy = User.UserId(),
            CreatedAt = now,
        };
        Apply(item, request.NameEn, request.NameAr, request.ActiveIngredient, request.DrugGroupId, request.Route, request.LoincCode, request.Aliases, now);
        db.CatalogCustomItems.Add(item);
        auditor.Add(AuditActions.CatalogCustomItemSaved, AuditTargets.CatalogCustomItem, item.Id, new { type = item.Type, created = true, active = true });
        await db.SaveChangesAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, CatalogController.ViewOf(item));
    }

    /// <summary>Every field replaced; <c>active: false</c> disables it on every device at the next sync.</summary>
    [HttpPost("catalog/updateCustomItem")]
    public async Task<IActionResult> UpdateCustomItem(UpdateCustomItemRequest request, CancellationToken cancellationToken)
    {
        var item = await db.CatalogCustomItems.SingleOrDefaultAsync(i => i.Id == request.CustomItemId, cancellationToken);
        if (item is null)
        {
            return this.NotFoundProblem();
        }

        var drug = item.Type == CatalogItemTypes.Drug;
        foreach (var (field, value, drugOnly) in new[]
        {
            ("activeIngredient", request.ActiveIngredient, true), ("drugGroupId", request.DrugGroupId, true),
            ("route", request.Route, true), ("loincCode", request.LoincCode, false),
        })
        {
            if (value is not null && drugOnly != drug)
            {
                return ValidationProblems.Field(HttpContext, field, ErrorCodes.InvalidValue, drugOnly ? "Only for medicines." : "Only for tests.");
            }
        }

        Apply(item, request.NameEn, request.NameAr, request.ActiveIngredient, request.DrugGroupId, request.Route, request.LoincCode, request.Aliases, Now);
        item.Active = request.Active!.Value;
        auditor.Add(AuditActions.CatalogCustomItemSaved, AuditTargets.CatalogCustomItem, item.Id, new { type = item.Type, created = false, active = item.Active });
        await db.SaveChangesAsync(cancellationToken);
        return Ok(CatalogController.ViewOf(item));
    }

    /// <summary>AD20 "Doctor reports" [S]: open ones first in the queue order.</summary>
    [HttpGet("catalog/reports")]
    public async Task<IActionResult> Reports([FromQuery] CatalogReportListQuery query, CancellationToken cancellationToken)
    {
        var reports = db.CatalogReports.AsNoTracking();
        if (query.Status != "all")
        {
            reports = reports.Where(r => r.Status == query.Status);
        }

        var page = await reports
            .OrderBy(r => r.Status == "open" ? 0 : 1).ThenBy(r => r.CreatedAt)
            .Select(r => new CatalogReportView(
                r.Id, r.Type, r.Text, r.ItemRef, r.Status, r.DoctorId, r.Doctor.FullName, r.CreatedAt, r.HandledBy, r.HandledAt))
            .ToPageAsync(query, cancellationToken);
        return Ok(page);
    }

    [HttpPost("catalog/handleReport")]
    public async Task<IActionResult> HandleReport(HandleReportRequest request, CancellationToken cancellationToken)
    {
        var report = await db.CatalogReports.Include(r => r.Doctor).SingleOrDefaultAsync(r => r.Id == request.ReportId, cancellationToken);
        if (report is null)
        {
            return this.NotFoundProblem();
        }

        if (report.Status != "done")
        {
            report.Status = "done";
            report.HandledBy = User.UserId();
            report.HandledAt = Now;
            auditor.Add(AuditActions.CatalogReportHandled, AuditTargets.CatalogReport, report.Id, new { type = report.Type }, doctorId: report.DoctorId);
            await db.SaveChangesAsync(cancellationToken);
        }

        return Ok(new CatalogReportView(
            report.Id, report.Type, report.Text, report.ItemRef, report.Status, report.DoctorId, report.Doctor.FullName,
            report.CreatedAt, report.HandledBy, report.HandledAt));
    }

    /// <summary>AD19: every specialty (General included), with the number of doctors in it and its profile size.</summary>
    [HttpGet("specialties")]
    public async Task<IActionResult> Specialties(CancellationToken cancellationToken)
    {
        var rows = await db.Specialties.AsNoTracking()
            .OrderBy(s => s.NameEn == SpecialtyProfiles.GeneralNameEn ? 0 : 1).ThenBy(s => s.SortOrder).ThenBy(s => s.NameAr)
            .Select(s => new
            {
                Specialty = s,
                Doctors = db.Doctors.Count(d => d.SpecialtyId == s.Id || d.Specialties.Any(x => x.Id == s.Id)),
                Items = s.SpecialtyProfileItems.GroupBy(i => i.ItemType).Select(g => new { Type = g.Key, Count = g.Count() }).ToList(),
            })
            .ToListAsync(cancellationToken);
        return Ok(rows.Select(r =>
        {
            var general = r.Specialty.NameEn == SpecialtyProfiles.GeneralNameEn;
            return new SpecialtyListItem(
                r.Specialty.Id, r.Specialty.NameAr, r.Specialty.NameEn, r.Specialty.Active, r.Specialty.SortOrder, general,
                !general && r.Specialty.IncludeGeneral, r.Doctors,
                SpecialtyProfiles.ItemTypes.ToDictionary(t => t, t => r.Items.FirstOrDefault(i => i.Type == t)?.Count ?? 0));
        }).ToList());
    }

    [HttpGet("specialties/{specialtyId:guid}/profile")]
    public async Task<IActionResult> Profile(Guid specialtyId, CancellationToken cancellationToken) =>
        await SpecialtyProfileStore.ViewAsync(db, specialtyId, cancellationToken) is { } view ? Ok(view) : this.NotFoundProblem();

    /// <summary>AD19 editor: every list replaced.</summary>
    [HttpPut("specialties/{specialtyId:guid}/profile")]
    public async Task<IActionResult> UpdateProfile(Guid specialtyId, SpecialtyProfileRequest request, CancellationToken cancellationToken)
    {
        var specialty = await db.Specialties.SingleOrDefaultAsync(s => s.Id == specialtyId, cancellationToken);
        if (specialty is null)
        {
            return this.NotFoundProblem();
        }

        var items = SpecialtyProfileStore.ItemsOf(request).ToList();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await SpecialtyProfileStore.ReplaceAsync(db, specialty.Id, items, cancellationToken);
        specialty.IncludeGeneral = specialty.NameEn != SpecialtyProfiles.GeneralNameEn && request.IncludeGeneral!.Value;
        specialty.UpdatedAt = Now;
        auditor.Add(
            AuditActions.SpecialtyProfileUpdated, AuditTargets.Specialty, specialty.Id,
            new { includeGeneral = specialty.IncludeGeneral, counts = items.GroupBy(i => i.Type).ToDictionary(g => g.Key, g => g.Count()) });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Ok(await SpecialtyProfileStore.ViewAsync(db, specialty.Id, cancellationToken));
    }

    /// <summary>AD19 "Copy from another specialty": the source's lists and its includeGeneral replace this one's.</summary>
    [HttpPost("specialties/{specialtyId:guid}/copyProfile")]
    public async Task<IActionResult> CopyProfile(Guid specialtyId, CopyProfileRequest request, CancellationToken cancellationToken)
    {
        var specialty = await db.Specialties.SingleOrDefaultAsync(s => s.Id == specialtyId, cancellationToken);
        var source = await db.Specialties.AsNoTracking().SingleOrDefaultAsync(s => s.Id == request.FromSpecialtyId, cancellationToken);
        if (specialty is null)
        {
            return this.NotFoundProblem();
        }

        if (source is null || source.Id == specialty.Id)
        {
            return ValidationProblems.Field(HttpContext, "fromSpecialtyId", ErrorCodes.InvalidValue, "Pick another specialty.");
        }

        var items = await db.SpecialtyProfileItems.AsNoTracking()
            .Where(i => i.SpecialtyId == source.Id)
            .Select(i => new { i.ItemType, i.Value })
            .ToListAsync(cancellationToken);
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await SpecialtyProfileStore.ReplaceAsync(db, specialty.Id, items.Select(i => (i.ItemType, i.Value)), cancellationToken);
        specialty.IncludeGeneral = specialty.NameEn != SpecialtyProfiles.GeneralNameEn
            && (source.NameEn == SpecialtyProfiles.GeneralNameEn || source.IncludeGeneral);
        specialty.UpdatedAt = Now;
        auditor.Add(
            AuditActions.SpecialtyProfileUpdated, AuditTargets.Specialty, specialty.Id,
            new { includeGeneral = specialty.IncludeGeneral, copiedFrom = source.Id, items = items.Count });
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return Ok(await SpecialtyProfileStore.ViewAsync(db, specialty.Id, cancellationToken));
    }

    private static void Apply(
        CatalogCustomItem item, string? nameEn, string? nameAr, string? ingredient, string? group, string? route, string? loinc,
        IReadOnlyList<string>? aliases, DateTime now)
    {
        item.NameEn = Text.CollapseSpaces(nameEn!);
        item.NameAr = Text.TrimToNull(nameAr) is { } ar ? Text.CollapseSpaces(ar) : null;
        item.ActiveIngredient = Text.TrimToNull(ingredient);
        item.DrugGroupId = Text.TrimToNull(group);
        item.Route = Text.TrimToNull(route);
        item.LoincCode = Text.TrimToNull(loinc);
        var cleaned = (aliases ?? []).Select(a => Text.CollapseSpaces(a)).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        item.AliasesJson = cleaned.Count == 0 ? null : JsonSerializer.Serialize(cleaned);
        item.UpdatedAt = now;
    }
}
