using El3yada.Api.Audit;
using El3yada.Api.Billing;
using El3yada.Api.Common;
using El3yada.Api.Configuration;
using El3yada.Api.Email;
using El3yada.Api.Features.Appointments;
using El3yada.Api.Sessions;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Controllers;

// ---- Requests ----------------------------------------------------------------------------------------------

public sealed class DoctorDirectoryQuery : IPagedQuery
{
    /// <summary>Name, phone, email or the clinic's (default branch) name.</summary>
    public string? Search { get; init; }

    public string? Status { get; init; }

    public Guid? SpecialtyId { get; init; }

    public string? Governorate { get; init; }

    /// <summary><c>name</c> (default), <c>newest</c>, <c>sessions</c> or <c>outstanding</c>.</summary>
    public string? Sort { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class DoctorDirectoryQueryValidator : AbstractValidator<DoctorDirectoryQuery>
{
    public DoctorDirectoryQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Status).OneOf(DoctorStatuses.All).When(x => x.Status is not null);
        RuleFor(x => x.Sort).OneOf("name", "newest", "sessions", "outstanding").When(x => x.Sort is not null);
        RuleFor(x => x.Search).MaxChars(100);
    }
}

public sealed class DoctorSessionsQuery : IPagedQuery
{
    /// <summary>A Cairo month, <c>yyyy-MM</c>. Default: the current one.</summary>
    public string? Month { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class DoctorSessionsQueryValidator : AbstractValidator<DoctorSessionsQuery>
{
    public DoctorSessionsQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Month)
            .Must(month => CairoTime.ParseMonthKey(month) is not null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use the form 2026-10.")
            .When(x => x.Month is not null);
    }
}

public sealed class PageQuery : IPagedQuery
{
    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class PageQueryValidator : AbstractValidator<PageQuery>
{
    public PageQueryValidator() => this.AddPagingRules();
}

/// <summary>AD5 "Add internal note".</summary>
public sealed record AddDoctorNoteRequest(Guid? DoctorId, string? Text);

public sealed class AddDoctorNoteRequestValidator : AbstractValidator<AddDoctorNoteRequest>
{
    public AddDoctorNoteRequestValidator()
    {
        RuleFor(x => x.DoctorId).Required();
        RuleFor(x => x.Text).Must(text => text?.Trim().Length >= 1).WithErrorCode(ErrorCodes.Required).WithMessage("Write the note.")
            .MaxChars(1000);
    }
}

/// <summary>AD5 "Profile tab: edit info". Only what was sent changes.</summary>
public sealed record AdminUpdateDoctorProfileRequest(
    Guid? DoctorId, string? FullName, string? FullNameEn, string? Title, string? TitleEn, string? LicenseNumber, Guid? SpecialtyId);

public sealed class AdminUpdateDoctorProfileRequestValidator : AbstractValidator<AdminUpdateDoctorProfileRequest>
{
    public AdminUpdateDoctorProfileRequestValidator()
    {
        RuleFor(x => x.DoctorId).Required();
        RuleFor(x => x.FullName).FullName().When(x => x.FullName is not null);
        RuleFor(x => x.FullNameEn).MaxChars(100);
        RuleFor(x => x.Title).MaxChars(50);
        RuleFor(x => x.TitleEn).MaxChars(50);
        RuleFor(x => x.LicenseNumber).MaxChars(30)
            .Must(text => text?.Trim().Length > 0).WithErrorCode(ErrorCodes.Required).WithMessage("The license number can't be empty.")
            .When(x => x.LicenseNumber is not null);
    }
}

public sealed record DoctorIdRequest(Guid? DoctorId);

public sealed class DoctorIdRequestValidator : AbstractValidator<DoctorIdRequest>
{
    public DoctorIdRequestValidator() => RuleFor(x => x.DoctorId).Required();
}

// ---- Views -------------------------------------------------------------------------------------------------

public sealed record DoctorDirectoryItem(
    Guid DoctorId,
    string FullName,
    string? FullNameEn,
    string? Email,
    string? Phone,
    string? ClinicName,
    string? ClinicNameEn,
    string? Governorate,
    string SpecialtyAr,
    string SpecialtyEn,
    string Status,
    DateTime? TrialEndsAt,
    DateTime CreatedAt,
    int SessionsThisMonth,
    int OutstandingPiasters);

public sealed record DoctorMonthActivity(string MonthKey, int Examinations, int Consultations, int PlatformFeesPiasters);

/// <summary>A session as the admin sees it (AD5): the time, type and fee, and the patient's masked name. No clinical content, no clinic revenue.</summary>
public sealed record DoctorSessionRow(Guid Id, DateOnly Day, DateTime At, string Type, int FeePiasters, string PatientMasked, bool Deleted);

public sealed record DoctorActivityView(IReadOnlyList<DoctorMonthActivity> Months, string Month, PagedResult<DoctorSessionRow> Sessions);

public sealed record DeletedSessionRow(Guid Id, DateOnly Day, string Type, DateTime? DeletedAt, string? Reason, string PatientMasked);

public sealed record DoctorAuditRow(DateTime At, string Action, string ActorRole, string? Details);

public sealed record DoctorAuditView(PagedResult<DeletedSessionRow> DeletedSessions, PagedResult<DoctorAuditRow> StatusChanges);

public sealed record DoctorBranchRow(Guid Id, string NameAr, string? NameEn, string? Area, string City, string Status, bool IsDefault, IReadOnlyList<string> Phones);

public sealed record DoctorAppointmentsMonth(string MonthKey, int Bookings, int NoShows, int Cancellations, int CheckedInNoSession, double NoShowRate);

public sealed record DoctorAssistantRow(Guid UserId, string FullName, string? Phone, string Preset, string Status, DateTime? LastActiveAt);

public sealed record DoctorNoteRow(Guid Id, string Text, string AuthorName, DateTime CreatedAt);

public sealed record AdminDoctorProfileView(
    Guid DoctorId,
    string FullName,
    string? FullNameEn,
    string Title,
    string? TitleEn,
    string LicenseNumber,
    Guid SpecialtyId,
    string SpecialtyAr,
    string SpecialtyEn,
    string? Email,
    string? Phone,
    bool EmailVerified,
    string Status,
    string? StatusReason,
    DateTime? StatusChangedAt,
    DateTime? TrialEndsAt,
    DateTime CreatedAt);

// ---- Controller --------------------------------------------------------------------------------------------

/// <summary>
/// The admin's view of the doctors (AD4, AD5; spec 7.5, 9.1 <c>getDoctorActivity</c>). Admins see sessions as time, type
/// and fee with the patient's name masked, never clinical content (AC-12) or the clinic's revenue (BR-REV1).
/// </summary>
[ApiController]
[Route("api/admin/doctors")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminDoctorDirectoryController(
    AppDbContext db,
    Auditor auditor,
    EmailTokens emailTokens,
    EmailTemplates emailTemplates,
    EmailQueue emailQueue,
    IOptions<AuthOptions> authOptions,
    TimeProvider time) : ControllerBase
{
    private DateOnly Today => CairoTime.Today(time);

    /// <summary>AD4: every doctor with the month's sessions and what they still owe.</summary>
    [HttpGet]
    public async Task<IActionResult> List([FromQuery] DoctorDirectoryQuery query, CancellationToken cancellationToken)
    {
        var month = CairoTime.MonthKey(Today);
        var outstanding = InvoiceStatuses.Outstanding;
        var doctors = db.Doctors.AsNoTracking().AsQueryable();
        if (query.Status is not null)
        {
            doctors = doctors.Where(d => d.Status == query.Status);
        }

        if (query.SpecialtyId is { } specialtyId)
        {
            doctors = doctors.Where(d => d.SpecialtyId == specialtyId);
        }

        if (Text.TrimToNull(query.Governorate) is { } governorate)
        {
            doctors = doctors.Where(d => d.DefaultBranch != null && d.DefaultBranch.Governorate == governorate);
        }

        if (Text.TrimToNull(query.Search) is { } search)
        {
            var phone = EgyptianMobile.Normalize(search);
            doctors = doctors.Where(d => d.FullName.Contains(search)
                || (d.FullNameEn != null && d.FullNameEn.Contains(search))
                || (d.User.Email != null && d.User.Email.Contains(search.ToLower()))
                || (phone != null && d.User.Phone == phone)
                || d.Branches.Any(b => b.NameAr.Contains(search) || (b.NameEn != null && b.NameEn.Contains(search))));
        }

        var rows = doctors.Select(d => new
        {
            d.UserId,
            d.FullName,
            d.FullNameEn,
            d.User.Email,
            d.User.Phone,
            ClinicName = d.DefaultBranch == null ? null : d.DefaultBranch.NameAr,
            ClinicNameEn = d.DefaultBranch == null ? null : d.DefaultBranch.NameEn,
            Governorate = d.DefaultBranch == null ? null : d.DefaultBranch.Governorate,
            SpecialtyAr = d.Specialty.NameAr,
            SpecialtyEn = d.Specialty.NameEn,
            d.Status,
            d.TrialEndsAt,
            d.CreatedAt,
            Sessions = db.Sessions.Count(s => s.DoctorId == d.UserId && s.MonthKey == month && !s.Deleted),
            Outstanding = db.Invoices.Where(i => i.DoctorId == d.UserId && outstanding.Contains(i.Status)).Sum(i => (int?)i.TotalDuePiasters) ?? 0,
        });
        rows = query.Sort switch
        {
            "newest" => rows.OrderByDescending(r => r.CreatedAt).ThenBy(r => r.UserId),
            "sessions" => rows.OrderByDescending(r => r.Sessions).ThenBy(r => r.FullName),
            "outstanding" => rows.OrderByDescending(r => r.Outstanding).ThenBy(r => r.FullName),
            _ => rows.OrderBy(r => r.FullName).ThenBy(r => r.UserId),
        };

        var page = await rows.ToPageAsync(query, cancellationToken);
        return Ok(new PagedResult<DoctorDirectoryItem>(
            page.Items.Select(r => new DoctorDirectoryItem(
                r.UserId, r.FullName, r.FullNameEn, r.Email, r.Phone, r.ClinicName, r.ClinicNameEn, r.Governorate, r.SpecialtyAr,
                r.SpecialtyEn, r.Status, r.TrialEndsAt, r.CreatedAt, r.Sessions, r.Outstanding)).ToList(),
            page.Page, page.PageSize, page.TotalCount));
    }

    /// <summary>AD5 Profile tab.</summary>
    [HttpGet("{doctorId:guid}")]
    public async Task<IActionResult> Profile(Guid doctorId, CancellationToken cancellationToken)
    {
        var doctor = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new AdminDoctorProfileView(
                d.UserId, d.FullName, d.FullNameEn, d.Title, d.TitleEn, d.LicenseNumber, d.SpecialtyId, d.Specialty.NameAr,
                d.Specialty.NameEn, d.User.Email, d.User.Phone, d.User.EmailVerifiedAt != null, d.Status, d.StatusReason,
                d.StatusChangedAt, d.TrialEndsAt, d.CreatedAt))
            .SingleOrDefaultAsync(cancellationToken);
        return doctor is null ? this.NotFoundProblem() : Ok(doctor);
    }

    /// <summary>AD5 "edit info": name, title, license number and specialty. Login details (email, phone) stay the doctor's own.</summary>
    [HttpPost("updateDoctorProfile")]
    public async Task<IActionResult> UpdateProfile(AdminUpdateDoctorProfileRequest request, CancellationToken cancellationToken)
    {
        var doctor = await db.Doctors.Include(d => d.User).SingleOrDefaultAsync(d => d.UserId == request.DoctorId, cancellationToken);
        if (doctor is null)
        {
            return this.NotFoundProblem();
        }

        if (request.SpecialtyId is { } specialtyId && !await db.Specialties.AnyAsync(s => s.Id == specialtyId, cancellationToken))
        {
            return ValidationProblems.Field(HttpContext, "specialtyId", ErrorCodes.NotFound, "Unknown specialty.");
        }

        var changed = new List<string>();
        void Set<T>(string name, T? value, Func<Doctor, T> get, Action<Doctor, T> set) where T : class
        {
            if (value is not null && !Equals(get(doctor), value))
            {
                set(doctor, value);
                changed.Add(name);
            }
        }

        Set("fullName", request.FullName is null ? null : Text.CollapseSpaces(request.FullName), d => d.FullName, (d, v) => d.FullName = v);
        Set("fullNameEn", Text.TrimToNull(request.FullNameEn), d => d.FullNameEn!, (d, v) => d.FullNameEn = v);
        Set("title", Text.TrimToNull(request.Title), d => d.Title, (d, v) => d.Title = v);
        Set("titleEn", Text.TrimToNull(request.TitleEn), d => d.TitleEn!, (d, v) => d.TitleEn = v);
        Set("licenseNumber", Text.TrimToNull(request.LicenseNumber), d => d.LicenseNumber, (d, v) => d.LicenseNumber = v);
        if (request.SpecialtyId is { } newSpecialty && newSpecialty != doctor.SpecialtyId)
        {
            doctor.SpecialtyId = newSpecialty;
            changed.Add("specialty");
        }

        if (changed.Count > 0)
        {
            doctor.UpdatedAt = time.GetUtcNow().UtcDateTime;
            if (request.FullName is not null)
            {
                doctor.User.DisplayName = doctor.FullName;
            }

            auditor.Add(AuditActions.DoctorProfileUpdated, AuditTargets.Doctor, doctor.UserId, new { fields = changed }, doctorId: doctor.UserId);
            await db.SaveChangesAsync(cancellationToken);
        }

        return await Profile(doctor.UserId, cancellationToken);
    }

    /// <summary>
    /// <c>getDoctorActivity</c> (spec 9.1, AD5 Activity tab): sessions per month for the last 12 months and the month's session list
    /// (date, time, type, fee, masked patient name). Admins never read <c>sessions</c> directly (AC-12).
    /// </summary>
    [HttpGet("{doctorId:guid}/activity")]
    public async Task<IActionResult> Activity(Guid doctorId, [FromQuery] DoctorSessionsQuery query, CancellationToken cancellationToken)
    {
        if (!await db.Doctors.AnyAsync(d => d.UserId == doctorId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var first = CairoTime.ParseMonthKey(query.Month) ?? new DateOnly(Today.Year, Today.Month, 1);
        var month = CairoTime.MonthKey(first);
        var firstDay = new DateOnly(Today.Year, Today.Month, 1).AddMonths(-11);
        var months = await db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == doctorId && !s.Deleted && s.DayKey >= firstDay)
            .GroupBy(s => s.MonthKey)
            .OrderByDescending(g => g.Key)
            .Select(g => new DoctorMonthActivity(
                g.Key, g.Count(s => s.Type == SessionTypes.Examination), g.Count(s => s.Type == SessionTypes.Consultation), g.Sum(s => s.FeePiasters)))
            .ToListAsync(cancellationToken);

        var page = await db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == doctorId && s.MonthKey == month && !s.Deleted)
            .OrderByDescending(s => s.CreatedAt)
            .Select(s => new { s.Id, s.DayKey, s.CreatedAt, s.Type, s.FeePiasters, Name = s.Link.PatientName, s.Deleted })
            .ToPageAsync(query, cancellationToken);
        return Ok(new DoctorActivityView(
            months,
            month,
            new PagedResult<DoctorSessionRow>(
                page.Items.Select(s => new DoctorSessionRow(s.Id, s.DayKey, s.CreatedAt, s.Type, s.FeePiasters, Masking.Name(s.Name), s.Deleted)).ToList(),
                page.Page, page.PageSize, page.TotalCount)));
    }

    /// <summary>AD5 Audit tab: deleted sessions with their reasons, and the status changes.</summary>
    [HttpGet("{doctorId:guid}/audit")]
    public async Task<IActionResult> Audit(Guid doctorId, [FromQuery] PageQuery query, CancellationToken cancellationToken)
    {
        if (!await db.Doctors.AnyAsync(d => d.UserId == doctorId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var deleted = await db.Sessions.AsNoTracking()
            .Where(s => s.DoctorId == doctorId && s.Deleted)
            .OrderByDescending(s => s.DeletedAt)
            .Select(s => new { s.Id, s.DayKey, s.Type, s.DeletedAt, s.DeleteReason, Name = s.Link.PatientName })
            .ToPageAsync(query, cancellationToken);
        string[] statusActions =
        [
            AuditActions.DoctorSuspended, AuditActions.DoctorReactivated, AuditActions.DoctorDisabled, AuditActions.DoctorServiceActivated,
            AuditActions.DoctorTrialExtended, AuditActions.InvoiceOverdue,
        ];
        var changes = await db.AuditLogs.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && statusActions.Contains(a.Action))
            .OrderByDescending(a => a.At)
            .Select(a => new DoctorAuditRow(a.At, a.Action, a.ActorRole, a.DetailsJson))
            .ToPageAsync(query, cancellationToken);
        return Ok(new DoctorAuditView(
            new PagedResult<DeletedSessionRow>(
                deleted.Items.Select(s => new DeletedSessionRow(s.Id, s.DayKey, s.Type, s.DeletedAt, s.DeleteReason, Masking.Name(s.Name))).ToList(),
                deleted.Page, deleted.PageSize, deleted.TotalCount),
            changes));
    }

    /// <summary>AD5 Branches tab (read-only).</summary>
    [HttpGet("{doctorId:guid}/branches")]
    public async Task<IActionResult> Branches(Guid doctorId, CancellationToken cancellationToken) =>
        Ok(await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == doctorId)
            .OrderByDescending(b => b.IsDefault).ThenBy(b => b.CreatedAt)
            .Select(b => new DoctorBranchRow(
                b.Id, b.NameAr, b.NameEn, b.Area, b.City, b.Status, b.IsDefault,
                b.BranchPhones.OrderBy(p => p.SortOrder).Select(p => p.Number).ToList()))
            .ToListAsync(cancellationToken));

    /// <summary>AD5 Appointments tab: counts only, no names (spec 9.4).</summary>
    [HttpGet("{doctorId:guid}/appointments")]
    public async Task<IActionResult> Appointments(Guid doctorId, CancellationToken cancellationToken)
    {
        var since = Today.AddMonths(-11);
        var from = new DateOnly(since.Year, since.Month, 1);
        var rows = await db.Appointments.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.LocalDate >= from)
            .Select(a => new { a.LocalDate, a.Status, a.FlaggedNoSession })
            .ToListAsync(cancellationToken);
        return Ok(rows
            .GroupBy(r => CairoTime.MonthKey(r.LocalDate))
            .OrderByDescending(g => g.Key)
            .Select(g =>
            {
                var noShows = g.Count(r => r.Status == AppointmentStatuses.NoShow);
                var counted = g.Count(r => r.Status is AppointmentStatuses.NoShow or AppointmentStatuses.Completed
                    or AppointmentStatuses.CheckedIn or AppointmentStatuses.WithDoctor);
                return new DoctorAppointmentsMonth(
                    g.Key,
                    g.Count(r => r.Status is not (AppointmentStatuses.Cancelled or AppointmentStatuses.Rejected)),
                    noShows,
                    g.Count(r => r.Status == AppointmentStatuses.Cancelled),
                    g.Count(r => r.FlaggedNoSession),
                    counted == 0 ? 0 : Math.Round(noShows / (double)counted, 3));
            })
            .ToList());
    }

