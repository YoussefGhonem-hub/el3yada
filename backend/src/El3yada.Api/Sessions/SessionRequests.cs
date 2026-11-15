using El3yada.Api.Common;
using El3yada.Api.Validation;
using FluentValidation;

namespace El3yada.Api.Sessions;

/// <summary>
/// Vitals (spec 6.2, all optional). The app warns about unusual values (spec section 11, for example systolic
/// 50–260, temperature 34–43 °C) but the API accepts them; it refuses only values that can't be a measurement.
/// </summary>
public sealed record VitalsInput(
    short? BpSys, short? BpDia, short? Pulse, decimal? TempC, decimal? WeightKg, decimal? HeightCm, short? Glucose);

public sealed class VitalsInputValidator : AbstractValidator<VitalsInput>
{
    public VitalsInputValidator()
    {
        RuleFor(x => x.BpSys).InclusiveBetween((short)30, (short)300).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.BpDia).InclusiveBetween((short)10, (short)200).WithErrorCode(ErrorCodes.OutOfRange)
            .Must((x, dia) => (dia is null) == (x.BpSys is null))
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Send both blood pressure values or neither.");
        RuleFor(x => x.Pulse).InclusiveBetween((short)20, (short)300).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.TempC).InclusiveBetween(25m, 45m).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.WeightKg).InclusiveBetween(0.2m, 400m).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.HeightCm).InclusiveBetween(20m, 250m).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.Glucose).InclusiveBetween((short)10, (short)1500).WithErrorCode(ErrorCodes.OutOfRange);
    }
}

/// <summary>Text limits of the session fields (Sessions columns; NVARCHAR(MAX) ones get a sane limit).</summary>
public static class SessionFieldLimits
{
    public const int ChiefComplaint = 1000;
    public const int Diagnosis = 1000;
    public const int LongText = 10_000;

    /// <summary>BR-S10 and spec section 11: 0–100,000 EGP.</summary>
    public const int MaxAmountPiasters = 10_000_000;

    /// <summary>A follow-up date is at most this far after the session.</summary>
    public const int FollowUpMaxYears = 2;
}

/// <summary>
/// createSession (D8, AS5). An assistant may send only type, chiefComplaint, vitals, amountChargedPiasters and
/// paymentMethod (BR-AS5); findings, diagnosis, patientNotes, privateNote and followUpDate are doctor only.
/// <c>amountChargedPiasters</c> defaults to the visit price and is required when there is none (BR-S10).
/// </summary>
public sealed record CreateSessionRequest(
    Guid? PatientId,
    Guid? BranchId,
    string? Type,
    string? ChiefComplaint,
    VitalsInput? Vitals,
    string? Findings,
    string? Diagnosis,
    string? PatientNotes,
    string? PrivateNote,
    DateOnly? FollowUpDate,
    int? AmountChargedPiasters,
    string? PaymentMethod)
{
    /// <summary>The doctor-only fields the request fills (BR-AS5), as JSON names.</summary>
    public IReadOnlyList<string> DoctorOnlyFields() =>
        new (string Name, bool Filled)[]
        {
            ("findings", !string.IsNullOrWhiteSpace(Findings)),
            ("diagnosis", !string.IsNullOrWhiteSpace(Diagnosis)),
            ("patientNotes", !string.IsNullOrWhiteSpace(PatientNotes)),
            ("privateNote", !string.IsNullOrWhiteSpace(PrivateNote)),
            ("followUpDate", FollowUpDate is not null),
        }.Where(f => f.Filled).Select(f => f.Name).ToList();
}

public sealed class CreateSessionRequestValidator : AbstractValidator<CreateSessionRequest>
{
    public CreateSessionRequestValidator(TimeProvider time)
    {
        RuleFor(x => x.PatientId).Required();
        RuleFor(x => x.BranchId).Required();
        RuleFor(x => x.Type).Required().OneOf(SessionTypes.All);
        RuleFor(x => x.ChiefComplaint).MaxChars(SessionFieldLimits.ChiefComplaint);
        RuleFor(x => x.Vitals!).SetValidator(new VitalsInputValidator()).When(x => x.Vitals is not null);
        RuleFor(x => x.Findings).MaxChars(SessionFieldLimits.LongText);
        RuleFor(x => x.Diagnosis).MaxChars(SessionFieldLimits.Diagnosis);
        RuleFor(x => x.PatientNotes).MaxChars(SessionFieldLimits.LongText);
        RuleFor(x => x.PrivateNote).MaxChars(SessionFieldLimits.LongText);
        RuleFor(x => x.FollowUpDate)
            .Must(date => date is null || FollowUpIsValid(date.Value, CairoTime.Today(time)))
            .WithErrorCode(ErrorCodes.OutOfRange).WithMessage("The follow-up date must be from the session day up to 2 years after.");
        RuleFor(x => x.AmountChargedPiasters)
            .InclusiveBetween(0, SessionFieldLimits.MaxAmountPiasters).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.PaymentMethod).OneOf(PaymentMethods.All);
    }

    /// <summary>From the session's day up to 2 years after it.</summary>
    public static bool FollowUpIsValid(DateOnly followUp, DateOnly sessionDay) =>
        followUp >= sessionDay && followUp <= sessionDay.AddYears(SessionFieldLimits.FollowUpMaxYears);
}

