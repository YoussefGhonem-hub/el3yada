using System.Text.Json;
using El3yada.Api.Doctors;
using El3yada.Api.Validation;
using El3yada.Data.Entities;
using FluentValidation;

namespace El3yada.Api.ClinicAdmin;

/// <summary>Branches.Status values (BR-BR2).</summary>
public static class BranchStatuses
{
    public const string Active = "active";
    public const string TemporarilyClosed = "temporarilyClosed";
    public const string Archived = "archived";

    public static readonly string[] All = [Active, TemporarilyClosed, Archived];
}

/// <summary>The checklists of D29 "Clinic info for patients" (BR-BR2).</summary>
public static class BranchChecklists
{
    public static readonly string[] PaymentMethods = ["cash", "card", "instapay", "wallet"];

    /// <summary>[S] amenities.</summary>
    public static readonly string[] Amenities = ["elevator", "parking", "wheelchair", "kidsArea"];

    public static string[] Read(string? json) =>
        string.IsNullOrEmpty(json) ? [] : JsonSerializer.Deserialize<string[]>(json) ?? [];
}

// D29 saves one tab at a time, so a branch is sent in groups. createBranch takes info, address and contact
// (required) and clinicInfo (optional); updateBranch takes any of them, and a group that is sent replaces that
// group whole. The fields and limits are the ones the first branch has at sign-up (BranchDataValidator, A4).

/// <summary>Info tab: name (2–60), optional English name and short description.</summary>
public sealed record BranchInfoInput(string? NameAr, string? NameEn, string? Description);

/// <summary>
/// Address and map tab. <c>details</c> is «العنوان بالتفصيل» (street, building, floor, apartment in one text);
/// <c>mapUrl</c> is an optional Google Maps link.
/// </summary>
public sealed record BranchAddressInput(
    string? Governorate, string? City, string? Area, string? Details, string? Landmark, string? MapUrl);

/// <summary>Contact tab: 1–5 phones (mobile, landline or hotline) and an optional email.</summary>
public sealed record BranchContactInput(List<BranchPhoneData>? Phones, string? Email);

/// <summary>Clinic info for patients: payment methods and [S] amenities. The branch's prices go through updatePrices.</summary>
public sealed record BranchClinicInfoInput(List<string>? PaymentMethods, List<string>? Amenities);

public sealed class BranchInfoInputValidator : AbstractValidator<BranchInfoInput>
{
    public BranchInfoInputValidator()
    {
        RuleFor(x => x.NameAr).Required()
            .Must(name => name is null || name.Trim().Length is >= 2 and <= 60)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("2–60 characters.");
        RuleFor(x => x.NameEn).MaxChars(60);
        RuleFor(x => x.Description).MaxChars(500);
    }
}

public sealed class BranchAddressInputValidator : AbstractValidator<BranchAddressInput>
{
    public BranchAddressInputValidator()
    {
        RuleFor(x => x.Governorate).Required().MaxChars(50);
        RuleFor(x => x.City).Required().MaxChars(60);
        RuleFor(x => x.Area).MaxChars(60);
        RuleFor(x => x.Details).Required().MaxChars(300);
        RuleFor(x => x.Landmark).MaxChars(150);
        RuleFor(x => x.MapUrl).MaxChars(MapLinks.MaxLength).GoogleMapsLink();
    }
}

public sealed class BranchContactInputValidator : AbstractValidator<BranchContactInput>
{
    public BranchContactInputValidator()
    {
        RuleFor(x => x.Phones)
            .Must(phones => phones is { Count: > 0 }).WithErrorCode(ErrorCodes.PhoneRequired).WithMessage("Add at least one phone number.")
            .Must(phones => phones is null || phones.Count <= 5).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("At most 5 phone numbers.");
        // Continue: every phone gets its own error, not only the first one that fails.
        RuleForEach(x => x.Phones).Cascade(CascadeMode.Continue).NotNull().WithErrorCode(ErrorCodes.Required).WithMessage("This field is required.").ChildRules(phone =>
        {
            phone.RuleFor(p => p.Number).Required()
                .Must(number => number is null || EgyptianPhone.Normalize(number) is not null)
                .WithErrorCode(ErrorCodes.InvalidPhone).WithMessage("Enter a valid Egyptian phone number.");
            phone.RuleFor(p => p.Label).OneOf("reception", "mobile", "landline");
        });
        RuleFor(x => x.Email).Email();
    }
}

public sealed class BranchClinicInfoInputValidator : AbstractValidator<BranchClinicInfoInput>
{
    public BranchClinicInfoInputValidator()
    {
        RuleFor(x => x.PaymentMethods).Must(list => IsChecklist(list, BranchChecklists.PaymentMethods))
            .WithErrorCode(ErrorCodes.InvalidValue)
            .WithMessage($"Choose from: {string.Join(", ", BranchChecklists.PaymentMethods)}, each once.");
        RuleFor(x => x.Amenities).Must(list => IsChecklist(list, BranchChecklists.Amenities))
            .WithErrorCode(ErrorCodes.InvalidValue)
            .WithMessage($"Choose from: {string.Join(", ", BranchChecklists.Amenities)}, each once.");
    }

    private static bool IsChecklist(List<string>? values, string[] allowed) =>
        values is null || (values.All(allowed.Contains) && values.Distinct().Count() == values.Count);
}

/// <summary>Writes a group of branch fields, cleaned as at sign-up (trimmed, phones in E.164, email in lower case).</summary>
public static class BranchFields
{
    public static void ApplyInfo(Branch branch, BranchInfoInput info)
    {
        branch.NameAr = info.NameAr!.Trim();
        branch.NameEn = Text.TrimToNull(info.NameEn);
        branch.Description = Text.TrimToNull(info.Description);
    }

