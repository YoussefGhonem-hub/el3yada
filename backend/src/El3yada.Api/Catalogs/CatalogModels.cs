using System.Text.RegularExpressions;
using El3yada.Api.Common;
using El3yada.Api.Validation;
using FluentValidation;

namespace El3yada.Api.Catalogs;

/// <summary>The local catalog database contract (spec 9.5) as the API checks it when a version is published.</summary>
public static class CatalogSchema
{
    /// <summary>
    /// The <c>meta.schema_version</c> the apps of this release read. Bump it together with the app's reader and
    /// <c>packages/catalog_core</c> when the builder's tables change.
    /// </summary>
    public const int ExpectedVersion = 1;

    /// <summary>A new version may have up to 5% fewer rows in a table than the current one without confirmation (9.1 publishCatalog).</summary>
    public const double AllowedDrop = 0.05;

    public const long MaxFileBytes = 150L * 1024 * 1024;

    public static readonly string[] MetaKeys = ["schema_version", "catalog_version", "built_at", "drug_source_date", "loinc_release"];
}

/// <summary>CatalogCustomItems.Type and CatalogReports.Type values.</summary>
public static class CatalogItemTypes
{
    public const string Drug = "drug";
    public const string Lab = "lab";
    public const string Radiology = "radiology";

    public static readonly string[] All = [Drug, Lab, Radiology];

    public static readonly string[] ReportTypes = ["missing", "wrong", "other"];
}

/// <summary>SpecialtyProfileItems.ItemType (DB CHECK), and the General profile (BR-CAT3).</summary>
public static partial class SpecialtyProfiles
{
    public const string DrugGroup = "drugGroup";
    public const string Route = "route";
    public const string LabCode = "labCode";
    public const string RadiologyRegion = "radiologyRegion";
    public const string RadiologyModality = "radiologyModality";
    public const string RadiologyCode = "radiologyCode";

    public static readonly string[] ItemTypes = [DrugGroup, Route, LabCode, RadiologyRegion, RadiologyModality, RadiologyCode];

    /// <summary>The General profile is a Specialties row with this NameEn, inactive so sign-up never lists it.</summary>
    public const string GeneralNameEn = "General";

    public const int MaxItemsPerType = 300;

    public const int ValueMax = 100;

    /// <summary>Values are ids and codes (VARCHAR): printable ASCII, no leading or trailing spaces.</summary>
    [GeneratedRegex(@"^[\x21-\x7E](?:[\x20-\x7E]*[\x21-\x7E])?\z", RegexOptions.CultureInvariant)]
    public static partial Regex ValuePattern();
}

/// <summary>A custom catalog item (BR-CAT9). Drug fields only for drugs; the LOINC code only for lab and radiology.</summary>
public sealed record CustomItemInput(
    string? Type, string? NameEn, string? NameAr, string? ActiveIngredient, string? DrugGroupId, string? Route,
    string? LoincCode, IReadOnlyList<string>? Aliases);

public sealed record CreateCustomItemRequest(
    string? Type, string? NameEn, string? NameAr, string? ActiveIngredient, string? DrugGroupId, string? Route,
    string? LoincCode, IReadOnlyList<string>? Aliases);

/// <summary>Every field replaced; <c>active: false</c> disables the item (it is never deleted, so devices learn of it).</summary>
public sealed record UpdateCustomItemRequest(
    Guid? CustomItemId, string? NameEn, string? NameAr, string? ActiveIngredient, string? DrugGroupId, string? Route,
    string? LoincCode, IReadOnlyList<string>? Aliases, bool? Active);

