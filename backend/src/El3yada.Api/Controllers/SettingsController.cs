using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Settings;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// AD13 <c>updateSettings</c>: send only the fields to change, by their names in <see cref="SettingFields"/>,
/// for example <c>{ "examFeePiasters": 4000, "supportEmail": null }</c>. Null or "" clears an optional text.
/// </summary>
public sealed class UpdateSettingsRequest
{
    [JsonExtensionData]
    public Dictionary<string, JsonElement>? Fields { get; set; }
}

public sealed class UpdateSettingsRequestValidator : AbstractValidator<UpdateSettingsRequest>
{
    public UpdateSettingsRequestValidator() => RuleFor(x => x).Custom((request, context) =>
    {
        if (request.Fields is not { Count: > 0 })
        {
            context.AddFailure(new FluentValidation.Results.ValidationFailure("body", "Send at least one setting.")
            {
                ErrorCode = ErrorCodes.Required,
            });
            return;
        }

        foreach (var (name, value) in request.Fields)
        {
            if (!SettingFields.ByName.TryGetValue(name, out var field))
            {
                context.AddFailure(new FluentValidation.Results.ValidationFailure(name, "Unknown setting.") { ErrorCode = ErrorCodes.UnknownSetting });
                continue;
            }

            var (_, code, message) = field.Parse(value);
            if (code is not null)
            {
                context.AddFailure(new FluentValidation.Results.ValidationFailure(name, message) { ErrorCode = code });
            }
        }
    });
}

public sealed class SettingsHistoryQuery : IPagedQuery
{
    /// <summary>One setting's history (a name from updateSettings), or every setting.</summary>
    public string? Field { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class SettingsHistoryQueryValidator : AbstractValidator<SettingsHistoryQuery>
{
    public SettingsHistoryQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Field).Must(field => field is null || SettingFields.ByName.ContainsKey(field))
            .WithErrorCode(ErrorCodes.UnknownSetting).WithMessage("Unknown setting.");
    }
}

public sealed record SettingsHistoryItem(
    Guid Id, string Field, string? Before, string? After, bool Truncated, Guid ChangedBy, string ChangedByName, DateTime ChangedAt);

/// <summary>Platform settings for admins (AD13), with a SettingsHistory row for every changed field.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminSettingsController(AppDbContext db, Auditor auditor, TimeProvider time) : ControllerBase
{
    /// <summary>History values longer than this are cut in the list; GET settingsHistory/{id} has the full text.</summary>
    private const int ListValueLength = 300;

    [HttpGet("settings")]
    public async Task<IActionResult> GetSettings(CancellationToken cancellationToken) =>
        Ok(await ViewAsync(await db.AppSettings.AsNoTracking().SingleAsync(cancellationToken), cancellationToken));

    [HttpPost("updateSettings")]
    public async Task<IActionResult> UpdateSettings(UpdateSettingsRequest request, CancellationToken cancellationToken)
    {
        var settings = await db.AppSettings.SingleAsync(cancellationToken);
        var adminId = User.UserId();
        var now = time.GetUtcNow().UtcDateTime;
        var changed = new List<string>();
        foreach (var (name, json) in request.Fields!)
        {
            var field = SettingFields.ByName[name];
            var before = SettingField.ToHistory(field.Get(settings));
            var (value, _, _) = field.Parse(json);
            var after = SettingField.ToHistory(value);
            if (before == after)
            {
                continue;
            }

            field.Set(settings, value);
            db.SettingsHistories.Add(new SettingsHistory
            {
                Id = Guid.NewGuid(),
                Field = name,
                BeforeValue = before,
                AfterValue = after,
                ChangedBy = adminId,
                ChangedAt = now,
            });
            changed.Add(name);
        }

        if (changed.Count > 0)
        {
            settings.UpdatedAt = now;
            settings.UpdatedBy = adminId;
            // Names only: the values are in SettingsHistory.
            auditor.Add(AuditActions.SettingsUpdated, AuditTargets.Settings, "1", new { fields = changed });
            await db.SaveChangesAsync(cancellationToken);
        }

        return Ok(await ViewAsync(settings, cancellationToken));
    }

    [HttpGet("settingsHistory")]
    public async Task<IActionResult> GetHistory([FromQuery] SettingsHistoryQuery query, CancellationToken cancellationToken)
    {
        var rows = db.SettingsHistories.AsNoTracking();
        if (query.Field is not null)
        {
            rows = rows.Where(h => h.Field == query.Field);
        }

        var page = await rows
            .OrderByDescending(h => h.ChangedAt).ThenByDescending(h => h.Id)
            .Select(h => new
            {
                h.Id, h.Field, h.BeforeValue, h.AfterValue, h.ChangedBy, ChangedByName = h.ChangedByNavigation.DisplayName, h.ChangedAt,
            })
            .ToPageAsync(query, cancellationToken);
        var items = page.Items.Select(h =>
        {
            var truncated = h.BeforeValue?.Length > ListValueLength || h.AfterValue?.Length > ListValueLength;
            return new SettingsHistoryItem(
                h.Id, h.Field, Cut(h.BeforeValue), Cut(h.AfterValue), truncated, h.ChangedBy, h.ChangedByName, h.ChangedAt);
        }).ToList();
        return Ok(new PagedResult<SettingsHistoryItem>(items, page.Page, page.PageSize, page.TotalCount));
    }

    [HttpGet("settingsHistory/{id:guid}")]
    public async Task<IActionResult> GetHistoryItem(Guid id, CancellationToken cancellationToken)
    {
        var item = await db.SettingsHistories.AsNoTracking()
            .Where(h => h.Id == id)
            .Select(h => new SettingsHistoryItem(
                h.Id, h.Field, h.BeforeValue, h.AfterValue, false, h.ChangedBy, h.ChangedByNavigation.DisplayName, h.ChangedAt))
            .SingleOrDefaultAsync(cancellationToken);
        return item is null ? this.NotFoundProblem() : Ok(item);
    }

    private static string? Cut(string? value) =>
        value is { Length: > ListValueLength } ? value[..ListValueLength] + "…" : value;

    /// <summary>Every setting by its updateSettings name, plus who changed the settings last.</summary>
    private async Task<Dictionary<string, object?>> ViewAsync(AppSetting settings, CancellationToken cancellationToken)
    {
        var view = SettingFields.All.ToDictionary(field => field.Name, field => field.Get(settings));
        view["updatedAt"] = settings.UpdatedAt;
        view["updatedBy"] = settings.UpdatedBy is { } by
            ? await db.Users.Where(u => u.Id == by).Select(u => new { id = u.Id, displayName = u.DisplayName }).SingleOrDefaultAsync(cancellationToken)
            : null;
        return view;
    }
}

