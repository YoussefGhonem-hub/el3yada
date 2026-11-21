using El3yada.Api.ClinicAdmin;
using El3yada.Api.Features.PatientPortal;
using El3yada.Api.Infrastructure.Paging;
using El3yada.Api.Infrastructure.Validation;
using FluentValidation;

namespace El3yada.Api.Features.Appointments;

// ---- Requests ---------------------------------------------------------------------------------

public sealed record GuestInput(string Name, string Phone);

/// <summary>
/// <c>createAppointment</c>. Queue mode: <see cref="Time"/> is the period start; timed mode: the slot start.
/// Staff may pass <see cref="Overbook"/> and <see cref="ConfirmWarnings"/> after seeing the warning (BR-AP7, case 2).
/// </summary>
public sealed record CreateAppointmentRequest(
    Guid BranchId,
    Guid? PatientId,
    GuestInput? Guest,
    string VisitType,
    DateOnly Date,
    TimeOnly Time,
    string? Reason,
    string? StaffNotes,
    bool Overbook = false,
    bool ConfirmWarnings = false);

public sealed record RescheduleRequest(Guid BranchId, DateOnly Date, TimeOnly Time, string? Reason, bool Overbook = false);

public sealed record ReasonRequest(string? Reason);

public sealed record WalkInRequest(Guid BranchId, Guid? PatientId, GuestInput? Guest, string VisitType, string? StaffNotes);

public sealed record ConvertGuestRequest(Guid PatientId);

public sealed record DelayRequest(Guid BranchId, int Minutes);

public sealed record BranchDayRequest(Guid BranchId, string? Reason);

public sealed record SetSelfBookingRequest(bool Enabled, string? Reason);

public sealed record AvailabilityQuery(Guid BranchId, string VisitType, DateOnly From, DateOnly? To);

public sealed record SearchAppointmentsQuery : PageQuery
{
    public DateOnly? From { get; init; }
    public DateOnly? To { get; init; }
    public List<Guid>? BranchIds { get; init; }
    public List<string>? Statuses { get; init; }
    public string? VisitType { get; init; }
    public string? Source { get; init; }
    public Guid? BookedBy { get; init; }

    /// <summary>Patient or guest name, phone or file number.</summary>
    public string? Q { get; init; }
    public bool GuestsOnly { get; init; }
    public bool RescheduledOnly { get; init; }
    public bool OverbookedOnly { get; init; }
    public bool CheckedInNoSession { get; init; }

    /// <summary><c>morning</c> (before 15:00) or <c>evening</c>.</summary>
    public string? Period { get; init; }
    public string Sort { get; init; } = "date";
}

// ---- Responses --------------------------------------------------------------------------------

public sealed record AppointmentHistoryDto(DateTime At, string ByRole, string? ByName, string Action, string? From, string? To, string? Reason);

public sealed record AppointmentDto(
    Guid Id,
    Guid DoctorId,
    DoctorRef Doctor,
    Guid BranchId,
    BranchRef Branch,
    Guid? PatientId,
    string DisplayName,
    string? Phone,
    bool IsGuest,
    string VisitType,
    string Mode,
    DateOnly Date,
    TimeOnly Time,
    DateTime StartUtc,
    DateTime? EndUtc,
    int? QueueNumber,
    string Status,
    string Source,
    string BookedByRole,
    string? BookedByName,
    string? Reason,
    string? StaffNotes,
    bool Overbooked,
    int RescheduleCount,
    DateTime? CheckedInAt,
    DateTime? CalledAt,
    Guid? SessionId,
    string? CancelReason,
    string? CancelledByRole,
    bool IsPriority,
    bool FlaggedNoSession,
    DateTime CreatedAt,
    /// <summary>Patients: can still cancel or reschedule themselves (BR-AP5).</summary>
    bool CanChange,
    /// <summary>Queue mode on the day: "now serving" and the estimated time (BR-AP15).</summary>
    int? NowServing,
    TimeOnly? EstimatedTime,
    IReadOnlyList<AppointmentHistoryDto>? History,
    IReadOnlyList<BranchPhoneDto>? BranchPhones);

public sealed record SearchResultDto(PagedResult<AppointmentDto> Page, IReadOnlyDictionary<string, int> StatusCounts);

/// <summary>P15 step 1–3: what this patient can book with a doctor.</summary>
public sealed record BookingOptionsDto(
    DoctorRef Doctor,
    bool CanBook,
    string? UnavailableReason,
    bool IsNewPatient,
    bool ConsultationAllowed,
    int ConsultationsSinceExam,
    int MaxConsecutiveConsultations,
    Guid? UpcomingAppointmentId,
    IReadOnlyList<BookingBranchDto> Branches);

