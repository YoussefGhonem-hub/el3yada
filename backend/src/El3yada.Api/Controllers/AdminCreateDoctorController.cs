using El3yada.Api.Audit;
using El3yada.Api.Auth;
using El3yada.Api.Common;
using El3yada.Api.Configuration;
using El3yada.Api.Doctors;
using El3yada.Api.Email;
using El3yada.Api.Notifications;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Controllers;

/// <summary>
/// AD6 "Add doctor" [S]: an admin creates a doctor account directly. Any admin (spec AD6 is not limited to super
/// admins). Contract: backend/docs/api-phase-1.md, "AD6 Add doctor".
/// </summary>
[ApiController]
[Route("api/admin")]
[Authorize(Policy = Policies.Admin)]
public sealed class AdminCreateDoctorController(
    AppDbContext db,
    IFileStorage storage,
    NotificationWriter notifications,
    Auditor auditor,
    EmailTokens emailTokens,
    EmailTemplates emailTemplates,
    EmailQueue emailQueue,
    TimeProvider time,
    IOptions<AuthOptions> authOptions,
    IOptions<JsonOptions> jsonOptions,
    ILogger<AdminCreateDoctorController> logger) : ControllerBase
{
    /// <summary>
    /// <c>multipart/form-data</c>: <c>data</c> (the A4 form without <c>password</c>, <c>acceptTerms</c> and
    /// <c>device</c>; same field rules) and <c>license</c> (required). The doctor is <c>active</c> at once with the
    /// service on and no free trial. They get an email with a link to choose their own password (a
    /// <c>passwordReset</c> token, valid Auth:DoctorInviteTokenHours). Writes a <c>doctorCreated</c> audit row.
    /// Answers 201 with the registration view (as in AD3).
    /// </summary>
    [HttpPost("createDoctor")]
    [RequestSizeLimit(DoctorForm.RequestMaxBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = DoctorForm.RequestMaxBytes)]
    public async Task<IActionResult> CreateDoctor(CancellationToken cancellationToken)
    {
        var (input, problem) = await DoctorForm.ReadAsync(this, db, jsonOptions.Value.JsonSerializerOptions, withPassword: false, cancellationToken);
        if (input is null)
        {
            return problem!;
        }

        if (input.License is null)
        {
            return ValidationProblems.Field(HttpContext, "license", ErrorCodes.Required, "Attach a photo of the syndicate card or license.");
        }

        var data = input.Data;
        var email = Text.NormalizeEmail(data.Email!);
        if (await db.Users.AnyAsync(u => u.Email == email, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.EmailAlreadyRegistered, "An account with this email already exists.");
        }

        var now = time.GetUtcNow().UtcDateTime;
        var adminId = User.UserId();
        var doctorId = Guid.NewGuid();
        var licensePath = StoragePath.DoctorLicense(doctorId, Guid.NewGuid(), input.LicenseType!);
        if (await DoctorForm.SaveLicenseAsync(this, storage, licensePath, input.License, cancellationToken) is { } refused)
        {
            return refused;
        }

        // No password: the doctor chooses one from the emailed link. Until then nobody can sign in with this account.
        var user = new User
        {
            Id = doctorId,
            Role = Roles.Doctor,
            Status = AccountStatuses.Active,
            DisplayName = Text.CollapseSpaces(data.FullName!),
            Email = email,
            Phone = EgyptianMobile.Normalize(data.Phone),
            SecurityStamp = Guid.NewGuid(),
            Locale = data.Locale ?? "ar",
            CreatedAt = now,
            UpdatedAt = now,
        };
        // Active with the service on (spec AD6): no free trial, so sessions carry the platform fees from the start.
        var doctor = new Doctor
        {
            UserId = doctorId,
            SpecialtyId = input.Specialty.Id,
            LicenseDocPath = licensePath.Value,
            Status = DoctorStatuses.Active,
            StatusChangedAt = now,
            ApprovedAt = now,
            ApprovedBy = adminId,
            TrialEndsAt = null,
            CreatedAt = now,
            UpdatedAt = now,
        };
        DoctorForm.ApplyProfessional(doctor, data);
        foreach (var extra in input.ExtraSpecialties)
        {
            doctor.Specialties.Add(extra);
        }

        var branch = new Branch { Id = Guid.NewGuid(), DoctorId = doctorId, IsDefault = true, CreatedAt = now, UpdatedAt = now };
        DoctorForm.ApplyBranch(branch, data.Branch!);

        var hours = authOptions.Value.DoctorInviteTokenHours;
        string token;
        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
            db.Users.Add(user);
            db.Doctors.Add(doctor);
            db.Branches.Add(branch);
            // Doctors.DefaultBranchId and Branches.DoctorId point at each other, so the default is set in a second save.
            await db.SaveChangesAsync(cancellationToken);
            doctor.DefaultBranchId = branch.Id;

            notifications.Add(doctorId, NotificationTexts.AccountCreated(), "/home", new { doctorId });
            auditor.Add(
                AuditActions.DoctorCreated, AuditTargets.Doctor, doctorId,
                new { specialtyId = doctor.SpecialtyId, branchId = branch.Id, serviceActive = true },
                doctorId: doctorId);
            token = await emailTokens.IssueAsync(doctorId, UserTokenPurposes.PasswordReset, TimeSpan.FromHours(hours), cancellationToken);
            await db.SaveChangesAsync(cancellationToken);
            await transaction.CommitAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (ex.IsUniqueViolation("UQ_Users_Email"))
        {
            await storage.DeleteAsync(licensePath, CancellationToken.None);
            return this.ConflictProblem(ErrorCodes.EmailAlreadyRegistered, "An account with this email already exists.");
        }
        catch
        {
            await storage.DeleteAsync(licensePath, CancellationToken.None);
            throw;
        }

        logger.LogInformation("Admin {AdminId} created doctor {DoctorId}", adminId, doctorId);
        emailQueue.Enqueue(emailTemplates.DoctorInvite(email, user.DisplayName, user.Locale, token, hours, doctorId));
        return StatusCode(StatusCodes.Status201Created, await DoctorRegistrationView.LoadAsync(db, doctorId, now, cancellationToken));
    }
}
