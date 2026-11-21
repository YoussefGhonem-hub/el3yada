using El3yada.Api.Infrastructure.Paging;
using El3yada.Api.Infrastructure.Validation;
using FluentValidation;

namespace El3yada.Api.Features.Admin;

// AD11: accounts support (search by phone only, no medical data)

public sealed record AccountSearchQuery(string? Phone);

public sealed record LinkedDoctorDto(Guid DoctorId, string FullName);

/// <summary>The account's deletion in progress (spec 6.17), for AD11's "Cancel and restore".</summary>
public sealed record SupportDeletionDto(Guid Id, string Status, DateTime ScheduledFor);

/// <summary><c>loginStatus</c> is Users.Status: active, disabled or pendingDeletion.</summary>
public sealed record SupportPatientDto(
    Guid UserId, Guid PatientId, string FullName, string Phone,
    string LoginStatus, string PatientStatus, DateTime CreatedAt,
    IReadOnlyList<LinkedDoctorDto> Doctors,
    SupportDeletionDto? Deletion = null);

public sealed record SupportAssistantDto(
    Guid UserId, string FullName, string Phone, string LoginStatus, string AssistantStatus,
    Guid DoctorId, string DoctorName, string Preset, DateTime? LastActiveAt,
    SupportDeletionDto? Deletion = null);

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
