using El3yada.Api.Auth;
using El3yada.Api.Clinic;
using El3yada.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Controllers;

public sealed record ClinicDoctorView(
    Guid Id, string FullName, string? FullNameEn, string Title, string? TitleEn, Guid SpecialtyId,
    string SpecialtyNameAr, string SpecialtyNameEn, string Status);

public sealed record ClinicAssistantView(Guid UserId, string FullName, string Preset, bool AllBranches, IReadOnlyList<Guid> BranchIds);

/// <summary>
/// One of the doctor's branches. <c>assigned</c>: the caller works there (always true for the doctor). Only
/// assigned, non-archived branches go in the current-branch picker (BR-BR3); the others are listed so
/// sessions from any branch can show the branch name.
/// </summary>
public sealed record ClinicBranchView(
    Guid Id, string NameAr, string? NameEn, bool IsDefault, string Status, string Governorate, string City, bool Assigned);

/// <summary>Platform fees per session (BR-S5, shown on the D8 type cards and the BR-S6 confirmation) and the consultation limit (BR-S3).</summary>
public sealed record ClinicFeesView(int ExaminationFeePiasters, int ConsultationFeePiasters, int MaxConsecutiveConsultations);

public sealed record ClinicLimitsView(int MaxAssistants, int MaxBranches, int MaxUploadMb);

/// <summary>
/// <c>GET /api/clinic/me</c>: what the app needs to draw a doctor or assistant shell (menus hidden by
/// permission, the current-branch picker, «عيادة د. …» for assistants, the suspension banner). Read it after
/// sign-in and on every resume; permissions can change at any time (BR-AS4), and the server checks them on
/// every request whatever the app shows.
/// </summary>
public sealed record ClinicContextView(
    string Role,
    ClinicDoctorView Doctor,
    ClinicAssistantView? Assistant,
    IReadOnlyDictionary<string, bool> Permissions,
    IReadOnlyList<ClinicBranchView> Branches,
    Guid? DefaultBranchId,
    ClinicFeesView Fees,
    ClinicLimitsView Limits);

[ApiController]
[Route("api/clinic")]
[Clinic]
public sealed class ClinicController(AppDbContext db) : ControllerBase
{
    [HttpGet("me")]
    public async Task<IActionResult> Me(CancellationToken cancellationToken)
    {
        var caller = HttpContext.Clinic();
        var doctor = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == caller.DoctorId)
            .Select(d => new
            {
                View = new ClinicDoctorView(
                    d.UserId, d.FullName, d.FullNameEn, d.Title, d.TitleEn, d.SpecialtyId,
                    d.Specialty.NameAr, d.Specialty.NameEn, d.Status),
                d.DefaultBranchId,
            })
            .SingleAsync(cancellationToken);

        var branches = await db.Branches.AsNoTracking()
            .Where(b => b.DoctorId == caller.DoctorId)
            .OrderByDescending(b => b.IsDefault).ThenBy(b => b.CreatedAt)
            .Select(b => new { b.Id, b.NameAr, b.NameEn, b.IsDefault, b.Status, b.Governorate, b.City })
            .ToListAsync(cancellationToken);

        var settings = await db.AppSettings.AsNoTracking().SingleAsync(cancellationToken);
        ClinicAssistantView? assistant = null;
        if (!caller.IsDoctor)
        {
            var preset = await db.Assistants.AsNoTracking()
                .Where(a => a.UserId == caller.UserId)
                .Select(a => a.Preset)
                .SingleAsync(cancellationToken);
            assistant = new ClinicAssistantView(
                caller.UserId, caller.AssistantName!, preset, caller.AllBranches, caller.BranchIds.ToList());
        }

        Response.Headers.CacheControl = "no-store";
        return Ok(new ClinicContextView(
            caller.Role,
            doctor.View,
            assistant,
            ClinicPermissions.ToMap(caller.Permissions),
            branches.Select(b => new ClinicBranchView(
                b.Id, b.NameAr, b.NameEn, b.IsDefault, b.Status, b.Governorate, b.City, caller.CanUseBranch(b.Id))).ToList(),
            doctor.DefaultBranchId,
            new ClinicFeesView(settings.ExamFeePiasters, settings.ConsultationFeePiasters, settings.MaxConsecutiveConsultations),
            new ClinicLimitsView(settings.MaxAssistantsPerDoctor, settings.MaxBranchesPerDoctor, settings.MaxUploadMb)));
    }
}
