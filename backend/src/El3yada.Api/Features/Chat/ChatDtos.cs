using FluentValidation;

namespace El3yada.Api.Features.Chat;

public sealed record ChatCounterpartDto(Guid Id, string Name, string? NameEn, string? Title, string? TitleEn);

public sealed record LastMessageDto(string Type, string? Text, string SenderRole, DateTime At);

/// <summary>One conversation in D16 / AS9 (staff) or P11 (patient).</summary>
public sealed record ChatSummaryDto(
    Guid Id,
    Guid DoctorId,
    Guid PatientId,
    ChatCounterpartDto Counterpart,
    int? FileNumber,
    LastMessageDto? LastMessage,
    int UnreadCount,
    bool Enabled,
    bool CanSend,
    string? UnavailableReason);

public sealed record ChatAttachmentDto(string FileName, string MimeType, long SizeBytes);

public sealed record ChatMessageDto(
    Guid Id,
    Guid ChatId,
    Guid SenderId,
    string SenderRole,
    string SenderName,
    string Type,
    string? Text,
    ChatAttachmentDto? Attachment,
    DateTime CreatedAt,
    DateTime? ReadAt,
    Guid? SavedRecordId);

public sealed record ChatThreadDto(ChatSummaryDto Chat, IReadOnlyList<ChatMessageDto> Messages, bool HasMore);

public sealed record SendTextRequest(string Text);

public sealed record SetChatEnabledRequest(bool Enabled);

/// <summary>BR-C4: save a chat attachment as a medical record (source = chat).</summary>
public sealed record SaveToFileRequest(string Category, string? OtherType, string? OtherTypeText, string? Title, DateOnly? DocumentDate, string? Notes);

public sealed record ChatThreadQuery
{
    /// <summary>Messages older than this message (scroll back).</summary>
    public Guid? Before { get; init; }

    public int Limit { get; init; } = 30;
}

public sealed class SendTextRequestValidator : AbstractValidator<SendTextRequest>
{
    public const int MaxLength = 2000;

    public SendTextRequestValidator()
    {
        RuleFor(x => x.Text).NotEmpty().WithErrorCode("REQUIRED")
            .Must(t => t is null || t.Trim().Length > 0).WithErrorCode("REQUIRED")
            .MaximumLength(MaxLength).WithErrorCode("TOO_LONG");
    }
}

public sealed class SaveToFileRequestValidator : AbstractValidator<SaveToFileRequest>
{
    private static readonly string[] Categories = ["prescription", "lab", "radiology", "other"];
    private static readonly string[] OtherTypes = ["report", "referral", "sickLeave", "ecg", "eegEmg", "endoscopy", "consent", "custom"];

    public SaveToFileRequestValidator()
    {
        RuleFor(x => x.Category).Must(c => Categories.Contains(c)).WithErrorCode("INVALID_CATEGORY");
        RuleFor(x => x.OtherType).Must(t => t is null || OtherTypes.Contains(t)).WithErrorCode("INVALID_TYPE");
        RuleFor(x => x.OtherType).Null().When(x => x.Category != "other").WithErrorCode("INVALID_TYPE");
        RuleFor(x => x.OtherTypeText).NotEmpty().When(x => x.OtherType == "custom").WithErrorCode("REQUIRED");
        RuleFor(x => x.OtherTypeText).MaximumLength(60).WithErrorCode("TOO_LONG");
        RuleFor(x => x.Title).MaximumLength(150).WithErrorCode("TOO_LONG");
        RuleFor(x => x.Notes).MaximumLength(1000).WithErrorCode("TOO_LONG");
    }
}
