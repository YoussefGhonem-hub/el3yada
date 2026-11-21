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
    /// <summary>Queue mode on the day: "now serving" for the period (BR-AP15).</summary>
    int? NowServing,
    /// <summary>Queue mode, checked in: about when the patient goes in (Cairo time).</summary>
    TimeOnly? EstimatedTime,
    IReadOnlyList<AppointmentHistoryDto>? History,
    IReadOnlyList<BranchPhoneDto>? BranchPhones,
    /// <summary>Queue mode, checked in: patients who go in first (priority, then lower numbers) (BR-AP16).</summary>
    int? Ahead = null,
    /// <summary>Queue mode, checked in: <see cref="Ahead"/> × the branch's average visit time.</summary>
    int? EstimatedWaitMinutes = null);

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

public sealed record PeriodInput(int Weekday, TimeOnly Start, TimeOnly End, bool EndsNextDay, string? Label, int? Capacity);

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

/// <summary><c>keep</c> or <c>cancel</c> for one affected booking (BR-AP12). Move = reschedule it first.</summary>
public sealed record ConflictDecision(Guid AppointmentId, string Action);

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

public sealed record ScheduleConflictDto(Guid AppointmentId, string DisplayName, DateOnly Date, TimeOnly Time, int? QueueNumber, string Status);

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
        RuleForEach(x => x.Weekly).ChildRules(p =>
        {
            p.RuleFor(x => x.Weekday).InclusiveBetween(1, 7).WithErrorCode("INVALID_WEEKDAY");
            p.RuleFor(x => x).Must(x => PeriodRules.LengthOk(x.Start, x.End, x.EndsNextDay)).WithName("period").WithErrorCode("PERIOD_LENGTH");
            p.RuleFor(x => x.Capacity).InclusiveBetween(1, 200).When(x => x.Capacity is not null).WithErrorCode("INVALID_RANGE");
            p.RuleFor(x => x.Label).MaximumLength(30).WithErrorCode("TOO_LONG");
        });
        RuleFor(x => x.Weekly).Must(PeriodRules.NoOverlap).WithErrorCode("PERIODS_OVERLAP");
        RuleForEach(x => x.DateOverrides).ChildRules(o =>
        {
            o.RuleForEach(x => x.Periods).Must(p => PeriodRules.LengthOk(p.Start, p.End, p.EndsNextDay)).WithErrorCode("PERIOD_LENGTH");
            o.RuleFor(x => x.Periods).Must(ps => PeriodRules.NoOverlap(ps.Select(p => new PeriodInput(1, p.Start, p.End, p.EndsNextDay, null, null)).ToList()))
                .WithErrorCode("PERIODS_OVERLAP");
        });
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
        RuleForEach(x => x.Decisions).Must(d => d.Action is "keep" or "cancel").WithErrorCode("INVALID_ACTION");
    }
}

/// <summary>Working-hours rules (spec 11).</summary>
public static class PeriodRules
{
    public static int Minutes(TimeOnly start, TimeOnly end, bool nextDay) =>
        (int)((end.ToTimeSpan() + (nextDay ? TimeSpan.FromDays(1) : TimeSpan.Zero)) - start.ToTimeSpan()).TotalMinutes;

    /// <summary>Ends after it starts (or the next day), and lasts 15 minutes to 16 hours.</summary>
    public static bool LengthOk(TimeOnly start, TimeOnly end, bool nextDay) => Minutes(start, end, nextDay) is >= 15 and <= 960;

    public static bool NoOverlap(IReadOnlyList<PeriodInput> periods) =>
        periods.GroupBy(p => p.Weekday).All(day =>
        {
            var ordered = day.OrderBy(p => p.Start).ToList();
            for (var i = 1; i < ordered.Count; i++)
            {
                var prevEnd = ordered[i - 1].Start.ToTimeSpan() + TimeSpan.FromMinutes(Minutes(ordered[i - 1].Start, ordered[i - 1].End, ordered[i - 1].EndsNextDay));
                if (ordered[i].Start.ToTimeSpan() < prevEnd) return false;
            }
            return true;
        });
}
