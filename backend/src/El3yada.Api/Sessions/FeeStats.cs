using System.Data;
using El3yada.Data;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace El3yada.Api.Sessions;

/// <summary>
/// DailyStats and MonthlyStats: the platform-fee counters per doctor and Cairo day or month (spec 9.1
/// createSession and deleteSession). The fee screens read SQL aggregates over Sessions, which are the source
/// of truth (spec 9.3); these counters are for the analytics and the nightly reconcile (Phase 7).
/// <para>
/// Each change is one SQL statement that adds to the stored value, inside the session's transaction, so two
/// sessions saved at once never lose an update. A missing row is inserted under a key-range lock
/// (UPDLOCK, SERIALIZABLE), so two first sessions of a day can't both insert it.
/// </para>
/// </summary>
public static class FeeStats
{
    private const string AddSql = """
        UPDATE [DailyStats] WITH (UPDLOCK, SERIALIZABLE)
        SET [ExamCount] = [ExamCount] + @exams, [ConsultationCount] = [ConsultationCount] + @consultations,
            [AmountPiasters] = [AmountPiasters] + @fee
        WHERE [DoctorId] = @doctorId AND [DayKey] = @day;
        IF @@ROWCOUNT = 0
            INSERT INTO [DailyStats] ([DoctorId], [DayKey], [MonthKey], [ExamCount], [ConsultationCount], [AmountPiasters])
            VALUES (@doctorId, @day, @month, @exams, @consultations, @fee);

        UPDATE [MonthlyStats] WITH (UPDLOCK, SERIALIZABLE)
        SET [ExamCount] = [ExamCount] + @exams, [ConsultationCount] = [ConsultationCount] + @consultations,
            [AmountPiasters] = [AmountPiasters] + @fee
        WHERE [DoctorId] = @doctorId AND [MonthKey] = @month;
        IF @@ROWCOUNT = 0
            INSERT INTO [MonthlyStats] ([DoctorId], [MonthKey], [ExamCount], [ConsultationCount], [AmountPiasters])
            VALUES (@doctorId, @month, @exams, @consultations, @fee);
        """;

    private const string RemoveSql = """
        UPDATE [DailyStats]
        SET [ExamCount] = [ExamCount] - @exams, [ConsultationCount] = [ConsultationCount] - @consultations,
            [AmountPiasters] = [AmountPiasters] - @fee
        WHERE [DoctorId] = @doctorId AND [DayKey] = @day;

        UPDATE [MonthlyStats]
        SET [ExamCount] = [ExamCount] - @exams, [ConsultationCount] = [ConsultationCount] - @consultations,
            [AmountPiasters] = [AmountPiasters] - @fee
        WHERE [DoctorId] = @doctorId AND [MonthKey] = @month;
        """;

    /// <summary>Adds one session's platform fee to the day and the month.</summary>
    public static Task AddAsync(
        AppDbContext db, Guid doctorId, DateOnly day, string month, string type, int feePiasters, CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlRawAsync(AddSql, Parameters(doctorId, day, month, type, feePiasters), cancellationToken);

    /// <summary>Takes a deleted session's platform fee off its day and month (BR-S7: the totals drop by that fee).</summary>
    public static Task RemoveAsync(
        AppDbContext db, Guid doctorId, DateOnly day, string month, string type, int feePiasters, CancellationToken cancellationToken) =>
        db.Database.ExecuteSqlRawAsync(RemoveSql, Parameters(doctorId, day, month, type, feePiasters), cancellationToken);

    /// <summary>
    /// Typed like the key columns (DATE, CHAR(7)): an NVARCHAR month would make SQL Server convert the column
    /// and lock every month row of the doctor instead of one.
    /// </summary>
    private static SqlParameter[] Parameters(Guid doctorId, DateOnly day, string month, string type, int feePiasters)
    {
        var examination = type == SessionTypes.Examination;
        return
        [
            new("@doctorId", SqlDbType.UniqueIdentifier) { Value = doctorId },
            new("@day", SqlDbType.Date) { Value = day.ToDateTime(TimeOnly.MinValue) },
            new("@month", SqlDbType.Char, 7) { Value = month },
            new("@exams", SqlDbType.Int) { Value = examination ? 1 : 0 },
            new("@consultations", SqlDbType.Int) { Value = examination ? 0 : 1 },
            new("@fee", SqlDbType.Int) { Value = feePiasters },
        ];
    }
}
