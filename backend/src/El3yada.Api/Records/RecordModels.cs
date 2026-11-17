using El3yada.Api.Common;
using El3yada.Api.Validation;
using FluentValidation;

namespace El3yada.Api.Records;

/// <summary>MedicalRecords.Category values (BR-F1).</summary>
public static class RecordCategories
{
    public const string Radiology = "radiology";
    public const string Lab = "lab";
    public const string Prescription = "prescription";
    public const string Other = "other";

    public static readonly string[] All = [Radiology, Lab, Prescription, Other];

    public static string NameAr(string category) => category switch
    {
        Radiology => "أشعة",
        Lab => "تحاليل",
        Prescription => "روشتة",
        _ => "ملف",
    };

    public static string NameEn(string category) => category switch
    {
        Radiology => "Radiology",
        Lab => "Lab tests",
        Prescription => "Prescription",
        _ => "Document",
    };
}

/// <summary>MedicalRecords.OtherType values ([S] BR-F1), only with <see cref="RecordCategories.Other"/>.</summary>
public static class RecordOtherTypes
{
    public const string Custom = "custom";

    public static readonly string[] All = ["report", "referral", "sickLeave", "ecg", "eegEmg", "endoscopy", "consent", Custom];

    public static string? NameAr(string? type) => type switch
    {
        "report" => "تقرير طبي",
        "referral" => "تحويل",
        "sickLeave" => "إجازة مرضية",
        "ecg" => "رسم قلب",
        "eegEmg" => "رسم مخ / أعصاب",
        "endoscopy" => "منظار",
        "consent" => "إقرار",
        _ => null,
    };

    public static string? NameEn(string? type) => type switch
    {
        "report" => "Medical report",
        "referral" => "Referral",
        "sickLeave" => "Sick leave",
        "ecg" => "ECG",
        "eegEmg" => "EEG / EMG",
        "endoscopy" => "Endoscopy",
        "consent" => "Consent form",
        _ => null,
    };
}

/// <summary>MedicalRecords.Source values (BR-F3). <c>chat</c> comes with Phase 5.</summary>
public static class RecordSources
{
    public const string Scan = "scan";
    public const string Upload = "upload";
    public const string Chat = "chat";
}

/// <summary>Limits from backend/docs/api-phase-3-files.md.</summary>
public static class RecordLimits
{
    public const int MaxAttachments = 20;
    public const int TitleMax = 120;
    public const int NotesMax = 1000;
    public const int OtherTypeTextMax = 60;
    public const int MaxPageCount = 500;
    public const long ThumbnailMaxBytes = 2 * 1024 * 1024;

    /// <summary>Unclaimed uploads are deleted after this.</summary>
    public static readonly TimeSpan UploadLifetime = TimeSpan.FromHours(24);
}

/// <summary>
/// createRecord (D10, D11, AS6). <c>uploadIds</c> are files sent with uploadFile, in display order.
/// </summary>
public sealed record CreateRecordRequest(
    Guid? PatientId,
    string? Category,
    string? OtherType,
    string? OtherTypeText,
    string? Title,
    DateOnly? DocumentDate,
    string? Notes,
    Guid? SessionId,
    string? Source,
    IReadOnlyList<Guid>? UploadIds) : IRecordFields;

/// <summary>
/// updateRecord (D12 "edit details", "change category"). Every field is replaced, as in updateClinical: a field
/// left out is cleared (<c>sessionId</c>, <c>notes</c>, <c>otherType</c>), and an empty title goes back to the default.
/// </summary>
public sealed record UpdateRecordRequest(
    Guid? RecordId,
    string? Category,
    string? OtherType,
    string? OtherTypeText,
    string? Title,
    DateOnly? DocumentDate,
    string? Notes,
    Guid? SessionId) : IRecordFields;

public sealed record DeleteRecordRequest(Guid? RecordId);

public interface IRecordFields
{
    string? Category { get; }
    string? OtherType { get; }
    string? OtherTypeText { get; }
    string? Title { get; }
    DateOnly? DocumentDate { get; }
    string? Notes { get; }
}

