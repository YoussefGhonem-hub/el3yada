using El3yada.Api.Common;
using El3yada.Api.Validation;
using FluentValidation;

namespace El3yada.Api.Patients;

/// <summary>
/// The identity fields of D5 and D7 (spec 7.3), shared by createPatient and updatePatient. Send
/// <see cref="DateOfBirth"/> or <see cref="AgeYears"/>, not both; an age sets DateOfBirthEstimated.
/// </summary>
public interface IPatientIdentity
{
    string? FullName { get; }
    string? Gender { get; }
    DateOnly? DateOfBirth { get; }
    int? AgeYears { get; }
    string? NationalId { get; }
    string? Address { get; }
    string? BloodType { get; }
    string? EmergencyContactName { get; }
    string? EmergencyContactPhone { get; }
}

/// <summary>
/// Spec section 11 rules for <see cref="IPatientIdentity"/>. Included by the request validators. With
/// <paramref name="required"/> false (createPatient), only the format of what is sent is checked here: linking
/// an existing number needs the phone alone (D32), and the action checks the required fields once it knows the
/// account is new (<see cref="MissingFields"/>).
/// </summary>
public sealed class PatientIdentityValidator : AbstractValidator<IPatientIdentity>
{
    public PatientIdentityValidator(TimeProvider time, bool required = true)
    {
        if (required)
        {
            RuleFor(x => x.FullName).Required();
            RuleFor(x => x.Gender).Required();
            RuleFor(x => x.DateOfBirth)
                .Must((x, dob) => dob is not null || x.AgeYears is not null)
                .WithErrorCode(ErrorCodes.Required).WithMessage("Enter the date of birth or the age.");
        }

        RuleFor(x => x.FullName).FullName();
        RuleFor(x => x.Gender).OneOf(Genders.All);
        RuleFor(x => x.DateOfBirth)
            .Must(dob => dob is null || PatientAge.IsValidDateOfBirth(dob.Value, CairoTime.Today(time)))
            .WithErrorCode(ErrorCodes.InvalidDateOfBirth).WithMessage("Enter a date of birth in the past, at most 120 years ago.");
        RuleFor(x => x.AgeYears)
            .Must((x, age) => age is null || x.DateOfBirth is null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Send the date of birth or the age, not both.")
            .InclusiveBetween(0, PatientAge.MaxYears).When(x => x.AgeYears is not null)
            .WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.NationalId)
            .Must(id => string.IsNullOrWhiteSpace(id) || Patients.NationalId.Normalize(id) is not null)
            .WithErrorCode(ErrorCodes.InvalidNationalId).WithMessage("The national ID must be 14 digits.");
        RuleFor(x => x.Address).MaxChars(300);
        RuleFor(x => x.BloodType).OneOf(BloodTypes.All).When(x => !string.IsNullOrWhiteSpace(x.BloodType));
        RuleFor(x => x.EmergencyContactName).MaxChars(60);
        RuleFor(x => x.EmergencyContactPhone)
            .Must(phone => string.IsNullOrWhiteSpace(phone) || EgyptianPhone.Normalize(phone) is not null)
            .WithErrorCode(ErrorCodes.InvalidPhone).WithMessage("Enter a valid phone number.");
    }

    /// <summary>The fields a new account needs that <paramref name="input"/> leaves out (REQUIRED failures).</summary>
    public static List<FluentValidation.Results.ValidationFailure> MissingFields(IPatientIdentity input)
    {
        var missing = new List<(string Field, bool Missing, string Message)>
        {
            (nameof(IPatientIdentity.FullName), string.IsNullOrWhiteSpace(input.FullName), "This field is required."),
            (nameof(IPatientIdentity.Gender), string.IsNullOrWhiteSpace(input.Gender), "This field is required."),
            (nameof(IPatientIdentity.DateOfBirth), input.DateOfBirth is null && input.AgeYears is null, "Enter the date of birth or the age."),
        };
        return missing.Where(m => m.Missing)
            .Select(m => new FluentValidation.Results.ValidationFailure(m.Field, m.Message) { ErrorCode = ErrorCodes.Required })
            .ToList();
    }
}

/// <summary>
/// createPatient (D5, AS3, D32). For a number that already has a patient account, only <see cref="Phone"/> is
/// needed and the other fields are ignored (BR-P3: the account's identity is kept). A new account also needs
/// <see cref="FullName"/>, <see cref="Gender"/> and <see cref="DateOfBirth"/> or <see cref="AgeYears"/>.
/// </summary>
public sealed record CreatePatientRequest(
    string? FullName,
    string? Phone,
    string? Gender,
    DateOnly? DateOfBirth,
    int? AgeYears,
    string? NationalId,
    string? Address,
    string? BloodType,
    string? EmergencyContactName,
    string? EmergencyContactPhone) : IPatientIdentity;

