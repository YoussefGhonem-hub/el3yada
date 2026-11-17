using El3yada.Api.Common;
using El3yada.Api.Validation;
using FluentValidation;

namespace El3yada.Api.Prescriptions;

/// <summary>Prescriptions.Kind (spec 6.4).</summary>
public static class PrescriptionKinds
{
    /// <summary>روشتة علاج.</summary>
    public const string Medication = "medication";

    /// <summary>روشتة تحاليل وأشعة.</summary>
    public const string Investigations = "investigations";

    public static readonly string[] All = [Medication, Investigations];

    public static string NameAr(string kind) => kind == Medication ? "روشتة علاج" : "روشتة تحاليل وأشعة";

    public static string NameEn(string kind) => kind == Medication ? "prescription" : "lab and radiology request";
}

/// <summary>Prescriptions.Status (BR-RX2, BR-AS12).</summary>
public static class PrescriptionStatuses
{
    public const string Draft = "draft";
    public const string ReadyForReview = "readyForReview";
    public const string Sent = "sent";
    public const string Cancelled = "cancelled";

    /// <summary>Still editable: drafts, and drafts an assistant sent for review.</summary>
    public static bool IsEditable(string status) => status is Draft or ReadyForReview;
}

/// <summary>The 6.4 lists the app offers. <c>form</c> may also be free text; <c>timing</c> must be one of these.</summary>
public static class PrescriptionLists
{
    public static readonly string[] Forms =
        ["tablet", "capsule", "syrup", "injection", "cream", "drops", "inhaler", "suppository", "sachet", "other"];

    public static readonly string[] Timings = ["beforeFood", "afterFood", "withFood", "unspecified"];

    public static readonly string[] InvestigationCategories = ["lab", "radiology"];
}

public static class PrescriptionLimits
{
    public const int MaxMedicationItems = 30;
    public const int MaxInvestigationItems = 50;
    public const int TextMax = 1000;
    public const long PdfMaxBytes = 10 * 1024 * 1024;
    public const int TemplateNameMax = 100;
    public const int HistoryLimit = 1000;
}

/// <summary>
/// One item of a prescription, template or draft. A medication item uses the first ten fields, an investigation
/// item the last four. Fields of the other kind must be left out.
/// </summary>
public sealed record PrescriptionItemInput(
    string? DrugName = null,
    string? ActiveIngredient = null,
    string? CatalogId = null,
    string? Form = null,
    string? Strength = null,
    string? Dose = null,
    string? Frequency = null,
    string? Timing = null,
    string? Duration = null,
    string? Instructions = null,
    string? Category = null,
    string? Name = null,
    string? LoincCode = null,
    string? Notes = null);

/// <summary>A medication item (6.4): the drug name is required, the rest is optional.</summary>
public sealed class MedicationItemValidator : AbstractValidator<PrescriptionItemInput>
{
    public MedicationItemValidator()
    {
        RuleFor(x => x.DrugName).Required().MaxChars(200);
        RuleFor(x => x.ActiveIngredient).MaxChars(300);
        RuleFor(x => x.CatalogId).MaxChars(50);
        RuleFor(x => x.Form).MaxChars(40);
        RuleFor(x => x.Strength).MaxChars(40);
        RuleFor(x => x.Dose).MaxChars(60);
        RuleFor(x => x.Frequency).MaxChars(60);
        RuleFor(x => x.Timing).OneOf(PrescriptionLists.Timings);
        RuleFor(x => x.Duration).MaxChars(60);
        RuleFor(x => x.Instructions).MaxChars(300);
        RuleFor(x => x.Category).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a medication field.");
        RuleFor(x => x.Name).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use drugName for a medicine.");
        RuleFor(x => x.LoincCode).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a medication field.");
        RuleFor(x => x.Notes).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use instructions for a medicine.");
    }
}

/// <summary>An investigation item (6.4): lab or radiology, a name, optional notes.</summary>
public sealed class InvestigationItemValidator : AbstractValidator<PrescriptionItemInput>
{
    public InvestigationItemValidator()
    {
        RuleFor(x => x.Category).Required().OneOf(PrescriptionLists.InvestigationCategories);
        RuleFor(x => x.Name).Required().MaxChars(200);
        RuleFor(x => x.LoincCode).MaxChars(20);
        RuleFor(x => x.Notes).MaxChars(300);
        RuleFor(x => x.DrugName).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use name for a test.");
        RuleFor(x => x.ActiveIngredient).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a test field.");
        RuleFor(x => x.Form).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a test field.");
        RuleFor(x => x.Strength).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a test field.");
        RuleFor(x => x.Dose).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a test field.");
        RuleFor(x => x.Frequency).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a test field.");
        RuleFor(x => x.Timing).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a test field.");
        RuleFor(x => x.Duration).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Not a test field.");
        RuleFor(x => x.Instructions).Null().WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use notes for a test.");
    }
}

