using El3yada.Api.Patients;

namespace El3yada.Api.Sessions;

public sealed record SessionBranchView(Guid Id, string NameAr, string? NameEn);

/// <summary>Who saved the session (BR-AS6 "Recorded by"): the doctor or one of their assistants.</summary>
public sealed record RecordedByView(Guid UserId, string Name, string Role);

public sealed record VitalsView(
    short? BpSys, short? BpDia, short? Pulse, decimal? TempC, decimal? WeightKg, decimal? HeightCm, short? Glucose);

/// <summary>The clinical fields (spec 6.2). Only for the doctor and assistants with <c>clinicalView</c>.</summary>
public sealed record SessionClinicalView(
    string? ChiefComplaint,
    string? Findings,
    VitalsView Vitals,
    string? Diagnosis,
    string? PatientNotes,
    DateOnly? FollowUpDate);

/// <summary>
/// What the caller may do with this session now, so D9 shows only the actions that will work.
/// <c>deleteBlockedReason</c> is the BR-S7 reason (<c>notLatest</c>, <c>notSameDay</c>) whatever the caller's
/// permissions; <c>delete</c> also needs <c>sessionsDelete</c>.
/// </summary>
public sealed record SessionActionsView(bool EditClinical, bool EditAmount, bool Delete, string? DeleteBlockedReason, bool PrivateNote);

/// <summary>
/// D9 (<c>GET /api/sessions/{sessionId}</c>, and the answer of every session write). Never holds the private note.
/// <list type="bullet">
/// <item><c>amountChargedPiasters</c>, <c>listPricePiasters</c>, <c>paymentMethod</c>: null unless the caller has
/// <c>revenueView</c> or recorded the session.</item>
/// <item><c>clinical</c>: null without <c>clinicalView</c>.</item>
/// <item><c>hasPrivateNote</c>: null except for the doctor.</item>
/// </list>
/// </summary>
public sealed record SessionDetailView(
    Guid SessionId,
    Guid PatientId,
    int FileNumber,
    string PatientName,
    string Type,
    DateTime At,
    DateOnly Day,
    SessionBranchView Branch,
    int PlatformFeePiasters,
    int? AmountChargedPiasters,
    int? ListPricePiasters,
    string? PaymentMethod,
    RecordedByView RecordedBy,
    bool AwaitingDoctor,
    SessionClinicalView? Clinical,
    bool? HasPrivateNote,
    SessionActionsView Can,
    DateTime UpdatedAt);

/// <summary>
/// A row of the D6 Sessions tab and of D2 / AS1. Money and clinical fields as in <see cref="SessionDetailView"/>:
/// <c>amountChargedPiasters</c> and <c>paymentMethod</c> need <c>revenueView</c> or having recorded the session;
/// <c>chiefComplaint</c> and <c>diagnosis</c> need <c>clinicalView</c>.
/// </summary>
public sealed record SessionListItem(
    Guid SessionId,
    DateTime At,
    DateOnly Day,
    string Type,
    Guid PatientId,
    int FileNumber,
    string PatientName,
    SessionBranchView Branch,
    int PlatformFeePiasters,
    int? AmountChargedPiasters,
    string? PaymentMethod,
    RecordedByView RecordedBy,
    bool AwaitingDoctor,
    string? ChiefComplaint,
    string? Diagnosis);

/// <summary>One session type on the D8 / AS5 type cards.</summary>
public sealed record SessionTypeOptionView(bool Allowed, int PlatformFeePiasters, int? VisitPricePiasters, string? PriceSource);

/// <summary>
/// newSessionInfo (D8 step 1, AS5): the consultation rule state (BR-S3, BR-S4: «استشارة 1 من 2 منذ آخر كشف»),
/// the platform fee per type (BR-S6 confirmation) and the visit price per type (BR-S10 default amount).
/// </summary>
public sealed record NewSessionInfoView(
    Guid PatientId,
    Guid BranchId,
    bool IsFirstVisit,
    LastVisitView? LastSession,
    int ConsultationsSinceExam,
    int MaxConsecutiveConsultations,
    bool ConsultationAllowed,
    string? ConsultationBlockedReason,
    SessionTypeOptionView Examination,
    SessionTypeOptionView Consultation);

public sealed record DeletedSessionResponse(Guid SessionId, DateTime DeletedAt);

public sealed record PrivateNoteView(Guid SessionId, string? Text, DateTime? UpdatedAt);

/// <summary>Platform-fee totals (BR-B2, BR-B3): counts and sums of the fee snapshots of non-deleted sessions.</summary>
public sealed record FeeTotalsView(
    int ExaminationCount,
    int ConsultationCount,
    int ExaminationFeePiasters,
    int ConsultationFeePiasters,
    int TotalPiasters)
{
    public static readonly FeeTotalsView Zero = new(0, 0, 0, 0, 0);

    public FeeTotalsView Add(string type, int count, int feePiasters) => type == SessionTypes.Examination
        ? this with { ExaminationCount = ExaminationCount + count, ExaminationFeePiasters = ExaminationFeePiasters + feePiasters, TotalPiasters = TotalPiasters + feePiasters }
        : this with { ConsultationCount = ConsultationCount + count, ConsultationFeePiasters = ConsultationFeePiasters + feePiasters, TotalPiasters = TotalPiasters + feePiasters };
}

/// <summary>
/// D2 / AS1: one Cairo day's sessions, newest first, and their totals. <c>amountChargedTotalPiasters</c> is null
/// without <c>revenueView</c>.
/// </summary>
public sealed record DaySessionsView(
    DateOnly Day,
    IReadOnlyList<SessionListItem> Items,
    FeeTotalsView Totals,
    int? AmountChargedTotalPiasters);

/// <summary>D1 platform fee cards (AC-4): today and this month, for the whole clinic.</summary>
public sealed record FeeSummaryView(DateOnly Day, string Month, FeeTotalsView Today, FeeTotalsView ThisMonth);

public sealed record BranchFeesView(Guid BranchId, string NameAr, string? NameEn, FeeTotalsView Totals);

public sealed record DayFeesView(DateOnly Day, FeeTotalsView Totals);

/// <summary>D3: the month's totals, the totals per branch (they add up to the month's, BR-BR7) and one row per day.</summary>
public sealed record MonthFeesView(
    string Month,
    Guid? BranchId,
    FeeTotalsView Totals,
    IReadOnlyList<BranchFeesView> Branches,
    IReadOnlyList<DayFeesView> Days);
