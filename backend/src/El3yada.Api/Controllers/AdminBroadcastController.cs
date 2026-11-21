using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Infrastructure.Notifications;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>Who gets a broadcast: every doctor, or the doctors in <c>doctorIds</c>.</summary>
public static class BroadcastAudiences
{
    public const string All = "all";
    public const string Selected = "selected";
}

/// <summary>
/// AD16 <c>sendBroadcast</c>. A language is written whole (title and body) or left out; at least one is needed, and an
/// empty one takes the other's text (spec 12: admin texts fall back to the other language).
/// </summary>
public sealed record SendBroadcastRequest(
    string? Audience, IReadOnlyList<Guid>? DoctorIds, string? TitleAr, string? BodyAr, string? TitleEn, string? BodyEn);

public sealed class SendBroadcastRequestValidator : AbstractValidator<SendBroadcastRequest>
{
    public const int MaxTitle = 100;
    public const int MaxBody = 500;
    public const int MaxDoctors = 500;

    public SendBroadcastRequestValidator()
    {
        RuleFor(x => x.Audience).Required().OneOf(BroadcastAudiences.All, BroadcastAudiences.Selected);
        RuleFor(x => x.DoctorIds)
            .Must(ids => ids is { Count: > 0 }).WithErrorCode(ErrorCodes.Required).WithMessage("Choose at least one doctor.")
            .When(x => x.Audience == BroadcastAudiences.Selected);
        RuleFor(x => x.DoctorIds)
            .Must(ids => ids is null || ids.Count <= MaxDoctors).WithErrorCode(ErrorCodes.InvalidValue).WithMessage($"At most {MaxDoctors} doctors.")
            .Must(ids => ids is null || ids.Distinct().Count() == ids.Count).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("A doctor is listed twice.");
        RuleFor(x => x.DoctorIds)
            .Must(ids => ids is not { Count: > 0 }).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Leave the doctors out when sending to all.")
            .When(x => x.Audience == BroadcastAudiences.All);
        RuleFor(x => x.TitleAr).MaxChars(MaxTitle);
        RuleFor(x => x.TitleEn).MaxChars(MaxTitle);
        RuleFor(x => x.BodyAr).MaxChars(MaxBody);
        RuleFor(x => x.BodyEn).MaxChars(MaxBody);

        // Nothing written: Arabic is asked for first.
        RuleFor(x => x.TitleAr)
            .Must((request, _) => Has(request.TitleAr) || Has(request.BodyAr) || Has(request.TitleEn) || Has(request.BodyEn))
            .WithErrorCode(ErrorCodes.Required).WithMessage("Write the message in Arabic, English or both.");
        // Half a language: the missing half is required.
        RuleFor(x => x.TitleAr).Must((request, title) => Has(title) || !Has(request.BodyAr))
            .WithErrorCode(ErrorCodes.Required).WithMessage("Write the Arabic title.");
        RuleFor(x => x.BodyAr).Must((request, body) => Has(body) || !Has(request.TitleAr))
            .WithErrorCode(ErrorCodes.Required).WithMessage("Write the Arabic text.");
        RuleFor(x => x.TitleEn).Must((request, title) => Has(title) || !Has(request.BodyEn))
            .WithErrorCode(ErrorCodes.Required).WithMessage("Write the English title.");
        RuleFor(x => x.BodyEn).Must((request, body) => Has(body) || !Has(request.TitleEn))
            .WithErrorCode(ErrorCodes.Required).WithMessage("Write the English text.");
    }

    internal static bool Has(string? value) => !string.IsNullOrWhiteSpace(value);
}

