using El3yada.Data.Entities;

namespace El3yada.Api.Sessions;

/// <summary>Sessions.Type values (BR-S1).</summary>
public static class SessionTypes
{
    public const string Examination = "examination";
    public const string Consultation = "consultation";

    public static readonly string[] All = [Examination, Consultation];
}

/// <summary>Sessions.PaymentMethod values (BR-S10 [S]).</summary>
public static class PaymentMethods
{
    public static readonly string[] All = ["cash", "card", "instapay", "wallet"];
}

/// <summary>
/// The consultation rule (BR-S2, BR-S3). The server checks it inside createSession with the link row locked
/// (BR-S4), from the link's counters, which count non-deleted sessions only.
/// </summary>
public static class ConsultationRule
{
    /// <summary>The patient has no examination with this doctor yet: the first session must be one (BR-S2).</summary>
    public const string FirstVisit = "firstVisit";

    /// <summary><c>maxConsecutiveConsultations</c> consultations in a row since the last examination (BR-S3).</summary>
    public const string LimitReached = "limitReached";

    /// <summary>
    /// Why a consultation can't be recorded now, or null when it can. An examination is always allowed and
    /// resets the count; the limit is a maximum, so 0, 1 … max − 1 consultations so far all allow one more.
    /// </summary>
    public static string? ConsultationBlockedReason(int examCount, int consultationsSinceExam, int maxConsecutive) =>
        examCount == 0 ? FirstVisit
        : consultationsSinceExam >= maxConsecutive ? LimitReached
        : null;

    /// <summary>Why a session of <paramref name="type"/> can't be recorded now, or null.</summary>
    public static string? BlockedReason(string type, int examCount, int consultationsSinceExam, int maxConsecutive) =>
        type == SessionTypes.Examination ? null : ConsultationBlockedReason(examCount, consultationsSinceExam, maxConsecutive);
}

/// <summary>What the link counters need from one session.</summary>
public sealed record SessionFact(Guid Id, string Type, DateTime CreatedAt, Guid BranchId);

/// <summary>
/// The counter columns of a doctor–patient link (DoctorPatients): first and last session, counts, and
/// ConsultationsSinceExam for BR-S3. createSession adds one session with <see cref="With"/>; deleteSession
/// rebuilds them from the remaining non-deleted sessions with <see cref="From"/>.
/// </summary>
public sealed record LinkCounters(
    DateTime? FirstSessionAt,
    Guid? LastSessionId,
    string? LastSessionType,
    DateTime? LastSessionAt,
    Guid? LastSessionBranchId,
    int SessionCount,
    int ExamCount,
    int ConsultationCount,
    int ConsultationsSinceExam)
{
    public static readonly LinkCounters Empty = new(null, null, null, null, null, 0, 0, 0, 0);

    /// <summary>The counters for these sessions (any order; the non-deleted ones only).</summary>
    public static LinkCounters From(IEnumerable<SessionFact> sessions) =>
        sessions.OrderBy(s => s.CreatedAt).ThenBy(s => s.Id).Aggregate(Empty, (counters, session) => counters.With(session));

    /// <summary>The counters after <paramref name="session"/>, which is newer than every counted session.</summary>
    public LinkCounters With(SessionFact session)
    {
        var examination = session.Type == SessionTypes.Examination;
        return new LinkCounters(
            FirstSessionAt ?? session.CreatedAt,
            session.Id,
            session.Type,
            session.CreatedAt,
            session.BranchId,
            SessionCount + 1,
            ExamCount + (examination ? 1 : 0),
            ConsultationCount + (examination ? 0 : 1),
            examination ? 0 : ConsultationsSinceExam + 1);
    }

    public static LinkCounters Of(DoctorPatient link) => new(
        link.FirstSessionAt, link.LastSessionId, link.LastSessionType, link.LastSessionAt, link.LastSessionBranchId,
        link.SessionCount, link.ExamCount, link.ConsultationCount, link.ConsultationsSinceExam);

    public void ApplyTo(DoctorPatient link)
    {
        link.FirstSessionAt = FirstSessionAt;
        link.LastSessionId = LastSessionId;
        link.LastSessionType = LastSessionType;
        link.LastSessionAt = LastSessionAt;
        link.LastSessionBranchId = LastSessionBranchId;
        link.SessionCount = SessionCount;
        link.ExamCount = ExamCount;
        link.ConsultationCount = ConsultationCount;
        link.ConsultationsSinceExam = ConsultationsSinceExam;
    }
}

/// <summary>Where a visit price came from (BR-PR2): the branch's own price, the doctor's, or none (BR-PR6).</summary>
public static class PriceSources
{
    public const string Branch = "branch";
    public const string Doctor = "doctor";
}

/// <summary>The clinic's visit price for a session type (spec 6.15), separate from the platform fee.</summary>
public sealed record VisitPrice(int? Piasters, string? Source)
{
    /// <summary>The branch's price for the type if it has one, otherwise the doctor's, otherwise none (BR-PR2, BR-S10).</summary>
    public static VisitPrice For(
        string type, int? branchExamination, int? branchConsultation, int? doctorExamination, int? doctorConsultation)
    {
        var (branch, doctor) = type == SessionTypes.Examination
            ? (branchExamination, doctorExamination)
            : (branchConsultation, doctorConsultation);
        return branch is not null ? new VisitPrice(branch, PriceSources.Branch)
            : doctor is not null ? new VisitPrice(doctor, PriceSources.Doctor)
            : new VisitPrice(null, null);
    }
}

/// <summary>BR-S7: why a session can't be deleted, or null.</summary>
public static class DeleteRule
{
    /// <summary>A newer non-deleted session of this patient with this doctor exists.</summary>
    public const string NotLatest = "notLatest";

    /// <summary>It was recorded on an earlier Cairo day.</summary>
    public const string NotSameDay = "notSameDay";

    public static string? BlockedReason(bool isLatest, DateOnly sessionDay, DateOnly today) =>
        !isLatest ? NotLatest : sessionDay != today ? NotSameDay : null;
}
