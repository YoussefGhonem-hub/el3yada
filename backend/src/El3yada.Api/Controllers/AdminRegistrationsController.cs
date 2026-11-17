using System.Text.Json;
using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Doctors;
using El3yada.Api.Notifications;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>AD2 filters. <c>status</c> defaults to <c>pendingApproval</c>; <c>all</c> lists every doctor.</summary>
public sealed class RegistrationListQuery : IPagedQuery
{
    public string Status { get; init; } = DoctorStatuses.PendingApproval;

    /// <summary>Name, email, mobile or syndicate number (contains).</summary>
    public string? Search { get; init; }

    public Guid? SpecialtyId { get; init; }

    public string? Governorate { get; init; }

    /// <summary>Submitted on or after (UTC).</summary>
    public DateTime? From { get; init; }

    /// <summary>Submitted before (UTC).</summary>
    public DateTime? To { get; init; }

    /// <summary><c>running</c> or <c>ended</c>: only doctors whose free trial is in that state (spec 6.16).</summary>
    public string? Trial { get; init; }

    /// <summary><c>oldest</c> (default: the queue order) or <c>newest</c>.</summary>
    public string Sort { get; init; } = "oldest";

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class RegistrationListQueryValidator : AbstractValidator<RegistrationListQuery>
{
    public RegistrationListQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Status).OneOf([.. DoctorStatuses.All, "all"]);
        RuleFor(x => x.Sort).OneOf("oldest", "newest");
        RuleFor(x => x.Trial).OneOf("running", "ended");
        RuleFor(x => x.Search).MaxChars(100);
        RuleFor(x => x.Governorate).MaxChars(50);
    }
}

public sealed record RegistrationListItem(
    Guid DoctorId,
    string FullName,
    string Title,
    SpecialtyView Specialty,
    string? Governorate,
    string? City,
    string Status,
    DateTime SubmittedAt,
    DateTime CreatedAt,
    bool EmailVerified,
    TrialView? Trial);

/// <summary><c>decision</c>: <c>approve</c>, or <c>reject</c> with a <c>reason</c> (3–500 characters) the doctor sees in A7.</summary>
public sealed record ReviewDoctorRegistrationRequest(Guid? DoctorId, string? Decision, string? Reason);

public sealed class ReviewDoctorRegistrationRequestValidator : AbstractValidator<ReviewDoctorRegistrationRequest>
{
    public ReviewDoctorRegistrationRequestValidator()
    {
        RuleFor(x => x.DoctorId).Required();
        RuleFor(x => x.Decision).Required().OneOf("approve", "reject");
        RuleFor(x => x.Reason)
            .Must((request, reason) => request.Decision != "reject" || reason?.Trim().Length >= 3)
            .WithErrorCode(ErrorCodes.ReasonRequired).WithMessage("Write the reason (at least 3 characters).")
            .MaxChars(500);
    }
}

/// <summary>A past review of a registration, from the audit log (AD3 history).</summary>
public sealed record RegistrationReview(string Decision, string? Reason, Guid? ReviewedBy, string? ReviewedByName, DateTime At);