public sealed class BroadcastHistoryQuery : IPagedQuery
{
    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class BroadcastHistoryQueryValidator : AbstractValidator<BroadcastHistoryQuery>
{
    public BroadcastHistoryQueryValidator() => this.AddPagingRules();
}

public sealed record BroadcastSender(Guid? UserId, string? DisplayName);

/// <summary>A sent broadcast, read back from its <c>broadcastSent</c> audit row.</summary>
public sealed record BroadcastView(
    Guid BroadcastId, DateTime SentAt, BroadcastSender SentBy, string Audience, int Recipients,
    string TitleAr, string BodyAr, string TitleEn, string BodyEn);

/// <summary>
/// AD16 Broadcast [C]: an in-app and push notification to every doctor or to chosen doctors, through the notification
/// service (stored in both languages, pushed in each doctor's language). The history is the audit log: no table of
/// its own. Any admin. Contract: backend/docs/api-broadcast.md.
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminBroadcastController(AppDbContext db, INotificationWriter notifications, Auditor auditor, TimeProvider time)
    : ControllerBase
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    /// <summary>
    /// Sends to the doctors who can use the app: account active and clinic <c>active</c> or <c>suspended</c> (pending,
    /// rejected and disabled doctors are left out, also when chosen). 400 <c>doctorIds</c> <c>INVALID_VALUE</c> when
    /// one isn't a doctor; 409 <c>BROADCAST_NO_RECIPIENTS</c> when nobody is left.
    /// </summary>
    [HttpPost("sendBroadcast")]
    public async Task<IActionResult> Send(SendBroadcastRequest request, CancellationToken cancellationToken)
    {
        var selected = request.Audience == BroadcastAudiences.Selected;
        var chosen = request.DoctorIds ?? [];
        if (selected)
        {
            var known = await db.Doctors.CountAsync(d => chosen.Contains(d.UserId), cancellationToken);
            if (known != chosen.Count)
            {
                return ValidationProblems.Field(HttpContext, "doctorIds", ErrorCodes.InvalidValue, "Choose doctors from the list.");
            }
        }

        var doctors = db.Doctors.AsNoTracking()
            .Where(d => (d.Status == DoctorStatuses.Active || d.Status == DoctorStatuses.Suspended) && d.User.Status == AccountStatuses.Active);
        if (selected)
        {
            doctors = doctors.Where(d => chosen.Contains(d.UserId));
        }

        var recipients = await doctors.Select(d => d.UserId).ToListAsync(cancellationToken);
        if (recipients.Count == 0)
        {
            return this.ConflictProblem(ErrorCodes.BroadcastNoRecipients, "None of these doctors can receive it now.");
        }

        var (titleAr, bodyAr, titleEn, bodyEn) = Texts(request);
        var broadcastId = Guid.NewGuid();
        var message = new NotificationMessage(NotificationTypes.Broadcast, titleAr, titleEn, bodyAr, bodyEn, null, new { broadcastId });
        foreach (var doctorId in recipients)
        {
            notifications.Add(doctorId, message);
        }

        var audience = selected ? BroadcastAudiences.Selected : BroadcastAudiences.All;
        auditor.Add(
            AuditActions.BroadcastSent, AuditTargets.Broadcast, broadcastId,
            new { audience, recipients = recipients.Count, doctorIds = selected ? chosen : null, titleAr, bodyAr, titleEn, bodyEn });
        // One save: the rows and their audit go together, and delivery (SignalR, FCM) starts once they are committed.
        await db.SaveChangesAsync(cancellationToken);

        var adminId = User.UserId();
        var adminName = await db.Users.Where(u => u.Id == adminId).Select(u => u.DisplayName).SingleOrDefaultAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, new BroadcastView(
            broadcastId, time.GetUtcNow().UtcDateTime, new BroadcastSender(adminId, adminName),
            audience, recipients.Count, titleAr, bodyAr, titleEn, bodyEn));
    }

    /// <summary>AD16 history: the broadcasts sent, newest first, from the audit log.</summary>
    [HttpGet("broadcasts")]
    public async Task<IActionResult> History([FromQuery] BroadcastHistoryQuery query, CancellationToken cancellationToken)
    {
        var page = await db.AuditLogs.AsNoTracking()
            .Where(a => a.Action == AuditActions.BroadcastSent)
            .OrderByDescending(a => a.At).ThenByDescending(a => a.Id)
            .Select(a => new { a.TargetId, a.At, a.ActorUserId, ActorName = a.ActorUser != null ? a.ActorUser.DisplayName : null, a.DetailsJson })
            .ToPageAsync(query, cancellationToken);
        return Ok(new PagedResult<BroadcastView>(
            [.. page.Items.Select(row => ViewOf(row.TargetId, row.At, row.ActorUserId, row.ActorName, row.DetailsJson))],
            page.Page, page.PageSize, page.TotalCount));
    }

    /// <summary>Trimmed texts, each language falling back to the other.</summary>
    private static (string TitleAr, string BodyAr, string TitleEn, string BodyEn) Texts(SendBroadcastRequest request)
    {
        var titleAr = Text.TrimToNull(request.TitleAr);
        var bodyAr = Text.TrimToNull(request.BodyAr);
        var titleEn = Text.TrimToNull(request.TitleEn);
        var bodyEn = Text.TrimToNull(request.BodyEn);
        return (titleAr ?? titleEn!, bodyAr ?? bodyEn!, titleEn ?? titleAr!, bodyEn ?? bodyAr!);
    }

    private static BroadcastView ViewOf(string? targetId, DateTime at, Guid? actorId, string? actorName, string? detailsJson)
    {
        var details = detailsJson is null ? default : JsonSerializer.Deserialize<Details>(detailsJson, Json);
        return new BroadcastView(
            Guid.TryParse(targetId, out var id) ? id : Guid.Empty, at, new BroadcastSender(actorId, actorName),
            details?.Audience ?? BroadcastAudiences.All, details?.Recipients ?? 0,
            details?.TitleAr ?? "", details?.BodyAr ?? "", details?.TitleEn ?? "", details?.BodyEn ?? "");
    }

    private sealed record Details(string? Audience, int Recipients, string? TitleAr, string? BodyAr, string? TitleEn, string? BodyEn);
}
