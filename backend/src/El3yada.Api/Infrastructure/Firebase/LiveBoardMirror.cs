using Google.Apis.Auth.OAuth2;
using Google.Cloud.Firestore;

namespace El3yada.Api.Infrastructure.Firebase;

/// <summary>Counts per board column (spec 6.13).</summary>
public sealed record BoardCounts(int Expected, int Waiting, int WithDoctor, int Done, int Missed);

public sealed record BoardEntryFlags(bool Priority, bool WalkIn, bool Late, bool Guest, bool ConsultationNotAllowed, bool HasNotes, bool Pending);

/// <summary>
/// One card on today's board. Holds no phone numbers and no medical data (spec 9.6, AC-25):
/// the side panel loads the rest from the API.
/// </summary>
public sealed record BoardEntry(
    Guid AppointmentId,
    int? QueueNumber,
    string? TimeLocal,
    string Stage,
    string DisplayName,
    string VisitType,
    string Source,
    bool IsNewPatient,
    DateOnly? LastVisitDate,
    string? LastVisitType,
    BoardEntryFlags Flags,
    DateTime? CheckedInAt,
    DateTime? CalledAt,
    int Order,
    string Status,
    Guid? PatientId,
    Guid? SessionId,
    DateTime CreatedAt);

public sealed record BoardSnapshot(
    Guid DoctorId,
    Guid BranchId,
    DateOnly Date,
    string Mode,
    int? NowServing,
    int? DelayMinutes,
    BoardCounts Counts,
    IReadOnlyList<BoardEntry> Entries,
    IReadOnlyList<int> NextNumbers,
    DateTime UpdatedAt);

/// <summary>
/// The read-only Firestore mirror of today's boards (spec 9.6). Only the API writes it, after every
/// booking change; SQL Server stays the source of truth.
/// </summary>
public interface ILiveBoardMirror
{
    Task PublishAsync(BoardSnapshot snapshot, CancellationToken ct);
}

public sealed class NoopLiveBoardMirror : ILiveBoardMirror
{
    public Task PublishAsync(BoardSnapshot snapshot, CancellationToken ct) => Task.CompletedTask;
}

/// <summary>
/// Writes <c>liveBoards/{branchId}_{date}</c> (+ <c>entries</c>) and <c>liveQueues/{branchId}_{date}</c>.
/// Every document has <c>expireAt</c> = date + 2 days for the Firestore TTL policy.
/// </summary>
public sealed class FirestoreLiveBoardMirror : ILiveBoardMirror
{
    private readonly FirestoreDb _db;
    private readonly ILogger<FirestoreLiveBoardMirror> _logger;

    public FirestoreLiveBoardMirror(FirebaseOptions options, ILogger<FirestoreLiveBoardMirror> logger)
    {
        _db = new FirestoreDbBuilder
        {
            ProjectId = options.ProjectId,
            GoogleCredential = CredentialFactory.FromFile<ServiceAccountCredential>(options.CredentialsPath!).ToGoogleCredential(),
        }.Build();
        _logger = logger;
    }

    public async Task PublishAsync(BoardSnapshot s, CancellationToken ct)
    {
        try
        {
            var id = $"{s.BranchId}_{s.Date:yyyy-MM-dd}";
            var expireAt = Timestamp.FromDateTime(DateTime.SpecifyKind(s.Date.ToDateTime(TimeOnly.MinValue).AddDays(2), DateTimeKind.Utc));
            var board = _db.Collection("liveBoards").Document(id);
            var entries = board.Collection("entries");

            var existing = await entries.Select(FieldPath.DocumentId).GetSnapshotAsync(ct);
            var keep = s.Entries.Select(e => e.AppointmentId.ToString()).ToHashSet();

            var batch = _db.StartBatch();
            batch.Set(board, new Dictionary<string, object?>
            {
                ["doctorId"] = s.DoctorId.ToString(), ["branchId"] = s.BranchId.ToString(), ["date"] = s.Date.ToString("yyyy-MM-dd"),
                ["mode"] = s.Mode, ["nowServing"] = s.NowServing, ["delayMinutes"] = s.DelayMinutes,
                ["counts"] = new Dictionary<string, object>
                {
                    ["expected"] = s.Counts.Expected, ["waiting"] = s.Counts.Waiting, ["withDoctor"] = s.Counts.WithDoctor,
                    ["done"] = s.Counts.Done, ["missed"] = s.Counts.Missed,
                },
                ["updatedAt"] = Timestamp.FromDateTime(DateTime.SpecifyKind(s.UpdatedAt, DateTimeKind.Utc)),
                ["expireAt"] = expireAt,
            });
            foreach (var e in s.Entries)
            {
                batch.Set(entries.Document(e.AppointmentId.ToString()), new Dictionary<string, object?>
                {
                    ["queueNumber"] = e.QueueNumber, ["timeLocal"] = e.TimeLocal, ["stage"] = e.Stage,
                    ["displayName"] = e.DisplayName, ["visitType"] = e.VisitType, ["source"] = e.Source,
                    ["isNewPatient"] = e.IsNewPatient, ["lastVisitDate"] = e.LastVisitDate?.ToString("yyyy-MM-dd"),
                    ["lastVisitType"] = e.LastVisitType,
                    ["flags"] = new Dictionary<string, object>
                    {
                        ["priority"] = e.Flags.Priority, ["walkIn"] = e.Flags.WalkIn, ["late"] = e.Flags.Late, ["guest"] = e.Flags.Guest,
                        ["consultationNotAllowed"] = e.Flags.ConsultationNotAllowed, ["hasNotes"] = e.Flags.HasNotes, ["pending"] = e.Flags.Pending,
                    },
                    ["checkedInAt"] = e.CheckedInAt is { } c ? Timestamp.FromDateTime(DateTime.SpecifyKind(c, DateTimeKind.Utc)) : null,
                    ["calledAt"] = e.CalledAt is { } k ? Timestamp.FromDateTime(DateTime.SpecifyKind(k, DateTimeKind.Utc)) : null,
                    ["order"] = e.Order,
                    ["expireAt"] = expireAt,
                });
            }
            foreach (var doc in existing.Documents.Where(d => !keep.Contains(d.Id))) batch.Delete(doc.Reference);

            batch.Set(_db.Collection("liveQueues").Document(id), new Dictionary<string, object?>
            {
                ["nowServing"] = s.NowServing, ["delayMinutes"] = s.DelayMinutes, ["nextNumbers"] = s.NextNumbers.ToList(),
                ["updatedAt"] = Timestamp.FromDateTime(DateTime.SpecifyKind(s.UpdatedAt, DateTimeKind.Utc)), ["expireAt"] = expireAt,
            });
            await batch.CommitAsync(ct);
        }
        catch (Exception error)
        {
            // The board falls back to the API refresh; never fail the booking because of the mirror.
            _logger.LogWarning(error, "Firestore mirror write failed for branch {BranchId}", s.BranchId);
        }
    }
}