/// <summary>What the app reads before sign-in (A1 version and maintenance checks, A11–A13, support contact).</summary>
[ApiController]
[Route("api/settings")]
[AllowAnonymous]
public sealed class PublicSettingsController(AppDbContext db) : ControllerBase
{
    [HttpGet("public")]
    public async Task<IActionResult> GetPublic(CancellationToken cancellationToken)
    {
        var s = await db.AppSettings.AsNoTracking().SingleAsync(cancellationToken);
        string[] legalFields = ["termsAr", "termsEn", "privacyAr", "privacyEn"];
        var changes = await db.SettingsHistories.AsNoTracking()
            .Where(h => legalFields.Contains(h.Field))
            .GroupBy(h => h.Field)
            .Select(g => new { Field = g.Key, At = g.Max(h => h.ChangedAt) })
            .ToDictionaryAsync(x => x.Field, x => (DateTime?)x.At, cancellationToken);

        Response.Headers.CacheControl = "no-cache";
        return Ok(new
        {
            minAppVersion = new { android = s.MinVersionAndroid, ios = s.MinVersionIos, windows = s.MinVersionWindows, macos = s.MinVersionMacos },
            maintenance = new { enabled = s.MaintenanceEnabled, messageAr = s.MaintenanceMessageAr, messageEn = s.MaintenanceMessageEn },
            support = new { phone = s.SupportPhone, whatsapp = s.SupportWhatsapp, email = s.SupportEmail },
            terms = Legal(s.TermsAr, s.TermsEn, Latest(changes, "termsAr", "termsEn")),
            privacy = Legal(s.PrivacyAr, s.PrivacyEn, Latest(changes, "privacyAr", "privacyEn")),
        });
    }

    private static DateTime? Latest(Dictionary<string, DateTime?> changes, string ar, string en) =>
        new[] { changes.GetValueOrDefault(ar), changes.GetValueOrDefault(en) }.Max();

    /// <summary>
    /// <c>version</c> is a fingerprint of both texts: it changes whenever either text changes, so the app can tell
    /// a cached copy is stale. <c>updatedAt</c> is the last change made in AD13 (null if never changed there).
    /// </summary>
    private static object Legal(string? ar, string? en, DateTime? updatedAt) => new
    {
        version = Convert.ToHexStringLower(SHA256.HashData(Encoding.UTF8.GetBytes($"{ar}\u0000{en}")))[..12],
        updatedAt,
        ar,
        en,
    };
}

/// <summary>The specialties a doctor picks from at registration (A4 step 2), managed by the admin (AD13, AD19).</summary>
[ApiController]
[Route("api/specialties")]
[AllowAnonymous]
public sealed class SpecialtiesController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellationToken) =>
        Ok(await db.Specialties.AsNoTracking()
            .Where(s => s.Active)
            .OrderBy(s => s.SortOrder).ThenBy(s => s.NameAr)
            .Select(s => new { s.Id, s.NameAr, s.NameEn })
            .ToListAsync(cancellationToken));
}
