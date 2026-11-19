using FluentValidation;

namespace El3yada.Api.Features.PatientPortal;

public sealed class MarkSeenRequestValidator : AbstractValidator<MarkSeenRequest>
{
    public const int MaxIds = 200;

    public MarkSeenRequestValidator()
    {
        RuleFor(x => x.Visits).Must(ids => ids is null || ids.Count <= MaxIds).WithErrorCode("TOO_MANY_IDS");
        RuleFor(x => x.Prescriptions).Must(ids => ids is null || ids.Count <= MaxIds).WithErrorCode("TOO_MANY_IDS");
        RuleFor(x => x.Files).Must(ids => ids is null || ids.Count <= MaxIds).WithErrorCode("TOO_MANY_IDS");
    }
}

public sealed class RequestAccountDeletionRequestValidator : AbstractValidator<RequestAccountDeletionRequest>
{
    public RequestAccountDeletionRequestValidator()
    {
        // DeletionRequests.Reason is NVARCHAR(500).
        RuleFor(x => x.Reason).MaximumLength(500).WithErrorCode("TOO_LONG");
    }
}

public sealed class PatientListQueryValidator : AbstractValidator<PatientListQuery>
{
    private static readonly string[] Kinds = ["medication", "investigations", "prescription", "lab", "radiology", "other"];

    public PatientListQueryValidator()
    {
        RuleFor(x => x.Kind).Must(k => k is null || Kinds.Contains(k)).WithErrorCode("INVALID_KIND");
        RuleFor(x => x).Must(x => x.From is null || x.To is null || x.From <= x.To).WithName("from").WithErrorCode("INVALID_RANGE");
    }
}
