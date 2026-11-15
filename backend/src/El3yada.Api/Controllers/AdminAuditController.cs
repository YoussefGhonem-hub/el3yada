using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>AD15 filters. All are optional; <c>from</c> and <c>to</c> are UTC (<c>to</c> is exclusive).</summary>
public sealed class AuditLogQuery : IPagedQuery
{
    public Guid? ActorUserId { get; init; }
    public string? ActorRole { get; init; }
    public string? Action { get; init; }
    public string? TargetType { get; init; }
    public string? TargetId { get; init; }
    public Guid? DoctorId { get; init; }
    public DateTime? From { get; init; }
    public DateTime? To { get; init; }
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class AuditLogQueryValidator : AbstractValidator<AuditLogQuery>
{
    public AuditLogQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.ActorRole).OneOf("system", Roles.Admin, Roles.Doctor, Roles.Assistant, Roles.Patient);
        RuleFor(x => x.Action).MaxChars(50);
        RuleFor(x => x.TargetType).MaxChars(30);
        RuleFor(x => x.TargetId).MaxChars(64);
    }
}

public sealed record AuditLogItem(
    long Id,
    DateTime At,
    Guid? ActorUserId,
    string ActorRole,
    string? ActorName,
    string Action,
    string TargetType,
    string? TargetId,
    Guid? DoctorId,
    JsonElement? Details);

/// <summary>AD15: the audit log, newest first. Any admin.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminAuditController(AppDbContext db) : ControllerBase
{
    [HttpGet("auditLogs")]
    public async Task<IActionResult> List([FromQuery] AuditLogQuery query, CancellationToken cancellationToken)
    {
        var rows = db.AuditLogs.AsNoTracking();
        if (query.ActorUserId is { } actor)
        {
            rows = rows.Where(a => a.ActorUserId == actor);
        }

        if (query.ActorRole is { } role)
        {
            rows = rows.Where(a => a.ActorRole == role);
        }

        if (Text.TrimToNull(query.Action) is { } action)
        {
            rows = rows.Where(a => a.Action == action);
        }

        if (Text.TrimToNull(query.TargetType) is { } targetType)
        {
            rows = rows.Where(a => a.TargetType == targetType);
        }

        if (Text.TrimToNull(query.TargetId) is { } targetId)
        {
            rows = rows.Where(a => a.TargetId == targetId);
        }

        if (query.DoctorId is { } doctorId)
        {
            rows = rows.Where(a => a.DoctorId == doctorId);
        }

        if (query.From is { } from)
        {
            rows = rows.Where(a => a.At >= from);
        }

        if (query.To is { } to)
        {
            rows = rows.Where(a => a.At < to);
        }

        var page = await rows
            .OrderByDescending(a => a.At).ThenByDescending(a => a.Id)
            .Select(a => new
            {
                a.Id, a.At, a.ActorUserId, a.ActorRole, ActorName = a.ActorUser != null ? a.ActorUser.DisplayName : null,
                a.Action, a.TargetType, a.TargetId, a.DoctorId, a.DetailsJson,
            })
            .ToPageAsync(query, cancellationToken);
        var items = page.Items.Select(a => new AuditLogItem(
            a.Id, a.At, a.ActorUserId, a.ActorRole, a.ActorName, a.Action, a.TargetType, a.TargetId, a.DoctorId,
            a.DetailsJson is null ? null : JsonDocument.Parse(a.DetailsJson).RootElement.Clone())).ToList();
        return Ok(new PagedResult<AuditLogItem>(items, page.Page, page.PageSize, page.TotalCount));
    }
}