public sealed record BookingBranchDto(
    Guid Id, string NameAr, string? NameEn, string? Area, string Status, string? ClosedMessage, string Mode,
    bool SelfBooking, int FreeCancelMinutes, int WindowDays, VisitPricesDto Prices, IReadOnlyList<BranchPhoneDto> Phones);

public sealed record AvailabilityDto(Guid BranchId, string Mode, IReadOnlyList<DayAvailability> Days);

/// <summary>The live-board side panel (spec 6.13): loaded from the API, never mirrored to Firebase.</summary>
public sealed record BoardPatientSummaryDto(
    Guid AppointmentId,
    string DisplayName,
    bool IsGuest,
    string? Phone,
    string? Gender,
    int? Age,
    int? FileNumber,
    int ExamCount,
    int ConsultationCount,
    DateTime? FirstVisitAt,
    DateTime? LastVisitAt,
    string? LastVisitType,
    int UpcomingBookings,
    int NoShows,
    string? Reason,
    string? StaffNotes,
    // clinicalView / doctor only
    IReadOnlyList<string>? Allergies,
    IReadOnlyList<string>? ChronicDiseases,
    string? LastDiagnosis,
    // revenueView / doctor only
    IReadOnlyList<int>? RecentAmountsPiasters,
    bool ConsultationAllowed,
    bool SelfBookingBlocked);

// ---- Schedule (D29, AS17) ---------------------------------------------------------------------

public sealed record PeriodInput(int Weekday, TimeOnly Start, TimeOnly End, bool EndsNextDay, string? Label, int? Capacity)
{
    public WeeklyPeriod ToPeriod() => new(Weekday, Start, End, EndsNextDay, Label, Capacity);
}

public sealed record DatePeriodInput(TimeOnly Start, TimeOnly End, bool EndsNextDay, string? Label, int? Capacity);

/// <summary>Special hours for one date. No periods = closed that day.</summary>
public sealed record DateOverrideInput(DateOnly Date, IReadOnlyList<DatePeriodInput> Periods);

/// <summary>A closure or blocked time. <c>AllBranches</c> = a vacation for every branch (BR-AP13).</summary>
public sealed record ClosureInput(Guid? Id, DateTime FromLocal, DateTime ToLocal, string? Reason, bool AllBranches);

public sealed record BookingSettingsInput(
    string Mode, int SlotMinutes, int ExamSlots, int ConsultationSlots, int DefaultCapacity, int AvgVisitMinutes,
    bool SelfBooking, bool AutoConfirm, int WindowDays, int MinNoticeMinutes, bool SameDay, int FreeCancelMinutes,
    int MaxReschedules, int MaxUpcomingPerPatient, int NoShowLimitCount, int NoShowLimitDays,
    IReadOnlyList<int> ReminderMinutes, bool StaffOverbooking, bool WaitingOrderByArrival);

/// <summary>
/// What to do with one affected booking (BR-AP12): <c>keep</c> it as an exception, <c>move</c> it to
/// <c>date</c> and <c>time</c> (a period start in queue mode, a slot start in timed mode) in <c>branchId</c>
/// (its own branch when null), or <c>cancel</c> it (the patient is notified with a rebook link). A move is a
/// clinic reschedule (BR-AP6) made in the same transaction as the schedule change.
/// </summary>
public sealed record ConflictDecision(Guid AppointmentId, string Action, Guid? BranchId = null, DateOnly? Date = null, TimeOnly? Time = null);

/// <summary>A place a booking can move to: a period start (queue) or a slot start (timed).</summary>
public sealed record MovePlaceDto(Guid BranchId, DateOnly Date, TimeOnly Time);

public sealed record UpdateScheduleRequest(
    IReadOnlyList<PeriodInput> Weekly,
    IReadOnlyList<DateOverrideInput> DateOverrides,
    IReadOnlyList<ClosureInput> Closures,
    BookingSettingsInput Settings,
    bool DryRun,
    IReadOnlyList<ConflictDecision>? Decisions);

public sealed record ScheduleDto(
    Guid BranchId,
    IReadOnlyList<PeriodInput> Weekly,
    IReadOnlyList<DateOverrideInput> DateOverrides,
    IReadOnlyList<ClosureInput> Closures,
    BookingSettingsInput Settings);

/// <summary>
/// A booking the new schedule leaves without a place (BR-AP12). <c>suggestion</c> is the nearest free place under
/// the new schedule in the booking's branch (the same day first, then up to 14 days later, closest to the booked
/// time), or null when there is none. The suggestions in one answer never take the same place twice.
/// </summary>
public sealed record ScheduleConflictDto(
    Guid AppointmentId, string DisplayName, DateOnly Date, TimeOnly Time, int? QueueNumber, string Status,
    Guid BranchId, string VisitType, MovePlaceDto? Suggestion);

