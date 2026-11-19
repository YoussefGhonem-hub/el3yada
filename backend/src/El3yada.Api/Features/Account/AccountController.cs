using El3yada.Api.Infrastructure.Auditing;
using El3yada.Api.Infrastructure.Auth;
using El3yada.Data;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Account;

/// <summary>Language, appearance and notification preferences (D24, AS12, P14, AD18). Any signed-in role.</summary>
public sealed record UpdatePreferencesRequest(
    string? Locale,
    string? ThemeMode,
    bool? NotifyChat,
    bool? NotifyReminders,
    bool? NotifyShowPreview);

public sealed record PreferencesDto(string Locale, string ThemeMode, bool NotifyChat, bool NotifyReminders, bool NotifyShowPreview, DateTime? AcceptedTermsAt);

public sealed class UpdatePreferencesRequestValidator : AbstractValidator<UpdatePreferencesRequest>
{
    public UpdatePreferencesRequestValidator()
    {
        RuleFor(x => x.Locale).Must(v => v is null or "ar" or "en").WithErrorCode("INVALID_LOCALE");
        RuleFor(x => x.ThemeMode).Must(v => v is null or "system" or "light" or "dark").WithErrorCode("INVALID_THEME");
    }
}

[ApiController]
[Route("api/me")]
[Authorize(Policy = Policies.SignedIn)]
[Produces("application/json")]
public sealed class AccountController(AppDbContext db, ICurrentUser user, IAuditLogger audit, TimeProvider clock) : ControllerBase
{
    [HttpGet("preferences", Name = "getPreferences")]
    public async Task<PreferencesDto> GetPreferences(CancellationToken ct) =>
        await db.Users.AsNoTracking()
            .Where(u => u.Id == user.UserId)
            .Select(u => new PreferencesDto(u.Locale, u.ThemeMode, u.NotifyChat, u.NotifyReminders, u.NotifyShowPreview, u.AcceptedTermsAt))
            .FirstAsync(ct);

    /// <summary>Changes only the fields that are sent. The locale is also the push language (spec 10.1).</summary>
    [HttpPatch("preferences", Name = "updatePreferences")]
    public async Task<PreferencesDto> UpdatePreferences(UpdatePreferencesRequest request, CancellationToken ct)
    {
        var entity = await db.Users.FirstAsync(u => u.Id == user.UserId, ct);
        if (request.Locale is not null) entity.Locale = request.Locale;
        if (request.ThemeMode is not null) entity.ThemeMode = request.ThemeMode;
        if (request.NotifyChat is { } chat) entity.NotifyChat = chat;
        if (request.NotifyReminders is { } reminders) entity.NotifyReminders = reminders;
        if (request.NotifyShowPreview is { } preview) entity.NotifyShowPreview = preview;
        entity.UpdatedAt = clock.GetUtcNow().UtcDateTime;
        await db.SaveChangesAsync(ct);
        return new PreferencesDto(entity.Locale, entity.ThemeMode, entity.NotifyChat, entity.NotifyReminders, entity.NotifyShowPreview, entity.AcceptedTermsAt);
    }

    /// <summary>Accepts the Terms and Privacy Policy (A4, A9 first login). Idempotent: the first acceptance is kept.</summary>
    [HttpPost("accept-terms", Name = "acceptTerms")]
    public async Task<IActionResult> AcceptTerms(CancellationToken ct)
    {
        var entity = await db.Users.FirstAsync(u => u.Id == user.UserId, ct);
        if (entity.AcceptedTermsAt is null)
        {
            entity.AcceptedTermsAt = entity.UpdatedAt = clock.GetUtcNow().UtcDateTime;
            audit.Add("user.acceptedTerms", "User", entity.Id);
            await db.SaveChangesAsync(ct);
        }
        return NoContent();
    }
}