    public static void ApplyAddress(Branch branch, BranchAddressInput address)
    {
        branch.Governorate = address.Governorate!.Trim();
        branch.City = address.City!.Trim();
        branch.Area = Text.TrimToNull(address.Area);
        branch.AddressDetails = address.Details!.Trim();
        branch.Landmark = Text.TrimToNull(address.Landmark);
        branch.MapUrl = Text.TrimToNull(address.MapUrl);
    }

    /// <summary>Adds the phones to an empty <c>BranchPhones</c> (remove the old rows first) and sets the email.</summary>
    public static void ApplyContact(Branch branch, BranchContactInput contact)
    {
        branch.Email = Text.TrimToNull(contact.Email) is { } email ? Text.NormalizeEmail(email) : null;
        var order = 0;
        foreach (var phone in contact.Phones!)
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

    /// <summary>Payment methods (none sent = none listed) and amenities, in the checklist's order.</summary>
    public static void ApplyClinicInfo(Branch branch, BranchClinicInfoInput clinicInfo)
    {
        var methods = BranchChecklists.PaymentMethods.Where(m => clinicInfo.PaymentMethods?.Contains(m) == true).ToArray();
        var amenities = BranchChecklists.Amenities.Where(a => clinicInfo.Amenities?.Contains(a) == true).ToArray();
        branch.PaymentMethodsJson = JsonSerializer.Serialize(methods);
        branch.AmenitiesJson = amenities.Length == 0 ? null : JsonSerializer.Serialize(amenities);
    }
}

/// <summary><c>createBranch</c> (doctor only): the Info, Address and Contact tabs, and optionally Clinic info.</summary>
public sealed record CreateBranchRequest(
    BranchInfoInput? Info, BranchAddressInput? Address, BranchContactInput? Contact, BranchClinicInfoInput? ClinicInfo);

public sealed class CreateBranchRequestValidator : AbstractValidator<CreateBranchRequest>
{
    public CreateBranchRequestValidator()
    {
        RuleFor(x => x.Info).Required();
        RuleFor(x => x.Info!).SetValidator(new BranchInfoInputValidator()).When(x => x.Info is not null);
        RuleFor(x => x.Address).Required();
        RuleFor(x => x.Address!).SetValidator(new BranchAddressInputValidator()).When(x => x.Address is not null);
        RuleFor(x => x.Contact).Required();
        RuleFor(x => x.Contact!).SetValidator(new BranchContactInputValidator()).When(x => x.Contact is not null);
        RuleFor(x => x.ClinicInfo!).SetValidator(new BranchClinicInfoInputValidator()).When(x => x.ClinicInfo is not null);
    }
}

/// <summary><c>updateBranch</c> (doctor only): one or more groups; each group sent replaces that group.</summary>
public sealed record UpdateBranchRequest(
    Guid? BranchId, BranchInfoInput? Info, BranchAddressInput? Address, BranchContactInput? Contact, BranchClinicInfoInput? ClinicInfo);

public sealed class UpdateBranchRequestValidator : AbstractValidator<UpdateBranchRequest>
{
    public UpdateBranchRequestValidator()
    {
        RuleFor(x => x.BranchId).Required();
        RuleFor(x => x).Must(x => x.Info is not null || x.Address is not null || x.Contact is not null || x.ClinicInfo is not null)
            .OverridePropertyName("body")
            .WithErrorCode(ErrorCodes.Required).WithMessage("Send at least one of info, address, contact or clinicInfo.");
        RuleFor(x => x.Info!).SetValidator(new BranchInfoInputValidator()).When(x => x.Info is not null);
        RuleFor(x => x.Address!).SetValidator(new BranchAddressInputValidator()).When(x => x.Address is not null);
        RuleFor(x => x.Contact!).SetValidator(new BranchContactInputValidator()).When(x => x.Contact is not null);
        RuleFor(x => x.ClinicInfo!).SetValidator(new BranchClinicInfoInputValidator()).When(x => x.ClinicInfo is not null);
    }
}

/// <summary>
/// <c>setBranchStatus</c> (doctor only). <c>temporarilyClosed</c> needs <c>closedMessage</c> (shown to patients,
/// BR-BR10) and may have <c>reopenDate</c> (a Cairo date, today or later). Other statuses clear both.
/// </summary>
public sealed record SetBranchStatusRequest(Guid? BranchId, string? Status, string? ClosedMessage, DateOnly? ReopenDate);

public sealed class SetBranchStatusRequestValidator : AbstractValidator<SetBranchStatusRequest>
{
    public SetBranchStatusRequestValidator(TimeProvider time)
    {
        RuleFor(x => x.BranchId).Required();
        RuleFor(x => x.Status).Required().OneOf(BranchStatuses.All);
        RuleFor(x => x.ClosedMessage).Required().MaxChars(300).When(x => x.Status == BranchStatuses.TemporarilyClosed);
        RuleFor(x => x.ReopenDate)
            .Must(date => date is null || date >= Common.CairoTime.Today(time))
            .WithErrorCode(ErrorCodes.OutOfRange).WithMessage("The reopening date can't be in the past.")
            .When(x => x.Status == BranchStatuses.TemporarilyClosed);
    }
}

public sealed record SetDefaultBranchRequest(Guid? BranchId);

public sealed class SetDefaultBranchRequestValidator : AbstractValidator<SetDefaultBranchRequest>
{
    public SetDefaultBranchRequestValidator() => RuleFor(x => x.BranchId).Required();
}
