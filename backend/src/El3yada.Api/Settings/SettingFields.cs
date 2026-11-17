using System.Globalization;
using System.Text.Json;
using System.Text.RegularExpressions;
using El3yada.Api.Validation;
using El3yada.Data.Entities;

namespace El3yada.Api.Settings;

public enum SettingKind
{
    Integer,
    Boolean,
    Text,
    Email,
    Phone,
    WhatsApp,
    Version,
}

/// <summary>One AD13 setting: its JSON name (also SettingsHistory.Field), its rule, and the AppSettings column.</summary>
public sealed partial record SettingField(
    string Name,
    SettingKind Kind,
    Func<AppSetting, object?> Get,
    Action<AppSetting, object?> Set,
    int Min = 0,
    int Max = 0)
{
    [GeneratedRegex(@"^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,4}\z", RegexOptions.CultureInvariant)]
    private static partial Regex VersionPattern();

    /// <summary>
    /// Reads and checks a value sent by the admin. Text is trimmed, and empty text clears an optional field.
    /// Returns the value to store, or an error code and message.
    /// </summary>
    public (object? Value, string? Code, string? Message) Parse(JsonElement json)
    {
        switch (Kind)
        {
            case SettingKind.Integer:
                if (json.ValueKind != JsonValueKind.Number || !json.TryGetInt32(out var number))
                {
                    return (null, ErrorCodes.InvalidValue, "A whole number is required.");
                }

                return number < Min || number > Max
                    ? (null, ErrorCodes.OutOfRange, $"Must be from {Min} to {Max}.")
                    : (number, null, null);

            case SettingKind.Boolean:
                return json.ValueKind is JsonValueKind.True or JsonValueKind.False
                    ? (json.GetBoolean(), null, null)
                    : (null, ErrorCodes.InvalidValue, "true or false is required.");
        }

        if (json.ValueKind is not (JsonValueKind.String or JsonValueKind.Null))
        {
            return (null, ErrorCodes.InvalidValue, "Text or null is required.");
        }

        var text = Validation.Text.TrimToNull(json.ValueKind == JsonValueKind.Null ? null : json.GetString());
        if (text is null)
        {
            return Kind == SettingKind.Version
                ? (null, ErrorCodes.Required, "This field is required.")
                : (null, null, null);
        }

        return Kind switch
        {
            SettingKind.Text => text.Length > Max ? (null, ErrorCodes.TooLong, $"At most {Max} characters.") : (text, null, null),
            SettingKind.Email => RuleBuilderExtensions.IsEmail(text)
                ? (Validation.Text.NormalizeEmail(text), null, null)
                : (null, ErrorCodes.InvalidEmail, "Enter a valid email address."),
            SettingKind.Phone => EgyptianPhone.Normalize(text) is { } phone
                ? (phone, null, null)
                : (null, ErrorCodes.InvalidPhone, "Enter a valid Egyptian phone number."),
            SettingKind.WhatsApp => EgyptianPhone.NormalizeWithInternational(text) is { Length: <= 16 } whatsapp
                ? (whatsapp, null, null)
                : (null, ErrorCodes.InvalidPhone, "Enter a valid mobile number."),
            _ => VersionPattern().IsMatch(text)
                ? (text, null, null)
                : (null, ErrorCodes.InvalidVersion, "Use the form 1.2.3."),
        };
    }

    /// <summary>The value as SettingsHistory stores it (invariant text; null stays null).</summary>
    public static string? ToHistory(object? value) => value switch
    {
        null => null,
        bool flag => flag ? "true" : "false",
        int number => number.ToString(CultureInfo.InvariantCulture),
        _ => value.ToString(),
    };
}

