using El3yada.Api.Clinic;
using El3yada.Api.Validation;
using El3yada.Data.Entities;
using FluentValidation;

namespace El3yada.Api.ClinicAdmin;

/// <summary>Assistants.Status values (BR-AS8). Removed is final: the history stays and the number is free again.</summary>
public static class AssistantStatuses
{
    public const string Active = "active";
    public const string Disabled = "disabled";
    public const string Removed = "removed";

    public static readonly string[] All = [Active, Disabled, Removed];
}

/// <summary>
/// <c>createAssistant</c> (D26). <c>permissions</c> is the same map as in answers and <c>clinic/me</c>
/// (<c>{ "patientsManage": true, … }</c>); a missing key is off, and dependencies are switched on
/// (spec 6.10). Branches: <c>allBranches: true</c>, or one or more of the doctor's <c>branchIds</c>.
/// </summary>
public sealed record CreateAssistantRequest(
    string? FullName, string? Phone, bool? AllBranches, List<Guid>? BranchIds, Dictionary<string, bool>? Permissions);

public sealed class CreateAssistantRequestValidator : AbstractValidator<CreateAssistantRequest>
{
    public CreateAssistantRequestValidator()
    {
        RuleFor(x => x.FullName).Required().FullName();
        RuleFor(x => x.Phone).Required().EgyptianMobile();
        RuleFor(x => x.BranchIds).Required().When(x => x.AllBranches != true);
        RuleFor(x => x.BranchIds).AssistantBranchIds();
        RuleFor(x => x.Permissions).NotNull().WithErrorCode(ErrorCodes.Required).WithMessage("Choose the permissions.")
            .KnownPermissions();
    }
}

/// <summary>
/// <c>updateAssistant</c> (D26 edit). Only the parts sent change: <c>fullName</c>, <c>phone</c>, the branches
/// (<c>allBranches</c> and/or <c>branchIds</c>) and <c>permissions</c> (the whole map; a missing key is off).
/// </summary>
public sealed record UpdateAssistantRequest(
    Guid? AssistantId, string? FullName, string? Phone, bool? AllBranches, List<Guid>? BranchIds, Dictionary<string, bool>? Permissions)
{
    public bool ChangesBranches => AllBranches is not null || BranchIds is not null;
}

public sealed class UpdateAssistantRequestValidator : AbstractValidator<UpdateAssistantRequest>
{
    public UpdateAssistantRequestValidator()
    {
        RuleFor(x => x.AssistantId).Required();
        RuleFor(x => x.FullName).FullName();
        RuleFor(x => x.Phone).EgyptianMobile();
        RuleFor(x => x.BranchIds).Required().When(x => x.AllBranches == false);
        RuleFor(x => x.BranchIds).AssistantBranchIds();
        RuleFor(x => x.Permissions).KnownPermissions();
    }
}

/// <summary>resetAssistantPassword.</summary>
public sealed record AssistantIdRequest(Guid? AssistantId);

public sealed class AssistantIdRequestValidator : AbstractValidator<AssistantIdRequest>
{
    public AssistantIdRequestValidator() => RuleFor(x => x.AssistantId).Required();
}

/// <summary><c>setAssistantStatus</c>: <c>active</c>, <c>disabled</c> or <c>removed</c> (final).</summary>
public sealed record SetAssistantStatusRequest(Guid? AssistantId, string? Status);

public sealed class SetAssistantStatusRequestValidator : AbstractValidator<SetAssistantStatusRequest>
{
    public SetAssistantStatusRequestValidator()
    {
        RuleFor(x => x.AssistantId).Required();
        RuleFor(x => x.Status).Required().OneOf(AssistantStatuses.All);
    }
}

/// <summary>D25 list. Removed assistants are left out unless <c>includeRemoved=true</c>.</summary>
public sealed class AssistantListQuery
{
    public bool IncludeRemoved { get; init; }
}

public static class AssistantRules
{
    public static IRuleBuilderOptions<T, List<Guid>?> AssistantBranchIds<T>(this IRuleBuilder<T, List<Guid>?> rule) =>
        rule.Must(ids => ids is null || (ids.Count <= 50 && ids.Distinct().Count() == ids.Count && !ids.Contains(Guid.Empty)))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Each branch once.");

    public static IRuleBuilderOptions<T, Dictionary<string, bool>?> KnownPermissions<T>(this IRuleBuilder<T, Dictionary<string, bool>?> rule) =>
        rule.Must(map => map is null || map.Keys.All(ClinicPermissions.IsKnown))
            .WithErrorCode(ErrorCodes.InvalidValue)
            .WithMessage($"Permission keys are: {string.Join(", ", ClinicPermissions.All)}.");

    /// <summary>The keys switched on, with their dependencies (spec 6.10).</summary>
    public static IReadOnlySet<string> Keys(Dictionary<string, bool> map) =>
        ClinicPermissions.WithDependencies(map.Where(pair => pair.Value).Select(pair => pair.Key));
}

public sealed record AssistantBranchView(Guid Id, string NameAr, string? NameEn, string Status);

/// <summary>
/// One assistant (D25 row, D26 form). <c>branches</c> is empty when <c>allBranches</c> is true.
/// <c>mustChangePassword</c>: they have not replaced the temporary password yet.
/// </summary>
/// <summary>
/// D25 / D26. <c>accountStatus</c> is the assistant's login (Users.Status): <c>pendingDeletion</c> while they are deleting
/// their account (D25 shows «طلب حذف حسابه»; they no longer act for the clinic), otherwise <c>active</c> or <c>disabled</c>.
/// </summary>
public sealed record AssistantView(
    Guid UserId, string FullName, string Phone, string Preset, string Status, bool AllBranches,
    IReadOnlyList<AssistantBranchView> Branches, IReadOnlyDictionary<string, bool> Permissions, bool MustChangePassword,
    DateTime? LastActiveAt, DateTime CreatedAt, DateTime UpdatedAt, DateTime? RemovedAt, string AccountStatus = "active")
{
    public IEnumerable<Guid> BranchIds => Branches.Select(b => b.Id);

    public static AssistantView Of(Assistant a, bool mustChangePassword, string? accountStatus = null) => new(
        a.UserId, a.FullName, Features.AccountDeletion.Tombstones.IsPhone(a.Phone) ? "" : a.Phone, a.Preset, a.Status, a.AllBranches,
        a.AllBranches ? [] : a.Branches.OrderBy(b => b.CreatedAt).Select(b => new AssistantBranchView(b.Id, b.NameAr, b.NameEn, b.Status)).ToList(),
        ClinicPermissions.ToMap(ClinicPermissions.Of(a)), mustChangePassword,
        a.LastActiveAt, a.CreatedAt, a.UpdatedAt, a.RemovedAt, accountStatus ?? a.User?.Status ?? "active");
}

/// <summary>D25: <c>count</c> is the active and disabled assistants (what maxAssistantsPerDoctor counts).</summary>
public sealed record AssistantListView(IReadOnlyList<AssistantView> Items, int Count, int Limit, bool CanAdd);

/// <summary>The temporary password is shown once (BR-AS2) and never stored in clear.</summary>
public sealed record AssistantWithPasswordView(AssistantView Assistant, string TemporaryPassword);