public sealed class CreatePatientRequestValidator : AbstractValidator<CreatePatientRequest>
{
    public CreatePatientRequestValidator(TimeProvider time)
    {
        RuleFor(x => x.Phone).Required().EgyptianMobile();
        Include(new PatientIdentityValidator(time, required: false));
    }
}

/// <summary>updatePatient (D7): every identity field except the phone. Optional fields left out are cleared.</summary>
public sealed record UpdatePatientRequest(
    Guid? PatientId,
    string? FullName,
    string? Gender,
    DateOnly? DateOfBirth,
    int? AgeYears,
    string? NationalId,
    string? Address,
    string? BloodType,
    string? EmergencyContactName,
    string? EmergencyContactPhone) : IPatientIdentity;

public sealed class UpdatePatientRequestValidator : AbstractValidator<UpdatePatientRequest>
{
    public UpdatePatientRequestValidator(TimeProvider time)
    {
        RuleFor(x => x.PatientId).Required();
        Include(new PatientIdentityValidator(time));
    }
}

public sealed record UpdatePatientPhoneRequest(Guid? PatientId, string? Phone);

public sealed class UpdatePatientPhoneRequestValidator : AbstractValidator<UpdatePatientPhoneRequest>
{
    public UpdatePatientPhoneRequestValidator()
    {
        RuleFor(x => x.PatientId).Required();
        RuleFor(x => x.Phone).Required().EgyptianMobile();
    }
}

public sealed record PatientIdRequest(Guid? PatientId);

public sealed class PatientIdRequestValidator : AbstractValidator<PatientIdRequest>
{
    public PatientIdRequestValidator() => RuleFor(x => x.PatientId).Required();
}

public sealed record SetArchivedRequest(Guid? PatientId, bool? Archived);

public sealed class SetArchivedRequestValidator : AbstractValidator<SetArchivedRequest>
{
    public SetArchivedRequestValidator()
    {
        RuleFor(x => x.PatientId).Required();
        RuleFor(x => x.Archived).NotNull().WithErrorCode(ErrorCodes.Required).WithMessage("This field is required.");
    }
}

public sealed class LookupPhoneQuery
{
    public string? Phone { get; init; }
}

public sealed class LookupPhoneQueryValidator : AbstractValidator<LookupPhoneQuery>
{
    public LookupPhoneQueryValidator() => RuleFor(x => x.Phone).Required().EgyptianMobile();
}

/// <summary>
/// updateMedicalProfile (D7): every list and text is replaced. A list or text left out is cleared, so send the
/// whole profile.
/// </summary>
public sealed record UpdateMedicalProfileRequest(
    Guid? PatientId,
    IReadOnlyList<string?>? Allergies,
    IReadOnlyList<string?>? ChronicDiseases,
    IReadOnlyList<string?>? CurrentMedications,
    IReadOnlyList<string?>? Surgeries,
    string? FamilyHistory,
    string? Notes);

public sealed class UpdateMedicalProfileRequestValidator : AbstractValidator<UpdateMedicalProfileRequest>
{
    /// <summary>Items per list. Far more than a real profile needs; it keeps a request small.</summary>
    public const int MaxItems = 50;

    public UpdateMedicalProfileRequestValidator()
    {
        RuleFor(x => x.PatientId).Required();
        RuleFor(x => x.FamilyHistory).MaxChars(2000);
        RuleFor(x => x.Notes).MaxChars(2000);
        RuleFor(x => x.Allergies).Must(HasRoom).WithErrorCode(ErrorCodes.OutOfRange).WithMessage(TooMany);
        RuleFor(x => x.ChronicDiseases).Must(HasRoom).WithErrorCode(ErrorCodes.OutOfRange).WithMessage(TooMany);
        RuleFor(x => x.CurrentMedications).Must(HasRoom).WithErrorCode(ErrorCodes.OutOfRange).WithMessage(TooMany);
        RuleFor(x => x.Surgeries).Must(HasRoom).WithErrorCode(ErrorCodes.OutOfRange).WithMessage(TooMany);
        RuleForEach(x => x.Allergies).Required().MaxChars(200);
        RuleForEach(x => x.ChronicDiseases).Required().MaxChars(200);
        RuleForEach(x => x.CurrentMedications).Required().MaxChars(200);
        RuleForEach(x => x.Surgeries).Required().MaxChars(200);
    }

    private static readonly string TooMany = $"At most {MaxItems} items.";

    private static bool HasRoom(IReadOnlyList<string?>? items) => items is null || items.Count <= MaxItems;
}