/// <summary>
/// Every setting the admin can change in AD13 (updateSettings), with the ranges from spec section 11 and the
/// AppSettings CHECK constraints. Fees are in piasters: 0–1,000,000 is 0–10,000 EGP.
/// </summary>
public static class SettingFields
{
    public static readonly IReadOnlyList<SettingField> All =
    [
        Int("examFeePiasters", 0, 1_000_000, s => s.ExamFeePiasters, (s, v) => s.ExamFeePiasters = v),
        Int("consultationFeePiasters", 0, 1_000_000, s => s.ConsultationFeePiasters, (s, v) => s.ConsultationFeePiasters = v),
        Int("gracePeriodDays", 0, 31, s => s.GracePeriodDays, (s, v) => s.GracePeriodDays = v),
        // spec 6.16 BR-T1, BR-T2: applies to doctors approved after the change.
        Int("trialDays", 1, 90, s => s.TrialDays, (s, v) => s.TrialDays = v),
        Int("maxConsecutiveConsultations", 1, 5, s => s.MaxConsecutiveConsultations, (s, v) => s.MaxConsecutiveConsultations = v),
        Int("maxUploadMb", 1, 200, s => s.MaxUploadMb, (s, v) => s.MaxUploadMb = v),
        Int("maxAssistantsPerDoctor", 0, 50, s => s.MaxAssistantsPerDoctor, (s, v) => s.MaxAssistantsPerDoctor = v),
        Int("maxBranchesPerDoctor", 1, 50, s => s.MaxBranchesPerDoctor, (s, v) => s.MaxBranchesPerDoctor = v),
        Txt("instapayAddress", 200, s => s.InstapayAddress, (s, v) => s.InstapayAddress = v),
        Txt("instapayAccountName", 100, s => s.InstapayAccountName, (s, v) => s.InstapayAccountName = v),
        Txt("instapayInstructionsAr", 2000, s => s.InstapayInstructionsAr, (s, v) => s.InstapayInstructionsAr = v),
        Txt("instapayInstructionsEn", 2000, s => s.InstapayInstructionsEn, (s, v) => s.InstapayInstructionsEn = v),
        Str("supportPhone", SettingKind.Phone, s => s.SupportPhone, (s, v) => s.SupportPhone = v),
        Str("supportWhatsapp", SettingKind.WhatsApp, s => s.SupportWhatsapp, (s, v) => s.SupportWhatsapp = v),
        Str("supportEmail", SettingKind.Email, s => s.SupportEmail, (s, v) => s.SupportEmail = v),
        Str("minVersionAndroid", SettingKind.Version, s => s.MinVersionAndroid, (s, v) => s.MinVersionAndroid = v!),
        Str("minVersionIos", SettingKind.Version, s => s.MinVersionIos, (s, v) => s.MinVersionIos = v!),
        Str("minVersionWindows", SettingKind.Version, s => s.MinVersionWindows, (s, v) => s.MinVersionWindows = v!),
        Str("minVersionMacos", SettingKind.Version, s => s.MinVersionMacos, (s, v) => s.MinVersionMacos = v!),
        new("maintenanceEnabled", SettingKind.Boolean, s => s.MaintenanceEnabled, (s, v) => s.MaintenanceEnabled = (bool)v!),
        Txt("maintenanceMessageAr", 500, s => s.MaintenanceMessageAr, (s, v) => s.MaintenanceMessageAr = v),
        Txt("maintenanceMessageEn", 500, s => s.MaintenanceMessageEn, (s, v) => s.MaintenanceMessageEn = v),
        Txt("termsAr", MaxLegalText, s => s.TermsAr, (s, v) => s.TermsAr = v),
        Txt("termsEn", MaxLegalText, s => s.TermsEn, (s, v) => s.TermsEn = v),
        Txt("privacyAr", MaxLegalText, s => s.PrivacyAr, (s, v) => s.PrivacyAr = v),
        Txt("privacyEn", MaxLegalText, s => s.PrivacyEn, (s, v) => s.PrivacyEn = v),
    ];

    /// <summary>Terms and Privacy texts (A12): up to 100,000 characters each.</summary>
    public const int MaxLegalText = 100_000;

    public static readonly IReadOnlyDictionary<string, SettingField> ByName =
        All.ToDictionary(field => field.Name, StringComparer.Ordinal);

    private static SettingField Int(string name, int min, int max, Func<AppSetting, int> get, Action<AppSetting, int> set) =>
        new(name, SettingKind.Integer, s => get(s), (s, v) => set(s, (int)v!), min, max);

    private static SettingField Txt(string name, int maxLength, Func<AppSetting, string?> get, Action<AppSetting, string?> set) =>
        new(name, SettingKind.Text, s => get(s), (s, v) => set(s, (string?)v), Max: maxLength);

    private static SettingField Str(string name, SettingKind kind, Func<AppSetting, string?> get, Action<AppSetting, string?> set) =>
        new(name, kind, s => get(s), (s, v) => set(s, (string?)v));
}