/// <summary>
/// updateClinical (D9, doctor only): the clinical fields, all replaced (a field left out is cleared). Type and
/// time are not here: they never change (BR-S6).
/// </summary>
public sealed record UpdateClinicalRequest(
    Guid? SessionId,
    string? ChiefComplaint,
    VitalsInput? Vitals,
    string? Findings,
    string? Diagnosis,
    string? PatientNotes,
    DateOnly? FollowUpDate);

public sealed class UpdateClinicalRequestValidator : AbstractValidator<UpdateClinicalRequest>
{
    public UpdateClinicalRequestValidator()
    {
        RuleFor(x => x.SessionId).Required();
        RuleFor(x => x.ChiefComplaint).MaxChars(SessionFieldLimits.ChiefComplaint);
        RuleFor(x => x.Vitals!).SetValidator(new VitalsInputValidator()).When(x => x.Vitals is not null);
        RuleFor(x => x.Findings).MaxChars(SessionFieldLimits.LongText);
        RuleFor(x => x.Diagnosis).MaxChars(SessionFieldLimits.Diagnosis);
        RuleFor(x => x.PatientNotes).MaxChars(SessionFieldLimits.LongText);
    }
}

/// <summary>setPrivateNote (doctor only). Empty text removes the note.</summary>
public sealed record SetPrivateNoteRequest(Guid? SessionId, string? Text);

public sealed class SetPrivateNoteRequestValidator : AbstractValidator<SetPrivateNoteRequest>
{
    public SetPrivateNoteRequestValidator()
    {
        RuleFor(x => x.SessionId).Required();
        RuleFor(x => x.Text).MaxChars(SessionFieldLimits.LongText);
    }
}

/// <summary>updateAmountCharged (BR-S10). <c>paymentMethod</c> left out is cleared.</summary>
public sealed record UpdateAmountChargedRequest(Guid? SessionId, int? AmountChargedPiasters, string? PaymentMethod);

public sealed class UpdateAmountChargedRequestValidator : AbstractValidator<UpdateAmountChargedRequest>
{
    public UpdateAmountChargedRequestValidator()
    {
        RuleFor(x => x.SessionId).Required();
        RuleFor(x => x.AmountChargedPiasters)
            .NotNull().WithErrorCode(ErrorCodes.AmountRequired).WithMessage("Enter the amount charged.")
            .InclusiveBetween(0, SessionFieldLimits.MaxAmountPiasters).WithErrorCode(ErrorCodes.OutOfRange);
        RuleFor(x => x.PaymentMethod).OneOf(PaymentMethods.All);
    }
}

/// <summary>deleteSession (BR-S7): the reason is required.</summary>
public sealed record DeleteSessionRequest(Guid? SessionId, string? Reason);

public sealed class DeleteSessionRequestValidator : AbstractValidator<DeleteSessionRequest>
{
    public DeleteSessionRequestValidator()
    {
        RuleFor(x => x.SessionId).Required();
        RuleFor(x => x.Reason)
            .Must(reason => reason is not null && reason.Trim().Length >= 3)
            .WithErrorCode(ErrorCodes.ReasonRequired).WithMessage("Give a reason (at least 3 characters).")
            .MaxChars(500);
    }
}

public sealed class NewSessionInfoQuery
{
    public Guid? PatientId { get; init; }

    public Guid? BranchId { get; init; }
}

public sealed class NewSessionInfoQueryValidator : AbstractValidator<NewSessionInfoQuery>
{
    public NewSessionInfoQueryValidator()
    {
        RuleFor(x => x.PatientId).Required();
        RuleFor(x => x.BranchId).Required();
    }
}

public sealed class PatientSessionsQuery : IPagedQuery
{
    public int Page { get; init; } = 1;

    public int PageSize { get; init; } = Paging.DefaultPageSize;
}

public sealed class PatientSessionsQueryValidator : AbstractValidator<PatientSessionsQuery>
{
    public PatientSessionsQueryValidator() => this.AddPagingRules();
}

/// <summary>D2 / AS1. <c>day</c> is a Cairo date (YYYY-MM-DD), default today.</summary>
public sealed class DaySessionsQuery
{
    public string? Day { get; init; }

    public Guid? BranchId { get; init; }

    public string? Type { get; init; }

    /// <summary>A user ID: the doctor or one assistant.</summary>
    public Guid? RecordedBy { get; init; }
}

public sealed class DaySessionsQueryValidator : AbstractValidator<DaySessionsQuery>
{
    public DaySessionsQueryValidator()
    {
        RuleFor(x => x.Day).Must(day => day is null || CairoDays.ParseDay(day) is not null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use YYYY-MM-DD.");
        RuleFor(x => x.Type).OneOf(SessionTypes.All);
    }
}

/// <summary>D3. <c>month</c> is a Cairo month (YYYY-MM), default this month.</summary>
public sealed class MonthFeesQuery
{
    public string? Month { get; init; }

    public Guid? BranchId { get; init; }
}

public sealed class MonthFeesQueryValidator : AbstractValidator<MonthFeesQuery>
{
    public MonthFeesQueryValidator() =>
        RuleFor(x => x.Month).Must(month => month is null || CairoTime.ParseMonthKey(month) is not null)
            .WithErrorCode(ErrorCodes.InvalidValue).WithMessage("Use YYYY-MM.");
}

public static class CairoDays
{
    /// <summary>Reads 'YYYY-MM-DD', or null when it isn't one.</summary>
    public static DateOnly? ParseDay(string? day) =>
        DateOnly.TryParseExact(day, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture,
            System.Globalization.DateTimeStyles.None, out var value)
            ? value
            : null;
}