/// <summary>Item rules by kind, with the item count limit.</summary>
public static class PrescriptionItemRules
{
    public static int MaxItems(string kind) =>
        kind == PrescriptionKinds.Medication ? PrescriptionLimits.MaxMedicationItems : PrescriptionLimits.MaxInvestigationItems;

    public static IValidator<PrescriptionItemInput> For(string kind) =>
        kind == PrescriptionKinds.Medication ? new MedicationItemValidator() : new InvestigationItemValidator();

    /// <summary>Every failure, with paths like <c>items[2].drugName</c>.</summary>
    public static List<FluentValidation.Results.ValidationFailure> Check(string kind, IReadOnlyList<PrescriptionItemInput>? items)
    {
        var failures = new List<FluentValidation.Results.ValidationFailure>();
        if (items is null)
        {
            return failures;
        }

        if (items.Count > MaxItems(kind))
        {
            failures.Add(new("Items", $"At most {MaxItems(kind)} items.") { ErrorCode = ErrorCodes.TooMany });
            return failures;
        }

        var validator = For(kind);
        for (var i = 0; i < items.Count; i++)
        {
            if (items[i] is null)
            {
                failures.Add(new($"Items[{i}]", "An item is required.") { ErrorCode = ErrorCodes.Required });
                continue;
            }

            foreach (var failure in validator.Validate(items[i]).Errors)
            {
                failures.Add(new($"Items[{i}].{failure.PropertyName}", failure.ErrorMessage) { ErrorCode = failure.ErrorCode });
            }
        }

        return failures;
    }
}

/// <summary>createPrescriptionDraft (D13/D14, BR-RX1). <c>copyFromId</c>: "Issue new copy" of a sent or cancelled document (D15).</summary>
public sealed record CreatePrescriptionDraftRequest(Guid? SessionId, string? Kind, Guid? CopyFromId);

public sealed class CreatePrescriptionDraftRequestValidator : AbstractValidator<CreatePrescriptionDraftRequest>
{
    public CreatePrescriptionDraftRequestValidator()
    {
        RuleFor(x => x.SessionId).Required();
        RuleFor(x => x.Kind).Required().OneOf(PrescriptionKinds.All);
    }
}

/// <summary>
/// updatePrescriptionDraft: everything replaced; <c>items</c> in display order (that is how the editor reorders).
/// Item rules depend on the draft's kind and are checked by the endpoint.
/// </summary>
public sealed record UpdatePrescriptionDraftRequest(
    Guid? PrescriptionId, string? Diagnosis, string? Advice, DateOnly? FollowUpDate, IReadOnlyList<PrescriptionItemInput>? Items);

public sealed class UpdatePrescriptionDraftRequestValidator : AbstractValidator<UpdatePrescriptionDraftRequest>
{
    public UpdatePrescriptionDraftRequestValidator()
    {
        RuleFor(x => x.PrescriptionId).Required();
        RuleFor(x => x.Diagnosis).MaxChars(PrescriptionLimits.TextMax);
        RuleFor(x => x.Advice).MaxChars(PrescriptionLimits.TextMax);
        RuleFor(x => x.FollowUpDate)
            .Must(date => date is null || date.Value.Year is >= 2000 and <= 2100)
            .WithErrorCode(ErrorCodes.InvalidDate).WithMessage("Pick a real date.");
    }
}

public sealed record PrescriptionIdRequest(Guid? PrescriptionId);

public sealed class PrescriptionIdRequestValidator : AbstractValidator<PrescriptionIdRequest>
{
    public PrescriptionIdRequestValidator() => RuleFor(x => x.PrescriptionId).Required();
}

/// <summary>cancelPrescription (BR-RX2): the reason the patient sees struck through, 3–500 characters.</summary>
public sealed record CancelPrescriptionRequest(Guid? PrescriptionId, string? Reason);

public sealed class CancelPrescriptionRequestValidator : AbstractValidator<CancelPrescriptionRequest>
{
    public CancelPrescriptionRequestValidator()
    {
        RuleFor(x => x.PrescriptionId).Required();
        RuleFor(x => x.Reason)
            .Must(reason => reason?.Trim().Length >= 3)
            .WithErrorCode(ErrorCodes.ReasonRequired).WithMessage("Write the reason (at least 3 characters).")
            .MaxChars(500);
    }
}

