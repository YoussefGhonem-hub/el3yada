using El3yada.Api.Validation;

namespace El3yada.Api.Patients;

/// <summary>Patients.Gender values.</summary>
public static class Genders
{
    public const string Male = "male";
    public const string Female = "female";

    public static readonly string[] All = [Male, Female];
}

/// <summary>Patients.BloodType values (CK_Patients_BloodType).</summary>
public static class BloodTypes
{
    public static readonly string[] All = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"];
}

/// <summary>Patients.Status values.</summary>
public static class PatientStatuses
{
    public const string Active = "active";
}

/// <summary>
/// PatientMedicalProfileItems.Kind values and the JSON list each one is sent in. Allergies come first: the app
/// shows them in red everywhere (spec 6.1).
/// </summary>
public static class ProfileKinds
{
    public const string Allergy = "allergy";
    public const string ChronicDisease = "chronicDisease";
    public const string CurrentMedication = "currentMedication";
    public const string Surgery = "surgery";

    public static readonly string[] All = [Allergy, ChronicDisease, CurrentMedication, Surgery];
}

/// <summary>MedicalRecords.Category values (the D6 Files sub-tabs, Phase 3).</summary>
public static class FileCategories
{
    public const string Prescription = "prescription";
    public const string Lab = "lab";
    public const string Radiology = "radiology";
    public const string Other = "other";
}

public static class PatientAge
{
    /// <summary>Oldest accepted age (spec section 11: age 0–120).</summary>
    public const int MaxYears = 120;

    /// <summary>Whole years between the date of birth and <paramref name="today"/> (a Cairo date).</summary>
    public static int Years(DateOnly dateOfBirth, DateOnly today)
    {
        var years = today.Year - dateOfBirth.Year;
        return dateOfBirth.AddYears(years) > today ? years - 1 : years;
    }

    /// <summary>
    /// The date of birth stored when staff type an age instead of a date (D5): today minus that many years,
    /// with DateOfBirthEstimated set, so the age shown stays right until the next birthday guess.
    /// </summary>
    public static DateOnly EstimatedDateOfBirth(int ageYears, DateOnly today) => today.AddYears(-ageYears);

    /// <summary>In the past (or today) and at most 120 years ago.</summary>
    public static bool IsValidDateOfBirth(DateOnly dateOfBirth, DateOnly today) =>
        dateOfBirth <= today && dateOfBirth >= today.AddYears(-MaxYears);
}

public static class NationalId
{
    /// <summary>14 digits after turning Arabic-Indic digits into 0–9, or null when it isn't.</summary>
    public static string? Normalize(string? value)
    {
        if (value is null)
        {
            return null;
        }

        var digits = EgyptianMobile.NormalizeDigits(value).Replace(" ", "", StringComparison.Ordinal);
        return digits.Length == 14 && digits.All(char.IsAsciiDigit) ? digits : null;
    }
}