public sealed record UpdateScheduleResult(bool Applied, IReadOnlyList<ScheduleConflictDto> Conflicts);

public sealed record StaffBranchDto(Guid Id, string NameAr, string? NameEn, bool IsDefault, string Status, string Mode);

// ---- Validation (spec 11) ---------------------------------------------------------------------

public sealed class CreateAppointmentRequestValidator : AbstractValidator<CreateAppointmentRequest>
{
    public CreateAppointmentRequestValidator()
    {
        RuleFor(x => x.VisitType).Must(v => v is "examination" or "consultation").WithErrorCode("VISIT_TYPE_REQUIRED");
        // Patients send neither (they book for themselves); staff send exactly one (checked in the service).
        RuleFor(x => x).Must(x => x.PatientId is null || x.Guest is null).WithName("patientId").WithErrorCode("PATIENT_OR_GUEST");
        RuleFor(x => x.Guest!.Name).Must(n => n.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries).Length >= 2 && n.Trim().Length <= 60)
            .When(x => x.Guest is not null).WithName("guestName").WithErrorCode("GUEST_NAME");
        RuleFor(x => x.Guest!.Phone).Must(p => EgyptianPhone.TryNormalize(p, out _))
            .When(x => x.Guest is not null).WithName("guestPhone").WithErrorCode("INVALID_PHONE");
        RuleFor(x => x.Reason).MaximumLength(200).WithErrorCode("TOO_LONG");
        RuleFor(x => x.StaffNotes).MaximumLength(500).WithErrorCode("TOO_LONG");
    }
}

public sealed class WalkInRequestValidator : AbstractValidator<WalkInRequest>
{
    public WalkInRequestValidator()
    {
        RuleFor(x => x.VisitType).Must(v => v is "examination" or "consultation").WithErrorCode("VISIT_TYPE_REQUIRED");
        RuleFor(x => x).Must(x => (x.PatientId is null) != (x.Guest is null)).WithName("patientId").WithErrorCode("PATIENT_OR_GUEST");
        RuleFor(x => x.Guest!.Phone).Must(p => EgyptianPhone.TryNormalize(p, out _))
            .When(x => x.Guest is not null).WithName("guestPhone").WithErrorCode("INVALID_PHONE");
        RuleFor(x => x.Guest!.Name).NotEmpty().MaximumLength(60).When(x => x.Guest is not null).WithName("guestName").WithErrorCode("GUEST_NAME");
    }
}

public sealed class RescheduleRequestValidator : AbstractValidator<RescheduleRequest>
{
    public RescheduleRequestValidator() => RuleFor(x => x.Reason).MaximumLength(200).WithErrorCode("TOO_LONG");
}

public sealed class ReasonRequestValidator : AbstractValidator<ReasonRequest>
{
    public ReasonRequestValidator() => RuleFor(x => x.Reason).MaximumLength(200).WithErrorCode("TOO_LONG");
}

public sealed class DelayRequestValidator : AbstractValidator<DelayRequest>
{
    public DelayRequestValidator() => RuleFor(x => x.Minutes).InclusiveBetween(5, 240).WithErrorCode("INVALID_RANGE");
}

