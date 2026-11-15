using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Api.Common;
using El3yada.Api.Doctors;
using El3yada.Api.Notifications;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using FluentValidation;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

/// <summary>D22 personal and professional info. Every field is sent; optional texts are cleared with null or "".</summary>
public sealed record UpdateDoctorProfileRequest(
    string? FullName, string? FullNameEn, string? Title, string? TitleEn, string? DegreesAr, string? DegreesEn,
    Guid? SpecialtyId, List<Guid>? ExtraSpecialtyIds);

/// <summary>The same rules as the sign-up form (A4, <see cref="DoctorRegistrationValidator"/>).</summary>
public sealed class UpdateDoctorProfileRequestValidator : AbstractValidator<UpdateDoctorProfileRequest>
{
    public UpdateDoctorProfileRequestValidator()
    {
        RuleFor(x => x.FullName).Required().FullName();
        RuleFor(x => x.FullNameEn).MaxChars(60);
        RuleFor(x => x.Title).Required().MaxChars(40);
        RuleFor(x => x.TitleEn).MaxChars(40);
        RuleFor(x => x.DegreesAr).MaxChars(300);
        RuleFor(x => x.DegreesEn).MaxChars(300);
        RuleFor(x => x.SpecialtyId).Required();
        RuleFor(x => x.ExtraSpecialtyIds)
            .Must(ids => ids is null || ids.Count <= 2).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("At most 2 extra specialties.")
            .Must(ids => ids is null || ids.Distinct().Count() == ids.Count).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("A specialty is listed twice.")
            .Must((data, ids) => ids is null || data.SpecialtyId is null || !ids.Contains(data.SpecialtyId.Value))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("The primary specialty can't also be an extra one.");
    }
}

/// <summary>
/// D22. Editable: names, titles, degrees and specialties. Read-only here: <c>email</c>, <c>phone</c>,
/// <c>licenseNumber</c> and <c>status</c> (they changed at sign-up or by the admin).
/// </summary>
public sealed record DoctorProfileView(
    Guid DoctorId, string FullName, string? FullNameEn, string Title, string? TitleEn, string? DegreesAr, string? DegreesEn,
    SpecialtyView Specialty, IReadOnlyList<SpecialtyView> ExtraSpecialties, string? Email, bool EmailVerified, string? Phone,
    string LicenseNumber, string Status, DateTime UpdatedAt)
{
    public Guid SpecialtyId => Specialty.Id;

    public IEnumerable<Guid> ExtraSpecialtyIds => ExtraSpecialties.Select(s => s.Id);
}

