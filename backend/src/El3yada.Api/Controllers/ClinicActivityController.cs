using System.Globalization;
using System.Text.Json;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>
/// D27 filters, all optional. <c>actorUserId</c>: the doctor or one assistant (from <c>people</c>). <c>from</c> and
/// <c>to</c> are Cairo dates (<c>YYYY-MM-DD</c>), both included.
/// </summary>
public sealed class ClinicActivityQuery : IPagedQuery
{
    public Guid? ActorUserId { get; init; }
    public string? Action { get; init; }
    public Guid? PatientId { get; init; }
    public string? From { get; init; }
    public string? To { get; init; }
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = Paging.DefaultPageSize;

    public static DateOnly? Day(string? value) =>
        DateOnly.TryParseExact(value, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day) ? day : null;
}

public sealed class ClinicActivityQueryValidator : AbstractValidator<ClinicActivityQuery>
{
    public ClinicActivityQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Action).MaxChars(50);
        RuleFor(x => x.From).Must(value => value is null || ClinicActivityQuery.Day(value) is not null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use YYYY-MM-DD.");
        RuleFor(x => x.To).Must(value => value is null || ClinicActivityQuery.Day(value) is not null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use YYYY-MM-DD.")
            .Must((query, to) => ClinicActivityQuery.Day(query.From) is not { } from || ClinicActivityQuery.Day(to) is not { } end || end >= from)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("The end date is before the start date.");
    }
}

/// <summary>Who did it. <c>role</c>: <c>doctor</c>, <c>assistant</c>, or <c>system</c> (no user, no name).</summary>
public sealed record ActivityActorView(Guid? UserId, string? Name, string Role);

/// <summary>The patient the action was about: the name and file number in this clinic.</summary>
public sealed record ActivityPatientView(Guid Id, string? Name, int? FileNumber);

public sealed record ActivityItemView(
    long Id, DateTime At, ActivityActorView Actor, string Action, string TargetType, string? TargetId,
    ActivityPatientView? Patient, JsonElement? Details);

/// <summary>Someone for the person filter: the doctor and every assistant the clinic ever had (removed ones too).</summary>
public sealed record ActivityPersonView(Guid UserId, string Name, string Role, string? Status);

/// <summary>A page of the log, plus <c>people</c> and <c>actions</c> (every action in this clinic's log) for the filters.</summary>
public sealed record ClinicActivityPage(
    IReadOnlyList<ActivityItemView> Items, int Page, int PageSize, int TotalCount, int TotalPages,
    IReadOnlyList<ActivityPersonView> People, IReadOnlyList<string> Actions);

/// <summary>
/// D27 activity log (spec 9.1 <c>getClinicActivity</c>, BR-AS10): the clinic's audit rows (<c>doctorId</c> = the
/// caller's clinic), newest first. Doctor only. Rows written by admins about the doctor (sign-up review, license
/// views) belong to the admin audit (AD15) and are left out.
/// </summary>
[ApiController]
[Route("api/clinic")]
[Clinic(DoctorOnly = true)]
public sealed class ClinicActivityController(AppDbContext db) : ControllerBase
{
    [HttpGet("activity")]
    public async Task<IActionResult> Activity([FromQuery] ClinicActivityQuery query, CancellationToken cancellationToken)
    {
        var doctorId = HttpContext.Clinic().DoctorId;
        var clinicRows = db.AuditLogs.AsNoTracking().Where(a => a.DoctorId == doctorId && a.ActorRole != Roles.Admin);
        var rows = clinicRows;
        if (query.ActorUserId is { } actor)
        {
            rows = rows.Where(a => a.ActorUserId == actor);
        }

        if (Text.TrimToNull(query.Action) is { } action)
        {
            rows = rows.Where(a => a.Action == action);
        }

        if (query.PatientId is { } patientId)
        {
            rows = rows.Where(a => a.PatientId == patientId);
        }

        if (ClinicActivityQuery.Day(query.From) is { } from)
        {
            var start = CairoTime.StartUtc(from);
            rows = rows.Where(a => a.At >= start);
        }

        if (ClinicActivityQuery.Day(query.To) is { } to)
        {
            var end = CairoTime.StartUtc(to.AddDays(1));
            rows = rows.Where(a => a.At < end);
        }

        var page = await rows
            .OrderByDescending(a => a.At).ThenByDescending(a => a.Id)
            .Select(a => new
            {
                a.Id, a.At, a.ActorUserId, a.ActorRole, ActorName = a.ActorUser != null ? a.ActorUser.DisplayName : null,
                a.Action, a.TargetType, a.TargetId, a.PatientId, a.DetailsJson,
                Link = db.DoctorPatients.Where(l => l.DoctorId == doctorId && l.PatientId == a.PatientId)
                    .Select(l => new { l.PatientName, l.FileNumber }).FirstOrDefault(),
            })
            .ToPageAsync(query, cancellationToken);

        var people = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new ActivityPersonView(d.UserId, d.FullName, Roles.Doctor, null))
            .ToListAsync(cancellationToken);
        people.AddRange(await db.Assistants.AsNoTracking()
            .Where(a => a.DoctorId == doctorId)
            .OrderBy(a => a.Status == "removed").ThenBy(a => a.FullName)
            .Select(a => new ActivityPersonView(a.UserId, a.FullName, Roles.Assistant, a.Status))
            .ToListAsync(cancellationToken));
        var actions = await clinicRows.Select(a => a.Action).Distinct().OrderBy(a => a).ToListAsync(cancellationToken);

        var items = page.Items.Select(a => new ActivityItemView(
            a.Id, a.At, new ActivityActorView(a.ActorUserId, a.ActorName, a.ActorRole), a.Action, a.TargetType, a.TargetId,
            a.PatientId is { } id ? new ActivityPatientView(id, a.Link?.PatientName, a.Link?.FileNumber) : null,
            a.DetailsJson is null ? null : JsonDocument.Parse(a.DetailsJson).RootElement.Clone())).ToList();
        return Ok(new ClinicActivityPage(items, page.Page, page.PageSize, page.TotalCount, page.TotalPages, people, actions));
    }
}
