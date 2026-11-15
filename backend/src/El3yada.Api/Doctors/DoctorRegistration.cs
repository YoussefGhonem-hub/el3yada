using System.Text.RegularExpressions;
using El3yada.Api.Auth;
using El3yada.Api.Validation;
using El3yada.Data;
using FluentValidation;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Doctors;

/// <summary>
/// The A4 form, sent as the JSON part <c>data</c> of the multipart request (the license is the file part
/// <c>license</c>). The same shape, without <c>password</c> and <c>acceptTerms</c>, resubmits after a
/// rejection (A7), and <see cref="DoctorRegistrationView"/> returns it for pre-filling.
/// </summary>
public sealed record DoctorRegistrationData
{
    // Step 1, account
    public string? FullName { get; init; }
    public string? Email { get; init; }
    public string? Phone { get; init; }
    public string? Password { get; init; }

    /// <summary><c>ar</c> (default) or <c>en</c>: the language of emails and notifications.</summary>
    public string? Locale { get; init; }

    // Step 2, professional
    public string? Title { get; init; }
    public Guid? SpecialtyId { get; init; }

    /// <summary>Up to 2 [S], different from the primary specialty.</summary>
    public List<Guid>? ExtraSpecialtyIds { get; init; }

    /// <summary>Medical syndicate number.</summary>
    public string? LicenseNumber { get; init; }

    /// <summary>Optional, printed in the prescription header (6.4.1); also editable later in D22.</summary>
    public string? FullNameEn { get; init; }
    public string? TitleEn { get; init; }
    public string? DegreesAr { get; init; }
    public string? DegreesEn { get; init; }

    // Step 3, first branch and visit prices (section 6.15; saved as the doctor's prices, used by every branch without its own)
    public BranchData? Branch { get; init; }
    public int? ExaminationPricePiasters { get; init; }
    public int? ConsultationPricePiasters { get; init; }

    // Step 4
    public bool? AcceptTerms { get; init; }

    /// <summary>The device registering, so the session it gets is tied to it (optional).</summary>
    public DeviceInfo? Device { get; init; }
}

public sealed record BranchData
{
    public string? NameAr { get; init; }
    public string? NameEn { get; init; }
    public string? Governorate { get; init; }
    public string? City { get; init; }
    public string? Area { get; init; }
    public string? Street { get; init; }
    public string? Building { get; init; }
    public string? Floor { get; init; }
    public string? Apartment { get; init; }
    public string? Landmark { get; init; }
    public decimal? Lat { get; init; }
    public decimal? Lng { get; init; }
    public string? Email { get; init; }
    public List<BranchPhoneData>? Phones { get; init; }
}

/// <summary><c>label</c>: <c>reception</c> (default), <c>mobile</c> or <c>landline</c>.</summary>
public sealed record BranchPhoneData(string? Number, string? Label, bool? IsWhatsapp);

public static partial class LicenseNumbers
{
    [GeneratedRegex(@"^[A-Za-z0-9/-]{3,20}\z", RegexOptions.CultureInvariant)]
    private static partial Regex Pattern();

    /// <summary>Western digits, no spaces; null when it is not 3–20 letters, digits, "-" or "/".</summary>
    public static string? Normalize(string? value)
    {
        if (value is null)
        {
            return null;
        }

        var cleaned = EgyptianMobile.NormalizeDigits(value).Replace(" ", "", StringComparison.Ordinal).Trim();
        return Pattern().IsMatch(cleaned) ? cleaned : null;
    }
}

/// <summary>Spec section 11 rules for A4. <paramref name="resubmit"/>: A7, where the password and terms are not sent.</summary>
public sealed class DoctorRegistrationValidator : AbstractValidator<DoctorRegistrationData>
{
    public const int MaxPrice = 10_000_000; // 100,000 EGP (spec section 11, visit prices)