/// <summary>
/// D22 "Profile and clinic": the doctor's personal and professional info (doctor only, BR-AS5; allowed while
/// suspended, BR-G5). The prescription header is Phase 3; clinic and branch details are in Branches (D28).
/// Password: <c>POST /api/auth/changePassword</c>.
/// </summary>
[ApiController]
[Route("api/doctor")]
[Clinic(DoctorOnly = true)]
public sealed class DoctorProfileController(
    AppDbContext db, Auditor auditor, NotificationWriter notifications, AccountStateCache stateCache, TimeProvider time) : ControllerBase
{
    [HttpGet("profile")]
    public async Task<IActionResult> Get(CancellationToken cancellationToken) =>
        Ok(await LoadAsync(HttpContext.Clinic().DoctorId, cancellationToken));

    /// <summary>
    /// Saves the profile and keeps Users.DisplayName equal to the name. A specialty change applies at once,
    /// is audited (<c>doctorSpecialtyChanged</c>) and notifies every active admin (D22).
    /// </summary>
    [HttpPost("updateProfile")]
    public async Task<IActionResult> Update(UpdateDoctorProfileRequest request, CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var doctor = await db.Doctors
            .Include(d => d.User)
            .Include(d => d.Specialty)
            .Include(d => d.Specialties)
            .SingleAsync(d => d.UserId == caller.DoctorId, cancellationToken);

        // A specialty the admin has since turned off may be kept, but not newly chosen.
        var extraIds = request.ExtraSpecialtyIds ?? [];
        var ids = extraIds.Append(request.SpecialtyId!.Value).ToList();
        var found = await db.Specialties.Where(s => ids.Contains(s.Id)).ToListAsync(cancellationToken);
        var primary = found.SingleOrDefault(s => s.Id == request.SpecialtyId && (s.Active || s.Id == doctor.SpecialtyId));
        if (primary is null)
        {
            return ValidationProblems.Field(HttpContext, "specialtyId", ErrorCodes.InvalidSpecialty, "Choose a specialty from the list.");
        }

        var currentExtras = doctor.Specialties.Select(s => s.Id).ToHashSet();
        var extras = extraIds
            .Select(id => found.SingleOrDefault(s => s.Id == id && (s.Active || currentExtras.Contains(s.Id))))
            .ToList();
        if (extras.Any(s => s is null))
        {
            return ValidationProblems.Field(HttpContext, "extraSpecialtyIds", ErrorCodes.InvalidSpecialty, "Choose specialties from the list.");
        }

        var fields = new List<string>();
        Set(doctor.FullName, Text.CollapseSpaces(request.FullName!), "fullName", value => doctor.FullName = value!);
        Set(doctor.FullNameEn, Text.TrimToNull(request.FullNameEn), "fullNameEn", value => doctor.FullNameEn = value);
        Set(doctor.Title, request.Title!.Trim(), "title", value => doctor.Title = value!);
        Set(doctor.TitleEn, Text.TrimToNull(request.TitleEn), "titleEn", value => doctor.TitleEn = value);
        Set(doctor.DegreesAr, Text.TrimToNull(request.DegreesAr), "degreesAr", value => doctor.DegreesAr = value);
        Set(doctor.DegreesEn, Text.TrimToNull(request.DegreesEn), "degreesEn", value => doctor.DegreesEn = value);

        var beforePrimary = doctor.Specialty;
        var beforeExtras = doctor.Specialties.OrderBy(s => s.SortOrder).ToList();
        var specialtyChanged = primary.Id != beforePrimary.Id;
        var extrasChanged = !currentExtras.SetEquals(extraIds);
        if (specialtyChanged)
        {
            doctor.SpecialtyId = primary.Id;
            doctor.Specialty = primary;
            fields.Add("specialtyId");
        }

        if (extrasChanged)
        {
            doctor.Specialties.Clear();
            foreach (var extra in extras)
            {
                doctor.Specialties.Add(extra!);
            }

            fields.Add("extraSpecialtyIds");
        }

        if (fields.Count == 0)
        {
            return Ok(await LoadAsync(doctor.UserId, cancellationToken));
        }

        var now = time.GetUtcNow().UtcDateTime;
        doctor.UpdatedAt = now;
        doctor.User.DisplayName = doctor.FullName;
        doctor.User.UpdatedAt = now;
        auditor.AddClinic(caller, AuditActions.DoctorProfileUpdated, AuditTargets.Doctor, doctor.UserId, new { fields });
        if (specialtyChanged || extrasChanged)
        {
            var afterExtras = extras.Select(s => s!).OrderBy(s => s.SortOrder).ToList();
            auditor.AddClinic(
                caller, AuditActions.DoctorSpecialtyChanged, AuditTargets.Doctor, doctor.UserId,
                new
                {
                    before = new { specialtyId = beforePrimary.Id, extraSpecialtyIds = beforeExtras.Select(s => s.Id) },
                    after = new { specialtyId = primary.Id, extraSpecialtyIds = afterExtras.Select(s => s.Id) },
                });
            await NotifyAdminsAsync(doctor, beforePrimary, beforeExtras, primary, afterExtras, cancellationToken);
        }

        await db.SaveChangesAsync(cancellationToken);
        stateCache.Invalidate(doctor.UserId);
        return Ok(await LoadAsync(doctor.UserId, cancellationToken));

        void Set(string? current, string? value, string name, Action<string?> apply)
        {
            if (current != value)
            {
                apply(value);
                fields.Add(name);
            }
        }
    }

    private async Task NotifyAdminsAsync(
        Doctor doctor, Specialty beforePrimary, List<Specialty> beforeExtras, Specialty afterPrimary, List<Specialty> afterExtras,
        CancellationToken cancellationToken)
    {
        var text = NotificationTexts.SpecialtyChanged(
            doctor.FullName,
            Names(beforePrimary, beforeExtras, s => s.NameAr, "، "), Names(beforePrimary, beforeExtras, s => s.NameEn, ", "),
            Names(afterPrimary, afterExtras, s => s.NameAr, "، "), Names(afterPrimary, afterExtras, s => s.NameEn, ", "));
        var admins = await db.Users
            .Where(u => u.Role == Roles.Admin && u.Status == AccountStatuses.Active)
            .Select(u => u.Id)
            .ToListAsync(cancellationToken);
        foreach (var adminId in admins)
        {
            notifications.Add(adminId, text, $"/admin/doctors/{doctor.UserId}", new { doctorId = doctor.UserId });
        }

        static string Names(Specialty primary, List<Specialty> extras, Func<Specialty, string> name, string separator) =>
            string.Join(separator, extras.Prepend(primary).Select(name));
    }

    private async Task<DoctorProfileView> LoadAsync(Guid doctorId, CancellationToken cancellationToken) =>
        await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new DoctorProfileView(
                d.UserId, d.FullName, d.FullNameEn, d.Title, d.TitleEn, d.DegreesAr, d.DegreesEn,
                new SpecialtyView(d.Specialty.Id, d.Specialty.NameAr, d.Specialty.NameEn),
                d.Specialties.OrderBy(s => s.SortOrder).Select(s => new SpecialtyView(s.Id, s.NameAr, s.NameEn)).ToList(),
                d.User.Email, d.User.EmailVerifiedAt != null, d.User.Phone, d.LicenseNumber, d.Status, d.UpdatedAt))
            .SingleAsync(cancellationToken);
}
