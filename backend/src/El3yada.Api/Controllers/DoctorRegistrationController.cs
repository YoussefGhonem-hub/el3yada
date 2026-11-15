using System.Text.Json;
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
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace El3yada.Api.Controllers;

/// <summary>
/// Doctor sign-up (A4, spec 9.1 <c>completeDoctorRegistration</c>), the pending and rejected screens (A6, A7)
/// and resubmitting after a rejection. Multipart requests: a JSON part <c>data</c>
/// (<see cref="DoctorRegistrationData"/>) and a file part <c>license</c>.
/// </summary>
[ApiController]
[Route("api/doctors")]
public sealed class DoctorRegistrationController(
    AppDbContext db,
    Passwords passwords,
    SessionService sessions,
    IFileStorage storage,
    NotificationWriter notifications,
    Auditor auditor,
    EmailTokens emailTokens,
    EmailTemplates emailTemplates,
    EmailQueue emailQueue,
    AccountStateCache stateCache,
    TimeProvider time,
    IOptions<AuthOptions> authOptions,
    IOptions<JsonOptions> jsonOptions,
    ILogger<DoctorRegistrationController> logger) : ControllerBase
{
    /// <summary>The syndicate card or license: one image or PDF of at most 10 MB.</summary>
    public const long LicenseMaxBytes = 10L * 1024 * 1024;

    private const long RequestMaxBytes = LicenseMaxBytes + (1024 * 1024);

    private DateTime Now => time.GetUtcNow().UtcDateTime;

    /// <summary>
    /// Creates the doctor account with status <c>pendingApproval</c>, the first branch, the license file,
    /// notifies the admins and sends the verification email (A5). Answers 201 with a session, so the app goes
    /// straight to A6.
    /// </summary>
    [HttpPost("completeDoctorRegistration")]
    [AllowAnonymous]
    [EnableRateLimiting(RateLimitPolicies.Registration)]
    [RequestSizeLimit(RequestMaxBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = RequestMaxBytes)]
    public async Task<IActionResult> CompleteDoctorRegistration(CancellationToken cancellationToken)
    {
        var input = await ReadInputAsync(resubmit: false, cancellationToken);
        if (input.Problem is not null)
        {
            return input.Problem;
        }

        var data = input.Data!;
        if (input.License is null)
        {
            return ValidationProblems.Field(HttpContext, "license", ErrorCodes.Required, "Attach a photo of the syndicate card or license.");
        }

        var email = Text.NormalizeEmail(data.Email!);
        if (await db.Users.AnyAsync(u => u.Email == email, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.EmailAlreadyRegistered, "An account with this email already exists.");
        }

        var now = Now;
        var doctorId = Guid.NewGuid();
        var licensePath = StoragePath.DoctorLicense(doctorId, Guid.NewGuid(), input.LicenseType!);
        var saved = await SaveLicenseAsync(licensePath, input.License, cancellationToken);
        if (saved is not null)
        {
            return saved;
        }

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
            AcceptedTermsAt = now,
            CreatedAt = now,
            UpdatedAt = now,
        };
        user.PasswordHash = passwords.Hash(user, data.Password!);
        var doctor = new Doctor
        {
            UserId = doctorId,
            SpecialtyId = data.SpecialtyId!.Value,
            LicenseDocPath = licensePath.Value,
            Status = DoctorStatuses.PendingApproval,
            StatusChangedAt = now,
            CreatedAt = now,
            UpdatedAt = now,
        };
        ApplyProfessional(doctor, data);
        foreach (var extra in input.ExtraSpecialties!)
        {
            doctor.Specialties.Add(extra);
        }

        var branch = new Branch { Id = Guid.NewGuid(), DoctorId = doctorId, IsDefault = true, CreatedAt = now, UpdatedAt = now };
        ApplyBranch(branch, data.Branch!);

        string verifyToken;
        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
            db.Users.Add(user);
            db.Doctors.Add(doctor);
            db.Branches.Add(branch);
            // Doctors.DefaultBranchId and Branches.DoctorId point at each other, so the default is set in a second save.
            await db.SaveChangesAsync(cancellationToken);
            doctor.DefaultBranchId = branch.Id;

            await NotifyAdminsAsync(NotificationTexts.RegistrationReceived(doctor.FullName, input.Specialty!.NameAr, input.Specialty.NameEn), doctorId, cancellationToken);
            auditor.Add(
                AuditActions.DoctorRegistrationSubmitted, AuditTargets.Doctor, doctorId,
                new { specialtyId = doctor.SpecialtyId, branchId = branch.Id },
                doctorId: doctorId, actor: new AuditActor(doctorId, Roles.Doctor));
            verifyToken = await emailTokens.IssueAsync(
                doctorId, UserTokenPurposes.EmailVerify, TimeSpan.FromHours(authOptions.Value.EmailVerificationTokenHours), cancellationToken);
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

        logger.LogInformation("Doctor {DoctorId} registered and waits for approval", doctorId);
        emailQueue.Enqueue(emailTemplates.VerifyEmail(
            email, user.DisplayName, user.Locale, verifyToken, authOptions.Value.EmailVerificationTokenHours, doctorId));

        var session = await sessions.SignInAsync(user, data.Device, null, HttpContext.ClientIp(), cancellationToken);
        return StatusCode(StatusCodes.Status201Created, session);
    }

    /// <summary>
    /// A7 "Edit and resubmit": a rejected doctor sends the corrected form (the <c>license</c> file only when it
    /// changes). The status goes back to <c>pendingApproval</c> and the admins are notified.
    /// </summary>
    [HttpPost("resubmitDoctorRegistration")]
    [Authorize(Policy = Policies.Doctor)]
    [RequestSizeLimit(RequestMaxBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = RequestMaxBytes)]
    public async Task<IActionResult> ResubmitDoctorRegistration(CancellationToken cancellationToken)
    {
        var doctorId = User.UserId();
        var doctor = await db.Doctors
            .Include(d => d.User)
            .Include(d => d.Specialties)
            .Include(d => d.DefaultBranch!).ThenInclude(b => b.BranchPhones)
            .SingleAsync(d => d.UserId == doctorId, cancellationToken);
        if (doctor.Status != DoctorStatuses.Rejected)
        {
            return this.ConflictProblem(ErrorCodes.RegistrationNotEditable, "Only a rejected registration can be edited and resubmitted.");
        }

        var input = await ReadInputAsync(resubmit: true, cancellationToken);
        if (input.Problem is not null)
        {
            return input.Problem;
        }

        var data = input.Data!;
        var user = doctor.User;
        var email = Text.NormalizeEmail(data.Email!);
        var emailChanged = email != user.Email;
        if (emailChanged && await db.Users.AnyAsync(u => u.Email == email && u.Id != doctorId, cancellationToken))
        {
            return this.ConflictProblem(ErrorCodes.EmailAlreadyRegistered, "An account with this email already exists.");
        }

        StoragePath? oldLicense = null;
        StoragePath? newLicense = null;
        if (input.License is not null)
        {
            newLicense = StoragePath.DoctorLicense(doctorId, Guid.NewGuid(), input.LicenseType!);
            var saved = await SaveLicenseAsync(newLicense, input.License, cancellationToken);
            if (saved is not null)
            {
                return saved;
            }

            oldLicense = StoragePath.TryParse(doctor.LicenseDocPath, out var old) ? old : null;
            doctor.LicenseDocPath = newLicense.Value;
        }

        var now = Now;
        user.DisplayName = Text.CollapseSpaces(data.FullName!);
        user.Phone = EgyptianMobile.Normalize(data.Phone);
        user.Locale = data.Locale ?? user.Locale;
        user.UpdatedAt = now;
        string? verifyToken = null;
        if (emailChanged)
        {
            user.Email = email;
            user.EmailVerifiedAt = null;
            verifyToken = await emailTokens.IssueAsync(
                doctorId, UserTokenPurposes.EmailVerify, TimeSpan.FromHours(authOptions.Value.EmailVerificationTokenHours), cancellationToken);
        }

        doctor.SpecialtyId = data.SpecialtyId!.Value;
        ApplyProfessional(doctor, data);
        doctor.Specialties.Clear();
        foreach (var extra in input.ExtraSpecialties!)
        {
            doctor.Specialties.Add(extra);
        }

        var branch = doctor.DefaultBranch;
        if (branch is null)
        {
            branch = new Branch { Id = Guid.NewGuid(), DoctorId = doctorId, IsDefault = true, CreatedAt = now };
            db.Branches.Add(branch);
        }
        else
        {
            db.BranchPhones.RemoveRange(branch.BranchPhones);
            branch.BranchPhones.Clear();
        }

        ApplyBranch(branch, data.Branch!);
        branch.UpdatedAt = now;

        doctor.Status = DoctorStatuses.PendingApproval;
        doctor.StatusReason = null;
        doctor.StatusChangedAt = now;
        doctor.UpdatedAt = now;

        await NotifyAdminsAsync(NotificationTexts.RegistrationResubmitted(doctor.FullName, input.Specialty!.NameAr, input.Specialty.NameEn), doctorId, cancellationToken);
        auditor.Add(
            AuditActions.DoctorRegistrationResubmitted, AuditTargets.Doctor, doctorId,
            new { licenseReplaced = newLicense is not null, emailChanged },
            doctorId: doctorId);

        try
        {
            await db.SaveChangesAsync(cancellationToken);
            if (doctor.DefaultBranchId != branch.Id)
            {
                doctor.DefaultBranchId = branch.Id;
                await db.SaveChangesAsync(cancellationToken);
            }
        }
        catch (DbUpdateException ex) when (ex.IsUniqueViolation("UQ_Users_Email"))
        {
            if (newLicense is not null)
            {
                await storage.DeleteAsync(newLicense, CancellationToken.None);
            }

            return this.ConflictProblem(ErrorCodes.EmailAlreadyRegistered, "An account with this email already exists.");
        }

        stateCache.Invalidate(doctorId);
        if (oldLicense is not null)
        {
            await storage.DeleteAsync(oldLicense, CancellationToken.None);
        }

        if (verifyToken is not null)
        {
            emailQueue.Enqueue(emailTemplates.VerifyEmail(
                email, user.DisplayName, user.Locale, verifyToken, authOptions.Value.EmailVerificationTokenHours, doctorId));
        }

        logger.LogInformation("Doctor {DoctorId} resubmitted the registration", doctorId);
        return Ok(await DoctorRegistrationView.LoadAsync(db, doctorId, cancellationToken));
    }

    /// <summary>The doctor's own registration (A6 read-only, A7 pre-fill), with the status and the rejection reason.</summary>
    [HttpGet("myRegistration")]
    [Authorize(Policy = Policies.Doctor)]
    public async Task<IActionResult> GetMyRegistration(CancellationToken cancellationToken)
    {
        var view = await DoctorRegistrationView.LoadAsync(db, User.UserId(), cancellationToken);
        return view is null ? this.NotFoundProblem() : Ok(view);
    }

    /// <summary>The doctor's own license file, streamed (never a public URL).</summary>
    [HttpGet("myRegistration/license")]
    [Authorize(Policy = Policies.Doctor)]
    public async Task<IActionResult> GetMyLicense(CancellationToken cancellationToken)
    {
        var path = await db.Doctors.Where(d => d.UserId == User.UserId()).Select(d => d.LicenseDocPath).SingleOrDefaultAsync(cancellationToken);
        return await LicenseFiles.StreamAsync(this, storage, path, cancellationToken);
    }

    private sealed record Input(
        DoctorRegistrationData? Data,
        IFormFile? License,
        string? LicenseType,
        Specialty? Specialty,
        List<Specialty>? ExtraSpecialties,
        IActionResult? Problem);

    /// <summary>Reads the multipart form, checks the data, the license type and the specialties.</summary>
    private async Task<Input> ReadInputAsync(bool resubmit, CancellationToken cancellationToken)
    {
        if (!Request.HasFormContentType)
        {
            return Fail(this.Problem(StatusCodes.Status415UnsupportedMediaType, ErrorCodes.UnsupportedMediaType, "Send multipart/form-data."));
        }

        IFormCollection form;
        try
        {
            form = await Request.ReadFormAsync(cancellationToken);
        }
        catch (Exception ex) when (ex is InvalidDataException or BadHttpRequestException)
        {
            return Fail(this.Problem(StatusCodes.Status413PayloadTooLarge, ErrorCodes.RequestTooLarge, "The request is too large."));
        }

        if (form["data"].ToString() is not { Length: > 0 } json)
        {
            return Fail(ValidationProblems.Field(HttpContext, "data", ErrorCodes.Required, "The data part is required."));
        }

        DoctorRegistrationData? data;
        try
        {
            data = JsonSerializer.Deserialize<DoctorRegistrationData>(json, jsonOptions.Value.JsonSerializerOptions);
        }
        catch (JsonException)
        {
            data = null;
        }

        if (data is null)
        {
            return Fail(ValidationProblems.Field(HttpContext, "data", ErrorCodes.InvalidRequest, "The data part is not valid JSON."));
        }

        var result = await new DoctorRegistrationValidator(resubmit).ValidateAsync(data, cancellationToken);
        if (!result.IsValid)
        {
            return Fail(this.ValidationProblem(result));
        }

        var license = form.Files.GetFile("license");
        string? licenseType = null;
        if (license is not null)
        {
            if (license.Length > LicenseMaxBytes)
            {
                return Fail(ValidationProblems.Field(HttpContext, "license", ErrorCodes.FileTooLarge, "The file is larger than 10 MB."));
            }

            var header = new byte[FileTypes.SignatureLength];
            await using (var stream = license.OpenReadStream())
            {
                var read = await stream.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
                licenseType = FileTypes.Detect(header.AsSpan(0, read));
            }

            if (licenseType is null)
            {
                return Fail(ValidationProblems.Field(HttpContext, "license", ErrorCodes.FileTypeNotAllowed, "Use a JPEG, PNG, WebP or PDF file."));
            }
        }

        var ids = (data.ExtraSpecialtyIds ?? []).Append(data.SpecialtyId!.Value).ToList();
        var specialties = await db.Specialties.Where(s => ids.Contains(s.Id) && s.Active).ToListAsync(cancellationToken);
        var primary = specialties.SingleOrDefault(s => s.Id == data.SpecialtyId);
        if (primary is null)
        {
            return Fail(ValidationProblems.Field(HttpContext, "specialtyId", ErrorCodes.InvalidSpecialty, "Choose a specialty from the list."));
        }

        var extras = specialties.Where(s => s.Id != primary.Id).ToList();
        if (extras.Count != (data.ExtraSpecialtyIds?.Count ?? 0))
        {
            return Fail(ValidationProblems.Field(HttpContext, "extraSpecialtyIds", ErrorCodes.InvalidSpecialty, "Choose specialties from the list."));
        }

        return new Input(data, license, licenseType, primary, extras, null);

        static Input Fail(IActionResult problem) => new(null, null, null, null, null, problem);
    }

    /// <summary>Saves the license file; returns a problem when the store refuses it.</summary>
    private async Task<IActionResult?> SaveLicenseAsync(StoragePath path, IFormFile license, CancellationToken cancellationToken)
    {
        try
        {
            await using var stream = license.OpenReadStream();
            await storage.SaveAsync(path, stream, path.ContentType, LicenseMaxBytes, cancellationToken);
            return null;
        }
        catch (FileStorageException ex)
        {
            return ValidationProblems.Field(HttpContext, "license", ex.Code, ex.Message);
        }
    }

    private static void ApplyProfessional(Doctor doctor, DoctorRegistrationData data)
    {
        doctor.FullName = Text.CollapseSpaces(data.FullName!);
        doctor.FullNameEn = Text.TrimToNull(data.FullNameEn);
        doctor.Title = data.Title!.Trim();
        doctor.TitleEn = Text.TrimToNull(data.TitleEn);
        doctor.DegreesAr = Text.TrimToNull(data.DegreesAr);
        doctor.DegreesEn = Text.TrimToNull(data.DegreesEn);
        doctor.LicenseNumber = LicenseNumbers.Normalize(data.LicenseNumber)!;
        doctor.ExaminationPricePiasters = data.ExaminationPricePiasters;
        doctor.ConsultationPricePiasters = data.ConsultationPricePiasters;
    }

    private static void ApplyBranch(Branch branch, BranchData data)
    {
        branch.NameAr = data.NameAr!.Trim();
        branch.NameEn = Text.TrimToNull(data.NameEn);
        branch.Governorate = data.Governorate!.Trim();
        branch.City = data.City!.Trim();
        branch.Area = Text.TrimToNull(data.Area);
        branch.Street = data.Street!.Trim();
        branch.Building = Text.TrimToNull(data.Building);
        branch.Floor = Text.TrimToNull(data.Floor);
        branch.Apartment = Text.TrimToNull(data.Apartment);
        branch.Landmark = Text.TrimToNull(data.Landmark);
        branch.Lat = data.Lat;
        branch.Lng = data.Lng;
        branch.Email = Text.TrimToNull(data.Email) is { } email ? Text.NormalizeEmail(email) : null;
        var order = 0;
        foreach (var phone in data.Phones!)
        {
            branch.BranchPhones.Add(new BranchPhone
            {
                Id = Guid.NewGuid(),
                BranchId = branch.Id,
                Number = EgyptianPhone.Normalize(phone.Number)!,
                Label = phone.Label ?? "reception",
                IsWhatsapp = phone.IsWhatsapp ?? false,
                SortOrder = order++,
            });
        }
    }

    private async Task NotifyAdminsAsync(NotificationText text, Guid doctorId, CancellationToken cancellationToken)
    {
        var admins = await db.Users
            .Where(u => u.Role == Roles.Admin && u.Status == AccountStatuses.Active)
            .Select(u => u.Id)
            .ToListAsync(cancellationToken);
        foreach (var adminId in admins)
        {
            notifications.Add(adminId, text, $"/admin/signups/{doctorId}", new { doctorId });
        }
    }
}

/// <summary>Streams a stored license file after the caller's access was checked.</summary>
internal static class LicenseFiles
{
    public static async Task<IActionResult> StreamAsync(
        ControllerBase controller, IFileStorage storage, string? storedPath, CancellationToken cancellationToken)
    {
        if (storedPath is null)
        {
            return controller.NotFoundProblem();
        }

        var file = StoragePath.TryParse(storedPath, out var path) ? await storage.OpenReadAsync(path, cancellationToken) : null;
        if (file is null)
        {
            return controller.Problem(StatusCodes.Status404NotFound, ErrorCodes.LicenseFileMissing, "The license file is missing.");
        }

        controller.Response.Headers.CacheControl = "no-store";
        return controller.File(file.Content, file.ContentType);
    }
}