    /// <summary>AD5 Assistants tab. Disable and enable go through <c>/api/admin/accounts/{id}/status</c>.</summary>
    [HttpGet("{doctorId:guid}/assistants")]
    public async Task<IActionResult> Assistants(Guid doctorId, CancellationToken cancellationToken) =>
        Ok(await db.Assistants.AsNoTracking()
            .Where(a => a.DoctorId == doctorId && a.Status != "removed")
            .OrderBy(a => a.FullName)
            .Select(a => new DoctorAssistantRow(a.UserId, a.FullName, a.Phone, a.Preset, a.Status, a.LastActiveAt))
            .ToListAsync(cancellationToken));

    /// <summary>AD5 internal notes, newest first. They are the admins' own and never reach the doctor.</summary>
    [HttpGet("{doctorId:guid}/notes")]
    public async Task<IActionResult> Notes(Guid doctorId, CancellationToken cancellationToken) =>
        Ok(await db.DoctorAdminNotes.AsNoTracking()
            .Where(n => n.DoctorId == doctorId)
            .OrderByDescending(n => n.CreatedAt)
            .Select(n => new DoctorNoteRow(n.Id, n.Text, n.CreatedByNavigation.DisplayName, n.CreatedAt))
            .ToListAsync(cancellationToken));

    [HttpPost("addDoctorNote")]
    public async Task<IActionResult> AddNote(AddDoctorNoteRequest request, CancellationToken cancellationToken)
    {
        if (!await db.Doctors.AnyAsync(d => d.UserId == request.DoctorId, cancellationToken))
        {
            return this.NotFoundProblem();
        }

        var note = new DoctorAdminNote
        {
            Id = Guid.NewGuid(),
            DoctorId = request.DoctorId!.Value,
            Text = request.Text!.Trim(),
            CreatedBy = User.UserId(),
            CreatedAt = time.GetUtcNow().UtcDateTime,
        };
        db.DoctorAdminNotes.Add(note);
        auditor.Add(AuditActions.DoctorNoteAdded, AuditTargets.Doctor, note.DoctorId, new { noteId = note.Id }, doctorId: note.DoctorId);
        await db.SaveChangesAsync(cancellationToken);
        return StatusCode(StatusCodes.Status201Created, new { note.Id });
    }

