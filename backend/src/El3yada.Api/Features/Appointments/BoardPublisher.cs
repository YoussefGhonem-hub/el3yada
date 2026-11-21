using El3yada.Api.Infrastructure.Firebase;
using El3yada.Api.Infrastructure.Realtime;
using El3yada.Api.Infrastructure.Time;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// Builds a branch's live board for a day from SQL Server (the source of truth) and publishes it
/// after every change (BR-LB1): to the Firestore mirror when configured, and as a SignalR event to
/// every clinic device watching that branch (BR-LB2), plus "now serving" for patients (BR-AP15).
/// </summary>
public sealed class BoardPublisher(AppDbContext db, ILiveBoardMirror mirror, IRealtime realtime, TimeProvider clock)
{
    /// <summary>The columns, in board order (6.13).</summary>
    public static readonly string[] Stages = ["expected", "waiting", "withDoctor", "done", "missed"];

    public static string StageOf(string status) => status switch
    {
        AppointmentStatuses.Pending or AppointmentStatuses.Confirmed => "expected",
        AppointmentStatuses.CheckedIn => "waiting",
        AppointmentStatuses.WithDoctor => "withDoctor",
        AppointmentStatuses.Completed => "done",
        _ => "missed",
    };

    public async Task<BoardSnapshot> BuildAsync(Guid branchId, DateOnly date, CancellationToken ct)
    {
        var branch = await db.Branches.AsNoTracking().Where(b => b.Id == branchId)
            .Select(b => new { b.DoctorId, b.BookingMode, b.WaitingOrderByArrival })
            .FirstAsync(ct);
        var maxConsultations = await db.AppSettings.AsNoTracking().Select(s => s.MaxConsecutiveConsultations).FirstAsync(ct);
        var nowUtc = clock.GetUtcNow().UtcDateTime;

        var rows = await db.Appointments.AsNoTracking()
            .Where(a => a.BranchId == branchId && a.LocalDate == date)
            .Select(a => new
            {
                a.Id, a.QueueNumber, a.StartUtc, a.Status, a.VisitType, a.Source, a.IsPriority, a.Overbooked, a.Mode, a.PeriodStartLocal,
                a.PatientId, a.GuestName, a.Reason, a.StaffNotes, a.CheckedInAt, a.CalledAt, a.BoardOrder, a.SessionId, a.CreatedAt,
                Link = db.DoctorPatients.Where(l => l.DoctorId == a.DoctorId && l.PatientId == a.PatientId)
                    .Select(l => new { l.PatientName, l.SessionCount, l.LastSessionAt, l.LastSessionType, l.ConsultationsSinceExam })
                    .FirstOrDefault(),
            })
            .ToListAsync(ct);

        // The order of each column (6.13):
        // - Expected: queue mode by booking time, as those patients have no number until they arrive; timed mode by time.
        // - Waiting: priority first, then by queue number, which is the order of arrival (BR-AP3); timed mode by time,
        //   or [S] by arrival when the branch asks. Each period is its own line.
        // - With the doctor by when they went in; the rest by their order.
        // `Order` is the card's place on the whole board, for listeners of the Firestore mirror.
        var sorted = rows.Select(r =>
        {
            var stage = StageOf(r.Status);
            var queue = r.Mode == "queue";
            var withinStage = stage switch
            {
                "expected" when queue => r.CreatedAt.Ticks,
                "expected" => (long)r.BoardOrder * TimeSpan.TicksPerMinute,
                "waiting" when branch.WaitingOrderByArrival => r.CheckedInAt?.Ticks ?? long.MaxValue,
                "withDoctor" => r.CalledAt?.Ticks ?? long.MaxValue,
                _ => r.BoardOrder,
            };
            return (Row: r, Stage: stage, Key: (
                Stage: Array.IndexOf(Stages, stage),
                Priority: stage == "waiting" && r.IsPriority ? 0 : 1,
                Period: stage == "waiting" && queue ? r.PeriodStartLocal.Ticks : 0,
                Within: withinStage,
                Created: r.CreatedAt.Ticks));
        })
        .OrderBy(x => x.Key)
        .ToList();

        var entries = sorted.Select((x, index) =>
        {
            var (r, stage) = (x.Row, x.Stage);
            var isGuest = r.PatientId is null;
            var lateAfter = r.StartUtc.AddMinutes(15);
            return new BoardEntry(
                r.Id,
                r.QueueNumber,
                CairoTime.ToCairo(r.StartUtc).ToString("HH:mm"),
                stage,
                isGuest ? r.GuestName! : r.Link?.PatientName ?? "",
                r.VisitType,
                r.Source,
                isGuest || (r.Link?.SessionCount ?? 0) == 0,
                r.Link?.LastSessionAt is { } last ? DateOnly.FromDateTime(CairoTime.ToCairo(last)) : null,
                r.Link?.LastSessionType,
                new BoardEntryFlags(
                    Priority: r.IsPriority,
                    WalkIn: r.Source == "walkIn",
                    Late: stage == "expected" && branch.BookingMode == "timed" && nowUtc > lateAfter,
                    Guest: isGuest,
                    ConsultationNotAllowed: r.VisitType == "consultation" && (r.Link is null || r.Link.ConsultationsSinceExam >= maxConsultations),
                    HasNotes: r.Reason is not null || r.StaffNotes is not null,
                    Pending: r.Status == AppointmentStatuses.Pending),
                r.CheckedInAt,
                r.CalledAt,
                index,
                r.Status,
                r.PatientId,
                r.SessionId,
                r.CreatedAt);
        })
        .ToList();

        var counts = new BoardCounts(
            entries.Count(e => e.Stage == "expected"), entries.Count(e => e.Stage == "waiting"),
            entries.Count(e => e.Stage == "withDoctor"), entries.Count(e => e.Stage == "done"), entries.Count(e => e.Stage == "missed"));

        // A period's row also exists once someone checks in to it (the check-in lock), so "now serving" and the
        // delay each come from the latest row that has one.
        var states = await db.BranchDayStates.AsNoTracking()
            .Where(s => s.BranchId == branchId && s.LocalDate == date)
            .Select(s => new { s.NowServingNumber, s.DelayMinutes, s.UpdatedAt })
            .ToListAsync(ct);
        var nowServing = states.Where(s => s.NowServingNumber is not null).MaxBy(s => s.UpdatedAt)?.NowServingNumber
            ?? entries.Where(e => e.Stage == "withDoctor").Select(e => e.QueueNumber).FirstOrDefault();
        var delay = states.Where(s => s.DelayMinutes is not null).MaxBy(s => s.UpdatedAt)?.DelayMinutes;
        // The waiting-room screen (D36) shows these after "now serving": the Waiting column's numbers, in its order.
        var next = entries.Where(e => e.Stage == "waiting" && e.QueueNumber is not null).Select(e => e.QueueNumber!.Value).Take(5).ToList();

        return new BoardSnapshot(branch.DoctorId, branchId, date, branch.BookingMode, nowServing, delay,
            counts, entries, next, nowUtc);
    }

    /// <summary>After a change. Only today's board is live; other days are fetched on demand.</summary>
    public async Task PublishAsync(Guid branchId, DateOnly date, CancellationToken ct)
    {
        if (date != CairoTime.Today(clock)) return;
        var snapshot = await BuildAsync(branchId, date, ct);
        await mirror.PublishAsync(snapshot, ct);
        await realtime.ToBoardAsync(branchId, new { branchId, date, counts = snapshot.Counts, updatedAt = snapshot.UpdatedAt });
        await realtime.ToQueueAsync(branchId, new { branchId, date, snapshot.NowServing, snapshot.DelayMinutes, snapshot.NextNumbers });
    }
}