public sealed class UpdateScheduleRequestValidator : AbstractValidator<UpdateScheduleRequest>
{
    public UpdateScheduleRequestValidator()
    {
        // The D29 working-hours rules (spec 11, ClinicAdmin/WeeklyHours.cs), on the period they are about:
        // weekly[i].weekday, .label and .capacity first; then, once every weekday is readable, the whole week:
        // weekly[i].end (PERIOD_END_BEFORE_START, PERIOD_LENGTH_OUT_OF_RANGE), weekly[i] (PERIODS_OVERLAP, on the
        // later period) and weekly (INVALID_VALUE: more than 10 periods in a day).
        RuleFor(x => x.Weekly).NotNull().WithErrorCode(ErrorCodes.Required);
        RuleForEach(x => x.Weekly).Cascade(CascadeMode.Continue).ChildRules(p =>
        {
            p.RuleFor(x => x.Weekday).InclusiveBetween(1, 7).WithErrorCode(ErrorCodes.OutOfRange);
            p.RuleFor(x => x.Capacity).InclusiveBetween(WeeklyHours.MinCapacity, WeeklyHours.MaxCapacity)
                .When(x => x.Capacity is not null).WithErrorCode(ErrorCodes.OutOfRange);
            p.RuleFor(x => x.Label).Must(l => l is null || l.Trim().Length <= WeeklyHours.MaxLabelChars).WithErrorCode(ErrorCodes.TooLong);
        });
        RuleFor(x => x.Weekly).Custom((periods, context) =>
        {
            if (periods is null || periods.Any(p => p is null || p.Weekday is < 1 or > 7)) return;
            AddPeriodProblems(context, "Weekly", WeeklyHours.Check(periods.Select(p => p.ToPeriod()).ToList()));
        });
        RuleFor(x => x.DateOverrides).NotNull().WithErrorCode(ErrorCodes.Required);
        RuleForEach(x => x.DateOverrides).Cascade(CascadeMode.Continue).ChildRules(o =>
        {
            o.RuleForEach(x => x.Periods).Cascade(CascadeMode.Continue).ChildRules(p =>
            {
                p.RuleFor(x => x.Capacity).InclusiveBetween(WeeklyHours.MinCapacity, WeeklyHours.MaxCapacity)
                    .When(x => x.Capacity is not null).WithErrorCode(ErrorCodes.OutOfRange);
                p.RuleFor(x => x.Label).Must(l => l is null || l.Trim().Length <= WeeklyHours.MaxLabelChars).WithErrorCode(ErrorCodes.TooLong);
            });
        });
        // Each special date: the same rules, on one day (dateOverrides[i].periods[j].end, dateOverrides[i].periods[j]).
        RuleFor(x => x.DateOverrides).Custom((overrides, context) =>
        {
            if (overrides is null) return;
            for (var i = 0; i < overrides.Count; i++)
            {
                if (overrides[i]?.Periods is not { } periods) continue;
                AddPeriodProblems(context, $"DateOverrides[{i}].Periods", WeeklyHours.Check(periods
                    .Select(p => new WeeklyPeriod(1, p.Start, p.End, p.EndsNextDay, p.Label, p.Capacity)).ToList()));
            }
        });
        RuleFor(x => x.Closures).NotNull().WithErrorCode(ErrorCodes.Required);
        RuleForEach(x => x.Closures).Must(c => c.ToLocal > c.FromLocal).WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.Mode).Must(m => m is "queue" or "timed").WithName("mode").WithErrorCode("INVALID_MODE");
        RuleFor(x => x.Settings.SlotMinutes).InclusiveBetween(5, 120).WithName("slotMinutes").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.ExamSlots).InclusiveBetween(1, 8).WithName("examSlots").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.ConsultationSlots).InclusiveBetween(1, 8).WithName("consultationSlots").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.DefaultCapacity).InclusiveBetween(1, 200).WithName("defaultCapacity").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.AvgVisitMinutes).InclusiveBetween(1, 240).WithName("avgVisitMinutes").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.WindowDays).InclusiveBetween(1, 180).WithName("windowDays").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.MinNoticeMinutes).InclusiveBetween(0, 1440).WithName("minNoticeMinutes").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.FreeCancelMinutes).InclusiveBetween(0, 2880).WithName("freeCancelMinutes").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.MaxReschedules).InclusiveBetween(0, 5).WithName("maxReschedules").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.MaxUpcomingPerPatient).InclusiveBetween(1, 5).WithName("maxUpcomingPerPatient").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.NoShowLimitCount).InclusiveBetween(1, 20).WithName("noShowLimitCount").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.NoShowLimitDays).InclusiveBetween(1, 365).WithName("noShowLimitDays").WithErrorCode("INVALID_RANGE");
        RuleFor(x => x.Settings.ReminderMinutes).Must(r => r.Count <= 3 && r.All(m => m is >= 15 and <= 2880)).WithName("reminderMinutes").WithErrorCode("INVALID_RANGE");
        RuleForEach(x => x.Decisions).Cascade(CascadeMode.Continue).ChildRules(d =>
        {
            d.RuleFor(x => x.Action).Must(a => a is "keep" or "move" or "cancel").WithErrorCode("INVALID_ACTION");
            d.RuleFor(x => x.Date).NotNull().When(x => x.Action == "move").WithErrorCode(ErrorCodes.Required);
            d.RuleFor(x => x.Time).NotNull().When(x => x.Action == "move").WithErrorCode(ErrorCodes.Required);
        });
    }

    /// <summary>WeeklyHours problems as failures on <c>{root}[i].end</c>, <c>{root}[i]</c> or <c>{root}</c>.</summary>
    private static void AddPeriodProblems<T>(ValidationContext<T> context, string root, IReadOnlyList<PeriodProblem> problems)
    {
        foreach (var problem in problems)
        {
            var field = problem.Field switch { "startLocal" => "Start", "endLocal" => "End", var other => other };
            var path = problem.Index < 0 ? root
                : field.Length == 0 ? $"{root}[{problem.Index}]"
                : $"{root}[{problem.Index}].{field}";
            context.AddFailure(new FluentValidation.Results.ValidationFailure(path, problem.Message) { ErrorCode = problem.Code });
        }
    }
}