    public DoctorRegistrationValidator(bool resubmit)
    {
        RuleFor(x => x.FullName).Required().FullName();
        RuleFor(x => x.Email).Required().Email();
        RuleFor(x => x.Phone).Required().EgyptianMobile();
        if (!resubmit)
        {
            RuleFor(x => x.Password).Required().StrongPassword();
            RuleFor(x => x.AcceptTerms).Equal(true)
                .WithErrorCode(ErrorCodes.TermsNotAccepted).WithMessage("Accept the Terms and Privacy Policy.");
            RuleFor(x => x.Device!).SetValidator(new DeviceInfoValidator()).When(x => x.Device is not null);
        }

        RuleFor(x => x.Locale).OneOf("ar", "en");
        RuleFor(x => x.Title).Required().MaxChars(40);
        RuleFor(x => x.SpecialtyId).Required()
            .WithErrorCode(ErrorCodes.Required);
        RuleFor(x => x.ExtraSpecialtyIds)
            .Must(ids => ids is null || ids.Count <= 2).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("At most 2 extra specialties.")
            .Must(ids => ids is null || ids.Distinct().Count() == ids.Count).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("A specialty is listed twice.")
            .Must((data, ids) => ids is null || data.SpecialtyId is null || !ids.Contains(data.SpecialtyId.Value))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("The primary specialty can't also be an extra one.");
        RuleFor(x => x.LicenseNumber).Required()
            .Must(value => LicenseNumbers.Normalize(value) is not null)
            .WithErrorCode(ErrorCodes.InvalidLicenseNumber).WithMessage("Enter the syndicate number (3–20 letters or digits).");
        RuleFor(x => x.FullNameEn).MaxChars(60);
        RuleFor(x => x.TitleEn).MaxChars(40);
        RuleFor(x => x.DegreesAr).MaxChars(300);
        RuleFor(x => x.DegreesEn).MaxChars(300);
        RuleFor(x => x.ExaminationPricePiasters).InclusiveBetween(0, MaxPrice).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.ConsultationPricePiasters).InclusiveBetween(0, MaxPrice).WithErrorCode(ErrorCodes.OutOfRange);

        RuleFor(x => x.Branch).Required();
        RuleFor(x => x.Branch!).SetValidator(new BranchDataValidator()).When(x => x.Branch is not null);
    }
}

public sealed class BranchDataValidator : AbstractValidator<BranchData>
{
    public BranchDataValidator()
    {
        RuleFor(x => x.NameAr).Required()
            .Must(name => name is null || name.Trim().Length is >= 2 and <= 60)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("2–60 characters.");
        RuleFor(x => x.NameEn).MaxChars(60);
        RuleFor(x => x.Governorate).Required().MaxChars(50);
        RuleFor(x => x.City).Required().MaxChars(60);
        RuleFor(x => x.Area).MaxChars(60);
        RuleFor(x => x.Street).Required().MaxChars(150);
        RuleFor(x => x.Building).MaxChars(20);
        RuleFor(x => x.Floor).MaxChars(20);
        RuleFor(x => x.Apartment).MaxChars(20);
        RuleFor(x => x.Landmark).MaxChars(150);
        RuleFor(x => x.Email).Email();
        RuleFor(x => x.Lat).InclusiveBetween(-90m, 90m).WithErrorCode(ErrorCodes.OutOfRange)
            .Must((branch, lat) => lat.HasValue == branch.Lng.HasValue)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Send both lat and lng, or neither.");
        RuleFor(x => x.Lng).InclusiveBetween(-180m, 180m).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.Phones)
            .Must(phones => phones is { Count: > 0 }).WithErrorCode(ErrorCodes.PhoneRequired).WithMessage("Add at least one phone number.")
            .Must(phones => phones is null || phones.Count <= 5).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("At most 5 phone numbers.");
        RuleForEach(x => x.Phones).ChildRules(phone =>
        {
            phone.RuleFor(p => p.Number).Required()
                .Must(number => number is null || EgyptianPhone.Normalize(number) is not null)
                .WithErrorCode(ErrorCodes.InvalidPhone).WithMessage("Enter a valid Egyptian phone number.");
            phone.RuleFor(p => p.Label).OneOf("reception", "mobile", "landline");
        });
    }
}

/// <summary>A registration as the doctor submitted it (A6 read-only, A7 pre-fill, AD3).</summary>
public sealed record DoctorRegistrationView
{
    public required Guid DoctorId { get; init; }
    public required string Status { get; init; }
    public string? StatusReason { get; init; }

    /// <summary>When the registration was last submitted (first submission or the latest resubmission).</summary>
    public required DateTime SubmittedAt { get; init; }

    public DateTime? ApprovedAt { get; init; }
    public required string FullName { get; init; }
    public string? Email { get; init; }
    public bool EmailVerified { get; init; }
    public string? Phone { get; init; }
    public required string Locale { get; init; }
    public required string Title { get; init; }
    public required SpecialtyView Specialty { get; init; }
    public required IReadOnlyList<SpecialtyView> ExtraSpecialties { get; init; }
    public Guid SpecialtyId => Specialty.Id;
    public IEnumerable<Guid> ExtraSpecialtyIds => ExtraSpecialties.Select(s => s.Id);
    public required string LicenseNumber { get; init; }

