using El3yada.Api.Audit;
using El3yada.Api.Billing;
using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.AccountDeletion;

/// <summary>
/// <c>accountErasure</c>, run once a day by <see cref="BillingJobsHost"/> (spec 9.3): every deletion whose grace period
/// has passed is erased (<see cref="AccountErasure"/>), except a doctor who still owes an invoice, whose deletion
/// becomes <c>waitingPayment</c> until it is paid (BR-DEL9). One transaction per deletion, each row locked and checked
/// again inside it, so a second run, a second server or a restore at the same moment changes nothing it should not.
/// </summary>
public sealed class AccountDeletionJob(
    AppDbContext db,
    AccountErasure erasure,
    Auditor auditor,
    AccountStateCache stateCache,
    Storage.IFileStorage storage,
    TimeProvider time,
    ILogger<AccountDeletionJob> logger)
{
    /// <summary>Processes the deletions due. Returns how many accounts were erased.</summary>
    public async Task<int> RunAsync(CancellationToken cancellationToken)
    {
        var now = time.GetUtcNow().UtcDateTime;
        var due = await db.DeletionRequests.AsNoTracking()
            .Where(r => DeletionStatuses.Open.Contains(r.Status) && r.ScheduledFor <= now)
            .OrderBy(r => r.ScheduledFor)
            .Select(r => r.Id)
            .ToListAsync(cancellationToken);

        var erased = 0;
        foreach (var id in due)
        {
            if (await ProcessAsync(id, now, cancellationToken))
            {
                erased++;
            }
        }

        return erased;
    }

    private async Task<bool> ProcessAsync(Guid requestId, DateTime now, CancellationToken cancellationToken)
    {
        db.ChangeTracker.Clear();
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        var request = await db.DeletionRequests
            .FromSqlInterpolated($"SELECT * FROM [DeletionRequests] WITH (UPDLOCK, ROWLOCK) WHERE [Id] = {requestId}")
            .SingleOrDefaultAsync(cancellationToken);
        if (request is null || !DeletionStatuses.IsOpen(request.Status) || request.ScheduledFor > now)
        {
            return false;
        }

        if (request.Role == Roles.Doctor)
        {
            var owed = await db.Invoices.Where(i => i.DoctorId == request.UserId && InvoiceStatuses.Outstanding.Contains(i.Status))
                .Select(i => new { i.Id, i.MonthKey, i.TotalDuePiasters })
                .ToListAsync(cancellationToken);
            if (owed.Count > 0)
            {
                if (request.Status != DeletionStatuses.WaitingPayment)
                {
                    request.Status = DeletionStatuses.WaitingPayment;
                    auditor.Add(
                        AuditActions.AccountDeletionWaitingPayment, AuditTargets.User, request.UserId,
                        new { requestId = request.Id, invoices = owed.Select(i => i.MonthKey), owedPiasters = owed.Sum(i => i.TotalDuePiasters) },
                        doctorId: request.UserId, actor: AuditActor.System);
                    await db.SaveChangesAsync(cancellationToken);
                    await transaction.CommitAsync(cancellationToken);
                    logger.LogInformation("Deletion of doctor {UserId} waits for {Count} invoices", request.UserId, owed.Count);
                }

                return false;
            }
        }

        var assistants = request.Role == Roles.Doctor
            ? await db.Assistants.AsNoTracking().Where(a => a.DoctorId == request.UserId).Select(a => a.UserId).ToListAsync(cancellationToken)
            : [];
        var files = await erasure.EraseAsync(request.UserId, cancellationToken);
        request.Status = DeletionStatuses.Completed;
        request.CompletedAt = now;
        auditor.Add(
            AuditActions.AccountErased, AuditTargets.User, request.UserId,
            new { requestId = request.Id, role = request.Role, assistantsErased = assistants.Count, filesRemoved = files.Count },
            doctorId: request.DoctorId, patientId: request.PatientId, actor: AuditActor.System);
        await db.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

        stateCache.Invalidate(request.UserId);
        foreach (var assistantId in assistants)
        {
            stateCache.Invalidate(assistantId);
        }

        foreach (var file in files)
        {
            try
            {
                await storage.DeleteAsync(file, cancellationToken);
            }
            catch (IOException error)
            {
                // The rows no longer point at the file; a leftover is harmless and is logged for cleanup.
                logger.LogWarning(error, "Could not delete a file of erased account {UserId}", request.UserId);
            }
        }

        logger.LogInformation("Account {UserId} ({Role}) erased", request.UserId, request.Role);
        return true;
    }
}
