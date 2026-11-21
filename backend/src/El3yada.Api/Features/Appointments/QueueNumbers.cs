using El3yada.Data;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Features.Appointments;

/// <summary>
/// BR-AP3: in queue mode the number is given at check-in, not at booking, so the order to see the doctor is
/// the order of arrival at the clinic. Booked patients have no number; walk-ins take the next one the same way.
/// <para>
/// The period is locked by its <c>BranchDayStates</c> row (UPDLOCK + HOLDLOCK, created if missing) for the rest
/// of the caller's transaction, so two receptionists checking in at the same moment are served one after the
/// other and never get the same number. The next number is one more than the highest the period has ever
/// given: numbers are never reused (a patient who left without being seen keeps theirs, and undoing a no-show
/// gives a new one). The unique index <c>UQ_Appointments_QueueNumber</c> is the second guard.
/// </para>
/// </summary>
public static class QueueNumbers
{
    /// <summary>Locks one period until the current transaction ends. Needs an open transaction.</summary>
    public static async Task LockPeriodAsync(AppDbContext db, Guid branchId, DateOnly date, TimeOnly period, DateTime nowUtc, CancellationToken ct)
    {
        if (db.Database.CurrentTransaction is null)
            throw new InvalidOperationException("A queue number is given inside a transaction that locks the period.");
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            IF NOT EXISTS (SELECT 1 FROM [BranchDayStates] WITH (UPDLOCK, HOLDLOCK)
                           WHERE [BranchId] = {branchId} AND [LocalDate] = {date} AND [PeriodStartLocal] = {period})
                INSERT INTO [BranchDayStates] ([BranchId], [LocalDate], [PeriodStartLocal], [UpdatedAt])
                VALUES ({branchId}, {date}, {period}, {nowUtc});
            """, ct);
    }

    /// <summary>The period's next number. Call it after <see cref="LockPeriodAsync"/>, in the same transaction.</summary>
    public static async Task<int> NextAsync(AppDbContext db, Guid branchId, DateOnly date, TimeOnly period, CancellationToken ct) =>
        (await db.Appointments
            .Where(a => a.BranchId == branchId && a.LocalDate == date && a.PeriodStartLocal == period)
            .MaxAsync(a => a.QueueNumber, ct) ?? 0) + 1;

    /// <summary>Locks the period and returns its next number.</summary>
    public static async Task<int> TakeAsync(AppDbContext db, Guid branchId, DateOnly date, TimeOnly period, DateTime nowUtc, CancellationToken ct)
    {
        await LockPeriodAsync(db, branchId, date, period, nowUtc, ct);
        return await NextAsync(db, branchId, date, period, ct);
    }
}
