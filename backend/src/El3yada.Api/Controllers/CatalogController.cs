using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Catalogs;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Notifications;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Net.Http.Headers;

namespace El3yada.Api.Controllers;

/// <summary>
/// The catalog on devices (spec 6.9, 9.5, D0): the current version, its file, admin custom items and the doctor's
/// specialty profile. Contract: backend/docs/api-phase-3-catalogs.md. Only doctors, admins and assistants with
/// <c>prescriptionsDraft</c> download it; patients never do (BR-CAT11).
/// </summary>
[ApiController]
[Route("api/catalog")]
public sealed class CatalogController(
    AppDbContext db, IFileStorage storage, NotificationWriter notifications, CatalogSizes sizes, TimeProvider time) : ControllerBase
{
    /// <summary>A sync page: devices ask again with <c>since = nextSince</c> while <c>hasMore</c>.</summary>
    public const int SyncPageSize = 1000;

    /// <summary>D0: the version to download. 404 CATALOG_NOT_PUBLISHED before the first publish.</summary>
    [HttpGet("current")]
    public async Task<IActionResult> Current(CancellationToken cancellationToken)
    {
        if (await CatalogAccess.CheckAsync(this, db, cancellationToken) is { } denied)
        {
            return denied;
        }

        var current = await CurrentVersionAsync(db, cancellationToken);
        return current is null
            ? this.Problem(StatusCodes.Status404NotFound, ErrorCodes.CatalogNotPublished, "No catalog has been published yet.")
            : Ok(ViewOf(current, await sizes.GetAsync(storage, current, cancellationToken)));
    }

    /// <summary>The <c>.sqlite.gz</c> file, with HTTP range support so D0 resumes an interrupted download.</summary>
    [HttpGet("file/{version:int}")]
    public async Task<IActionResult> File(int version, CancellationToken cancellationToken)
    {
        if (await CatalogAccess.CheckAsync(this, db, cancellationToken) is { } denied)
        {
            return denied;
        }

        var row = await db.CatalogVersions.AsNoTracking().SingleOrDefaultAsync(v => v.VersionNumber == version, cancellationToken);
        if (row is null || !StoragePath.TryParse(row.StoragePath, out var path) || await storage.OpenReadAsync(path, cancellationToken) is not { } stored)
        {
            return this.NotFoundProblem();
        }

        Response.Headers.CacheControl = "private, max-age=31536000, immutable";
        Response.Headers.XContentTypeOptions = "nosniff";
        return new FileStreamResult(stored.Content, FileTypes.Gzip)
        {
            EnableRangeProcessing = true,
            FileDownloadName = $"catalog-v{row.VersionNumber}.sqlite.gz",
            EntityTag = new EntityTagHeaderValue($"\"{row.Sha256.Trim()}\""),
        };
    }

    /// <summary>
    /// BR-CAT9 sync: custom items changed after <c>since</c> (all of them when left out), inactive ones included so
    /// devices drop them. Devices ask about once a minute while an editor is open (AC-18).
    /// </summary>
    [HttpGet("customItems")]
    public async Task<IActionResult> CustomItems([FromQuery] DateTime? since, CancellationToken cancellationToken)
    {
        if (await CatalogAccess.CheckAsync(this, db, cancellationToken) is { } denied)
        {
            return denied;
        }

        var query = db.CatalogCustomItems.AsNoTracking();
        if (since is { } from)
        {
            var utc = from.Kind == DateTimeKind.Local ? from.ToUniversalTime() : DateTime.SpecifyKind(from, DateTimeKind.Utc);
            query = query.Where(i => i.UpdatedAt > utc);
        }

        var rows = await query.OrderBy(i => i.UpdatedAt).ThenBy(i => i.Id).Take(SyncPageSize).ToListAsync(cancellationToken);
        Response.Headers.CacheControl = "no-store";
        return Ok(new CustomItemSyncView(
            rows.Select(ViewOf).ToList(),
            rows.Count > 0 ? rows[^1].UpdatedAt : since,
            rows.Count == SyncPageSize));
    }

    /// <summary>The doctor's specialty profile(s) merged with General (BR-CAT2–CAT4), for ranking search on the device.</summary>
    [HttpGet("myProfile")]
    [Clinic(ClinicPermissions.PrescriptionsDraft)]
    public async Task<IActionResult> MyProfile(CancellationToken cancellationToken) =>
        Ok(await SpecialtyProfileStore.ForDoctorAsync(db, HttpContext.Clinic().DoctorId, cancellationToken));

    /// <summary>"Report a missing or wrong item" [S] (BR-CAT8): the admins are notified (AD20).</summary>
    [HttpPost("reportCatalogItem")]
    [Clinic(DoctorOnly = true)]
    public async Task<IActionResult> Report(ReportCatalogItemRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var report = new CatalogReport
        {
            Id = Guid.NewGuid(),
            DoctorId = caller.DoctorId,
            Type = request.Type!,
            Text = request.Text!.Trim(),
            ItemRef = Text.TrimToNull(request.ItemRef),
            Status = "open",
            CreatedAt = time.GetUtcNow().UtcDateTime,
        };
        db.CatalogReports.Add(report);
        var doctorName = await db.Doctors.Where(d => d.UserId == caller.DoctorId).Select(d => d.FullName).SingleAsync(cancellationToken);
        var admins = await db.Users.Where(u => u.Role == Roles.Admin && u.Status == AccountStatuses.Active).Select(u => u.Id).ToListAsync(cancellationToken);
        foreach (var adminId in admins)
        {
            notifications.Add(adminId, NotificationTexts.CatalogReport(doctorName), "/admin/catalogs", new { reportId = report.Id });
        }

        await db.SaveChangesAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, new CatalogReportView(
            report.Id, report.Type, report.Text, report.ItemRef, report.Status, report.DoctorId, doctorName, report.CreatedAt, null, null));
    }

    public static Task<CatalogVersion?> CurrentVersionAsync(AppDbContext db, CancellationToken cancellationToken) =>
        db.AppSettings.AsNoTracking()
            .Where(s => s.CurrentCatalogVersion != null)
            .Select(s => s.CurrentCatalogVersion)
            .SingleOrDefaultAsync(cancellationToken);

    public static CatalogVersionView ViewOf(CatalogVersion v, long? uncompressedSizeBytes = null) => new(
        v.VersionNumber, v.SchemaVersion, v.Sha256.Trim(), v.SizeBytes, new CatalogCountsView(v.DrugCount, v.LabCount, v.RadiologyCount),
        v.DrugDatasetDate, v.LoincRelease, v.PublishedAt, $"/api/catalog/file/{v.VersionNumber}", uncompressedSizeBytes);

    public static CustomItemView ViewOf(CatalogCustomItem i) => new(
        i.Id, i.Type, i.NameEn, i.NameAr, i.ActiveIngredient, i.DrugGroupId, i.Route, i.LoincCode,
        i.AliasesJson is null ? [] : JsonSerializer.Deserialize<List<string>>(i.AliasesJson) ?? [], i.Active, i.CreatedAt, i.UpdatedAt);
}

/// <summary>
/// Who may read the catalog (BR-CAT11): admins; doctors whose clinic is open; assistants with
/// <c>prescriptionsDraft</c>. Patients get 403 FORBIDDEN.
/// </summary>
public static class CatalogAccess
{
    public static async Task<IActionResult?> CheckAsync(ControllerBase controller, AppDbContext db, CancellationToken cancellationToken)
    {
        var account = controller.HttpContext.Account();
        if (account.Role == Roles.Admin)
        {
            return null;
        }

        var caller = await ClinicCaller.LoadAsync(db, account.UserId, account.Role, cancellationToken);
        if (caller is null)
        {
            return controller.ForbiddenProblem(ErrorCodes.Forbidden, "The catalog is for doctors and their assistants.");
        }

        if (!DoctorStatuses.ClinicIsOpen(caller.DoctorStatus))
        {
            return controller.ForbiddenProblem(ErrorCodes.ClinicNotActive, "The clinic account is not active.");
        }

        return caller.Has(ClinicPermissions.PrescriptionsDraft) ? null : controller.PermissionDenied(ClinicPermissions.PrescriptionsDraft);
    }
}