public static class CustomItemRules
{
    public static void AddCustomItemRules<T>(
        this AbstractValidator<T> validator, Func<T, string?> type, System.Linq.Expressions.Expression<Func<T, string?>> nameEn,
        System.Linq.Expressions.Expression<Func<T, string?>> nameAr, System.Linq.Expressions.Expression<Func<T, string?>> ingredient,
        System.Linq.Expressions.Expression<Func<T, string?>> group, System.Linq.Expressions.Expression<Func<T, string?>> route,
        System.Linq.Expressions.Expression<Func<T, string?>> loinc, System.Linq.Expressions.Expression<Func<T, IReadOnlyList<string>?>> aliases)
    {
        validator.RuleFor(nameEn).Required().MaxChars(200);
        validator.RuleFor(nameAr).MaxChars(200);
        validator.RuleFor(ingredient).MaxChars(300)
            .Must((x, v) => v is null || type(x) == CatalogItemTypes.Drug).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Only for medicines.");
        validator.RuleFor(group).MaxChars(100)
            .Must((x, v) => v is null || type(x) == CatalogItemTypes.Drug).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Only for medicines.");
        validator.RuleFor(route).MaxChars(50)
            .Must((x, v) => v is null || type(x) == CatalogItemTypes.Drug).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Only for medicines.");
        validator.RuleFor(loinc).MaxChars(20)
            .Must((x, v) => v is null || type(x) != CatalogItemTypes.Drug).WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Only for tests.");
        validator.RuleFor(aliases)
            .Must(list => list is null || (list.Count <= 10 && list.All(a => !string.IsNullOrWhiteSpace(a) && a.Trim().Length <= 100)))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("At most 10 aliases of up to 100 characters.");
    }
}

public sealed class CreateCustomItemRequestValidator : AbstractValidator<CreateCustomItemRequest>
{
    public CreateCustomItemRequestValidator()
    {
        RuleFor(x => x.Type).Required().OneOf(CatalogItemTypes.All);
        this.AddCustomItemRules(x => x.Type, x => x.NameEn, x => x.NameAr, x => x.ActiveIngredient, x => x.DrugGroupId, x => x.Route, x => x.LoincCode, x => x.Aliases);
    }
}

public sealed class UpdateCustomItemRequestValidator : AbstractValidator<UpdateCustomItemRequest>
{
    public UpdateCustomItemRequestValidator()
    {
        RuleFor(x => x.CustomItemId).Required();
        RuleFor(x => x.Active).NotNull().WithErrorCode(ErrorCodes.Required);
        // The type can't change; the endpoint checks the drug-only fields against the stored type.
        RuleFor(x => x.NameEn).Required().MaxChars(200);
        RuleFor(x => x.NameAr).MaxChars(200);
        RuleFor(x => x.ActiveIngredient).MaxChars(300);
        RuleFor(x => x.DrugGroupId).MaxChars(100);
        RuleFor(x => x.Route).MaxChars(50);
        RuleFor(x => x.LoincCode).MaxChars(20);
        RuleFor(x => x.Aliases)
            .Must(list => list is null || (list.Count <= 10 && list.All(a => !string.IsNullOrWhiteSpace(a) && a.Trim().Length <= 100)))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("At most 10 aliases of up to 100 characters.");
    }
}

public sealed class CustomItemListQuery : IPagedQuery
{
    public string? Type { get; init; }

    public string? Search { get; init; }

    public bool? Active { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class CustomItemListQueryValidator : AbstractValidator<CustomItemListQuery>
{
    public CustomItemListQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Type).OneOf(CatalogItemTypes.All);
        RuleFor(x => x.Search).MaxChars(100);
    }
}

/// <summary>reportCatalogItem [S] (BR-CAT8, AD20 "Doctor reports").</summary>
public sealed record ReportCatalogItemRequest(string? Type, string? Text, string? ItemRef);

public sealed class ReportCatalogItemRequestValidator : AbstractValidator<ReportCatalogItemRequest>
{
    public ReportCatalogItemRequestValidator()
    {
        RuleFor(x => x.Type).Required().OneOf(CatalogItemTypes.ReportTypes);
        RuleFor(x => x.Text).Required().MaxChars(500);
        RuleFor(x => x.ItemRef).MaxChars(100);
    }
}

public sealed class CatalogReportListQuery : IPagedQuery
{
    /// <summary><c>open</c> (default), <c>done</c> or <c>all</c>.</summary>
    public string Status { get; init; } = "open";

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class CatalogReportListQueryValidator : AbstractValidator<CatalogReportListQuery>
{
    public CatalogReportListQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Status).OneOf("open", "done", "all");
    }
}

public sealed record HandleReportRequest(Guid? ReportId);

public sealed class HandleReportRequestValidator : AbstractValidator<HandleReportRequest>
{
    public HandleReportRequestValidator() => RuleFor(x => x.ReportId).Required();
}