/// <summary>Doctor sign-up requests (AD2, AD3) and <c>reviewDoctorRegistration</c>. Any admin.</summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminRegistrationsController(
    AppDbContext db, IFileStorage storage, NotificationWriter notifications, Auditor auditor,
    AccountStateCache stateCache, TimeProvider time) : ControllerBase
{
    /// <summary>AD2: sign-up requests, oldest first by default.</summary>
    [HttpGet("doctorRegistrations")]
    public async Task<IActionResult> List([FromQuery] RegistrationListQuery query, CancellationToken cancellationToken)
    {
        var doctors = db.Doctors.AsNoTracking();
        if (query.Status != "all")
        {
            doctors = doctors.Where(d => d.Status == query.Status);
        }

        if (Text.TrimToNull(query.Search) is { } search)
        {
            var phone = EgyptianMobile.Normalize(search);
            doctors = doctors.Where(d => d.FullName.Contains(search)
                || (d.FullNameEn != null && d.FullNameEn.Contains(search))
                || (d.User.Email != null && d.User.Email.Contains(search.ToLowerInvariant()))
                || d.LicenseNumber.Contains(search)
                || (phone != null && d.User.Phone == phone));
        }

        var now = time.GetUtcNow().UtcDateTime;
        if (query.Trial == "running")
        {
            doctors = doctors.Where(d => d.TrialEndsAt > now);
        }
        else if (query.Trial == "ended")
        {
            doctors = doctors.Where(d => d.TrialEndsAt <= now);
        }

        if (query.SpecialtyId is { } specialtyId)
        {
            doctors = doctors.Where(d => d.SpecialtyId == specialtyId);
        }

        if (Text.TrimToNull(query.Governorate) is { } governorate)
        {
            doctors = doctors.Where(d => d.DefaultBranch != null && d.DefaultBranch.Governorate == governorate);
        }

        if (query.From is { } from)
        {
            doctors = doctors.Where(d => (d.StatusChangedAt ?? d.CreatedAt) >= from);
        }

        if (query.To is { } to)
        {
            doctors = doctors.Where(d => (d.StatusChangedAt ?? d.CreatedAt) < to);
        }

        doctors = query.Sort == "newest"
            ? doctors.OrderByDescending(d => d.StatusChangedAt ?? d.CreatedAt).ThenByDescending(d => d.UserId)
            : doctors.OrderBy(d => d.StatusChangedAt ?? d.CreatedAt).ThenBy(d => d.UserId);

        var rows = await doctors
            .Select(d => new
            {
                Item = new RegistrationListItem(
                    d.UserId,
                    d.FullName,
                    d.Title,
                    new SpecialtyView(d.Specialty.Id, d.Specialty.NameAr, d.Specialty.NameEn),
                    d.DefaultBranch != null ? d.DefaultBranch.Governorate : null,
                    d.DefaultBranch != null ? d.DefaultBranch.City : null,
                    d.Status,
                    d.StatusChangedAt ?? d.CreatedAt,
                    d.CreatedAt,
                    d.User.EmailVerifiedAt != null,
                    null),
                d.TrialEndsAt,
            })
            .ToPageAsync(query, cancellationToken);
        return Ok(new PagedResult<RegistrationListItem>(
            [.. rows.Items.Select(row => row.Item with { Trial = TrialView.Of(row.TrialEndsAt, now) })],
            rows.Page, rows.PageSize, rows.TotalCount));
    }

    /// <summary>AD3: everything the doctor submitted in A4, plus earlier reviews.</summary>
    [HttpGet("doctorRegistrations/{doctorId:guid}")]
    public async Task<IActionResult> Get(Guid doctorId, CancellationToken cancellationToken)
    {
        var view = await DoctorRegistrationView.LoadAsync(db, doctorId, time.GetUtcNow().UtcDateTime, cancellationToken);
        if (view is null)
        {
            return this.NotFoundProblem();
        }

        var reviews = await db.AuditLogs.AsNoTracking()
            .Where(a => a.TargetType == AuditTargets.Doctor && a.TargetId == doctorId.ToString()
                && (a.Action == AuditActions.DoctorRegistrationApproved || a.Action == AuditActions.DoctorRegistrationRejected))
            .OrderByDescending(a => a.At)
            .Select(a => new { a.Action, a.DetailsJson, a.ActorUserId, ActorName = a.ActorUser != null ? a.ActorUser.DisplayName : null, a.At })
            .ToListAsync(cancellationToken);
        return Ok(new
        {
            registration = view,
            reviews = reviews.Select(r => new RegistrationReview(
                r.Action == AuditActions.DoctorRegistrationApproved ? "approve" : "reject",
                ReasonOf(r.DetailsJson), r.ActorUserId, r.ActorName, r.At)),
        });
    }

    /// <summary>AD3 license viewer: the file streams through the API after the admin check. Logged.</summary>
    [HttpGet("doctorRegistrations/{doctorId:guid}/license")]
    public async Task<IActionResult> GetLicense(Guid doctorId, CancellationToken cancellationToken)
    {
        var path = await db.Doctors.Where(d => d.UserId == doctorId).Select(d => d.LicenseDocPath).SingleOrDefaultAsync(cancellationToken);
        if (path is null)
        {
            return this.NotFoundProblem();
        }

        auditor.Add(AuditActions.DoctorLicenseViewed, AuditTargets.Doctor, doctorId, doctorId: doctorId);
        await db.SaveChangesAsync(cancellationToken);
        return await LicenseFiles.StreamAsync(this, storage, path, cancellationToken);
    }

    /// <summary>
    /// spec 9.1 <c>reviewDoctorRegistration</c>: approve (the doctor becomes <c>active</c>) or reject with a reason
    /// (<c>rejected</c>, shown in A7). Notifies the doctor. Only a <c>pendingApproval</c> registration can be reviewed.
    /// </summary>
    [HttpPost("reviewDoctorRegistration")]
    public async Task<IActionResult> Review(ReviewDoctorRegistrationRequest request, CancellationToken cancellationToken)
    {
        var doctorId = request.DoctorId!.Value;
        if (!await db.Doctors.AnyAsync(d => d.UserId == doctorId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var approve = request.Decision == "approve";
        var reason = approve ? null : Text.CollapseSpaces(request.Reason!);
        var adminId = User.UserId();
        var now = time.GetUtcNow().UtcDateTime;
        var trialDays = await db.AppSettings.Select(s => s.TrialDays).SingleAsync(cancellationToken);
        var trialEndsAt = Trial.EndsAt(now, trialDays);

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        // Only one review wins when two admins answer at the same moment.
        var updated = approve
            ? await db.Doctors
                .Where(d => d.UserId == doctorId && d.Status == DoctorStatuses.PendingApproval)
                .ExecuteUpdateAsync(set => set
                    .SetProperty(d => d.Status, DoctorStatuses.Active)
                    .SetProperty(d => d.StatusReason, (string?)null)
                    .SetProperty(d => d.StatusChangedAt, now)
                    .SetProperty(d => d.ApprovedAt, now)
                    .SetProperty(d => d.ApprovedBy, adminId)
                    .SetProperty(d => d.TrialEndsAt, trialEndsAt)
                    .SetProperty(d => d.UpdatedAt, now), cancellationToken)
            : await db.Doctors
                .Where(d => d.UserId == doctorId && d.Status == DoctorStatuses.PendingApproval)
                .ExecuteUpdateAsync(set => set
                    .SetProperty(d => d.Status, DoctorStatuses.Rejected)
                    .SetProperty(d => d.StatusReason, reason)
                    .SetProperty(d => d.StatusChangedAt, now)
                    .SetProperty(d => d.UpdatedAt, now), cancellationToken);
        if (updated == 0)
        {
            return this.ConflictProblem(ErrorCodes.RegistrationNotPending, "This registration is not waiting for review.");
        }

        notifications.Add(
            doctorId,
            approve ? NotificationTexts.RegistrationApproved(trialDays) : NotificationTexts.RegistrationRejected(reason!),
            approve ? "/home" : "/registration/rejected",
            new { doctorId });
        auditor.Add(
            approve ? AuditActions.DoctorRegistrationApproved : AuditActions.DoctorRegistrationRejected,
            AuditTargets.Doctor, doctorId, approve ? new { trialEndsAt } : new { reason }, doctorId: doctorId);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        stateCache.Invalidate(doctorId);

        return Ok(await DoctorRegistrationView.LoadAsync(db, doctorId, now, cancellationToken));
    }

    private static string? ReasonOf(string? detailsJson)
    {
        if (detailsJson is null)
        {
            return null;
        }

        using var document = JsonDocument.Parse(detailsJson);
        return document.RootElement.TryGetProperty("reason", out var reason) ? reason.GetString() : null;
    }
}