    /// <summary>The license file's type (download it from the license endpoint, never by path).</summary>
    public required string LicenseContentType { get; init; }

    public string? FullNameEn { get; init; }
    public string? TitleEn { get; init; }
    public string? DegreesAr { get; init; }
    public string? DegreesEn { get; init; }
    public int? ExaminationPricePiasters { get; init; }
    public int? ConsultationPricePiasters { get; init; }
    public BranchView? Branch { get; init; }

    public static async Task<DoctorRegistrationView?> LoadAsync(AppDbContext db, Guid doctorId, CancellationToken cancellationToken)
    {
        var row = await db.Doctors.AsNoTracking()
            .Where(d => d.UserId == doctorId)
            .Select(d => new
            {
                d.UserId, d.Status, d.StatusReason, d.StatusChangedAt, d.CreatedAt, d.ApprovedAt,
                d.FullName, d.User.Email, d.User.EmailVerifiedAt, d.User.Phone, d.User.Locale,
                d.Title, d.TitleEn, d.FullNameEn, d.DegreesAr, d.DegreesEn, d.LicenseNumber, d.LicenseDocPath,
                d.ExaminationPricePiasters, d.ConsultationPricePiasters,
                Specialty = new SpecialtyView(d.Specialty.Id, d.Specialty.NameAr, d.Specialty.NameEn),
                Extras = d.Specialties.OrderBy(s => s.SortOrder).Select(s => new SpecialtyView(s.Id, s.NameAr, s.NameEn)).ToList(),
                d.DefaultBranchId,
            })
            .SingleOrDefaultAsync(cancellationToken);
        if (row is null)
        {
            return null;
        }

        var branch = row.DefaultBranchId is not { } branchId ? null : await db.Branches.AsNoTracking()
            .Where(b => b.Id == branchId)
            .Select(b => new BranchView
            {
                Id = b.Id,
                NameAr = b.NameAr,
                NameEn = b.NameEn,
                Governorate = b.Governorate,
                City = b.City,
                Area = b.Area,
                Street = b.Street,
                Building = b.Building,
                Floor = b.Floor,
                Apartment = b.Apartment,
                Landmark = b.Landmark,
                Lat = b.Lat,
                Lng = b.Lng,
                Email = b.Email,
                Phones = b.BranchPhones.OrderBy(p => p.SortOrder)
                    .Select(p => new BranchPhoneView(p.Number, p.Label, p.IsWhatsapp)).ToList(),
            })
            .SingleOrDefaultAsync(cancellationToken);

        return new DoctorRegistrationView
        {
            DoctorId = row.UserId,
            Status = row.Status,
            StatusReason = row.StatusReason,
            SubmittedAt = row.StatusChangedAt ?? row.CreatedAt,
            ApprovedAt = row.ApprovedAt,
            FullName = row.FullName,
            Email = row.Email,
            EmailVerified = row.EmailVerifiedAt is not null,
            Phone = row.Phone,
            Locale = row.Locale,
            Title = row.Title,
            TitleEn = row.TitleEn,
            FullNameEn = row.FullNameEn,
            DegreesAr = row.DegreesAr,
            DegreesEn = row.DegreesEn,
            LicenseNumber = row.LicenseNumber,
            LicenseContentType = Storage.StoragePath.TryParse(row.LicenseDocPath, out var path) ? path.ContentType : "application/octet-stream",
            ExaminationPricePiasters = row.ExaminationPricePiasters,
            ConsultationPricePiasters = row.ConsultationPricePiasters,
            Specialty = row.Specialty,
            ExtraSpecialties = row.Extras,
            Branch = branch,
        };
    }
}

public sealed record SpecialtyView(Guid Id, string NameAr, string NameEn);

public sealed record BranchView
{
    public Guid Id { get; init; }
    public required string NameAr { get; init; }
    public string? NameEn { get; init; }
    public required string Governorate { get; init; }
    public required string City { get; init; }
    public string? Area { get; init; }
    public required string Street { get; init; }
    public string? Building { get; init; }
    public string? Floor { get; init; }
    public string? Apartment { get; init; }
    public string? Landmark { get; init; }
    public decimal? Lat { get; init; }
    public decimal? Lng { get; init; }
    public string? Email { get; init; }
    public required IReadOnlyList<BranchPhoneView> Phones { get; init; }
}

public sealed record BranchPhoneView(string Number, string Label, bool IsWhatsapp);