/// <summary>AD19: a specialty's profile. Every list replaced; <c>includeGeneral</c> is ignored for the General profile.</summary>
public sealed record SpecialtyProfileRequest(
    bool? IncludeGeneral, IReadOnlyList<string>? DrugGroups, IReadOnlyList<string>? Routes, IReadOnlyList<string>? LabCodes,
    IReadOnlyList<string>? RadiologyRegions, IReadOnlyList<string>? RadiologyModalities, IReadOnlyList<string>? RadiologyCodes);

public sealed class SpecialtyProfileRequestValidator : AbstractValidator<SpecialtyProfileRequest>
{
    public SpecialtyProfileRequestValidator()
    {
        RuleFor(x => x.IncludeGeneral).NotNull().WithErrorCode(ErrorCodes.Required);
        Values(x => x.DrugGroups);
        Values(x => x.Routes);
        Values(x => x.LabCodes);
        Values(x => x.RadiologyRegions);
        Values(x => x.RadiologyModalities);
        Values(x => x.RadiologyCodes);
    }

    private void Values(System.Linq.Expressions.Expression<Func<SpecialtyProfileRequest, IReadOnlyList<string>?>> list) =>
        RuleFor(list)
            .Must(values => values is null || values.Count <= SpecialtyProfiles.MaxItemsPerType)
            .WithErrorCode(ErrorCodes.TooMany).WithMessage($"At most {SpecialtyProfiles.MaxItemsPerType} values.")
            .Must(values => values is null || values.All(v => v is not null && v.Trim().Length <= SpecialtyProfiles.ValueMax && SpecialtyProfiles.ValuePattern().IsMatch(v.Trim())))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Codes and ids: printable ASCII, at most 100 characters.");
}

public sealed record CopyProfileRequest(Guid? FromSpecialtyId);

public sealed class CopyProfileRequestValidator : AbstractValidator<CopyProfileRequest>
{
    public CopyProfileRequestValidator() => RuleFor(x => x.FromSpecialtyId).Required();
}

public sealed record CatalogCountsView(int Drugs, int Labs, int Radiology);

public sealed record CatalogVersionView(
    int Version, int SchemaVersion, string Sha256, long SizeBytes, CatalogCountsView Counts, DateOnly? DrugSourceDate,
    string? LoincRelease, DateTime PublishedAt, string DownloadPath);

public sealed record CustomItemView(
    Guid CustomItemId, string Type, string NameEn, string? NameAr, string? ActiveIngredient, string? DrugGroupId, string? Route,
    string? LoincCode, IReadOnlyList<string> Aliases, bool Active, DateTime CreatedAt, DateTime UpdatedAt);

public sealed record CustomItemSyncView(IReadOnlyList<CustomItemView> Items, DateTime? NextSince, bool HasMore);

public sealed record CatalogReportView(
    Guid ReportId, string Type, string Text, string? ItemRef, string Status, Guid DoctorId, string DoctorName,
    DateTime CreatedAt, Guid? HandledBy, DateTime? HandledAt);

public sealed record SpecialtyListItem(
    Guid SpecialtyId, string NameAr, string NameEn, bool Active, int SortOrder, bool IsGeneral, bool IncludeGeneral,
    int DoctorCount, IReadOnlyDictionary<string, int> ItemCounts);

public sealed record SpecialtyProfileView(
    Guid SpecialtyId, string NameAr, string NameEn, bool IsGeneral, bool IncludeGeneral,
    IReadOnlyList<string> DrugGroups, IReadOnlyList<string> Routes, IReadOnlyList<string> LabCodes,
    IReadOnlyList<string> RadiologyRegions, IReadOnlyList<string> RadiologyModalities, IReadOnlyList<string> RadiologyCodes,
    DateTime UpdatedAt);

/// <summary>GET catalog/myProfile: what ranks the doctor's search first (BR-CAT2–CAT4).</summary>
public sealed record MyProfileView(
    IReadOnlyList<Guid> SpecialtyIds, bool IncludesGeneral,
    IReadOnlyList<string> DrugGroups, IReadOnlyList<string> Routes, IReadOnlyList<string> LabCodes,
    IReadOnlyList<string> RadiologyRegions, IReadOnlyList<string> RadiologyModalities, IReadOnlyList<string> RadiologyCodes);