    /// <summary>
    /// AD5 "Send password reset email": the same email as "forgot password" (A8), without the doctor asking. 409 when the
    /// doctor has no email or the account is disabled.
    /// </summary>
    [HttpPost("sendPasswordReset")]
    public async Task<IActionResult> SendPasswordReset(DoctorIdRequest request, CancellationToken cancellationToken)
    {
        var user = await db.Users.SingleOrDefaultAsync(
            u => u.Id == request.DoctorId && u.Role == Roles.Doctor, cancellationToken);
        if (user is null)
        {
            return this.NotFoundProblem();
        }

        if (user.Email is null || user.Status != AccountStatuses.Active)
        {
            return this.ConflictProblem(ErrorCodes.DoctorStatusNotChangeable, "This doctor has no active email to send the link to.");
        }

        var minutes = authOptions.Value.PasswordResetTokenMinutes;
        var token = await emailTokens.IssueAsync(user.Id, UserTokenPurposes.PasswordReset, TimeSpan.FromMinutes(minutes), cancellationToken);
        auditor.Add(AuditActions.PasswordResetRequested, AuditTargets.User, user.Id, new { channel = "adminEmail" }, doctorId: user.Id);
        await db.SaveChangesAsync(cancellationToken);
        emailQueue.Enqueue(emailTemplates.PasswordReset(user.Email, user.DisplayName, user.Locale, token, minutes, user.Id));
        return Accepted(new AcceptedResponse("requested"));
    }
}

/// <summary>Masks a patient's name for the admin: «أحمد علي» → «أ*** ع***» (AD5).</summary>
public static class Masking
{
    public static string Name(string? name) =>
        string.Join(' ', (name ?? string.Empty)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries)
            .Select(word => word[..1] + "***"));
}