public static class RecordFieldRules
{
    /// <summary>The BR-F3 field rules shared by create and update.</summary>
    public static void AddRecordFieldRules<T>(this AbstractValidator<T> validator, TimeProvider time)
        where T : IRecordFields
    {
        validator.RuleFor(x => x.Category).Required().OneOf(RecordCategories.All);
        validator.RuleFor(x => x.OtherType)
            .Must((x, type) => type is null || x.Category == RecordCategories.Other)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("A type is only for the Other category.")
            .OneOf(RecordOtherTypes.All);
        validator.RuleFor(x => x.OtherTypeText)
            .Must((x, text) => x.OtherType != RecordOtherTypes.Custom || !string.IsNullOrWhiteSpace(text))
            .WithErrorCode(ErrorCodes.Required).WithMessage("Type the document type.")
            .MaxChars(RecordLimits.OtherTypeTextMax);
        validator.RuleFor(x => x.Title).MaxChars(RecordLimits.TitleMax);
        validator.RuleFor(x => x.Notes).MaxChars(RecordLimits.NotesMax);
        validator.RuleFor(x => x.DocumentDate)
            .Must(date => date is null || (date.Value <= CairoTime.Today(time) && date.Value.Year >= 1900))
            .WithErrorCode(ErrorCodes.InvalidDate).WithMessage("The document date can't be in the future.");
    }
}

public sealed class CreateRecordRequestValidator : AbstractValidator<CreateRecordRequest>
{
    public CreateRecordRequestValidator(TimeProvider time)
    {
        RuleFor(x => x.PatientId).Required();
        this.AddRecordFieldRules(time);
        RuleFor(x => x.Source).Required().OneOf(RecordSources.Scan, RecordSources.Upload);
        RuleFor(x => x.UploadIds)
            .Must(ids => ids is { Count: > 0 })
            .WithErrorCode(ErrorCodes.Required).WithMessage("Add at least one file.");
        RuleFor(x => x.UploadIds)
            .Must(ids => ids is null || ids.Count <= RecordLimits.MaxAttachments)
            .WithErrorCode(ErrorCodes.TooMany).WithMessage($"A record holds at most {RecordLimits.MaxAttachments} files.")
            .Must(ids => ids is null || ids.Distinct().Count() == ids.Count)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Each file once.");
    }
}

public sealed class UpdateRecordRequestValidator : AbstractValidator<UpdateRecordRequest>
{
    public UpdateRecordRequestValidator(TimeProvider time)
    {
        RuleFor(x => x.RecordId).Required();
        this.AddRecordFieldRules(time);
        RuleFor(x => x.DocumentDate).Required();
    }
}

public sealed class DeleteRecordRequestValidator : AbstractValidator<DeleteRecordRequest>
{
    public DeleteRecordRequestValidator()
    {
        RuleFor(x => x.RecordId).Required();
    }
}

/// <summary>GET patients/{patientId}/records.</summary>
public sealed class RecordListQuery : IPagedQuery
{
    public string? Category { get; init; }

    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = 30;
}

public sealed class RecordListQueryValidator : AbstractValidator<RecordListQuery>
{
    public RecordListQueryValidator()
    {
        this.AddPagingRules();
        RuleFor(x => x.Category).OneOf(RecordCategories.All);
    }
}

public sealed record UploadView(
    Guid UploadId, string FileName, string MimeType, long SizeBytes, long StoredSizeBytes, long OriginalSizeBytes,
    int? PageCount, bool HasThumbnail, bool Optimized, DateTime ExpiresAt);

public sealed record RecordSessionView(Guid SessionId, string Type, DateTime CreatedAt);

public sealed record RecordCreatorView(Guid UserId, string Role, string Name);

public sealed record AttachmentView(
    Guid AttachmentId, string FileName, string MimeType, long SizeBytes, long StoredSizeBytes, int? PageCount,
    bool HasThumbnail, bool Previewable);

public sealed record RecordView(
    Guid RecordId,
    Guid PatientId,
    string Category,
    string? OtherType,
    string? OtherTypeText,
    string Title,
    DateOnly DocumentDate,
    string? Notes,
    RecordSessionView? Session,
    string Source,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    RecordCreatorView CreatedBy,
    IReadOnlyList<AttachmentView> Attachments,
    long TotalSizeBytes);

public sealed record RecordCountsView(int Radiology, int Lab, int Prescription, int Other);

public sealed record RecordPageView(
    IReadOnlyList<RecordView> Items, int Page, int PageSize, int TotalCount, RecordCountsView Counts);
