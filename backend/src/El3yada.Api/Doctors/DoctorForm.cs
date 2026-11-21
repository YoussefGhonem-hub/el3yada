using System.Text.Json;
using El3yada.Api.Common;
using El3yada.Api.Storage;
using El3yada.Api.Validation;
using El3yada.Data;
using El3yada.Data.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Doctors;

/// <summary>The A4 form read from a multipart request, with its specialties loaded.</summary>
public sealed record DoctorFormInput(
    DoctorRegistrationData Data,
    IFormFile? License,
    string? LicenseType,
    Specialty Specialty,
    List<Specialty> ExtraSpecialties);

/// <summary>
/// The A4 form as one multipart request: a JSON part <c>data</c> (<see cref="DoctorRegistrationData"/>) and a file
/// part <c>license</c>. Shared by sign-up (A4), resubmitting (A7) and the admin's "Add doctor" (AD6), so the three
/// follow the same field rules.
/// </summary>
public static class DoctorForm
{
    /// <summary>The syndicate card or license: one image or PDF of at most 10 MB.</summary>
    public const long LicenseMaxBytes = 10L * 1024 * 1024;

    public const long RequestMaxBytes = LicenseMaxBytes + (1024 * 1024);

    /// <summary>
    /// Reads and checks the form. <paramref name="withPassword"/>: A4, where the password and the Terms are part of
    /// it; A7 and AD6 send neither. The license is optional here; callers that need it check
    /// <see cref="DoctorFormInput.License"/>.
    /// </summary>
    public static async Task<(DoctorFormInput? Input, IActionResult? Problem)> ReadAsync(
        ControllerBase controller, AppDbContext db, JsonSerializerOptions json, bool withPassword, CancellationToken cancellationToken)
    {
        var request = controller.Request;
        var http = controller.HttpContext;
        if (!request.HasFormContentType)
        {
            return Fail(controller.Problem(StatusCodes.Status415UnsupportedMediaType, ErrorCodes.UnsupportedMediaType, "Send multipart/form-data."));
        }

        IFormCollection form;
        try
        {
            form = await request.ReadFormAsync(cancellationToken);
        }
        catch (Exception ex) when (ex is InvalidDataException or BadHttpRequestException)
        {
            return Fail(controller.Problem(StatusCodes.Status413PayloadTooLarge, ErrorCodes.RequestTooLarge, "The request is too large."));
        }

        if (form["data"].ToString() is not { Length: > 0 } text)
        {
            return Fail(ValidationProblems.Field(http, "data", ErrorCodes.Required, "The data part is required."));
        }

        DoctorRegistrationData? data;
        try
        {
            data = JsonSerializer.Deserialize<DoctorRegistrationData>(text, json);
        }
        catch (JsonException)
        {
            data = null;
        }

        if (data is null)
        {
            return Fail(ValidationProblems.Field(http, "data", ErrorCodes.InvalidRequest, "The data part is not valid JSON."));
        }

        var result = await new DoctorRegistrationValidator(resubmit: !withPassword).ValidateAsync(data, cancellationToken);
        if (!result.IsValid)
        {
            return Fail(controller.ValidationProblem(result));
        }

        var license = form.Files.GetFile("license");
        string? licenseType = null;
        if (license is not null)
        {
            if (license.Length > LicenseMaxBytes)
            {
                return Fail(ValidationProblems.Field(http, "license", ErrorCodes.FileTooLarge, "The file is larger than 10 MB."));
            }

            var header = new byte[FileTypes.SignatureLength];
            await using (var stream = license.OpenReadStream())
            {
                var read = await stream.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
                licenseType = FileTypes.Detect(header.AsSpan(0, read));
            }

            if (licenseType is null)
            {
                return Fail(ValidationProblems.Field(http, "license", ErrorCodes.FileTypeNotAllowed, "Use a JPEG, PNG, WebP or PDF file."));
            }
        }

        var ids = (data.ExtraSpecialtyIds ?? []).Append(data.SpecialtyId!.Value).ToList();
        var specialties = await db.Specialties.Where(s => ids.Contains(s.Id) && s.Active).ToListAsync(cancellationToken);
        var primary = specialties.SingleOrDefault(s => s.Id == data.SpecialtyId);
        if (primary is null)
        {
            return Fail(ValidationProblems.Field(http, "specialtyId", ErrorCodes.InvalidSpecialty, "Choose a specialty from the list."));
        }

        var extras = specialties.Where(s => s.Id != primary.Id).ToList();
        if (extras.Count != (data.ExtraSpecialtyIds?.Count ?? 0))
        {
            return Fail(ValidationProblems.Field(http, "extraSpecialtyIds", ErrorCodes.InvalidSpecialty, "Choose specialties from the list."));
        }

        return (new DoctorFormInput(data, license, licenseType, primary, extras), null);

        static (DoctorFormInput?, IActionResult?) Fail(IActionResult problem) => (null, problem);
    }

    /// <summary>Saves the license file; returns a problem when the store refuses it.</summary>
    public static async Task<IActionResult?> SaveLicenseAsync(
        ControllerBase controller, IFileStorage storage, StoragePath path, IFormFile license, CancellationToken cancellationToken)
    {
        try
        {
            await using var stream = license.OpenReadStream();
            await storage.SaveAsync(path, stream, path.ContentType, LicenseMaxBytes, cancellationToken);
            return null;
        }
        catch (FileStorageException ex)
        {
            return ValidationProblems.Field(controller.HttpContext, "license", ex.Code, ex.Message);
        }
    }

    public static void ApplyProfessional(Doctor doctor, DoctorRegistrationData data)
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

    public static void ApplyBranch(Branch branch, BranchData data)
    {
        branch.NameAr = data.NameAr!.Trim();
        branch.NameEn = Text.TrimToNull(data.NameEn);
        branch.Governorate = data.Governorate!.Trim();
        branch.City = data.City!.Trim();
        branch.Area = Text.TrimToNull(data.Area);
        branch.AddressDetails = data.AddressDetails!.Trim();
        branch.Landmark = Text.TrimToNull(data.Landmark);
        branch.MapUrl = Text.TrimToNull(data.MapUrl);
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
}