/// <summary>The <c>data</c> part of sendPrescription.</summary>
public sealed record SendPrescriptionData(Guid? PrescriptionId);

/// <summary>GET patients/{patientId}/prescriptions.</summary>
public sealed class PrescriptionListQuery : IPagedQuery
{
    public string? Kind { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class PrescriptionListQueryValidator : AbstractValidator<PrescriptionListQuery>
{
    public PrescriptionListQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Kind).OneOf(PrescriptionKinds.All);
    }
}

/// <summary>A saved template (BR-RX6, D23 [S]). The kind is fixed at creation.</summary>
public sealed record CreateTemplateRequest(string? Name, string? Kind, IReadOnlyList<PrescriptionItemInput>? Items, string? Advice);

public sealed class CreateTemplateRequestValidator : AbstractValidator<CreateTemplateRequest>
{
    public CreateTemplateRequestValidator()
    {
        RuleFor(x => x.Name).Required().MaxChars(PrescriptionLimits.TemplateNameMax);
        RuleFor(x => x.Kind).Required().OneOf(PrescriptionKinds.All);
        RuleFor(x => x.Advice).MaxChars(PrescriptionLimits.TextMax);
        RuleFor(x => x.Items).Must(items => items is { Count: > 0 })
            .WithErrorCode(ErrorCodes.Required).WithMessage("Add at least one item.");
        RuleFor(x => x).Custom((request, context) =>
        {
            if (request.Kind is PrescriptionKinds.Medication or PrescriptionKinds.Investigations)
            {
                foreach (var failure in PrescriptionItemRules.Check(request.Kind, request.Items))
                {
                    context.AddFailure(failure);
                }
            }
        });
    }
}

public sealed record UpdateTemplateRequest(Guid? TemplateId, string? Name, IReadOnlyList<PrescriptionItemInput>? Items, string? Advice);

public sealed class UpdateTemplateRequestValidator : AbstractValidator<UpdateTemplateRequest>
{
    public UpdateTemplateRequestValidator()
    {
        RuleFor(x => x.TemplateId).Required();
        RuleFor(x => x.Name).Required().MaxChars(PrescriptionLimits.TemplateNameMax);
        RuleFor(x => x.Advice).MaxChars(PrescriptionLimits.TextMax);
        RuleFor(x => x.Items).Must(items => items is { Count: > 0 })
            .WithErrorCode(ErrorCodes.Required).WithMessage("Add at least one item.");
    }
}

public sealed record TemplateIdRequest(Guid? TemplateId);

public sealed class TemplateIdRequestValidator : AbstractValidator<TemplateIdRequest>
{
    public TemplateIdRequestValidator() => RuleFor(x => x.TemplateId).Required();
}

public sealed record HistoryItemIdRequest(Guid? ItemId);

public sealed class HistoryItemIdRequestValidator : AbstractValidator<HistoryItemIdRequest>
{
    public HistoryItemIdRequestValidator() => RuleFor(x => x.ItemId).Required();
}

public sealed record MedicationItemView(
    string DrugName, string? ActiveIngredient, string? CatalogId, string? Form, string? Strength, string? Dose,
    string? Frequency, string? Timing, string? Duration, string? Instructions);

public sealed record InvestigationItemView(string Category, string Name, string? LoincCode, string? Notes);

public sealed record PreparedByView(Guid UserId, string Role, string Name);

/// <summary>
/// One prescription or request. <c>items</c> hold <see cref="MedicationItemView"/> or <see cref="InvestigationItemView"/>
/// by kind. <c>qrUrl</c> is what the app prints as the QR code (6.4.1).
/// </summary>
public sealed record PrescriptionView(
    Guid PrescriptionId,
    Guid PatientId,
    Guid SessionId,
    string Kind,
    string Status,
    string? Diagnosis,
    string? Advice,
    DateOnly? FollowUpDate,
    IReadOnlyList<object> Items,
    PreparedByView? PreparedBy,
    DateTime? SentAt,
    DateTime? CancelledAt,
    string? CancelReason,
    Guid? ReplacesRxId,
    Guid? ReplacedById,
    string QrShortCode,
    string QrUrl,
    bool HasPdf,
    DateTime CreatedAt,
    DateTime UpdatedAt);

public sealed record ItemHistoryView(
    Guid ItemId, string Kind, string Name, string? CatalogId, string Form, string Strength, int UseCount, DateTime LastUsedAt);

public sealed record TemplateView(
    Guid TemplateId, string Kind, string Name, IReadOnlyList<object> Items, string? Advice, DateTime CreatedAt, DateTime UpdatedAt);
