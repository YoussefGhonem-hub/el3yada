using El3yada.Api.Infrastructure.Paging;
using El3yada.Api.Infrastructure.Validation;
using FluentValidation;

namespace El3yada.Api.Features.Admin;

// AD12: account deletion requests

public sealed record DeletionRequestsQuery : PageQuery
{
    /// <summary><c>pending</c> (default), <c>approved</c>, <c>rejected</c> or <c>all</c>.</summary>
    public string Status { get; init; } = "pending";
}

public sealed record AdminDeletionRequestDto(
    Guid Id,
    Guid PatientId,
    string PatientName,
    string PatientPhone,
    string? Reason,
    string Status,
    DateTime CreatedAt,
    DateTime? ReviewedAt,
    string? ReviewedByName,
    string? ReviewNote);

public sealed record ReviewDeletionRequest(string Decision, string? Note);

public sealed class DeletionRequestsQueryValidator : AbstractValidator<DeletionRequestsQuery>
{
    public DeletionRequestsQueryValidator()
    {
        RuleFor(x => x.Status).Must(s => s is "pending" or "approved" or "rejected" or "all").WithErrorCode("INVALID_STATUS");
    }
}

public sealed class ReviewDeletionRequestValidator : AbstractValidator<ReviewDeletionRequest>
{
    public ReviewDeletionRequestValidator()
    {
        RuleFor(x => x.Decision).Must(d => d is "approve" or "reject").WithErrorCode("INVALID_DECISION");
        // AD12: rejecting needs a reason.
        RuleFor(x => x.Note).NotEmpty().When(x => x.Decision == "reject").WithErrorCode("REASON_REQUIRED");
        RuleFor(x => x.Note).MaximumLength(500).WithErrorCode("TOO_LONG");
    }
}

// AD11: accounts support (search by phone only, no medical data)

public sealed record AccountSearchQuery(string? Phone);

public sealed record LinkedDoctorDto(Guid DoctorId, string FullName);

public sealed record SupportPatientDto(
    Guid UserId, Guid PatientId, string FullName, string Phone,
    string LoginStatus, string PatientStatus, DateTime CreatedAt,
    IReadOnlyList<LinkedDoctorDto> Doctors);

public sealed record SupportAssistantDto(
    Guid UserId, string FullName, string Phone, string LoginStatus, string AssistantStatus,
    Guid DoctorId, string DoctorName, string Preset, DateTime? LastActiveAt);

public sealed record AccountSearchResultDto(
    string Phone,
    IReadOnlyList<SupportPatientDto> Patients,
    IReadOnlyList<SupportAssistantDto> Assistants);

public sealed record SetLoginStatusRequest(string Status, string? Reason);

public sealed class AccountSearchQueryValidator : AbstractValidator<AccountSearchQuery>
{
    public AccountSearchQueryValidator()
    {
        RuleFor(x => x.Phone).Must(p => EgyptianPhone.TryNormalize(p, out _)).WithErrorCode("INVALID_PHONE");
    }
}

public sealed class SetLoginStatusRequestValidator : AbstractValidator<SetLoginStatusRequest>
{
    public SetLoginStatusRequestValidator()
    {
        RuleFor(x => x.Status).Must(s => s is "active" or "disabled").WithErrorCode("INVALID_STATUS");
        RuleFor(x => x.Reason).MaximumLength(500).WithErrorCode("TOO_LONG");
    }
}
